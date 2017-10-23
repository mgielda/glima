require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'launchy'
require 'forwardable'

# Retry if rate-limit.
Google::Apis::RequestOptions.default.retries = 5

module Glima
  class GmailClient
    class AuthorizationError < StandardError ; end

    extend Forwardable

    def_delegators :@client,
    # Users.histoy
    :list_user_histories,

    # Users.labels
    :list_user_labels,
    # :get_user_label,
    :patch_user_label,

    # Users.messages
    :get_user_message,
    :insert_user_message,
    :list_user_messages,
    :modify_message,
    # :trash_user_message,

    # Users.threads
    :get_user_thread,

    # Users getProfile
    :get_user_profile

    attr_reader :user

    # Find nearby messages from pivot_message
    # `Nearby' message:
    #   + has same From: address
    #   + has near Date: field (+-1day)
    # with the pivot_message.
    def nearby_mails(pivot_mail)
      from  = "from:#{pivot_mail.from}"
      date1 = (pivot_mail.date.to_date - 1).strftime("after:%Y/%m/%d")
      date2 = (pivot_mail.date.to_date + 1).strftime("before:%Y/%m/%d")
      query = "#{from} -in:trash #{date1} #{date2}"
      scan_batch("+all", query) do |mail|
        next if pivot_mail.id == mail.id
        yield mail
      end
    end

    # * message types by format:
    #   | field/fromat:   | list | minimal | raw | value type      |
    #   |-----------------+------+---------+-----+-----------------|
    #   | id              | ○   | ○      | ○  | string          |
    #   | threadId        | ○   | ○      | ○  | string          |
    #   | labelIds        |      | ○      | ○  | string[]        |
    #   | snippet         |      | ○      | ○  | string          |
    #   | historyId       |      | ○      | ○  | unsinged long   |
    #   | internalDate    |      | ○      | ○  | long            |
    #   | sizeEstimate    |      | ○      | ○  | int             |
    #   |-----------------+------+---------+-----+-----------------|
    #   | payload         |      |         |     | object          |
    #   | payload.headers |      |         |     | key/value pairs |
    #   | raw             |      |         | ○  | bytes           |
    #
    def get_user_smart_message(id)
      fmt = if @datastore.exist?(id) then "minimal" else "raw" end

      mail = nil
      @client.get_user_message(me, id, format: fmt) do |m, err|
        mail = Glima::Resource::Mail.new(@datastore.update(m)) if m
        yield(mail, err)
      end
      return mail
    end

    def online?
      Socket.getifaddrs.select {|i|
        i.addr.ipv4? and ! i.addr.ipv4_loopback?
      }.map(&:addr).map(&:ip_address).length > 0
    end

    def initialize(client_id, client_secret, token_store_path, user, datastore, logger = nil)
      @client_id = client_id
      @client_secret = client_secret
      @token_store_path = token_store_path
      @user = user
      @datastore = datastore
      @client = Google::Apis::GmailV1::GmailService.new
      @client.client_options.application_name = 'glima'
      if logger
        @logger = logger
      else
        # quiet
        @logger = ::Logger.new($stderr)
        @logger.formatter = proc {|severity, datetime, progname, msg| ""}
      end
    end

    def auth_interactively
      credentials = begin
                      authorizer.auth_interactively(@user)
                    rescue
                      raise AuthorizationError.new
                    end
      @client.authorization = credentials
      @client.authorization
      @client.authorization.username = @user # for IMAP
    end

    def auth
      unless credentials = authorizer.credentials(@user)
        raise AuthorizationError.new
      end
      @client.authorization = credentials
      @client.authorization.username = @user # for IMAP
    end

    def watch(label = nil, &block)
      loop do
        @logger.info "[#{self.class}#watch] loop tick"

        curr_hid = get_user_profile(me).history_id.to_i
        last_hid ||= curr_hid

        # If server is changed at this point, we will miss the events.
        # so, we have to set the timeout and update history record.

        wait(label, 60) if last_hid == curr_hid

        each_events(since: last_hid) do |ev|
          yield ev
          last_hid = ev.history_id.to_i
        end
      end
    end

    def each_events(since:)
      options, response = {start_history_id: since}, nil

      loop do
        client.list_user_histories(me, options) do |res, err|
          raise err if err
          response = res
        end

        break unless response.history

        response.history.each do |h|
          Glima::Resource::History.new(h).to_events.each do |ev|
            yield ev
          end
        end

        break unless options[:page_token] = response.next_page_token
      end
    end

    def get_user_label(id, fields: nil, options: nil, &block)
      client.get_user_label(me, id, fields: fields, options: options, &block)
    end

    def trash_user_message(id, fields: nil, options: nil, &block)
      client.trash_user_message(me, id, fields: fields, options: options, &block)
    end

    def batch(options = nil)
      @client.batch(options) do |batch_client|
        begin
          Thread.current[:glima_api_batch] = batch_client
          yield self
        ensure
          Thread.current[:glima_api_batch] = nil
        end
      end
    end

    def scan_batch(folder, search_or_range = nil, &block)
      qp = Glima::QueryParameter.new(folder, search_or_range)
      list_user_messages(me, qp.to_hash) do |res, error|
        fail "#{error}" if error
        ids = (res.messages || []).map(&:id)
        unless ids.empty?
          batch_on_messages(ids) do |message|
            yield Glima::Resource::Mail.new(message) if block
          end
          # context.save_page_token(res.next_page_token)
        end
      end
    rescue Glima::QueryParameter::FormatError => e
      STDERR.print "Error: " + e.message + "\n"
    end

    def find_messages(query)
      qp = Glima::QueryParameter.new("+all", query)
      list_user_messages(me, qp.to_hash) do |res, error|
        STDERR.print "#{error}" if error
        return (res.messages || []).map(&:id)
      end
    rescue Glima::QueryParameter::FormatError => e
      STDERR.print "Error: " + e.message + "\n"
    end

    def labels
      @labels ||= client.list_user_labels(me).labels
    end

    def label_by_name(label_name)
      labels.find {|label| label.name == label_name}
    end

    def label_by_id(label_id)
      labels.find {|label| label.id == label_id}
    end

    private

    def authorizer
      @authorizer ||= Clian::Authorizer.new(
        @client_id,
        @client_secret,
        Google::Apis::GmailV1::AUTH_SCOPE,
        @token_store_path
      )
    end

    def me
      'me'
    end

    def client
      Thread.current[:glima_api_batch] || @client
    end

    def batch_on_messages(ids, &block)
      @client.batch do |batch_client|
        ids.each do |id|
          fmt = if @datastore.exist?(id) then "minimal" else "raw" end

          batch_client.get_user_message(me, id, format: fmt) do |m, err|
            fail "#{err}" if err
            message = @datastore.update(m)
            yield message
          end
        end
      end
    end

    # label == nil means "[Gmail]/All Mail"
    def wait(label = nil, timeout_sec = 60)
      @logger.info "[#{self.class}#wait] Enter"

      if @imap.nil? || @imap.disconnected?
        @imap = Glima::ImapWatch.new("imap.gmail.com", @client.authorization, @logger)

        @logger.info "[#{self.class}#wait] create new IMAPWatch #{@imap}"
      else
        @logger.info "[#{self.class}#wait] use existing IMAPWatch #{@imap}"
      end

      begin
        @imap.wait(label&.name, timeout_sec)
      rescue
        @imap = nil
        @logger.info "[#{self.class}#wait] imap connection error. abandon current imap connection."
      end
      @logger.info "[#{self.class}#wait] Exit"
    end

  end # class GmailClient
end # module Glima

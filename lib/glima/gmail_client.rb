require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'launchy'
require 'forwardable'

# Retry if rate-limit.
Google::Apis::RequestOptions.default.retries = 5

module Glima
  class Authorizer
    def initialize(client_id, client_secret, scope, token_store_path)
      @authorizer = Google::Auth::UserAuthorizer.new(
        Google::Auth::ClientId.new(client_id, client_secret),
        scope,
        Google::Auth::Stores::FileTokenStore.new(file: token_store_path)
      )
    end

    def credentials(user_id = "default")
      @authorizer.get_credentials(user_id)
    end

    def auth_interactively(user_id = "default", shell = Thor.new.shell)
      oob_uri = "urn:ietf:wg:oauth:2.0:oob"

      url = @authorizer.get_authorization_url(base_url: oob_uri)
      begin
        Launchy.open(url)
      rescue
        puts "Open URL in your browser:\n #{url}"
      end

      code = shell.ask "Enter the resulting code:"

      @authorizer.get_and_store_credentials_from_code(
        user_id:  user_id,
        code:     code,
        base_url: oob_uri
      )
    end
  end # Authorizer

  class GmailClient
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
    :get_user_profile,


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
      scan_batch("+all", query) do |message|
        next if pivot_mail.id == message.id
        yield Glima::Resource::Mail.new(message)
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

    def initialize(config, datastore)
      authorizer = Authorizer.new(config.client_id,
                                  config.client_secret,
                                  Google::Apis::GmailV1::AUTH_SCOPE,
                                  config.token_store)

      credentials = authorizer.credentials(config.default_user) ||
                    authorizer.auth_interactively(config.default_user)
      @datastore = datastore
      @client = Google::Apis::GmailV1::GmailService.new
      @client.client_options.application_name = 'glima'
      @client.authorization = credentials
      @client.authorization.username = config.default_user # for IMAP
      return @client
    end

    # label == nil means "[Gmail]/All Mail"
    def wait(label = nil)
      @imap ||= Glima::ImapWatch.new("imap.gmail.com", @client.authorization)
      @imap.wait(label)
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
            yield message if block
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

    private

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

  end # class GmailClient
end # module Glima

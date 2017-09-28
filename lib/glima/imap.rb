require 'forwardable'
require "net/imap"
require "pp"

module Glima
  #
  # IMAP client with IMAP extentions provided by Gmail
  #   https://developers.google.com/gmail/imap/imap-extensions
  #
  class IMAP < Net::IMAP
    def initialize(host, port_or_options = {},
                   usessl = false, certs = nil, verify = true)
      super
      @parser = Glima::IMAP::ResponseParser.new
    end

    class Xoauth2Authenticator
      def initialize(user, oauth2_token)
        @user = user
        @oauth2_token = oauth2_token
      end

      def process(data)
        build_oauth2_string(@user, @oauth2_token)
      end

      private
      # https://developers.google.com/google-apps/gmail/xoauth2_protocol
      def build_oauth2_string(user, oauth2_token)
        str = "user=%s\1auth=Bearer %s\1\1".encode("us-ascii") % [user, oauth2_token]
        return str
      end
    end
    private_constant :Xoauth2Authenticator
    add_authenticator('XOAUTH2', Xoauth2Authenticator)

    class ResponseParser < Net::IMAP::ResponseParser
      def msg_att(n = 0)
        match(T_LPAR)
        attr = {}
        while true
          token = lookahead
          case token.symbol
          when T_RPAR
            shift_token
            break
          when T_SPACE
            shift_token
            next
          end
          case token.value
          when /\A(?:ENVELOPE)\z/ni
            name, val = envelope_data
          when /\A(?:FLAGS)\z/ni
            name, val = flags_data
          when /\A(?:INTERNALDATE)\z/ni
            name, val = internaldate_data
          when /\A(?:RFC822(?:\.HEADER|\.TEXT)?)\z/ni
            name, val = rfc822_text
          when /\A(?:RFC822\.SIZE)\z/ni
            name, val = rfc822_size
          when /\A(?:BODY(?:STRUCTURE)?)\z/ni
            name, val = body_data
          when /\A(?:UID)\z/ni
            name, val = uid_data

          # Gmail extension additions.
          # https://gist.github.com/WojtekKruszewski/1404434
          when /\A(?:X-GM-LABELS)\z/ni
            name, val = flags_data
          when /\A(?:X-GM-MSGID)\z/ni
            name, val = uid_data
          when /\A(?:X-GM-THRID)\z/ni
            name, val = uid_data
          else
            parse_error("unknown attribute `%s' for {%d}", token.value, n)
          end
          attr[name] = val
        end
        return attr
      end
    end # class ResponseParser
  end # class IMAP
end # module Glima

module Glima
  class ImapWatch
    extend Forwardable

    def_delegators :@imap,
    :fetch,
    :select,
    :disconnect

    def initialize(imap_server, authorization)
      @imap_server, @authorization = imap_server, authorization
      connect(imap_server, authorization)
    end

    def watch(folder, &block)
      @imap.select(Net::IMAP.encode_utf7(folder))

      @thread = Thread.new do
        while true
          begin
            @imap.idle do |resp|
              yield resp if resp.name == "EXISTS"
            end
          rescue Net::IMAP::Error => e
            if e.inspect.include? "connection closed"
              connect
            else
              raise
            end
          end
        end
      end
    end

    def wait(folder = nil, timeout_sec = 60)
      if folder
        folder = Net::IMAP.encode_utf7(folder)
      else
        # select "[Gmail]/All Mail" or localized one like "[Gmail]/すべてのメール"
        folder = @imap.list("", "[Gmail]/*").find {|f| f.attr.include?(:All)}.name
      end

      @imap.select(folder)
      begin
        th = Thread.new(@imap, timeout_sec) do |imap, timeout|
          begin
            sleep timeout
          ensure
            imap.idle_done
          end
        end

        @imap.idle do |resp|
          puts "#{resp.name}"
          th.terminate
        end
      rescue Net::IMAP::Error => e
        if e.inspect.include? "connection closed"
          reconnect
        else
          raise
        end
      end
    end # def wait

    # Ruby IMAP IDLE concurrency - how to tackle? - Stack Overflow
    # http://stackoverflow.com/questions/5604480/ruby-imap-idle-concurrency-how-to-tackle
    # How bad is IMAP IDLE? Joshua Tauberer's Archived Blog
    # https://joshdata.wordpress.com/2014/08/09/how-bad-is-imap-idle/
    #
    def watch_and_fetch(folder, &block)
      @imap.select(folder)
      num = @imap.responses["EXISTS"].last

      last_uid = @imap.fetch(num, "UID").first.attr['UID']
      puts "Last_UID: #{last_uid}"

      while true
        id = waitfor()

        puts "*********** GET EXISTS: #{id}"
        mails = @imap.uid_fetch(last_uid..-1, %w(UID X-GM-MSGID X-GM-THRID X-GM-LABELS))

        mails.each do |mail|
          next if mail.attr['UID'] <= last_uid
          resp  = yield mail
          return unless resp
        end

        last_uid = mails.last.attr['UID']
      end
    end

    private

    def waitfor
      id = -1
      begin
        @imap.idle do |resp|
          pp resp
          if resp.name == "EXISTS"
            @imap.idle_done
            id = resp.data.to_i
          else
            # pp resp
          end
        end
      rescue Net::IMAP::Error => e
        if e.inspect.include? "connection closed"
          reconnect
        else
          raise
        end
      end
      return id
    end

    def connect(imap_server, authorization)
      retry_count = 0

      begin
        @imap = Glima::IMAP.new(imap_server, 993, true)
        @imap.authenticate('XOAUTH2',
                           authorization.username,
                           authorization.access_token)
        puts "Connected to imap server #{imap_server}."

      rescue Net::IMAP::NoResponseError => e
        if e.inspect.include? "Invalid credentials" && retry_count < 2
          puts "Refreshing access token for #{imap_server}."
          authorization.refresh!
          retry_count += 1
          retry
        else
          raise
        end
      end
    end

    def reconnect
      connect(@imap_server, @authorization)
    end

  end # class ImapWatch
end # module Glima

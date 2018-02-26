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

      set_keepalive(@sock, 30) # set *TCP* Keepalive
    end

    # https://www.winehq.org/pipermail/wine-devel/2015-July/108583.html
    # TCP_KEEPALIVE on Darwin corresponds to Linux TCP_KEEPIDLE, not TCP_KEEPINTVL.
    #
    # * Darwin (macOS)
    #   /usr/include/netinet/tcp.h:
    #     : #define TCP_KEEPALIVE  0x10    /* idle time used when SO_KEEPALIVE is enabled */
    #  : TCP_KEEPALIVE = 0x10
    #  : TCP_KEEPCNT   = 0x102
    #  : TCP_KEEPINTVL = 0x101
    # * Linux
    #  : TCP_KEEPIDLE
    #  : TCP_KEEPCNT
    #  : TCP_KEEPINTVL
    #
    # Configurable TCP keepalives by normelton: PR #262 redis/redis-rb
    #   https://github.com/redis/redis-rb/pull/262
    #
    def set_keepalive(sock, sec)
      xTCP_KEEPIDLE = if RUBY_PLATFORM =~ /darwin/ then 0x10 else :TCP_KEEPIDLE end

      idle, interval, probes = if sec >= 60
                                 [sec - 20, 10, 2]
                               elsif sec >= 30
                                 [sec - 10,  5, 2]
                               elsif sec >= 5
                                 [sec -  2,  2, 1]
                               end

      sock.setsockopt(:SOL_SOCKET,  :SO_KEEPALIVE,  true)
      sock.setsockopt(:IPPROTO_TCP, xTCP_KEEPIDLE,  idle)
      sock.setsockopt(:IPPROTO_TCP, :TCP_KEEPINTVL, interval)
      sock.setsockopt(:IPPROTO_TCP, :TCP_KEEPCNT,   probes)
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
    :disconnected?

    def initialize(imap_server, authorization, logger)
      @imap_server, @authorization, @logger = imap_server, authorization, logger
      @current_folder = nil
      connect(imap_server, authorization)
    end

    def wait(folder = nil, timeout_sec = 60)
      select(folder || :all) unless @current_folder

      logger.info "[#{self.class}#wait] Enter"
      begin
        logger.info "[#{self.class}#wait] IMAP IDLE start (timeout: #{timeout_sec})"
        @imap.idle(timeout_sec) do |resp|
          logger.info "[#{self.class}#wait] got event #{resp.name} in IMAP IDLE"
          @imap.idle_done
        end
        logger.info "[#{self.class}#wait] IMAP IDLE done"

      # rescue Net::IMAP::Error => e
      #   if e.inspect.include? "connection closed"
      #     reconnect
      #   else
      #     raise
      #   end
      end
      logger.info "[#{self.class}#wait] Exit"
    end # def wait

    private

    def select(folder)
      @current_folder = folder

      if folder == :all
        # select "[Gmail]/All Mail" or localized one like "[Gmail]/すべてのメール"
        folder = @imap.list("", "[Gmail]/*").find {|f| f.attr.include?(:All)}.name
      else
        folder = Net::IMAP.encode_utf7(folder)
      end

      logger.info "[#{self.class}#wait] IMAP Selecting #{Net::IMAP.decode_utf7(folder)}..."
      @imap.select(folder)
      logger.info "[#{self.class}#wait] IMAP Selected #{Net::IMAP.decode_utf7(folder)}"
    end

    def connect(imap_server, authorization)
      logger.info "[#{self.class}#connect] Enter"
      retry_count = 0

      begin
        Timeout.timeout(10) do
          # @imap = Glima::IMAP.new(imap_server, 993, true)
          @imap = Glima::IMAP.new(imap_server, :port => 993, :ssl => {:timeout => 10})

          @imap.authenticate('XOAUTH2',
                             authorization.username,
                             authorization.access_token)
          logger.info "[#{self.class}#connect] connected"
        end
      rescue Timeout::Error, Net::IMAP::NoResponseError => e
        logger.info "[#{self.class}#connect] rescue #{e}"

        if e.inspect.include? "Invalid credentials" && retry_count < 2
          logger.info "[#{self.class}#connect] Refreshing access token for #{imap_server}."
          authorization.refresh!
          retry_count += 1
          retry
        else
          raise
        end
      end
      logger.info "[#{self.class}#connect] Exit"
    end

    # def reconnect
    #   logger.info "[#{self.class}#reconnect] Enter"
    #   connect(@imap_server, @authorization)
    #   logger.info "[#{self.class}#reconnect] Exit"
    # end

    def logger
      @logger
    end

  end # class ImapWatch
end # module Glima

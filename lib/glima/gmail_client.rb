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
    :get_user_label,
    :patch_user_label,

    # Users.messages
    :get_user_message,
    :insert_user_message,
    :list_user_messages,
    :modify_message,
    :trash_user_message,

    # Users.threads
    :get_user_thread,

    # Users getProfile
    :get_user_profile,

    # Non-resources
    :authorization,
    :batch


    def online?
      Socket.getifaddrs.select {|i|
        i.addr.ipv4? and ! i.addr.ipv4_loopback?
      }.map(&:addr).map(&:ip_address).length > 0
    end

    def initialize(config, shell)
      authorizer = Authorizer.new(config.client_id,
                                  config.client_secret,
                                  Google::Apis::GmailV1::AUTH_SCOPE,
                                  config.token_store)

      credentials = authorizer.credentials(config.default_user) ||
                    authorizer.auth_interactively(config.default_user, shell)

      @client = Google::Apis::GmailV1::GmailService.new
      @client.client_options.application_name = 'glima'
      @client.authorization = credentials
      @client.authorization.username = config.default_user # for IMAP
      return @client
    end

    # "[Gmail]/すべてのメール"
    def wait(label = "INBOX")
      @imap ||= Glima::ImapWatch.new("imap.gmail.com", @client.authorization)
      @imap.wait(label)
    end
  end # class GmailClient
end # module Glima

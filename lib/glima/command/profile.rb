module Glima
  module Command
    class Profile < Base

      def initialize
        response = client.get_user_profile('me')
        puts "emailAddress: #{response.email_address}"
        puts "messagesTotal: #{response.messages_total}"
        puts "threadsTotal: #{response.threads_total}"
        puts "historyId: #{response.history_id}"
      end

    end # class Profile
  end # module Command
end # module Glima

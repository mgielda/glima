module Glima
  module Command
    class Label < Base

      def initialize(client, message_id, add, del)
        super(client)

        req = {}
        req[:add_label_ids]    = add.map(&:id) unless add.empty?
        req[:remove_label_ids] = del.map(&:id) unless add.empty?

        if req.empty?
          puts "Do nothing."
          return 0
        end

        req = Google::Apis::GmailV1::ModifyMessageRequest.new(req)

        client.modify_message('me', message_id, req) do |res, err|
          if res
            puts "Update #{message_id} successfully."
          else
            puts "Error: #{err}"
          end
        end
      end

    end # class Label
  end # module Command
end # module Glima

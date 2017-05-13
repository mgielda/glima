module Glima
  module Command
    class Trash < Base

      def initialize(message_ids)

        client.batch do |batch_client|
          message_ids.each do |id|
            batch_client.trash_user_message(id) do |res, err|
              if res
                puts "Trash #{id} successfully."
              else
                puts "Error: #{err}"
              end
            end
          end
        end
      end

    end # class Trash
  end # module Command
end # module Glima

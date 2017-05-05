module Glima
  module Command
    class Guess < Base

      def initialize(client, logger, message_id)
        super(client, logger)

        fmt = "minimal"
        user_label_ids = []

        msg = client.get_user_message('me', message_id, format: fmt)
        thr = client.get_user_thread('me', msg.thread_id, format: fmt)

        thr.messages.each do |tmsg|
          # puts tmsg.snippet
          tmsg.label_ids.each do |label_id|
            next unless label_id =~ /^Label_\d+$/
            user_label_ids << label_id unless user_label_ids.member?(label_id)
            puts "#{tmsg.id} -> #{label_id}"
          end
        end

        user_label_ids.each do |label_id|
          label = client.get_user_label(label_id)
          puts "#{label_id} -> #{label.name}"
        end
      end

    end # class Guess
  end # module Command
end # module Glima

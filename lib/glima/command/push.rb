module Glima
  module Command
    class Push < Base

      def initialize(client, logger, email_file, date, thread, labels)
        super(client, logger)
        label_ids = labels.map(&:id) + ["INBOX", "UNREAD"]

        File.open(email_file) do |source|
          client.insert_user_message(
            'me',
            Google::Apis::GmailV1::Message.new(label_ids: label_ids, thread_id: thread),
            content_type: "message/rfc822",
            internal_date_source: date,
            upload_source: source) do |msg, err|
            if msg
              puts "pushed to: #{msg.id}"
            else
              STDERR.puts "Error: #{err}"
            end
          end
        end
      end

    end # class Push
  end # module Command
end # module Glima

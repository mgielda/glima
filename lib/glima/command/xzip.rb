module Glima
  module Command
    class Xzip < Base
      def initialize(target,
                     add_src_labels: [],
                     del_src_labels: [],
                     add_dst_labels: [],
                     del_dst_labels: [])

        add_src_label_ids = add_src_labels.map(&:id)
        del_src_label_ids = del_src_labels.map(&:id)
        add_dst_label_ids = add_dst_labels.map(&:id)
        del_dst_label_ids = del_dst_labels.map(&:id)

        ids = if target =~ /^[\da-fA-F]{16}$/
                [target]
              else
                client.find_messages(target)
              end

        ids.each do |message_id|
          # get target mail
          logger.info "xzip start #{message_id}"

          mail = client.get_user_smart_message(message_id) do |m, err|
            if err
              logger.error "Error: #{err}"
              next
            end
          end

          unless mail.attachments.map(&:filename).any? {|filename| filename =~ /\.zip$/i}
            logger.info "xzip skip #{message_id} - has no zip attachments"
            next
          end

          # find password candidates from nearby mails
          password_candidates = []
          client.nearby_mails(mail) do |nm|
            logger.info "Passwordish mail: " + nm.format_summary
            password_candidates += nm.find_passwordish_strings
          end

          # try to unlock zip attachments
          unless mail.unlock_zip!(password_candidates, logger)
            logger.info "Password unlock failed."
            next
          end

          # push back unlocked mail to server
          unless push_mail(mail, "dateHeader", add_dst_label_ids, del_dst_label_ids)
            logger.info "Push mail failed."
            next
          end

          # add/remove labels from the target
          if add_src_label_ids.empty? && del_src_label_ids.empty?
            next
          end

          req = {}
          req[:add_label_ids]    = add_src_label_ids
          req[:remove_label_ids] = del_src_label_ids

          req = Google::Apis::GmailV1::ModifyMessageRequest.new(req)

          client.modify_message('me', message_id, req) do |res,err|
            if res
              puts "Update #{message_id} successfully."
            else
              puts "Error: #{err}"
            end
          end
        end
      end # def initialize

      private

      def push_mail(mail, date_source = "receivedTime", add_label_ids = [], del_label_ids = [])
        label_ids = (mail.label_ids +
                     add_label_ids  -
                     del_label_ids  +
                     ["INBOX", "UNREAD"]).uniq
        thid = mail.thread_id

        unless date_source == "dateHeader" || date_source == "receivedTime"
          raise "Unknown date type: #{date_source}"
        end

        mail.header["X-Glima-Processed"] = DateTime.now.rfc2822

        client.insert_user_message(
          'me',
          Google::Apis::GmailV1::Message.new(label_ids: label_ids, thread_id: thid),
          content_type: "message/rfc822",
          internal_date_source: date_source,
          upload_source: StringIO.new(mail.to_s)) do |msg, err|
          if msg
            puts "pushed to: #{msg.id}"
            return true
          else
            STDERR.puts "Error: #{err}"
            return false
          end
        end
      end

    end # class Xzip
  end # module Command
end # module Glima

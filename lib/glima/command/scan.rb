module Glima
  module Command
    class Scan < Base

      def initialize(folder, format, search_or_range)

        index = 1
        client.scan_batch(folder, search_or_range, true) do |mail|
          case format
          when :mew
            puts mail.format_mew(index)
          when :archive
            puts format_archive_friendly(mail)
          when :legible
            puts format_legible(mail)
          else
            puts mail.format_summary(index)
          end
          index += 1
        end
      end

      private

      def format_archive_friendly(mail)
        date = mail.date.strftime("%Y-%m-%d-%H%M%S")
        # Replace unsafe chars for filename
        subject = mail.subject.tr('!/:*?"<>|\\', '！／：＊？″＜＞｜＼').gsub(/[\s　]/, '')
        return "#{mail.id} #{date}-#{mail.id}-#{subject}.eml"
      end

      def format_legible(mail)
        date = mail.date.strftime("%Y-%m-%d-%H%M%S")
        # Remove delim char
        subject = mail.subject.tr('|', '')

        return "#{mail.id}|#{date}|#{mail.subject}|#{mail.header['from']}|#{mail.header['to']}"
      end

    end # class Scan
  end # module Command
end # module Glima

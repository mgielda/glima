require "mail"

module Glima
  module Resource
    class Mail < ::Mail::Message

      def to_plain_text
        mail = self
        parts = if mail.multipart? then mail.parts else [mail] end

        body = parts.map do |part|
          if part.content_type =~ /text\/plain/
            charset = part.content_type_parameters["charset"]
            convert_to_utf8(part.body.decoded.to_s, charset)
          else
            "NOT_TEXT_PART (#{part.content_type})\n"
          end
        end.join("-- PART ---- PART ---- PART ---- PART ---- PART --\n")

        return pretty_hearder + "\n" + body
      end

      def find_passwordish_strings
        mail = self
        body = mail.to_plain_text

        password_candidates = []

        # gather passwordish ASCII strings.
        body.scan(/(?:^|[^!-~])([!-~]{4,16})[^!-~]/) do |str|
          password_candidates += str
        end
        return password_candidates
      end

      private

      def convert_to_utf8(string, from_charset = nil)
        if from_charset && from_charset != "utf-8"
          string.encode("utf-8", from_charset,
                        :invalid => :replace, :undef => :replace)
        else
          string.force_encoding("utf-8")
        end
      end

      def pretty_hearder
        mail = self
        ["Subject: #{mail.subject}",
         "From: #{mail.header['from']&.decoded}",
         "Date: #{mail.header['date']}",
         "Message-Id: #{mail.header['message_id']}",
         "To: #{mail.header['to']&.decoded}",
         "Cc: #{mail.header['cc']&.decoded}"
        ].join("\n") + "\n"
      end
    end # class Mail
  end # module Resource
end # module Glima

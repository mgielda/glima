require "mail"
require 'forwardable'

module Glima
  module Resource
    class Mail < ::Mail::Message
      extend Forwardable

      def_delegators :@gmail_message,
      # Users.histoy
      :internal_date,
      :snippet

      def self.read(mail_filename)
        new(File.open(filename, 'rb') {|f| f.read })
      end

      def initialize(message)
        @gmail_message = message
        super(message.raw)
      end

      def gm_msgid
        @gmail_message.id
      end
      alias_method :id, :gm_msgid

      def gm_thrid
        @gmail_message.thread_id
      end
      alias_method :thread_id, :gm_thrid

      def gm_label_ids
        @gmail_message.label_ids
      end
      alias_method :label_ids, :gm_label_ids

      def raw
        @gmail_message.raw
      end

      def to_plain_text
        mail = self
        parts = if mail.multipart? then mail.parts else [mail] end

        body = parts.map do |part|
          part_to_plain_text(part)
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

      def part_to_plain_text(part)
        case part.content_type
        when /text\/plain/
          convert_to_utf8(part.body.decoded.to_s,
                          part.content_type_parameters["charset"])
        when /multipart\/alternative/
          part_to_plain_text(part.text_part)
        else
          "NOT_TEXT_PART (#{part.content_type})\n"
        end
      end

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

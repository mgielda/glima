module Glima
  module Resource
    class Message < Base

      def dump
        dump_message(@raw_resource)
      end

      private
      def dump_message(msg, indent = 0)
        str1 = <<-EOF.indent_heredoc(indent)
          id: #{msg.id}
          threadId: #{msg.thread_id}
          labelIds: #{msg.label_ids&.join(', ')}
          snippet: #{msg.snippet&.slice(0..20)}...
          historyId: #{msg.history_id}
          internalDate: #{msg.internal_date}
          sizeEstimate: #{msg.size_estimate}
          payload:
        EOF
        str1 += dump_message_part(msg.payload, indent + 2)

        str2 = <<-EOF.indent_heredoc(indent)
          raw:
        EOF
        str2 += (msg.raw.force_encoding("UTF-8")) if msg.raw
        return str1 + str2
      end

      def dump_message_part(part, indent)
        return (" " * indent) + "part is NULL\n" unless part

        str1 = <<-EOF.indent_heredoc(indent)
          partId: #{part.part_id}
          mimeType: #{part.mime_type}
          filename: #{part.filename}
          headers: #{dump_message_headers(part.headers)}
          body:
        EOF
        str1 += dump_message_attachment(part.body, indent + 2) if part.body

        str2 = <<-EOF.indent_heredoc(indent)
          parts:
        EOF
        str2 += dump_message_parts(part.parts, indent + 2)

        return str1 + str2
      end

      def dump_message_headers(headers, all = nil)
        return "headers is empty" unless headers
        str = headers.map{|h| h.name + ": " + h.value}.join("\n")
        return str if all
        return str.split("\n").first
      end

      def dump_message_parts(parts, indent = 0)
        return (' ' * indent) + "parts is empty\n" unless parts
        return parts.map{|p| dump_message_part(p, indent)}.join("\n") + "\n"
      end

      def dump_message_body(body, indent)
        str = <<-EOF.indent_heredoc(indent)
          attachmentId: #{(body.attachment_id.to_s)[0..20]}
          size: #{body&.size}
          data: #{if body.data then body.data.force_encoding("UTF-8")&.gsub(/\r?\n/, "")[0..20] else 'NULL' end}...
        EOF
        return str
      end
      alias_method :dump_message_attachment, :dump_message_body

    end # class Message
  end # module Resource
end # module Glima

module Glima
  module Resource
    class Label < Base

      def dump
        label = @raw_resource
        str =
          "id: #{label.id}\n" +
          "name: #{label.name}\n" +
          "messageListVisibility: #{label.message_list_visibility}\n" +
          "labelListVisibility: #{label.label_list_visibility}\n" +
          "type: #{label.type}\n" +
          "messagesTotal: #{label.messages_total}\n" +
          "messagesUnread: #{label.messages_unread}\n" +
          "threadsTotal: #{label.threads_total}\n" +
          "threadsUnread: #{label.threads_unread}\n"
        return str
      end

    end # class Label
  end # module Resource
end # modlue Glima

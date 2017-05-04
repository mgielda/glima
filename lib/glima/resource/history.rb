module Glima
  module Resource
    class History < Base

      def dump
        h = @raw_resource

        str = ""
        types = []

        msgs = h.messages
        str += "** Messages: (#{msgs.length})\n"
        msgs.each do |m|
          str += Message.new(m).dump
        end

        if msgs = h.messages_added
          types << :messages_added
          str += "** Messages Added (#{msgs.length}):\n"
          msgs.map(&:message).each do |m|
            str += Message.new(m).dump
          end
        end

        if msgs = h.messages_deleted
          types << :messages_deleted
          str += "** Messages Deleted (#{msgs.length}):\n"
          msgs.map(&:message).each do |m|
            str += Message.new(m).dump
          end
        end

        if msgs = h.labels_added
          types << :labels_added
          str += "** Labels Added (#{msgs.length}):\n"
          h.labels_added.each do |lm|
            str += Message.new(lm.message).dump
            str += "   label_ids: " + lm.label_ids.join(',')
          end
        end

        if msgs = h.labels_removed
          types << :labels_removed
          str += "** Labels Removed (#{msgs.length}):\n"
          h.labels_removed.each do |lm|
            str += Message.new(lm.message).dump
            str += "   label_ids: " + lm.label_ids.join(',')
          end
        end

        return "* Id: #{h.id}, types: " + types.join(",") + "\n" + str
      end

    end # class History
  end # module Resource
end # modlue Glima

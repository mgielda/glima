module Glima
  module Resource
    class History < Base
      class Event
        attr_reader :history_id, :message, :type, :label_ids

        def initialize(history_id:, message:, type:, label_ids: nil)
          @history_id, @message, @type, @label_ids = history_id, message, type, label_ids
        end

        def dump
          str = "history: #{history_id}, messgae: #{message.id}, type: #{type}"
          str += ", label_ids: #{label_ids.join(',')}" if label_ids
          str
        end
      end

      # Single history entry will be converted to multiple events
      def to_events
        events = []
        h = @raw_resource
        id = h.id

        h.messages_added.each do |ent|
          events << Event.new(history_id: id, message: ent.message, type: :added)
        end if h.messages_added

        h.messages_deleted.each do |ent|
          events << Event.new(history_id: id, message: ent.message, type: :deleted)
        end if h.messages_deleted

        h.labels_added.each do |ent|
          events << Event.new(history_id: id, message: ent.message, type: :labels_added, label_ids: ent.label_ids)
        end if h.labels_added

        h.labels_removed.each do |ent|
          events << Event.new(history_id: id, message: ent.message, type: :labels_removed, label_ids: ent.label_ids)
        end if h.labels_removed

        return events
      end

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

module Glima
  module Command
    class Watch < Base

      def initialize(client, queue_label = nil, mark_label = nil)
        super(client)

        # Watch "[Gmail]/All Mail" by IMAP idle
        client.watch(nil) do |ev|
          next unless ev.type == :added

          # Scan messages in queue_label or new message itself.
          #
          # If Xzip process is successful, remove queue_label
          # from the source message.
          #
          if queue_label
            target      = "label:#{queue_label.name}"
            target     += " -label:#{mark_label.name}" if mark_label
            del_labels  = [queue_label]
          else
            target      = ev.message.id
            del_labels  = []
          end

          # Also, mark_label will be added to the xzipped message.
          # It is for avoidance of infinite loop.
          #
          if mark_label
            add_labels = [mark_label]
          else
            add_labels = []
          end

          logger.info "Xzip #{target}"

          Glima::Command::Xzip.new(client, logger, target,
                                   add_dst_labels: add_labels,
                                   del_dst_labels: del_labels,
                                   del_src_labels: del_labels)
        end
      end

    end # class Watch
  end # module Command
end # module Glima

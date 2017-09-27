module Glima
  module Command
    class Watch < Base

      def initialize(queue_label = nil, mark_label = nil)
        # If xzip is successful,
        #   remove queue_label from the original message, also
        #   add mark_label to the xzipped message.
        #
        add_labels, del_labels = [], []
        add_labels << mark_label  if mark_label
        del_labels << queue_label if queue_label

        # if queue_label is set, xzip process scan search zip-attached
        # messages with queue_label, without mark_label
        #
        if queue_label
          target = "label:#{queue_label.name}"
          target += " -label:#{mark_label.name}" if mark_label
        end

        # Cleanup queue before watching imap events.
        Glima::Command::Xzip.new(target,
                                 add_dst_labels: add_labels,
                                 del_dst_labels: del_labels,
                                 del_src_labels: del_labels)

        # Watch "[Gmail]/All Mail" by IMAP idle
        # XXX: IMAP idle does not have timeout mechanism,
        #      should add timer thread to refresh imap connection.
        #
        client.watch(queue_label) do |ev|
          # next unless ev.type == :added

          logger.info "xzip #{target}"

          target ||= ev.message.id
          Glima::Command::Xzip.new(target,
                                   add_dst_labels: add_labels,
                                   del_dst_labels: del_labels,
                                   del_src_labels: del_labels)
        end
      end

    end # class Watch
  end # module Command
end # module Glima

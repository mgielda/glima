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
        logger.info "xzip #{target}"
        Glima::Command::Xzip.new(target,
                                 add_dst_labels: add_labels,
                                 del_dst_labels: del_labels,
                                 del_src_labels: del_labels)

        # Watch "[Gmail]/All Mail" by IMAP idle

        timestamp = Time.now

        client.watch(queue_label) do |ev|
          # avoid burst events
          next if Time.now - timestamp < 3

          logger.info "xzip #{target}"

          target ||= ev.message.id
          Glima::Command::Xzip.new(target,
                                   add_dst_labels: add_labels,
                                   del_dst_labels: del_labels,
                                   del_src_labels: del_labels)
          timestamp = Time.now
        end
      end

    end # class Watch
  end # module Command
end # module Glima

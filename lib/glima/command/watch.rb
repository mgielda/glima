module Glima
  module Command
    class Watch < Base

      def initialize(queue_label = nil, mark_label = nil, default_passwords = [])
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
        logger.info "xzip cleanup queue before watching imap events #{target}."
        Glima::Command::Xzip.new(target, default_passwords,
                                 add_dst_labels: add_labels,
                                 del_dst_labels: del_labels,
                                 del_src_labels: del_labels)

        # Watch "[Gmail]/All Mail" by IMAP idle

        timestamp = Time.now

        logger.info "[#{self.class}#initialize] Entering GmailClient#watch"
        client.watch do |ev|
          # avoid burst events
          next if Time.now - timestamp < 3

          logger.info "[#{self.class}#initialize] xzip #{target} in event loop."

          target ||= ev.message.id
          Glima::Command::Xzip.new(target, default_passwords,
                                   add_dst_labels: add_labels,
                                   del_dst_labels: del_labels,
                                   del_src_labels: del_labels)
          timestamp = Time.now
        end
        logger.info "[#{self.class}#initialize] Done (not reached)"
      end

    end # class Watch
  end # module Command
end # module Glima

module Glima
  module Command
    class Watch < Base

      def initialize(client, logger, label = nil)
        super(client, logger)

        label = parse_label_names(label).first

        client.watch(label) do |ev|
          target = if label then "label:#{label.name}" else ev.message.id end
          logger.info "Xzip #{target}"
          Glima::Command::Xzip.new(client, logger, target,
                                   add_dst_labels: parse_label_names("glima/decrypted"),
                                   del_dst_labels: parse_label_names("glima/queue"),
                                   del_src_labels: parse_label_names("glima/queue"))
        end
      end

    end # class Watch
  end # module Command
end # module Glima

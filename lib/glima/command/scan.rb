module Glima
  module Command
    class Scan < Base

      def initialize(folder, format, search_or_range)

        index = 1
        client.scan_batch(folder, search_or_range) do |mail|
          if format == :mew
            puts mail.format_mew(index)
          else
            puts mail.format_summary(index)
          end
          index += 1
        end
      end

    end # class Scan
  end # module Command
end # module Glima

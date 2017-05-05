module Glima
  module Command
    class Base

      def initialize(client, logger)
        @client = client
        @logger = logger
      end

      private

      def logger
        @logger
      end

      def client
        @client
      end

      def exit_if_error(message, error, logger)
        return true unless error
        logger.error "#{error.message.split(':').last.strip} #{message}."
        exit 1
      end

    end # class Scan
  end # module Command
end # module Glima

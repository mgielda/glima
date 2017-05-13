module Glima
  module Command
    class Labels < Base

      def initialize(client, verbose = nil)
        super(client)

        labels = client.labels

        if labels.empty?
          puts 'No labels found'
          return 0
        end

        total = labels.length

        unless verbose
          labels.sort_by(&:name).each do |label|
            puts "#{label.name}"
          end
          return 0
        end

        # Gmail API has rate limit at 250 requests/seccond/user (deps on type of method)
        # https://developers.google.com/gmail/api/v1/reference/quota
        # labels.get consumes 1quota unit
        # It is only an experiment, not practical...
        #
        # how to retry batch requests? Issue #444 google/google-api-ruby-client
        # https://github.com/google/google-api-ruby-client/issues/444
        # Setting default option should also work, but it has to be done before the service is created.
        #
        # Retries on individual operations within a batch isn't yet
        # supported. It's a bit complicated to do that correctly
        # (e.g. extract the failed requests/responses, build a new batch,
        # retry, repeat... merge all the results...)
        #
        # I'd caution against using retries with batches unless you know
        # the operations are safe to repeat. Since the entire batch is
        # repeated, you may be replaying successful operations as part of
        # it.
        #
        index = 1
        labels.each_slice(100) do |chunk|
          client.batch do |batch_client|
            chunk.each do |lbl|
              batch_client.get_user_label(lbl.id) do |label, err|
                if label
                  puts "--- #{index}/#{total} -------------------------------------------------"
                  puts Glima::Resource::Label.new(label).dump
                  index += 1
                else
                  puts "Error: #{err}"
                end
              end
            end # chunk
          end # batch
          sleep 1
        end # slice
      end

    end # class Labels
  end # module Command
end # module Glima

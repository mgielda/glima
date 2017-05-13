module Glima
  module Command
    class Dezip < Base

      def initialize(gmail_id, directory, password_file = nil, password_dir = nil)

        unless File.writable?(File.expand_path(directory))
          logger.error "#{directory} is not writable."
          exit 1
        end

        mail = client.get_user_smart_message(gmail_id) do |m, err|
          exit_if_error(gmail_id, err, logger)
        end

        # get password candidates from config file
        password_candidates = []
        if File.exists?(password_file)
          password_candidates += File.open(password_file) {|f| f.read.split(/\n+/) }
        end

        # gather password candidates from nearby mails
        client.nearby_mails(mail) do |nm|
          logger.info "Passwordish mail: " + nm.format_summary
          password_candidates += nm.find_passwordish_strings
        end

        # try to unlock zip attachments
        unless mail.unlock_zip!(password_candidates, logger)
          logger.info "Password unlock failed."
          return false
        end

        # Write to unlocked zip file to DIRECTORY
        mail.attachments.each do |attachment|
          next unless attachment.filename =~ /\.zip$/i
          zip_filename = File.expand_path(attachment.filename, directory)
          Glima::Zip.new(attachment.body.decoded).write_to_file(zip_filename)
          logger.info "Wrote to #{zip_filename || 'STDOUT'}."
        end
      end

    end # class Dezip
  end # module Command
end # module Glima

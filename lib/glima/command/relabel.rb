module Glima
  module Command
    class Relabel < Base

      def initialize(source_name, dest_name, dry_run)

        all_labels = client.list_user_labels('me').labels.sort_by(&:name)

        if /\/$/ =~ dest_name
          move_to_dir = true
          dest_name = dest_name.sub(/\/$/, '')
        else
          move_to_dir = false
        end

        source_labels = all_labels.find_all {|x| File.fnmatch(source_name, x.name, File::FNM_PATHNAME)}
        dest_label    = all_labels.find {|x| x.name == dest_name}

        if source_labels.empty?
          puts "Error: source #{source_name} not found"
          return nil
        end

        if dest_label && !move_to_dir
          puts "Error: dest #{dest_name} already exists"
          return nil
        end

        if !dest_label && move_to_dir
          puts "Error: dest #{dest_name} not found"
          return nil
        end

        source_labels.each do |source_label|
          dirtop = File.dirname(source_label.name)
          sub_labels = all_labels.find_all {|x| File.fnmatch(source_label.name + '/*', x.name)}

          ([source_label] + sub_labels).each do |label|
            src = label.name
            dst = dest_name + '/' + (label.name.sub(/^#{dirtop}\//, ''))

            if all_labels.find {|x| x.name == dst}
              puts "Error: relabel #{src} -> #{dst}: Destination already exists"
              next
            else
              puts "relabel #{src} -> #{dst}"
            end

            unless dry_run
              label_obj = Google::Apis::GmailV1::Label.new(id: label.id, name: dst)
              client.patch_user_label('me', label.id, label_obj) do |response, err|
                if response
                  # puts dump_label(response)
                else
                  puts "Error: #{err}"
                end
              end
            end
          end
        end
      end

    end # class Relabel
  end # module Command
end # module Glima

require "zip"
require "base64"

module Glima
  class Zip
    attr_accessor :password

    def initialize(zip_content, password = nil)
      @zip_string = if zip_content.is_a?(String)
                      zip_content
                    else
                      File.open(zip_content).read
                    end
      @password = password
    end

    def correct_password?(password)
      with_input_stream(password) do |zip|
        return false unless entry = zip.get_next_entry

        begin
          size = zip.read.size # Exception if invalid password
        rescue Zlib::DataError => e
          puts "*** #{e} ***" if $DEBUG
          return false
        end

        # no Exception emitted, but size is invalid.
        return (size == entry.size)
      end
    end

    def encrypted?
      correct_password?(nil)
    end

    def write_to_file(file)
      return file.write(@zip_string) if file.respond_to?(:write)

      File.open(file, "w") do |f|
        f.write(@zip_string)
      end
    end

    def to_s
      @zip_string
    end

    def to_base64
      Base64.encode64(@zip_string)
    end

    def to_decrypted_unicode_zip()
      ::Zip.unicode_names = true

      out = ::Zip::OutputStream.write_buffer(StringIO.new) do |zos|
        with_input_stream(@password) do |zis|
          while entry = zis.get_next_entry
            name = cp932_path_to_utf8_path(entry.name)

            # Two types of Exception will occur on encrypted zip:
            #  1) "invalid block type (Zlib::DataError)" if password is not specified.
            #  2) "invalid stored block lengths (Zlib::DataError)" if password is wrong.
            content = zis.read
            raise Zlib::DataError if content.size != entry.size

            zos.put_next_entry(name)
            zos.write(content)
          end
        end
      end
      Zip.new(out.string)
    end

    private

    def with_input_stream(password = nil, &block)
      ::Zip::InputStream.open(StringIO.new(@zip_string), 0, decrypter(password)) do |zis|
        yield zis
      end
    end

    def decrypter(password = nil)
      password ? ::Zip::TraditionalDecrypter.new(password) : nil
    end

    # 1) Convert CP932 (SJIS) to UTF8.
    # 2) Replace path-separators from backslash (\) to slash (/).
    #
    # Example:
    #   path = io.get_next_entry.name # rubyzip returns ASCII-8BIT string as name.
    #   path is:
    #    + ASCII-8BIT
    #    + Every backslash is replaced to '/' even in second-byte of CP932.
    #
    # See also:
    #   https://github.com/rubyzip/rubyzip/blob/master/lib/zip/entry.rb#L223
    #   Zip::Entry#read_local_entry does gsub('\\', '/')
    #
    def cp932_path_to_utf8_path(cp932_path_string)
      # Replace-back all '/' to '\'
      name = cp932_path_string.force_encoding("BINARY").gsub('/', '\\')

      # Change endoding to CP932 (SJIS) and replace all '\' to '/'
      # In this replacement, '\' in second-byte of CP932 will be preserved.
      name = name.force_encoding("CP932").gsub('\\', '/')

      # Convert CP932 to UTF-8
      return name.encode("utf-8", "CP932",
                         :invalid => :replace, :undef => :replace)
    end

  end # class Zip
end # module Glima

__END__

  def decrypted_utf8_zip(zipped_string, output = nil, password = nil)
    Zip.unicode_names = true

    decrypter = password ? Zip::TraditionalDecrypter.new(password) : nil

    outstream = if output.respond_to?(:write)
                  output # IO, StringIO or File
                elsif output.is_a?(String)
                  File.open(output, "w") # filename
                else
                  StringIO.new('') # nil
                end

    out = Zip::OutputStream.write_buffer(outstream) do |zos|
      Zip::InputStream.open(StringIO.new(zipped_string), 0, decrypter) do |zis|
        while entry = zis.get_next_entry
          name = cp932_path_to_utf8_path(entry.name)

          # Two types of Exception will occur on encrypted zip:
          #  1) "invalid block type (Zlib::DataError)" if password is not specified.
          #  2) "invalid stored block lengths (Zlib::DataError)" if password is wrong.
          content = zis.read

          raise Zlib::DataError if content.size != entry.size

          STDERR.puts "- Name: #{name}"
          zos.put_next_entry(name)
          zos.write(content)
        end
      end
    end
    return out.string if out.respond_to?(:string)
  end

require "zip"
require "base64"

module Glima
  class Zip
    attr_accessor :password

    def self.read(zip_filename, password = "")
      new(File.open(File.expand_path(zip_file)).read, password)
    end

    def initialize(zip_string, password = "")
      @zip_string = zip_string
      @password = password
    end

    def correct_password?(password)
      with_input_stream(password) do |zip|
        begin
          # Looking the first entry is not enough, because
          # some zip files have directory entry which size is zero
          # and no error is emitted even with wrong password.
          while entry = zip.get_next_entry
            size = zip.read.size # Exception if invalid password
            return false if size != entry.size
            return true  if size > 0 # short cut
          end
        rescue Zlib::DataError => e
          puts "*** #{e} ***" if $DEBUG
          return false
        end

        # False-positive if all files are emtpy.
        return true
      end
    end

    def unlock_password!(password_candidates, logger = nil)
      list = sort_by_password_strength(password_candidates.uniq).unshift("")

      list.each do |password|
        msg = "Try password:'#{password}' (#{password_strength(password)})..."

        if correct_password?(password)
          logger.info(msg + " OK.") if logger
          @password = password
          return password # Found password
        else
          logger.info(msg + " NG.") if logger
        end
      end
      return nil # No luck
    end

    def encrypted?
      correct_password?("")
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

    def password_strength(password)
      password = password.to_s
      score = Math.log2(password.length + 1)

      password.scan(/[a-z]+|[A-Z]+|\d+|[!"#$%&'()*+,-.\/:;<=>?@\[\\\]^_`{|}~]+/) do |s|
        score += 1.0
      end
      return score
    end

    def sort_by_password_strength(password_array)
      password_array.sort{|a,b|
        password_strength(b) <=> password_strength(a)
      }
    end

    def with_input_stream(password = "", &block)
      ::Zip::InputStream.open(StringIO.new(@zip_string), 0, decrypter(password)) do |zis|
        yield zis
      end
    end

    def decrypter(password = "")
      if password.empty?
        nil # return empty decrypter
      else
        ::Zip::TraditionalDecrypter.new(password)
      end
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

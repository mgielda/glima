require "fileutils"
require "pathname"

module Glima
  class DataStore

    def initialize(basedir)
      unless basedir and File.directory?(File.expand_path(basedir.to_s))
        raise Glima::ConfigurationError, "datastore directory '#{basedir}' not found"
      end
      @basedir = Pathname.new(File.expand_path(basedir))
    end

    def update(message)
      if message.raw
        save(message)
      else
        message.raw = load(message)
      end
      return message
    end

    def save(message)
      path = folder_message_to_path("+all", message.id)
      File.open(path, "w") do |f|
        f.write(message.raw.gsub("\r\n", "\n"))
      end
    end

    def load(message)
      path = folder_message_to_path("+all", message.id)
      return File.open(path).read
    end

    def exist?(message_id)
      File.exist?(folder_message_to_path("+all", message_id))
    end

    ################################################################
    private

    def folder_to_directory(folder)
      folder = folder.sub(/^\+/, "")
      File.expand_path(folder, "~/Mail")
    end

    def save_message_in_id(message, folder)
      directory = folder_to_directory(folder)

      raise "Error: #{directory} not exist" unless File.exist?(directory)

      # name =  message.thread_id + "-" + message.id
      name =  message.id + ".eml"
      filename = File.expand_path(name, directory)

      File.open(filename, "w") do |f|
        f.write(message.raw.gsub("\r\n", "\n"))
      end
      return message.id
    end

    def folder_message_to_path(folder, message_id = nil)
      folder = folder.sub(/^\+/, "")
      directory = File.expand_path(folder, @basedir)
      return directory unless message_id
      return File.expand_path(message_id + ".eml", directory)
    end

  end # class DataStore
end # module Glima

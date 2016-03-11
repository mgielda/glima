require "fileutils"
require "pathname"

module Glima
  class Context

    def initialize(basedir)
      unless basedir and File.directory?(File.expand_path(basedir.to_s))
        raise Glima::ConfigurationError, "datastore directory '#{basedir}' not found"
      end
      @basedir = Pathname.new(File.expand_path(basedir))
    end

    def save_page_token(token)
      File.open(page_token_path, "w") do |f|
        f.write(token)
      end
    end

    def load_page_token
      File.open(page_token_path).read.to_s
    end

    ################################################################
    private

    def page_token_path
      File.expand_path("page_token.context", @basedir)
    end

  end # class Context
end # module Glima

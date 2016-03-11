class String
  def indent_heredoc(indent = 0)
    strip_heredoc.gsub(/^/, ' ' * indent)
  end

  def strip_heredoc
    indent = scan(/^[ \t]*(?=\S)/).min.size rescue 0
    gsub(/^[ \t]{#{indent}}/, '')
  end
end

module Glima
  module Resource
    class ParseError < StandardError; end

    class Base
      def initialize(raw_resource)
        @raw_resource = raw_resource
      end
    end

    dir = File.dirname(__FILE__) + "/resource"

    autoload :History,             "#{dir}/history.rb"
    autoload :Label,               "#{dir}/label.rb"
    autoload :Message,             "#{dir}/message.rb"
    autoload :Thread,              "#{dir}/thread.rb"
    autoload :User,                "#{dir}/user.rb"
  end # modlue Resource
end # module Glima

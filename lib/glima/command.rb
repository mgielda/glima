module Glima
  module Command

    def self.logger
      @logger
    end

    def self.client
      @client
    end

    class << self
      attr_writer :logger, :client
    end

    dir = File.dirname(__FILE__) + "/command"

    autoload :Base,        "#{dir}/base.rb"
    autoload :Dezip,       "#{dir}/dezip.rb"
    # autoload :Events,      "#{dir}/events.rb"
    autoload :Guess,       "#{dir}/guess.rb"
    autoload :Label,       "#{dir}/label.rb"
    autoload :Labels,      "#{dir}/labels.rb"
    autoload :Init,        "#{dir}/init.rb"
    # autoload :Open,        "#{dir}/open.rb"
    autoload :Profile,     "#{dir}/profile.rb"
    autoload :Push,        "#{dir}/push.rb"
    autoload :Relabel,     "#{dir}/relabel.rb"
    autoload :Scan,        "#{dir}/scan.rb"
    # autoload :Show,        "#{dir}/show.rb"
    autoload :Trash,       "#{dir}/trash.rb"
    autoload :Watch,       "#{dir}/watch.rb"
    autoload :Xzip,        "#{dir}/xzip.rb"

  end # module Command
end # module Glima

require "thor"

module Glima
  class Cli < Thor
    ################################################################
    # config files

    CONFIG_HOME = File.join((ENV["XDG_CONFIG_HOME"] || "~/.config"), basename)
    CONFIG_FILE = "config.yml"
    CONFIG_PATH = File.join(CONFIG_HOME, CONFIG_FILE)

    def self.config_home ; CONFIG_HOME; end
    def self.config_path ; CONFIG_PATH; end

    ################################################################
    # register preset options

    def self.named_option(name, options)
      @named_options ||= {}
      @named_options[name] = options
    end

    def self.expand_option(*names)
      expand_named_option(:method, *names)
    end

    def self.expand_class_option(*names)
      expand_named_option(:class, *names)
    end

    def self.expand_named_option(type, *names)
      names.each do |name|
        options = @named_options[name]
        if type == :class
          class_option name, options
        else
          method_option name, options
        end
      end
    end
    private_class_method :expand_named_option

    named_option :debug,   :desc => "Set debug flag", :type => :boolean
    named_option :profile, :desc => "Set profiler flag", :type => :boolean
    named_option :config,  :desc => "Set config path (default: #{CONFIG_PATH})", :banner => "FILE"
    named_option :dry_run, :desc => "Perform a trial run with no changes made", :type => :boolean

    ################################################################
    # command name mappings

    map ["--version", "-v"] => :version

    map ["--help", "-h"] => :help

    default_command :help

    ################################################################
    # Command: help
    ################################################################

    desc "help [COMMAND]", "Describe available commands or one specific command"

    def help(command = nil)
      super(command)
    end

    ################################################################
    # Command: version
    ################################################################
    desc "version", "Show version"

    def version
      puts Glima::VERSION
    end

    ################################################################
    # Command: completions
    ################################################################
    check_unknown_options! :except => :completions

    desc "completions [COMMAND]", "List available commands or options for COMMAND", :hide => true

    long_desc <<-LONGDESC
      List available commands or options for COMMAND
      This is supposed to be a zsh compsys helper"
    LONGDESC

    def completions(*command)
      help = self.class.commands
      global_options = self.class.class_options
      Glima::Command::Completions.new(help, global_options, command, config)
    end

    ################################################################
    # add some hooks to Thor

    no_commands do
      def invoke_command(command, *args)
        setup_global_options unless command.name == "init"
        result = super
        teardown
        result
      end
    end

    ################################################################
    # private

    private

    def exit_on_error(&block)
      begin
        yield if block_given?
      rescue Glima::ConfigurationError => e
        STDERR.print "ERROR: #{e.message}.\n"
        exit 1
      end
    end

    attr_reader :builder, :config, :client, :context, :datastore

    def setup_global_options
      exit_on_error do
        if options[:profile]
          require 'profiler'
          Profiler__.start_profile
        end
        if options[:debug]
          require "pp"
          $GLIMA_DEBUG = true
          $GLIMA_DEBUG_FOR_DEVELOPER = true if ENV["GLIMA_DEBUG_FOR_DEVELOPER"]
        end
      end
    end

    def load_plugins
      config_path = options[:config] || CONFIG_PATH
      plugin_dir  = File.dirname(config_path)

      Dir.glob(File.expand_path("plugins/*.rb", plugin_dir)) do |rb|
        require rb
      end
    end

    def teardown
      if options[:profile]
        Profiler__.print_profile($stdout)
      end
    end
  end
end

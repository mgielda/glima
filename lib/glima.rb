module Glima
  # Your code goes here...
  class ConfigurationError < StandardError ; end

  dir = File.dirname(__FILE__) + "/glima"

  autoload :Cli,                  "#{dir}/cli.rb"
  autoload :Config,               "#{dir}/config.rb"
  autoload :Context,              "#{dir}/context.rb"
  autoload :DataStore,            "#{dir}/datastore.rb"
  autoload :GmailClient,          "#{dir}/gmail_client.rb"
  autoload :QueryParameter,       "#{dir}/query_parameter.rb"
  autoload :Resource,             "#{dir}/resource.rb"
  autoload :VERSION,              "#{dir}/version.rb"
end

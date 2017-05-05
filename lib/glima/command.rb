module Glima
  module Command

    dir = File.dirname(__FILE__) + "/command"

    autoload :Xzip,        "#{dir}/xzip.rb"

  end # module Command
end # module Glima

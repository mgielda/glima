# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
git = File.expand_path('../.git', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'glima/version'

Gem::Specification.new do |spec|
  spec.name          = "glima"
  spec.version       = Glima::VERSION
  spec.authors       = ["Yoshinari Nomura"]
  spec.email         = ["nom@quickhack.net"]
  spec.summary       = %q{Gmail CLI client}
  spec.description   = %q{Gmail CLI client}
  spec.homepage      = "https://github.com/yoshinari-nomura/glima"
  spec.license       = "MIT"

  spec.files         = if Dir.exist?(git)
                         `git ls-files -z`.split("\x0")
                       else
                         Dir['**/*']
                       end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.3.0"

  spec.add_runtime_dependency "thor", ">= 0.19.1"
  spec.add_runtime_dependency "clian", ">= 0.4.0"
  spec.add_runtime_dependency "mail"
  spec.add_runtime_dependency "rubyzip"

  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end

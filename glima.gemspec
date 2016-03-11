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
  spec.summary       = %q{}
  spec.description   = %q{}
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

  spec.add_runtime_dependency "thor", ">= 0.19.1"
  spec.add_runtime_dependency "google-api-client", "0.9.pre4"
  spec.add_runtime_dependency "googleauth"
  spec.add_runtime_dependency "launchy"
  spec.add_runtime_dependency "mail"

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end

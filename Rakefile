require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)



namespace :docker do
  tag = "nom4476/glima"

  desc "Build Docker image from Dockerfile"
  task :build do
    version = Glima::VERSION
    system "docker build --build-arg GLIMA_VERSION=#{version} -t #{tag} ."
  end

  desc "Push current Docker image to Docker Hub"
  task :push do
    system "docker push #{tag}"
  end
end

task "docker:build" => "^build"
task :default => :spec

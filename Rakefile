require 'rake/clean'
require 'rubygems'
require 'rubygems/package_task'
require 'rdoc/task'

require "bundler/gem_tasks"

Rake::RDocTask.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files.include("README.rdoc","lib/**/*.rb","bin/**/*")
  rd.title = 'Your application title'
end

spec = Gem::Specification.load("bandcamp-discover.gemspec")

Gem::PackageTask.new(spec) do |pkg|
end
require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
end

task :default => :test

# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  gem.name = "buckets"
  gem.homepage = "http://github.com/tysontate/buckets"
  gem.license = "MIT"
  gem.summary = "Simple distribution-based sampling of arbitrary objects."
  gem.description = "Simple distribution-based sampling of arbitrary objects via the use of, well, buckets."
  gem.email = "tyson@tysontate.com"
  gem.authors = ["Tyson Tate"]
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

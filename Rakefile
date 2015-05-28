require 'bundler'
require 'bundler/gem_tasks'
require 'bundler/setup'

require 'opal'

Opal.use_gem('wedge')
Opal.append_path File.expand_path('../lib', __FILE__)
Opal.append_path File.expand_path('../playground/app', __FILE__)
Opal.append_path File.expand_path('../playground/public', __FILE__)

require 'opal/rspec/rake_task'
Opal::RSpec::RakeTask.new('opal:rspec') do |s|
  s.index_path = 'spec/index.html.erb'
end

task default: [:test]

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new('ruby:rspec')

task :test do
  puts "--------------------------\nRun specs in Opal\n--------------------------"
  Rake::Task['opal:rspec'].invoke
  puts "--------------------------\nRun specs in normal ruby\n--------------------------"
  Rake::Task['ruby:rspec'].invoke
end

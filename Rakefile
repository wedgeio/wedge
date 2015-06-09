$:.unshift(File.expand_path('./lib'))
$:.unshift(File.expand_path("./playground/app"))

current_task = Rake.application.top_level_tasks.first

ENV['RACK_ENV'] ||= (current_task['default'] || current_task[/(rspec|test)\z/]) ? 'test' : 'development'

require 'bundler'
require 'bundler/gem_tasks'
require 'bundler/setup'

require 'config/boot'
require 'opal/rspec/rake_task'

Opal.append_path File.expand_path('../lib', __FILE__)
Opal.append_path File.expand_path('../playground/app', __FILE__)
Opal.append_path File.expand_path('../playground/public', __FILE__)

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

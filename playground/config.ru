ENV['LC_ALL'] ||= 'en_US.utf8'

require File.expand_path '../app/config/boot', __FILE__

run Playground

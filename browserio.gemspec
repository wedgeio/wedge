# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'browserio/version'

Gem::Specification.new do |spec|
  spec.name          = "browserio"
  spec.version       = BrowserIO::VERSION
  spec.authors       = ["cj"]
  spec.email         = ["cjlazell@gmail.com"]
  spec.summary       = %q{TODO: Write a short summary. Required.}
  spec.description   = %q{TODO: Write a longer description. Optional.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "opal", "~> 0.7.1"
  spec.add_runtime_dependency "opal-jquery", "~> 0.3.0"
  spec.add_runtime_dependency "nokogiri", '~> 1.6.6.2'

  spec.add_development_dependency "pry"
  spec.add_development_dependency "awesome_print"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "phantomjs.rb"
  spec.add_development_dependency 'minitest-line'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'roda'
end

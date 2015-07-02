# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wedge/version'

Gem::Specification.new do |spec|
  spec.name          = "wedge"
  spec.version       = Wedge::VERSION
  spec.authors       = ["cj"]
  spec.email         = ["cjlazell@gmail.com"]
  spec.summary       = %q{Components for the Browser and Server}
  spec.description   = %q{Components for the Browser and Server}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "opal", '~> 0.8.0.rc1'
  spec.add_runtime_dependency "opal-jquery", '~> 0.3.0'
  spec.add_runtime_dependency "nokogiri"

  spec.add_development_dependency 'rspec'
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "awesome_print"
  spec.add_development_dependency "yard"
  spec.add_development_dependency 'roda'

end

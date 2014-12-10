# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hydra-bones/version'

Gem::Specification.new do |spec|
  spec.name          = "hydra-bones"
  spec.version       = HydraBones::VERSION
  spec.authors       = ["Colin Gross"]
  spec.email         = ["grosscol@umich.edu"]
  spec.summary       = %q{Automate setup and teardown of full Hydra stack}
  spec.description   = %q{Spin up virtual machines; Install dependencies; Stand up Fedora and Solr; ect...}
  spec.homepage      = ""
  spec.license       = "Apache 2"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk", "< 2.0"
  spec.add_dependency "inifile"

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end

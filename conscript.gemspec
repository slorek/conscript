# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'conscript/version'

Gem::Specification.new do |spec|
  spec.name          = "conscript"
  spec.version       = Conscript::VERSION
  spec.authors       = ["Steve Lorek"]
  spec.email         = ["steve@stevelorek.com"]
  spec.description   = %q{Provides ActiveRecord models with draft instances, including associations}
  spec.summary       = %q{Provides ActiveRecord models with draft instances, including associations}
  spec.homepage      = "http://github.com/slorek/conscript"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_runtime_dependency "activerecord", "~> 3.2.13"
  spec.add_runtime_dependency "deep_cloneable", "~> 1.5.2"
end

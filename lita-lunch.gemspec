# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'lita-lunch'
  spec.version       = '0.1.0'
  spec.authors       = ['Erik Ogan']
  spec.email         = ['erik@change.org']
  spec.summary       = 'A Lita handler for selecting random lunch groups.'
  spec.description   = 'Manages groups by office, distributing participants randomly into appropriately sized groups.'
  spec.homepage      = 'http://github.com/change/lita-stacker'
  spec.license       = 'MIT'
  spec.metadata      = { 'lita_plugin_type' => 'handler' }

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'lita', '>= 4.7'
  spec.add_runtime_dependency 'tzinfo'

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '>= 3.7.0'
  spec.add_development_dependency 'rubocop', '>= 0.58.1'
  spec.add_development_dependency 'rubocop-rspec', '>= 1.28.0'
  spec.add_development_dependency 'timecop', '>= 0.9.1'
end

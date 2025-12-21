require 'rubygems'

Gem::Specification.new do |spec|
  spec.name        = 'database-model-generator'
  spec.version     = '0.7.0'
  spec.author      = 'Daniel J. Berger'
  spec.license     = 'Apache-2.0'
  spec.email       = 'djberg96@gmail.com'
  spec.homepage    = 'http://www.github.com/djberg96/database-model-generator'
  spec.summary     = 'A Ruby library for generating Rails AR models from existing tables.'
  spec.test_files  = Dir['spec/**/*.rb']
  spec.files       = Dir['**/*'].reject{ |f| f.include?('git') }
  spec.cert_chain  = spec.cert_chain = ['certs/djberg96_pub.pem']

  spec.executables = 'dmg'

  spec.add_dependency('getopt', '~> 1.6')

  # I do not require vendor-specific gems because I do not know which vendor
  # you may or may not be using. However, I've added them as development
  # dependencies for testing, and as a clue for you the reader.
  spec.add_development_dependency('rspec', '~> 3.12')
  spec.add_development_dependency('ruby-oci8', '~> 2.2')
  spec.add_development_dependency('tiny_tds', '~> 3.2.1')
  spec.add_development_dependency('pg', '~> 1.5')

  # Again, I only set this as a development dependency mainly as a reminder.
  # The version you need will depend on which version of Rails you're using.
  spec.add_development_dependency('validates_timeliness')

  spec.description = <<-EOF
    The database-model-generator library allows you to generate an ActiveRecord
    model from an existing Oracle, SQL Server, or PostgreSQL table or view,
    as well as automatically generate a baseline test file for test-unit or minitest.
  EOF
end

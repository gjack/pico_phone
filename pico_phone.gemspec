# frozen_string_literal: true

require_relative "lib/pico_phone/version"

Gem::Specification.new do |spec|
  spec.name = "pico_phone"
  spec.version = PicoPhone::VERSION
  spec.authors = ["Gabi Jack"]
  spec.email = ["gabi@gabijack.com"]

  spec.summary = "Uses the Google libphonenumber C lib to parse, validate, and format phone numbers"
  spec.description = <<~MSG.strip
    Ruby binding of the Google's native C++ [libphonenumber](https://github.com/google/libphonenumber).
  MSG
  spec.homepage = "https://gabijack.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/gjack/pico_phone"
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.extensions    = ['ext/pico_phone/extconf.rb']
  spec.files = [
    'ext/pico_phone/pico_phone.cpp',
    'lib/pico_phone.rb',
    'lib/pico_phone/version.rb'
  ]
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

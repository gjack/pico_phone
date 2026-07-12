# frozen_string_literal: true

require_relative "lib/pico_phone/version"

Gem::Specification.new do |spec|
  spec.name = "pico_phone"
  spec.version = PicoPhone::VERSION
  spec.authors = ["Gabi Jack"]
  spec.email = ["gabi@gabijack.com"]

  spec.summary = "A thin Ruby wrapper around Google's libphonenumber for parsing, validating, and formatting phone numbers"
  spec.description = "pico_phone wraps Google's libphonenumber C++ library via a Rice native extension, " \
    "providing phone number parsing, validation, and formatting for any country. It uses the same engine " \
    "as Android's dialer and delivers native C++ performance for high-throughput server-side use."
  spec.homepage = "https://github.com/gjack/pico_phone"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/gjack/pico_phone"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/pico_phone"
  spec.metadata["changelog_uri"] = "https://github.com/gjack/pico_phone/releases"
  spec.metadata["bug_tracker_uri"] = "https://github.com/gjack/pico_phone/issues"

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.extensions    = ['ext/pico_phone/extconf.rb']
  spec.files = [
    'ext/pico_phone/extconf.rb',
    'ext/pico_phone/pico_phone.cpp',
    'lib/pico_phone.rb',
    'lib/pico_phone/version.rb',
    'lib/pico_phone/phone_number.rb',
    'LICENSE.txt',
    'THIRD_PARTY_LICENSES.txt'
  ]
  spec.require_paths = ["lib"]

  spec.add_dependency "rice", "~> 4.3"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rake-compiler", "~> 1.2"
end

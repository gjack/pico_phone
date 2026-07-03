# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require 'rake/extensiontask'

desc "pico_phone test suite"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = "spec/*_spec.rb"
  t.verbose = false
end

gemspec = Gem::Specification.load('pico_phone.gemspec')

Rake::ExtensionTask.new("pico_phone", gemspec) do |ext|
  ext.source_pattern = "*.{cpp}"
  ext.ext_dir = 'ext/pico_phone'
  ext.lib_dir = 'lib/pico_phone'
end

task default: [:compile, :spec]

desc "Build static dependencies and package a native gem for arm64-darwin"
task "native:build" do
  require "rubygems/package"

  sh "bash ext/pico_phone/build_deps.sh"
  ENV["PICO_PHONE_NATIVE_BUILD"] = "1"
  Rake::Task["compile"].invoke

  native_spec = gemspec.dup
  native_spec.platform = Gem::Platform.new("arm64-darwin")
  native_spec.extensions = []
  native_spec.files = (gemspec.files + ["lib/pico_phone/pico_phone.bundle"]).uniq

  mkdir_p "pkg"
  gem_filename = Gem::Package.build(native_spec)
  mv gem_filename, "pkg/#{gem_filename}"

  puts "\nBuilt pkg/#{gem_filename}"
end

# frozen_string_literal: true

require "bundler/gem_tasks"
require 'rake/extensiontask'

begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = "spec/*_spec.rb"
    t.verbose = false
  end
rescue LoadError
end

gemspec = Gem::Specification.load('pico_phone.gemspec')

Rake::ExtensionTask.new("pico_phone", gemspec) do |ext|
  ext.source_pattern = "*.{cpp,cc}"
  ext.ext_dir = 'ext/pico_phone'
  ext.lib_dir = 'lib/pico_phone'
end

task default: [:compile, :spec]

namespace :bench do
  desc "Compare pico_phone vs phonelib throughput (requires: bundle install)"
  task :speed do
    ruby "bench/speed.rb"
  end

  desc "Compare pico_phone vs phonelib peak memory (requires: bundle install)"
  task :memory do
    ruby "bench/memory.rb"
  end
end

desc "Run all benchmarks"
task bench: %w[bench:speed bench:memory]

desc "Build static dependencies and package a native gem for the current platform"
task "native:build" do
  require "rubygems/package"

  platform_str = if RUBY_PLATFORM.include?("darwin")
    "arm64-darwin"
  else
    "#{RbConfig::CONFIG['host_cpu']}-linux"
  end

  sh "bash ext/pico_phone/build_deps.sh"
  ENV["PICO_PHONE_NATIVE_BUILD"] = "1"
  Rake::Task["compile"].invoke

  ext = RbConfig::CONFIG["DLEXT"]
  bundle_file = "lib/pico_phone/pico_phone.#{ext}"

  native_spec = gemspec.dup
  native_spec.platform = Gem::Platform.new(platform_str)
  native_spec.extensions = []
  native_spec.files = (gemspec.files + [bundle_file]).uniq

  mkdir_p "pkg"
  gem_filename = Gem::Package.build(native_spec)
  mv gem_filename, "pkg/#{gem_filename}"

  puts "\nBuilt pkg/#{gem_filename}"
end

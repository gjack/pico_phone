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

desc "Build static dependencies and package a native gem for the current platform"
task "native:build" do
  sh "bash ext/pico_phone/build_deps.sh"
  ENV["PICO_PHONE_NATIVE_BUILD"] = "1"
  Rake::Task["native"].invoke
  Rake::Task["gem"].invoke
end

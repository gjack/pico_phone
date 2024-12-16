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
Rake::ExtensionTask.new do |ext|
  ext.name = 'pico_phone'
  ext.source_pattern = "*.{cpp}"
  ext.ext_dir = 'ext/pico_phone'
  ext.lib_dir = 'lib/pico_phone'
  ext.gem_spec = gemspec
end

task default: [:compile, :spec]

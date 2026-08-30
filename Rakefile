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

desc "Build static dependencies for native gem builds (idempotent, Ruby-version independent)"
task "native:deps" do
  sh "bash ext/pico_phone/build_deps.sh"
end

# Ruby's C-extension ABI is only guaranteed stable within a major series (e.g. all of 3.x), not
# across major boundaries (Ruby 4.0 intentionally broke ABI compatibility with 3.x). So a native
# gem needs one compiled binary per major series, built with the OLDEST minor that series supports
# — "old build, new runtime" is the direction Ruby's ABI promise reliably covers. Each binary is
# staged under lib/pico_phone/<major.minor>/ (matching the Ruby that compiled it) rather than the
# unconditional flat path, so a fat gem can carry one binary per series and lib/pico_phone.rb's
# loader can pick the right one at require time.
desc "Compile the native extension for the currently active Ruby and stage it into its ABI-series bucket"
task "native:compile" => "native:deps" do
  ENV["PICO_PHONE_NATIVE_BUILD"] = "1"
  Rake::Task["compile"].invoke

  dlext = RbConfig::CONFIG["DLEXT"]
  abi = RUBY_VERSION.split(".").first(2).join(".")
  bucket_dir = "lib/pico_phone/#{abi}"
  mkdir_p bucket_dir
  cp "lib/pico_phone/pico_phone.#{dlext}", "#{bucket_dir}/pico_phone.#{dlext}"

  puts "\nStaged native extension for Ruby ABI series #{abi} at #{bucket_dir}/pico_phone.#{dlext}"
end

desc "Package every currently-staged per-ABI-series binary for this platform into one native gem"
task "native:package" do
  require "rubygems/package"

  platform_str = if RUBY_PLATFORM.include?("darwin")
    "arm64-darwin"
  elsif RUBY_PLATFORM.include?("musl")
    # Must be distinguished from the glibc build below -- RubyGems/Bundler use this
    # suffix to avoid installing a glibc-linked binary on a musl system (or vice versa).
    "#{RbConfig::CONFIG['host_cpu']}-linux-musl"
  else
    "#{RbConfig::CONFIG['host_cpu']}-linux"
  end

  dlext = RbConfig::CONFIG["DLEXT"]
  bucket_files = Dir.glob("lib/pico_phone/*/pico_phone.#{dlext}").sort
  if bucket_files.empty?
    abort "No compiled binaries found under lib/pico_phone/*/ — run native:compile (once per target Ruby) first"
  end

  native_spec = gemspec.dup
  native_spec.platform = Gem::Platform.new(platform_str)
  native_spec.extensions = []
  native_spec.files = (gemspec.files + bucket_files).uniq

  mkdir_p "pkg"
  gem_filename = Gem::Package.build(native_spec)
  mv gem_filename, "pkg/#{gem_filename}"

  built_abis = bucket_files.map { |f| File.basename(File.dirname(f)) }
  puts "\nBuilt pkg/#{gem_filename} with binaries for Ruby ABI series: #{built_abis.join(', ')}"
end

desc "Build a native gem for the current platform using only the currently active Ruby " \
     "(local single-Ruby dev convenience; CI instead runs native:compile once per target Ruby, " \
     "then native:package once)"
task "native:build" => ["native:compile", "native:package"]

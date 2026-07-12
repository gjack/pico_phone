# frozen_string_literal: true

# Compares peak RSS across pico_phone and phonelib under a few workloads.
#
# Each scenario runs in its own subprocess (via `bundle exec ruby`) so that
# process-global caches — libphonenumber's metadata singleton, phonelib's
# @@phone_data / @@phone_ext_data class variables — don't leak between
# scenarios and skew the numbers.
#
# Run with: bundle exec rake bench:memory

require "open3"

SCENARIOS = [
  ["baseline",           "bench/memory_scenarios/baseline.rb",           nil],
  ["pico_phone (light)", "bench/memory_scenarios/pico_light.rb",         nil],
  ["pico_phone (heavy)", "bench/memory_scenarios/pico_heavy.rb",         "20000"],
  ["pico_phone (heavy, +geo_name)", "bench/memory_scenarios/pico_heavy_geo.rb", "20000"],
  ["pico_phone (heavy, +carrier_name)", "bench/memory_scenarios/pico_heavy_carrier.rb", "20000"],
  ["phonelib (light)",   "bench/memory_scenarios/phonelib_light.rb",     nil],
  ["phonelib (heavy)",   "bench/memory_scenarios/phonelib_heavy.rb",     "20000"],
  ["phonelib (heavy, +geo/carrier/timezone)", "bench/memory_scenarios/phonelib_heavy_ext.rb", "20000"],
].freeze

SAMPLES = (ARGV[0] || 3).to_i

def run_scenario(script, arg)
  cmd = ["bundle", "exec", "ruby", "-Ilib", script]
  cmd << arg if arg
  out, err, status = Open3.capture3(*cmd)
  raise "#{script} failed: #{err}" unless status.success?

  Float(out.strip)
end

puts "Sampling each scenario #{SAMPLES}x (peak RSS in MB, via get_process_mem)...\n\n"

results = SCENARIOS.map do |label, script, arg|
  samples = Array.new(SAMPLES) { run_scenario(script, arg) }
  print "#{label}: #{samples.map { |s| s.round(1) }}\n"
  [label, samples.max]
end

label_width = results.map { |label, _| label.length }.max

puts "\n%-#{label_width}s  %10s" % ["Scenario", "Peak MB"]
puts "-" * (label_width + 12)
results.each do |label, mb|
  puts "%-#{label_width}s  %10.1f" % [label, mb]
end

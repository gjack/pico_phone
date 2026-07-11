# frozen_string_literal: true

# Throughput comparison between pico_phone (native libphonenumber via Rice)
# and phonelib (a pure-Ruby port of libphonenumber's matching logic).
#
# Run with: bundle exec rake bench:speed

require "benchmark/ips"
require "pico_phone"
require "phonelib"
require_relative "numbers"

number, region = "5102745656", "US"

Benchmark.ips do |x|
  x.config(time: 3, warmup: 1)

  x.report("pico_phone: valid?") { PicoPhone.valid_for_country?(number, region) }
  x.report("phonelib:   valid?") { Phonelib.valid_for_country?(number, region) }

  x.report("pico_phone: parse + e164") { PicoPhone.parse(number, region).e164 }
  x.report("phonelib:   parse + e164") { Phonelib.parse(number, region).e164 }

  x.report("pico_phone: parse + national") { PicoPhone.parse(number, region).national }
  x.report("phonelib:   parse + national") { Phonelib.parse(number, region).national }

  x.compare!
end

puts
puts "--- across #{NUMBERS.size} numbers spanning multiple regions ---"
puts

Benchmark.ips do |x|
  x.config(time: 3, warmup: 1)

  x.report("pico_phone: valid? (multi-region)") do
    NUMBERS.each { |n, r| PicoPhone.valid_for_country?(n, r) }
  end

  x.report("phonelib:   valid? (multi-region)") do
    NUMBERS.each { |n, r| Phonelib.valid_for_country?(n, r) }
  end

  x.compare!
end

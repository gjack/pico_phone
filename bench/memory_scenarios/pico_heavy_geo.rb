# frozen_string_literal: true

# Same workload as pico_heavy.rb, plus geo_name on every call. Unlike
# phonelib's extended data (see phonelib_heavy_ext.rb), libphonenumber's
# geocoder loads its data lazily per (country calling code, language) file
# and caches only what's queried -- this scenario exists to confirm that
# holds in practice, not just architecturally.
require "get_process_mem"
require "pico_phone"
require_relative "../numbers"

iterations = (ARGV[0] || 20_000).to_i

iterations.times do
  NUMBERS.each do |number, region|
    phone = PicoPhone.parse(number, region)
    phone.valid?
    phone.possible?
    phone.e164
    phone.national
    phone.international
    phone.geo_name
  end
end

GC.start
puts GetProcessMem.new.mb

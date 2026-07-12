# frozen_string_literal: true

# Same workload as pico_heavy.rb, plus carrier_name on every call. Mirrors
# pico_heavy_geo.rb: PhoneNumberCarrierMapper reuses the same lazy
# per-(country calling code, language) file loading and caching as
# PhoneNumberOfflineGeocoder (see carrier_mapper.h), so this scenario
# exists to confirm that holds in practice for carrier data too, not just
# architecturally.
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
    phone.carrier_name
  end
end

GC.start
puts GetProcessMem.new.mb

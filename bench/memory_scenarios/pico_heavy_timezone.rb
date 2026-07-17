# frozen_string_literal: true

# Same workload as pico_heavy.rb, plus timezones on every call. Unlike the
# geocoder and carrier mapper (which load prefix data lazily, one
# country-code/language file at a time), PhoneNumberTimeZonesMapper eagerly
# loads its single flat table (~86KB on disk) at first use. This scenario
# exists to confirm that the eager load is negligible in practice and that
# memory stays flat under sustained load.
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
    phone.timezones
  end
end

GC.start
puts GetProcessMem.new.mb

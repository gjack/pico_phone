# frozen_string_literal: true

# Same workload as phonelib_heavy.rb, plus geo_name/carrier/timezone on every
# call. Those methods lazily Marshal.load phonelib's extended_data.dat (area
# code -> city/carrier/timezone tables for every region) into nested Ruby
# objects and cache it in a class variable for the life of the process —
# this scenario exists to show the cost of that specifically, not of
# validate/parse/format.
require "get_process_mem"
require "phonelib"
require_relative "../numbers"

iterations = (ARGV[0] || 20_000).to_i

iterations.times do
  NUMBERS.each do |number, region|
    phone = Phonelib.parse(number, region)
    phone.valid?
    phone.possible?
    phone.e164
    phone.national
    phone.international
    phone.geo_name
    phone.carrier
    phone.timezone
  end
end

GC.start
puts GetProcessMem.new.mb

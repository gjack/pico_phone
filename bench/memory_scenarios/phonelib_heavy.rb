# frozen_string_literal: true

# Same operations as pico_heavy.rb — validate/parse/format only, no
# geo/carrier/timezone lookups (see phonelib_heavy_ext.rb for that).
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
  end
end

GC.start
puts GetProcessMem.new.mb

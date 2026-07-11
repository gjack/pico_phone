# frozen_string_literal: true

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
  end
end

GC.start
puts GetProcessMem.new.mb

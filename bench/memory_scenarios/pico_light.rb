# frozen_string_literal: true

require "get_process_mem"
require "pico_phone"
require_relative "../numbers"

number, region = NUMBERS.first
phone = PicoPhone.parse(number, region)
phone.valid?
phone.e164

GC.start
puts GetProcessMem.new.mb

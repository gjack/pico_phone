# frozen_string_literal: true

require "get_process_mem"
require "phonelib"
require_relative "../numbers"

number, region = NUMBERS.first
phone = Phonelib.parse(number, region)
phone.valid?
phone.e164

GC.start
puts GetProcessMem.new.mb

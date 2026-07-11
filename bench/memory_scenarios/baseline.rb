# frozen_string_literal: true

# No gem loaded — measures the bare Ruby interpreter's own footprint.
require "get_process_mem"

GC.start
puts GetProcessMem.new.mb

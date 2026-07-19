# encoding: UTF-8
# frozen_string_literal: true
require "pico_phone/version"

# Native/precompiled gems ship one binary per Ruby minor actually tested in CI (bucketed by
# major.minor, e.g. "3.1", "3.4", "4.0") under lib/pico_phone/<major.minor>/. This is an EXACT
# match only, deliberately -- a binary built under one minor can produce wrong results (not just
# fail to load) under a different minor, because Rice (the C++ binding layer) is header-only and
# some Ruby C-API usage compiles down to macros that bake in that minor's internal struct layout.
# Ruby's "ABI stable within a major series" promise doesn't cover that, so there is no safe
# cross-minor fallback here. Source/dynamic gem installs (compiled fresh at `gem install` time
# against system libphonenumber) never have any lib/pico_phone/<major.minor>/ directory -- they
# fall straight through to the flat path below, unchanged from before this loader existed.
begin
  abi = RUBY_VERSION.split(".").first(2).join(".")
  bucket = File.join(__dir__, "pico_phone", abi)

  if File.directory?(bucket)
    require "pico_phone/#{abi}/pico_phone"
  else
    require "pico_phone/pico_phone"
  end
rescue LoadError
  require "pico_phone/pico_phone"
end

module PicoPhone
  class Error < StandardError; end
end

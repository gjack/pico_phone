# frozen_string_literal: true

# Behavior checks run against an INSTALLED, packaged pico_phone gem (never the source tree) by
# smoke_packaged_gem.sh (bare Linux/Alpine images) and by the release workflow's macOS job.
# Deliberately touches everything the vendored native stack provides: libphonenumber metadata,
# the offline geocoder, carrier and timezone tables, and ICU (regex/case-folding/character
# properties for non-ASCII text, and country names for geo_name in other languages).
require "pico_phone"

checks = {
  "valid?" => [PicoPhone.valid?("+15102745656"), true],
  "geo_name" => [PicoPhone.parse("5102745656", "US").geo_name, "California"],
  "geo_name ja (country names come from ICU data)" => [PicoPhone.parse("0435582008", "AU").geo_name("ja"), "オーストラリア"],
  "carrier_name" => [PicoPhone.parse("6001234567", "IN").carrier_name, "Reliance Jio"],
  "timezones" => [PicoPhone.parse("+33612345678").timezones, ["Europe/Paris"]],
  "find_numbers (Cyrillic text)" => [
    PicoPhone.find_numbers("тел. +7 495 123-45-67 доб. 12", "RU").map { |m| m.number.e164 }, ["+74951234567"]
  ],
  "non-ASCII digits" => [PicoPhone.parse("+٩٦٦٥٠١٢٣٤٥٦٧").e164, "+966501234567"]
}

bad = checks.reject { |_, (got, want)| got == want }
bad.each { |name, (got, want)| warn "   FAIL #{name}: got #{got.inspect}, want #{want.inspect}" }
abort "   smoke FAILED" unless bad.empty?
puts "   OK (#{checks.size} checks, pico_phone #{PicoPhone::VERSION}, Ruby #{RUBY_VERSION})"

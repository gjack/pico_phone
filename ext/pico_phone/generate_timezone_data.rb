#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates timezone_data.cc from libphonenumber's resources/timezones/
# map_data.txt. Not adapted from libphonenumber's own generate_geocoding_data
# tool -- that tool's per-language directory walk doesn't apply here, since
# timezone names aren't translated and the data is one flat file, not one
# per (country code, language) pair. Mirrors the *shape* it produces
# (a single PrefixDescriptions struct, see geocoding_data.h) closely enough
# to reuse AreaCodeMap for lookups, just with one static table instead of
# lazily-loaded per-language ones.
#
# Run manually when the vendored libphonenumber version bumps -- output is
# committed, not regenerated at install/build time, same rationale as
# carrier_data.cc: keeps the dynamic-link build path from needing to fetch
# or build any of libphonenumber's source tree.
#
# Usage: ruby generate_timezone_data.rb <path to map_data.txt> <output .cc path>

input_path, output_path = ARGV
abort "usage: #{$PROGRAM_NAME} <map_data.txt> <output .cc path>" unless input_path && output_path

entries = {}
File.foreach(input_path) do |line|
  line = line.strip
  next if line.empty? || line.start_with?("#")

  prefix, description = line.split("|", 2)
  abort "malformed line: #{line.inspect}" unless prefix && description
  abort "non-numeric prefix: #{line.inspect}" unless prefix.match?(/\A\d+\z/)
  abort "unescaped quote/backslash in description, generator doesn't handle that: #{line.inspect}" if description.match?(/["\\]/)

  entries[prefix.to_i] = description
end

sorted_prefixes = entries.keys.sort
possible_lengths = sorted_prefixes.map { |p| p.to_s.length }.uniq.sort

File.open(output_path, "w") do |out|
  out.puts <<~HEADER
    // Copyright (C) 2012 The Libphonenumber Authors
    //
    // Licensed under the Apache License, Version 2.0 (the "License");
    // you may not use this file except in compliance with the License.
    // You may obtain a copy of the License at
    //
    // http://www.apache.org/licenses/LICENSE-2.0
    //
    // Unless required by applicable law or agreed to in writing, software
    // distributed under the License is distributed on an "AS IS" BASIS,
    // WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    // See the License for the specific language governing permissions and
    // limitations under the License.
    //
    // This file is generated automatically by
    // ext/pico_phone/generate_timezone_data.rb from libphonenumber's
    // resources/timezones/map_data.txt -- do not edit it manually.

    #include "timezone_data.h"

    namespace i18n {
    namespace phonenumbers {
    namespace {

    const int32_t timezone_prefixes[] = {
    #{sorted_prefixes.map { |p| "  #{p}," }.join("\n")}
    };

    const char* timezone_descriptions[] = {
    #{sorted_prefixes.map { |p| "  \"#{entries[p]}\"," }.join("\n")}
    };

    const int32_t timezone_possible_lengths[] = {
    #{possible_lengths.map { |l| "  #{l}," }.join("\n")}
    };

    const PrefixDescriptions timezone_prefix_descriptions = {
      timezone_prefixes,
      sizeof(timezone_prefixes) / sizeof(*timezone_prefixes),
      timezone_descriptions,
      timezone_possible_lengths,
      sizeof(timezone_possible_lengths) / sizeof(*timezone_possible_lengths),
    };

    }  // namespace

    const PrefixDescriptions* get_timezone_descriptions() {
      return &timezone_prefix_descriptions;
    }

    }  // namespace phonenumbers
    }  // namespace i18n
  HEADER
end

warn "Wrote #{output_path}: #{sorted_prefixes.size} prefixes, #{possible_lengths.size} distinct lengths"

# PicoPhone

[![CI](https://github.com/gjack/pico_phone/actions/workflows/ci.yml/badge.svg)](https://github.com/gjack/pico_phone/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/pico_phone.svg?v=1)](https://badge.fury.io/rb/pico_phone)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A thin Ruby wrapper around Google's [libphonenumber](https://github.com/google/libphonenumber) C++ library, built with [Rice](https://github.com/ruby-rice/rice). It uses the same engine as Android's dialer for parsing, validating, and formatting phone numbers in any country.

## Installation

Add to your Gemfile:

```ruby
gem 'pico_phone'
```

Or install directly:

```
gem install pico_phone
```

Pre-compiled native gems are available for `arm64-darwin` (Apple Silicon Macs), `x86_64-linux`, and `aarch64-linux` (Ubuntu 24.04). On these platforms no system libraries or compiler are required — Bundler will select the right binary automatically.

On other platforms the gem compiles from source and requires libphonenumber:

```
# macOS
brew install libphonenumber

# Ubuntu/Debian
sudo apt-get install libphonenumber-dev libicu-dev
```

## Usage

### Checking if a phone number is valid

```
PicoPhone.valid?("+15102745656")  #true
PicoPhone.valid_for_country?("(510) 274-5556", "BR")  #false

phone = PicoPhone.parse("(510) 274-5556", "BR")
phone.valid? #false
```

### Checking if a phone number is possible

```
PicoPhone.possible?("+15102745556")  #true
PicoPhone.possible?("It's my number") #false

phone = PicoPhone.parse("-245")
phone.possible? #false
```

`possible_with_reason` returns a symbol explaining why a number is or is not possible, which is more useful than a boolean when generating validation messages.

```
phone = PicoPhone.parse("+15102745656", "US")
phone.possible_with_reason  # :is_possible

phone = PicoPhone.parse("123", "US")
phone.possible_with_reason  # :too_short

phone = PicoPhone.parse("123456789000", "US")
phone.possible_with_reason  # :too_long
```

Possible return values are `:is_possible`, `:is_possible_local_only`, `:too_short`, `:too_long`, `:invalid_country_code`, and `:invalid_length`.

### Formatting a phone number

```
phone = PicoPhone.parse("5102745656", "US")

phone.national            # (510) 274-5656
phone.international       # +1 510-274-5656
phone.e164                # +15102745656
phone.raw_national        # 5102745656
phone.raw_international   # 15102745656

phone = PicoPhone.parse("0435582008", "AU")

phone.national            # 0435 582 008
phone.international       # +61 435 582 008
phone.e164                # +61435582008
phone.raw_national        # 435582008
phone.raw_international   # 61435582008
```

### Country codes, area codes, and local number

```
phone = PicoPhone.parse("5102745656", "US")

phone.country_code     # 1
phone.area_code        # "510"
phone.local_number     # "2745656"

phone = PicoPhone.parse("0435582008", "AU")

phone.country_code     # 61
phone.area_code        # "" (AU mobile numbers have no geographical area code)
phone.local_number     # "435582008" (full national number when there is no area code)
```

`country_calling_code` returns the international calling code for a region code, without needing to parse a number first. Returns `0` for unknown or invalid region codes.

```
PicoPhone.country_calling_code("US")  # 1
PicoPhone.country_calling_code("FR")  # 33
PicoPhone.country_calling_code("BR")  # 55
PicoPhone.country_calling_code("CA")  # 1  (NANP — same calling code as US)
PicoPhone.country_calling_code("XX")  # 0  (unknown region)
```

### Truncating too-long numbers

`truncate` removes trailing digits from a number that is too long until a valid number is found. Returns a new `PhoneNumber` on success, or `nil` when the number was already valid or no valid truncation exists. The receiver is never mutated.

```
phone = PicoPhone.parse("+151027456560000", "US")
phone.valid?    # false

truncated = phone.truncate
truncated.e164  # "+15102745656"
truncated.valid?  # true

PicoPhone.parse("+15102745656").truncate  # nil  (already valid)
PicoPhone.parse("garbage").truncate       # nil  (cannot be truncated)
```

### Geographic description

```
phone = PicoPhone.parse("5102745656", "US")

phone.geo_name         # "California"
phone.geo_name("de")   # description in another language, where available

phone = PicoPhone.parse("0435582008", "AU")

phone.geo_name         # "Australia" (falls back to the country name when no finer description exists)
```

Backed by libphonenumber's own offline geocoder, not a separate re-implementation — it loads its area-code data lazily, one region/language file at a time, so looking up a number doesn't pull the whole world's geocoding data into memory (see the memory benchmark in [Benchmarks](#benchmarks)).

### Carrier lookup

```
phone = PicoPhone.parse("6001234567", "IN")

phone.carrier_name         # "Reliance Jio"
phone.carrier_name("de")   # carrier name in another language, where available

phone = PicoPhone.parse("5102745656", "US")

phone.carrier_name         # "" (no carrier mapping for this prefix -- number portability makes carrier-by-prefix unreliable in many countries, including the US)
```

`carrier_name` returns the carrier the number was **originally allocated to**, not necessarily its current carrier — in countries that support mobile number portability, a number may have since been ported away from that carrier. This matches libphonenumber's own Java carrier mapper, which documents the same caveat verbatim ("the carrier name is the one the number was originally allocated to, however if the country supports mobile number portability the number might not belong to the returned carrier anymore").

libphonenumber has no upstream C++ port of its carrier mapper (only Java), so this is a first-party pico_phone implementation reusing the same lazy per-(country code, language) loading machinery as `geo_name` above, rather than a Ruby-level reimplementation. Unlike `geo_name`, there's no fallback to a country-level description when a prefix has no carrier data — an unmapped number just returns an empty string, matching phonelib's `carrier` semantics.

### Timezone lookup

```
phone = PicoPhone.parse("+12082123456")

phone.timezones   # ["America/Boise", "America/Los_Angeles"]

phone = PicoPhone.parse("6001234567", "IN")

phone.timezones   # ["Asia/Calcutta"]

phone = PicoPhone.parse("+33612345678")

phone.timezones   # ["Europe/Paris"]
```

`timezones` returns an array of [IANA time zone identifiers](https://www.iana.org/time-zones) for the number's prefix. A number can map to more than one timezone when its prefix covers a geographic area that spans multiple zones — NANP area codes in particular span many US time zones. The method returns an empty array when no mapping exists for the number's prefix.

libphonenumber has no upstream C++ port of its timezone mapper (only Java), so this is a first-party pico_phone implementation using the same prefix-lookup machinery (`AreaCodeMap`) as `geo_name` and `carrier_name`. The timezone table is small enough (~86KB on disk) to load once at first call rather than lazily per-region — the initial load cost is negligible.

### Checking validity for a specific country on a parsed number

The module-level `valid_for_country?` accepts a raw string. The same check is also available as an instance method once a number has been parsed.

```
phone = PicoPhone.parse("+15102745656")

phone.valid_for_country?("US")    # true
phone.valid_for_country?("AU")    # false
phone.invalid_for_country?("US")  # false
phone.invalid_for_country?("AU")  # true
```

### Original input and string conversion

`original` returns the input exactly as it was passed to `parse`, regardless of whether parsing succeeded. `to_s` returns the e164 format for a valid number, and falls back to the original input for an invalid one.

```
phone = PicoPhone.parse("5102745656", "US")
phone.original   # "5102745656"
phone.to_s       # "+15102745656"

phone = PicoPhone.parse("not a number")
phone.original   # "not a number"
phone.to_s       # "not a number"
```

### Additional formatting options

`format_in_original_format` returns the number formatted in the same style it was originally entered — international if a `+` prefix was used, national otherwise.

```
PicoPhone.parse("+15102745656", "US").format_in_original_format  # "+1 510-274-5656"
PicoPhone.parse("5102745656", "US").format_in_original_format    # "(510) 274-5656"
```

`out_of_country_format(region)` returns the dialing string needed to reach the number from a given country. Within shared-prefix regions such as NANP no international prefix is prepended; from other regions the appropriate dialing prefix for the calling country is used.

```
phone = PicoPhone.parse("+15102745656", "US")

phone.out_of_country_format("US")  # "1 (510) 274-5656"
phone.out_of_country_format("GB")  # "00 1 510-274-5656"
phone.out_of_country_format("AU")  # "0011 1 510-274-5656"
```

`mobile_dialing_format(region)` returns the most convenient representation for dialing the number from a mobile device in the given region, typically the full international format with separators.

```
phone = PicoPhone.parse("+15102745656", "US")

phone.mobile_dialing_format("US")  # "+1 510-274-5656"
phone.mobile_dialing_format("GB")  # "+1 510-274-5656"
```

### Comparing phone numbers

`number_match` compares two phone number strings and returns how closely they match. E.164 input gives the most precise result; national-format strings without a country code may return `:nsn_match` where a full E.164 comparison would return `:exact_match`.

```
PicoPhone.number_match("+15102745656", "+15102745656")  # :exact_match
PicoPhone.number_match("+15102745656", "5102745656")    # :nsn_match   (no country code in second arg)
PicoPhone.number_match("+15102745656", "2745656")       # :short_nsn_match
PicoPhone.number_match("+15102745656", "+61435582008")  # :no_match
PicoPhone.number_match("+15102745656", "garbage")       # :invalid_number
```

`match_type` is the instance-method equivalent. It accepts either a string or a `PhoneNumber`. When passed a `PhoneNumber`, the country code already embedded in the parsed object is used, which gives `:exact_match` where a bare national-format string would give `:nsn_match`.

```
phone = PicoPhone.parse("+15102745656")

phone.match_type("+15102745656")                      # :exact_match
phone.match_type(PicoPhone.parse("5102745656", "US")) # :exact_match  (country code resolved at parse time)
phone.match_type("5102745656")                        # :nsn_match    (string has no country code)
phone.match_type("+61435582008")                      # :no_match
```

Possible return values are `:exact_match`, `:nsn_match`, `:short_nsn_match`, `:no_match`, and `:invalid_number`.

### Finding phone numbers in text

`find_numbers` scans an arbitrary block of text and returns every phone number found, along with its position and the raw substring that was matched. It uses libphonenumber's `PhoneNumberMatcher` internally.

```
matches = PicoPhone.find_numbers("Call me at +1 425 882-8080 or (650) 253-0000 for details.", "US")

matches.size              # 2
matches.first.raw_string  # "+1 425 882-8080"
matches.first.start       # 11
matches.first.end_index   # 26
matches.first.number      # #<PicoPhone::PhoneNumber>
matches.first.number.e164 # "+14258828080"
```

Each element in the returned array is a `PicoPhone::PhoneNumberMatch` with four methods:

| Method | Returns |
|--------|---------|
| `start` | Byte offset of the match start in the searched text |
| `end_index` | Exclusive byte offset of the match end (`text[start...end_index]` is the match) |
| `raw_string` | The matched substring exactly as it appears in the text |
| `number` | A fully-parsed `PicoPhone::PhoneNumber` |

The `leniency` keyword argument controls how strictly a candidate is required to look like a phone number before being included. Defaults to `:valid`.

```
# :possible — accept any number-like sequence with a plausible digit count
PicoPhone.find_numbers(text, "US", leniency: :possible)

# :valid (default) — must be a valid number for its region
PicoPhone.find_numbers(text, "US", leniency: :valid)

# :strict_grouping — must also be formatted in a regionally plausible grouping
PicoPhone.find_numbers(text, "US", leniency: :strict_grouping)

# :exact_grouping — must match exactly how libphonenumber would format it
PicoPhone.find_numbers(text, "US", leniency: :exact_grouping)
```

> **Note:** Some Linux distributions ship a `libphonenumber` system package compiled with
> `USE_ALTERNATE_FORMATS=OFF`, which disables alternate-format pattern recognition used by
> `find_numbers`. If the method returns fewer matches than expected on Linux, building with
> `PICO_PHONE_NATIVE_BUILD=1` uses the vendored library, which always enables alternate formats.

### Finding possible or valid countries for a phone number

A calling code is not always 1:1 with a country. `+1` covers the US, Canada, and around 20 Caribbean territories. `+7` covers both Russia and Kazakhstan. These methods let you find which countries a given number could belong to.

`possible_countries` uses a lenient check: for unambiguous calling codes (e.g. `+33` for France) it only requires the number to be the right length. For ambiguous calling codes it narrows the list down using full pattern validation, since length alone cannot distinguish between candidates.

`valid_countries` always applies full pattern validation and returns only the regions where the number is genuinely valid.

```
PicoPhone.possible_countries("+15102745656")  # ["US"]
PicoPhone.possible_countries("+12423570000")  # ["BS"]  (Bahamas, also a NANP number)
PicoPhone.possible_countries("+78005553535")  # ["RU", "KZ"]

PicoPhone.valid_countries("+15102745656")     # ["US"]
PicoPhone.valid_countries("+78005553535")     # ["RU", "KZ"]

# A number that is the right length for France but fails pattern validation
PicoPhone.possible_countries("+33000000000") # ["FR"]
PicoPhone.valid_countries("+33000000000")    # []

# Both methods return [] for unparseable input
PicoPhone.possible_countries("not a number") # []

phone = PicoPhone.parse("+15102745656")
phone.possible_countries  # ["US"]
phone.valid_countries     # ["US"]
```

### Number characteristics

`geographical?` returns true for fixed-line numbers tied to a geographic area code. Mobile, toll-free, and other non-geographic number types return false.

```
PicoPhone.parse("+15102745656", "US").geographical?   # true  (fixed-line with area code)
PicoPhone.parse("+61435582008", "AU").geographical?   # false (AU mobile)
PicoPhone.parse("+18005551234", "US").geographical?   # false (toll-free)
```

`can_be_internationally_dialled?` returns false for numbers that can only be reached from within their own country.

```
PicoPhone.parse("+15102745656", "US").can_be_internationally_dialled?  # true
```

### Supported types for a region

`supported_types_for_region` returns the phone number types that actually exist in a given country. The set of types varies significantly between regions.

```
PicoPhone.supported_types_for_region("US")
# => [:fixed_line, :mobile, :toll_free, :premium_rate, :personal_number]

PicoPhone.supported_types_for_region("AU")
# => [:fixed_line, :mobile, :toll_free, :premium_rate, :shared_cost, :voip, :pager]
```

### Example numbers

`example_number` returns a valid example `PhoneNumber` instance for a region. `example_number_for_type` returns an example for a specific number type. Both return a fully parsed object, so all the usual methods are available on the result.

```
PicoPhone.example_number("AU").e164            # "+61212345678"
PicoPhone.example_number("AU").national        # "02 1234 5678"

PicoPhone.example_number_for_type("US", :toll_free).e164   # "+18002345678"
PicoPhone.example_number_for_type("AU", :mobile).e164      # "+61412345678"
```

> **Note:** Some Linux distributions ship a `libphonenumber` system package compiled with
> `USE_LITE_METADATA=ON`, which strips example number data from the library. If
> `example_number` or `example_number_for_type` returns `nil` on Linux, this is the cause.
> Build with `PICO_PHONE_NATIVE_BUILD=1` to use the vendored library, which always includes
> full metadata.

### Checking if a number is possible for a specific type

`possible_for_type?` checks whether a number's digit count is consistent with a given type in its region. This is a length-based check — more permissive than `type`, which classifies the number strictly.

```
phone = PicoPhone.parse("+15102745656", "US")
phone.possible_for_type?(:fixed_line_or_mobile)  # true
phone.possible_for_type?(:toll_free)             # true  (same digit count)

phone.type  # :fixed_line_or_mobile  (strict classification)
```

### Vanity numbers

`alpha_number?` identifies vanity number strings before parsing or converting them. `convert_alpha_characters` converts the alpha characters to their dialable digit equivalents.

```
PicoPhone.alpha_number?("1-800-FLOWERS")           # true
PicoPhone.alpha_number?("+15102745656")            # false

PicoPhone.convert_alpha_characters("1-800-FLOWERS")  # "1-800-3569377"
```

Once converted, the result can be passed to `parse` as usual.

```
PicoPhone.parse(PicoPhone.convert_alpha_characters("1-800-FLOWERS")).type  # :toll_free
```

### Supported regions

`supported_regions` returns an array of all region codes the library knows about. Useful for populating a country selector or validating a region code before passing it elsewhere.

```
PicoPhone.supported_regions          # ["AC", "AD", "AE", ...]
PicoPhone.supported_regions.size     # 245
PicoPhone.supported_regions.include?("US")  # true
```

### Short numbers and emergency services

Short numbers (emergency services, short codes, etc.) cannot be parsed as regular phone numbers and require a region to be meaningful. These methods wrap libphonenumber's `ShortNumberInfo` API.

`emergency_number?` checks whether a string exactly matches an emergency service number in the given region.

```
PicoPhone.emergency_number?("911", "US")   # true
PicoPhone.emergency_number?("999", "GB")   # true
PicoPhone.emergency_number?("411", "US")   # false
```

`short_number_valid?` checks whether a string is a valid short number in the given region.

```
PicoPhone.short_number_valid?("911", "US")  # true
PicoPhone.short_number_valid?("411", "US")  # true
PicoPhone.short_number_valid?("411", "GB")  # false
```

`short_number_cost` returns the cost category of a short number as a symbol. Emergency numbers are always `:toll_free`. Returns `:unknown_cost` if the number cannot be parsed or has no cost data for the region.

```
PicoPhone.short_number_cost("911", "US")  # :toll_free
PicoPhone.short_number_cost("411", "US")  # :unknown_cost
```

Possible return values are `:toll_free`, `:standard_rate`, `:premium_rate`, and `:unknown_cost`.

### Extensions

PicoPhone exposes libphonenumber's methods that identify and extract the extension out of a parsed phone number.

```
phone = PicoPhone.parse("5102745656;456", "US")

phone.has_extension?    # true
phone.extension         # 456
```

You can also format a phone number including its extension. The extension prefix can also be customized as needed. If no custom value is indicated, it will default to `;`

```
PicoPhone.default_extension_prefix = " ext. "

phone = PicoPhone.parse("5102745656;456", "US")

phone.full_national   # (510) 274-5656 ext. 456
```


## Benchmarks

pico_phone wraps the actual libphonenumber C++ engine via [Rice](https://github.com/ruby-rice/rice). [phonelib](https://github.com/daddyz/phonelib) instead reimplements libphonenumber's pattern-matching in pure Ruby. That difference in architecture shows up clearly in throughput, and less clearly (and more conditionally) in memory.

The numbers below are one data point — macOS arm64, Ruby 3.4.1, pico_phone vs. phonelib 0.10.22 — not a guarantee for your platform. Run `bundle exec rake bench` yourself to reproduce them (requires `bundle install`, which pulls in `phonelib` and `benchmark-ips` as dev-only dependencies for comparison).

### Speed

```
$ bundle exec rake bench:speed

                                   pico_phone     phonelib
valid?                              128.1k i/s     35.9k i/s   (4.7x slower)
parse + e164                        168.8k i/s     64.9k i/s   (2.6x slower)
parse + national                    109.5k i/s     47.4k i/s   (3.6x slower)
valid? (30 numbers, multi-region)     3.0k i/s      1.0k i/s   (3.0x slower)
carrier_name / carrier              173.5k i/s     42.9k i/s   (4.1x slower)
timezones / timezone                 98.1k i/s      2.5k i/s  (39.7x slower)
```

Calling into compiled C++ beats matching regexes in Ruby, as expected.

### Memory

```
$ bundle exec rake bench:memory

Scenario                                    Peak MB
---------------------------------------------------
baseline                                       21.4
pico_phone (light)                             29.8
pico_phone (heavy)                             40.7
pico_phone (heavy, +geo_name)                  39.9
pico_phone (heavy, +carrier_name)              39.7
pico_phone (heavy, +timezones)                 41.1
phonelib (light)                               24.2
phonelib (heavy)                               31.2
phonelib (heavy, +geo/carrier/timezone)       184.6
```

For validate/parse/format, memory use is comparable between the two, and pico_phone isn't the clear winner: it uses somewhat *more* than phonelib in this test (partly the cost of linking in libphonenumber's offline geocoder and carrier mapper, used below). Memory stays flat under sustained load for both (no leak).

phonelib's footprint balloons specifically when something calls `geo_name`, `carrier`, or `timezone`. Those lazily `Marshal.load` a ~4MB serialized data file — area-code-to-city, carrier, and timezone tables for every region in the world — into nested Ruby `Hash`/`Array`/`String` objects, then cache the whole thing in a class variable for the life of the process (see `phonelib/core.rb`, `@@phone_ext_data`).

pico_phone's `geo_name` (backed by libphonenumber's C++ offline geocoder, see [Geographic description](#geographic-description)) and `carrier_name` (see [Carrier lookup](#carrier-lookup)) don't have this problem: both load their prefix data lazily, one (country code, language) file at a time, and cache only what's actually queried — calling either 600k times across 30 regions above added no measurable RSS over the no-lookup baseline (both landed at or below the plain `pico_phone (heavy)` figure, within run-to-run noise). `timezones` (see [Timezone lookup](#timezone-lookup)) loads its single flat table (~86KB) once at first call and caches it for the life of the process — the one-time cost is negligible given the small table size.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Running `rake spec` will run the tests. If you make any changes to the `pico_phone.cpp` file, running `rake` will compile the gem with the new changes and run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

### Cross-platform verification

The extension links against libphonenumber, which behaves differently across platforms (system library versions, linking strategies, Abseil ABI). Before merging changes to the C++ extension, verify across all supported platforms:

```bash
# macOS arm64 — dynamic (default developer workflow)
bundle exec rake

# macOS arm64 — static (the NATIVE_BUILD path used for precompiled gems)
PICO_PHONE_NATIVE_BUILD=1 bundle exec rake compile spec
```

For Linux, use `verify_docker.sh` (requires Docker Desktop):

```bash
bash verify_docker.sh dynamic   # Ubuntu arm64 + x86_64, dynamic linking (~2 min each)
bash verify_docker.sh static    # Ubuntu arm64 + x86_64, NATIVE_BUILD=1 (~8–15 min each)
bash verify_docker.sh           # all four Linux combinations
```

The static Linux runs compile abseil, protobuf, and libphonenumber from source inside the container — that's what makes them slow. The dynamic runs use Ubuntu's packaged `libphonenumber-dev` and are much faster.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/gjack/pico_phone.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

pico_phone's precompiled native gems compile against and statically embed several third-party libraries — libphonenumber and Abseil (Apache License 2.0), protobuf (BSD-3-Clause), ICU (Unicode License v3), and, on macOS, Boost (Boost Software License 1.0) — plus Rice (BSD-2-Clause-style), which is compiled directly in as a header-only library. Their licenses are reproduced in full in [`THIRD_PARTY_LICENSES.txt`](THIRD_PARTY_LICENSES.txt), which ships with the gem.

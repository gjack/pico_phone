# PicoPhone

[![CI](https://github.com/gjack/pico_phone/actions/workflows/ci.yml/badge.svg)](https://github.com/gjack/pico_phone/actions/workflows/ci.yml)

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

Pre-compiled native gems are available for `arm64-darwin` (Apple Silicon Macs) and `x86_64-linux` (Ubuntu 24.04). On these platforms no system libraries or compiler are required — Bundler will select the right binary automatically.

On other platforms the gem compiles from source and requires libphonenumber:

```
# macOS
brew install libphonenumber

# Ubuntu/Debian
sudo apt-get install libphonenumber-dev
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


## Development

After checking out the repo, run `bin/setup` to install dependencies. Running `rake spec` will run the tests. If you make any changes to the `pico_phone.cpp` file, running `rake` will compile the gem with the new changes and run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/gjack/pico_phone.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

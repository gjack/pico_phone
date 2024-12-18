# PicoPhone

This gem was developed as an extension of Google's [libphonenumber C++ library](https://github.com/google/libphonenumber/tree/424617599369e7adba8a5d1509b910d9ce2e3e44/cpp), using a Ruby interface for C++ extensions called [Rice](https://github.com/ruby-rice/rice).

You can experiment with the code by running `bin/console` for an interactive prompt.

## Installation

You will first need to install `libphonenumber`. 

In MacOS, you can do this by running

```
brew install libphonenumber
```

You can also follow [the instructions in the repo](https://github.com/google/libphonenumber/tree/424617599369e7adba8a5d1509b910d9ce2e3e44/cpp) for other systems or for manual installation.

After cloning the repo, run `bundle install`. 

Notice that the gem has not been published and it's not compiled yet, so you will have to run the following in order to build the gem.

```
gem build pico_phone.gemspec
``` 

Once the gem is built, you should be able to install it

```
% gem install pico_phone-0.0.1.gem
Building native extensions. This could take a while...
Successfully installed pico_phone-0.0.1
Parsing documentation for pico_phone-0.0.1
Installing ri documentation for pico_phone-0.0.1
Done installing documentation for pico_phone after 0 seconds
1 gem installed
```

And, finally, try it out in IRB

```
irb(main):001> require "pico_phone"
=> true
irb(main):002> PicoPhone::VERSION
=> "0.0.1"
irb(main):003>
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

### Country codes and area codes

```
phone = PicoPhone.parse("5102745656", "US")

phone.country_code     # 1
phone.area_code        # 510

phone = PicoPhone.parse("0435582008", "AU")

phone.country_code     # 61
phone.area_code        # empty string because phone doesn't have one
```

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

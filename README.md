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

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/pico_phone.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

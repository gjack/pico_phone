# Contributing to pico_phone

Bug reports and pull requests are welcome on GitHub at https://github.com/gjack/pico_phone.

## Setup

```bash
git clone https://github.com/gjack/pico_phone.git
cd pico_phone
bundle install
bundle exec rake   # compiles the extension and runs the specs
```

On macOS, install the system dependencies first:

```bash
brew install libphonenumber protobuf abseil
```

On Ubuntu/Debian:

```bash
sudo apt-get install libphonenumber-dev libicu-dev
```

## Running the tests

```bash
bundle exec rake          # compile + spec
bundle exec rake spec     # spec only (no recompile)
bundle exec rake bench    # speed and memory benchmarks vs phonelib
```

## Making changes

**Ruby changes** (`lib/`, `spec/`): edit and run `bundle exec rake spec`.

**C++ changes** (`ext/pico_phone/pico_phone.cpp` or any `.cc`/`.h` file): run `bundle exec rake` to recompile before running specs. If you add a new public method, add a YARD annotation for it in `lib/pico_phone/phone_number.rb` — all methods are defined in C++ via Rice and are invisible to IDE tooling without it.

**Build system changes** (`ext/pico_phone/extconf.rb`, `ext/pico_phone/build_deps.sh`): test both linking paths:

```bash
bundle exec rake                                          # dynamic (system libphonenumber)
PICO_PHONE_NATIVE_BUILD=1 bundle exec rake compile spec  # static (vendored libraries)
```

## Cross-platform verification

Before opening a PR that touches the C++ extension or build system, verify on Linux as well. `verify_docker.sh` (repo root) runs the specs inside Ubuntu 24.04 containers for all supported Linux platforms and linking strategies (requires Docker):

```bash
bash verify_docker.sh dynamic   # fast (~2 min each): dynamic linking on arm64 + x86_64
bash verify_docker.sh static    # slow (~8–15 min each): NATIVE_BUILD on arm64 + x86_64
bash verify_docker.sh           # all four combinations
```

PRs that only touch Ruby files, specs, or documentation do not need Docker verification.

## Pull requests

- Keep PRs focused — one concern per PR makes review easier.
- New features should include specs and, if user-facing, a README example.
- The PR template will prompt you for a summary and test plan checklist.

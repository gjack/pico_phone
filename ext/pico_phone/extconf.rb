require "mkmf-rice"

$CXXFLAGS << ' -std=c++17'

# On macOS, libphonenumber's headers pull in protobuf and abseil transitively.
# Each is its own Homebrew formula with its own opt prefix, so we add all three.
# On Linux with libphonenumber-dev, all headers land in /usr/include and no
# extra paths are needed.
if RUBY_PLATFORM.include?('darwin')
  %w[libphonenumber protobuf abseil].each do |pkg|
    prefix = `brew --prefix #{pkg} 2>/dev/null`.strip
    next if prefix.empty?
    $INCFLAGS << " -I#{prefix}/include"
    $LDFLAGS  << " -L#{prefix}/lib"
  end
end

$LOCAL_LIBS << ' -lphonenumber'

unless find_header('phonenumbers/phonenumberutil.h')
  abort <<~MSG

    Could not find libphonenumber. Please install it before installing this gem:
      macOS:  brew install libphonenumber
      Ubuntu: sudo apt-get install libphonenumber-dev
      Fedora: sudo dnf install libphonenumber-devel
  MSG
end

create_makefile("pico_phone/pico_phone")

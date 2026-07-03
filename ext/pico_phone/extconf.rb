require "mkmf-rice"

$CXXFLAGS << ' -std=c++17'

VENDOR_INSTALL = File.expand_path("vendor/install", __dir__)
NATIVE_BUILD = ENV["PICO_PHONE_NATIVE_BUILD"] == "1"

if NATIVE_BUILD
  # Static linking against vendored libraries for native gem builds.
  # All five dependencies are baked into the .so — users need nothing installed.
  $INCFLAGS << " -I#{VENDOR_INSTALL}/include"

  static_libs = []
  static_libs << "#{VENDOR_INSTALL}/lib/libphonenumber.a"
  static_libs << "#{VENDOR_INSTALL}/lib/libprotobuf.a"
  static_libs += Dir["#{VENDOR_INSTALL}/lib/libabsl_*.a"].sort

  if RUBY_PLATFORM.include?("darwin")
    boost_prefix = `brew --prefix boost 2>/dev/null`.strip
    icu_prefix   = `brew --prefix icu4c@78 2>/dev/null`.strip

    %w[libboost_date_time libboost_thread libboost_atomic].each do |lib|
      static_libs << "#{boost_prefix}/lib/#{lib}.a"
    end

    %w[libicui18n libicuuc libicudata].each do |lib|
      static_libs << "#{icu_prefix}/lib/#{lib}.a"
    end
  end

  $LOCAL_LIBS << " " + static_libs.join(" ")

  unless find_header("phonenumbers/phonenumberutil.h")
    abort "Could not find phonenumberutil.h in #{VENDOR_INSTALL}/include — run build_deps.sh first"
  end
else
  # Dynamic linking against system/Homebrew libraries (default developer workflow).
  if RUBY_PLATFORM.include?("darwin")
    %w[libphonenumber protobuf abseil].each do |pkg|
      prefix = `brew --prefix #{pkg} 2>/dev/null`.strip
      next if prefix.empty?
      $INCFLAGS << " -I#{prefix}/include"
      $LDFLAGS  << " -L#{prefix}/lib"
    end
  end

  $LOCAL_LIBS << " -lphonenumber"

  unless find_header("phonenumbers/phonenumberutil.h")
    abort <<~MSG

      Could not find libphonenumber. Please install it before installing this gem:
        macOS:  brew install libphonenumber
        Ubuntu: sudo apt-get install libphonenumber-dev
        Fedora: sudo dnf install libphonenumber-devel
    MSG
  end
end

create_makefile("pico_phone/pico_phone")

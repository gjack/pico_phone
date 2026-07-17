require "mkmf-rice"

$CXXFLAGS << ' -std=c++17'

# carrier_mapper.cc needs AreaCodeMap/MappingFileProvider/the
# CountryLanguages+PrefixDescriptions structs, none of which libphonenumber
# installs publicly (only phonenumber_offline_geocoder.h is installed) in
# either build path below. Headers vendored verbatim under
# vendor_headers/phonenumbers/geocoding/ -- see that directory's own
# comments. Needed unconditionally, regardless of NATIVE_BUILD.
$INCFLAGS << " -I#{File.expand_path("vendor_headers", __dir__)}"

VENDOR_INSTALL = File.expand_path("vendor/install", __dir__)
NATIVE_BUILD = ENV["PICO_PHONE_NATIVE_BUILD"] == "1"

if NATIVE_BUILD
  # Static linking against vendored libraries for native gem builds.
  # All five dependencies are baked into the .so — users need nothing installed.
  $INCFLAGS << " -I#{VENDOR_INSTALL}/include"

  static_libs = []
  # geocoding depends on symbols from phonenumber, so it must precede it in
  # the static link order.
  static_libs << "#{VENDOR_INSTALL}/lib/libgeocoding.a"
  static_libs << "#{VENDOR_INSTALL}/lib/libphonenumber.a"
  static_libs << "#{VENDOR_INSTALL}/lib/libprotobuf.a"
  # protobuf's own transitive static deps (UTF-8 validation, upb). Whole-archive
  # linking (below) force-includes every object in libprotobuf.a, including
  # members that reference these, so they must be present even though nothing
  # in our own code calls them directly. libutf8_range and libutf8_validity are
  # two CMake target names for the exact same compiled object (utf8_range.c.o)
  # in this protobuf version — link only one, or whole-archive pulls in both
  # copies and the linker sees duplicate symbols.
  %w[libutf8_range libupb].each do |lib|
    path = "#{VENDOR_INSTALL}/lib/#{lib}.a"
    static_libs << path if File.exist?(path)
  end
  static_libs += Dir["#{VENDOR_INSTALL}/lib/libabsl_*.a"].sort

  if RUBY_PLATFORM.include?("darwin")
    boost_prefix = `brew --prefix boost 2>/dev/null`.strip
    icu_prefix   = `brew --prefix icu4c@78 2>/dev/null`.strip

    $INCFLAGS << " -I#{icu_prefix}/include"

    %w[libboost_date_time libboost_thread libboost_atomic].each do |lib|
      static_libs << "#{boost_prefix}/lib/#{lib}.a"
    end

    %w[libicui18n libicuuc libicudata].each do |lib|
      static_libs << "#{icu_prefix}/lib/#{lib}.a"
    end
  else
    # Linux: libphonenumber was built with USE_BOOST=OFF so no Boost needed.
    # Ubuntu's libicu-dev static archives are not compiled with -fPIC and cannot
    # be linked into a shared object. Link ICU dynamically instead — libicu74 is
    # part of the Ubuntu 24.04 base system and is present in the target environment.
    # ICU headers (for the geocoder) come from the system libicu-dev package.
    $LOCAL_LIBS << " -licui18n -licuuc -licudata -lpthread -ldl"
  end

  # Adding the geocoder introduces a circular reference among several small
  # Abseil static archives (e.g. synchronization <-> log_internal). A plain
  # left-to-right static link only pulls in archive members that satisfy an
  # already-outstanding undefined symbol, which for a -bundle target isn't
  # even validated until dlopen time — so a missing member surfaces as a
  # runtime "symbol not found in flat namespace" error, not a link failure.
  # Force-load every member of our own vendored archives so nothing gets
  # silently dropped.
  if RUBY_PLATFORM.include?("darwin")
    $LOCAL_LIBS << " -Wl,-all_load " + static_libs.join(" ")
  else
    $LOCAL_LIBS << " -Wl,--whole-archive " + static_libs.join(" ") + " -Wl,--no-whole-archive"
  end

  unless find_header("phonenumbers/phonenumberutil.h")
    abort "Could not find phonenumberutil.h in #{VENDOR_INSTALL}/include — run build_deps.sh first"
  end

  unless find_header("phonenumbers/geocoding/phonenumber_offline_geocoder.h")
    abort "Could not find the geocoding header in #{VENDOR_INSTALL}/include — run build_deps.sh first"
  end
else
  # Dynamic linking against system/Homebrew libraries (default developer workflow).
  if RUBY_PLATFORM.include?("darwin")
    # icu4c@78 is already a transitive dependency of Homebrew's libphonenumber
    # formula (which itself ships geocoding), so no extra install step needed.
    %w[libphonenumber protobuf abseil icu4c@78].each do |pkg|
      prefix = `brew --prefix #{pkg} 2>/dev/null`.strip
      next if prefix.empty?
      $INCFLAGS << " -I#{prefix}/include"
      $LDFLAGS  << " -L#{prefix}/lib"
    end
  end

  $LOCAL_LIBS << " -lphonenumber -lgeocoding"

  unless find_header("phonenumbers/phonenumberutil.h")
    abort <<~MSG

      Could not find libphonenumber. Please install it before installing this gem:
        macOS:  brew install libphonenumber
        Ubuntu: sudo apt-get install libphonenumber-dev libicu-dev
        Fedora: sudo dnf install libphonenumber-devel
    MSG
  end

  unless find_header("phonenumbers/geocoding/phonenumber_offline_geocoder.h")
    abort <<~MSG

      Found libphonenumber but not its geocoding headers/library. On Debian/Ubuntu
      this also needs ICU development headers:
        sudo apt-get install libphonenumber-dev libicu-dev
    MSG
  end
end

create_makefile("pico_phone/pico_phone")

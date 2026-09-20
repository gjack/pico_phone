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
  # Linked normally (not force-loaded) after static_libs -- see the link line below.
  icu_libs = []
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
    # Linux (glibc and musl): libphonenumber was built with USE_BOOST=OFF so no
    # Boost needed. build_deps.sh compiles a static, -fPIC, data-filtered ICU into
    # VENDOR_INSTALL alongside abseil/protobuf/libphonenumber, and we link that
    # instead of a system ICU: a dynamic link would tie the .so to one distro's ICU
    # SONAME (libicu74 on Ubuntu 24.04, absent on Debian), and a distro's own
    # static ICU archives generally aren't built -fPIC so can't go into a shared
    # object either. ICU is kept out of the force-load group below: it has no
    # circular references with the other archives, and force-loading all of it
    # would embed every ICU object (~5MB) libphonenumber never calls.
    icu_libs = %w[libicui18n libicuuc libicudata].map { |lib| "#{VENDOR_INSTALL}/lib/#{lib}.a" }
    $LOCAL_LIBS << " -lpthread -ldl"
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
    $LOCAL_LIBS << " -Wl,--whole-archive " + static_libs.join(" ") + " -Wl,--no-whole-archive " +
                   icu_libs.join(" ")
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

# Ruby builds with --enable-shared (used by ruby/setup-ruby, official Docker images, Homebrew, and
# most system packages) make mkmf hard-link every extension against a build-specific libruby.so/
# .dylib via LIBRUBYARG_SHARED, on top of -Wl,-undefined,dynamic_lookup which alone is already
# sufficient for symbol resolution at load time. On macOS that dependency is an absolute path tied
# to wherever that particular Ruby happened to be installed -- which cannot exist on any other
# machine, breaking every precompiled native gem once it's moved off the machine that built it,
# regardless of Ruby version. Drop it so the compiled extension only depends on libraries it
# actually needs.
$LIBRUBYARG_SHARED = ""
$LIBRUBYARG = ""

create_makefile("pico_phone/pico_phone")

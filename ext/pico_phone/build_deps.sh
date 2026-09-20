#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/vendor/src"
BUILD_DIR="$SCRIPT_DIR/vendor/build"
INSTALL_DIR="$SCRIPT_DIR/vendor/install"

mkdir -p "$SRC_DIR" "$BUILD_DIR" "$INSTALL_DIR"

# macOS ships `shasum` (Perl-based) but no `sha256sum`; glibc/musl Linux ship
# `sha256sum` (coreutils/busybox) and usually not `shasum`. Support both.
verify_sha256() {
  local expected="$1" file="$2"
  if command -v shasum >/dev/null 2>&1; then
    echo "${expected}  ${file}" | shasum -a 256 -c -
  else
    echo "${expected}  ${file}" | sha256sum -c -
  fi
}

ABSEIL_VERSION="20260817.0"
ABSEIL_URL="https://github.com/abseil/abseil-cpp/archive/refs/tags/${ABSEIL_VERSION}.tar.gz"
ABSEIL_SHA256="f7e05179df39c45434cad433f5783840bb3788ef322976f9138bc6b72b3a107d"
ABSEIL_TARBALL="$SRC_DIR/abseil-${ABSEIL_VERSION}.tar.gz"
ABSEIL_SRC="$BUILD_DIR/abseil-cpp-${ABSEIL_VERSION}"
ABSEIL_BUILD="$BUILD_DIR/abseil-build"

OS="$(uname)"
CPU_COUNT=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)

if [ -f "$INSTALL_DIR/lib/libabsl_base.a" ]; then
  echo "==> Abseil already installed, skipping"
else
  echo "==> Downloading abseil ${ABSEIL_VERSION}..."
  if [ ! -f "$ABSEIL_TARBALL" ]; then
    curl -L "$ABSEIL_URL" -o "$ABSEIL_TARBALL"
  else
    echo "    already downloaded, skipping"
  fi

  echo "==> Verifying checksum..."
  verify_sha256 "$ABSEIL_SHA256" "$ABSEIL_TARBALL"

  echo "==> Extracting..."
  if [ ! -d "$ABSEIL_SRC" ]; then
    tar -xzf "$ABSEIL_TARBALL" -C "$BUILD_DIR"
  else
    echo "    already extracted, skipping"
  fi

  echo "==> Configuring abseil..."
  cmake \
    -S "$ABSEIL_SRC" \
    -B "$ABSEIL_BUILD" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DABSL_BUILD_TESTING=OFF \
    -DCMAKE_CXX_STANDARD=17

  echo "==> Building abseil (using ${CPU_COUNT} cores)..."
  cmake --build "$ABSEIL_BUILD" --parallel "$CPU_COUNT"

  echo "==> Installing abseil to ${INSTALL_DIR}..."
  cmake --install "$ABSEIL_BUILD"

  echo "==> Abseil done."
  ls "$INSTALL_DIR/lib/libabsl_"*.a | wc -l | xargs echo "    libabsl_*.a count:"
fi

# ---------------------------------------------------------------------------
# protobuf
# ---------------------------------------------------------------------------

PROTOBUF_VERSION="36.1"
PROTOBUF_URL="https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protobuf-${PROTOBUF_VERSION}.tar.gz"
PROTOBUF_SHA256="dc74fa582f559cbd31614ddfefb4868f43c919d7184bde514bb47f90c6025eb8"
PROTOBUF_TARBALL="$SRC_DIR/protobuf-${PROTOBUF_VERSION}.tar.gz"
PROTOBUF_SRC="$BUILD_DIR/protobuf-${PROTOBUF_VERSION}"
PROTOBUF_BUILD="$BUILD_DIR/protobuf-build"

if [ -f "$INSTALL_DIR/lib/libprotobuf.a" ]; then
  echo "==> Protobuf already installed, skipping"
else
  echo "==> Downloading protobuf ${PROTOBUF_VERSION}..."
  if [ ! -f "$PROTOBUF_TARBALL" ]; then
    curl -L "$PROTOBUF_URL" -o "$PROTOBUF_TARBALL"
  else
    echo "    already downloaded, skipping"
  fi

  echo "==> Verifying checksum..."
  verify_sha256 "$PROTOBUF_SHA256" "$PROTOBUF_TARBALL"

  echo "==> Extracting..."
  if [ ! -d "$PROTOBUF_SRC" ]; then
    tar -xzf "$PROTOBUF_TARBALL" -C "$BUILD_DIR"
  else
    echo "    already extracted, skipping"
  fi

  echo "==> Configuring protobuf..."
  cmake \
    -S "$PROTOBUF_SRC" \
    -B "$PROTOBUF_BUILD" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_CXX_STANDARD=17 \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_BUILD_EXAMPLES=OFF \
    -Dprotobuf_ABSL_PROVIDER=package \
    -DCMAKE_PREFIX_PATH="$INSTALL_DIR"

  echo "==> Building protobuf (using ${CPU_COUNT} cores)..."
  cmake --build "$PROTOBUF_BUILD" --parallel "$CPU_COUNT"

  echo "==> Installing protobuf to ${INSTALL_DIR}..."
  cmake --install "$PROTOBUF_BUILD"

  echo "==> Protobuf done."
  ls "$INSTALL_DIR/lib/libprotobuf"*.a 2>/dev/null | xargs echo "    protobuf archives:"
fi

# ---------------------------------------------------------------------------
# ICU (all Linux -- Darwin links Homebrew's instead). We build our own static,
# -fPIC copy rather than linking a system one: musl has no ABI-stable system
# ICU to rely on, and on glibc a dynamic link ties the resulting .so to one
# distro's ICU SONAME (e.g. libicu74 on Ubuntu 24.04, which doesn't exist on
# Debian) while the distro's own static archives aren't built -fPIC and can't
# go into a shared object.
#
# ICU's full data is ~32MB. pico_phone never calls ICU directly; libphonenumber
# uses it for regexes/case folding/character properties (core data, kept) and, in
# the offline geocoder, for localized country names (the `region` tree, kept for
# every language so geo_name(lang) keeps working). Everything else -- collation,
# break iterators, currencies, time zones, units, transliteration, converters,
# language/script names, all locales but `en` -- is dropped via ICU's data filter,
# which takes the data down to ~2.4MB. Two build details that make the filter
# actually apply:
#   * icu4c-*-sources.tgz has no data sources (only a prebuilt full icudt*.dat),
#     so the separate icu4c-*-data.zip is overlaid onto it, and
#   * data/Makefile.in uses a prebuilt data/in/icudt*.dat verbatim if present, so
#     it is deleted to force a from-source (filtered) data build.
# Needs python3 (ICU's data builder). The filter lives in this script so that the
# release workflow's cache key (a hash of this file) changes whenever it does.
# ---------------------------------------------------------------------------

if [[ "$OS" != "Darwin" ]]; then
  ICU_VERSION="78.3"
  ICU_BASE_URL="https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION}"
  ICU_URL="${ICU_BASE_URL}/icu4c-${ICU_VERSION}-sources.tgz"
  ICU_DATA_URL="${ICU_BASE_URL}/icu4c-${ICU_VERSION}-data.zip"
  ICU_SHA512_LISTING_URL="${ICU_BASE_URL}/SHASUM512.txt"
  ICU_TARBALL="$SRC_DIR/icu4c-${ICU_VERSION}-sources.tgz"
  ICU_DATA_ZIP="$SRC_DIR/icu4c-${ICU_VERSION}-data.zip"
  ICU_SRC="$BUILD_DIR/icu-${ICU_VERSION}/icu/source"
  ICU_FILTER="$BUILD_DIR/icu-data-filter.json"

  ICU_FILTER_JSON='{
  "strategy": "subtractive",
  "featureFilters": {
    "locales_tree": { "filterType": "language", "includelist": ["en"] },
    "brkitr_tree": "exclude",
    "brkitr_rules": "exclude",
    "brkitr_dictionaries": "exclude",
    "brkitr_lstm": "exclude",
    "brkitr_adaboost": "exclude",
    "coll_tree": "exclude",
    "coll_ucadata": "exclude",
    "curr_tree": "exclude",
    "curr_supplemental": "exclude",
    "lang_tree": "exclude",
    "zone_tree": "exclude",
    "zone_supplemental": "exclude",
    "unit_tree": "exclude",
    "rbnf_tree": "exclude",
    "translit": "exclude",
    "confusables": "exclude",
    "stringprep": "exclude",
    "conversion_mappings": "exclude",
    "unames": "exclude",
    "ulayout": "exclude",
    "uemoji": "exclude"
  }
}'

  # Identifies "this ICU version + this filter" so a stale vendor/install left by an
  # older build_deps.sh (e.g. full unfiltered ICU) gets rebuilt instead of reused.
  ICU_STAMP="$INSTALL_DIR/lib/.icu-stamp-${ICU_VERSION}-$(printf '%s' "$ICU_VERSION $ICU_FILTER_JSON" | cksum | cut -d' ' -f1)"

  if [ -f "$INSTALL_DIR/lib/libicudata.a" ] && [ -f "$ICU_STAMP" ]; then
    echo "==> ICU already installed, skipping"
  else
    command -v python3 >/dev/null 2>&1 || {
      echo "python3 is required to build ICU's filtered data (install python3 and re-run)" >&2
      exit 1
    }

    # Start clean: drop any ICU from an older recipe (different version/filter/unfiltered).
    rm -f "$INSTALL_DIR"/lib/libicu*.a "$INSTALL_DIR"/lib/.icu-stamp-*
    rm -rf "$BUILD_DIR/icu-${ICU_VERSION}"

    echo "==> Downloading ICU ${ICU_VERSION}..."
    for pair in "$ICU_TARBALL|$ICU_URL" "$ICU_DATA_ZIP|$ICU_DATA_URL"; do
      if [ ! -f "${pair%%|*}" ]; then
        curl -L "${pair##*|}" -o "${pair%%|*}"
      else
        echo "    ${pair%%|*} already downloaded, skipping"
      fi
    done

    echo "==> Verifying checksums..."
    curl -sL "$ICU_SHA512_LISTING_URL" -o "$SRC_DIR/icu-SHASUM512.txt"
    ( cd "$SRC_DIR" && grep -e "icu4c-${ICU_VERSION}-sources.tgz\$" -e "icu4c-${ICU_VERSION}-data.zip\$" icu-SHASUM512.txt | sha512sum -c - )

    echo "==> Extracting (sources + data sources)..."
    mkdir -p "$BUILD_DIR/icu-${ICU_VERSION}"
    tar -xzf "$ICU_TARBALL" -C "$BUILD_DIR/icu-${ICU_VERSION}"
    python3 -m zipfile -e "$ICU_DATA_ZIP" "$ICU_SRC"
    rm -f "$ICU_SRC"/data/in/icudt*.dat
    printf '%s\n' "$ICU_FILTER_JSON" > "$ICU_FILTER"

    echo "==> Configuring ICU (static, PIC, filtered data; tools left enabled --" \
         "the data build needs them)..."
    ( cd "$ICU_SRC" && \
      ICU_DATA_FILTER_FILE="$ICU_FILTER" \
      CFLAGS="-fPIC -O2" CXXFLAGS="-fPIC -O2 -std=c++17" \
      ./runConfigureICU Linux \
        --prefix="$INSTALL_DIR" \
        --enable-static \
        --disable-shared \
        --disable-tests \
        --disable-samples \
        --disable-extras )

    # GNU make is `gmake` on Alpine/BSD but plain `make` on Debian/Ubuntu.
    ICU_MAKE="$(command -v gmake || command -v make)"

    echo "==> Building ICU (using ${CPU_COUNT} cores)..."
    ( cd "$ICU_SRC" && "$ICU_MAKE" -j"$CPU_COUNT" )

    echo "==> Installing ICU to ${INSTALL_DIR}..."
    ( cd "$ICU_SRC" && "$ICU_MAKE" install )

    touch "$ICU_STAMP"
    echo "==> ICU done."
    ls -la "$INSTALL_DIR/lib/libicu"*.a 2>/dev/null
  fi
fi

# ---------------------------------------------------------------------------
# libphonenumber
# ---------------------------------------------------------------------------

LIBPHONE_VERSION="9.0.39"
LIBPHONE_URL="https://github.com/google/libphonenumber/archive/refs/tags/v${LIBPHONE_VERSION}.tar.gz"
LIBPHONE_SHA256="e30c2aea5b66f53821d1eb971f81b9be1350e4b04a4577c8283803a1c8c5210b"
LIBPHONE_TARBALL="$SRC_DIR/libphonenumber-${LIBPHONE_VERSION}.tar.gz"
LIBPHONE_SRC="$BUILD_DIR/libphonenumber-${LIBPHONE_VERSION}"
LIBPHONE_BUILD="$BUILD_DIR/libphonenumber-build"

BOOST_PATCH_URL="https://github.com/google/libphonenumber/commit/72c1023fbf00fc48866acab05f6ccebcae7f3213.patch?full_index=1"
BOOST_PATCH_SHA256="6bce9d77b45f35a84ef39831bf2cca793b11aa7b92bd6d71000397d3176f0345"
BOOST_PATCH_FILE="$SRC_DIR/libphonenumber-boost-fix.patch"

if [[ "$OS" == "Darwin" ]]; then
  BOOST_PREFIX="$(brew --prefix boost)"
  ICU_PREFIX="$(brew --prefix icu4c@78)"
  PHONE_CMAKE_PREFIX="${INSTALL_DIR};${BOOST_PREFIX};${ICU_PREFIX}"
  USE_BOOST="ON"
else
  # Linux: libphonenumber built without Boost (uses std::mutex/thread via C++17).
  # Our own static ICU was just installed into INSTALL_DIR above, so
  # CMAKE_PREFIX_PATH=INSTALL_DIR is enough to find it on glibc and musl alike.
  PHONE_CMAKE_PREFIX="${INSTALL_DIR}"
  USE_BOOST="OFF"
fi

if [ -f "$INSTALL_DIR/lib/libphonenumber.a" ]; then
  echo "==> libphonenumber already installed, skipping"
else
  echo "==> Downloading libphonenumber ${LIBPHONE_VERSION}..."
  if [ ! -f "$LIBPHONE_TARBALL" ]; then
    curl -L "$LIBPHONE_URL" -o "$LIBPHONE_TARBALL"
  else
    echo "    already downloaded, skipping"
  fi

  echo "==> Verifying checksum..."
  verify_sha256 "$LIBPHONE_SHA256" "$LIBPHONE_TARBALL"

  echo "==> Extracting..."
  if [ ! -d "$LIBPHONE_SRC" ]; then
    tar -xzf "$LIBPHONE_TARBALL" -C "$BUILD_DIR"
  else
    echo "    already extracted, skipping"
  fi

  echo "==> Downloading Boost compatibility patch..."
  if [ ! -f "$BOOST_PATCH_FILE" ]; then
    curl -L "$BOOST_PATCH_URL" -o "$BOOST_PATCH_FILE"
    verify_sha256 "$BOOST_PATCH_SHA256" "$BOOST_PATCH_FILE"
  else
    echo "    already downloaded, skipping"
  fi

  echo "==> Applying Boost patch..."
  cd "$LIBPHONE_SRC"
  if patch -p1 --forward --silent < "$BOOST_PATCH_FILE" 2>/dev/null; then
    echo "    patch applied"
  else
    echo "    patch already applied, skipping"
  fi
  cd "$SCRIPT_DIR"

  # The geocoder still uses absl::MutexLock's pointer-taking constructor,
  # which our vendored Abseil (20260526.0) deprecates and -Werror turns into
  # a build failure. Two call sites, fixed in place rather than via a
  # hosted patch file since it's this small.
  GEOCODER_CC="$LIBPHONE_SRC/cpp/src/phonenumbers/geocoding/phonenumber_offline_geocoder.cc"
  if [ -f "$GEOCODER_CC" ]; then
    echo "==> Patching geocoder for deprecated absl::MutexLock(ptr) usage..."
    sed -i.bak 's/absl::MutexLock l(&mu_);/absl::MutexLock l(mu_);/' "$GEOCODER_CC"
    rm -f "$GEOCODER_CC.bak"
  fi

  echo "==> Configuring libphonenumber..."
  cmake \
    -S "$LIBPHONE_SRC/cpp" \
    -B "$LIBPHONE_BUILD" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_PREFIX_PATH="${PHONE_CMAKE_PREFIX}" \
    -DUSE_BOOST="${USE_BOOST}" \
    -DREGENERATE_METADATA=OFF \
    -DBUILD_GEOCODER=ON \
    -DBUILD_TESTING=OFF

  echo "==> Building libphonenumber (using ${CPU_COUNT} cores)..."
  cmake --build "$LIBPHONE_BUILD" --parallel "$CPU_COUNT"

  echo "==> Installing libphonenumber to ${INSTALL_DIR}..."
  cmake --install "$LIBPHONE_BUILD"

  echo ""
  echo "==> All done."
  ls "$INSTALL_DIR/lib/libphonenumber"*.a 2>/dev/null | xargs echo "    libphonenumber archives:"
fi

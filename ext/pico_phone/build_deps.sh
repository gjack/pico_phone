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
IS_MUSL=false
if ruby -e 'exit(RUBY_PLATFORM.include?("musl") ? 0 : 1)' 2>/dev/null; then
  IS_MUSL=true
fi

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
# ICU (musl only -- glibc Linux links the system's dynamic ICU instead, and
# Darwin links Homebrew's. musl has no equivalent system package we can rely
# on being ABI-compatible, so we build our own static copy here, the same way
# Darwin's static-link native builds do for boost.)
# ---------------------------------------------------------------------------

if [[ "$IS_MUSL" == "true" ]]; then
  ICU_VERSION="78.3"
  ICU_URL="https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION}/icu4c-${ICU_VERSION}-sources.tgz"
  ICU_SHA512_LISTING_URL="https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION}/SHASUM512.txt"
  ICU_TARBALL="$SRC_DIR/icu4c-${ICU_VERSION}-sources.tgz"
  ICU_SRC="$BUILD_DIR/icu-${ICU_VERSION}/icu/source"

  if [ -f "$INSTALL_DIR/lib/libicudata.a" ]; then
    echo "==> ICU already installed, skipping"
  else
    echo "==> Downloading ICU ${ICU_VERSION}..."
    if [ ! -f "$ICU_TARBALL" ]; then
      curl -L "$ICU_URL" -o "$ICU_TARBALL"
    else
      echo "    already downloaded, skipping"
    fi

    echo "==> Verifying checksum..."
    curl -sL "$ICU_SHA512_LISTING_URL" -o "$SRC_DIR/icu-SHASUM512.txt"
    ( cd "$SRC_DIR" && grep "icu4c-${ICU_VERSION}-sources.tgz\$" icu-SHASUM512.txt | sha512sum -c - )

    echo "==> Extracting..."
    if [ ! -d "$ICU_SRC" ]; then
      mkdir -p "$BUILD_DIR/icu-${ICU_VERSION}"
      tar -xzf "$ICU_TARBALL" -C "$BUILD_DIR/icu-${ICU_VERSION}"
    else
      echo "    already extracted, skipping"
    fi

    echo "==> Configuring ICU (static, PIC; tools left enabled -- pkgdata needs" \
         "them to package the prebuilt locale data that ships in data/in)..."
    ( cd "$ICU_SRC" && \
      CFLAGS="-fPIC -O2" CXXFLAGS="-fPIC -O2 -std=c++17" \
      ./runConfigureICU Linux \
        --prefix="$INSTALL_DIR" \
        --enable-static \
        --disable-shared \
        --disable-tests \
        --disable-samples \
        --disable-extras )

    echo "==> Building ICU (using ${CPU_COUNT} cores)..."
    ( cd "$ICU_SRC" && gmake -j"$CPU_COUNT" )

    echo "==> Installing ICU to ${INSTALL_DIR}..."
    ( cd "$ICU_SRC" && gmake install )

    echo "==> ICU done."
    ls -la "$INSTALL_DIR/lib/libicu"*.a 2>/dev/null
  fi
fi

# ---------------------------------------------------------------------------
# libphonenumber
# ---------------------------------------------------------------------------

LIBPHONE_VERSION="9.0.38"
LIBPHONE_URL="https://github.com/google/libphonenumber/archive/refs/tags/v${LIBPHONE_VERSION}.tar.gz"
LIBPHONE_SHA256="75e0a15fdc8fab9efc8a101d1d36ba3866c407889faae6c025e6aac58957da77"
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
  # glibc: ICU comes from the system (libicu-dev), found via CMake's default
  # search paths. musl: our own static ICU was just installed into
  # INSTALL_DIR above, so CMAKE_PREFIX_PATH=INSTALL_DIR covers both cases
  # without branching here. Boost not needed either way.
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

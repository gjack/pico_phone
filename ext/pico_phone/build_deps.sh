#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/vendor/src"
BUILD_DIR="$SCRIPT_DIR/vendor/build"
INSTALL_DIR="$SCRIPT_DIR/vendor/install"

mkdir -p "$SRC_DIR" "$BUILD_DIR" "$INSTALL_DIR"

ABSEIL_VERSION="20260107.1"
ABSEIL_URL="https://github.com/abseil/abseil-cpp/archive/refs/tags/${ABSEIL_VERSION}.tar.gz"
ABSEIL_SHA256="4314e2a7cbac89cac25a2f2322870f343d81579756ceff7f431803c2c9090195"
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
  echo "${ABSEIL_SHA256}  ${ABSEIL_TARBALL}" | shasum -a 256 -c -

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

PROTOBUF_VERSION="35.1"
PROTOBUF_URL="https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protobuf-${PROTOBUF_VERSION}.tar.gz"
PROTOBUF_SHA256="f0b6838e7522a8da96126d487068c959bc624926368f3024ac8fd03abd0a1ac4"
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
  echo "${PROTOBUF_SHA256}  ${PROTOBUF_TARBALL}" | shasum -a 256 -c -

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
# libphonenumber
# ---------------------------------------------------------------------------

LIBPHONE_VERSION="9.0.33"
LIBPHONE_URL="https://github.com/google/libphonenumber/archive/refs/tags/v${LIBPHONE_VERSION}.tar.gz"
LIBPHONE_SHA256="649e13846a7c49ca91ddfbf649e8feeafe7b04b590de4ce64cedfbf28d37b2ee"
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
  # ICU comes from the system (libicu-dev). Boost not needed.
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
  echo "${LIBPHONE_SHA256}  ${LIBPHONE_TARBALL}" | shasum -a 256 -c -

  echo "==> Extracting..."
  if [ ! -d "$LIBPHONE_SRC" ]; then
    tar -xzf "$LIBPHONE_TARBALL" -C "$BUILD_DIR"
  else
    echo "    already extracted, skipping"
  fi

  echo "==> Downloading Boost compatibility patch..."
  if [ ! -f "$BOOST_PATCH_FILE" ]; then
    curl -L "$BOOST_PATCH_URL" -o "$BOOST_PATCH_FILE"
    echo "${BOOST_PATCH_SHA256}  ${BOOST_PATCH_FILE}" | shasum -a 256 -c -
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
    -DBUILD_GEOCODER=OFF \
    -DBUILD_TESTING=OFF

  echo "==> Building libphonenumber (using ${CPU_COUNT} cores)..."
  cmake --build "$LIBPHONE_BUILD" --parallel "$CPU_COUNT"

  echo "==> Installing libphonenumber to ${INSTALL_DIR}..."
  cmake --install "$LIBPHONE_BUILD"

  echo ""
  echo "==> All done."
  ls "$INSTALL_DIR/lib/libphonenumber"*.a 2>/dev/null | xargs echo "    libphonenumber archives:"
fi

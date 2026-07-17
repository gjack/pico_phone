#!/usr/bin/env bash
# Cross-platform verification: runs compile + spec inside Ubuntu 24.04
# containers for the four Linux build combinations (aarch64/x86_64 × dynamic/static).
#
# Prerequisites: Docker running, with linux/amd64 emulation available
# (Docker Desktop on Mac ships QEMU for this by default).
#
# Usage:
#   bash verify_docker.sh              # runs all four combinations
#   bash verify_docker.sh dynamic      # dynamic builds only
#   bash verify_docker.sh static       # NATIVE_BUILD static builds only
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
FILTER="${1:-all}"
PASS=0
FAIL=0

run_combo() {
  local label="$1"
  local platform="$2"
  local native_build="$3"

  echo ""
  echo "=========================================="
  echo "  $label"
  echo "=========================================="

  # Compute platform-specific values before building the inline script,
  # so interpolation is unambiguous (no subshell expansion inside the string).
  if [ "$native_build" = "1" ]; then
    # NATIVE_BUILD: no system libphonenumber needed; we build from vendored source.
    local extra_pkg=""
    # Remove macOS binaries and CMake build dirs (CMakeCache.txt embeds the
    # macOS source path, causing cmake to refuse to re-run on a different path).
    # Keep vendor/build/abseil-cpp-*/ etc. (extracted source, platform-agnostic)
    # and vendor/src/ (downloaded tarballs) so build_deps.sh doesn't re-download.
    local build_cmd="rm -rf /tmp/pico_phone/ext/pico_phone/vendor/install /tmp/pico_phone/ext/pico_phone/vendor/build/abseil-build /tmp/pico_phone/ext/pico_phone/vendor/build/protobuf-build /tmp/pico_phone/ext/pico_phone/vendor/build/libphonenumber-build && bash /tmp/pico_phone/ext/pico_phone/build_deps.sh && PICO_PHONE_NATIVE_BUILD=1 bundle exec rake compile spec"
  else
    # Dynamic: system libphonenumber-dev supplies headers + shared library.
    local extra_pkg="libphonenumber-dev"
    local build_cmd="bundle exec rake"
  fi

  local inline_script="
set -euo pipefail
apt-get update -q
apt-get install -y --no-install-recommends \
  ruby ruby-dev bundler cmake build-essential git curl ca-certificates \
  libicu-dev ${extra_pkg}
cp -r /work /tmp/pico_phone
cd /tmp/pico_phone
bundle install --quiet
${build_cmd}
"

  if docker run --rm \
       --platform "$platform" \
       -v "${REPO_ROOT}:/work:ro" \
       ubuntu:24.04 bash -c "$inline_script" 2>&1; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

if [ "$FILTER" = "all" ] || [ "$FILTER" = "dynamic" ]; then
  run_combo "aarch64-linux  dynamic"       "linux/arm64" "0"
  run_combo "x86_64-linux   dynamic"       "linux/amd64" "0"
fi

if [ "$FILTER" = "all" ] || [ "$FILTER" = "static" ]; then
  run_combo "aarch64-linux  NATIVE_BUILD=1" "linux/arm64" "1"
  run_combo "x86_64-linux   NATIVE_BUILD=1" "linux/amd64" "1"
fi

echo ""
echo "=========================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "=========================================="
[ "$FAIL" -eq 0 ]

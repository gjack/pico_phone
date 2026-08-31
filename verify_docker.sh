#!/usr/bin/env bash
# Cross-platform verification: runs compile + spec inside containers for the
# six Linux build combinations -- glibc (Ubuntu 24.04) aarch64/x86_64 ×
# dynamic/static, plus musl (Alpine) aarch64/x86_64, static only (there's no
# packaged libphonenumber-dev equivalent on Alpine to link against
# dynamically, so NATIVE_BUILD is the only way musl ever works at all).
#
# Prerequisites: Docker running, with linux/amd64 emulation available
# (Docker Desktop on Mac ships QEMU for this by default).
#
# Usage:
#   bash verify_docker.sh              # runs all six combinations
#   bash verify_docker.sh dynamic      # glibc dynamic builds only
#   bash verify_docker.sh static       # glibc NATIVE_BUILD static builds only
#   bash verify_docker.sh musl         # musl builds only (always static)
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
    local build_cmd="bash ext/pico_phone/build_deps.sh && PICO_PHONE_NATIVE_BUILD=1 bundle exec rake compile spec"
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
mkdir -p /tmp/pico_phone
git -C /work ls-files -z | tar --null -C /work -T - -czf /tmp/repo.tar.gz
tar -xzf /tmp/repo.tar.gz -C /tmp/pico_phone
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

run_musl_combo() {
  local label="$1"
  local platform="$2"

  echo ""
  echo "=========================================="
  echo "  $label"
  echo "=========================================="

  local inline_script="
set -euo pipefail
apk add --no-cache build-base cmake bash curl tar git patch pkgconfig linux-headers python3
mkdir -p /tmp/pico_phone
git -C /work ls-files -z | tar --null -C /work -T - -czf /tmp/repo.tar.gz
tar -xzf /tmp/repo.tar.gz -C /tmp/pico_phone
cd /tmp/pico_phone
bash ext/pico_phone/build_deps.sh
gem install bundler --no-document
bundle config set --local path vendor/bundle
bundle install --quiet
export PICO_PHONE_NATIVE_BUILD=1
bundle exec rake compile spec
"

  if docker run --rm \
       --platform "$platform" \
       -v "${REPO_ROOT}:/work:ro" \
       ruby:3.3-alpine sh -c "$inline_script" 2>&1; then
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

if [ "$FILTER" = "all" ] || [ "$FILTER" = "musl" ]; then
  run_musl_combo "aarch64-linux-musl  NATIVE_BUILD=1" "linux/arm64"
  run_musl_combo "x86_64-linux-musl   NATIVE_BUILD=1" "linux/amd64"
fi

echo ""
echo "=========================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "=========================================="
[ "$FAIL" -eq 0 ]

#!/usr/bin/env bash
# Cross-platform verification: runs compile + spec inside containers for the
# eight Linux build combinations -- glibc (Ubuntu 24.04) aarch64/x86_64 ×
# dynamic/static, musl (Alpine) aarch64/x86_64 (static only: there's no packaged
# libphonenumber-dev equivalent on Alpine to link against dynamically, so
# NATIVE_BUILD is the only way musl ever works at all), and the "portable" glibc
# builds (Debian 12 container, the same recipe as the glibc release jobs) which
# also check the glibc/libstdc++ floor and smoke-test the packaged gem on bare
# Debian and Ubuntu images.
#
# Prerequisites: Docker running, with linux/amd64 emulation available
# (Docker Desktop on Mac ships QEMU for this by default).
#
# Usage:
#   bash verify_docker.sh              # runs all eight combinations
#   bash verify_docker.sh dynamic      # glibc dynamic builds only
#   bash verify_docker.sh static       # glibc NATIVE_BUILD static builds only
#   bash verify_docker.sh musl         # musl builds only (always static) + smoke test of the packaged gem on bare Alpine
#   bash verify_docker.sh portable     # release-recipe glibc builds (Debian 12) + floor + bare-image smoke test
#   bash verify_docker.sh musl arm64   # any mode can be limited to one architecture (arm64 | amd64)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
FILTER="${1:-all}"
# Optional second argument limits the run to one architecture (arm64 | amd64); default: both.
ARCH_FILTER="${2:-all}"
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
    # NATIVE_BUILD: no system libphonenumber or ICU needed; build_deps.sh compiles
    # and statically links its own (python3 is for ICU's data builder). Deliberately
    # leaving libicu-dev out so a build that quietly fell back to system ICU can't
    # pass this check.
    local extra_pkg="python3"
    # After the specs, assert the compiled .so has no dynamic ICU dependency at all
    # (the whole point of vendoring it -- specs alone can't tell static from dynamic).
    local build_cmd="bash ext/pico_phone/build_deps.sh && PICO_PHONE_NATIVE_BUILD=1 bundle exec rake compile spec && so=\$(find lib tmp -name pico_phone.so | sed -n 1p) && test -n \"\$so\" && test -z \"\$(readelf -d \$so | grep libicu)\" && echo \"OK: \$so has no dynamic ICU dependency\""
  else
    # Dynamic: system libphonenumber-dev + libicu-dev supply headers + shared libraries.
    local extra_pkg="libphonenumber-dev libicu-dev"
    local build_cmd="bundle exec rake"
  fi

  local inline_script="
set -euo pipefail
apt-get update -q
apt-get install -y --no-install-recommends \
  ruby ruby-dev bundler cmake build-essential git curl ca-certificates \
  ${extra_pkg}
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
  local name="verify_musl_$$_${platform#linux/}"
  local gem_dir
  gem_dir="$(mktemp -d)"

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
# sed -n 1p, not head -1: with pipefail, head closing the pipe early makes find die of SIGPIPE
so=\$(find lib tmp -name pico_phone.so | sed -n 1p)
test -n \"\$so\"
test -z \"\$(readelf -d \$so | grep libicu)\"
echo \"OK: \$so has no dynamic ICU dependency\"
bundle exec rake native:compile native:package
"

  if docker run --name "$name" \
       --platform "$platform" \
       -v "${REPO_ROOT}:/work:ro" \
       ruby:3.3-alpine sh -c "$inline_script" 2>&1; then
    # Smoke-test the packaged gem on a bare Alpine image (the Ruby 3.3 gem, so Ruby 3.3).
    docker cp "$name:/tmp/pico_phone/pkg/." "$gem_dir/" >/dev/null
    if DOCKER_DEFAULT_PLATFORM="$platform" bash "${REPO_ROOT}/smoke_packaged_gem.sh" "$gem_dir" ruby:3.3-alpine; then
      echo "  PASS: $label"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: $label (smoke test)"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
  docker rm -f "$name" >/dev/null 2>&1 || true
  rm -rf "$gem_dir"
}

# Upper bounds on what the glibc release gems may require -- i.e. the supported floor
# (Debian 12 / Ubuntu 22.04 and newer). Lower is fine; higher means the binary would
# stop loading on a distro we claim to support. Keep in sync with the README.
MAX_GLIBC="2.34"
MAX_GLIBCXX="3.4.30"

# The glibc release recipe: build in a Debian 12 (bookworm) container, then check what the
# result needs and that the *packaged* gem loads on bare images with no ICU and no compiler.
run_portable_combo() {
  local label="$1"
  local platform="$2"
  local name="verify_portable_$$_${platform#linux/}"
  local gem_dir
  gem_dir="$(mktemp -d)"

  echo ""
  echo "=========================================="
  echo "  $label"
  echo "=========================================="

  if docker run --name "$name" -i --platform "$platform" \
       -e MAX_GLIBC="$MAX_GLIBC" -e MAX_GLIBCXX="$MAX_GLIBCXX" \
       -v "${REPO_ROOT}:/work:ro" \
       ruby:3.4-bookworm bash -s 2>&1 <<'INNER'
set -euo pipefail
apt-get update -q >/dev/null
apt-get install -y -q --no-install-recommends cmake >/dev/null
mkdir -p /tmp/pico_phone
git -C /work ls-files -z | tar --null -C /work -T - -czf /tmp/repo.tar.gz
tar -xzf /tmp/repo.tar.gz -C /tmp/pico_phone
cd /tmp/pico_phone
bundle install --quiet
export PICO_PHONE_NATIVE_BUILD=1
bundle exec rake native:compile
bundle exec rspec
so=$(find lib -name pico_phone.so | sed -n 1p)
test -n "$so"
ls -l "$so" | awk '{printf "size: %.1f MB\n", $5/1048576}'

# no dynamic ICU
test -z "$(readelf -d "$so" | grep libicu)"
echo "OK: no dynamic ICU dependency"

# glibc / libstdc++ floor: highest version required must be <= the supported floor
le() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$2" ]; }
need_glibc=$(objdump -T "$so" | grep -o 'GLIBC_[0-9.]*' | sed 's/^GLIBC_//' | sort -V | tail -1)
need_glibcxx=$(objdump -T "$so" | grep -o 'GLIBCXX_[0-9.]*' | sed 's/^GLIBCXX_//' | sort -V | tail -1)
echo "requires glibc >= $need_glibc (allowed <= $MAX_GLIBC), libstdc++ >= ${need_glibcxx:-none} (allowed <= $MAX_GLIBCXX)"
le "$need_glibc" "$MAX_GLIBC"
le "${need_glibcxx:-0}" "$MAX_GLIBCXX"
echo "OK: within the supported glibc/libstdc++ floor"

bundle exec rake native:package
INNER
  then
    # Smoke-test the packaged gem on bare images (the Ruby 3.4 gem, so Ruby 3.4 images).
    docker cp "$name:/tmp/pico_phone/pkg/." "$gem_dir/" >/dev/null
    if DOCKER_DEFAULT_PLATFORM="$platform" bash "${REPO_ROOT}/smoke_packaged_gem.sh" "$gem_dir" \
         ruby:3.4-slim-bookworm ruby:3.4-slim rubylang/ruby:3.4-jammy rubylang/ruby:3.4-noble; then
      echo "  PASS: $label"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: $label (smoke test)"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
  docker rm -f "$name" >/dev/null 2>&1 || true
  rm -rf "$gem_dir"
}

if [ "$FILTER" = "all" ] || [ "$FILTER" = "dynamic" ]; then
  [ "$ARCH_FILTER" = "all" ] || [ "$ARCH_FILTER" = "arm64" ] && run_combo "aarch64-linux  dynamic"       "linux/arm64" "0"
  [ "$ARCH_FILTER" = "all" ] || [ "$ARCH_FILTER" = "amd64" ] && run_combo "x86_64-linux   dynamic"       "linux/amd64" "0"
fi

if [ "$FILTER" = "all" ] || [ "$FILTER" = "static" ]; then
  [ "$ARCH_FILTER" = "all" ] || [ "$ARCH_FILTER" = "arm64" ] && run_combo "aarch64-linux  NATIVE_BUILD=1" "linux/arm64" "1"
  [ "$ARCH_FILTER" = "all" ] || [ "$ARCH_FILTER" = "amd64" ] && run_combo "x86_64-linux   NATIVE_BUILD=1" "linux/amd64" "1"
fi

if [ "$FILTER" = "all" ] || [ "$FILTER" = "musl" ]; then
  [ "$ARCH_FILTER" = "all" ] || [ "$ARCH_FILTER" = "arm64" ] && run_musl_combo "aarch64-linux-musl  NATIVE_BUILD=1" "linux/arm64"
  [ "$ARCH_FILTER" = "all" ] || [ "$ARCH_FILTER" = "amd64" ] && run_musl_combo "x86_64-linux-musl   NATIVE_BUILD=1" "linux/amd64"
fi

if [ "$FILTER" = "all" ] || [ "$FILTER" = "portable" ]; then
  [ "$ARCH_FILTER" = "all" ] || [ "$ARCH_FILTER" = "arm64" ] && run_portable_combo "aarch64-linux  portable (Debian 12 build)" "linux/arm64"
  [ "$ARCH_FILTER" = "all" ] || [ "$ARCH_FILTER" = "amd64" ] && run_portable_combo "x86_64-linux   portable (Debian 12 build)" "linux/amd64"
fi

echo ""
echo "=========================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "=========================================="
[ "$FAIL" -eq 0 ]

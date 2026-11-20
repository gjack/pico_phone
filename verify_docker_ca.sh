#!/usr/bin/env bash
# Builds and smoke-tests content-addressable native gems (RubyGems/Bundler >= 4.1.0) for the
# content-addressable track -- mirrors verify_docker.sh's static/musl legs, but packages with
# `native:package_ca` instead of `native:package` (one small gem per Ruby ABI, not one fat gem
# with every ABI bundled in) and then proves the result actually installs and works: first on
# an UPGRADED client (gem update --system), which is what anyone opting into --pre needs to do.
#
# This does not test the "old client ignores the prerelease" safety net -- that only exists once
# something has actually been pushed to rubygems.org, since it depends on the real compact index.
#
# Prerequisites: Docker running, with linux/amd64 emulation available.
#
# Usage:
#   bash verify_docker_ca.sh              # glibc (aarch64 + x86_64) and musl (aarch64 + x86_64)
#   bash verify_docker_ca.sh arm64        # limit to one architecture
#   bash verify_docker_ca.sh amd64
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
ARCH_FILTER="${1:-all}"
PASS=0
FAIL=0

# Builds a CA gem inside a glibc (Ubuntu 24.04) container, then smoke-tests it in a second,
# bare container that never saw a compiler -- the same thing smoke_packaged_gem.sh does for the
# fat gem, plus the `gem update --system` an opt-in --pre adopter would actually run.
run_glibc_ca() {
  local label="$1" platform="$2"
  local name="verify_ca_$$_${platform#linux/}"
  local gem_dir
  gem_dir="$(mktemp -d)"

  echo ""
  echo "=========================================="
  echo "  $label"
  echo "=========================================="

  # Use the official ruby:*-bookworm image (upstream-built Ruby + RubyGems), not apt-installed
  # Ruby on bare ubuntu:24.04: Debian/Ubuntu patches their packaged RubyGems to refuse
  # `gem update --system` entirely ("installed through APT ... unsupported"). The real release
  # workflow hits neither path -- ruby/setup-ruby installs prebuilt Ruby too -- so this is purely
  # a test-harness concern, not something content-addressable gems need to work around.
  local build_script='
set -euo pipefail
apt-get update -q
apt-get install -y --no-install-recommends cmake build-essential git curl ca-certificates python3
mkdir -p /tmp/pico_phone
git -C /work ls-files -z | tar --null -C /work -T - -czf /tmp/repo.tar.gz
tar -xzf /tmp/repo.tar.gz -C /tmp/pico_phone
cd /tmp/pico_phone
gem update --system --no-document
bundle install --quiet
bundle exec rake native:compile native:package_ca
'
  if docker run --name "$name" --rm=false \
       --platform "$platform" \
       -v "${REPO_ROOT}:/work:ro" \
       ruby:3.4-bookworm bash -c "$build_script" 2>&1; then
    docker cp "$name:/tmp/pico_phone/pkg/." "$gem_dir/" >/dev/null
    docker rm -f "$name" >/dev/null 2>&1 || true

    if DOCKER_DEFAULT_PLATFORM="$platform" bash "${REPO_ROOT}/smoke_packaged_gem_ca.sh" "$gem_dir" ruby:3.4-slim-bookworm; then
      echo "  PASS: $label"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: $label (smoke test)"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  FAIL: $label (build)"
    FAIL=$((FAIL + 1))
    docker rm -f "$name" >/dev/null 2>&1 || true
  fi
  rm -rf "$gem_dir"
}

# Same idea for musl (Alpine) -- always the NATIVE_BUILD static path (there's no dynamic
# libphonenumber-dev equivalent to link against on Alpine).
run_musl_ca() {
  local label="$1" platform="$2"
  local name="verify_ca_musl_$$_${platform#linux/}"
  local gem_dir
  gem_dir="$(mktemp -d)"

  echo ""
  echo "=========================================="
  echo "  $label"
  echo "=========================================="

  local build_script='
set -euo pipefail
apk add --no-cache build-base cmake bash curl tar git patch pkgconfig linux-headers python3
mkdir -p /tmp/pico_phone
git -C /work ls-files -z | tar --null -C /work -T - -czf /tmp/repo.tar.gz
tar -xzf /tmp/repo.tar.gz -C /tmp/pico_phone
cd /tmp/pico_phone
gem update --system --no-document
gem install bundler --no-document
bundle config set --local path vendor/bundle
bundle install --quiet
export PICO_PHONE_NATIVE_BUILD=1
bundle exec rake native:compile native:package_ca
'
  if docker run --name "$name" \
       --platform "$platform" \
       -v "${REPO_ROOT}:/work:ro" \
       ruby:3.3-alpine sh -c "$build_script" 2>&1; then
    docker cp "$name:/tmp/pico_phone/pkg/." "$gem_dir/" >/dev/null

    if DOCKER_DEFAULT_PLATFORM="$platform" bash "${REPO_ROOT}/smoke_packaged_gem_ca.sh" "$gem_dir" ruby:3.3-alpine; then
      echo "  PASS: $label"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: $label (smoke test)"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  FAIL: $label (build)"
    FAIL=$((FAIL + 1))
  fi
  docker rm -f "$name" >/dev/null 2>&1 || true
  rm -rf "$gem_dir"
}

[ "$ARCH_FILTER" = "all" ] || [ "$ARCH_FILTER" = "arm64" ] && run_glibc_ca "aarch64-linux  content-addressable" "linux/arm64"
[ "$ARCH_FILTER" = "all" ] || [ "$ARCH_FILTER" = "amd64" ] && run_glibc_ca "x86_64-linux   content-addressable" "linux/amd64"
[ "$ARCH_FILTER" = "all" ] || [ "$ARCH_FILTER" = "arm64" ] && run_musl_ca  "aarch64-linux-musl  content-addressable" "linux/arm64"
[ "$ARCH_FILTER" = "all" ] || [ "$ARCH_FILTER" = "amd64" ] && run_musl_ca  "x86_64-linux-musl   content-addressable" "linux/amd64"

echo ""
echo "=========================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "=========================================="
[ "$FAIL" -eq 0 ]

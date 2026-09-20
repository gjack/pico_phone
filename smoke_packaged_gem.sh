#!/usr/bin/env bash
# Installs a PACKAGED (precompiled) gem into bare images -- no compiler, no ICU, nothing but
# Ruby -- and exercises it (smoke_check.rb). This is the check a passing spec suite on the build
# machine cannot give you: does the released artifact actually load and work where users run it?
# (The failures it exists to catch: a missing libicu*.so.N, or a binary needing a newer
# glibc/libstdc++ than the target has.) Shared by verify_docker.sh and the release workflow.
#
# Works on glibc and musl (Alpine) images alike: the in-container script is plain POSIX sh.
#
# Usage: bash smoke_packaged_gem.sh <dir containing pico_phone-*.gem> <image> [<image> ...]
#   e.g. bash smoke_packaged_gem.sh pkg ruby:3.4-slim-bookworm rubylang/ruby:3.4-jammy
# Set DOCKER_DEFAULT_PLATFORM (e.g. linux/amd64) to run the images for another architecture.
set -uo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <gem dir> <image> [<image> ...]" >&2
  exit 2
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
GEM_DIR="$(cd "$1" && pwd)"
shift

FAILED=0
for img in "$@"; do
  echo "== smoke: $img"
  if docker run --rm -i -v "$GEM_DIR:/gem:ro" -v "$HERE/smoke_check.rb:/smoke_check.rb:ro" "$img" sh -s <<'SH'
set -eu
export LANG=C.UTF-8
echo "   $(. /etc/os-release; echo "$PRETTY_NAME"); ICU files on system: $(find / -xdev -name 'libicu*' 2>/dev/null | wc -l)"
gem install rice -v '~> 4.3' --no-document >/dev/null
gem install --local /gem/pico_phone-*.gem --no-document >/dev/null
# run from / so nothing but the installed gem can satisfy `require "pico_phone"`
cd / && ruby /smoke_check.rb
SH
  then
    :
  else
    echo "   FAIL: $img"
    FAILED=1
  fi
done
exit $FAILED

#!/usr/bin/env bash
# Like smoke_packaged_gem.sh, but for content-addressable gems: a directory can hold several
# pico_phone-<version>-<hash>.gem files (one per Ruby ABI, since that's the whole point of
# content addressing), so the hash alone can't name "the" file to install -- this picks the one
# whose required_ruby_version matches the image's own Ruby. Also upgrades the image's stock
# RubyGems first (required_rubygems_version >= 4.1.0.a), which a real --pre adopter would have
# to do too. Does NOT test that an un-upgraded client safely ignores the prerelease; that only
# exists once something has been pushed to rubygems.org.
#
# Usage: bash smoke_packaged_gem_ca.sh <dir containing pico_phone-*-<hash>.gem files> <image> [<image> ...]
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
  echo "== smoke (content-addressable): $img"
  if docker run --rm -i -v "$GEM_DIR:/gem:ro" -v "$HERE/smoke_check.rb:/smoke_check.rb:ro" "$img" sh -s <<'SH'
set -eu
export LANG=C.UTF-8
echo "   rubygems before upgrade: $(gem --version)"
gem update --system --no-document >/dev/null
echo "   rubygems after upgrade:  $(gem --version)"

abi="$(ruby -e 'puts RUBY_VERSION.split(".").first(2).join(".")')"
gem_file=""
for f in /gem/pico_phone-*.gem; do
  if gem specification "$f" required_ruby_version 2>/dev/null | grep -q "version: ${abi}\.0"; then
    gem_file="$f"
    break
  fi
done
if [ -z "$gem_file" ]; then
  echo "   no content-addressable gem in /gem matches Ruby ABI $abi" >&2
  ls /gem >&2
  exit 1
fi
echo "   Ruby ABI $abi -> $gem_file"

gem install rice -v '~> 4.3' --no-document >/dev/null
gem install --local "$gem_file" --no-document >/dev/null
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

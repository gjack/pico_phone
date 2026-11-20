#!/usr/bin/env bash
# Like smoke_packaged_gem.sh, but for a content-addressable gem (name-version-hash.gem): the
# bare image's stock RubyGems is almost certainly older than the >= 4.1.0 these gems require
# (required_rubygems_version), so this upgrades it first -- exactly what a real --pre adopter
# would have to do. Does NOT test that an un-upgraded client safely ignores the prerelease;
# that only exists once something has been pushed to rubygems.org (see verify_docker_ca.sh).
#
# Usage: bash smoke_packaged_gem_ca.sh <dir containing pico_phone-*-<hash>.gem> <image> [<image> ...]
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
gem install rice -v '~> 4.3' --no-document >/dev/null
gem install --local /gem/pico_phone-*.gem --no-document >/dev/null
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

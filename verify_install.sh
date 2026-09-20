#!/usr/bin/env bash
# Verifies that pico_phone installs and works on bare images (only Ruby: no compiler, no ICU),
# for every supported Ruby on the oldest supported distros plus the newest. Two modes, which
# prove different things:
#
#   bash verify_install.sh --index <dir> [arm64|amd64]
#       BEFORE publishing. <dir> holds the gems a release run produced (`gh run download
#       <run-id> -D dir`, plus the source gem). For each image it installs the gem built for
#       that image's exact platform and runs smoke_check.rb: "the artifacts we are about to
#       publish load and work". It deliberately does NOT test RubyGems' platform selection: a
#       local file index does not reproduce rubygems.org's (on Alpine it can hand a glibc gem to
#       a musl Ruby even when the already-published gems do not misbehave on the real index).
#
#   bash verify_install.sh --rubygems <version> [arm64|amd64]
#       AFTER publishing. Installs the real thing from rubygems.org twice per image -- `gem
#       install` and Bundler -- letting them choose the platform gem themselves, reports which
#       one they picked, and runs smoke_check.rb. This is the check for "people who run gem
#       install pico_phone get something that works"; run it right after a release so a bad
#       one can be yanked quickly.
#
# Override the image list with IMAGES="img1 img2 ...". Architecture defaults to the host's; the
# other one runs under emulation (slow).
set -uo pipefail

usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

MODE="${1:-}"; shift || true
case "$MODE" in
  --index)    INDEX_SRC="${1:-}"; [ -d "$INDEX_SRC" ] || usage; INDEX_SRC="$(cd "$INDEX_SRC" && pwd)"; shift ;;
  --rubygems) VERSION="${1:-}"; [ -n "$VERSION" ] || usage; shift ;;
  *) usage ;;
esac
ARCH="${1:-}"
[ -n "$ARCH" ] && export DOCKER_DEFAULT_PLATFORM="linux/$ARCH"

HERE="$(cd "$(dirname "$0")" && pwd)"
INDEX_DIR=""
if [ "$MODE" = "--index" ]; then
  INDEX_DIR="$(mktemp -d)"
  mkdir -p "$INDEX_DIR/gems"
  cp "$INDEX_SRC"/*.gem "$INDEX_DIR/gems/"
  VERSION="$(ls "$INDEX_DIR/gems" | sed -n 's/^pico_phone-\([0-9][0-9.]*\)\(-.*\)\{0,1\}\.gem$/\1/p' | sort -uV | tail -1)"
  echo "== gems under test: $(ls "$INDEX_DIR/gems" | tr '\n' ' ')"
  trap 'rm -rf "$INDEX_DIR"' EXIT
fi
echo "== testing pico_phone $VERSION from $([ "$MODE" = "--index" ] && echo "downloaded gems" || echo "rubygems.org")${ARCH:+ on $ARCH}"

if [ -z "${IMAGES:-}" ]; then
  IMAGES=""
  for v in 3.1 3.2 3.3 3.4 4.0; do
    IMAGES="$IMAGES ruby:$v-slim-bookworm rubylang/ruby:$v-jammy ruby:$v-alpine"
  done
  IMAGES="$IMAGES ruby:3.4-slim rubylang/ruby:3.4-noble"
fi

MOUNTS=(-v "$HERE/smoke_check.rb:/smoke_check.rb:ro")
[ -n "$INDEX_DIR" ] && MOUNTS+=(-v "$INDEX_DIR:/idx:ro")

FAILED=0
for img in $IMAGES; do
  echo "== $img"
  if docker run --rm -i "${MOUNTS[@]}" -e PICO_VERSION="$VERSION" -e PICO_INDEX="${INDEX_DIR:+1}" "$img" sh -s <<'SH'
set -eu
export LANG=C.UTF-8
echo "   $(. /etc/os-release; echo "$PRETTY_NAME"), Ruby $(ruby -e 'print RUBY_VERSION'), RubyGems platform $(ruby -e 'print Gem::Platform.local')"
gem install rice -v '~> 4.3' --no-document >/dev/null

echo "   -- gem install"
if [ -n "${PICO_INDEX:-}" ]; then
  # Install the gem built for this exact platform (see the header: selection is only tested
  # with --rubygems).
  plat=$(ruby -e 'print Gem::Platform.local.to_s.sub(/-gnu$/, "")')
  gem install --local "/idx/gems/pico_phone-$PICO_VERSION-$plat.gem" --no-document >/dev/null
else
  gem install pico_phone -v "$PICO_VERSION" --no-document >/dev/null
fi
echo "   installed: $(gem list pico_phone | tail -1)"
(cd / && ruby /smoke_check.rb)
[ -n "${PICO_INDEX:-}" ] && exit 0

echo "   -- bundle install"
mkdir -p /app && cd /app
printf 'source "https://rubygems.org"\ngem "pico_phone", "= %s"\n' "$PICO_VERSION" > Gemfile
bundle config set --local path /app/bundle >/dev/null
bundle install --quiet
echo "   picked: $(bundle list | grep pico_phone | sed 's/^ *\* //')"
bundle exec ruby /smoke_check.rb
SH
  then
    :
  else
    echo "   FAIL: $img"
    FAILED=$((FAILED + 1))
  fi
done

echo
[ "$FAILED" -eq 0 ] && echo "ALL IMAGES OK" || echo "$FAILED image(s) FAILED"
exit "$FAILED"

#!/usr/bin/env bash
# Bootstrap a project-local Free Pascal toolchain by fetching the Homebrew
# bottle for our architecture directly from ghcr.io. This avoids depending on
# Homebrew itself — bottles are just OCI-layout tarballs and public ghcr.io
# content can be pulled with an anonymous token.
#
# The bottle is rooted at `<prefix>/Cellar/fpc/<version>/` when installed by
# Homebrew. We extract it anywhere and rewrite a tiny fpc.cfg to locate the
# units/libraries.

set -euo pipefail

: "${FPC_HOME:?FPC_HOME must be set (pixi activation.env should provide it)}"

if [ -x "$FPC_HOME/bin/fpc" ]; then
  echo "fpc already installed at $FPC_HOME/bin/fpc"
  "$FPC_HOME/bin/fpc" -iV
  exit 0
fi

mkdir -p "$FPC_HOME"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Pick the bottle that matches the current macOS major version. Falls back to
# the most recent stable when running on an unknown version.
major=""
case "$(uname -s)" in
  Darwin)
    ver=$(sw_vers -productVersion | cut -d. -f1)
    case "$ver" in
      26) key="arm64_tahoe"    ;;
      15) key="arm64_sequoia"  ;;
      14) key="arm64_sonoma"   ;;
      13) key="arm64_ventura"  ;;
      12) key="arm64_monterey" ;;
      *)
        # Newer macOS can typically run older bottles; try tahoe first.
        key="arm64_tahoe"
        ;;
    esac
    ;;
  Linux)
    if [ "$(uname -m)" = "aarch64" ]; then
      key="arm64_linux"
    else
      key="x86_64_linux"
    fi
    ;;
  *)
    echo "unsupported platform: $(uname -s)" >&2
    exit 2
    ;;
esac

echo ">>> looking up Homebrew formula for fpc"
formula=$(curl -fsSL https://formulae.brew.sh/api/formula/fpc.json)
url=$(echo "$formula" | jq -r ".bottle.stable.files.\"$key\".url")
if [ -z "$url" ] || [ "$url" = "null" ]; then
  # Fall back to any available arm64/darwin bottle.
  url=$(echo "$formula" | jq -r '.bottle.stable.files | to_entries[] | select(.key|test("arm64")) | .value.url' | head -1)
fi
if [ -z "$url" ] || [ "$url" = "null" ]; then
  echo "no matching bottle for $key" >&2
  exit 3
fi
echo ">>> bottle URL: $url"

# ghcr.io requires a bearer token even for public pulls.
token=$(curl -fsSL "https://ghcr.io/token?scope=repository:homebrew/core/fpc:pull" | jq -r .token)

echo ">>> downloading FPC bottle"
curl -fsSL -H "Authorization: Bearer $token" -o "$tmp/fpc.tar.gz" "$url"

echo ">>> extracting"
tar -xzf "$tmp/fpc.tar.gz" -C "$tmp"

# Homebrew bottles use the layout: fpc/<version>/{bin,lib,share}
src_root=$(find "$tmp" -type d -name fpc -mindepth 1 -maxdepth 2 | head -1)
if [ -z "$src_root" ]; then
  echo "could not find fpc/ inside bottle; layout:" >&2
  find "$tmp" -maxdepth 3 -type d >&2
  exit 4
fi
version_dir=$(find "$src_root" -mindepth 1 -maxdepth 1 -type d | head -1)
if [ -z "$version_dir" ]; then
  echo "could not find fpc/<version> inside $src_root" >&2
  exit 5
fi

echo ">>> installing toolchain into $FPC_HOME"
# Copy contents of fpc/<version>/* into FPC_HOME/
cp -R "$version_dir/." "$FPC_HOME/"

# The bottle's fpc.cfg embeds an absolute path to /opt/homebrew/Cellar/fpc/VERSION.
# Rewrite that to $FPC_HOME so fpc finds its units without Homebrew present.
cfg="$FPC_HOME/etc/fpc.cfg"
[ -f "$cfg" ] || cfg="$FPC_HOME/lib/fpc/etc/fpc.cfg"
if [ -f "$cfg" ]; then
  echo ">>> rewriting fpc.cfg paths to $FPC_HOME"
  sed -i.bak \
    -e "s|/opt/homebrew/Cellar/fpc/[^/]*|$FPC_HOME|g" \
    -e "s|/usr/local/Cellar/fpc/[^/]*|$FPC_HOME|g" \
    -e "s|@@HOMEBREW_PREFIX@@|$FPC_HOME/..|g" \
    -e "s|@@HOMEBREW_CELLAR@@/fpc/[^/]*|$FPC_HOME|g" \
    "$cfg"
fi

echo
echo ">>> installed:"
"$FPC_HOME/bin/fpc" -iV || echo "(fpc exists but couldn't report version)"

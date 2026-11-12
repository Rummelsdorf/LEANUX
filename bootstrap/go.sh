#!/usr/bin/env bash
# bootstrap/go.sh – install the pinned Go toolchain used to build Go spells.
#
# Go is a build-time toolchain only.  It is installed under tools/host/go and
# is deliberately kept out of the distribution payload.
#
# Environment:
#   GO_VERSION   Go release (default: 1.27.4, the first release that satisfies
#                Ollama's go.mod requirement of 1.26.10)
#   GO_ARCHIVE   pre-downloaded tarball (default: sources/go<version>.linux-amd64.tar.gz)
#   GO_URL       download mirror (default: Aliyun Go mirror)
#   GO_SHA256    expected archive checksum
#   PREFIX       install prefix (default: tools/host/go)

set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
VERSION="${GO_VERSION:-1.27.4}"
ARCH="${GO_ARCH:-amd64}"
PREFIX="${PREFIX:-$ROOT/tools/host/go}"
ARCHIVE="${GO_ARCHIVE:-$ROOT/sources/go${VERSION}.linux-${ARCH}.tar.gz}"
URL="${GO_URL:-https://mirrors.aliyun.com/golang/go${VERSION}.linux-${ARCH}.tar.gz}"
EXPECTED="${GO_SHA256:-7226736c2339719cda28fbf3a54d71aa63bcefe376e98cef00034268dab24840}"

if [ -x "$PREFIX/bin/go" ]; then
    "$PREFIX/bin/go" version
    exit 0
fi

mkdir -p "$(dirname "$ARCHIVE")"
if [ ! -f "$ARCHIVE" ]; then
    echo "Fetching Go $VERSION from $URL"
    curl -fL --retry 5 --connect-timeout 20 -o "$ARCHIVE.part" "$URL"
    mv "$ARCHIVE.part" "$ARCHIVE"
fi

if [ -n "$EXPECTED" ] && [ "$EXPECTED" != "PLACEHOLDER_HASH" ]; then
    echo "$EXPECTED  $ARCHIVE" | sha256sum -c -
fi

echo "Installing Go $VERSION into $PREFIX"
rm -rf "$PREFIX"
mkdir -p "$PREFIX"
tar -xf "$ARCHIVE" -C "$PREFIX" --strip-components=1

mkdir -p "$ROOT/tools/host/bin"
ln -sf "$PREFIX/bin/go" "$ROOT/tools/host/bin/go"
[ -x "$PREFIX/bin/gofmt" ] && ln -sf "$PREFIX/bin/gofmt" "$ROOT/tools/host/bin/gofmt"

# Keep module and build caches inside the repository so they are easy to clean
# and never touch the user's home directory.
export GOCACHE="${GOCACHE:-$ROOT/build-output/.gocache}"
export GOPATH="${GOPATH:-$ROOT/build-output/.gopath}"
mkdir -p "$GOCACHE" "$GOPATH"

"$PREFIX/bin/go" version

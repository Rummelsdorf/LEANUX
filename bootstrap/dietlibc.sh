#!/usr/bin/env bash
# bootstrap/dietlibc.sh – build the LEANUX base C library (dietlibc 0.35)
# from the bundled source archive into tools/diet.

set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
TARBALL="${TARBALL:-$ROOT/diet/dietlibc-0.35.tar.xz}"
PREFIX="${PREFIX:-$ROOT/tools/diet}"
BUILD="$ROOT/build-output/dietlibc-0.35"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 2)}"

[ -f "$TARBALL" ] || { echo "Missing $TARBALL" >&2; exit 1; }

echo "Building dietlibc 0.35 into $PREFIX"
rm -rf "$BUILD"
mkdir -p "$BUILD"
tar -xf "$TARBALL" -C "$BUILD" --strip-components=1

(
    cd "$BUILD"
    make -j"$JOBS"
    make install prefix="$PREFIX"
)

mkdir -p "$PREFIX/bin"
cat > "$PREFIX/bin/dietgcc" <<EOF
#!/bin/sh
export DIETHOME="\${DIETHOME:-$PREFIX}"
exec "$PREFIX/bin/diet" gcc "\$@"
EOF
cat > "$PREFIX/bin/dietcc" <<EOF
#!/bin/sh
export DIETHOME="\${DIETHOME:-$PREFIX}"
exec "$PREFIX/bin/diet" gcc "\$@"
EOF
chmod +x "$PREFIX/bin/dietgcc" "$PREFIX/bin/dietcc"

echo "dietlibc ready: $PREFIX/bin/dietgcc"
"$PREFIX/bin/dietgcc" --version | head -1
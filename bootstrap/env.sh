#!/usr/bin/env bash

set -euo pipefail

export PROJECT_ROOT="$HOME/LEANUX"

export TARGET="x86_64-leanux-gnu"

export PREFIX="$PROJECT_ROOT/tools/cross"

export SOURCES="$PROJECT_ROOT/sources"

export BUILD="$PROJECT_ROOT/build-output"

export SYSROOT="$PROJECT_ROOT/sysroot"

export PATH="$PREFIX/bin:$PATH"

export MAKEFLAGS="-j4"

mkdir -p \
    "$PREFIX" \
    "$SOURCES" \
    "$BUILD" \
    "$SYSROOT"

echo "PROJECT bootstrap environment loaded"
echo "Target: $TARGET"
echo "Prefix: $PREFIX"
echo "Sysroot: $SYSROOT"



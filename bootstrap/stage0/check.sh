#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/../env.sh"

echo "Checking PROJECT bootstrap environment..."

for tool in gcc g++ make ld as python3 tar; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Missing required tool: $tool"
        exit 1
    fi
done

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "This initial bootstrap targets x86_64."
    exit 1
fi

mkdir -p \
    "$BUILD/binutils" \
    "$BUILD/gcc-pass1" \
    "$BUILD/kernel-headers" \
    "$BUILD/glibc" \
    "$BUILD/gcc-pass2"

echo "Bootstrap preparation successful."



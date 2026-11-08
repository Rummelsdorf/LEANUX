#!/usr/bin/env bash
# build_leanux.sh – compatibility wrapper for the LEANUX spell system.
#
# All package builds go through spells/cast.sh so that dietlibc is the default
# C library and dependency resolution is always applied.
#
# Usage:
#   ./build_leanux.sh <spell> [spell ...]
#   ./build_leanux.sh --list
#
# Examples:
#   ./build_leanux.sh zlib
#   ./build_leanux.sh bash openssh tmux

set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
exec "$ROOT/spells/cast.sh" "$@"
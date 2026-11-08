#!/usr/bin/env bash
# tests/run-tests.sh – functional tests for the LEANUX build system.

set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0

pass() { echo "[PASS] $*"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $*"; FAIL=$((FAIL + 1)); }

check() {
    local desc="$1"; shift
    if "$@"; then pass "$desc"; else fail "$desc"; fi
}

echo "LEANUX build-system tests"
echo "========================="

# ---------------------------------------------------------------------------
# 1. Shell syntax
# ---------------------------------------------------------------------------
check "cast.sh syntax" bash -n spells/cast.sh
check "bootstrap/dietlibc.sh syntax" bash -n bootstrap/dietlibc.sh

# ---------------------------------------------------------------------------
# 2. Configuration uses dietlibc, not glibc
# ---------------------------------------------------------------------------
check "config.toml selects dietlibc" grep -q 'libc = "dietlibc"' build/config.toml
if grep -qE '^libc = "glibc"' build/config.toml; then
    fail "config.toml still selects glibc"
else
    pass "config.toml does not select glibc"
fi

# ---------------------------------------------------------------------------
# 3. dietlibc bootstrap
# ---------------------------------------------------------------------------
if [ ! -x tools/diet/bin/dietgcc ]; then
    echo "Bootstrapping dietlibc (one-time)..."
    ./bootstrap/dietlibc.sh
fi
check "dietgcc exists" test -x tools/diet/bin/dietgcc

cat > /tmp/leanux-hello.c <<'EOF'
#include <stdio.h>
int main(void) { printf("leanux-dietlibc-ok\n"); return 0; }
EOF

if tools/diet/bin/dietgcc -static /tmp/leanux-hello.c -o /tmp/leanux-hello 2>/tmp/leanux-hello.err; then
    pass "dietgcc compiles a C program"
else
    fail "dietgcc compiles a C program"
    sed -n '1,10p' /tmp/leanux-hello.err
fi

if [ -x /tmp/leanux-hello ] && /tmp/leanux-hello | grep -q leanux-dietlibc-ok; then
    pass "dietlibc binary runs"
else
    fail "dietlibc binary runs"
fi

if file /tmp/leanux-hello 2>/dev/null | grep -q "statically linked"; then
    pass "dietlibc binary is statically linked"
else
    fail "dietlibc binary is statically linked"
fi

# ---------------------------------------------------------------------------
# 4. Dependency ordering (test_a before test_b)
# ---------------------------------------------------------------------------
rm -rf sysroot/install/test_a sysroot/install/test_b build-output/test_a build-output/test_b
ORDER_OUT=$(./spells/cast.sh test_a test_b 2>&1 || true)
if printf '%s\n' "$ORDER_OUT" | grep -q 'Build order: test_a test_b'; then
    pass "dependencies are built in the correct order"
else
    fail "dependencies are built in the correct order"
    printf '%s\n' "$ORDER_OUT" | sed -n '1,20p'
fi

if [ -f sysroot/install/test_b/.built ] && [ -f sysroot/install/test_a/.built ]; then
    pass "both test packages were marked built"
else
    fail "both test packages were marked built"
fi

# ---------------------------------------------------------------------------
# 5. Real package: zlib with dietlibc
# ---------------------------------------------------------------------------
rm -rf sysroot/install/zlib build-output/zlib
if ./spells/cast.sh zlib >/tmp/leanux-zlib.log 2>&1; then
    pass "zlib builds through the spell system"
else
    fail "zlib builds through the spell system"
    tail -25 /tmp/leanux-zlib.log
fi

ZLIB_A=$(find sysroot/install/zlib -name 'libz.a' 2>/dev/null | head -1)
if [ -n "$ZLIB_A" ]; then
    pass "zlib static library installed"
else
    fail "zlib static library installed"
fi

if [ -n "$ZLIB_A" ]; then
    ZLIB_INC=$(dirname "$(dirname "$ZLIB_A")")/include
    cat > /tmp/leanux-ztest.c <<'EOF'
#include <stdio.h>
#include <zlib.h>
int main(void) { printf("zlib-%s\n", zlibVersion()); return 0; }
EOF
    if tools/diet/bin/dietgcc -static -I"$ZLIB_INC" /tmp/leanux-ztest.c "$ZLIB_A" \
            -o /tmp/leanux-ztest 2>/tmp/leanux-ztest.err; then
        pass "program links against zlib built with dietlibc"
        if /tmp/leanux-ztest | grep -q '^zlib-1\.3\.1'; then
            pass "linked zlib program runs"
        else
            fail "linked zlib program runs"
        fi
        if file /tmp/leanux-ztest | grep -q "statically linked"; then
            pass "zlib test binary is statically linked"
        else
            fail "zlib test binary is statically linked"
        fi
    else
        fail "program links against zlib built with dietlibc"
        sed -n '1,15p' /tmp/leanux-ztest.err
    fi
fi

# ---------------------------------------------------------------------------
# 6. Missing dependency is reported (not silently ignored)
# ---------------------------------------------------------------------------
TMP_SPELLS=$(mktemp -d)
cat > "$TMP_SPELLS/missingdep.spell" <<'EOF'
PACKAGE_NAME="missingdep"
DEPENDENCIES=("does_not_exist")
EXTERNAL_DEPENDENCIES=()
SOURCE_URL=""
build() { :; }
EOF

if SPELL_DIR="$TMP_SPELLS" ./spells/cast.sh missingdep >/tmp/leanux-missing.log 2>&1; then
    fail "missing dependency is reported"
else
    if grep -q "Missing spell for dependency 'does_not_exist'" /tmp/leanux-missing.log; then
        pass "missing dependency is reported"
    else
        fail "missing dependency is reported"
        sed -n '1,10p' /tmp/leanux-missing.log
    fi
fi

# ---------------------------------------------------------------------------
# 7. Circular dependency is detected
# ---------------------------------------------------------------------------
cat > "$TMP_SPELLS/cycle_a.spell" <<'EOF'
PACKAGE_NAME="cycle_a"
DEPENDENCIES=("cycle_b")
EXTERNAL_DEPENDENCIES=()
SOURCE_URL=""
build() { :; }
EOF
cat > "$TMP_SPELLS/cycle_b.spell" <<'EOF'
PACKAGE_NAME="cycle_b"
DEPENDENCIES=("cycle_a")
EXTERNAL_DEPENDENCIES=()
SOURCE_URL=""
build() { :; }
EOF

if SPELL_DIR="$TMP_SPELLS" ./spells/cast.sh cycle_a >/tmp/leanux-cycle.log 2>&1; then
    fail "circular dependency is detected"
else
    if grep -qi "circular dependency" /tmp/leanux-cycle.log; then
        pass "circular dependency is detected"
    else
        fail "circular dependency is detected"
        sed -n '1,10p' /tmp/leanux-cycle.log
    fi
fi

rm -rf "$TMP_SPELLS"

# ---------------------------------------------------------------------------
# 8. Standard-libc fallback only when the spell allows it
# ---------------------------------------------------------------------------
TMP_SPELLS=$(mktemp -d)
cat > "$TMP_SPELLS/fallback_pkg.spell" <<'EOF'
PACKAGE_NAME="fallback_pkg"
DEPENDENCIES=()
EXTERNAL_DEPENDENCIES=()
SOURCE_URL=""
FALLBACK_ALLOWED=1
build() {
    case "$(basename "$CC")" in
        dietgcc|dietcc)
            log "simulated dietlibc failure"
            return 1
            ;;
        *)
            log "fallback build with $CC"
            ;;
    esac
}
EOF

if SPELL_DIR="$TMP_SPELLS" STAGING_DIR="$ROOT/sysroot" ./spells/cast.sh --force fallback_pkg \
        >/tmp/leanux-fallback.log 2>&1; then
    if grep -q "retrying with standard libc" /tmp/leanux-fallback.log \
            && grep -q "fallback build with gcc" /tmp/leanux-fallback.log; then
        pass "approved stdlibc fallback works"
    else
        fail "approved stdlibc fallback works"
        sed -n '1,15p' /tmp/leanux-fallback.log
    fi
else
    fail "approved stdlibc fallback works"
    sed -n '1,15p' /tmp/leanux-fallback.log
fi

cat > "$TMP_SPELLS/no_fallback.spell" <<'EOF'
PACKAGE_NAME="no_fallback"
DEPENDENCIES=()
EXTERNAL_DEPENDENCIES=()
SOURCE_URL=""
FALLBACK_ALLOWED=0
build() {
    log "simulated dietlibc failure"
    return 1
}
EOF

if SPELL_DIR="$TMP_SPELLS" STAGING_DIR="$ROOT/sysroot" ./spells/cast.sh --force no_fallback \
        >/tmp/leanux-nofallback.log 2>&1; then
    fail "unapproved fallback is refused"
else
    if grep -q "FALLBACK_ALLOWED is not set" /tmp/leanux-nofallback.log; then
        pass "unapproved fallback is refused"
    else
        fail "unapproved fallback is refused"
        sed -n '1,15p' /tmp/leanux-nofallback.log
    fi
fi

rm -rf "$TMP_SPELLS" "$ROOT/sysroot/install/fallback_pkg" "$ROOT/sysroot/install/no_fallback"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
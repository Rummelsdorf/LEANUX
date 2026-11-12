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
check "compile-all.sh syntax" bash -n tests/compile-all.sh
check "compare-libc.sh syntax" bash -n tests/compare-libc.sh
check "build-release.sh syntax" bash -n tests/build-release.sh
check "fetch_sources.py syntax" python3 -m py_compile tools/fetch_sources.py
check "verify_sources.py syntax" python3 -m py_compile tools/verify_sources.py

# SOURCE_FILE lets a spell cache an archive under a unique name when the
# upstream URL basename is ambiguous or not descriptive.
TMP_SRC=$(mktemp -d)
cat > "$TMP_SRC/renamed.spell" <<'EOF'
PACKAGE_NAME="renamed"
SOURCE_URL="https://example.invalid/v1.2.3.tar.gz"
SOURCE_FILE="renamed-1.2.3.tar.gz"
SOURCE_HASH=""
EOF
check "SOURCE_FILE overrides the cached archive name" \
    python3 -c "
import sys
from pathlib import Path
sys.path.insert(0, 'tools')
from fetch_sources import parse_spell
spell = parse_spell(Path('$TMP_SRC/renamed.spell'))
sys.exit(0 if spell.file == 'renamed-1.2.3.tar.gz' else 1)
"
rm -rf "$TMP_SRC"
check "compile_report.py syntax" python3 -m py_compile tools/compile_report.py
check "compare_report.py syntax" python3 -m py_compile tools/compare_report.py
check "select_libc.py syntax" python3 -m py_compile tools/select_libc.py
check "make_localrepo.py syntax" python3 -m py_compile tools/make_localrepo.py
check "collect_runtime_deps.py syntax" python3 -m py_compile tools/collect_runtime_deps.py
check "full_report.py syntax" python3 -m py_compile tools/full_report.py
check "fetch selection matches world.order" \
    test "$(python3 tools/fetch_sources.py --list --selection world | wc -l)" \
         -eq "$(grep -vcE '^[[:space:]]*(#|$)' build/world.order)"
check "xtrans is part of the world order" grep -qx xtrans build/world.order
check "libX11 resolves xtrans as a build dependency" \
    bash -c './spells/cast.sh --dry-run libX11 2>/dev/null | grep -qx xtrans'

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
# 9. glibc mode skips dietcompat and writes a glibc marker
# ---------------------------------------------------------------------------
TMP_SPELLS=$(mktemp -d)
GLIBC_TEST=$(mktemp -d)
cat > "$TMP_SPELLS/glibc_pkg.spell" <<'EOF'
PACKAGE_NAME="glibc_pkg"
DEPENDENCIES=()
EXTERNAL_DEPENDENCIES=()
SOURCE_URL=""
USE_DIETCOMPAT=1
build() {
    log "glibc test build with $CC"
    install -d "$DESTDIR/usr/bin"
    printf 'glibc-test\n' > "$DESTDIR/usr/bin/glibc_pkg"
}
EOF

if SPELL_DIR="$TMP_SPELLS" STAGING_DIR="$GLIBC_TEST/sysroot" \
        BUILD_ROOT="$GLIBC_TEST/build" HOSTCC=gcc \
        ./spells/cast.sh --libc glibc glibc_pkg >/tmp/leanux-glibc.log 2>&1; then
    pass "glibc mode builds a spell"
else
    fail "glibc mode builds a spell"
    sed -n '1,15p' /tmp/leanux-glibc.log
fi

if [ "$(cat "$GLIBC_TEST/sysroot/install/glibc_pkg/.libc" 2>/dev/null)" = "glibc" ]; then
    pass "glibc mode writes the glibc marker"
else
    fail "glibc mode writes the glibc marker"
fi

if [ ! -e "$GLIBC_TEST/sysroot/install/dietcompat" ]; then
    pass "glibc mode does not build dietcompat"
else
    fail "glibc mode does not build dietcompat"
fi

rm -rf "$TMP_SPELLS" "$GLIBC_TEST"

# ---------------------------------------------------------------------------
# 10. Size comparison helpers
# ---------------------------------------------------------------------------
SIZE_TEST=$(mktemp -d)
mkdir -p "$SIZE_TEST/stage/usr/bin" "$SIZE_TEST/stage/usr/share/man/man1"
printf '1234567890' > "$SIZE_TEST/stage/usr/bin/tool"
printf 'ignored documentation' > "$SIZE_TEST/stage/usr/share/man/man1/tool.1"
printf 'dietlibc\n' > "$SIZE_TEST/stage/.libc"
printf '' > "$SIZE_TEST/stage/.built"

MEASURE=$(python3 tools/compare_report.py measure --stage "$SIZE_TEST/stage" 2>/dev/null || true)
if [ "$MEASURE" = "$(printf '10\t1')" ]; then
    pass "artifact measurement ignores docs and markers"
else
    fail "artifact measurement ignores docs and markers (got: $MEASURE)"
fi

cat > "$SIZE_TEST/libc-size-comparison.tsv" <<'EOF'
# package	diet_result	glibc_result	diet_bytes	glibc_bytes	diff_bytes	ratio	diet_files	glibc_files	seconds	reason	log
zlib	PASS (dietlibc)	PASS	1000	1500	500	1.5	1	1	1		log
EOF
if python3 tools/compare_report.py render \
        --tsv "$SIZE_TEST/libc-size-comparison.tsv" --md "$SIZE_TEST/comparison.md" \
        && grep -q 'Size comparison: dietlibc vs glibc' "$SIZE_TEST/comparison.md" \
        && grep -q '| `zlib` |' "$SIZE_TEST/comparison.md"; then
    pass "size comparison renders a Markdown table"
else
    fail "size comparison renders a Markdown table"
fi

cat > "$SIZE_TEST/matrix.tsv" <<'EOF'
# index	package	result	libc	seconds	exit	reason	log
# started=2026-01-01T00:00:00 selection=only mode=force timeout=900 host=test jobs=4
1	zlib	PASS (dietlibc)	dietlibc	2	0		compile-logs/zlib.log
EOF
touch -t 202601010000 "$SIZE_TEST/matrix.tsv"
touch -t 202601010001 "$SIZE_TEST/libc-size-comparison.tsv"
if python3 tools/compile_report.py \
        --tsv "$SIZE_TEST/matrix.tsv" --md "$SIZE_TEST/matrix.md" --quiet \
        && grep -q 'Size comparison: dietlibc vs glibc' "$SIZE_TEST/matrix.md" \
        && grep -q 'Selection: `only`' "$SIZE_TEST/matrix.md"; then
    pass "main report picks up the size comparison"
else
    fail "main report picks up the size comparison"
fi

cp "$SIZE_TEST/matrix.tsv" "$SIZE_TEST/compile-matrix.tsv"
if python3 tools/full_report.py --report-dir "$SIZE_TEST" \
        --out "$SIZE_TEST/result.md" >/dev/null \
        && grep -qF 'LEANUX – Kompilier- und Größenvergleich' "$SIZE_TEST/result.md" \
        && grep -qF '| PASS insgesamt | 1 |' "$SIZE_TEST/result.md" \
        && grep -qF '| **Gesamt (1)** |' "$SIZE_TEST/result.md"; then
    pass "consolidated result file contains matrix and comparison"
else
    fail "consolidated result file contains matrix and comparison"
fi

# Per-package libc selection: dietlibc only wins when it is strictly smaller.
SEL_TEST=$(mktemp -d)
cat > "$SEL_TEST/matrix.tsv" <<'EOF'
# index	package	result	libc	seconds	exit	reason	log
# started=2026-01-01T00:00:00 selection=only mode=force timeout=900 host=test jobs=4
1	small	PASS (dietlibc)	dietlibc	1	0		log
2	big	PASS (dietlibc)	dietlibc	1	0		log
3	failed	FAIL	dietlibc	1	1		dietlibc build failed	log
EOF
cat > "$SEL_TEST/comparison.tsv" <<'EOF'
# package	diet_result	glibc_result	diet_bytes	glibc_bytes	diff_bytes	ratio	diet_files	glibc_files	seconds	reason	log
small	PASS (dietlibc)	PASS	100	200	100	2.0	1	1	1		log
big	PASS (dietlibc)	PASS	300	200	-100	0.6667	1	1	1		log
EOF
if python3 tools/select_libc.py --matrix "$SEL_TEST/matrix.tsv" \
        --comparison "$SEL_TEST/comparison.tsv" --out-dir "$SEL_TEST" --quiet \
        && awk -F'\t' '$1=="small" && $2=="dietlibc"' "$SEL_TEST/libc-selection.tsv" | grep -q . \
        && awk -F'\t' '$1=="big" && $2=="glibc"' "$SEL_TEST/libc-selection.tsv" | grep -q . \
        && awk -F'\t' '$1=="failed" && $2=="glibc"' "$SEL_TEST/libc-selection.tsv" | grep -q . \
        && grep -qx small "$SEL_TEST/dietlibc-packages.list" \
        && grep -qx big "$SEL_TEST/glibc-packages.list"; then
    pass "libc selection applies the smaller-artifact rule"
else
    fail "libc selection applies the smaller-artifact rule"
fi
rm -rf "$SEL_TEST"

rm -rf "$SIZE_TEST"

# ---------------------------------------------------------------------------
# localrepo generation
# ---------------------------------------------------------------------------
LR_TEST=$(mktemp -d)
if python3 tools/make_localrepo.py bash zlib dbus \
        --out "$LR_TEST/localrepo" --no-timestamp >"$LR_TEST/generate.log" 2>&1; then
    pass "localrepo is generated from package names"
else
    fail "localrepo is generated from package names"
    sed -n '1,10p' "$LR_TEST/generate.log"
fi

check "localrepo has the documented column header" \
    grep -qF $'name\tversion\trelease\tlibc\tsource_url\tsource_file\tsize\tsha256\tsignature\tsignature_url' \
    "$LR_TEST/localrepo"
check "localrepo contains the requested packages only" \
    bash -c "grep -qP '^bash\t' '$LR_TEST/localrepo' \
        && grep -qP '^zlib\t' '$LR_TEST/localrepo' \
        && ! grep -qP '^firefox\t' '$LR_TEST/localrepo'"
check "localrepo rows carry a SHA-256 signature" \
    awk -F'\t' '$1=="bash" && $8 ~ /^[0-9a-f]{64}$/ && $9 == "sha256:" $8 {ok=1} END {exit !ok}' \
    "$LR_TEST/localrepo"
check "localrepo picks the libc selection per package" \
    bash -c "printf 'package\tlibc\nzlib\tdietlibc\n' > '$LR_TEST/libc.tsv' \
        && python3 tools/make_localrepo.py zlib --libc-table '$LR_TEST/libc.tsv' \
            --out '$LR_TEST/libc-localrepo' --no-timestamp >/dev/null 2>&1 \
        && grep -qP '^zlib\t1\.3\.1\t1\tdietlibc\t' '$LR_TEST/libc-localrepo'"
check "localrepo checksum verifies" \
    bash -c "cd '$LR_TEST' && sha256sum -c localrepo.sha256 >/dev/null"
check "localrepo excludes fixture spells" \
    bash -c "! grep -qP '^(template|test_a|test_b)\t' '$LR_TEST/localrepo'"

if python3 tools/make_localrepo.py --profile base \
        --out "$LR_TEST/base-localrepo" --no-timestamp >/dev/null 2>&1 \
        && grep -qP '^bash\t' "$LR_TEST/base-localrepo" \
        && ! grep -qP '^firefox\t' "$LR_TEST/base-localrepo"; then
    pass "localrepo --profile base selects the base package set"
else
    fail "localrepo --profile base selects the base package set"
fi

check "localrepo rejects unknown package names" \
    bash -c "! python3 tools/make_localrepo.py does-not-exist \
        --out '$LR_TEST/unknown' >/dev/null 2>&1"
check "localrepo rejects fixture package names" \
    bash -c "! python3 tools/make_localrepo.py template \
        --out '$LR_TEST/fixture' >/dev/null 2>&1"
rm -rf "$LR_TEST"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
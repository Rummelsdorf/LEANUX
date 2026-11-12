#!/usr/bin/env bash
# tests/compare-libc.sh – build a glibc variant of every package that passed the
# dietlibc matrix and compare the installed payload sizes.  With
# --include-failed, packages whose dietlibc build failed are measured too.
#
# Usage:
#   ./tests/compare-libc.sh                    # all dietlibc PASS packages
#   ./tests/compare-libc.sh --include-failed   # also build glibc for dietlibc failures
#   ./tests/compare-libc.sh --only zlib,xz     # selected packages
#   ./tests/compare-libc.sh --force            # rebuild glibc variants
#   ./tests/compare-libc.sh --timeout 600      # per-package timeout (seconds)
#   ./tests/compare-libc.sh --report-dir DIR   # read/write reports elsewhere
#   ./tests/compare-libc.sh --matrix FILE      # use a specific compile matrix
#
# Glibc builds use their own staging and build roots so the dietlibc stages
# stay untouched.  Both variants are linked statically, therefore the glibc
# executables contain the C library itself; that is exactly what the size
# comparison is meant to show.
#
# Results:
#   reports/libc-size-comparison.tsv           machine-readable rows
#   reports/libc-size-comparison.md            human-readable table
#   reports/glibc-logs/<package>.log           full glibc build log per package
#
# The main report (reports/compile-matrix.md) automatically picks up the
# comparison table on its next render.

set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
cd "$ROOT"

REPORT_DIR="${REPORT_DIR:-$ROOT/reports}"
MATRIX_TSV=""
ONLY=""
FORCE=0
INCLUDE_FAILED=0
TIMEOUT="${COMPARE_TIMEOUT:-1200}"
export JOBS="${JOBS:-4}"

DIET_STAGING_DIR="${DIET_STAGING_DIR:-$ROOT/sysroot}"
STAGING_DIR="${GLIBC_STAGING_DIR:-$ROOT/sysroot-glibc}"
BUILD_ROOT="${GLIBC_BUILD_ROOT:-$ROOT/build-output-glibc}"
SOURCES_DIR="${SOURCES_DIR:-$ROOT/sources}"
# The compatibility shim only exists for dietlibc and has no glibc counterpart.
SKIP_PACKAGES="${SKIP_PACKAGES:-dietcompat}"

usage() {
    sed -n '2,29p' "$0"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --only)
            [ $# -ge 2 ] || { echo "ERROR: --only needs a value" >&2; exit 2; }
            ONLY="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        --reuse) FORCE=0; shift ;;
        --include-failed) INCLUDE_FAILED=1; shift ;;
        --timeout)
            [ $# -ge 2 ] || { echo "ERROR: --timeout needs a value" >&2; exit 2; }
            TIMEOUT="$2"; shift 2 ;;
        --report-dir)
            [ $# -ge 2 ] || { echo "ERROR: --report-dir needs a value" >&2; exit 2; }
            REPORT_DIR="$2"; shift 2 ;;
        --matrix)
            [ $# -ge 2 ] || { echo "ERROR: --matrix needs a value" >&2; exit 2; }
            MATRIX_TSV="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

REPORT_DIR="$(realpath -m "$REPORT_DIR")"
MATRIX_TSV="${MATRIX_TSV:-$REPORT_DIR/compile-matrix.tsv}"
MATRIX_TSV="$(realpath -m "$MATRIX_TSV")"
LOG_DIR="$REPORT_DIR/glibc-logs"
TSV="$REPORT_DIR/libc-size-comparison.tsv"
MD="$REPORT_DIR/libc-size-comparison.md"
MAIN_MD="$REPORT_DIR/compile-matrix.md"

if [ ! -f "$MATRIX_TSV" ]; then
    echo "ERROR: compile matrix not found: $MATRIX_TSV" >&2
    echo "       run ./tests/compile-all.sh first" >&2
    exit 1
fi

mkdir -p "$LOG_DIR" "$STAGING_DIR" "$BUILD_ROOT" "$SOURCES_DIR"

mapfile -t PACKAGES < <(
    if [ "$INCLUDE_FAILED" = "1" ]; then
        awk -F'\t' '!/^#/ && (($3 ~ /^PASS/ && $4 == "dietlibc") ||
                             ($3 ~ /^(FAIL|TIMEOUT)$/ && $4 ~ /^dietlibc/)) { print $2 }' \
            "$MATRIX_TSV"
    else
        awk -F'\t' '!/^#/ && $3 ~ /^PASS/ && $4 == "dietlibc" { print $2 }' "$MATRIX_TSV"
    fi
)

if [ -n "$ONLY" ]; then
    declare -A wanted=()
    IFS=',' read -ra requested <<< "$ONLY"
    for pkg in "${requested[@]}"; do
        pkg="${pkg//[[:space:]]/}"
        [ -n "$pkg" ] && wanted["$pkg"]=1
    done
    filtered=()
    for pkg in "${PACKAGES[@]}"; do
        [ -n "${wanted[$pkg]:-}" ] && filtered+=("$pkg")
    done
    PACKAGES=("${filtered[@]}")
fi

if [ ${#PACKAGES[@]} -eq 0 ]; then
    echo "ERROR: no dietlibc PASS packages selected in $MATRIX_TSV" >&2
    exit 1
fi

HOST="$(hostname 2>/dev/null || echo unknown)"
MODE="reuse"
[ "$FORCE" = "1" ] && MODE="force"
STARTED_AT="$(date -Iseconds)"

{
    printf '# started=%s mode=%s timeout=%s host=%s jobs=%s staging=%s matrix=%s\n' \
        "$STARTED_AT" "$MODE" "$TIMEOUT" "$HOST" "$JOBS" "$STAGING_DIR" "$MATRIX_TSV"
    printf '# package\tdiet_result\tglibc_result\tdiet_bytes\tglibc_bytes\tdiff_bytes\tratio\tdiet_files\tglibc_files\tseconds\treason\tlog\n'
} > "$TSV"

render_comparison() {
    python3 tools/compare_report.py render --tsv "$TSV" --md "$MD"
}

render_main_report() {
    [ -f "$MAIN_MD" ] || return 0
    python3 tools/compile_report.py --tsv "$MATRIX_TSV" --md "$MAIN_MD" \
        --compare-tsv "$TSV" --quiet
}

render_full_report() {
    # One consolidated file for the user, independent of terminal scrollback.
    python3 tools/full_report.py --report-dir "$REPORT_DIR" || true
}

extract_reason() {
    local log="$1" line
    line=$(grep -aE '(\[cast\] ERROR:|configure: error:|CMake Error|fatal error:|undefined reference|cannot find|No such file or directory|not found|FAILED:|Error [0-9]+)' "$log" 2>/dev/null | tail -n 1)
    if [ -z "$line" ]; then
        line=$(tail -n 1 "$log" 2>/dev/null)
    fi
    printf '%s' "$line" | tr '\t|' '  ' | tr '\n' ' ' | cut -c1-240
}

measure_stage() {
    local stage="$1"
    python3 tools/compare_report.py measure --stage "$stage" 2>/dev/null || printf '0\t0\n'
}

is_skipped() {
    local pkg="$1" skip
    for skip in $SKIP_PACKAGES; do
        [ "$pkg" = "$skip" ] && return 0
    done
    return 1
}

total=${#PACKAGES[@]}
index=0
compared=0
failed=0
timed_out=0
skipped=0
cached=0

echo "[compare] $total dietlibc PASS packages, mode=$MODE, timeout=${TIMEOUT}s, JOBS=$JOBS" >&2
[ "$INCLUDE_FAILED" = "1" ] && \
    echo "[compare] including packages that failed the dietlibc build" >&2
echo "[compare] glibc staging: $STAGING_DIR" >&2
echo "[compare] glibc builds:  $BUILD_ROOT" >&2
render_comparison

for pkg in "${PACKAGES[@]}"; do
    index=$((index + 1))
    diet_stage="$DIET_STAGING_DIR/install/$pkg"
    glibc_stage="$STAGING_DIR/install/$pkg"
    glibc_marker="$glibc_stage/.built"
    logrel="glibc-logs/$pkg.log"
    log="$LOG_DIR/$pkg.log"
    seconds=0
    reason=""

    if is_skipped "$pkg"; then
        diet_measure="$(measure_stage "$diet_stage")"
        diet_bytes="${diet_measure%%$'\t'*}"
        diet_files="${diet_measure##*$'\t'}"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$pkg" "PASS (dietlibc)" "SKIP" "$diet_bytes" \
            "" "" "" "$diet_files" "" "0" \
            "dietlibc-only compatibility shim" "" >> "$TSV"
        skipped=$((skipped + 1))
        printf '[compare] [%d/%d] %-28s SKIP (dietlibc-only shim)\n' \
            "$index" "$total" "$pkg" >&2
        render_comparison
        continue
    fi

    diet_result="PASS (dietlibc)"
    diet_bytes=0
    diet_files=0

    if [ -f "$diet_stage/.built" ]; then
        diet_measure="$(measure_stage "$diet_stage")"
        diet_bytes="${diet_measure%%$'\t'*}"
        diet_files="${diet_measure##*$'\t'}"
        [ -n "$diet_bytes" ] || diet_bytes=0
        [ -n "$diet_files" ] || diet_files=0
    elif [ "$INCLUDE_FAILED" = "1" ]; then
        # No dietlibc stage exists because the package cannot be built with
        # dietlibc.  Still measure the glibc variant so the report documents
        # which libc the distribution has to use.
        diet_result="FAIL (dietlibc)"
    else
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$pkg" "PASS (dietlibc)" "SKIP" "0" "" "" "" "0" "" "0" \
            "dietlibc stage missing" "" >> "$TSV"
        skipped=$((skipped + 1))
        printf '[compare] [%d/%d] %-28s SKIP (dietlibc stage missing)\n' \
            "$index" "$total" "$pkg" >&2
        render_comparison
        continue
    fi

    if [ "$diet_result" = "PASS (dietlibc)" ] && [ "$diet_bytes" -eq 0 ]; then
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$pkg" "PASS (dietlibc)" "SKIP" "$diet_bytes" "" "" "" \
            "$diet_files" "" "0" "no compiled payload" "" >> "$TSV"
        skipped=$((skipped + 1))
        printf '[compare] [%d/%d] %-28s SKIP (no compiled payload)\n' \
            "$index" "$total" "$pkg" >&2
        render_comparison
        continue
    fi

    glibc_libc="$(cat "$glibc_stage/.libc" 2>/dev/null || true)"
    need_build=1
    if [ "$FORCE" = "0" ] && [ -f "$glibc_marker" ] && [ "$glibc_libc" = "glibc" ]; then
        need_build=0
        glibc_result="PASS (cached)"
        cached=$((cached + 1))
    fi

    if [ "$need_build" = "1" ]; then
        start_ts=$(date +%s)
        {
            printf '=== LEANUX glibc comparison: %s ===\n' "$pkg"
            printf 'Started: %s\n' "$(date -Iseconds)"
            printf 'Timeout: %ss  JOBS: %s\n' "$TIMEOUT" "$JOBS"
            printf 'Staging: %s\n' "$STAGING_DIR"
            printf 'Command: ./spells/cast.sh --libc glibc --force %s\n\n' "$pkg"
        } > "$log"

        env -u PKG_CONFIG_PATH -u PKG_CONFIG_SYSROOT_DIR \
            LIBC=glibc STAGING_DIR="$STAGING_DIR" BUILD_ROOT="$BUILD_ROOT" \
            SOURCES_DIR="$SOURCES_DIR" JOBS="$JOBS" \
            timeout --signal=TERM --kill-after=30 "$TIMEOUT" \
            ./spells/cast.sh --libc glibc --force "$pkg" >> "$log" 2>&1
        rc=$?
        seconds=$(( $(date +%s) - start_ts ))
        printf 'Finished: %s  Exit: %d  Duration: %ds\n' \
            "$(date -Iseconds)" "$rc" "$seconds" >> "$log"

        if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ] || [ "$rc" -eq 143 ]; then
            glibc_result="TIMEOUT"
            reason="per-package timeout after ${TIMEOUT}s; $(extract_reason "$log")"
            timed_out=$((timed_out + 1))
        elif [ "$rc" -eq 0 ] && [ -f "$glibc_marker" ] && \
             [ "$(cat "$glibc_stage/.libc" 2>/dev/null || true)" = "glibc" ]; then
            glibc_result="PASS"
            compared=$((compared + 1))
        else
            glibc_result="FAIL"
            reason="$(extract_reason "$log")"
            failed=$((failed + 1))
        fi
    else
        compared=$((compared + 1))
    fi

    if [ "$glibc_result" = "PASS" ] || [ "$glibc_result" = "PASS (cached)" ]; then
        glibc_measure="$(measure_stage "$glibc_stage")"
        glibc_bytes="${glibc_measure%%$'\t'*}"
        glibc_files="${glibc_measure##*$'\t'}"
        [ -n "$glibc_bytes" ] || glibc_bytes=0
        [ -n "$glibc_files" ] || glibc_files=0
        diff=$((glibc_bytes - diet_bytes))
        ratio="$(awk -v d="$diet_bytes" -v g="$glibc_bytes" \
            'BEGIN { if (d > 0) printf "%.4f", g / d }')"
    else
        glibc_bytes=0
        glibc_files=0
        diff=0
        ratio=""
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$pkg" "$diet_result" "$glibc_result" "$diet_bytes" "$glibc_bytes" \
        "$diff" "$ratio" "$diet_files" "$glibc_files" "$seconds" \
        "$reason" "$logrel" >> "$TSV"

    printf '[compare] [%d/%d] %-28s %-14s %4ds  %s\n' \
        "$index" "$total" "$pkg" "$glibc_result" "$seconds" "$reason" >&2
    render_comparison
done

FINISHED_AT="$(date -Iseconds)"
printf '# finished=%s\n' "$FINISHED_AT" >> "$TSV"
render_comparison
render_main_report
render_full_report

echo "[compare] done: compared=$compared cached=$cached fail=$failed timeout=$timed_out skip=$skipped" >&2
echo "[compare] report: $MD" >&2
echo "[compare] tsv:    $TSV" >&2
echo "[compare] logs:   $LOG_DIR" >&2

[ "$index" -gt 0 ]

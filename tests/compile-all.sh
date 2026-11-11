#!/usr/bin/env bash
# tests/compile-all.sh – fetch every LEANUX source and try to build it with
# dietlibc, one package at a time, recording a resumable result matrix.
#
# Usage:
#   ./tests/compile-all.sh                     # world order + required extras
#   ./tests/compile-all.sh --all               # every spell except fixtures
#   ./tests/compile-all.sh --only zlib,xz      # selected spells
#   ./tests/compile-all.sh --force             # rebuild packages already staged
#   ./tests/compile-all.sh --timeout 600       # per-package timeout (seconds)
#   ./tests/compile-all.sh --no-fetch          # use the local source cache only
#   ./tests/compile-all.sh --report-dir DIR    # write results somewhere else
#   ./tests/compile-all.sh --compare           # also build+measure glibc variants
#
# Results:
#   reports/compile-matrix.md                  human-readable table
#   reports/compile-matrix.tsv                 machine-readable rows
#   reports/compile-logs/<package>.log         full build log per package
#   reports/libc-size-comparison.md            dietlibc/glibc size comparison
#   reports/glibc-logs/<package>.log           glibc comparison build logs
#
# A package counts as PASS only if cast.sh exits 0 *and* the stage marker
# sysroot/install/<package>/.built exists.  A build that used the documented
# glibc fallback is reported separately.

set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
cd "$ROOT"

REPORT_DIR="${REPORT_DIR:-$ROOT/reports}"
SELECTION="world-extras"
ONLY=""
FORCE=0
FETCH=1
COMPARE=0
TIMEOUT="${COMPILE_TIMEOUT:-1200}"
export JOBS="${JOBS:-4}"

usage() {
    sed -n '2,29p' "$0"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --all) SELECTION="all"; shift ;;
        --world) SELECTION="world"; shift ;;
        --only)
            [ $# -ge 2 ] || { echo "ERROR: --only needs a value" >&2; exit 2; }
            ONLY="$2"; SELECTION="only"; shift 2 ;;
        --force) FORCE=1; shift ;;
        --reuse) FORCE=0; shift ;;
        --no-fetch) FETCH=0; shift ;;
        --fetch) FETCH=1; shift ;;
        --timeout)
            [ $# -ge 2 ] || { echo "ERROR: --timeout needs a value" >&2; exit 2; }
            TIMEOUT="$2"; shift 2 ;;
        --report-dir)
            [ $# -ge 2 ] || { echo "ERROR: --report-dir needs a value" >&2; exit 2; }
            REPORT_DIR="$2"; shift 2 ;;
        --compare) COMPARE=1; shift ;;
        --no-compare) COMPARE=0; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

REPORT_DIR="$(realpath -m "$REPORT_DIR")"
LOG_DIR="$REPORT_DIR/compile-logs"
TSV="$REPORT_DIR/compile-matrix.tsv"
MD="$REPORT_DIR/compile-matrix.md"
FETCH_REPORT="$REPORT_DIR/source-fetch.md"

mkdir -p "$LOG_DIR"

if [ ! -d "$REPORT_DIR" ]; then
    echo "ERROR: could not create report directory: $REPORT_DIR" >&2
    exit 1
fi

if [ "$FETCH" = "1" ]; then
    echo "[matrix] fetching sources (selection: $SELECTION)" >&2
    fetch_args=(--selection "$SELECTION" --report "$FETCH_REPORT")
    [ -n "$ONLY" ] && fetch_args+=(--only "$ONLY")
    python3 tools/fetch_sources.py "${fetch_args[@]}" || \
        echo "[matrix] WARNING: source fetch reported failures; continuing" >&2
fi

list_args=(--list --selection "$SELECTION")
[ -n "$ONLY" ] && list_args+=(--only "$ONLY")
mapfile -t PACKAGES < <(python3 tools/fetch_sources.py "${list_args[@]}")
if [ ${#PACKAGES[@]} -eq 0 ]; then
    echo "ERROR: no packages selected" >&2
    exit 1
fi

HOST="$(hostname 2>/dev/null || echo unknown)"
MODE="reuse"
[ "$FORCE" = "1" ] && MODE="force"
STARTED_AT="$(date -Iseconds)"

{
    printf '# index\tpackage\tresult\tlibc\tseconds\texit\treason\tlog\n'
    printf '# started=%s selection=%s mode=%s timeout=%s host=%s jobs=%s\n' \
        "$STARTED_AT" "$SELECTION" "$MODE" "$TIMEOUT" "$HOST" "$JOBS"
} > "$TSV"

render_report() {
    python3 tools/compile_report.py \
        --tsv "$TSV" --md "$MD" \
        --selection "$SELECTION" --timeout "${TIMEOUT}s" \
        --mode "$MODE" --host "$HOST" --jobs "$JOBS" --quiet
}

extract_reason() {
    local log="$1" line
    line=$(grep -aE '(\[cast\] ERROR:|configure: error:|CMake Error|fatal error:|undefined reference|cannot find|No such file or directory|not found|FAILED:|Error [0-9]+)' "$log" 2>/dev/null | tail -n 1)
    if [ -z "$line" ]; then
        line=$(tail -n 1 "$log" 2>/dev/null)
    fi
    printf '%s' "$line" | tr '\t|' '  ' | tr '\n' ' ' | cut -c1-240
}

total=${#PACKAGES[@]}
index=0
diet=0
fallback=0
cached=0
failed=0
timed_out=0
other=0

echo "[matrix] $total packages, selection=$SELECTION, mode=$MODE, timeout=${TIMEOUT}s, JOBS=$JOBS" >&2
render_report

for pkg in "${PACKAGES[@]}"; do
    index=$((index + 1))
    stage="$ROOT/sysroot/install/$pkg"
    marker="$stage/.built"
    logrel="compile-logs/$pkg.log"
    log="$LOG_DIR/$pkg.log"
    seconds=0
    rc=0
    reason=""
    libc=""

    if [ -f "$marker" ] && [ "$FORCE" = "0" ]; then
        libc="$(cat "$stage/.libc" 2>/dev/null || echo unknown)"
        result="PASS (cached)"
        cached=$((cached + 1))
        printf '[matrix] [%d/%d] %-28s %s (%s)\n' "$index" "$total" "$pkg" "$result" "$libc" >&2
        printf '%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$index" "$pkg" "$result" "$libc" "$seconds" "$rc" "$reason" "$logrel" >> "$TSV"
        render_report
        continue
    fi

    start_ts=$(date +%s)
    {
        printf '=== LEANUX compile matrix: %s ===\n' "$pkg"
        printf 'Started: %s\n' "$(date -Iseconds)"
        printf 'Selection: %s  Mode: %s  Timeout: %ss  JOBS: %s\n' \
            "$SELECTION" "$MODE" "$TIMEOUT" "$JOBS"
        printf 'Command: ./spells/cast.sh --force %s\n\n' "$pkg"
    } > "$log"

    timeout --signal=TERM --kill-after=30 "$TIMEOUT" \
        ./spells/cast.sh --force "$pkg" >> "$log" 2>&1
    rc=$?
    seconds=$(( $(date +%s) - start_ts ))
    printf 'Finished: %s  Exit: %d  Duration: %ds\n' \
        "$(date -Iseconds)" "$rc" "$seconds" >> "$log"

    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ] || [ "$rc" -eq 143 ]; then
        result="TIMEOUT"
        libc="dietlibc"
        timed_out=$((timed_out + 1))
    elif [ "$rc" -eq 0 ] && [ -f "$marker" ]; then
        if grep -aq 'built with standard libc fallback' "$log"; then
            result="PASS (glibc fallback)"
            libc="glibc-fallback"
            fallback=$((fallback + 1))
        else
            result="PASS (dietlibc)"
            libc="dietlibc"
            diet=$((diet + 1))
        fi
    elif [ "$rc" -eq 0 ]; then
        result="PASS (no marker)"
        libc="unknown"
        other=$((other + 1))
    else
        result="FAIL"
        if grep -aq 'retrying with standard libc' "$log"; then
            libc="dietlibc+fallback"
        else
            libc="dietlibc"
        fi
        failed=$((failed + 1))
    fi

    case "$result" in
        PASS*) reason="" ;;
        TIMEOUT) reason="per-package timeout after ${TIMEOUT}s; $(extract_reason "$log")" ;;
        *) reason="$(extract_reason "$log")" ;;
    esac
    printf '[matrix] [%d/%d] %-28s %-22s %4ds  %s\n' \
        "$index" "$total" "$pkg" "$result" "$seconds" "$reason" >&2
    printf '%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$index" "$pkg" "$result" "$libc" "$seconds" "$rc" "$reason" "$logrel" >> "$TSV"
    render_report
done

FINISHED_AT="$(date -Iseconds)"
{
    printf '# finished=%s\n' "$FINISHED_AT"
} >> "$TSV"
render_report

echo "[matrix] done: dietlibc=$diet fallback=$fallback cached=$cached fail=$failed timeout=$timed_out other=$other" >&2
echo "[matrix] report: $MD" >&2
echo "[matrix] tsv:    $TSV" >&2
echo "[matrix] logs:   $LOG_DIR" >&2

if [ "$COMPARE" = "1" ]; then
    echo "[matrix] building glibc variants for the size comparison" >&2
    compare_args=(--report-dir "$REPORT_DIR" --timeout "$TIMEOUT")
    [ "$FORCE" = "1" ] && compare_args+=(--force)
    if [ "$SELECTION" = "only" ] && [ -n "$ONLY" ]; then
        compare_args+=(--only "$ONLY")
    fi
    ./tests/compare-libc.sh "${compare_args[@]}" || \
        echo "[matrix] WARNING: glibc comparison reported an error" >&2
fi

# A matrix with failures is still a successful *test run*: the script itself
# did its job.  Exit non-zero only when nothing could be attempted.
[ "$index" -gt 0 ]

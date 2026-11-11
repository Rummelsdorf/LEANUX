#!/usr/bin/env python3
"""Render the compile-matrix TSV as a Markdown report.

The TSV is written incrementally by ``tests/compile-all.sh``.  This helper is
called after every package so the report is usable even if the run is
interrupted.
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime
from pathlib import Path

COLUMNS = ["index", "package", "result", "libc", "seconds", "exit", "reason", "log"]

sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    from compare_report import read_rows as read_comparison
    from compare_report import render as render_comparison
except ImportError:  # pragma: no cover - only when the helper is missing
    read_comparison = None
    render_comparison = None


def read_metadata(path: Path) -> dict[str, str]:
    """Parse the ``# key=value`` metadata line written by compile-all.sh."""
    meta: dict[str, str] = {}
    if not path.is_file():
        return meta
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.startswith("#"):
            continue
        for token in line[1:].split():
            key, sep, value = token.partition("=")
            if sep and key not in meta:
                meta[key] = value
    return meta


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    rows: list[dict[str, str]] = []
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    for line in lines:
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < len(COLUMNS):
            parts += [""] * (len(COLUMNS) - len(parts))
        rows.append(dict(zip(COLUMNS, parts)))
    return rows


def human_duration(seconds: str) -> str:
    try:
        value = float(seconds)
    except ValueError:
        return seconds
    if value < 60:
        return f"{value:.0f}s"
    minutes, rest = divmod(int(value), 60)
    hours, minutes = divmod(minutes, 60)
    if hours:
        return f"{hours}h {minutes:02d}m"
    return f"{minutes}m {rest:02d}s"


def escape(value: str) -> str:
    return value.replace("|", "/").replace("\n", " ").strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tsv", type=Path, required=True)
    parser.add_argument("--md", type=Path, required=True)
    parser.add_argument("--title", default="LEANUX compile matrix")
    parser.add_argument("--selection", default=None)
    parser.add_argument("--timeout", default=None)
    parser.add_argument("--mode", default=None)
    parser.add_argument("--host", default=None)
    parser.add_argument("--jobs", default=None)
    parser.add_argument(
        "--compare-tsv",
        type=Path,
        default=None,
        help="size-comparison TSV (default: libc-size-comparison.tsv next to --tsv)",
    )
    parser.add_argument("--no-compare", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    metadata = read_metadata(args.tsv)
    selection = args.selection or metadata.get("selection", "world-extras")
    mode = args.mode or metadata.get("mode", "reuse")
    host = args.host or metadata.get("host", "")
    jobs = args.jobs or metadata.get("jobs", "")
    timeout = args.timeout or metadata.get("timeout", "")
    if timeout and timeout.isdigit():
        timeout = f"{timeout}s"

    rows = read_rows(args.tsv)
    counts: dict[str, int] = {}
    for row in rows:
        counts[row["result"]] = counts.get(row["result"], 0) + 1

    diet = sum(count for result, count in counts.items() if result.startswith("PASS (dietlibc"))
    fallback = sum(
        count for result, count in counts.items() if "fallback" in result.lower()
    )
    failed = counts.get("FAIL", 0)
    timed_out = counts.get("TIMEOUT", 0)
    cached = sum(count for result, count in counts.items() if "cached" in result.lower())

    lines = [
        f"# {args.title}",
        "",
        f"- Generated: {datetime.now().isoformat(timespec='seconds')}",
        f"- Selection: `{selection}`",
        f"- Mode: `{mode}`",
        f"- Per-package timeout: {timeout or 'none'}",
        f"- Host: {host or 'unknown'}",
        f"- JOBS: {jobs or 'default'}",
        f"- Packages attempted: {len(rows)}",
        "",
        "## Summary",
        "",
        "| Result | Count |",
        "|---|---:|",
        f"| PASS with dietlibc | {diet} |",
        f"| PASS with glibc fallback | {fallback} |",
        f"| PASS cached (not rebuilt) | {cached} |",
        f"| FAIL | {failed} |",
        f"| TIMEOUT | {timed_out} |",
    ]
    other = {
        key: value
        for key, value in counts.items()
        if not (
            key.startswith("PASS (dietlibc")
            or "fallback" in key.lower()
            or "cached" in key.lower()
            or key in {"FAIL", "TIMEOUT"}
        )
    }
    for key in sorted(other):
        lines.append(f"| {escape(key)} | {other[key]} |")

    lines.extend(
        [
            "",
            "## Results",
            "",
            "| # | Package | Result | Libc | Duration | Exit | Reason | Log |",
            "|---:|---|---|---|---:|---:|---|---|",
        ]
    )
    for row in rows:
        log = row["log"]
        log_cell = f"[log]({log})" if log else ""
        lines.append(
            f"| {row['index']} | `{row['package']}` | {escape(row['result'])} | "
            f"{escape(row['libc'])} | {human_duration(row['seconds'])} | "
            f"{escape(row['exit'])} | {escape(row['reason'])} | {log_cell} |"
        )
    lines.append("")

    compare_path: Path | None = None
    if not args.no_compare and read_comparison and render_comparison:
        if args.compare_tsv:
            compare_path = args.compare_tsv
            use_compare = compare_path.is_file()
        else:
            compare_path = args.tsv.with_name("libc-size-comparison.tsv")
            # A comparison from an older matrix run is stale: cast.sh --force
            # rebuilds stages, so only reuse it when it is at least as new as
            # the matrix that produced it.
            use_compare = (
                compare_path.is_file()
                and compare_path.stat().st_mtime >= args.tsv.stat().st_mtime
            )
        if use_compare:
            compare_rows = read_comparison(compare_path)
            if compare_rows:
                lines.extend(render_comparison(compare_rows))

    if not args.quiet:
        print(
            f"[matrix] {len(rows)} packages: dietlibc={diet}, "
            f"fallback={fallback}, cached={cached}, fail={failed}, timeout={timed_out}"
        )

    args.md.parent.mkdir(parents=True, exist_ok=True)
    args.md.write_text("\n".join(lines), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())

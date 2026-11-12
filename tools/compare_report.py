#!/usr/bin/env python3
"""Measure staged artifacts and render the dietlibc/glibc size comparison.

Subcommands
-----------
measure --stage DIR
    Print ``<bytes>\\t<files>`` for the installed payload of a staged package.
    Documentation, pkg-config metadata and build markers are ignored so the
    number represents compiled binaries, libraries and data.

render --tsv FILE --md FILE
    Render a Markdown table from the TSV written by ``tests/compare-libc.sh``.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

COLUMNS = [
    "package",
    "diet_result",
    "glibc_result",
    "diet_bytes",
    "glibc_bytes",
    "diff_bytes",
    "ratio",
    "diet_files",
    "glibc_files",
    "seconds",
    "reason",
    "log",
]

# These parts are packaging metadata or documentation, not compiled output.
IGNORED_PARTS = {"man", "doc", "info", "locale", "pkgconfig", "aclocal", "cmake"}
IGNORED_NAMES = {".built", ".libc", ".gitkeep"}


def payload_files(stage: Path) -> list[Path]:
    files: list[Path] = []
    if not stage.is_dir():
        return files
    for path in stage.rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        rel = path.relative_to(stage)
        if rel.name in IGNORED_NAMES:
            continue
        if any(part in IGNORED_PARTS for part in rel.parts):
            continue
        files.append(path)
    return files


def measure(stage: Path) -> tuple[int, int]:
    files = payload_files(stage)
    return sum(path.stat().st_size for path in files), len(files)


def human_size(value: int | str) -> str:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return str(value)
    sign = "-" if number < 0 else ""
    number = abs(number)
    for unit in ("B", "KiB", "MiB", "GiB"):
        if number < 1024 or unit == "GiB":
            if unit == "B":
                return f"{sign}{number:.0f} {unit}"
            return f"{sign}{number:.1f} {unit}"
        number /= 1024
    return f"{sign}{number:.1f} GiB"


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    rows: list[dict[str, str]] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < len(COLUMNS):
            parts += [""] * (len(COLUMNS) - len(parts))
        rows.append(dict(zip(COLUMNS, parts)))
    return rows


def ratio_text(row: dict[str, str]) -> str:
    try:
        diet = int(row["diet_bytes"])
        glibc = int(row["glibc_bytes"])
    except ValueError:
        return row.get("ratio", "")
    if diet == 0:
        return "–"
    return f"{glibc / diet:.2f}×"


def diff_text(row: dict[str, str]) -> str:
    try:
        diff = int(row["diff_bytes"])
    except ValueError:
        try:
            diff = int(row["glibc_bytes"]) - int(row["diet_bytes"])
        except ValueError:
            return ""
    sign = "+" if diff > 0 else ""
    return f"{sign}{human_size(diff)}"


def passes(row: dict[str, str], key: str) -> bool:
    return str(row.get(key, "")).startswith("PASS")


def render(rows: list[dict[str, str]]) -> list[str]:
    compared = [row for row in rows if passes(row, "glibc_result")]
    paired = [row for row in compared if int(row["diet_bytes"] or 0) > 0]
    lines = [
        "## Size comparison: dietlibc vs glibc",
        "",
        "Both variants are built from the same source and spells.  C packages "
        "are linked statically (`-static`), so the glibc variant carries the C "
        "library inside every executable and the difference is expected to be "
        "large.  Packages that cannot use dietlibc at all are installed with "
        "their normal dynamic runtime.  The numbers are installed payload sizes "
        "(executables, libraries and data; docs and pkg-config files are "
        "excluded).  A dash in the dietlibc column means the package cannot be "
        "built with dietlibc; only its glibc payload is measured.",
        "",
        "| Package | dietlibc | glibc | Difference | Ratio | Files (diet/glibc) |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    diet_total = glibc_total = files_diet_total = files_glibc_total = 0
    for row in compared:
        diet = int(row["diet_bytes"] or 0)
        glibc = int(row["glibc_bytes"] or 0)
        lines.append(
            f"| `{row['package']}` | {human_size(diet) if diet else '–'} | "
            f"{human_size(glibc)} | "
            f"{diff_text(row) if diet else '–'} | {ratio_text(row)} | "
            f"{row['diet_files'] or '–'}/{row['glibc_files']} |"
        )
    for row in paired:
        diet_total += int(row["diet_bytes"] or 0)
        glibc_total += int(row["glibc_bytes"] or 0)
        files_diet_total += int(row["diet_files"] or 0)
        files_glibc_total += int(row["glibc_files"] or 0)
    if paired:
        diff = glibc_total - diet_total
        sign = "+" if diff > 0 else ""
        total_ratio = f"{glibc_total / diet_total:.2f}×" if diet_total else "–"
        lines.append(
            f"| **Total ({len(paired)})** | **{human_size(diet_total)}** | "
            f"**{human_size(glibc_total)}** | **{sign}{human_size(diff)}** | "
            f"**{total_ratio}** | "
            f"{files_diet_total}/{files_glibc_total} |"
        )
    else:
        lines.append(
            "| _No package has both a dietlibc and a glibc build yet._ | | | | | |"
        )

    skipped = [
        row
        for row in rows
        if passes(row, "diet_result") and not passes(row, "glibc_result")
    ]
    if skipped:
        lines.extend(
            [
                "",
                "### Packages without a glibc comparison build",
                "",
                "| Package | dietlibc | glibc result | Reason | Log |",
                "|---|---|---|---|---|",
            ]
        )
        for row in skipped:
            log = f"[log]({row['log']})" if row.get("log") else ""
            lines.append(
                f"| `{row['package']}` | {row['diet_result']} | "
                f"{row['glibc_result'] or 'not built'} | "
                f"{row.get('reason', '').replace('|', '/')} | {log} |"
            )
    lines.append("")
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    measure_parser = sub.add_parser("measure")
    measure_parser.add_argument("--stage", type=Path, required=True)

    render_parser = sub.add_parser("render")
    render_parser.add_argument("--tsv", type=Path, required=True)
    render_parser.add_argument("--md", type=Path, required=True)

    args = parser.parse_args()

    if args.command == "measure":
        size, count = measure(args.stage)
        print(f"{size}\t{count}")
        return 0

    rows = read_rows(args.tsv)
    lines = render(rows)
    args.md.parent.mkdir(parents=True, exist_ok=True)
    args.md.write_text("\n".join(lines), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())

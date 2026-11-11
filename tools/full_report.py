#!/usr/bin/env python3
"""Write one consolidated LEANUX result file.

The compile matrix and the size comparison are produced incrementally by
``tests/compile-all.sh`` and ``tests/compare-libc.sh``.  This helper combines
them into a single Markdown file in the repository root so the complete result
is available outside the terminal, including every package, reason and log
path.
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

from compile_report import escape, human_duration, read_metadata, read_rows  # noqa: E402
from compare_report import human_size, passes  # noqa: E402
from compare_report import read_rows as read_comparison  # noqa: E402


def int_value(value: str) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def log_cell(row: dict[str, str]) -> str:
    log = row.get("log", "")
    return f"[Log](reports/{log})" if log else ""


def display_path(path: Path) -> str:
    """Return a repository-relative path when possible, else the full path."""
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def result_summary(rows: list[dict[str, str]]) -> list[str]:
    counts: dict[str, int] = {}
    for row in rows:
        counts[row["result"]] = counts.get(row["result"], 0) + 1

    diet = sum(
        1
        for row in rows
        if row["libc"] == "dietlibc" and row["result"].startswith("PASS")
    )
    fallback = sum(
        1
        for row in rows
        if row["libc"] == "glibc-fallback" and row["result"].startswith("PASS")
    )
    cached = sum(count for result, count in counts.items() if "cached" in result.lower())
    failed = counts.get("FAIL", 0)
    timed_out = counts.get("TIMEOUT", 0)
    passed = sum(count for result, count in counts.items() if result.startswith("PASS"))
    other = len(rows) - passed - failed - timed_out

    return [
        "| Ergebnis | Anzahl |",
        "|---|---:|",
        f"| PASS insgesamt | {passed} |",
        f"| davon PASS mit dietlibc | {diet} |",
        f"| davon PASS mit glibc-Fallback | {fallback} |",
        f"| davon aus dem Cache übernommen | {cached} |",
        f"| FAIL | {failed} |",
        f"| TIMEOUT | {timed_out} |",
    ] + ([f"| sonstige | {other} |"] if other else [])


def fetch_summary(path: Path) -> list[str]:
    if not path.is_file():
        return []
    counts: dict[str, int] = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        if parts[0] == "package" or parts[2] == "status":
            continue
        counts[parts[2]] = counts.get(parts[2], 0) + 1
    if not counts:
        return []
    lines = ["", "## Quellen", "", "| Status | Anzahl |", "|---|---:|"]
    for status in sorted(counts):
        lines.append(f"| `{escape(status)}` | {counts[status]} |")
    return lines


def read_tsv(path: Path) -> list[dict[str, str]]:
    """Read a tab-separated report, accepting an optional ``#`` header."""
    if not path.is_file():
        return []
    header: list[str] | None = None
    rows: list[dict[str, str]] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip():
            continue
        if line.startswith("#"):
            candidate = line.lstrip("#").strip().split("\t")
            if candidate and candidate[0] == "package":
                header = candidate
            continue
        parts = line.split("\t")
        if header is None:
            header = parts
            continue
        rows.append(dict(zip(header, parts)))
    return rows


def selection_section(rows: list[dict[str, str]]) -> list[str]:
    """Render the per-package libc decision written by select_libc.py."""
    if not rows:
        return []
    diet = [row for row in rows if row.get("libc") == "dietlibc"]
    glibc = [row for row in rows if row.get("libc") == "glibc"]
    comparable = [
        row for row in rows
        if int_value(row.get("diet_bytes")) > 0 and int_value(row.get("glibc_bytes")) > 0
    ]
    chosen = sum(
        int_value(row["diet_bytes"] if row.get("libc") == "dietlibc" else row["glibc_bytes"])
        for row in comparable
    )
    all_glibc = sum(int_value(row["glibc_bytes"]) for row in comparable)

    lines = [
        "## libc-Auswahl pro Paket",
        "",
        "Ein Paket wird mit **dietlibc** gebaut, wenn sein gemessenes Kompilat "
        "**streng kleiner** ist als die glibc-Variante. Alle anderen Pakete "
        "werden mit **glibc** gebaut.",
        "",
        "| Ergebnis | Anzahl |",
        "|---|---:|",
        f"| dietlibc | {len(diet)} |",
        f"| glibc | {len(glibc)} |",
        "",
        f"- Gewählte Nutzlast (vergleichbare Pakete): {human_size(chosen)}",
        f"- Alles glibc: {human_size(all_glibc)}",
        f"- Ersparnis: {human_size(all_glibc - chosen)}",
        "",
        "| Paket | libc | dietlibc | glibc | Begründung |",
        "|---|---|---:|---:|---|",
    ]
    for row in rows:
        diet_bytes = int_value(row.get("diet_bytes"))
        glibc_bytes = int_value(row.get("glibc_bytes"))
        lines.append(
            f"| `{escape(row.get('package', ''))}` | {escape(row.get('libc', ''))} | "
            f"{human_size(diet_bytes) if diet_bytes else '–'} | "
            f"{human_size(glibc_bytes) if glibc_bytes else '–'} | "
            f"{escape(row.get('reason', ''))} |"
        )

    lines += ["", f"### Nur dietlibc ({len(diet)})", ""]
    lines += [f"- `{escape(row.get('package', ''))}`" for row in diet] or ["_Keine._"]
    lines += ["", f"### Nur glibc ({len(glibc)})", ""]
    lines += [f"- `{escape(row.get('package', ''))}`" for row in glibc] or ["_Keine._"]
    return lines


def release_section(out_dir: Path, title: str = "Erstausgabe / Abbilder") -> list[str]:
    """Summarize the assembled rootfs and the generated images."""
    manifest = read_tsv(out_dir / "rootfs-manifest.tsv")
    if not manifest:
        return []
    diet = sum(1 for row in manifest if row.get("libc") == "dietlibc")
    glibc = len(manifest) - diet
    lines = [
        f"## {title}",
        "",
        f"- Pakete in der Rootfs: {len(manifest)}",
        f"- davon dietlibc: {diet}",
        f"- davon glibc: {glibc}",
    ]
    rootfs = out_dir / "rootfs"
    if rootfs.is_dir():
        size = sum(
            p.lstat().st_size
            for p in rootfs.rglob("*")
            if p.is_file() and not p.is_symlink()
        )
        lines.append(f"- Rootfs-Größe: {human_size(size)}")
    images = sorted(
        [*out_dir.glob("*.img"), *out_dir.glob("*.iso")],
        key=lambda path: path.name,
    )
    for image in images:
        lines.append(f"- `{display_path(image)}` ({human_size(image.stat().st_size)})")
    report = out_dir / "RELEASE-BERICHT.md"
    if report.is_file():
        lines.append(f"- Release-Bericht: `{display_path(report)}`")
    lines.append(
        f"- Manifest: `{display_path(out_dir / 'rootfs-manifest.tsv')}`"
    )
    return lines


def comparison_section(rows: list[dict[str, str]]) -> list[str]:
    compared = [
        row for row in rows if passes(row, "diet_result") and passes(row, "glibc_result")
    ]
    skipped = [
        row for row in rows if passes(row, "diet_result") and not passes(row, "glibc_result")
    ]

    lines = [
        "## Größenvergleich: dietlibc vs. glibc",
        "",
        "Beide Varianten werden aus derselben Quelle und mit denselben Spell-Rezepten "
        "gebaut und statisch gelinkt (`-static`). Gemessen wird die installierte "
        "Nutzlast (Programme, Bibliotheken und Daten); Dokumentation, Locales und "
        "pkg-config-Dateien sind ausgeschlossen. Bei glibc steckt die statisch "
        "gelinkte C-Bibliothek in jeder ausführbaren Datei, daher ist der Unterschied "
        "dort erwartungsgemäß groß.",
        "",
        "| Paket | dietlibc | glibc | Differenz | Faktor | Dateien (diet/glibc) | glibc-Build | Log |",
        "|---|---:|---:|---:|---:|---:|---:|---|",
    ]

    diet_total = glibc_total = files_diet_total = files_glibc_total = seconds_total = 0
    for row in compared:
        diet = int_value(row["diet_bytes"])
        glibc = int_value(row["glibc_bytes"])
        diff = glibc - diet
        diet_total += diet
        glibc_total += glibc
        files_diet_total += int_value(row["diet_files"])
        files_glibc_total += int_value(row["glibc_files"])
        seconds_total += int_value(row["seconds"])
        ratio = f"{glibc / diet:.2f}×" if diet else "–"
        diff_text = f"{'+' if diff > 0 else ''}{human_size(diff)}"
        lines.append(
            f"| `{row['package']}` | {human_size(diet)} | {human_size(glibc)} | "
            f"{diff_text} | {ratio} | "
            f"{row['diet_files'] or 0}/{row['glibc_files'] or 0} | "
            f"{human_duration(row['seconds'])} | {log_cell(row)} |"
        )

    if compared:
        diff = glibc_total - diet_total
        total_ratio = f"{glibc_total / diet_total:.2f}×" if diet_total else "–"
        lines.append(
            f"| **Gesamt ({len(compared)})** | **{human_size(diet_total)}** | "
            f"**{human_size(glibc_total)}** | "
            f"**{'+' if diff > 0 else ''}{human_size(diff)}** | "
            f"**{total_ratio}** | "
            f"{files_diet_total}/{files_glibc_total} | "
            f"**{human_duration(str(seconds_total))}** | |"
        )
    else:
        lines.append("| _Noch kein Paket mit beiden Varianten._ | | | | | | | |")

    if skipped:
        lines += [
            "",
            "### Pakete ohne glibc-Vergleichsbuild",
            "",
            "| Paket | dietlibc | glibc-Ergebnis | Grund | Log |",
            "|---|---|---|---|---|",
        ]
        for row in skipped:
            log = log_cell(row)
            lines.append(
                f"| `{row['package']}` | {escape(row['diet_result'])} | "
                f"{escape(row['glibc_result'] or 'nicht gebaut')} | "
                f"{escape(row.get('reason', ''))} | {log} |"
            )
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report-dir", type=Path, default=ROOT / "reports")
    parser.add_argument("--out", type=Path, default=ROOT / "LEANUX-ERGEBNISSE.md")
    args = parser.parse_args()

    report_dir = args.report_dir.resolve()
    matrix_tsv = report_dir / "compile-matrix.tsv"
    comparison_tsv = report_dir / "libc-size-comparison.tsv"
    if not matrix_tsv.is_file():
        print(f"ERROR: compile matrix not found: {matrix_tsv}", file=sys.stderr)
        return 1

    rows = read_rows(matrix_tsv)
    metadata = read_metadata(matrix_tsv)
    comparison_rows = read_comparison(comparison_tsv)

    failures = [row for row in rows if not row["result"].startswith("PASS")]

    lines = [
        "# LEANUX – Kompilier- und Größenvergleich",
        "",
        f"- Erzeugt: {datetime.now().isoformat(timespec='seconds')}",
        f"- Auswahl: `{metadata.get('selection', 'world-extras')}`",
        f"- Modus: `{metadata.get('mode', 'reuse')}`",
        f"- Timeout pro Paket: {metadata.get('timeout', 'unbekannt')}s",
        f"- Host: {metadata.get('host', 'unbekannt')}",
        f"- JOBS: {metadata.get('jobs', 'unbekannt')}",
        f"- Pakete in der Matrix: {len(rows)}",
        (
            f"- Abgeschlossen: {metadata['finished']}"
            if metadata.get("finished")
            else "- Status: Lauf noch nicht abgeschlossen (Zwischenstand)"
        ),
        "",
        "## Zusammenfassung",
        "",
    ]
    lines += result_summary(rows)
    lines += fetch_summary(report_dir / "source-fetch.tsv")

    lines += [
        "",
        "## Kompilier-Matrix",
        "",
        "| # | Paket | Ergebnis | Libc | Dauer | Exit | Grund | Log |",
        "|---:|---|---|---|---:|---:|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row['index']} | `{row['package']}` | {escape(row['result'])} | "
            f"{escape(row['libc'])} | {human_duration(row['seconds'])} | "
            f"{escape(row['exit'])} | {escape(row['reason'])} | {log_cell(row)} |"
        )

    lines += ["", "## Fehlgeschlagene Pakete", ""]
    if failures:
        lines += [
            "| Paket | Ergebnis | Libc | Grund | Log |",
            "|---|---|---|---|---|",
        ]
        for row in failures:
            lines.append(
                f"| `{row['package']}` | {escape(row['result'])} | "
                f"{escape(row['libc'])} | {escape(row['reason'])} | {log_cell(row)} |"
            )
    else:
        lines.append("_Keine._")

    lines.append("")
    selection_rows = read_tsv(ROOT / "build" / "libc-selection.tsv")
    if selection_rows:
        lines += selection_section(selection_rows)
        lines.append("")
    if comparison_rows:
        lines += comparison_section(comparison_rows)
    else:
        lines += [
            "## Größenvergleich: dietlibc vs. glibc",
            "",
            "_Noch keine Vergleichsdaten vorhanden. `./tests/compare-libc.sh` erzeugt sie._",
        ]

    release_lines = release_section(ROOT / "out", "Erstausgabe / Abbilder (built)")
    if release_lines:
        lines.append("")
        lines += release_lines
    base_lines = release_section(ROOT / "out-base", "Erstausgabe / Abbilder (base)")
    if base_lines:
        lines.append("")
        lines += base_lines

    lines += [
        "",
        "## Artefakte",
        "",
        f"- Kompilier-Matrix: `{display_path(matrix_tsv)}`",
        f"- Größenvergleich: `{display_path(report_dir / 'libc-size-comparison.tsv')}`",
        "- Vollständige Build-Logs: `reports/compile-logs/`",
        "- Vollständige glibc-Logs: `reports/glibc-logs/`",
        "- Quellen-Report: `reports/source-fetch.md`",
        "",
        "Die Markdown-Tabellen oben enthalten alle Pakete. Bei Bedarf stehen die "
        "vollständigen Configure-/Make-Ausgaben in den verlinkten Logdateien.",
        "",
    ]

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text("\n".join(lines), encoding="utf-8")
    print(f"[result] wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Choose dietlibc or glibc per package from the measured size comparison.

Policy
------
A package is built with dietlibc only when it compiled with dietlibc *and*
the measured dietlibc payload is strictly smaller than the glibc payload.
Every other package is built with glibc.  This keeps the size advantage where
it is real and falls back to the normal C library everywhere else.

Inputs
------
reports/compile-matrix.tsv          result of tests/compile-all.sh
reports/libc-size-comparison.tsv    result of tests/compare-libc.sh
build/world.order                   default package order

Outputs
-------
build/libc-selection.tsv            machine-readable decision per package
build/libc-selection.md             German report with the package lists
build/dietlibc-packages.list        one package per line
build/glibc-packages.list           one package per line

Examples
--------
    tools/select_libc.py
    tools/select_libc.py --profile world
    tools/select_libc.py --profile base --out-dir /tmp/selection
    tools/select_libc.py --list dietlibc
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

from compare_report import human_size  # noqa: E402
from compile_report import read_rows as read_matrix  # noqa: E402
from compare_report import read_rows as read_comparison  # noqa: E402

COLUMNS = [
    "package",
    "libc",
    "diet_result",
    "glibc_result",
    "diet_bytes",
    "glibc_bytes",
    "ratio",
    "reason",
]


def int_value(value: str | int | None) -> int:
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


def read_order(path: Path) -> list[str]:
    """Read a package order file, ignoring comments and blank lines."""
    if not path.is_file():
        return []
    packages: list[str] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        name = line.split("#", 1)[0].strip()
        if name and name not in packages:
            packages.append(name)
    return packages


def selected(row: dict[str, str]) -> bool:
    return row["libc"] == "dietlibc" or row["libc"] == "glibc"


def decide(package: str, matrix: dict[str, dict[str, str]],
           comparison: dict[str, dict[str, str]]) -> dict[str, str]:
    """Return one selection row for *package*."""
    m = matrix.get(package, {})
    c = comparison.get(package, {})
    result = m.get("result", "")
    matrix_libc = m.get("libc", "")
    diet_result = c.get("diet_result", result)
    glibc_result = c.get("glibc_result", "")
    diet_bytes = int_value(c.get("diet_bytes"))
    glibc_bytes = int_value(c.get("glibc_bytes"))

    row = {
        "package": package,
        "libc": "glibc",
        "diet_result": diet_result,
        "glibc_result": glibc_result,
        "diet_bytes": str(diet_bytes),
        "glibc_bytes": str(glibc_bytes),
        "ratio": c.get("ratio", ""),
        "reason": "",
    }

    if package == "dietcompat":
        row["libc"] = "dietlibc"
        row["reason"] = "nur für dietlibc-Pakete benötigt"
        return row

    if not result.startswith("PASS"):
        row["reason"] = "dietlibc-Build nicht möglich – Standard-libc"
        return row

    if matrix_libc == "glibc-fallback":
        row["reason"] = "dokumentierter glibc-Fallback im dietlibc-Lauf"
        return row

    if matrix_libc != "dietlibc":
        row["reason"] = "keine dietlibc-Stufe vorhanden – Standard-libc"
        return row

    if glibc_result.startswith("PASS") and diet_bytes > 0 and glibc_bytes > 0:
        if diet_bytes < glibc_bytes:
            row["libc"] = "dietlibc"
            row["reason"] = (
                f"dietlibc-Kompilat kleiner ({human_size(diet_bytes)} < "
                f"{human_size(glibc_bytes)})"
            )
        elif diet_bytes == glibc_bytes:
            row["reason"] = "gleich groß – Standard-libc"
        else:
            row["reason"] = (
                f"glibc-Kompilat kleiner ({human_size(glibc_bytes)} < "
                f"{human_size(diet_bytes)})"
            )
        return row

    if glibc_result == "SKIP":
        if diet_bytes == 0:
            row["reason"] = "keine vergleichbare Nutzlast – Standard-libc"
        else:
            row["reason"] = "glibc-Vergleich übersprungen – Standard-libc"
        return row

    if glibc_result in {"FAIL", "TIMEOUT"}:
        row["libc"] = "dietlibc"
        row["reason"] = "glibc-Build nicht möglich – dietlibc beibehalten"
        return row

    row["reason"] = "kein Größenvergleich – konservativ Standard-libc"
    return row


def load_packages(profile: str, matrix_rows: list[dict[str, str]]) -> list[str]:
    if profile == "all":
        return [row["package"] for row in matrix_rows]
    if profile in {"world", "world-extras"}:
        return read_order(ROOT / "build" / "world.order")
    path = Path(profile)
    if path.is_file():
        return read_order(path)
    candidate = ROOT / "build" / "profiles" / f"{profile}.order"
    if candidate.is_file():
        return read_order(candidate)
    raise SystemExit(f"unknown profile or order file: {profile}")


def render_markdown(rows: list[dict[str, str]], meta: dict[str, str]) -> str:
    diet = [row for row in rows if row["libc"] == "dietlibc"]
    glibc = [row for row in rows if row["libc"] == "glibc"]

    def table(entries: list[dict[str, str]]) -> list[str]:
        lines = [
            "| Paket | dietlibc | glibc | Faktor | Begründung |",
            "|---|---:|---:|---:|---|",
        ]
        for row in entries:
            d = int_value(row["diet_bytes"])
            g = int_value(row["glibc_bytes"])
            ratio = f"{g / d:.2f}×" if d and g else "–"
            lines.append(
                f"| `{row['package']}` | {human_size(d) if d else '–'} | "
                f"{human_size(g) if g else '–'} | {ratio} | {row['reason']} |"
            )
        return lines

    comparable = [
        row for row in rows
        if int_value(row["diet_bytes"]) > 0 and int_value(row["glibc_bytes"]) > 0
    ]
    selected_bytes = sum(
        int_value(row["diet_bytes"] if row["libc"] == "dietlibc" else row["glibc_bytes"])
        for row in comparable
    )
    all_glibc = sum(int_value(row["glibc_bytes"]) for row in comparable)
    all_diet = sum(int_value(row["diet_bytes"]) for row in comparable)
    saving = all_glibc - selected_bytes

    lines = [
        "# LEANUX – libc-Auswahl pro Paket",
        "",
        f"- Erzeugt: {meta['generated']}",
        f"- Profil/Auswahl: `{meta['profile']}`",
        f"- Matrix: `{meta['matrix']}`",
        f"- Größenvergleich: `{meta['comparison']}`",
        f"- Pakete: {len(rows)}",
        "",
        "## Regel",
        "",
        "Ein Paket wird mit **dietlibc** gebaut, wenn es mit dietlibc kompiliert "
        "und sein gemessenes Kompilat **streng kleiner** ist als die glibc-Variante. "
        "Alle anderen Pakete werden mit **glibc** gebaut.",
        "",
        "## Zusammenfassung",
        "",
        "| Ergebnis | Anzahl |",
        "|---|---:|",
        f"| dietlibc | {len(diet)} |",
        f"| glibc | {len(glibc)} |",
        "",
        "| Größe | Wert |",
        "|---|---:|",
        f"| gewählt (vergleichbare Pakete) | {human_size(selected_bytes)} |",
        f"| alles dietlibc (vergleichbare Pakete) | {human_size(all_diet)} |",
        f"| alles glibc (vergleichbare Pakete) | {human_size(all_glibc)} |",
        f"| Ersparnis gegenüber alles glibc | {human_size(saving)} |",
        "",
        f"## Mit dietlibc ({len(diet)})",
        "",
        *table(diet),
        "",
        f"## Mit glibc ({len(glibc)})",
        "",
        *table(glibc),
        "",
        "## Hinweise",
        "",
        "- Pakete ohne dietlibc-PASS werden immer mit glibc gebaut.",
        "- `dietcompat` ist kein normales Paket, sondern die Kompatibilitäts-"
        "bibliothek für dietlibc-Builds.",
        "- Bei Paketen ohne belastbaren Größenvergleich entscheidet die Regel "
        "konservativ für glibc.",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--matrix", type=Path,
                        default=ROOT / "reports" / "compile-matrix.tsv")
    parser.add_argument("--comparison", type=Path,
                        default=ROOT / "reports" / "libc-size-comparison.tsv")
    parser.add_argument("--out-dir", type=Path, default=ROOT / "build")
    parser.add_argument("--profile", default="all",
                        help="all, world, base, desktop, or a path to an .order file")
    parser.add_argument("--list", choices=["dietlibc", "glibc"],
                        help="print only the selected packages for one libc")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    matrix_rows = read_matrix(args.matrix)
    if not matrix_rows:
        print(f"ERROR: compile matrix not found or empty: {args.matrix}",
              file=sys.stderr)
        return 1
    comparison_rows = read_comparison(args.comparison)
    if not comparison_rows:
        print(f"ERROR: size comparison not found or empty: {args.comparison}",
              file=sys.stderr)
        print("       run ./tests/compare-libc.sh first", file=sys.stderr)
        return 1

    matrix = {row["package"]: row for row in matrix_rows}
    comparison = {row["package"]: row for row in comparison_rows}
    packages = load_packages(args.profile, matrix_rows)
    if not packages:
        print(f"ERROR: no packages for profile {args.profile}", file=sys.stderr)
        return 1

    rows = [decide(package, matrix, comparison) for package in packages]

    if args.list:
        for row in rows:
            if row["libc"] == args.list:
                print(row["package"])
        return 0

    args.out_dir.mkdir(parents=True, exist_ok=True)
    tsv = args.out_dir / "libc-selection.tsv"
    md = args.out_dir / "libc-selection.md"
    diet_list = args.out_dir / "dietlibc-packages.list"
    glibc_list = args.out_dir / "glibc-packages.list"

    generated = datetime.now().isoformat(timespec="seconds")
    lines = [
        "# LEANUX libc selection",
        f"# generated={generated}",
        f"# profile={args.profile}",
        f"# policy=dietlibc only when the measured dietlibc payload is strictly smaller",
        "\t".join(COLUMNS),
    ]
    lines += ["\t".join(row[column] for column in COLUMNS) for row in rows]
    tsv.write_text("\n".join(lines) + "\n", encoding="utf-8")

    meta = {
        "generated": generated,
        "profile": args.profile,
        "matrix": args.matrix,
        "comparison": args.comparison,
    }
    md.write_text(render_markdown(rows, meta) + "\n", encoding="utf-8")

    diet_list.write_text(
        "".join(f"{row['package']}\n" for row in rows if row["libc"] == "dietlibc"),
        encoding="utf-8",
    )
    glibc_list.write_text(
        "".join(f"{row['package']}\n" for row in rows if row["libc"] == "glibc"),
        encoding="utf-8",
    )

    if not args.quiet:
        diet = sum(1 for row in rows if row["libc"] == "dietlibc")
        glibc = len(rows) - diet
        print(f"[libc] {len(rows)} Pakete: {diet} dietlibc, {glibc} glibc")
        print(f"[libc] Auswahl: {tsv}")
        print(f"[libc] Bericht: {md}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

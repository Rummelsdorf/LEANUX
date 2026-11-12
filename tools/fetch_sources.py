#!/usr/bin/env python3
"""Fetch (or verify) the source archives for LEANUX spells.

The spell files under ``spells/`` are plain shell files.  This tool only reads
their metadata assignments; it never sources or executes a spell.

Examples
--------
    tools/fetch_sources.py --selection world-extras
    tools/fetch_sources.py --selection all --jobs 6
    tools/fetch_sources.py --check
    tools/fetch_sources.py --list --selection world-extras

Results are written to ``reports/source-fetch.md`` and
``reports/source-fetch.tsv`` (override with ``--report``).
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parent.parent
SPELL_DIR = ROOT / "spells"
SOURCES_DIR = ROOT / "sources"
WORLD_FILE = ROOT / "build" / "world.order"
REPORT_DIR = ROOT / "reports"

# Spells that are fixtures/placeholders rather than real packages.
FIXTURES = {"template", "test_a", "test_b"}

# Packages kept outside build/world.order but still part of the required set.
EXTRAS = ["bash", "tmux", "python3.12", "llama.cpp"]

ASSIGN_RE = re.compile(r"^([A-Z][A-Z0-9_]*)=(.*)$", re.MULTILINE)
VAR_RE = re.compile(r"\$\{([A-Z][A-Z0-9_]*)\}|\$([A-Z][A-Z0-9_]*)")
USER_AGENT = "LEANUX-source-fetcher/1.0"


@dataclass
class Spell:
    name: str
    path: Path
    version: str = ""
    url: str = ""
    file: str = ""
    hash: str = ""
    build_style: str = ""
    fallback_allowed: str = "0"
    dependencies: str = ""


@dataclass
class FetchResult:
    package: str
    version: str = ""
    url: str = ""
    filename: str = ""
    status: str = ""
    size: int = 0
    sha256: str = ""
    detail: str = ""
    seconds: float = 0.0
    index: int = 0
    warnings: list[str] = field(default_factory=list)


def _strip_quotes(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def _expand(value: str, meta: dict[str, str]) -> str:
    def repl(match: re.Match[str]) -> str:
        key = match.group(1) or match.group(2)
        return meta.get(key, "")

    return VAR_RE.sub(repl, value)


def parse_spell(path: Path) -> Spell:
    text = path.read_text(encoding="utf-8", errors="replace")
    raw: dict[str, str] = {}
    for match in ASSIGN_RE.finditer(text):
        raw[match.group(1)] = match.group(2).strip()

    meta = {key: _strip_quotes(value) for key, value in raw.items()}
    spell = Spell(
        name=path.stem,
        path=path,
        version=meta.get("PACKAGE_VERSION", ""),
        url=_expand(meta.get("SOURCE_URL", ""), meta),
        file=_expand(meta.get("SOURCE_FILE", ""), meta),
        hash=meta.get("SOURCE_HASH", ""),
        build_style=meta.get("BUILD_STYLE", ""),
        fallback_allowed=meta.get("FALLBACK_ALLOWED", "0"),
        dependencies=raw.get("DEPENDENCIES", ""),
    )
    return spell


def load_spells() -> dict[str, Spell]:
    return {
        path.stem: parse_spell(path)
        for path in sorted(SPELL_DIR.glob("*.spell"))
        if path.is_file()
    }


def world_order() -> list[str]:
    if not WORLD_FILE.is_file():
        return []
    names: list[str] = []
    for line in WORLD_FILE.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0]
        for word in line.split():
            if word not in names:
                names.append(word)
    return names


def select_spells(
    spells: dict[str, Spell],
    selection: str,
    only: list[str] | None = None,
) -> list[str]:
    if only:
        missing = [name for name in only if name not in spells]
        if missing:
            raise SystemExit(f"unknown spell(s): {', '.join(missing)}")
        return only

    if selection == "all":
        return [name for name in sorted(spells) if name not in FIXTURES]

    if selection == "world":
        names = world_order()
    else:  # world-extras
        names = world_order()
        for extra in EXTRAS:
            if extra in spells and extra not in names:
                names.append(extra)

    missing = [name for name in names if name not in spells]
    if missing:
        raise SystemExit(
            "world order references missing spell(s): " + ", ".join(missing)
        )
    return names


def source_filename(url: str) -> str:
    path = urlparse(url).path
    name = unquote(path.rsplit("/", 1)[-1])
    return name or "source.tar.gz"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _download_curl(url: str, destination: Path, timeout: int) -> None:
    part = destination.with_name(destination.name + ".part")
    base = [
        "curl",
        "-fL",
        "--retry",
        "3",
        "--retry-delay",
        "2",
        "--connect-timeout",
        "20",
        "--max-time",
        str(timeout),
        "-A",
        USER_AGENT,
        "-o",
        str(part),
    ]
    if part.exists() and part.stat().st_size > 0:
        cmd = base[:1] + ["-C", "-"] + base[1:] + [url]
    else:
        cmd = base + [url]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0 and "-C" in cmd:
        # Servers that do not support range requests reject resuming. Retry
        # from scratch rather than reporting a bogus download failure.
        part.unlink(missing_ok=True)
        result = subprocess.run(
            base + [url], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
    if result.returncode != 0:
        tail = (result.stderr or result.stdout).strip().splitlines()
        raise RuntimeError(tail[-1] if tail else f"curl exited {result.returncode}")
    if not part.is_file() or part.stat().st_size == 0:
        raise RuntimeError("download produced an empty file")
    os.replace(part, destination)


def _download_wget(url: str, destination: Path, timeout: int) -> None:
    part = destination.with_name(destination.name + ".part")
    cmd = [
        "wget",
        "-q",
        "-O",
        str(part),
        "--tries=3",
        f"--timeout={max(30, timeout // 10)}",
        url,
    ]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        tail = (result.stderr or result.stdout).strip().splitlines()
        raise RuntimeError(tail[-1] if tail else f"wget exited {result.returncode}")
    os.replace(part, destination)


def download(url: str, destination: Path, timeout: int) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if shutil.which("curl"):
        _download_curl(url, destination, timeout)
    elif shutil.which("wget"):
        _download_wget(url, destination, timeout)
    else:
        raise RuntimeError("neither curl nor wget is available")


def fetch_one(
    spell: Spell,
    *,
    check_only: bool,
    redownload_invalid: bool,
    timeout: int,
    index: int,
) -> FetchResult:
    started = time.monotonic()
    result = FetchResult(
        package=spell.name,
        version=spell.version,
        url=spell.url,
        index=index,
    )

    if not spell.url:
        result.status = "no-source"
        result.detail = "spell builds without an archive"
        result.seconds = time.monotonic() - started
        return result

    destination = SOURCES_DIR / (spell.file or source_filename(spell.url))
    result.filename = destination.name
    expected = spell.hash.strip()
    pinned = bool(expected) and expected != "PLACEHOLDER_HASH"

    def inspect() -> str:
        if not destination.is_file() or destination.stat().st_size == 0:
            return "missing"
        result.size = destination.stat().st_size
        if pinned:
            actual = sha256_file(destination)
            result.sha256 = actual
            if actual != expected:
                return "invalid"
            return "present"
        result.sha256 = sha256_file(destination)
        return "present-unpinned"

    state = inspect()
    if state == "present":
        result.status = "present"
        result.seconds = time.monotonic() - started
        return result
    if state == "present-unpinned":
        result.status = "present-unpinned"
        result.detail = "no SHA-256 pinned in spell"
        result.seconds = time.monotonic() - started
        return result
    if state == "invalid" and not redownload_invalid:
        result.status = "invalid"
        result.detail = "existing archive does not match SOURCE_HASH"
        result.seconds = time.monotonic() - started
        return result
    if check_only:
        result.status = "missing" if state == "missing" else "invalid"
        result.seconds = time.monotonic() - started
        return result

    print(f"[fetch] downloading {spell.name}: {spell.url}", file=sys.stderr, flush=True)
    try:
        download(spell.url, destination, timeout)
    except Exception as exc:  # noqa: BLE001 - report every download failure
        result.status = "failed"
        result.detail = str(exc).replace("\n", " ")[:300]
        result.seconds = time.monotonic() - started
        return result

    result.size = destination.stat().st_size
    if pinned:
        actual = sha256_file(destination)
        result.sha256 = actual
        if actual != expected:
            result.status = "invalid"
            result.detail = "downloaded archive does not match SOURCE_HASH"
        else:
            result.status = "downloaded"
    else:
        result.sha256 = sha256_file(destination)
        result.status = "downloaded-unpinned"
        result.detail = "no SHA-256 pinned in spell"
    result.seconds = time.monotonic() - started
    return result


def human_size(size: int) -> str:
    value = float(size)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if value < 1024 or unit == "TiB":
            return f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"
        value /= 1024
    return f"{size} B"


def write_report(
    results: list[FetchResult],
    report_path: Path,
    *,
    selection: str,
    jobs: int,
    check_only: bool,
) -> None:
    report_path.parent.mkdir(parents=True, exist_ok=True)
    tsv_path = report_path.with_suffix(".tsv")

    ordered = sorted(results, key=lambda item: item.index)
    with tsv_path.open("w", encoding="utf-8") as handle:
        handle.write("package\tversion\tstatus\tbytes\tsha256\tfile\turl\tdetail\n")
        for item in ordered:
            handle.write(
                "\t".join(
                    [
                        item.package,
                        item.version,
                        item.status,
                        str(item.size),
                        item.sha256,
                        item.filename,
                        item.url,
                        item.detail.replace("\t", " ").replace("\n", " "),
                    ]
                )
                + "\n"
            )

    counts: dict[str, int] = {}
    total_bytes = 0
    for item in ordered:
        counts[item.status] = counts.get(item.status, 0) + 1
        total_bytes += item.size

    lines = [
        "# LEANUX source fetch report",
        "",
        f"- Generated: {datetime.now(timezone.utc).isoformat(timespec='seconds')}",
        f"- Selection: `{selection}`",
        f"- Mode: `{'check-only' if check_only else 'fetch'}`",
        f"- Parallel downloads: {jobs}",
        f"- Packages: {len(ordered)}",
        f"- Total archive size: {human_size(total_bytes)}",
        "",
        "## Summary",
        "",
    ]
    for status in sorted(counts):
        lines.append(f"- `{status}`: {counts[status]}")
    lines.extend(
        [
            "",
            "## Details",
            "",
            "| # | Package | Version | Status | Size | SHA-256 | File |",
            "|---:|---|---|---|---:|---|---|",
        ]
    )
    for item in ordered:
        digest = item.sha256[:16] + "…" if len(item.sha256) > 16 else item.sha256
        detail = item.detail.replace("|", "/").replace("\n", " ")
        status = item.status
        if detail:
            status = f"{status}<br><sub>{detail}</sub>"
        lines.append(
            f"| {item.index + 1} | `{item.package}` | {item.version} | {status} | "
            f"{human_size(item.size)} | `{digest}` | `{item.filename}` |"
        )
    lines.append("")
    report_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--selection",
        choices=["world", "world-extras", "all", "only"],
        default="world-extras",
        help="which spells to fetch (default: world-extras)",
    )
    parser.add_argument(
        "--only",
        default="",
        help="comma-separated spell names (implies --selection only)",
    )
    parser.add_argument("--list", action="store_true", help="print selected spell names and exit")
    parser.add_argument("--check", action="store_true", help="verify cached archives only")
    parser.add_argument(
        "--redownload-invalid",
        action="store_true",
        help="re-download archives whose cached SHA-256 is wrong",
    )
    parser.add_argument("--jobs", type=int, default=4, help="parallel downloads (default: 4)")
    parser.add_argument(
        "--timeout", type=int, default=3600, help="per-download timeout in seconds"
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=REPORT_DIR / "source-fetch.md",
        help="Markdown report path",
    )
    args = parser.parse_args()

    only = [name.strip() for name in args.only.split(",") if name.strip()]
    if only:
        args.selection = "only"

    spells = load_spells()
    names = select_spells(spells, args.selection, only or None)

    if args.list:
        for name in names:
            print(name)
        return 0

    SOURCES_DIR.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    results: list[FetchResult] = []

    if args.jobs <= 1:
        for index, name in enumerate(names):
            result = fetch_one(
                spells[name],
                check_only=args.check,
                redownload_invalid=args.redownload_invalid,
                timeout=args.timeout,
                index=index,
            )
            results.append(result)
            print(
                f"[fetch] [{index + 1}/{len(names)}] {name}: {result.status}",
                file=sys.stderr,
                flush=True,
            )
    else:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
            futures = {
                pool.submit(
                    fetch_one,
                    spells[name],
                    check_only=args.check,
                    redownload_invalid=args.redownload_invalid,
                    timeout=args.timeout,
                    index=index,
                ): name
                for index, name in enumerate(names)
            }
            completed = 0
            for future in concurrent.futures.as_completed(futures):
                name = futures[future]
                completed += 1
                try:
                    result = future.result()
                except Exception as exc:  # noqa: BLE001 - one bad spell must not stop the run
                    result = FetchResult(
                        package=name,
                        status="failed",
                        detail=str(exc).replace("\n", " ")[:300],
                        index=names.index(name),
                    )
                results.append(result)
                print(
                    f"[fetch] [{completed}/{len(names)}] {name}: {result.status}",
                    file=sys.stderr,
                    flush=True,
                )

    write_report(
        results,
        args.report,
        selection=args.selection,
        jobs=max(1, args.jobs),
        check_only=args.check,
    )

    counts: dict[str, int] = {}
    for result in results:
        counts[result.status] = counts.get(result.status, 0) + 1
    elapsed = time.monotonic() - started
    print(
        f"[fetch] done in {elapsed:.1f}s: "
        + ", ".join(f"{key}={value}" for key, value in sorted(counts.items())),
        file=sys.stderr,
    )
    print(f"[fetch] report: {args.report}", file=sys.stderr)

    bad = counts.get("failed", 0) + counts.get("invalid", 0) + counts.get("missing", 0)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

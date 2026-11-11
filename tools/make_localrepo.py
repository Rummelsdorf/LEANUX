#!/usr/bin/env python3
"""Generate the LEANUX ``localrepo`` package index from spell metadata.

The spell files under ``spells/`` are plain shell files.  This tool only reads
their metadata assignments; it never sources or executes a spell.  Package
names given on the command line are resolved to spells, their source archives
are hashed, and a tab-separated repository index is written.

Examples
--------
    tools/make_localrepo.py bash curl wget
    tools/make_localrepo.py --all
    tools/make_localrepo.py --profile base
    tools/make_localrepo.py --all --sign-key leanux@example.org

The default output is ``repository/localrepo``.  A detached OpenPGP signature
(``localrepo.asc``) is written when ``--sign`` or ``--sign-key`` is used, and a
``localrepo.sha256`` checksum is always written next to the index.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import sys
import tomllib
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parent.parent
SPELL_DIR = ROOT / "spells"
SOURCES_DIR = ROOT / "sources"
LOCKFILE = ROOT / "build" / "sources.lock.toml"
LIBC_TABLE = ROOT / "build" / "libc-selection.tsv"
PROFILE_DIR = ROOT / "build" / "profiles"
WORLD_ORDER = ROOT / "build" / "world.order"
DEFAULT_OUT = ROOT / "repository" / "localrepo"

# Spells that are fixtures/placeholders rather than real packages.
FIXTURES = {"template", "test_a", "test_b"}

FORMAT_VERSION = "1"
COLUMNS = [
    "name",
    "version",
    "release",
    "libc",
    "source_url",
    "source_file",
    "size",
    "sha256",
    "signature",
    "signature_url",
]

ASSIGN_RE = re.compile(r"^([A-Z][A-Z0-9_]*)=(.*)$", re.MULTILINE)
VAR_RE = re.compile(r"\$\{([A-Z][A-Z0-9_]*)\}|\$([A-Z][A-Z0-9_]*)")
PLACEHOLDER_HASHES = {"", "PLACEHOLDER_HASH", "REPLACE_ME", "TODO"}
BAD_URL_MARKERS = ("example.com", "REPLACE_", "<", ">")


@dataclass
class Spell:
    name: str
    path: Path
    meta: dict[str, str] = field(default_factory=dict)

    @property
    def version(self) -> str:
        return self.meta.get("PACKAGE_VERSION", "")

    @property
    def release(self) -> str:
        return self.meta.get("PACKAGE_RELEASE", "1") or "1"

    @property
    def url(self) -> str:
        return expand(self.meta.get("SOURCE_URL", ""), self.meta)

    @property
    def declared_hash(self) -> str:
        return self.meta.get("SOURCE_HASH", "").strip()

    @property
    def signature_url(self) -> str:
        return expand(
            self.meta.get("SOURCE_SIGNATURE_URL", "")
            or self.meta.get("SOURCE_SIGNATURE", ""),
            self.meta,
        )

    @property
    def real_hash(self) -> str:
        return "" if self.declared_hash in PLACEHOLDER_HASHES else self.declared_hash


@dataclass
class Entry:
    spell: Spell
    version: str
    release: str
    libc: str
    source_url: str
    source_file: str
    size: str
    sha256: str
    signature_url: str
    notes: list[str] = field(default_factory=list)

    @property
    def signature(self) -> str:
        return f"sha256:{self.sha256}" if self.sha256 else "none"

    def fields(self) -> list[str]:
        return [
            self.spell.name,
            self.version,
            self.release,
            self.libc,
            self.source_url,
            self.source_file,
            self.size,
            self.sha256,
            self.signature,
            self.signature_url,
        ]


def _strip_quotes(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def expand(value: str, meta: dict[str, str]) -> str:
    def repl(match: re.Match[str]) -> str:
        return meta.get(match.group(1) or match.group(2), "")

    return VAR_RE.sub(repl, value)


def parse_spell(path: Path) -> Spell:
    text = path.read_text(encoding="utf-8", errors="replace")
    meta = {
        match.group(1): _strip_quotes(match.group(2))
        for match in ASSIGN_RE.finditer(text)
    }
    return Spell(name=path.stem, path=path, meta=meta)


def load_spells() -> dict[str, Spell]:
    return {
        path.stem: parse_spell(path)
        for path in sorted(SPELL_DIR.glob("*.spell"))
        if path.is_file()
    }


def read_order(path: Path) -> list[str]:
    names: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0]
        for word in line.split():
            if word not in names:
                names.append(word)
    return names


def profile_names(profile: str) -> list[str]:
    if profile == "world":
        path = WORLD_ORDER
    else:
        path = PROFILE_DIR / f"{profile}.order"
    if not path.is_file():
        raise SystemExit(f"unknown profile {profile!r}: {path} does not exist")
    return read_order(path)


def load_lock(path: Path = LOCKFILE) -> dict[str, dict[str, str]]:
    if not path.is_file():
        return {}
    with path.open("rb") as handle:
        manifest = tomllib.load(handle)
    return {
        source.get("name", ""): source
        for source in manifest.get("source", [])
        if source.get("name")
    }


def load_libc_table(path: Path = LIBC_TABLE) -> dict[str, str]:
    selection: dict[str, str] = {}
    if not path.is_file():
        return selection
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        fields = line.split("\t")
        if fields[0] == "package" or len(fields) < 2:
            continue
        selection[fields[0]] = fields[1]
    return selection


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def source_filename(url: str) -> str:
    path = urlparse(url).path
    name = unquote(path.rsplit("/", 1)[-1]) if path else ""
    return name or "source.tar.gz"


def find_archive(
    url: str, lock: dict[str, str], sources_dir: Path
) -> Path | None:
    for candidate in (url, lock.get("url", "")):
        if not candidate:
            continue
        path = sources_dir / source_filename(candidate)
        if path.is_file():
            return path
    return None


def build_entry(
    spell: Spell,
    *,
    lock: dict[str, str],
    sources_dir: Path,
    libc_table: dict[str, str],
    allow_unpinned: bool,
) -> tuple[Entry | None, str]:
    """Return (entry, reason).  A reason is set when the spell is skipped."""
    url = spell.url or lock.get("url", "")
    if not url:
        return None, "no source URL"
    if any(marker in url for marker in BAD_URL_MARKERS):
        if not allow_unpinned:
            return None, "no fetchable source URL"
        archive = None
    else:
        archive = find_archive(url, lock, sources_dir)

    sha = ""
    size = ""
    notes: list[str] = []

    if archive is not None:
        sha = sha256_file(archive)
        size = str(archive.stat().st_size)
        if source_filename(url) != archive.name:
            notes.append(
                f"archive cached as {archive.name}; URL names {source_filename(url)}"
            )
        if spell.real_hash and spell.real_hash != sha:
            notes.append(
                f"spell hash {spell.real_hash[:12]}… differs from archive; using archive"
            )
    elif spell.real_hash:
        sha = spell.real_hash
        notes.append("hash from spell metadata (archive not cached)")
    elif lock.get("sha256"):
        sha = lock["sha256"]
        notes.append("hash from sources.lock.toml (archive not cached)")

    if not sha and not allow_unpinned:
        return None, "no SHA-256 and archive not cached"

    version = spell.version or lock.get("version", "") or "unknown"
    release = spell.release
    source_file = archive.name if archive is not None else source_filename(url)

    entry = Entry(
        spell=spell,
        version=version,
        release=release,
        libc=libc_table.get(spell.name, "glibc"),
        source_url=url,
        source_file=source_file,
        size=size,
        sha256=sha,
        signature_url=spell.signature_url,
        notes=notes,
    )
    return entry, ""


def select_spells(
    spells: dict[str, Spell],
    names: list[str],
    all_spells: bool,
    profiles: list[str],
) -> list[str]:
    selected: list[str] = []

    def add(name: str) -> None:
        if name not in selected:
            selected.append(name)

    for profile in profiles:
        for name in profile_names(profile):
            if name not in FIXTURES:
                add(name)

    if all_spells:
        for name in sorted(spells):
            if name not in FIXTURES:
                add(name)

    for name in names:
        add(name)

    if not selected:
        raise SystemExit(
            "no packages selected: pass package names, --all, or --profile"
        )

    missing = [name for name in selected if name not in spells]
    if missing:
        raise SystemExit("unknown spell(s): " + ", ".join(sorted(missing)))

    fixtures = [name for name in names if name in FIXTURES]
    if fixtures:
        raise SystemExit(
            "fixture spell(s) are not distributable packages: "
            + ", ".join(sorted(fixtures))
        )

    return selected


def esc(value: str) -> str:
    return value.replace("\t", " ").replace("\r", " ").replace("\n", " ").strip()


def render(entries: list[Entry], *, timestamp: str) -> str:
    lines = [
        "# localrepo – LEANUX source repository index",
        f"# format: {FORMAT_VERSION}",
        f"# generated: {timestamp}",
        "# generator: tools/make_localrepo.py",
        "#",
        "# signature: sha256:<hex> over source_file; mandatory integrity check",
        "# signature_url: optional upstream OpenPGP signature for source_file",
        "# libc: preferred C library for this package (dietlibc or glibc)",
        "\t".join(COLUMNS),
    ]
    for entry in entries:
        lines.append("\t".join(esc(field) for field in entry.fields()))
    return "\n".join(lines) + "\n"


def write_checksum(path: Path) -> Path:
    target = path.with_name(path.name + ".sha256")
    target.write_text(f"{sha256_file(path)}  {path.name}\n", encoding="utf-8")
    return target


def sign_file(path: Path, key: str | None) -> Path:
    signature = path.with_name(path.name + ".asc")
    command = [
        "gpg",
        "--batch",
        "--yes",
        "--armor",
        "--detach-sign",
        "--output",
        str(signature),
    ]
    if key:
        command += ["--local-user", key]
    command.append(str(path))
    result = subprocess.run(command)
    if result.returncode != 0:
        raise SystemExit("gpg failed to sign the repository index")
    return signature


def write_report(
    path: Path,
    *,
    entries: list[Entry],
    skipped: list[tuple[str, str]],
    libc_table_ok: bool,
    timestamp: str,
    signed: Path | None,
) -> None:
    lines = [
        "# LEANUX localrepo",
        "",
        f"- Erzeugt: {timestamp}",
        f"- Format: {FORMAT_VERSION}",
        f"- Pakete: {len(entries)}",
        f"- libc-Auswahl geladen: {'ja' if libc_table_ok else 'nein (Standard: glibc)'}",
    ]
    if signed:
        lines.append(f"- Signatur: `{signed.name}`")
    else:
        lines.append("- Signatur: keine (nur SHA-256)")

    lines += [
        "",
        "## Pakete",
        "",
        "| Paket | Version | libc | Quelle | Größe | SHA-256 |",
        "|---|---|---|---|---:|---|",
    ]
    for entry in sorted(entries, key=lambda item: item.spell.name):
        source = entry.source_file or "–"
        size = entry.size or "–"
        digest = entry.sha256 or "–"
        lines.append(
            f"| `{entry.spell.name}` | {entry.version} | {entry.libc} | "
            f"`{source}` | {size} | `{digest}` |"
        )

    lines += ["", "## Übersprungen", ""]
    if skipped:
        for name, reason in sorted(skipped):
            lines.append(f"- `{name}`: {reason}")
    else:
        lines.append("Keine.")

    notes = [
        f"- `{entry.spell.name}`: {'; '.join(entry.notes)}"
        for entry in sorted(entries, key=lambda item: item.spell.name)
        if entry.notes
    ]
    lines += ["", "## Hinweise", ""]
    lines += notes or ["Keine."]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate the LEANUX localrepo package index from spell metadata.",
    )
    parser.add_argument(
        "packages",
        nargs="*",
        metavar="PACKAGE",
        help="spell/program names to include",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="include every real spell (fixtures excluded)",
    )
    parser.add_argument(
        "--profile",
        action="append",
        default=[],
        metavar="NAME",
        help="include a build profile (base, desktop, world)",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_OUT,
        help=f"output file (default: {DEFAULT_OUT.relative_to(ROOT)})",
    )
    parser.add_argument(
        "--report",
        type=Path,
        help="write a Markdown report to this path",
    )
    parser.add_argument(
        "--sources",
        type=Path,
        default=SOURCES_DIR,
        help="source archive cache (default: sources/)",
    )
    parser.add_argument(
        "--lock",
        type=Path,
        default=LOCKFILE,
        help="source lock file (default: build/sources.lock.toml)",
    )
    parser.add_argument(
        "--libc-table",
        type=Path,
        default=LIBC_TABLE,
        help="libc selection table (default: build/libc-selection.tsv)",
    )
    parser.add_argument(
        "--allow-unpinned",
        action="store_true",
        help="include packages without a SHA-256 or cached archive",
    )
    parser.add_argument(
        "--sign",
        action="store_true",
        help="detach-sign the index with the default GPG key",
    )
    parser.add_argument(
        "--sign-key",
        metavar="KEYID",
        help="detach-sign the index with this GPG key",
    )
    parser.add_argument(
        "--no-timestamp",
        action="store_true",
        help="omit the generated timestamp (reproducible output)",
    )
    args = parser.parse_args(argv)

    sources_dir = args.sources.resolve()
    spells = load_spells()
    lock_data = load_lock(args.lock)
    libc_table = load_libc_table(args.libc_table)

    selected = select_spells(spells, args.packages, args.all, args.profile)

    entries: list[Entry] = []
    skipped: list[tuple[str, str]] = []
    for name in selected:
        spell = spells[name]
        entry, reason = build_entry(
            spell,
            lock=lock_data.get(name, {}),
            sources_dir=sources_dir,
            libc_table=libc_table,
            allow_unpinned=args.allow_unpinned,
        )
        if entry is None:
            skipped.append((name, reason))
        else:
            entries.append(entry)

    entries.sort(key=lambda item: item.spell.name)

    if not entries:
        details = "; ".join(f"{name}: {reason}" for name, reason in skipped)
        raise SystemExit(
            "no packages could be included"
            + (f" ({details})" if details else "")
            + "; use --allow-unpinned to include unverified entries"
        )

    timestamp = (
        "reproducible"
        if args.no_timestamp
        else datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    )
    content = render(entries, timestamp=timestamp)

    out = args.out
    if not out.is_absolute():
        out = (Path.cwd() / out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(content, encoding="utf-8")
    checksum = write_checksum(out)

    signed: Path | None = None
    if args.sign or args.sign_key:
        signed = sign_file(out, args.sign_key)

    if args.report:
        report = args.report
        if not report.is_absolute():
            report = (Path.cwd() / report).resolve()
        write_report(
            report,
            entries=entries,
            skipped=skipped,
            libc_table_ok=bool(libc_table),
            timestamp=timestamp,
            signed=signed,
        )

    diet = sum(1 for entry in entries if entry.libc == "dietlibc")
    glibc = sum(1 for entry in entries if entry.libc == "glibc")
    print(f"[localrepo] wrote {out} ({len(entries)} packages)")
    if not libc_table:
        print(
            f"[localrepo] WARNING: {args.libc_table} not found; defaulting to glibc",
            file=sys.stderr,
        )
    print(f"[localrepo] libc: {diet} dietlibc, {glibc} glibc")
    print(f"[localrepo] checksum: {checksum}")
    if signed:
        print(f"[localrepo] signature: {signed}")
    else:
        print("[localrepo] signature: none (use --sign-key to sign the index)")
    if skipped:
        print(f"[localrepo] skipped {len(skipped)} package(s):")
        for name, reason in sorted(skipped):
            print(f"[localrepo]   {name}: {reason}")
    notes = [entry for entry in entries if entry.notes]
    if notes:
        print(f"[localrepo] {len(notes)} package(s) with metadata notes")
        for entry in notes:
            print(f"[localrepo]   {entry.spell.name}: {'; '.join(entry.notes)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())

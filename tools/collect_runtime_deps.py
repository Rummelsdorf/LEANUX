#!/usr/bin/env python3
"""Copy host runtime libraries needed by dynamically linked files in a rootfs.

dietlibc packages are normally static, but the glibc reference builds use the
normal dynamic glibc toolchain.  Those binaries need the loader and the glibc
runtime inside the image.  This helper scans every ELF file in an assembled
rootfs with ``ldd`` and copies missing host libraries into the image.

Libraries that already exist in the rootfs (matched by basename anywhere under
``usr/lib``, ``lib``, ``usr/lib64`` or ``lib64``) are left untouched so the
package version wins.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

IGNORED_PREFIXES = ("/proc/", "/sys/", "/dev/")
LIB_DIRS = ("usr/lib", "lib", "usr/lib64", "lib64")


def is_elf(path: Path) -> bool:
    try:
        with path.open("rb") as handle:
            return handle.read(4) == b"\x7fELF"
    except OSError:
        return False


def elf_files(rootfs: Path) -> list[Path]:
    result: list[Path] = []
    for dirpath, _dirnames, filenames in os.walk(rootfs):
        for name in filenames:
            path = Path(dirpath) / name
            if path.is_symlink() or not path.is_file():
                continue
            if is_elf(path):
                result.append(path)
    return result


def rootfs_library_names(rootfs: Path) -> set[str]:
    names: set[str] = set()
    for sub in LIB_DIRS:
        base = rootfs / sub
        if not base.is_dir():
            continue
        for dirpath, _dirnames, filenames in os.walk(base):
            for name in filenames:
                names.add(name)
    return names


def ldd_libraries(path: Path) -> tuple[list[Path], list[str]]:
    """Return resolved absolute libraries and unresolved names for one ELF."""
    try:
        proc = subprocess.run(
            ["ldd", str(path)],
            capture_output=True,
            text=True,
            timeout=20,
            env={**os.environ, "LC_ALL": "C"},
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return [], [f"ldd failed: {exc}"]
    stderr = proc.stderr.strip()
    if "not a dynamic executable" in stderr or "statically linked" in stderr:
        return [], []
    if proc.returncode != 0 and not proc.stdout:
        return [], [stderr or "ldd failed"]

    libraries: list[Path] = []
    missing: list[str] = []
    for raw in proc.stdout.splitlines():
        line = raw.strip()
        if not line:
            continue
        if "not a dynamic executable" in line or "statically linked" in line:
            continue
        if "=>" in line:
            rhs = line.split("=>", 1)[1].strip()
            if rhs.startswith("not found"):
                missing.append(line.split("=>", 1)[0].strip())
                continue
            candidate = rhs.split(" (", 1)[0].strip()
        elif line.startswith("/") and " (" in line:
            candidate = line.split(" (", 1)[0].strip()
        else:
            continue
        if not candidate.startswith("/"):
            continue
        if candidate.startswith(IGNORED_PREFIXES):
            continue
        path_obj = Path(candidate)
        if path_obj.is_file():
            libraries.append(path_obj)
    return libraries, missing


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rootfs", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    rootfs = args.rootfs.resolve()
    if not rootfs.is_dir():
        print(f"ERROR: rootfs not found: {rootfs}", file=sys.stderr)
        return 1

    existing = rootfs_library_names(rootfs)
    copied: list[tuple[str, str]] = []
    missing_all: list[str] = []

    for binary in elf_files(rootfs):
        libraries, missing = ldd_libraries(binary)
        missing_all.extend(missing)
        for library in libraries:
            if library.name in existing:
                continue
            dest = rootfs / library.as_posix().lstrip("/")
            if dest.exists():
                existing.add(library.name)
                continue
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(library, dest, follow_symlinks=True)
            existing.add(library.name)
            copied.append((str(library), str(dest.relative_to(rootfs))))

    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        lines = ["# source\tinstalled_as"]
        lines += [f"{src}\t{dest}" for src, dest in copied]
        args.report.write_text("\n".join(lines) + "\n", encoding="utf-8")

    if not args.quiet:
        print(f"[runtime] {len(copied)} Host-Bibliotheken in die Rootfs kopiert")
        if missing_all:
            print(f"[runtime] WARNUNG: {len(missing_all)} unaufgelöste Bibliotheken")
            for name in sorted(set(missing_all))[:20]:
                print(f"[runtime]   fehlt: {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

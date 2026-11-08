#!/usr/bin/env python3

import hashlib
import sys
import tomllib

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

LOCKFILE = ROOT / "build" / "sources.lock.toml"
SOURCES = ROOT / "sources"

def sha256(path):
    digest = hashlib.sha256()

    with path.open("rb") as file:
        for block in iter(
            lambda: file.read(1024 * 1024),
            b""
        ):
            digest.update(block)

    return digest.hexdigest()

def main():
    SOURCES.mkdir(exist_ok=True)

    with LOCKFILE.open("rb") as file:
        manifest = tomllib.load(file)

    failed = False

    for source in manifest.get("source", []):
        name = source["name"]
        expected = source["sha256"]

        archive = SOURCES / Path(
            source["url"].split("?")[0]
        ).name

        if not archive.is_file():
            # The base C library is kept with the repository, not in sources/.
            alt = ROOT / "diet" / archive.name
            if alt.is_file():
                archive = alt

        if (
            "REPLACE_" in expected
            or "PINNED_" in source["version"]
            or "UPSTREAM_" in source["url"]
        ):
            print(f"[UNPINNED] {name}")
            failed = True
            continue

        if not archive.is_file():
            print(f"[MISSING] {name}: {archive.name}")
            failed = True
            continue

        actual = sha256(archive)

        if actual != expected:
            print(f"[INVALID] {name}: hash mismatch")
            failed = True
            continue

        print(f"[VERIFIED] {name}")

    if failed:
        print("\nSource verification failed.")
        return 1

    print("\nAll source archives verified.")
    return 0

if __name__ == "__main__":
    sys.exit(main())



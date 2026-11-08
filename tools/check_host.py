#!/usr/bin/env python3

import platform
import shutil
import subprocess
import sys

REQUIRED = [
    "gcc",
    "g++",
    "make",
    "ld",
    "as",
    "python3",
    "git",
    "tar",
    "xz",
    "zstd",
    "qemu-system-x86_64",
]

def main():
    print("PROJECT Linux - Host Environment Check")
    print("=" * 45)

    print("Architecture:", platform.machine())
    print("Platform:", platform.system())
    print("Python:", sys.version.split()[0])

    missing = []

    for program in REQUIRED:
        path = shutil.which(program)

        if path:
            print(f"[OK] {program}: {path}")
        else:
            print(f"[MISSING] {program}")
            missing.append(program)

    if missing:
        print("\nMissing dependencies:")
        print(", ".join(missing))
        return 1

    print("\nHost environment looks good.")
    return 0


if __name__ == "__main__":
    sys.exit(main())



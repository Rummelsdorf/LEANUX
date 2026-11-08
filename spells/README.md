# LEANUX Spells System

A small source‑based build framework inspired by Surce Mage GNU Linux. Every
package ("spell") is built from source with **dietlibc** as the default C
library; the standard C library is used only when a spell explicitly permits a
fallback.

## Quick use

```bash
./cast.sh --list
./cast.sh zlib
./cast.sh test_a test_b
./cast.sh --force zlib
```

`cast.sh` performs the full pipeline:

1. Resolve dependencies recursively (missing spells are an error).
2. Topologically order the build (cycles are detected).
3. Download and SHA‑256‑verify the source archive.
4. Extract into `build-output/<pkg>/src`.
5. Export `CC=dietgcc`, static flags, and the per‑package `DESTDIR`.
6. Run the spell's `build()` (and optional `install()`).
7. Mark the package built in `sysroot/install/<pkg>/.built`.

## Spell format

```bash
PACKAGE_NAME="example"
PACKAGE_VERSION="1.0"
PACKAGE_RELEASE="1"

DEPENDENCIES=("zlib")                 # must have spells
EXTERNAL_DEPENDENCIES=("libssl")      # host-provided, no spell required

SOURCE_URL="https://example.org/example-1.0.tar.gz"
SOURCE_HASH="<sha256 or PLACEHOLDER_HASH>"

BUILD_STYLE="configure"               # informational
LANGUAGE="c"                          # or "c++"
FALLBACK_ALLOWED=0                    # 1 = retry with host gcc if dietlibc fails

build() {
    ./configure --prefix=/usr CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
    make -j"${JOBS:-$(nproc)}"
    make DESTDIR="$DESTDIR" install
}
```

The engine sets these variables before calling `build()`:

| Variable | Meaning |
|----------|---------|
| `CC` | `dietgcc` (or `gcc` during an approved fallback) |
| `CFLAGS` / `LDFLAGS` | static, optimized defaults |
| `DESTDIR` | `sysroot/install/<pkg>` |
| `STAGING_DIR` | same as `DESTDIR` (compatibility) |
| `DIETHOME` | dietlibc installation prefix |
| `JOBS` | parallel build jobs |

## Environment

| Variable | Default |
|----------|---------|
| `SPELL_DIR` | this directory |
| `STAGING_DIR` | `~/LEANUX/sysroot` |
| `SOURCES_DIR` | `~/LEANUX/sources` |
| `BUILD_ROOT` | `~/LEANUX/build-output` |
| `DIET_PREFIX` | `~/LEANUX/tools/diet` |
| `DIETGCC` | `$DIET_PREFIX/bin/dietgcc` |

## Dietlibc rules

- `CC=dietgcc` is the default for C packages.
- Static linking is preferred.
- `FALLBACK_ALLOWED=1` triggers one clean retry with host `gcc` if the
  dietlibc build fails. Without it, a failure aborts the build.
- C++ packages (`LANGUAGE="c++"`) normally need the standard‑libc fallback
  because dietlibc has no C++ runtime.
- Do not mix dietlibc and glibc objects in a single binary.

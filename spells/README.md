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
./cast.sh --dry-run zlib libpng       # print the resolved build plan
./cast.sh --world                     # build build/world.order
./cast.sh --dry-run --world           # print the full world plan
```

`cast.sh` performs the full pipeline:

1. Resolve dependencies recursively (missing spells are an error) and add the
   implicit `dietcompat` dependency for spells with `USE_DIETCOMPAT=1`.
2. Topologically order the build (cycles are detected).
3. Download and SHA‑256‑verify the source archive.
4. Extract into `build-output/<pkg>/src`.
5. Export `CC=dietgcc`, static flags, the per‑package `DESTDIR`, and the
   include/library/pkg-config paths of every staged transitive dependency.
6. Run the spell's `build()` (and optional `install()`).
7. Rewrite staged `.pc` files and mark the package built in
   `sysroot/install/<pkg>/.built`.

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
USE_DIETCOMPAT=1                      # implicit dep on dietcompat; -ldietcompat -lm

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
| `CFLAGS` / `CPPFLAGS` / `LDFLAGS` | static, optimized defaults plus dependency include/library paths |
| `DESTDIR` | `sysroot/install/<pkg>` |
| `STAGING_DIR` | same as `DESTDIR` (compatibility) |
| `PATH` | includes the `bin/` directories of staged dependencies |
| `PKG_CONFIG_PATH` | `.pc` files of every staged transitive dependency |
| `DIETHOME` | dietlibc installation prefix |
| `JOBS` | parallel build jobs |

Dependency staging is transitive: if `freetype` needs `libpng` and `zlib`, a
`cairo` build sees the staged `freetype`, `libpng` and `zlib` trees. Staged
`.pc` files are rewritten from `/usr` to their absolute stage paths after each
install so dependent configure steps resolve the staged copy, not the host's.

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

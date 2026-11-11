# LEANUX – Clean & Lean AI‑Ready Linux Distribution

LEANUX is a minimal Linux distribution for AI workloads. Every package is built
from source with **dietlibc** as the default C library. The standard C library
(glibc) is used only when dietlibc lacks a required interface **and** the package
spell explicitly allows a fallback (`FALLBACK_ALLOWED=1`).

## Current status

| Area | Status |
|------|--------|
| dietlibc 0.35 bootstrap | **working** (built from the bundled tarball into `tools/diet`) |
| Spell/dependency engine | **working** (topological ordering, cycle and missing-dependency detection, dependency staging) |
| dietlibc compile + static link | **verified** |
| zlib 1.3.1 built with dietlibc | **verified** (static library + linked test program run) |
| CLEANUX package port | **spells and graph imported** – 70-package world order; see `PORTING.md` |
| xz, libpng, pixman built with dietlibc | **verified** |
| Full desktop/AI package set | **in progress** – 53 ported spells still need their archives pinned |
| Live ISO | **not built yet** – only after the package set compiles |

The project does **not** yet build the full MATE/Firefox/VLC/Python/llama.cpp
stack. The spell definitions and dependency graph are in place, but most of the
CLEANUX source archives were not cached in the reference tree, so those spells
still carry `PLACEHOLDER_HASH` and will download their sources on first build.
See `PORTING.md` for the exact state.

## Quick start

```bash
cd ~/LEANUX

# 1. Check the host and build the base C library
make check-host
make bootstrap-dietlibc

# 2. Run the functional test suite (dietlibc + dependency engine + zlib)
make test

# 3. Build a package (dependencies are resolved automatically)
make cast PKGS="zlib"
# or
./spells/cast.sh zlib
```

Build outputs are staged in `sysroot/install/<package>/`.

## Commands

| Command | Purpose |
|---------|---------|
| `make check-host` | Verify host tools |
| `make fetch-all` | Fetch sources for the world order + required extras |
| `make compile-all` | Fetch and try to build every selected spell, then compare glibc artifact sizes |
| `make compare-libc` | Build glibc variants for all dietlibc PASS packages and compare sizes |
| `make bootstrap-dietlibc` | Build dietlibc into `tools/diet` |
| `make test` | Run all functional tests |
| `make cast PKGS="..."` | Build one or more spells with dependency resolution |
| `make world` | Build every package in `build/world.order` |
| `make plan PKGS="..."` | Print the resolved build plan without building |
| `make plan-world` | Print the full world build plan |
| `./spells/cast.sh --list` | List available spells |
| `./spells/cast.sh --force <spell>` | Rebuild a spell from scratch |
| `make verify` | Verify pinned source hashes |
| `make localrepo` | Generate `repository/localrepo` from all real spells |
| `make localrepo-base` | Generate a `localrepo` for the base profile |

## Source fetch and compile matrix

Two test tools automate the "does it really build with dietlibc?" question:

```bash
# Fetch/verify every source archive (world order + bash, tmux, Python 3.12,
# llama.cpp).  Resumable and hash-checked where a SOURCE_HASH is pinned.
make fetch-all

# Fetch, then try to build every selected package with dietlibc, one at a
# time, and finally build a statically linked glibc variant of every dietlibc
# PASS package for a size comparison.  The default is world order + extras.
make compile-all
# or, with options:
./tests/compile-all.sh --all --force --timeout 900
./tests/compile-all.sh --only zlib,xz,libpng
./tests/compile-all.sh --compare          # enable the glibc size comparison
./tests/compare-libc.sh                   # comparison only, using the last matrix
```

Results are written under `reports/`:

| File | Contents |
|------|----------|
| `reports/source-fetch.md` / `.tsv` | per-package download/verify status |
| `reports/compile-matrix.md` / `.tsv` | PASS/FAIL/TIMEOUT per package |
| `reports/libc-size-comparison.md` / `.tsv` | dietlibc vs glibc payload size per package |
| `reports/compile-logs/<package>.log` | full configure/make log |
| `reports/glibc-logs/<package>.log` | glibc comparison build log |

The consolidated result of a complete run is written to
`LEANUX-ERGEBNISSE.md` in the repository root (matrix, failures, source status
and the full size comparison in one file).

The matrix distinguishes `PASS (dietlibc)`, `PASS (glibc fallback)` (only for
spells that set `FALLBACK_ALLOWED=1`), `PASS (cached)` (already staged, not
rebuilt), `FAIL`, and `TIMEOUT`.  Existing stages are reused by default; use
`--force` to rebuild them.  The run is resumable because every report row is
written as soon as a package finishes.

For every dietlibc PASS package the comparison builds the same spell with the
host compiler (`--libc glibc`) in separate `sysroot-glibc/` and
`build-output-glibc/` roots, so the dietlibc stages are never touched.  Both
variants are linked statically; the reported number is the installed payload
(executables, libraries and data, excluding docs, locales and pkg-config
files).  The size section is appended to `compile-matrix.md` automatically.

## localrepo – package source index

`tools/make_localrepo.py` turns spell package names into a tab-separated
repository index.  It reads the metadata assignments from the spell files
(without sourcing them), hashes the cached archives in `sources/`, and takes
the per-package C library preference from `build/libc-selection.tsv`:

```bash
# explicit program names
tools/make_localrepo.py bash curl wget

# every real package (fixtures excluded)
tools/make_localrepo.py --all

# a build profile
tools/make_localrepo.py --profile base

# Make targets (default output: repository/localrepo)
make localrepo
make localrepo-base
make localrepo-desktop
```

The default output is `repository/localrepo`; a `localrepo.sha256` checksum is
written next to it.  Rows are tab-separated and sorted by package name:

```
name	version	release	libc	source_url	source_file	size	sha256	signature	signature_url
bash	5.2	1	glibc	https://ftp.gnu.org/gnu/bash/bash-5.2.tar.gz	bash-5.2.tar.gz	10950833	a139…	sha256:a139…	
```

| Column | Meaning |
|---|---|
| `name` | Spell / program package name |
| `version`, `release` | Package version and LEANUX release number |
| `libc` | Preferred C library: `dietlibc` or `glibc` |
| `source_url` | Upstream source archive |
| `source_file` | Archive filename in `sources/` |
| `size` | Archive size in bytes |
| `sha256` | SHA-256 of the archive |
| `signature` | `sha256:<hex>` integrity signature over `source_file` |
| `signature_url` | Optional upstream OpenPGP signature (from `SOURCE_SIGNATURE_URL`) |

The hash is computed from the archive when it is present.  Otherwise the tool
falls back to a real `SOURCE_HASH` from the spell and then to
`build/sources.lock.toml`.  Packages without a source URL or without any hash
are skipped and reported; `--allow-unpinned` includes them with
`signature=none`.  Fixture spells (`template`, `test_a`, `test_b`) are never
included.

The index itself can be signed with OpenPGP:

```bash
tools/make_localrepo.py --all --sign-key leanux@example.org
# writes repository/localrepo.asc in addition to localrepo.sha256
```

An optional Markdown report is written with `--report reports/localrepo.md`.
The intended consumer is `spells/cast.sh` in a running LEANUX system: it looks
up a package by name, downloads and verifies `source_file`, builds the package
with dietlibc and glibc, and installs the smaller of the two payloads.

## Per-package libc selection and release images

`tools/select_libc.py` applies the size rule: a package keeps dietlibc only
when it compiled with dietlibc **and** its measured payload is strictly smaller
than the glibc variant.  Every other package uses glibc.

```bash
make libc-selection          # writes build/libc-selection.tsv/.md and lists
make release                 # assemble an image from already built stages
make release-base            # build missing base packages, then image + ISO
make release-desktop         # build missing desktop packages, then image + ISO
```

The selection is written to:

| File | Contents |
|------|----------|
| `build/libc-selection.tsv` | package, chosen libc, both sizes, reason |
| `build/libc-selection.md` | German report with the two package lists |
| `build/dietlibc-packages.list` | packages built with dietlibc |
| `build/glibc-packages.list` | packages built with glibc |

`tests/build-release.sh` assembles `out/rootfs/` from `sysroot/install/<pkg>`
for dietlibc packages and `sysroot-glibc/install/<pkg>` for glibc packages.
It prunes headers, static libraries, pkg-config files and documentation,
adds base configuration, and copies the glibc runtime needed by dynamically
linked glibc executables.  A static busybox is added as a rescue shell for the
first edition (disable with `--no-busybox`).

```bash
./tests/build-release.sh --profile base --image both
./tests/build-release.sh --profile world --require-all
./tests/build-release.sh --profile built --assemble-only
```

Outputs are `out/LEANUX-<version>-<profile>.img` (ext4, created without root
via `mkfs.ext4 -d`), `out/LEANUX-<version>-<profile>.iso` (GRUB + squashfs +
initramfs), `out/RELEASE-BERICHT.md`, `out/rootfs-manifest.tsv` and
`out/runtime-deps.tsv`.  The ISO uses the newest readable kernel below `/boot`
unless `--kernel FILE` is given.  The `built` profile is the default and only
assembles packages that already have a matching stage.

## Directory layout

```
bootstrap/        dietlibc bootstrap script
build/            config.toml, sources.lock.toml, world.order and profiles
compat/           dietcompat compatibility shim (dietlibc)
diet/             dietlibc 0.35 tarball + FAQ
spells/           spell recipes and the cast.sh build engine
sources/          downloaded source archives (cache)
build-output/     per-package build trees
build-output-glibc/ glibc comparison build trees
sysroot/install/  staged installs (one directory per package)
sysroot-glibc/    glibc comparison installs (separate root)
out/              assembled rootfs, .img/.iso images and release report
tools/diet/       dietlibc installation and dietgcc wrapper
tools/            host checks, source fetcher, reports, libc selector
tests/            functional tests, compile-matrix and release runners
reports/          generated fetch/compile reports and build logs
```

## Ported package set

`tools/import_cleanux_spells.py` imports the CLEANUX spell metadata and
dependency graph. The generated world order is `build/world.order`:

```bash
make plan-world     # inspect the 70-package order
make world          # build it (long; most sources are downloaded on demand)
```

The port keeps CLEANUX versions, URLs and descriptions, but fixes dependency
ordering mistakes in the original list (for example `xorgproto` before the X11
libraries and `libpng` before `freetype`). Four missing transitive dependencies
were added as spells: `libpthread-stubs`, `libfontenc`, `libxkbfile` and
`libxklavier`. `dietcompat` supplies the handful of glibc interfaces dietlibc
does not implement. See `PORTING.md`.

## dietlibc policy

1. `CC=dietgcc` is exported for every C package.
2. Static linking is the default (`-static`).
3. A spell may set `FALLBACK_ALLOWED=1`; if the dietlibc build fails, the engine
   retries from a clean source tree with the host `gcc`.
4. C++ packages (`LANGUAGE="c++"`) cannot use dietlibc for the C++ runtime and
   are expected to use the documented fallback.
5. A missing dependency spell is an error, not a silent skip. Host-provided
   libraries must be listed in `EXTERNAL_DEPENDENCIES`.

## Required package set

tor, bash, OpenSSH server/client, X11, MATE, VLC, Firefox, an X11 terminal
emulator, gkrellm, mc, tmux, screen, Python 3.12, llama.cpp, and their
dependencies. See `TODO.md` for the build plan and remaining porting work.

## License

MIT. See `LICENSE` if present in the repository.

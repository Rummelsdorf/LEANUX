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
| `make bootstrap-dietlibc` | Build dietlibc into `tools/diet` |
| `make test` | Run all functional tests |
| `make cast PKGS="..."` | Build one or more spells with dependency resolution |
| `make world` | Build every package in `build/world.order` |
| `make plan PKGS="..."` | Print the resolved build plan without building |
| `make plan-world` | Print the full world build plan |
| `./spells/cast.sh --list` | List available spells |
| `./spells/cast.sh --force <spell>` | Rebuild a spell from scratch |
| `make verify` | Verify pinned source hashes |

## Directory layout

```
bootstrap/        dietlibc bootstrap script
build/            config.toml, sources.lock.toml and world.order
compat/           dietcompat compatibility shim (dietlibc)
diet/             dietlibc 0.35 tarball + FAQ
spells/           spell recipes and the cast.sh build engine
sources/          downloaded source archives (cache)
build-output/     per-package build trees
sysroot/install/  staged installs (one directory per package)
tools/diet/       dietlibc installation and dietgcc wrapper
tools/            host checks, source verification, CLEANUX importer
tests/            functional test suite
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

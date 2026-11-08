# LEANUX – Clean & Lean AI‑Ready Linux Distribution

LEANUX is a minimal Linux distribution for AI workloads. Every package is built
from source with **dietlibc** as the default C library. The standard C library
(glibc) is used only when dietlibc lacks a required interface **and** the package
spell explicitly allows a fallback (`FALLBACK_ALLOWED=1`).

## Current status

| Area | Status |
|------|--------|
| dietlibc 0.35 bootstrap | **working** (built from the bundled tarball into `tools/diet`) |
| Spell/dependency engine | **working** (topological ordering, cycle and missing-dependency detection) |
| dietlibc compile + static link | **verified** |
| zlib 1.3.1 built with dietlibc | **verified** (static library + linked test program run) |
| Full desktop/AI package set | **pending** – spells and dependency porting still required |
| Live ISO | **not built yet** – only after the package set compiles |

The project does **not** currently build the full MATE/Firefox/VLC/Python/llama.cpp
stack. Those packages need dedicated spells and, in several cases, porting work
because dietlibc does not implement all glibc interfaces. The build framework is
ready to drive that work.

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
| `./spells/cast.sh --list` | List available spells |
| `./spells/cast.sh --force <spell>` | Rebuild a spell from scratch |
| `make verify` | Verify pinned source hashes |

## Directory layout

```
bootstrap/        dietlibc bootstrap script
build/            config.toml and sources.lock.toml
diet/             dietlibc 0.35 tarball + FAQ
spells/           spell recipes and the cast.sh build engine
sources/          downloaded source archives (cache)
build-output/     per-package build trees
sysroot/install/  staged installs (one directory per package)
tools/diet/       dietlibc installation and dietgcc wrapper
tests/            functional test suite
```

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

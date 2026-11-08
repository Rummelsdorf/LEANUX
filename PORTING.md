# CLEANUX → LEANUX port

This document records what was imported from `~/CLEANUX`, how the build engine
was extended, what has actually been built, and what remains.

The goal is to keep CLEANUX's package definitions and dependency graph while
enforcing LEANUX's stricter policy: **every package is built with dietlibc by
default**, and glibc is used only where a spell explicitly allows a fallback.
CLEANUX's `cleanux-install` disabled dietlibc (`DIET=""`), so its packages were
in fact built with host gcc/glibc. This port deliberately does not copy that
behaviour.

## What was imported

| Item | Result |
|------|--------|
| Spell metadata | 65 CLEANUX spells (version, URL, description) |
| Added transitive dependencies | `libpthread-stubs`, `libfontenc`, `libxkbfile`, `libxklavier` |
| Compatibility shim | `dietcompat` spell + `compat/dietcompat.c` |
| World order | 70 packages in `build/world.order` |
| Source archives | 15 CLEANUX archives copied into `sources/` |
| Pinned hashes | 14 new archives added to `build/sources.lock.toml` |
| Generator | `tools/import_cleanux_spells.py` (rerunnable) |

`zlib` was kept rather than overwritten, but its prefix is now `/usr` so that
dependents find its headers and `zlib.pc`. `openssh.spell` was replaced with the
CLEANUX 9.9p1 definition. The pre-existing LEANUX spells (`bash`, `tmux`,
`llama.cpp`, `python3.12`, `template`, `test_a`, `test_b`) were left untouched;
`python3` 3.13.0 was added alongside `python3.12`.

Spells are ordinary LEANUX shell spells. `DEPENDENCIES` lists packages that must
have spells; `EXTERNAL_DEPENDENCIES` lists host-provided requirements that are
not (yet) part of the distribution.

## Dependency graph corrections

CLEANUX's `DEPENDENCIES.md` / `build-world.sh` order was not always
topological. The port fixes at least these cases:

- `xorgproto` before `libXau`, `libXdmcp`, `libxcb` and the X11 libraries.
- `libpng` before `freetype` (freetype links PNG support).
- `harfbuzz`, `freetype`, `fontconfig` before `cairo`/`pango`.
- `zlib` and `xz` before their consumers.
- `dietcompat` before every spell that links it.

Four implicit prerequisites that CLEANUX obtained from the host are now real
spells: `libpthread-stubs` (libxcb), `libfontenc` (libXfont2), `libxkbfile`
(xkbcomp) and `libxklavier` (libmatekbd). The graph resolves without cycles:

```bash
make plan-world
```

## Build-engine changes (`spells/cast.sh`)

- **Transitive dependency staging.** For each package the engine collects the
  stages of every dependency (not just direct ones) and adds their
  `include/`, `lib/` and `bin/` directories to `CFLAGS`/`CPPFLAGS`/`LDFLAGS`
  and `PATH`.
- **`CPPFLAGS` is populated.** Some configure scripts / generators only honour
  `CPPFLAGS`. libpng's `pnglibconf.h` generator was reading the host `zlib.h`
  and recording zlib `0x1300` while the staged library was `0x1310`, which
  tripped `#error ZLIB_VERNUM != PNG_ZLIB_VERNUM`.
- **pkg-config staging.** `PKG_CONFIG_PATH` is built from every staged
  dependency, and `rewrite_pkgconfig()` rewrites absolute install directories
  from `/usr` to the absolute stage path after each install.
- **`USE_DIETCOMPAT`.** When set, the spell implicitly depends on `dietcompat`
  and dietlibc builds append `-ldietcompat -lm`.
- **`--dry-run` / `--plan`** prints the resolved, topologically ordered build
  plan without building.
- **`--world`** reads `build/world.order` and builds that set.

The compat shim provides weak definitions for a few interfaces dietlibc lacks
(`pthread_mutexattr_settype`, `initstate`, `setstate`, `modf`). All symbols are
weak, so a real implementation wins if present. It is compiled with dietlibc,
not the host compiler.

## Verified builds

These were built through the spell engine with `CC=dietgcc` and static linking:

| Package | Result |
|---------|--------|
| `dietcompat` | `libdietcompat.a` |
| `xz` 5.6.3 | static `xz` binary runs (`xz --version`), `liblzma.a`, rewritten `.pc` |
| `zlib` 1.3.1 | `libz.a`; existing test program links and runs |
| `libpng` 1.6.44 | `libpng16.a` + `libpng.a`; `PNG_ZLIB_VERNUM` now matches staged zlib |
| `pixman` 0.43.4 | `libpixman-1.a`, meson path and rewritten `pixman-1.pc` |

`make test` covers the engine (ordering, cycles, fallback rules, zlib), not the
entire ported set.

## Known gaps

1. **Most archives are not cached.** Only the 16 pinned archives in
   `sources/` are present. The other 53 ported spells use `PLACEHOLDER_HASH` and will
   download their source on first build. Run `make verify` to see the pinned
   set; placeholders are intentionally reported as unpinned.
2. **Most ported packages have not been compiled yet.** xz, libpng and pixman
   validate the autotools and meson paths, but large spells (glib, cairo,
   freetype, openssl, X11, MATE, VLC, Firefox) need individual debugging against
   dietlibc.
3. **Host tools required:** `meson`, `ninja`, `pkg-config`, `gperf`, `bison`,
   `flex` and a host `python3` for several configure steps. `cmake` is **not**
   installed on the current host, so the `llvm` spell (and anything using the
   cmake template) cannot configure yet.
4. **C++ and prebuilt toolchains.** `qtbase`, `llvm`, `rust`, `nodejs`,
   `firefox` and `vlc` set `FALLBACK_ALLOWED=1`; dietlibc has no C++ runtime.
   `rust` installs a prebuilt glibc-hosted toolchain. These are documented
   fallbacks, not dietlibc builds.
5. **`EXTERNAL_DEPENDENCIES` are host-provided.** Examples: `gettext`,
   `itstool`, `xtrans`, `libXcomposite`, `libXdamage`, `libXcursor`,
   `libXinerama`, `libXmu`, `libXpm`, `libpciaccess`, `libSM`, `libICE`,
   `vte-2.91`, `libwnck-3.0`, `libexif`, `libnotify`, `libsndfile`, `libsoxr`,
   `libltdl`, `libgcrypt`, `libxml2`, `libssh2`, `pam`, `readline`, `bzip2`,
   `libuuid`, `perl`, `yasm`, `zip`, `unzip`, `mako`, `pyyaml`. A fully
   self-hosted image needs spells for the ones that matter.
6. **`make verify` currently reports the unpinned placeholders** when run over
   every spell; the pinned subset verifies cleanly. Pin a source by downloading
   its archive into `sources/`, replacing `PLACEHOLDER_HASH` with the SHA-256,
   and adding an entry to `build/sources.lock.toml`.

## Regenerating the port

```bash
python3 tools/import_cleanux_spells.py   # rewrites ported spells + world.order
make verify                             # check pinned archives
make plan-world                         # inspect order
make test                               # engine regression tests
```

The importer keeps `zlib` and does not touch the pre-existing LEANUX spells.

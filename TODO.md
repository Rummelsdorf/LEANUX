# LEANUX Build TODO

Goal: a clean, lean, AI‑ready live Linux distribution in which **every package
is compiled with dietlibc by default**. Standard libc is allowed only when
dietlibc lacks a required interface and the spell explicitly permits a fallback.

Reference material:
- dietlibc 0.35: `diet/dietlibc-0.35.tar.xz`
- dietlibc FAQ: `diet/FAQ`

## Verified working

- [x] dietlibc 0.35 builds from the bundled tarball
- [x] `tools/diet/bin/dietgcc` wrapper compiles and statically links C programs
- [x] Spell engine resolves dependencies and detects cycles/missing spells
- [x] zlib 1.3.1 builds with dietlibc; a statically linked test program runs
- [x] `make test` passes (17 checks)

## Phase 0 – Host and base toolchain

- [x] `make check-host`
- [x] `make bootstrap-dietlibc`
- [ ] Pin and verify binutils source in `build/sources.lock.toml`
- [ ] Pin and verify Linux kernel source in `build/sources.lock.toml`
- [ ] Decide whether GCC is host‑provided or built from source
- [ ] Add a kernel build target and a minimal kernel config

## Phase 1 – Package infrastructure

- [x] `spells/cast.sh` fetches, verifies, extracts, and builds sources
- [x] Dependency resolution with topological ordering
- [x] Missing dependency and circular dependency detection
- [x] Per‑package staging in `sysroot/install/<pkg>`
- [ ] Add a `--dry-run` mode that prints the resolved build plan
- [ ] Add per‑package build logs under `build-output/<pkg>/build.log`
- [ ] Add a manifest of installed files per package
- [ ] Add reproducible‑build flags and SOURCE_DATE_EPOCH support

## Phase 2 – Core dependencies (must exist before the applications)

- [x] zlib
- [ ] openssl (libssl/libcrypto)
- [ ] readline
- [ ] ncurses
- [ ] libevent
- [ ] libffi
- [ ] libiconv
- [ ] pcre2
- [ ] libxml2
- [ ] libpng / libjpeg‑turbo / libtiff
- [ ] freetype / fontconfig / harfbuzz
- [ ] cairo / pango / gdk‑pixbuf
- [ ] glib / gobject‑introspection
- [ ] dbus / polkit
- [ ] libX11 and the X11 protocol libraries (xcb, xext, xrender, xtst, …)
- [ ] libdrm / mesa (or a deliberately minimal X11 stack)
- [ ] ALSA / PulseAudio or a lean audio alternative for VLC

Each dependency needs a `.spell` file and a dietlibc compatibility check. If a
library cannot build with dietlibc, record the missing symbols in the spell and
set `FALLBACK_ALLOWED=1` only as a last resort.

## Phase 3 – Required applications

- [ ] bash
- [ ] tor
- [ ] OpenSSH server + client
- [ ] X11 server and utilities
- [ ] MATE desktop
- [ ] VLC
- [ ] Firefox
- [ ] X11 terminal emulator (xterm or a lean alternative)
- [ ] gkrellm
- [ ] mc (midnight commander)
- [ ] tmux
- [ ] screen
- [ ] Python 3.12
- [ ] llama.cpp

Current spells exist for bash, OpenSSH, tmux, Python 3.12, llama.cpp, and zlib.
The remaining applications still need spells. Expect significant porting effort
for MATE, VLC, Firefox, and Python because they depend on glibc‑specific
interfaces (NSS, locale, iconv, full pthreads, dynamic loading, C++ runtime).

## Phase 4 – Root filesystem and init

- [ ] Assemble the staged packages into a bootable root filesystem
- [ ] Add `/etc`, device nodes, users, and permissions
- [ ] Choose and configure init (systemd is currently listed in `config.toml`)
- [ ] Add networking configuration
- [ ] Add a minimal live‑boot initramfs

## Phase 5 – Live ISO

- [ ] Create a squashfs image of the root filesystem
- [ ] Add a hybrid BIOS/UEFI bootloader (GRUB or Syslinux)
- [ ] Build the ISO with `xorriso`
- [ ] Boot the ISO in QEMU and verify all required applications start

## Phase 6 – Quality gates

- [ ] `make test` passes from a clean tree
- [ ] Every binary in the ISO is statically linked against dietlibc, or has a
      documented, approved glibc fallback
- [ ] No package silently links against glibc
- [ ] ISO size target met (aim for < 300 MB compressed)
- [ ] Reproducible build from pinned sources

## Dietlibc compatibility notes

- Check missing interfaces with a compile test before writing a spell.
- Do not mix dietlibc and glibc objects in one process; prefer a clean
  package‑level fallback instead.
- C++ packages need the standard libc/libstdc++ fallback; dietlibc does not
  provide a C++ runtime.
- Consult `diet/FAQ` for symbol and linking guidance.

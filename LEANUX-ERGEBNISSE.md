# LEANUX – Kompilier- und Größenvergleich

- Erzeugt: 2026-11-11T04:19:29
- Auswahl: `world-extras`
- Modus: `reuse`
- Timeout pro Paket: 1200s
- Host: Elite-Coolermaster
- JOBS: 4
- Pakete in der Matrix: 75
- Abgeschlossen: 2026-11-11T02:40:22+01:00

## Zusammenfassung

| Ergebnis | Anzahl |
|---|---:|
| PASS insgesamt | 46 |
| davon PASS mit dietlibc | 45 |
| davon PASS mit glibc-Fallback | 1 |
| davon aus dem Cache übernommen | 46 |
| FAIL | 29 |
| TIMEOUT | 0 |

## Quellen

| Status | Anzahl |
|---|---:|
| `no-source` | 2 |
| `present` | 17 |
| `present-unpinned` | 56 |

## Kompilier-Matrix

| # | Paket | Ergebnis | Libc | Dauer | Exit | Grund | Log |
|---:|---|---|---|---:|---:|---|---|
| 1 | `xcb-proto` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/xcb-proto.log) |
| 2 | `xorgproto` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/xorgproto.log) |
| 3 | `libpthread-stubs` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libpthread-stubs.log) |
| 4 | `dietcompat` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/dietcompat.log) |
| 5 | `zlib` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/zlib.log) |
| 6 | `xz` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/xz.log) |
| 7 | `expat` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/expat.log) |
| 8 | `libffi` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libffi.log) |
| 9 | `pcre2` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/pcre2.log) |
| 10 | `harfbuzz` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/harfbuzz.log) |
| 11 | `pixman` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/pixman.log) |
| 12 | `libXau` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libXau.log) |
| 13 | `libXdmcp` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libXdmcp.log) |
| 14 | `libdrm` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libdrm.log) |
| 15 | `xkeyboard-config` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/xkeyboard-config.log) |
| 16 | `alsa-lib` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/alsa-lib.log) |
| 17 | `ncurses` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/ncurses.log) |
| 18 | `nasm` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/nasm.log) |
| 19 | `openssl` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/openssl.log) |
| 20 | `glib` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/glib.log) |
| 21 | `libpng` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libpng.log) |
| 22 | `libxcb` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libxcb.log) |
| 23 | `ffmpeg` | FAIL | dietlibc | 3s | 1 | [cast] ERROR: ffmpeg failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/ffmpeg.log) |
| 24 | `llvm` | FAIL | dietlibc+fallback | 5m 08s | 1 | [cast] ERROR: llvm failed with standard libc fallback | [Log](reports/compile-logs/llvm.log) |
| 25 | `libfontenc` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libfontenc.log) |
| 26 | `libevent` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libevent.log) |
| 27 | `dbus` | FAIL | dietlibc | 19s | 1 | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/dbus.log) |
| 28 | `freetype` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/freetype.log) |
| 29 | `atk` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/atk.log) |
| 30 | `gdk-pixbuf` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/gdk-pixbuf.log) |
| 31 | `gsettings-desktop-schemas` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/gsettings-desktop-schemas.log) |
| 32 | `xtrans` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/xtrans.log) |
| 33 | `libX11` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libX11.log) |
| 34 | `mate-menus` | FAIL | dietlibc | 4s | 1 | [cast] ERROR: mate-menus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mate-menus.log) |
| 35 | `openssh` | FAIL | dietlibc | 18s | 1 | [cast] ERROR: openssh failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/openssh.log) |
| 36 | `mc` | FAIL | dietlibc | 3s | 1 | [cast] ERROR: mc failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mc.log) |
| 37 | `curl` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/curl.log) |
| 38 | `wget` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/wget.log) |
| 39 | `python3` | FAIL | dietlibc+fallback | 2m 09s | 1 | [cast] ERROR: python3 failed with standard libc fallback | [Log](reports/compile-logs/python3.log) |
| 40 | `fontconfig` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/fontconfig.log) |
| 41 | `dconf` | FAIL | dietlibc | 18s | 1 | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/dconf.log) |
| 42 | `libXext` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libXext.log) |
| 43 | `libXrender` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libXrender.log) |
| 44 | `libXfixes` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libXfixes.log) |
| 45 | `libXfont2` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libXfont2.log) |
| 46 | `pulseaudio` | FAIL | dietlibc | 18s | 1 | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/pulseaudio.log) |
| 47 | `tor` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/tor.log) |
| 48 | `rust` | FAIL | dietlibc+fallback | 5m 01s | 1 | [cast] ERROR: llvm failed with standard libc fallback | [Log](reports/compile-logs/rust.log) |
| 49 | `nodejs` | FAIL | dietlibc+fallback | 2m 09s | 1 | [cast] ERROR: python3 failed with standard libc fallback | [Log](reports/compile-logs/nodejs.log) |
| 50 | `libxkbfile` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libxkbfile.log) |
| 51 | `cairo` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/cairo.log) |
| 52 | `libXrandr` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libXrandr.log) |
| 53 | `libXi` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libXi.log) |
| 54 | `xkbcomp` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/xkbcomp.log) |
| 55 | `libxklavier` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libxklavier.log) |
| 56 | `pango` | FAIL | dietlibc | 25s | 1 | [cast] ERROR: pango failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/pango.log) |
| 57 | `libXtst` | PASS (cached) | dietlibc | 0s | 0 |  | [Log](reports/compile-logs/libXtst.log) |
| 58 | `gtk3` | FAIL | dietlibc | 19s | 1 | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/gtk3.log) |
| 59 | `mesa` | FAIL | dietlibc | 11s | 1 | [cast] ERROR: mesa failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mesa.log) |
| 60 | `qtbase` | FAIL | dietlibc | 18s | 1 | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/qtbase.log) |
| 61 | `xorg-server` | FAIL | dietlibc | 18s | 1 | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/xorg-server.log) |
| 62 | `libmatekbd` | FAIL | dietlibc | 18s | 1 | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/libmatekbd.log) |
| 63 | `mate-desktop` | FAIL | dietlibc | 19s | 1 | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mate-desktop.log) |
| 64 | `marco` | FAIL | dietlibc | 18s | 1 | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/marco.log) |
| 65 | `mate-panel` | FAIL | dietlibc | 4s | 1 | [cast] ERROR: mate-menus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mate-panel.log) |
| 66 | `mate-session-manager` | FAIL | dietlibc | 19s | 1 | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mate-session-manager.log) |
| 67 | `mate-terminal` | FAIL | dietlibc | 18s | 1 | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mate-terminal.log) |
| 68 | `caja` | FAIL | dietlibc | 18s | 1 | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/caja.log) |
| 69 | `vlc` | FAIL | dietlibc | 3s | 1 | [cast] ERROR: ffmpeg failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/vlc.log) |
| 70 | `firefox` | FAIL | dietlibc+fallback | 5m 00s | 1 | [cast] ERROR: llvm failed with standard libc fallback | [Log](reports/compile-logs/firefox.log) |
| 71 | `mate` | FAIL | dietlibc | 5s | 1 | [cast] ERROR: mate-menus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mate.log) |
| 72 | `bash` | PASS (cached) | glibc-fallback | 0s | 0 |  | [Log](reports/compile-logs/bash.log) |
| 73 | `tmux` | FAIL | dietlibc+fallback | 9s | 1 | [cast] ERROR: tmux failed with standard libc fallback | [Log](reports/compile-logs/tmux.log) |
| 74 | `python3.12` | FAIL | dietlibc+fallback | 1m 55s | 1 | [cast] ERROR: python3.12 failed with standard libc fallback | [Log](reports/compile-logs/python3.12.log) |
| 75 | `llama.cpp` | FAIL | dietlibc+fallback | 24s | 1 | [cast] ERROR: llama.cpp failed with standard libc fallback | [Log](reports/compile-logs/llama.cpp.log) |

## Fehlgeschlagene Pakete

| Paket | Ergebnis | Libc | Grund | Log |
|---|---|---|---|---|
| `ffmpeg` | FAIL | dietlibc | [cast] ERROR: ffmpeg failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/ffmpeg.log) |
| `llvm` | FAIL | dietlibc+fallback | [cast] ERROR: llvm failed with standard libc fallback | [Log](reports/compile-logs/llvm.log) |
| `dbus` | FAIL | dietlibc | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/dbus.log) |
| `mate-menus` | FAIL | dietlibc | [cast] ERROR: mate-menus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mate-menus.log) |
| `openssh` | FAIL | dietlibc | [cast] ERROR: openssh failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/openssh.log) |
| `mc` | FAIL | dietlibc | [cast] ERROR: mc failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mc.log) |
| `python3` | FAIL | dietlibc+fallback | [cast] ERROR: python3 failed with standard libc fallback | [Log](reports/compile-logs/python3.log) |
| `dconf` | FAIL | dietlibc | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/dconf.log) |
| `pulseaudio` | FAIL | dietlibc | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/pulseaudio.log) |
| `rust` | FAIL | dietlibc+fallback | [cast] ERROR: llvm failed with standard libc fallback | [Log](reports/compile-logs/rust.log) |
| `nodejs` | FAIL | dietlibc+fallback | [cast] ERROR: python3 failed with standard libc fallback | [Log](reports/compile-logs/nodejs.log) |
| `pango` | FAIL | dietlibc | [cast] ERROR: pango failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/pango.log) |
| `gtk3` | FAIL | dietlibc | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/gtk3.log) |
| `mesa` | FAIL | dietlibc | [cast] ERROR: mesa failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mesa.log) |
| `qtbase` | FAIL | dietlibc | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/qtbase.log) |
| `xorg-server` | FAIL | dietlibc | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/xorg-server.log) |
| `libmatekbd` | FAIL | dietlibc | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/libmatekbd.log) |
| `mate-desktop` | FAIL | dietlibc | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mate-desktop.log) |
| `marco` | FAIL | dietlibc | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/marco.log) |
| `mate-panel` | FAIL | dietlibc | [cast] ERROR: mate-menus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mate-panel.log) |
| `mate-session-manager` | FAIL | dietlibc | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mate-session-manager.log) |
| `mate-terminal` | FAIL | dietlibc | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mate-terminal.log) |
| `caja` | FAIL | dietlibc | [cast] ERROR: dbus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/caja.log) |
| `vlc` | FAIL | dietlibc | [cast] ERROR: ffmpeg failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/vlc.log) |
| `firefox` | FAIL | dietlibc+fallback | [cast] ERROR: llvm failed with standard libc fallback | [Log](reports/compile-logs/firefox.log) |
| `mate` | FAIL | dietlibc | [cast] ERROR: mate-menus failed with dietlibc and FALLBACK_ALLOWED is not set | [Log](reports/compile-logs/mate.log) |
| `tmux` | FAIL | dietlibc+fallback | [cast] ERROR: tmux failed with standard libc fallback | [Log](reports/compile-logs/tmux.log) |
| `python3.12` | FAIL | dietlibc+fallback | [cast] ERROR: python3.12 failed with standard libc fallback | [Log](reports/compile-logs/python3.12.log) |
| `llama.cpp` | FAIL | dietlibc+fallback | [cast] ERROR: llama.cpp failed with standard libc fallback | [Log](reports/compile-logs/llama.cpp.log) |

## libc-Auswahl pro Paket

Ein Paket wird mit **dietlibc** gebaut, wenn sein gemessenes Kompilat **streng kleiner** ist als die glibc-Variante. Alle anderen Pakete werden mit **glibc** gebaut.

| Ergebnis | Anzahl |
|---|---:|
| dietlibc | 27 |
| glibc | 48 |

- Gewählte Nutzlast (vergleichbare Pakete): 154.9 MiB
- Alles glibc: 174.7 MiB
- Ersparnis: 19.8 MiB

| Paket | libc | dietlibc | glibc | Begründung |
|---|---|---:|---:|---|
| `xcb-proto` | glibc | 1.0 MiB | 1.0 MiB | gleich groß – Standard-libc |
| `xorgproto` | dietlibc | 1.1 MiB | 1.1 MiB | dietlibc-Kompilat kleiner (1.1 MiB < 1.1 MiB) |
| `libpthread-stubs` | glibc | – | – | keine vergleichbare Nutzlast – Standard-libc |
| `dietcompat` | dietlibc | 10.5 KiB | – | nur für dietlibc-Pakete benötigt |
| `zlib` | glibc | 241.6 KiB | 237.8 KiB | glibc-Kompilat kleiner (237.8 KiB < 241.6 KiB) |
| `xz` | glibc | 1.2 MiB | 1.0 MiB | glibc-Kompilat kleiner (1.0 MiB < 1.2 MiB) |
| `expat` | dietlibc | 333.8 KiB | 334.1 KiB | dietlibc-Kompilat kleiner (333.8 KiB < 334.1 KiB) |
| `libffi` | dietlibc | 84.7 KiB | 85.2 KiB | dietlibc-Kompilat kleiner (84.7 KiB < 85.2 KiB) |
| `pcre2` | glibc | 1.4 MiB | 1.4 MiB | glibc-Kompilat kleiner (1.4 MiB < 1.4 MiB) |
| `harfbuzz` | glibc | 5.7 MiB | 5.7 MiB | gleich groß – Standard-libc |
| `pixman` | dietlibc | 692.6 KiB | 696.9 KiB | dietlibc-Kompilat kleiner (692.6 KiB < 696.9 KiB) |
| `libXau` | dietlibc | 23.5 KiB | 23.6 KiB | dietlibc-Kompilat kleiner (23.5 KiB < 23.6 KiB) |
| `libXdmcp` | dietlibc | 38.2 KiB | 38.3 KiB | dietlibc-Kompilat kleiner (38.2 KiB < 38.3 KiB) |
| `libdrm` | dietlibc | 1023.7 KiB | 1.0 MiB | dietlibc-Kompilat kleiner (1023.7 KiB < 1.0 MiB) |
| `xkeyboard-config` | glibc | 3.1 MiB | 3.1 MiB | gleich groß – Standard-libc |
| `alsa-lib` | dietlibc | 3.8 MiB | 3.9 MiB | dietlibc-Kompilat kleiner (3.8 MiB < 3.9 MiB) |
| `ncurses` | dietlibc | 6.7 MiB | 12.0 MiB | dietlibc-Kompilat kleiner (6.7 MiB < 12.0 MiB) |
| `nasm` | dietlibc | 4.6 MiB | 6.6 MiB | dietlibc-Kompilat kleiner (4.6 MiB < 6.6 MiB) |
| `openssl` | dietlibc | 13.9 MiB | 13.9 MiB | dietlibc-Kompilat kleiner (13.9 MiB < 13.9 MiB) |
| `glib` | glibc | 13.8 MiB | 13.8 MiB | glibc-Kompilat kleiner (13.8 MiB < 13.8 MiB) |
| `libpng` | glibc | 895.5 KiB | 880.3 KiB | glibc-Kompilat kleiner (880.3 KiB < 895.5 KiB) |
| `libxcb` | glibc | 3.2 MiB | 3.2 MiB | glibc-Kompilat kleiner (3.2 MiB < 3.2 MiB) |
| `ffmpeg` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `llvm` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `libfontenc` | dietlibc | 45.5 KiB | 45.7 KiB | dietlibc-Kompilat kleiner (45.5 KiB < 45.7 KiB) |
| `libevent` | dietlibc | 1.6 MiB | 1.6 MiB | dietlibc-Kompilat kleiner (1.6 MiB < 1.6 MiB) |
| `dbus` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `freetype` | glibc | 1.8 MiB | 1.8 MiB | glibc-Kompilat kleiner (1.8 MiB < 1.8 MiB) |
| `atk` | glibc | 550.8 KiB | 550.8 KiB | gleich groß – Standard-libc |
| `gdk-pixbuf` | dietlibc | 14.4 MiB | 19.2 MiB | dietlibc-Kompilat kleiner (14.4 MiB < 19.2 MiB) |
| `gsettings-desktop-schemas` | glibc | 152.7 KiB | 152.7 KiB | gleich groß – Standard-libc |
| `xtrans` | glibc | 158.5 KiB | 158.5 KiB | gleich groß – Standard-libc |
| `libX11` | dietlibc | 2.5 MiB | 2.5 MiB | dietlibc-Kompilat kleiner (2.5 MiB < 2.5 MiB) |
| `mate-menus` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `openssh` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `mc` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `curl` | dietlibc | 8.3 MiB | 8.6 MiB | dietlibc-Kompilat kleiner (8.3 MiB < 8.6 MiB) |
| `wget` | dietlibc | 6.1 MiB | 7.3 MiB | dietlibc-Kompilat kleiner (6.1 MiB < 7.3 MiB) |
| `python3` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `fontconfig` | dietlibc | 13.5 MiB | 13.7 MiB | dietlibc-Kompilat kleiner (13.5 MiB < 13.7 MiB) |
| `dconf` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `libXext` | dietlibc | 179.2 KiB | 179.4 KiB | dietlibc-Kompilat kleiner (179.2 KiB < 179.4 KiB) |
| `libXrender` | glibc | 96.3 KiB | 96.3 KiB | glibc-Kompilat kleiner (96.3 KiB < 96.3 KiB) |
| `libXfixes` | glibc | 38.6 KiB | 38.6 KiB | glibc-Kompilat kleiner (38.6 KiB < 38.6 KiB) |
| `libXfont2` | dietlibc | 411.8 KiB | 413.6 KiB | dietlibc-Kompilat kleiner (411.8 KiB < 413.6 KiB) |
| `pulseaudio` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `tor` | dietlibc | 37.2 MiB | 41.9 MiB | dietlibc-Kompilat kleiner (37.2 MiB < 41.9 MiB) |
| `rust` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `nodejs` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `libxkbfile` | glibc | 303.4 KiB | 302.6 KiB | glibc-Kompilat kleiner (302.6 KiB < 303.4 KiB) |
| `cairo` | glibc | 3.1 MiB | 2.9 MiB | glibc-Kompilat kleiner (2.9 MiB < 3.1 MiB) |
| `libXrandr` | dietlibc | 89.6 KiB | 89.8 KiB | dietlibc-Kompilat kleiner (89.6 KiB < 89.8 KiB) |
| `libXi` | dietlibc | 232.0 KiB | 234.3 KiB | dietlibc-Kompilat kleiner (232.0 KiB < 234.3 KiB) |
| `xkbcomp` | dietlibc | 1.5 MiB | 2.6 MiB | dietlibc-Kompilat kleiner (1.5 MiB < 2.6 MiB) |
| `libxklavier` | dietlibc | 328.1 KiB | 329.8 KiB | dietlibc-Kompilat kleiner (328.1 KiB < 329.8 KiB) |
| `pango` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `libXtst` | dietlibc | 36.6 KiB | 36.7 KiB | dietlibc-Kompilat kleiner (36.6 KiB < 36.7 KiB) |
| `gtk3` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `mesa` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `qtbase` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `xorg-server` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `libmatekbd` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `mate-desktop` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `marco` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `mate-panel` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `mate-session-manager` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `mate-terminal` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `caja` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `vlc` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `firefox` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `mate` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `bash` | glibc | – | – | dokumentierter glibc-Fallback im dietlibc-Lauf |
| `tmux` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `python3.12` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |
| `llama.cpp` | glibc | – | – | dietlibc-Build nicht möglich – Standard-libc |

### Nur dietlibc (27)

- `xorgproto`
- `dietcompat`
- `expat`
- `libffi`
- `pixman`
- `libXau`
- `libXdmcp`
- `libdrm`
- `alsa-lib`
- `ncurses`
- `nasm`
- `openssl`
- `libfontenc`
- `libevent`
- `gdk-pixbuf`
- `libX11`
- `curl`
- `wget`
- `fontconfig`
- `libXext`
- `libXfont2`
- `tor`
- `libXrandr`
- `libXi`
- `xkbcomp`
- `libxklavier`
- `libXtst`

### Nur glibc (48)

- `xcb-proto`
- `libpthread-stubs`
- `zlib`
- `xz`
- `pcre2`
- `harfbuzz`
- `xkeyboard-config`
- `glib`
- `libpng`
- `libxcb`
- `ffmpeg`
- `llvm`
- `dbus`
- `freetype`
- `atk`
- `gsettings-desktop-schemas`
- `xtrans`
- `mate-menus`
- `openssh`
- `mc`
- `python3`
- `dconf`
- `libXrender`
- `libXfixes`
- `pulseaudio`
- `rust`
- `nodejs`
- `libxkbfile`
- `cairo`
- `pango`
- `gtk3`
- `mesa`
- `qtbase`
- `xorg-server`
- `libmatekbd`
- `mate-desktop`
- `marco`
- `mate-panel`
- `mate-session-manager`
- `mate-terminal`
- `caja`
- `vlc`
- `firefox`
- `mate`
- `bash`
- `tmux`
- `python3.12`
- `llama.cpp`

## Größenvergleich: dietlibc vs. glibc

Beide Varianten werden aus derselben Quelle und mit denselben Spell-Rezepten gebaut und statisch gelinkt (`-static`). Gemessen wird die installierte Nutzlast (Programme, Bibliotheken und Daten); Dokumentation, Locales und pkg-config-Dateien sind ausgeschlossen. Bei glibc steckt die statisch gelinkte C-Bibliothek in jeder ausführbaren Datei, daher ist der Unterschied dort erwartungsgemäß groß.

| Paket | dietlibc | glibc | Differenz | Faktor | Dateien (diet/glibc) | glibc-Build | Log |
|---|---:|---:|---:|---:|---:|---:|---|
| `xcb-proto` | 1.0 MiB | 1.0 MiB | 0 B | 1.00× | 61/61 | 2s | [Log](reports/glibc-logs/xcb-proto.log) |
| `xorgproto` | 1.1 MiB | 1.1 MiB | +2 B | 1.00× | 129/129 | 7s | [Log](reports/glibc-logs/xorgproto.log) |
| `zlib` | 241.6 KiB | 237.8 KiB | -3.8 KiB | 0.98× | 3/3 | 2s | [Log](reports/glibc-logs/zlib.log) |
| `xz` | 1.2 MiB | 1.0 MiB | -105.3 KiB | 0.91× | 25/25 | 17s | [Log](reports/glibc-logs/xz.log) |
| `expat` | 333.8 KiB | 334.1 KiB | +327 B | 1.00× | 5/5 | 9s | [Log](reports/glibc-logs/expat.log) |
| `libffi` | 84.7 KiB | 85.2 KiB | +502 B | 1.01× | 4/4 | 6s | [Log](reports/glibc-logs/libffi.log) |
| `pcre2` | 1.4 MiB | 1.4 MiB | -16.2 KiB | 0.99× | 9/9 | 14s | [Log](reports/glibc-logs/pcre2.log) |
| `harfbuzz` | 5.7 MiB | 5.7 MiB | 0 B | 1.00× | 35/35 | 1m 25s | [Log](reports/glibc-logs/harfbuzz.log) |
| `pixman` | 692.6 KiB | 696.9 KiB | +4.2 KiB | 1.01× | 3/3 | 8s | [Log](reports/glibc-logs/pixman.log) |
| `libXau` | 23.5 KiB | 23.6 KiB | +150 B | 1.01× | 3/3 | 7s | [Log](reports/glibc-logs/libXau.log) |
| `libXdmcp` | 38.2 KiB | 38.3 KiB | +22 B | 1.00× | 3/3 | 7s | [Log](reports/glibc-logs/libXdmcp.log) |
| `libdrm` | 1023.7 KiB | 1.0 MiB | +7.8 KiB | 1.01× | 45/45 | 4s | [Log](reports/glibc-logs/libdrm.log) |
| `xkeyboard-config` | 3.1 MiB | 3.1 MiB | 0 B | 1.00× | 292/292 | 2s | [Log](reports/glibc-logs/xkeyboard-config.log) |
| `alsa-lib` | 3.8 MiB | 3.9 MiB | +62.1 KiB | 1.02× | 133/133 | 20s | [Log](reports/glibc-logs/alsa-lib.log) |
| `ncurses` | 6.7 MiB | 12.0 MiB | +5.3 MiB | 1.79× | 2905/2905 | 37s | [Log](reports/glibc-logs/ncurses.log) |
| `nasm` | 4.6 MiB | 6.6 MiB | +2.0 MiB | 1.42× | 2/2 | 23s | [Log](reports/glibc-logs/nasm.log) |
| `openssl` | 13.9 MiB | 13.9 MiB | +21.0 KiB | 1.00× | 141/141 | 1m 01s | [Log](reports/glibc-logs/openssl.log) |
| `glib` | 13.8 MiB | 13.8 MiB | -167 B | 1.00× | 405/405 | 39s | [Log](reports/glibc-logs/glib.log) |
| `libpng` | 895.5 KiB | 880.3 KiB | -15.2 KiB | 0.98× | 8/8 | 7s | [Log](reports/glibc-logs/libpng.log) |
| `libxcb` | 3.2 MiB | 3.2 MiB | -716 B | 1.00× | 83/83 | 17s | [Log](reports/glibc-logs/libxcb.log) |
| `libfontenc` | 45.5 KiB | 45.7 KiB | +180 B | 1.00× | 3/3 | 7s | [Log](reports/glibc-logs/libfontenc.log) |
| `libevent` | 1.6 MiB | 1.6 MiB | +2.0 KiB | 1.00× | 42/42 | 18s | [Log](reports/glibc-logs/libevent.log) |
| `freetype` | 1.8 MiB | 1.8 MiB | -11.3 KiB | 0.99× | 57/57 | 12s | [Log](reports/glibc-logs/freetype.log) |
| `atk` | 550.8 KiB | 550.8 KiB | 0 B | 1.00× | 36/36 | 4s | [Log](reports/glibc-logs/atk.log) |
| `gdk-pixbuf` | 14.4 MiB | 19.2 MiB | +4.9 MiB | 1.34× | 19/19 | 6s | [Log](reports/glibc-logs/gdk-pixbuf.log) |
| `gsettings-desktop-schemas` | 152.7 KiB | 152.7 KiB | 0 B | 1.00× | 34/34 | 2s | [Log](reports/glibc-logs/gsettings-desktop-schemas.log) |
| `xtrans` | 158.5 KiB | 158.5 KiB | 0 B | 1.00× | 7/7 | 5s | [Log](reports/glibc-logs/xtrans.log) |
| `libX11` | 2.5 MiB | 2.5 MiB | +8.1 KiB | 1.00× | 19/19 | 38s | [Log](reports/glibc-logs/libX11.log) |
| `curl` | 8.3 MiB | 8.6 MiB | +354.0 KiB | 1.04× | 16/16 | 45s | [Log](reports/glibc-logs/curl.log) |
| `wget` | 6.1 MiB | 7.3 MiB | +1.2 MiB | 1.20× | 2/2 | 1m 00s | [Log](reports/glibc-logs/wget.log) |
| `fontconfig` | 13.5 MiB | 13.7 MiB | +231.5 KiB | 1.02× | 60/60 | 22s | [Log](reports/glibc-logs/fontconfig.log) |
| `libXext` | 179.2 KiB | 179.4 KiB | +220 B | 1.00× | 18/18 | 8s | [Log](reports/glibc-logs/libXext.log) |
| `libXrender` | 96.3 KiB | 96.3 KiB | -12 B | 1.00× | 3/3 | 8s | [Log](reports/glibc-logs/libXrender.log) |
| `libXfixes` | 38.6 KiB | 38.6 KiB | -12 B | 1.00× | 3/3 | 6s | [Log](reports/glibc-logs/libXfixes.log) |
| `libXfont2` | 411.8 KiB | 413.6 KiB | +1.8 KiB | 1.00× | 3/3 | 12s | [Log](reports/glibc-logs/libXfont2.log) |
| `tor` | 37.2 MiB | 41.9 MiB | +4.7 MiB | 1.13× | 8/8 | 1m 03s | [Log](reports/glibc-logs/tor.log) |
| `libxkbfile` | 303.4 KiB | 302.6 KiB | -804 B | 1.00× | 8/8 | 8s | [Log](reports/glibc-logs/libxkbfile.log) |
| `cairo` | 3.1 MiB | 2.9 MiB | -226.7 KiB | 0.93× | 119/119 | 18s | [Log](reports/glibc-logs/cairo.log) |
| `libXrandr` | 89.6 KiB | 89.8 KiB | +268 B | 1.00× | 3/3 | 7s | [Log](reports/glibc-logs/libXrandr.log) |
| `libXi` | 232.0 KiB | 234.3 KiB | +2.3 KiB | 1.01× | 4/4 | 9s | [Log](reports/glibc-logs/libXi.log) |
| `xkbcomp` | 1.5 MiB | 2.6 MiB | +1.1 MiB | 1.72× | 1/1 | 7s | [Log](reports/glibc-logs/xkbcomp.log) |
| `libxklavier` | 328.1 KiB | 329.8 KiB | +1.8 KiB | 1.01× | 24/24 | 6s | [Log](reports/glibc-logs/libxklavier.log) |
| `libXtst` | 36.6 KiB | 36.7 KiB | +42 B | 1.00× | 4/4 | 7s | [Log](reports/glibc-logs/libXtst.log) |
| **Gesamt (43)** | **155.3 MiB** | **174.7 MiB** | **+19.4 MiB** | **1.13×** | 4787/4787 | **12m 32s** | |

### Pakete ohne glibc-Vergleichsbuild

| Paket | dietlibc | glibc-Ergebnis | Grund | Log |
|---|---|---|---|---|
| `libpthread-stubs` | PASS (dietlibc) | SKIP | no compiled payload |  |
| `dietcompat` | PASS (dietlibc) | SKIP | dietlibc-only compatibility shim |  |

## Erstausgabe / Abbilder (built)

- Pakete in der Rootfs: 49
- davon dietlibc: 27
- davon glibc: 22
- Rootfs-Größe: 178.7 MiB
- `out/LEANUX-0.1.0-built.img` (299.0 MiB)
- `out/LEANUX-0.1.0-built.iso` (94.4 MiB)
- Release-Bericht: `out/RELEASE-BERICHT.md`
- Manifest: `out/rootfs-manifest.tsv`

## Erstausgabe / Abbilder (base)

- Pakete in der Rootfs: 24
- davon dietlibc: 11
- davon glibc: 13
- Rootfs-Größe: 153.2 MiB
- `out-base/LEANUX-0.1.0-base.img` (261.0 MiB)
- `out-base/LEANUX-0.1.0-base.iso` (85.5 MiB)
- Release-Bericht: `out-base/RELEASE-BERICHT.md`
- Manifest: `out-base/rootfs-manifest.tsv`

## Artefakte

- Kompilier-Matrix: `reports/compile-matrix.tsv`
- Größenvergleich: `reports/libc-size-comparison.tsv`
- Vollständige Build-Logs: `reports/compile-logs/`
- Vollständige glibc-Logs: `reports/glibc-logs/`
- Quellen-Report: `reports/source-fetch.md`

Die Markdown-Tabellen oben enthalten alle Pakete. Bei Bedarf stehen die vollständigen Configure-/Make-Ausgaben in den verlinkten Logdateien.

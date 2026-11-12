#!/usr/bin/env bash
# tools/collect_kernel_modules.sh – copy the kernel modules the LEANUX
# initramfs needs to find and mount the ISO root filesystem.
#
# The initramfs is deliberately tiny.  It must not rely on the host initramfs
# conventions: on many kernels the CD/DVD, USB and AHCI drivers are loadable
# modules, so without them the initramfs cannot see the installation medium and
# drops into a rescue shell (or, with a broken console setup, panics).
#
# Usage:
#   ./tools/collect_kernel_modules.sh --kernel-version 6.14.0-37-generic \
#       --dest out/initramfs-root
#   ./tools/collect_kernel_modules.sh --kernel-version 6.14.0-37-generic --list
#
# Options:
#   --kernel-version VER   kernel release whose /lib/modules tree is used
#   --dest DIR             initramfs root; modules are copied below it
#   --module NAME          add a module (repeatable, replaces the default list)
#   --list                 print the resolved module files, copy nothing
#   --help                 show this help
#
# Output:
#   DIR/lib/modules/VER/...   decompressed .ko files (zstd is unpacked)
#   DIR/modules.load          one absolute module path per line, dependencies
#                             first, ready for `busybox insmod`
#
# Modules that the kernel built in are reported as "builtin" by modprobe and
# are skipped automatically.

set -uo pipefail

KERNEL_VERSION=""
DEST=""
LIST_ONLY=0
MODULES=()

# Storage, filesystem and bus drivers needed for a CD/DVD, USB stick, SATA or
# NVMe device.  Builtins are harmless: modprobe reports them and they are
# skipped.
DEFAULT_MODULES=(
    isofs
    squashfs
    loop
    sr_mod
    cdrom
    sd_mod
    scsi_mod
    ahci
    libahci
    ata_piix
    pata_acpi
    usb-storage
    uas
    usbcore
    usb-common
    xhci-hcd
    xhci-pci
    ehci-hcd
    ehci-pci
    ohci-hcd
    ohci-pci
    uhci-hcd
    virtio
    virtio_ring
    virtio_pci
    virtio_blk
    nvme
    nvme_core
)

usage() {
    sed -n '2,30p' "$0"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --kernel-version)
            [ $# -ge 2 ] || { echo "ERROR: --kernel-version needs a value" >&2; exit 2; }
            KERNEL_VERSION="$2"; shift 2 ;;
        --dest)
            [ $# -ge 2 ] || { echo "ERROR: --dest needs a value" >&2; exit 2; }
            DEST="$2"; shift 2 ;;
        --module)
            [ $# -ge 2 ] || { echo "ERROR: --module needs a value" >&2; exit 2; }
            MODULES+=("$2"); shift 2 ;;
        --list) LIST_ONLY=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "ERROR: unknown option: $1" >&2; exit 2 ;;
    esac
done

[ -n "$KERNEL_VERSION" ] || { echo "ERROR: --kernel-version is required" >&2; exit 2; }
if [ "$LIST_ONLY" = 0 ] && [ -z "$DEST" ]; then
    echo "ERROR: --dest is required (or use --list)" >&2
    exit 2
fi

if [ ! -d "/lib/modules/$KERNEL_VERSION" ]; then
    echo "ERROR: /lib/modules/$KERNEL_VERSION not found" >&2
    echo "       the ISO kernel and the installed module tree do not match" >&2
    exit 1
fi

if [ ${#MODULES[@]} -eq 0 ]; then
    MODULES=("${DEFAULT_MODULES[@]}")
fi

command -v modprobe >/dev/null 2>&1 || {
    echo "ERROR: modprobe not found (install kmod)" >&2
    exit 1
}

# Busybox insmod cannot read zstd-compressed modules, so they are unpacked.
if command -v unzstd >/dev/null 2>&1; then
    DECOMPRESS=(unzstd -c)
elif command -v zstd >/dev/null 2>&1; then
    DECOMPRESS=(zstd -dc)
else
    DECOMPRESS=()
fi

# modprobe prints dependencies before the module itself, which is exactly the
# load order the initramfs needs.  It also knows which modules are builtin.
resolve_module() {
    local module="$1" line path
    while IFS= read -r line; do
        case "$line" in
            "insmod "*)
                path="${line#insmod }"
                path="${path%% *}"
                [ -n "$path" ] && printf '%s\n' "$path"
                ;;
        esac
    done < <(modprobe --show-depends --set-version "$KERNEL_VERSION" "$module" 2>/dev/null)
}

declare -A SEEN=()
ORDER=()
for module in "${MODULES[@]}"; do
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        [ -n "${SEEN[$path]:-}" ] && continue
        SEEN[$path]=1
        ORDER+=("$path")
    done < <(resolve_module "$module")
done

if [ "$LIST_ONLY" = 1 ]; then
    for path in "${ORDER[@]}"; do
        printf '%s\n' "$path"
    done
    exit 0
fi

mkdir -p "$DEST"
: > "$DEST/modules.load"

copied=0
for path in "${ORDER[@]}"; do
    rel="${path#/}"
    case "$path" in
        *.zst)
            target="${rel%.zst}"
            if [ ${#DECOMPRESS[@]} -eq 0 ]; then
                echo "WARNING: no zstd tool, skipping $path" >&2
                continue
            fi
            mkdir -p "$DEST/$(dirname "$target")"
            if ! "${DECOMPRESS[@]}" "$path" > "$DEST/$target" 2>/dev/null; then
                echo "WARNING: cannot decompress $path" >&2
                rm -f "$DEST/$target"
                continue
            fi
            ;;
        *)
            target="$rel"
            mkdir -p "$DEST/$(dirname "$target")"
            cp "$path" "$DEST/$target" || {
                echo "WARNING: cannot copy $path" >&2
                continue
            }
            ;;
    esac
    printf '/%s\n' "$target" >> "$DEST/modules.load"
    copied=$((copied + 1))
done

if [ "$copied" -eq 0 ]; then
    echo "WARNING: no loadable modules found for $KERNEL_VERSION (all builtin?)" >&2
fi

printf '[modules] %d module(s) for %s -> %s\n' "$copied" "$KERNEL_VERSION" "$DEST" >&2

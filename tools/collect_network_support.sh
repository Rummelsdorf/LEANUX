#!/usr/bin/env bash
# tools/collect_network_support.sh – copy network drivers and firmware into a
# LEANUX root filesystem.
#
# The live ISO boots a squashfs root without the host's initramfs, so the
# network drivers are not available after switch_root.  This tool copies a
# curated set of common Ethernet, VirtIO, VMXNET3, Hyper-V and USB network
# modules (with their dependencies and firmware) into the image and writes
# /etc/modules.network, which the init script loads at boot.
#
# Usage:
#   ./tools/collect_network_support.sh --kernel-version 6.14.0-37-generic \
#       --rootfs out/rootfs
#   ./tools/collect_network_support.sh --kernel-version 6.14.0-37-generic --list
#
# Options:
#   --kernel-version VER   kernel release whose /lib/modules tree is used
#   --rootfs DIR           assembled root filesystem
#   --module NAME          add a module (repeatable, replaces the default list)
#   --no-firmware          do not copy firmware blobs
#   --list                 print the resolved module files, copy nothing
#   --help                 show this help
#
# Output:
#   ROOTFS/lib/modules/VER/...   decompressed .ko files
#   ROOTFS/lib/firmware/...      firmware required by those modules
#   ROOTFS/etc/modules.network   absolute module paths, dependencies first

set -uo pipefail

KERNEL_VERSION=""
ROOTFS=""
LIST_ONLY=0
WITH_FIRMWARE=1
MODULES=()

# Common wired, virtual and USB network adapters.  Wireless adapters are not
# included: they need wpa_supplicant and per-device firmware, which the first
# edition does not ship.  Modules that are builtin or absent are skipped.
DEFAULT_MODULES=(
    # virtio / hypervisors
    virtio_net
    net_failover
    failover
    vmxnet3
    hv_netvsc
    # Intel / AMD / Broadcom / Realtek / Marvell PCIe
    e1000
    e1000e
    igb
    igc
    ixgbe
    ixgbevf
    i40e
    ice
    r8169
    tg3
    bnx2
    bnx2x
    atlantic
    sky2
    skge
    # older PCI adapters
    8139too
    8139cp
    via_rhine
    sis900
    ne2k_pci
    pcnet32
    forcedeth
    tulip
    sundance
    epic100
    dl2k
    ns83820
    hamachi
    r6040
    sc92031
    yellowfin
    acenic
    # cloud
    ena
    # USB network adapters and their host controllers
    usbnet
    cdc_ether
    cdc_ncm
    cdc_subset
    rndis_host
    ax88179_178a
    asix
    r8152
    sr9700
    smsc75xx
    smsc95xx
    usb-common
    usbcore
    xhci-hcd
    ehci-hcd
    ohci-hcd
    uhci-hcd
    # PHY helpers
    mii
    libphy
    mdio
)

usage() {
    sed -n '2,29p' "$0"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --kernel-version)
            [ $# -ge 2 ] || { echo "ERROR: --kernel-version needs a value" >&2; exit 2; }
            KERNEL_VERSION="$2"; shift 2 ;;
        --rootfs)
            [ $# -ge 2 ] || { echo "ERROR: --rootfs needs a value" >&2; exit 2; }
            ROOTFS="$2"; shift 2 ;;
        --module)
            [ $# -ge 2 ] || { echo "ERROR: --module needs a value" >&2; exit 2; }
            MODULES+=("$2"); shift 2 ;;
        --no-firmware) WITH_FIRMWARE=0; shift ;;
        --list) LIST_ONLY=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "ERROR: unknown option: $1" >&2; exit 2 ;;
    esac
done

[ -n "$KERNEL_VERSION" ] || { echo "ERROR: --kernel-version is required" >&2; exit 2; }
if [ "$LIST_ONLY" = 0 ] && [ -z "$ROOTFS" ]; then
    echo "ERROR: --rootfs is required (or use --list)" >&2
    exit 2
fi

if [ ! -d "/lib/modules/$KERNEL_VERSION" ]; then
    echo "ERROR: /lib/modules/$KERNEL_VERSION not found" >&2
    exit 1
fi

command -v modprobe >/dev/null 2>&1 || {
    echo "ERROR: modprobe not found (install kmod)" >&2
    exit 1
}

if command -v unzstd >/dev/null 2>&1; then
    DECOMPRESS=(unzstd -c)
elif command -v zstd >/dev/null 2>&1; then
    DECOMPRESS=(zstd -dc)
else
    DECOMPRESS=()
fi

if [ ${#MODULES[@]} -eq 0 ]; then
    MODULES=("${DEFAULT_MODULES[@]}")
fi

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

[ -d "$ROOTFS" ] || { echo "ERROR: rootfs not found: $ROOTFS" >&2; exit 1; }

mkdir -p "$ROOTFS/lib/modules" "$ROOTFS/etc"
: > "$ROOTFS/etc/modules.network"

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
            mkdir -p "$ROOTFS/$(dirname "$target")"
            if ! "${DECOMPRESS[@]}" "$path" > "$ROOTFS/$target" 2>/dev/null; then
                echo "WARNING: cannot decompress $path" >&2
                rm -f "$ROOTFS/$target"
                continue
            fi
            ;;
        *)
            target="$rel"
            mkdir -p "$ROOTFS/$(dirname "$target")"
            cp "$path" "$ROOTFS/$target" || {
                echo "WARNING: cannot copy $path" >&2
                continue
            }
            ;;
    esac
    printf '/%s\n' "$target" >> "$ROOTFS/etc/modules.network"
    copied=$((copied + 1))
done

firmware=0
if [ "$WITH_FIRMWARE" = 1 ] && command -v modinfo >/dev/null 2>&1; then
    declare -A FW_SEEN=()
    for path in "${ORDER[@]}"; do
        while IFS= read -r fw; do
            [ -n "$fw" ] || continue
            [ -n "${FW_SEEN[$fw]:-}" ] && continue
            FW_SEEN[$fw]=1
            # Ubuntu ships firmware compressed (.zst/.xz).  The kernel firmware
            # loader finds the compressed variant automatically when
            # CONFIG_FW_LOADER_COMPRESS_* is enabled, so keep the original name
            # and extension instead of decompressing.
            src=""
            for candidate in "$fw" "$fw.zst" "$fw.xz"; do
                if [ -f "/lib/firmware/$candidate" ]; then
                    src="$candidate"
                    break
                fi
            done
            [ -n "$src" ] || continue
            mkdir -p "$ROOTFS/lib/firmware/$(dirname "$src")"
            cp "/lib/firmware/$src" "$ROOTFS/lib/firmware/$src" || {
                echo "WARNING: cannot copy firmware $src" >&2
                continue
            }
            firmware=$((firmware + 1))
        done < <(modinfo -F firmware "$path" 2>/dev/null)
    done
fi

printf '[network] %d module(s), %d firmware file(s) for %s -> %s\n' \
    "$copied" "$firmware" "$KERNEL_VERSION" "$ROOTFS" >&2

#!/usr/bin/env bash
# cast.sh – LEANUX spell builder
#
# Builds packages from source with dietlibc as the default C library.
# Falls back to the standard C library only when a spell explicitly allows it
# and the dietlibc build fails (FALLBACK_ALLOWED=1).
#
# Usage:
#   ./cast.sh <spell> [spell ...]
#   ./cast.sh --list
#   ./cast.sh --force <spell>
#   ./cast.sh --dry-run <spell> [spell ...]   print the resolved build plan
#   ./cast.sh --world                          build every spell in build/world.order
#   ./cast.sh --dry-run --world                print the full world build plan
#
# Environment:
#   SPELL_DIR      directory containing *.spell files (default: this dir)
#   STAGING_DIR    install root (default: ~/LEANUX/sysroot)
#   SOURCES_DIR    downloaded source archives (default: ~/LEANUX/sources)
#   BUILD_ROOT     per-package build trees (default: ~/LEANUX/build-output)
#   DIET_PREFIX    dietlibc installation (default: ~/LEANUX/tools/diet)
#   DIETGCC        dietlibc compiler wrapper (default: $DIET_PREFIX/bin/dietgcc)
#   JOBS           parallel make jobs (default: nproc)

set -euo pipefail

LEANUX_ROOT="${LEANUX_ROOT:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}"
SPELL_DIR="${SPELL_DIR:-$LEANUX_ROOT/spells}"
STAGING_DIR="${STAGING_DIR:-$LEANUX_ROOT/sysroot}"
SOURCES_DIR="${SOURCES_DIR:-$LEANUX_ROOT/sources}"
BUILD_ROOT="${BUILD_ROOT:-$LEANUX_ROOT/build-output}"
DIET_PREFIX="${DIET_PREFIX:-$LEANUX_ROOT/tools/diet}"
DIETGCC="${DIETGCC:-$DIET_PREFIX/bin/dietgcc}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 2)}"

# ---------------------------------------------------------------------------
# Logging helpers (also used by spell files)
# ---------------------------------------------------------------------------
log()  { printf '[cast] %s\n' "$*" >&2; }
warn() { printf '[cast] WARNING: %s\n' "$*" >&2; }
die()  { printf '[cast] ERROR: %s\n' "$*" >&2; exit 1; }

# Convenience wrapper used by some spells.
configure() { ./configure "$@"; }

# ---------------------------------------------------------------------------
# dietlibc setup
# ---------------------------------------------------------------------------
ensure_dietlibc() {
    if [ -x "$DIETGCC" ]; then
        return 0
    fi

    log "dietgcc not found at $DIETGCC – bootstrapping dietlibc"
    local tarball="$LEANUX_ROOT/diet/dietlibc-0.35.tar.xz"
    [ -f "$tarball" ] || die "dietlibc tarball missing: $tarball"

    local work="$BUILD_ROOT/dietlibc-0.35"
    rm -rf "$work"
    mkdir -p "$work"
    tar -xf "$tarball" -C "$work" --strip-components=1
    (
        cd "$work"
        make -j"$JOBS" >/dev/null
        make install prefix="$DIET_PREFIX" >/dev/null
    )
    mkdir -p "$DIET_PREFIX/bin"
    cat > "$DIETGCC" <<EOF
#!/bin/sh
export DIETHOME="\${DIETHOME:-$DIET_PREFIX}"
exec "$DIET_PREFIX/bin/diet" gcc "\$@"
EOF
    chmod +x "$DIETGCC"
    log "dietlibc installed at $DIET_PREFIX"
}

# ---------------------------------------------------------------------------
# Source handling
# ---------------------------------------------------------------------------
source_filename() {
    local url="$1"
    url="${url%%\?*}"
    basename "$url"
}

fetch_source() {
    local url="$1" hash="$2"
    [ -n "$url" ] || return 0
    mkdir -p "$SOURCES_DIR"
    local file="$SOURCES_DIR/$(source_filename "$url")"

    if [ ! -f "$file" ]; then
        log "Fetching $url"
        if command -v curl >/dev/null 2>&1; then
            curl -fL --retry 3 --connect-timeout 20 -o "$file.part" "$url" \
                || die "download failed: $url"
        elif command -v wget >/dev/null 2>&1; then
            wget -O "$file.part" "$url" || die "download failed: $url"
        else
            die "neither curl nor wget is available"
        fi
        mv "$file.part" "$file"
    else
        log "Using cached source $file"
    fi

    if [ -n "$hash" ] && [ "$hash" != "PLACEHOLDER_HASH" ]; then
        echo "$hash  $file" | sha256sum -c - >/dev/null \
            || die "SHA-256 mismatch for $file"
        log "Verified SHA-256 for $(basename "$file")"
    else
        warn "No SHA-256 pinned for $(basename "$file")"
    fi
    printf '%s\n' "$file"
}

extract_source() {
    local archive="$1" dest="$2"
    rm -rf "$dest"
    mkdir -p "$dest"
    case "$archive" in
        *.tar.gz|*.tgz|*.tar.xz|*.tar.bz2|*.tar)
            tar -xf "$archive" -C "$dest"
            ;;
        *.zip)
            command -v unzip >/dev/null 2>&1 || die "unzip is required for $archive"
            unzip -q "$archive" -d "$dest"
            ;;
        *)
            die "unsupported archive format: $archive"
            ;;
    esac

    # Collapse a single top-level directory so the build starts in it.
    local entries
    entries=$(find "$dest" -mindepth 1 -maxdepth 1 | wc -l)
    if [ "$entries" -eq 1 ]; then
        local only
        only=$(find "$dest" -mindepth 1 -maxdepth 1 -type d)
        if [ -n "$only" ]; then
            shopt -s dotglob
            mv "$only"/* "$dest"/
            rmdir "$only"
            shopt -u dotglob
        fi
    fi
}

# ---------------------------------------------------------------------------
# Spell metadata
# ---------------------------------------------------------------------------
spell_meta() {
    local spell="$1"
    # Only read the simple metadata lines; the build functions are not run here.
    grep -E '^(PACKAGE_NAME|PACKAGE_VERSION|DEPENDENCIES|EXTERNAL_DEPENDENCIES|FALLBACK_ALLOWED|LANGUAGE|SOURCE_URL|SOURCE_HASH|USE_DIETCOMPAT)=' "$spell" || true
}

is_built() {
    local pkg="$1"
    [ -f "$STAGING_DIR/install/$pkg/.built" ]
}

# ---------------------------------------------------------------------------
# Dependency resolution (DFS post-order, then Kahn topological sort)
# ---------------------------------------------------------------------------
declare -A GRAPH=()
declare -A VISITED=()

resolve_deps() {
    local pkg="$1" parent="$2"
    [ -n "${VISITED[$pkg]:-}" ] && return 0
    VISITED[$pkg]=1

    local spell="$SPELL_DIR/$pkg.spell"
    if [ ! -f "$spell" ]; then
        if [ -n "$parent" ]; then
            local allowed
            allowed=$(grep -E '^EXTERNAL_DEPENDENCIES=' "$SPELL_DIR/$parent.spell" || true)
            if printf '%s' "$allowed" | grep -q "\"$pkg\""; then
                log "Using system-provided dependency: $pkg (allowed by $parent)"
                return 0
            fi
        fi
        die "Missing spell for dependency '$pkg' (needed by ${parent:-user})"
    fi

    # shellcheck disable=SC1090
    source <(spell_meta "$spell")

    # Packages that use the dietlibc compatibility shim get an implicit
    # dependency on the dietcompat spell. This mirrors CLEANUX, where the shim
    # was linked into every package.
    local deps="${DEPENDENCIES[*]:-}"
    if [ "${USE_DIETCOMPAT:-0}" = "1" ]; then
        deps="$deps dietcompat"
    fi
    GRAPH[$pkg]="$deps"

    local dep
    for dep in $deps; do
        resolve_deps "$dep" "$pkg"
    done
}

topological_sort() {
    local -n graph_ref="$1"
    local -n result_arr="$2"

    declare -A in_degree=()
    declare -A edges=()

    local pkg
    for pkg in "${!graph_ref[@]}"; do
        in_degree[$pkg]=0
        edges[$pkg]=""
    done

    for pkg in "${!graph_ref[@]}"; do
        local dep
        for dep in ${graph_ref[$pkg]}; do
            [ -n "${in_degree[$dep]+x}" ] || in_degree[$dep]=0
            in_degree[$pkg]=$(( ${in_degree[$pkg]} + 1 ))
            edges[$dep]+=" $pkg"
        done
    done

    local queue=()
    for pkg in "${!in_degree[@]}"; do
        [ "${in_degree[$pkg]}" -eq 0 ] && queue+=("$pkg")
    done

    while [ ${#queue[@]} -gt 0 ]; do
        local current="${queue[0]}"
        queue=("${queue[@]:1}")
        result_arr+=("$current")
        local neighbour
        for neighbour in ${edges[$current]}; do
            in_degree[$neighbour]=$(( ${in_degree[$neighbour]} - 1 ))
            [ "${in_degree[$neighbour]}" -eq 0 ] && queue+=("$neighbour")
        done
    done

    if [ ${#result_arr[@]} -ne ${#graph_ref[@]} ]; then
        die "Circular dependency detected in spell graph"
    fi
}

# ---------------------------------------------------------------------------
# Transitive dependency staging
# ---------------------------------------------------------------------------
transitive_deps() {
    local pkg="$1"
    local -A seen=()
    local -a queue=()
    local dep d

    for dep in ${GRAPH[$pkg]:-}; do
        queue+=("$dep")
    done

    while [ ${#queue[@]} -gt 0 ]; do
        dep="${queue[0]}"
        queue=("${queue[@]:1}")
        [ -n "${seen[$dep]:-}" ] && continue
        seen[$dep]=1
        for d in ${GRAPH[$dep]:-}; do
            queue+=("$d")
        done
    done

    [ ${#seen[@]} -gt 0 ] || return 0
    printf '%s\n' "${!seen[@]}"
}

# Point pkg-config files at the package's staging directory. The files are
# installed with prefix=/usr; after staging they must resolve to the absolute
# stage so that dependent builds pick up the staged headers and libraries.
rewrite_pkgconfig() {
    local stage="$1"
    [ -d "$stage" ] || return 0
    local pc
    while IFS= read -r -d '' pc; do
        # Prefix every absolute install directory with the stage. Variables
        # that already use ${prefix} are left alone and resolve correctly.
        sed -i -E "s#^(prefix|exec_prefix|libdir|includedir|bindir|sbindir|libexecdir|datadir|sysconfdir|sharedstatedir|localstatedir|infodir|mandir|docdir|dvidir|htmldir|pdfdir|psdir|runstatedir)=/#\1=$stage/#" "$pc"
    done < <(find "$stage" -type f -name '*.pc' -print0)
}

# ---------------------------------------------------------------------------
# Build one package
# ---------------------------------------------------------------------------
build_package() {
    local pkg="$1"
    local spell="$SPELL_DIR/$pkg.spell"
    local stage="$STAGING_DIR/install/$pkg"
    local builddir="$BUILD_ROOT/$pkg"

    if is_built "$pkg"; then
        log "Already built: $pkg"
        return 0
    fi

    log "=== Building $pkg (dietlibc) ==="
    # Start from a clean stage so a previous failed build cannot leak files
    # (or pkg-config files) into this one.
    rm -rf "$stage"
    mkdir -p "$stage" "$builddir"

    # Collect the staged prefixes of all transitive dependencies so the build
    # can find headers, libraries, pkg-config files and generated tools.
    local dep
    local -a dep_stages=()
    while IFS= read -r dep; do
        [ -n "$dep" ] || continue
        [ -d "$STAGING_DIR/install/$dep" ] && dep_stages+=("$STAGING_DIR/install/$dep")
    done < <(transitive_deps "$pkg")

    (
        set -e
        # Reset metadata for this spell.
        PACKAGE_NAME="$pkg"; PACKAGE_VERSION=""; PACKAGE_RELEASE="1"
        DEPENDENCIES=(); EXTERNAL_DEPENDENCIES=(); FALLBACK_ALLOWED=0
        LANGUAGE="c"; SOURCE_URL=""; SOURCE_HASH=""; USE_DIETCOMPAT=0
        BUILD_STYLE="configure"

        # shellcheck disable=SC1090
        source "$spell"

        if [ -n "$SOURCE_URL" ]; then
            local archive
            archive=$(fetch_source "$SOURCE_URL" "${SOURCE_HASH:-}")
            extract_source "$archive" "$builddir/src"
            cd "$builddir/src"
        else
            cd "$builddir"
        fi

        export DESTDIR="$stage"
        export STAGING_DIR="$stage"
        export DIETHOME="$DIET_PREFIX"
        export PATH="$DIET_PREFIX/bin:$PATH"
        export MAKEFLAGS="-j$JOBS"

        # Build the dependency search paths once. Every dep is installed into
        # its own stage with a /usr prefix.
        local dep_flags="" dep_pc="" dep_bins=""
        local dep_stage inc lib pc
        for dep_stage in "${dep_stages[@]}"; do
            for inc in "$dep_stage/usr/include" "$dep_stage/include"; do
                [ -d "$inc" ] && dep_flags="$dep_flags -I$inc"
            done
            for lib in "$dep_stage/usr/lib" "$dep_stage/usr/lib64" \
                       "$dep_stage/lib" "$dep_stage/lib64"; do
                [ -d "$lib" ] && dep_flags="$dep_flags -L$lib"
            done
            for pc in "$dep_stage/usr/lib/pkgconfig" \
                      "$dep_stage/usr/lib64/pkgconfig" \
                      "$dep_stage/usr/share/pkgconfig" \
                      "$dep_stage/lib/pkgconfig"; do
                [ -d "$pc" ] && dep_pc="${dep_pc:+$dep_pc:}$pc"
            done
            [ -d "$dep_stage/usr/bin" ] && dep_bins="$dep_bins:$dep_stage/usr/bin"
        done

        [ -n "$dep_bins" ] && export PATH="$PATH$dep_bins"
        [ -n "$dep_pc" ] && export PKG_CONFIG_PATH="$dep_pc${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
        unset PKG_CONFIG_SYSROOT_DIR

        # Remember the caller's flags before appending the staging paths. Some
        # packages (libpng's pnglibconf generator) only honour CPPFLAGS, and a
        # fallback build must not inherit flags appended twice.
        local base_cflags="${CFLAGS:--O2 -static -march=x86-64}"
        local base_cppflags="${CPPFLAGS:-}"
        local base_ldflags="${LDFLAGS:--static}"

        build_with() {
            local cc="$1"
            export CC="$cc"
            export CFLAGS="$base_cflags$dep_flags"
            export CPPFLAGS="$base_cppflags$dep_flags"
            export LDFLAGS="$base_ldflags$dep_flags"
            # The compatibility shim supplies a handful of glibc APIs that
            # dietlibc lacks. It is only linked for the dietlibc toolchain.
            case "$(basename "$cc")" in
                dietgcc|dietcc)
                    if [ "${USE_DIETCOMPAT:-0}" = "1" ]; then
                        export LDFLAGS="$LDFLAGS -ldietcompat -lm"
                    fi
                    ;;
            esac
            if [ "$LANGUAGE" = "c++" ]; then
                export CXX="${CXX:-g++}"
            fi
            if declare -F build >/dev/null; then
                build || return $?
            else
                die "$pkg has no build() function"
            fi
            if declare -F install >/dev/null; then
                install || return $?
            fi
        }

        if build_with "$DIETGCC"; then
            log "$pkg built with dietlibc"
        else
            if [ "${FALLBACK_ALLOWED:-0}" = "1" ]; then
                warn "$pkg failed with dietlibc – retrying with standard libc (allowed by spell)"
                rm -rf "$builddir/src"
                if [ -n "$SOURCE_URL" ]; then
                    local archive
                    archive=$(fetch_source "$SOURCE_URL" "${SOURCE_HASH:-}")
                    extract_source "$archive" "$builddir/src"
                    cd "$builddir/src"
                fi
                build_with "gcc"
                log "$pkg built with standard libc fallback"
            else
                die "$pkg failed with dietlibc and FALLBACK_ALLOWED is not set"
            fi
        fi

        rewrite_pkgconfig "$stage"
        touch "$stage/.built"
    )
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    local force=0 dry_run=0 world=0
    local packages=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --list)
                for f in "$SPELL_DIR"/*.spell; do
                    [ -e "$f" ] || continue
                    basename "$f" .spell
                done | sort
                exit 0
                ;;
            --force)
                force=1
                shift
                ;;
            --dry-run|--plan)
                dry_run=1
                shift
                ;;
            --world)
                world=1
                shift
                ;;
            --help|-h)
                sed -n '2,24p' "$0"
                exit 0
                ;;
            -*)
                die "Unknown option: $1"
                ;;
            *)
                packages+=("$1")
                shift
                ;;
        esac
    done

    if [ "$world" = "1" ]; then
        local world_file="${WORLD_ORDER:-$LEANUX_ROOT/build/world.order}"
        [ -f "$world_file" ] || die "World order file not found: $world_file"
        local line word
        while IFS= read -r line; do
            line="${line%%#*}"
            for word in $line; do
                packages+=("$word")
            done
        done < "$world_file"
    fi

    [ ${#packages[@]} -gt 0 ] || die "Usage: $0 <spell> [spell ...]"

    # Resolve the full dependency graph before touching the build host.
    local pkg
    for pkg in "${packages[@]}"; do
        [ -f "$SPELL_DIR/$pkg.spell" ] || die "Spell not found: $SPELL_DIR/$pkg.spell"
        resolve_deps "$pkg" ""
    done

    local order=()
    topological_sort GRAPH order

    log "Build order: ${order[*]}"
    if [ "$dry_run" = "1" ]; then
        printf '%s\n' "${order[@]}"
        exit 0
    fi

    ensure_dietlibc
    mkdir -p "$STAGING_DIR" "$SOURCES_DIR" "$BUILD_ROOT"

    if [ "$force" = "1" ]; then
        local p
        for p in "${packages[@]}"; do
            rm -rf "$STAGING_DIR/install/$p" "$BUILD_ROOT/$p"
        done
    fi

    for pkg in "${order[@]}"; do
        build_package "$pkg"
    done

    log "All requested spells cast successfully."
}

main "$@"

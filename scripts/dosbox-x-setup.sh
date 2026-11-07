#!/usr/bin/env bash
#
# Download and build the pinned DOSBox-X that runs the DOS build.
#
#   scripts/dosbox-x-setup.sh            set up DOSBox-X for this host (x86-64 Linux)
#   scripts/dosbox-x-setup.sh --print    print the folder DOSBox-X is (or would be) installed in, and stop; its
#                                        dosbox-x is in bin/
#   scripts/dosbox-x-setup.sh --pack DIR set up as usual, then pack the installation into DIR as the talonius/dosbox-x
#                                        fork's goldbox release publishes it (scripts/toolchain-release.sh)
#
# build/toolchain (or the file TOOLCHAIN_FILE names) selects the version, dosbox_x=<version>, a DOSBox-X release
# (tag dosbox-x-v<version>), and the recipe (recipe=N), the revision of how this script builds it. It installs below
# $FPC_PREFIX/dosbox-x-<version>, using ~/fpc as the default prefix, beside fpc-setup.sh's and sdl3-setup.sh's builds.
# With DOSBOX_X_RELEASES (or TOOLCHAIN_RELEASES) set, a published build, dosbox-x-<version>-r<recipe>-<host>.tar.zst,
# is downloaded instead of compiled. DOSBOX_X_GIT_URL builds from a mirror of DOSBox-X's repository.
#
# The build is the one the DOS build needs and no more: DOSBox-X's own static SDL 1.x (vs/sdl), and no FFmpeg capture,
# FluidSynth, MT-32, SLIRP or SDL_net. It runs headless with SDL_VIDEODRIVER=dummy. A published build links against
# the shared libraries of the system it was built on (Ubuntu 24.04 for the goldbox release); after unpacking one,
# this script names any of them this computer lacks.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
toolchain="${TOOLCHAIN_FILE:-$root/build/toolchain}"
version="$(sed -n 's/^dosbox_x=\([0-9.]*\).*/\1/p' "$toolchain" 2> /dev/null | head -n 1)"
[ -n "$version" ] || { echo "dosbox-x-setup.sh: $toolchain has no dosbox_x=<version> line." >&2; exit 1; }
recipe="$(sed -n 's/^recipe=\([0-9]*\).*/\1/p' "$toolchain" 2> /dev/null | head -n 1)"
recipe="${recipe:-1}"
prefix_root="${FPC_PREFIX:-$HOME/fpc}"
prefix="$prefix_root/dosbox-x-$version"
tag="dosbox-x-$version-r$recipe"

pack=""
case "${1:-}" in
    --print) echo "$prefix"; exit 0 ;;
    --pack) [ $# -eq 2 ] || { echo "dosbox-x-setup.sh: --pack needs the folder to pack into." >&2; exit 2; }
            pack="$2" ;;
    "") ;;
    *) echo "dosbox-x-setup.sh: unknown option $1 (the options are --print and --pack DIR)" >&2; exit 2 ;;
esac
. "$(dirname "${BASH_SOURCE[0]}")/toolchain-release.sh"

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) host=x86_64-linux ;;
    *) echo "dosbox-x-setup.sh: no recipe for this host; install DOSBox-X $version or later yourself." >&2; exit 1 ;;
esac
file="$tag-$host.tar.zst"

# Name the shared libraries dosbox-x needs that this computer lacks.
check_libs() {
    local missing
    missing="$(ldd "$prefix/bin/dosbox-x" 2> /dev/null | awk '/not found/ { print $1 }' | tr '\n' ' ')"
    if [ -n "$missing" ]; then
        echo "dosbox-x-setup.sh: dosbox-x needs shared libraries this computer lacks: $missing" >&2
        return 1
    fi
}

finish() {
    if [ -n "$pack" ]; then
        release_pack "$prefix_root" "$(basename "$prefix")" "$file" "$pack"
        echo "dosbox-x-setup.sh: packed $pack/$file"
    fi
    exit 0
}

stamp="$prefix/.complete"
if [ -f "$stamp" ]; then
    echo "dosbox-x-setup.sh: DOSBox-X $version is already in $prefix"
    finish
fi

# --- a published build --------------------------------------------------------------------------

base="$(release_base DOSBOX_X_RELEASES "$tag")"
if release_fetch "$base" "$file" "$prefix_root"; then
    check_libs || exit 1
    touch "$stamp"
    echo "dosbox-x-setup.sh: DOSBox-X $version installed in $prefix from $base"
    finish
fi
release_missing "DOSBox-X $version" "$base" "$file"

# --- build it -----------------------------------------------------------------------------------

problems=()
for tool in git make gcc g++ autoconf automake pkg-config; do
    command -v "$tool" > /dev/null 2>&1 || problems+=("$tool is not on PATH.")
done
if [ ${#problems[@]} -gt 0 ]; then
    echo "dosbox-x-setup.sh: cannot build DOSBox-X. Fix these first:" >&2
    printf '  - %s\n' "${problems[@]}" >&2
    exit 1
fi

cache="$prefix_root/cache"
mkdir -p "$cache"
jobs="$(getconf _NPROCESSORS_ONLN 2> /dev/null || echo 4)"
source="$cache/dosbox-x-$version"
if [ ! -f "$source/configure.ac" ]; then
    echo "dosbox-x-setup.sh: fetching DOSBox-X $version..."
    rm -rf "$source"
    git init -q "$source"
    git -C "$source" fetch -q --depth 1 "${DOSBOX_X_GIT_URL:-https://github.com/joncampbell123/dosbox-x.git}" \
        "refs/tags/dosbox-x-v$version"
    git -C "$source" checkout -q FETCH_HEAD
fi

log="$cache/build-dosbox-x-$version.log"
: > "$log"
echo "dosbox-x-setup.sh: building DOSBox-X $version (log: $log)..."
{
    (cd "$source/vs/sdl" && ./build-dosbox.sh) \
    && (cd "$source" && ./autogen.sh) \
    && (cd "$source" && ./configure --prefix="$prefix" --disable-avcodec --disable-libfluidsynth --disable-mt32 \
            --disable-libslirp --disable-sdlnet) \
    && make -C "$source" -j "$jobs" \
    && make -C "$source" install
} >> "$log" 2>&1 \
    || { echo "dosbox-x-setup.sh: the build failed; see $log" >&2; tail -n 30 "$log" >&2; exit 1; }

"$prefix/bin/dosbox-x" --version > /dev/null 2>&1 || true
check_libs || exit 1
touch "$stamp"
echo "dosbox-x-setup.sh: DOSBox-X $version installed in $prefix"
finish

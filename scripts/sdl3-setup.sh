#!/usr/bin/env bash
#
# Download and build the pinned SDL3 libraries used by native builds.
#
#   scripts/sdl3-setup.sh            build SDL3 for this host and the cross targets fpc-setup.sh builds compilers for
#   scripts/sdl3-setup.sh --print    print the folder SDL3 is (or would be) installed in, and stop
#   scripts/sdl3-setup.sh --pack DIR set up as usual, then pack each target into DIR as the talonius/SDL fork's
#                                    goldbox release publishes it (scripts/toolchain-release.sh)
#
# build/toolchain (or the file TOOLCHAIN_FILE names) selects the SDL version and the recipe (recipe=N), the revision
# of how this script builds it. Each target installs below $FPC_PREFIX/sdl3-<version>/<target>, using ~/fpc as the
# default prefix. Static libraries keep the Linux and macOS game builds self-contained:
#   x86_64-linux    lib/libSDL3.a
#   i386-linux      lib/libSDL3.a, when gcc -m32 links (a 32-bit C library is installed: Arch's lib32-glibc, Debian's
#                   gcc-multilib); otherwise it is left out, and said so
#   i386-win32      bin/SDL3.dll, which the game loads and the package ships; lib/libSDL3.a (mingw) is unused
#   x86_64-win64    bin/SDL3.dll, likewise
#   aarch64-darwin  lib/libSDL3.a (on an Apple Silicon Mac; there is no Intel Mac target)
# A target already built is skipped. With SDL3_RELEASES (or TOOLCHAIN_RELEASES) set, a target not yet built is
# downloaded first, as sdl3-<version>-r<recipe>-<target>.tar.zst from the talonius/SDL fork's goldbox release (see
# scripts/toolchain-release.sh), and only the rest are compiled. SDL_GIT_URL
# builds from a mirror of SDL's repository, at tag release-<version>, instead of the release tarball from GitHub.
#
# The build requires CMake and Ninja. Linux uses the system packages. On macOS, missing tools are downloaded at the
# pinned versions, verified against their published SHA-256 sums, and stored under $FPC_PREFIX/tools/bin. Nothing
# outside FPC_PREFIX is changed.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
toolchain="${TOOLCHAIN_FILE:-$root/build/toolchain}"
version="$(sed -n 's/^sdl3=\([0-9.]*\).*/\1/p' "$toolchain" 2> /dev/null | head -n 1)"
[ -n "$version" ] || { echo "sdl3-setup.sh: $toolchain has no sdl3=<version> line." >&2; exit 1; }
recipe="$(sed -n 's/^recipe=\([0-9]*\).*/\1/p' "$toolchain" 2> /dev/null | head -n 1)"
recipe="${recipe:-1}"
prefix_root="${FPC_PREFIX:-$HOME/fpc}"
prefix="$prefix_root/sdl3-$version"
tag="sdl3-$version-r$recipe"

pack=""
case "${1:-}" in
    --print) echo "$prefix"; exit 0 ;;
    --pack) [ $# -eq 2 ] || { echo "sdl3-setup.sh: --pack needs the folder to pack into." >&2; exit 2; }
            pack="$2" ;;
    "") ;;
    *) echo "sdl3-setup.sh: unknown option $1 (the options are --print and --pack DIR)" >&2; exit 2 ;;
esac
. "$(dirname "${BASH_SOURCE[0]}")/toolchain-release.sh"

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) targets=(x86_64-linux i386-win32 x86_64-win64) ;;
    Darwin-arm64) targets=(aarch64-darwin) ;;
    *) echo "sdl3-setup.sh: no recipe for this host." >&2; exit 1 ;;
esac
if [ "${targets[0]}" = x86_64-linux ]; then
    if echo 'int main(void) { return 0; }' | gcc -m32 -x c - -o /dev/null > /dev/null 2>&1; then
        targets+=(i386-linux)
    else
        echo "sdl3-setup.sh: no 32-bit C library (gcc -m32 does not link), so no SDL3 for i386-linux." >&2
    fi
fi

# Pack every target when asked to, and stop.
finish() {
    local t
    if [ -n "$pack" ]; then
        for t in "${targets[@]}"; do
            release_pack "$prefix_root" "sdl3-$version/$t" "$tag-$t.tar.zst" "$pack"
            echo "sdl3-setup.sh: packed $pack/$tag-$t.tar.zst"
        done
    fi
    exit 0
}

# Download the targets not yet built that have a published build.
missing=0
base="$(release_base SDL3_RELEASES "$tag")"
for t in "${targets[@]}"; do
    [ -f "$prefix/$t/lib/libSDL3.a" ] && continue
    if release_fetch "$base" "$tag-$t.tar.zst" "$prefix_root"; then
        echo "sdl3-setup.sh: SDL3 $version for $t installed in $prefix/$t from $base"
    else
        release_missing "SDL3 $version for $t" "$base" "$tag-$t.tar.zst"
        missing=1
    fi
done
# Every target already built needs neither the tools nor the source, which a CI image deletes once it has built them.
if [ $missing -eq 0 ]; then
    echo "sdl3-setup.sh: SDL3 $version is in $prefix (${targets[*]})"
    finish
fi

# The Forgejo macOS runner has neither tool on PATH, so install private copies when needed.
if [ "$(uname -s)" = Darwin ]; then
    bin="$prefix_root/tools/bin"
    cmake_sha=330b9514f5112e5ed4fb08b8b05803b776fd9b539a6ae12927d14dcc0ee2ba8d
    ninja_sha=89a287444b5b3e98f88a945afa50ce937b8ffd1dcc59c555ad9b1baf855298c9
    export PATH="$bin:$PATH"
    mkdir -p "$bin" "$prefix_root/tools/dl"
    if ! command -v cmake > /dev/null 2>&1; then
        echo "sdl3-setup.sh: downloading cmake 3.31.6..."
        dl="$prefix_root/tools/dl/cmake.tgz"
        curl -fsSL -o "$dl" \
            https://github.com/Kitware/CMake/releases/download/v3.31.6/cmake-3.31.6-macos-universal.tar.gz
        [ "$(shasum -a 256 "$dl" | cut -d' ' -f1)" = "$cmake_sha" ] \
            || { echo "sdl3-setup.sh: the cmake download does not match its SHA-256." >&2; exit 1; }
        tar -xzf "$dl" -C "$prefix_root/tools"
        ln -sf "$prefix_root/tools/cmake-3.31.6-macos-universal/CMake.app/Contents/bin/cmake" "$bin/cmake"
    fi
    if ! command -v ninja > /dev/null 2>&1; then
        echo "sdl3-setup.sh: downloading ninja 1.12.1..."
        dl="$prefix_root/tools/dl/ninja.zip"
        curl -fsSL -o "$dl" https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-mac.zip
        [ "$(shasum -a 256 "$dl" | cut -d' ' -f1)" = "$ninja_sha" ] \
            || { echo "sdl3-setup.sh: the ninja download does not match its SHA-256." >&2; exit 1; }
        unzip -oq "$dl" -d "$bin"
        chmod +x "$bin/ninja"
    fi
fi

problems=()
for tool in curl tar cmake ninja; do
    command -v "$tool" > /dev/null 2>&1 || problems+=("$tool is not on PATH.")
done
for t in "${targets[@]}"; do
    case "$t" in
        i386-win32) command -v i686-w64-mingw32-gcc > /dev/null 2>&1 \
            || problems+=("i686-w64-mingw32-gcc is not on PATH: install mingw-w64 (Arch: mingw-w64-gcc).") ;;
        x86_64-win64) command -v x86_64-w64-mingw32-gcc > /dev/null 2>&1 \
            || problems+=("x86_64-w64-mingw32-gcc is not on PATH: install mingw-w64 (Arch: mingw-w64-gcc).") ;;
    esac
done
if [ ${#problems[@]} -gt 0 ]; then
    echo "sdl3-setup.sh: cannot build SDL3. Fix these first:" >&2
    printf '  - %s\n' "${problems[@]}" >&2
    exit 1
fi

cache="$prefix_root/cache"
mkdir -p "$cache"
source="$cache/SDL3-$version"
if [ ! -f "$source/CMakeLists.txt" ]; then
    echo "sdl3-setup.sh: downloading SDL3 $version..."
    rm -rf "$source" "$source.download"
    mkdir -p "$source.download"
    if [ -n "${SDL_GIT_URL:-}" ]; then
        git init -q "$source.download"
        git -C "$source.download" fetch -q --depth 1 "$SDL_GIT_URL" "refs/tags/release-$version"
        git -C "$source.download" checkout -q FETCH_HEAD
        mv "$source.download" "$source"
    else
        curl -fsSL "https://github.com/libsdl-org/SDL/releases/download/release-$version/SDL3-$version.tar.gz" \
            -o "$source.download/SDL3.tar.gz"
        tar -xzf "$source.download/SDL3.tar.gz" -C "$source.download"
        mv "$source.download/SDL3-$version" "$source"
        rm -rf "$source.download"
    fi
fi

# Build both forms. Linux and macOS use the static library; Windows ships the DLL.
common=(-G Ninja -DCMAKE_BUILD_TYPE=Release -DSDL_STATIC=ON -DSDL_SHARED=ON -DSDL_TEST_LIBRARY=OFF
        -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF -DSDL_INSTALL_DOCS=OFF)

for t in "${targets[@]}"; do
    if [ -f "$prefix/$t/lib/libSDL3.a" ]; then
        echo "sdl3-setup.sh: SDL3 $version for $t is already in $prefix/$t"
        continue
    fi
    build="$cache/build-SDL3-$version-$t"
    log="$build.log"
    rm -rf "$build"
    extra=()
    case "$t" in
        i386-win32) extra=(-DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER=i686-w64-mingw32-gcc
                           -DCMAKE_CXX_COMPILER=i686-w64-mingw32-g++
                           -DCMAKE_RC_COMPILER=i686-w64-mingw32-windres) ;;
        x86_64-win64) extra=(-DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc
                             -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++
                             -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres) ;;
        i386-linux) extra=(-DCMAKE_C_FLAGS=-m32 -DCMAKE_CXX_FLAGS=-m32 -DCMAKE_SYSTEM_PROCESSOR=i686) ;;
        aarch64-darwin) extra=(-DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0) ;;
    esac
    echo "sdl3-setup.sh: building SDL3 $version for $t (log: $log)..."
    { cmake -S "$source" -B "$build" "${common[@]}" "${extra[@]}" -DCMAKE_INSTALL_PREFIX="$prefix/$t" \
        && cmake --build "$build" \
        && cmake --install "$build"; } > "$log" 2>&1 \
        || { echo "sdl3-setup.sh: the $t build failed; see $log" >&2; tail -n 20 "$log" >&2; exit 1; }
done

echo "sdl3-setup.sh: SDL3 $version installed in $prefix (${targets[*]})"
finish

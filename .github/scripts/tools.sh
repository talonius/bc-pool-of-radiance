#!/usr/bin/env bash
#
# Set up a GitHub-hosted runner for one of the build workflow's jobs, from the toolchains' goldbox releases.
#
#   .github/scripts/tools.sh dos               DOSBox-X, and the DOS toolchains as TOOLS
#   .github/scripts/tools.sh native TARGET     Free Pascal and SDL3 (and MinGW, or Wine, when TARGET needs them)
#   .github/scripts/tools.sh macos             Free Pascal and SDL3 on an Apple Silicon runner
#
# Nothing is compiled here: each tool comes from a goldbox release built by that repository's own CI, and the setup
# scripts run with TOOLCHAIN_FETCH_ONLY=1, so pins in build/toolchain with no published build stop the job.
#   talonius/fpc        public   Free Pascal, fpc-<branch>-<commit>-r<recipe>-<host>.tar.zst
#   talonius/SDL        public   SDL3, sdl3-<version>-r<recipe>-<target>.tar.zst
#   talonius/dosbox-x   public   DOSBox-X, dosbox-x-<version>-r<recipe>-x86_64-linux.tar.zst
#   talonius/goldbox-re-tools  private  the proprietary DOS toolchains, drive_d.tar.zst; read with the repository
#                       secret GOLDBOX_RE_TOOLS_TOKEN, a fine-grained token with read access to that repository's contents
#
# FPC_PREFIX (set by the workflow) is where the toolchains go. Variables later steps need are written to GITHUB_ENV and
# GITHUB_PATH.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
releases=https://github.com/talonius
export TOOLCHAIN_FETCH_ONLY=1
export FPC_RELEASES="$releases/fpc/releases/download/goldbox"
export SDL3_RELEASES="$releases/SDL/releases/download/goldbox"
export DOSBOX_X_RELEASES="$releases/dosbox-x/releases/download/goldbox"
: "${FPC_PREFIX:?FPC_PREFIX is not set: the workflow sets it}"

apt_install() {
    sudo apt-get update -q
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends "$@"
}

case "${1:-}" in
    dos)
        # DOSBox-X links these; most are on the runner image already. dosbox-x-setup.sh names any that are missing.
        apt_install zstd libpng16-16t64 zlib1g libfreetype6 libasound2t64 libncursesw6 libx11-6 libxext6 \
            libxkbfile1 libxrandr2
        "$root/scripts/dosbox-x-setup.sh"
        echo "$("$root/scripts/dosbox-x-setup.sh" --print)/bin" >> "$GITHUB_PATH"

        : "${GOLDBOX_RE_TOOLS_TOKEN:?the repository secret GOLDBOX_RE_TOOLS_TOKEN is not set (see .github/scripts/tools.sh)}"
        dl="$(mktemp -d)"
        GH_TOKEN="$GOLDBOX_RE_TOOLS_TOKEN" gh release download goldbox -R talonius/goldbox-re-tools -D "$dl" \
            -p drive_d.tar.zst -p SHA256SUMS
        (cd "$dl" && sha256sum --check --strict SHA256SUMS)
        tar --zstd -xf "$dl/drive_d.tar.zst" -C "$RUNNER_TEMP"
        rm -rf "$dl"
        echo "TOOLS=$RUNNER_TEMP/drive_d" >> "$GITHUB_ENV"
        echo "tools.sh: DOSBox-X $(dosbox_x="$("$root/scripts/dosbox-x-setup.sh" --print)/bin/dosbox-x"; \
            "$dosbox_x" --version 2>&1 | head -n 1), TOOLS=$RUNNER_TEMP/drive_d ($(ls "$RUNNER_TEMP/drive_d" | wc -l) folders)"
        ;;
    native)
        target="${2:?give the target, for example: tools.sh native x86_64-win64}"
        pkgs=(zstd)
        case "$target" in
            i386-linux) pkgs+=(gcc-multilib) ;;
            i386-win32|x86_64-win64) pkgs+=(mingw-w64) ;;
        esac
        apt_install "${pkgs[@]}"
        case "$target" in
            # build-native.sh --test runs the Windows tests under Wine.
            i386-win32|x86_64-win64)
                sudo dpkg --add-architecture i386
                apt_install wine wine64 wine32:i386
                ;;
        esac
        "$root/scripts/fpc-setup.sh"
        "$root/scripts/sdl3-setup.sh"
        ;;
    macos)
        # release_fetch needs zstd and sha256sum; Homebrew's coreutils names it gsha256sum outside gnubin.
        brew install zstd coreutils
        export PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"
        echo "$(brew --prefix coreutils)/libexec/gnubin" >> "$GITHUB_PATH"
        "$root/scripts/fpc-setup.sh"
        "$root/scripts/sdl3-setup.sh"
        ;;
    *)
        echo "tools.sh: say which job: dos, native TARGET or macos" >&2
        exit 2
        ;;
esac

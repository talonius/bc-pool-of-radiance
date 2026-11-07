#!/usr/bin/env bash
#
# Create or update a GitHub release and attach its DOS archive from dist/.
#
#   .github/scripts/release.sh v1.4
#
# The GitHub port of .forgejo/scripts/release.sh; the workflow supplies GH_TOKEN and GH_REPO. The notes list the
# changes since the last production release the tag descends from (#1105), then the checksums, as one block between
# <!-- ASSET --> lines (.forgejo/scripts/notes.sh): a rerun replaces only that block, so notes written on the release
# page are kept.
#
# The tag latest is the rolling pre-release of main, published after every push to main. Its notes are rewritten
# whole, and every other file is removed once the new archive is attached, so a native or macOS build that fails this
# time leaves its file missing rather than the previous one's.
#
# GitHub release assets must have unique names, so a replacement is uploaded with --clobber, which removes the old
# file first.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../../.forgejo/scripts/notes.sh"

tag="$1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
asset="pool-of-radiance-$tag-dos.zip"
zip="$root/dist/$asset"
: "${GH_REPO:?GH_REPO is not set: the workflow sets it}"

[ -f "$zip" ] || { echo "release.sh: dist/$asset is missing; run package.sh first." >&2; exit 1; }

rolling=0
name="Pool of Radiance $tag"
[ "$tag" != latest ] || { rolling=1; name="Pool of Radiance (latest build of main)"; }

# The newest production release that is an ancestor of the tag, which the change list counts from.
base="$(gh api "repos/$GH_REPO/releases?per_page=100" \
    --jq ".[] | select((.draft or .prerelease or .tag_name == \"$tag\") | not) | .tag_name" \
    | while read -r t; do
        if git -C "$root" merge-base --is-ancestor "$t" "$tag" 2> /dev/null; then echo "$t"; break; fi
    done)"

section=""
if [ $rolling -eq 1 ]; then
    printf -v section '%s %s (%s), rebuilt after every change to main; not a production release.\n\n' \
        'A pre-release of main at' "$(git -C "$root" rev-parse --short=7 HEAD)" \
        "$(git -C "$root" log -1 --format=%cs HEAD)"
fi
if [ -n "$base" ]; then
    printf -v section '%sChanges since %s (%s commits):\n\n%s\n\n' "$section" "$base" \
        "$(git -C "$root" rev-list --count --first-parent "$base..$tag")" \
        "$(cd "$root" && .forgejo/scripts/changes.sh "$base" "$tag")"
fi
begin="<!-- $asset -->"
end="<!-- /$asset -->"
block="$(printf '%s\n%sSTART.EXE and GAME.OVR built from the source tagged %s.\n\nSHA-256:\n\n```\n%s\n%s\n```\n%s' \
    "$begin" "$section" "$tag" "$(cd "$root/obj" && sha256sum START.EXE GAME.OVR)" \
    "$(cd "$root/dist" && sha256sum "$asset")" "$end")"
notes="$block"

if body="$(gh release view "$tag" --json body --jq .body 2> /dev/null)"; then
    if [ $rolling -eq 0 ]; then
        notes="$(printf '%s\n' "$body" | notes_put "$begin" "$end" "$block")"
    fi
    gh release upload "$tag" "$zip" --clobber
    echo "release.sh: attached $asset to the release for $tag"
    if [ $rolling -eq 1 ]; then
        gh release edit "$tag" --title "$name" --prerelease --notes "$notes" > /dev/null
        gh release view "$tag" --json assets --jq ".assets[].name | select(. != \"$asset\")" \
            | while read -r old; do
                gh release delete-asset "$tag" "$old" --yes
                echo "release.sh: removed the earlier $old"
            done
    else
        gh release edit "$tag" --notes "$notes" > /dev/null
    fi
    echo "release.sh: updated the notes of the release for $tag"
else
    flags=()
    [ $rolling -eq 0 ] || flags=(--prerelease --latest=false)
    gh release create "$tag" "$zip" --verify-tag --title "$name" --notes "$notes" "${flags[@]}"
    echo "release.sh: created the release for $tag with $asset"
fi

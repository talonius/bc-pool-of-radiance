#!/usr/bin/env bash
#
# Attach another file to an existing GitHub release.
#
#   .github/scripts/release-asset.sh v1.4 dist/pool-of-radiance-v1.4-macos.zip
#
# The GitHub port of .forgejo/scripts/release-asset.sh; the workflow supplies GH_TOKEN and GH_REPO. The file replaces
# an earlier one of the same name, and its checksum block in the release notes is replaced in place (notes.sh).

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../../.forgejo/scripts/notes.sh"

tag="$1"
file="$2"
asset="$(basename "$file")"
: "${GH_REPO:?GH_REPO is not set: the workflow sets it}"

[ -f "$file" ] || { echo "release-asset.sh: $file is missing." >&2; exit 1; }
body="$(gh release view "$tag" --json body --jq .body)" \
    || { echo "release-asset.sh: no release for $tag: release.sh makes it first." >&2; exit 1; }

gh release upload "$tag" "$file" --clobber
echo "release-asset.sh: attached $asset to the release for $tag"

sum="$(cd "$(dirname "$file")" && sha256sum "$asset")"
begin="<!-- $asset -->"
end="<!-- /$asset -->"
notes="$(printf '%s\n' "$body" \
    | notes_put "$begin" "$end" "$(printf '%s\n%s, SHA-256:\n\n```\n%s\n```\n%s' "$begin" "$asset" "$sum" "$end")")"
gh release edit "$tag" --notes "$notes" > /dev/null
echo "release-asset.sh: added $asset's SHA-256 to the notes of the release for $tag"

#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
repo="${OPENRIGHT_GITHUB_REPO:-MaxTheTurtle0/OpenRight}"
publish=false
cloud=false
resume=false
notes_path=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --publish) publish=true; shift ;;
        --cloud) cloud=true; shift ;;
        --resume) resume=true; shift ;;
        --repo) repo="${2:?Missing GitHub repository}"; shift 2 ;;
        --notes) notes_path="${2:?Missing release notes file}"; shift 2 ;;
        *) printf 'Usage: %s [--publish] [--cloud [--resume]] [--repo owner/repo] [--notes file]\n' "$0" >&2; exit 2 ;;
    esac
done
if [[ -n "$(git status --porcelain)" ]]; then printf 'Commit source changes before creating a release.\n' >&2; exit 1; fi
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
build_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)"
tag="v$version"
head="$(git rev-parse HEAD)"
require_release_source() {
    [[ "$(git rev-parse HEAD)" == "$head" && -z "$(git status --porcelain)" ]] || {
        printf 'Source changed during release preparation. Restore the recorded source revision before publishing.\n' >&2; exit 1;
    }
}
if [[ "$resume" == true && "$cloud" == false ]]; then printf '%s\n' '--resume requires --cloud.' >&2; exit 2; fi
if [[ "$cloud" == false ]]; then
    OPENRIGHT_SIGN_IDENTITY="$(./scripts/sign-app.sh --resolve-release-identity)"
    export OPENRIGHT_SIGN_IDENTITY
fi
account="${OPENRIGHT_SPARKLE_ACCOUNT:-org.openright.sparkle}"
public_key="$(./scripts/sparkle-tools.sh generate_keys --account "$account" -p)"
python3 - Resources/Info.plist "$repo" "$public_key" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    info = plistlib.load(f)
expected = 'https://github.com/' + sys.argv[2] + '/releases/latest/download/appcast.xml'
if info.get('SUFeedURL') != expected:
    sys.exit('SUFeedURL must match the GitHub repository being released: ' + expected)
if info.get('SUPublicEDKey') != sys.argv[3].strip():
    sys.exit('The Sparkle Keychain account does not match the public key embedded in the app.')
PY
remote_head="$(gh api "repos/$repo/commits/$head" --jq .sha)"
[[ "$remote_head" == "$head" ]] || { printf 'Push the exact release commit before releasing.\n' >&2; exit 1; }
if tag_head="$(gh api "repos/$repo/commits/$tag" --jq .sha 2>/dev/null)"; then
    [[ "$tag_head" == "$head" ]] || { printf 'Existing tag %s points at a different commit.\n' "$tag" >&2; exit 1; }
fi
if existing_state="$(gh release view "$tag" --repo "$repo" --json isDraft --jq .isDraft 2>/dev/null)"; then
    [[ "$existing_state" == true ]] || { printf 'Release %s is already published. Increment the version instead of replacing it.\n' "$tag" >&2; exit 1; }
fi
release_check_dir="$(mktemp -d "${TMPDIR:-/tmp}/openright-release-check.XXXXXX")"
trap 'rm -rf "$release_check_dir"' EXIT
# An authenticated list returns [] for a first release. API/auth/network errors
# fail the command rather than being mistaken for an empty release history.
gh api --paginate --slurp "repos/$repo/releases?per_page=100" > "$release_check_dir/releases.json"
has_published="$(python3 - "$release_check_dir/releases.json" <<'PY'
import json,sys
pages=json.load(open(sys.argv[1]))
print('yes' if any(not r['draft'] and not r['prerelease'] for page in pages for r in page) else 'no')
PY
)"
if [[ "$has_published" == yes ]]; then
    latest_tag="$(gh api "repos/$repo/releases/latest" --jq .tag_name)"
    gh release download "$latest_tag" --repo "$repo" --pattern appcast.xml --dir "$release_check_dir"
    python3 scripts/check-release-version.py Resources/Info.plist "$release_check_dir/appcast.xml"
fi
swift test -Xswiftc -warnings-as-errors
python3 -m unittest discover -s Tests/ReleasePipelineTests
if [[ "$cloud" == true ]]; then
    cloud_args=()
    if [[ "$resume" == true ]]; then cloud_args+=(--resume); fi
    ./scripts/xcode-export.sh ${cloud_args[@]+"${cloud_args[@]}"}
    ./scripts/package.sh --notarized-app
else
    ./scripts/package.sh --release
fi
release_dir="$project_root/dist/releases/$version"
mkdir -p "$release_dir"
archive_name="OpenRight-$version-universal.zip"
cp "$project_root/dist/$archive_name" "$release_dir/$archive_name"
# A draft retry may produce a newly timestamped archive for the same version.
# Regenerate its feed entry instead of reusing an old signature.
if [[ -f "$release_dir/appcast.xml" ]]; then rm -f "$release_dir/appcast.xml"; fi
if [[ -n "$notes_path" ]]; then
    cp "$notes_path" "$release_dir/OpenRight-$version-universal.md"
else
    printf '# OpenRight %s\n\nApp switching, pinned launch shortcuts, and signed in-app updates.\n' "$version" > "$release_dir/OpenRight-$version-universal.md"
fi
./scripts/sparkle-tools.sh generate_appcast --account "$account" \
    --download-url-prefix "https://github.com/$repo/releases/download/$tag/" \
    --link "https://github.com/$repo" --embed-release-notes --maximum-deltas 0 \
    -o "$release_dir/appcast.xml" "$release_dir"
# Check the generated feed against the bytes being uploaded, not just tool exit status.
python3 - "$release_dir/appcast.xml" "$repo" "$tag" "$archive_name" "$release_dir/$archive_name" "$build_version" <<'PY'
import base64, os, sys, xml.etree.ElementTree as ET
feed, repo, tag, name, archive, build = sys.argv[1:]
ns = {'sparkle': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
items = ET.parse(feed).findall('./channel/item')
item = next((item for item in items if item.findtext('sparkle:version', namespaces=ns) == build), None)
if item is None:
    sys.exit('Appcast does not contain the current build version.')
enclosure = item.find('enclosure')
if enclosure is None or enclosure.get('url') != f'https://github.com/{repo}/releases/download/{tag}/{name}':
    sys.exit('Appcast download URL does not match the release asset.')
if enclosure.get('length') != str(os.path.getsize(archive)):
    sys.exit('Appcast size does not match the update archive.')
signature = enclosure.get('{'+ns['sparkle']+'}edSignature', '')
if len(base64.b64decode(signature, validate=True)) != 64:
    sys.exit('Appcast is missing a valid Ed25519 signature.')
print('Appcast version, URL, length, and signature structure verified.')
PY
signature="$(python3 - "$release_dir/appcast.xml" "$build_version" <<'PY'
import sys, xml.etree.ElementTree as ET
ns={'sparkle':'http://www.andymatuschak.org/xml-namespaces/sparkle'}
for item in ET.parse(sys.argv[1]).findall('./channel/item'):
    if item.findtext('sparkle:version', namespaces=ns)==sys.argv[2]:
        print(item.find('enclosure').get('{'+ns['sparkle']+'}edSignature'))
        break
PY
)"
./scripts/sparkle-tools.sh sign_update --account "$account" --verify "$release_dir/$archive_name" "$signature"
cp "$release_dir/appcast.xml" "$project_root/dist/appcast.xml"
release_notes="$release_dir/release-notes.md"
cat "$release_dir/OpenRight-$version-universal.md" > "$release_notes"
printf '\nDownload OpenRight.dmg, drag OpenRight.app to Applications, then enable Accessibility for OpenRight.\n\nBoth Apple Silicon and Intel Macs are supported, on macOS 13 or newer. OpenRight.app is Developer ID signed and Apple-notarized.\n' >> "$release_notes"
if [[ "$cloud" == true ]]; then
    printf '\nThe DMG is an unsigned container carrying the signed, notarized app. The ZIP carries the same app and is verified by Sparkle before an update is extracted.\n' >> "$release_notes"
else
    printf '\nThe disk image is also Developer ID signed and notarized.\n' >> "$release_notes"
fi
printf '\nSource commit: `%s`\n' "$head" >> "$release_notes"
if [[ "${existing_state:-}" != true ]]; then
    require_release_source
    gh release create "$tag" --repo "$repo" --target "$head" --draft --title "OpenRight $version" --notes-file "$release_notes"
else
    require_release_source
    gh release edit "$tag" --repo "$repo" --title "OpenRight $version" --notes-file "$release_notes"
fi
assets=("$project_root/dist/$archive_name" "$project_root/dist/$archive_name.sha256" \
        "$project_root/dist/OpenRight-$version-universal.dmg" "$project_root/dist/OpenRight-$version-universal.dmg.sha256" \
        "$project_root/dist/OpenRight.dmg" "$project_root/dist/OpenRight.dmg.sha256" "$release_dir/appcast.xml")
require_release_source
gh release upload "$tag" --repo "$repo" --clobber "${assets[@]}"
if [[ "$publish" == true ]]; then
    require_release_source
    gh release edit "$tag" --repo "$repo" --draft=false --latest
    printf 'Published: https://github.com/%s/releases/tag/%s\nDownload: https://github.com/%s/releases/latest/download/OpenRight.dmg\n' "$repo" "$tag" "$repo"
else
    printf 'Prepared a signed, notarized draft release: https://github.com/%s/releases/tag/%s\nRun gh release edit %s --repo %s --draft=false --latest after review to publish it.\n' "$repo" "$tag" "$tag" "$repo"
fi

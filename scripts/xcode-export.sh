#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
resume=false
if [[ "${1:-}" == --resume ]]; then resume=true; shift; fi
[[ $# -eq 0 ]] || { printf 'Usage: %s [--resume]\n' "$0" >&2; exit 2; }
[[ -z "$(git status --porcelain)" ]] || { printf 'Commit source changes before creating or resuming a releasable archive.\n' >&2; exit 1; }
source_head="$(git rev-parse HEAD)"
source_fingerprint="$(python3 scripts/source-fingerprint.py)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
archive="${OPENRIGHT_XCODE_ARCHIVE:-$project_root/dist/archives/OpenRight-$version.xcarchive}"
export_dir="$project_root/dist/xcode-export-$version"
options="$project_root/dist/XcodeExportOptions.plist"
if [[ "$resume" == false ]]; then
    [[ ! -e "$archive" ]] || { printf 'Archive already exists. Use --resume to retrieve its notarized app, or choose OPENRIGHT_XCODE_ARCHIVE for a fresh upload.\n' >&2; exit 1; }
    identity="${OPENRIGHT_DEVELOPMENT_IDENTITY:-}"
    if [[ -z "$identity" ]]; then
        identity="$(security find-identity -v -p codesigning | python3 -c '
import re,sys
items=re.findall(r"\b([0-9A-Fa-f]{40})\s+\"Apple Development:[^\"]+\"",sys.stdin.read())
if len(items)!=1:sys.exit("Set OPENRIGHT_DEVELOPMENT_IDENTITY to one Apple Development identity.")
print(items[0])')"
    fi
    OPENRIGHT_SIGN_IDENTITY="$identity" ./scripts/build.sh --universal
    [[ "$(git rev-parse HEAD)" == "$source_head" && -z "$(git status --porcelain)" && "$(python3 scripts/source-fingerprint.py)" == "$source_fingerprint" ]] || {
        printf 'Source changed while building. Start from a clean committed revision.\n' >&2; exit 1;
    }
    mkdir -p "$(dirname "$archive")"
    python3 - "$archive" "$options" "$source_head" "$source_fingerprint" <<'PY'
from pathlib import Path
import datetime, os, plistlib, re, subprocess, sys
archive, options = map(Path, sys.argv[1:3])
app = Path('dist/OpenRight.app').resolve()
details = subprocess.check_output(['codesign','--display','--verbose=4',str(app)],stderr=subprocess.STDOUT,text=True)
team = re.search(r'^TeamIdentifier=(.+)$',details,re.M).group(1)
requested_team = os.environ.get('OPENRIGHT_TEAM_ID',team)
if requested_team != team:
    sys.exit('The development certificate does not belong to OPENRIGHT_TEAM_ID.')
identity = re.search(r'^Authority=(Apple Development:.+)$',details,re.M).group(1)
info = plistlib.load(open(app/'Contents/Info.plist','rb'))
destination = archive/'Products/Applications/OpenRight.app'
destination.parent.mkdir(parents=True,exist_ok=True)
subprocess.run(['ditto',str(app),str(destination)],check=True)
metadata = {'ArchiveVersion':2,'CreationDate':datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None),
            'OpenRightSourceRevision':sys.argv[3],'OpenRightSourceFingerprint':sys.argv[4],
            'Name':'OpenRight','SchemeName':'OpenRight','ApplicationProperties':{
                'ApplicationPath':'Applications/OpenRight.app','SigningIdentity':identity,'Team':team,
                **{key:info[key] for key in ['CFBundleIdentifier','CFBundleShortVersionString','CFBundleVersion']}}}
plistlib.dump(metadata,open(archive/'Info.plist','wb'))
plistlib.dump({'method':'developer-id','destination':'upload','signingStyle':'automatic','teamID':team,'stripSwiftSymbols':True},open(options,'wb'))
PY
    if ! xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$options" \
        -exportPath "$project_root/dist/xcode-upload-$version" -allowProvisioningUpdates; then
        printf 'Xcode upload did not finish. Preserve %s and use --resume to check notarization instead of re-uploading.\n' "$archive" >&2
        exit 1
    fi
fi
[[ -d "$archive" ]] || { printf 'Archive not found: %s\n' "$archive" >&2; exit 1; }
python3 - "$archive/Info.plist" "$source_head" "$source_fingerprint" <<'PY'
import plistlib,sys
info=plistlib.load(open(sys.argv[1],'rb'))
if info.get('OpenRightSourceRevision')!=sys.argv[2] or info.get('OpenRightSourceFingerprint')!=sys.argv[3]:
    sys.exit('This archive was built from a different source revision. Restore that revision or build a new archive.')
PY
if ! xcodebuild -exportNotarizedApp -archivePath "$archive" -exportPath "$export_dir"; then
    printf 'Apple has not exported an accepted notarized app yet. Keep the archive and run %s --resume later.\n' "$0" >&2
    exit 1
fi
exported="$export_dir/OpenRight.app"
[[ "$(git rev-parse HEAD)" == "$source_head" && -z "$(git status --porcelain)" && "$(python3 scripts/source-fingerprint.py)" == "$source_fingerprint" ]] || {
    printf 'Source changed during notarization. Restore the archive source revision before resuming.\n' >&2; exit 1;
}
python3 - Resources/Info.plist "$exported/Contents/Info.plist" <<'PY'
import plistlib,sys
source,exported=[plistlib.load(open(path,'rb')) for path in sys.argv[1:]]
for key in ['CFBundleIdentifier','CFBundleVersion','CFBundleShortVersionString','SUFeedURL','SUPublicEDKey','SUVerifyUpdateBeforeExtraction']:
    if source.get(key)!=exported.get(key):
        sys.exit('Exported archive differs from current release configuration: '+key)
PY
./scripts/sign-app.sh --verify-release "$exported"
xcrun stapler validate "$exported"
spctl --assess --type execute --verbose=2 "$exported"
# Replace only generated build output after the exported bundle has passed all checks.
rm -rf "$project_root/dist/OpenRight.app"
ditto "$exported" "$project_root/dist/OpenRight.app"
printf 'Cloud-signed, notarized app ready: %s/dist/OpenRight.app\n' "$project_root"

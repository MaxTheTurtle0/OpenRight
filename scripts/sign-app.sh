#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

verify_universal() {
    python3 - "$1/Contents/MacOS/OpenRight" <<'PY'
import subprocess, sys
architectures = set(subprocess.check_output(['/usr/bin/lipo', '-archs', sys.argv[1]], text=True).split())
if not {'arm64', 'x86_64'} <= architectures:
    sys.exit('Universal releases require both arm64 and x86_64 executable slices.')
PY
}

resolve_release_identity() {
    security find-identity -v -p codesigning | python3 -c '
import os, re, sys
identities = re.findall(r"\b([0-9A-Fa-f]{40})\s+\"([^\"]+)\"", sys.stdin.read())
requested = os.environ.get("OPENRIGHT_SIGN_IDENTITY", "")
choices = [(sha, name) for sha, name in identities if name.startswith("Developer ID Application:") and (not requested or requested.lower() == sha.lower() or requested == name)]
if len(choices) != 1:
    sys.exit("Set OPENRIGHT_SIGN_IDENTITY to the exact name or SHA-1 of one valid Developer ID Application identity with its private key.")
print(choices[0][0])'
}

validate_configuration() {
    python3 - "$1/Contents/Info.plist" <<'PY'
import base64, plistlib, re, sys
from urllib.parse import urlsplit
with open(sys.argv[1], 'rb') as f:
    info = plistlib.load(f)
feed = urlsplit(info.get('SUFeedURL', ''))
if feed.scheme != 'https' or not feed.hostname or feed.username or feed.password or feed.fragment:
    sys.exit('A valid HTTPS SUFeedURL is required for releases.')
try:
    public_key = base64.b64decode(info.get('SUPublicEDKey', ''), validate=True)
except Exception:
    sys.exit('SUPublicEDKey must be a base64 Ed25519 public key.')
if len(public_key) != 32:
    sys.exit('A 32-byte Sparkle public key is required for releases.')
if not re.fullmatch(r'[0-9]+(?:\.[0-9]+){0,2}', str(info.get('CFBundleShortVersionString', ''))):
    sys.exit('CFBundleShortVersionString must be a numeric release version.')
if not re.fullmatch(r'[0-9]+(?:\.[0-9]+){0,2}', str(info.get('CFBundleVersion', ''))):
    sys.exit('CFBundleVersion must be an incrementing numeric build version.')
if info.get('SUVerifyUpdateBeforeExtraction') is not True:
    sys.exit('Release updates must be verified before extraction.')
PY
}

verify_release() {
    local app="$1"
    validate_configuration "$app"
    codesign --verify --deep --strict "$app"
    local details
    details="$(codesign --display --verbose=4 "$app" 2>&1)"
    if ! printf '%s\n' "$details" | grep -q '^Authority=Developer ID Application:'; then
        printf 'Release app is not signed with Developer ID Application.\n' >&2
        exit 1
    fi
    if ! printf '%s\n' "$details" | grep -Eq '^CodeDirectory .*flags=.*runtime'; then
        printf 'Release app must enable Hardened Runtime.\n' >&2
        exit 1
    fi
    verify_universal "$app"
    for code_path in "$app/Contents/MacOS/OpenRight" "$app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle"; do
        if otool -L "$code_path" | tail -n +2 | grep -Eq '^[[:space:]]+(/Users/|/private/|/tmp/|.*\.build/)'; then
            printf 'Release contains a nonportable dynamic library reference: %s\n' "$code_path" >&2
            exit 1
        fi
    done
}

if [[ "${1:-}" == --verify-universal ]]; then
    [[ $# -eq 2 ]] || { printf 'Usage: %s --verify-universal <app>\n' "$0" >&2; exit 2; }
    verify_universal "$2"
    exit
fi
if [[ "${1:-}" == --resolve-release-identity ]]; then
    resolve_release_identity
    exit
fi
if [[ "${1:-}" == --verify-release ]]; then
    [[ $# -eq 2 ]] || { printf 'Usage: %s --verify-release <app>\n' "$0" >&2; exit 2; }
    verify_release "$2"
    exit
fi
release=false
if [[ "${1:-}" == --release ]]; then release=true; shift; fi
[[ $# -eq 1 && -d "$1/Contents" ]] || { printf 'Usage: %s [--release] <OpenRight.app>\n' "$0" >&2; exit 2; }
app="$1"
identity="${OPENRIGHT_SIGN_IDENTITY:--}"
if [[ "$release" == true ]]; then
    identity="$(resolve_release_identity)"
    validate_configuration "$app"
fi
flags=()
if [[ "$identity" != - ]]; then flags=(--options runtime --timestamp); fi
framework="$app/Contents/Frameworks/Sparkle.framework"
versioned="$framework/Versions/B"
for inner in "$versioned/XPCServices/Installer.xpc" "$versioned/Autoupdate" "$versioned/Updater.app"; do
    [[ -e "$inner" ]] || { printf 'Missing Sparkle helper: %s\n' "$inner" >&2; exit 1; }
    codesign --force --sign "$identity" ${flags[@]+"${flags[@]}"} "$inner"
done
downloader="$versioned/XPCServices/Downloader.xpc"
[[ -d "$downloader" ]] || { printf 'Missing Sparkle downloader.\n' >&2; exit 1; }
codesign --force --sign "$identity" ${flags[@]+"${flags[@]}"} --preserve-metadata=entitlements "$downloader"
codesign --force --sign "$identity" ${flags[@]+"${flags[@]}"} "$framework"
codesign --force --sign "$identity" ${flags[@]+"${flags[@]}"} --identifier org.openright.app "$app"
codesign --verify --deep --strict "$app"
if [[ "$release" == true ]]; then verify_release "$app"; fi

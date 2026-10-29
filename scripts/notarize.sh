#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
resume_id=""
if [[ "${1:-}" == --resume ]]; then resume_id="${2:?Missing submission ID}"; shift 2; fi
[[ $# -eq 1 && -e "$1" ]] || { printf 'Usage: %s [--resume <submission-id>] <app-or-dmg>\n' "$0" >&2; exit 2; }
target="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
case "$target" in
    *.app) ./scripts/sign-app.sh --verify-release "$target" ;;
    *.dmg)
        codesign --verify --strict "$target"
        if ! codesign --display --verbose=2 "$target" 2>&1 | grep -q '^Authority=Developer ID Application:'; then
            printf 'DMG must be Developer ID signed before notarization.\n' >&2; exit 1
        fi ;;
    *) printf 'Only .app and .dmg notarization is supported.\n' >&2; exit 2 ;;
esac
if xcrun stapler validate "$target" >/dev/null 2>&1; then
    printf 'Existing notarization ticket is valid: %s\n' "$target"
    exit
fi
auth=()
if [[ -n "${OPENRIGHT_NOTARY_PROFILE:-}" ]]; then
    auth=(--keychain-profile "$OPENRIGHT_NOTARY_PROFILE")
elif [[ -n "${OPENRIGHT_NOTARY_KEY_PATH:-}" && -n "${OPENRIGHT_NOTARY_KEY_ID:-}" ]]; then
    auth=(--key "$OPENRIGHT_NOTARY_KEY_PATH" --key-id "$OPENRIGHT_NOTARY_KEY_ID")
    if [[ -n "${OPENRIGHT_NOTARY_ISSUER:-}" ]]; then auth+=(--issuer "$OPENRIGHT_NOTARY_ISSUER"); fi
else
    printf 'Set OPENRIGHT_NOTARY_PROFILE, or OPENRIGHT_NOTARY_KEY_PATH and OPENRIGHT_NOTARY_KEY_ID with optional OPENRIGHT_NOTARY_ISSUER.\n' >&2
    exit 1
fi
mkdir -p "$project_root/dist/notarization"
result_path="$project_root/dist/notarization/$(basename "$target").json"
staging_dir="$(mktemp -d "$project_root/dist/.OpenRight.notary.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
if [[ -n "$resume_id" ]]; then
    command=(xcrun notarytool wait "$resume_id")
else
    submission="$target"
    if [[ "$target" == *.app ]]; then
        submission="$staging_dir/OpenRight.zip"
        ditto -c -k --sequesterRsrc --keepParent "$target" "$submission"
    fi
    command=(xcrun notarytool submit "$submission" --wait)
fi
if ! "${command[@]}" "${auth[@]}" --timeout "${OPENRIGHT_NOTARY_TIMEOUT:-30m}" --output-format json > "$result_path"; then
    printf 'Notarization did not complete. Result: %s. Resume the submission with --resume rather than resubmitting it.\n' "$result_path" >&2
    exit 1
fi
python3 - "$result_path" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    result = json.load(f)
if result.get('status') != 'Accepted':
    sys.exit('Notarization was not accepted. Inspect ' + sys.argv[1] + ' and request the Apple notary log for submission ' + result.get('id', '<unknown>'))
print('Notarization accepted: ' + result.get('id', '<unknown>'))
PY
xcrun stapler staple "$target"
xcrun stapler validate "$target"
if [[ "$target" == *.app ]]; then spctl --assess --type execute --verbose=2 "$target"; fi

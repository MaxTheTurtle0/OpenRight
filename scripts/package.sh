#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
release=false
notarized_app=false
skip_build=false
build_args=()
for argument in "$@"; do
    case "$argument" in
        --release) release=true; build_args+=(--release) ;;
        --universal) build_args+=(--universal) ;;
        --skip-build) skip_build=true ;;
        --notarized-app) notarized_app=true; skip_build=true ;;
        *) printf 'Usage: %s [--universal] [--release] [--skip-build] [--notarized-app]\n' "$0" >&2; exit 2 ;;
    esac
done
if [[ "$skip_build" == false ]]; then ./scripts/build.sh ${build_args[@]+"${build_args[@]}"}; fi
app_path="$project_root/dist/OpenRight.app"
[[ -d "$app_path" ]] || { printf 'Build OpenRight.app first.\n' >&2; exit 1; }
codesign --verify --deep --strict "$app_path"
if [[ "$notarized_app" == true ]]; then
    ./scripts/sign-app.sh --verify-release "$app_path"
    xcrun stapler validate "$app_path"
    spctl --assess --type execute --verbose=2 "$app_path"
fi
if [[ "$release" == true ]]; then
    OPENRIGHT_SIGN_IDENTITY="$(./scripts/sign-app.sh --resolve-release-identity)"
    export OPENRIGHT_SIGN_IDENTITY
    ./scripts/sign-app.sh --verify-release "$app_path"
    ./scripts/notarize.sh "$app_path"
fi
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
architectures="$(lipo -archs "$app_path/Contents/MacOS/OpenRight")"
if [[ "$architectures" == *arm64* && "$architectures" == *x86_64* ]]; then
    architecture=universal
elif [[ "$architectures" == arm64 || "$architectures" == x86_64 ]]; then
    architecture="$architectures"
else
    printf 'Unexpected application architectures: %s\n' "$architectures" >&2
    exit 1
fi
archive_base="OpenRight-$version-$architecture"
archive_path="$project_root/dist/$archive_base.zip"
dmg_path="$project_root/dist/$archive_base.dmg"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$archive_path"
staging_dir="$(mktemp -d "$project_root/dist/.OpenRight.dmg.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
mkdir "$staging_dir/image"
ditto "$app_path" "$staging_dir/image/OpenRight.app"
ln -s /Applications "$staging_dir/image/Applications"
cat > "$staging_dir/image/Install OpenRight.txt" <<'TXT'
Install OpenRight

1. Drag OpenRight.app to Applications.
2. Open the installed app from Applications.
3. Enable OpenRight in System Settings > Privacy & Security > Accessibility.
4. Quit rcmd before using OpenRight with the Right Command trigger.

Hold Right Command and press the first letter of an app to switch to it.
Right Command + Space opens app search.
Use the OpenRight menu bar icon for Settings and Check for Updates.
TXT
hdiutil create -quiet -ov -format UDZO -fs APFS -volname OpenRight -srcfolder "$staging_dir/image" "$dmg_path"
hdiutil verify -quiet "$dmg_path"
if [[ "$release" == true ]]; then
    codesign --force --sign "$OPENRIGHT_SIGN_IDENTITY" --timestamp "$dmg_path"
    ./scripts/notarize.sh "$dmg_path"
fi
cp "$dmg_path" "$project_root/dist/OpenRight.dmg"
for artifact in "$archive_path" "$dmg_path" "$project_root/dist/OpenRight.dmg"; do
    artifact_name="$(basename "$artifact")"
    (cd "$project_root/dist" && shasum -a 256 "$artifact_name" > "$artifact_name.sha256")
done
printf 'Packaged %s\nPackaged %s\n' "$archive_path" "$dmg_path"
if [[ "$release" == false && "$notarized_app" == false ]]; then printf 'Development artifacts only; they have not been notarized for public distribution.\n'; fi
if [[ "$notarized_app" == true ]]; then printf 'The app is Developer ID signed and notarized. The DMG is an unsigned container for that notarized app.\n'; fi

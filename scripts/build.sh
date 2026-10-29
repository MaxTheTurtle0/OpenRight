#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
universal="${OPENRIGHT_UNIVERSAL:-0}"
release=false
for argument in "$@"; do
    case "$argument" in
        --universal) universal=1 ;;
        --release) release=true; universal=1 ;;
        *) printf 'Usage: %s [--universal] [--release]\n' "$0" >&2; exit 2 ;;
    esac
done
if [[ "$release" == true ]]; then
    OPENRIGHT_SIGN_IDENTITY="$(./scripts/sign-app.sh --resolve-release-identity)"
    export OPENRIGHT_SIGN_IDENTITY
fi
mkdir -p dist
staging_dir="$(mktemp -d "$project_root/dist/.OpenRight.build.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
app_path="$staging_dir/OpenRight.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" "$app_path/Contents/Frameworks"
if [[ "$universal" == 1 ]]; then
    for arch in arm64 x86_64; do
        triple="$arch-apple-macosx13.0"
        swift build -c release --triple "$triple"
        binary_dir="$(swift build -c release --triple "$triple" --show-bin-path)"
        cp "$binary_dir/OpenRight" "$staging_dir/OpenRight-$arch"
    done
    lipo -create "$staging_dir/OpenRight-arm64" "$staging_dir/OpenRight-x86_64" -output "$app_path/Contents/MacOS/OpenRight"
    ./scripts/sign-app.sh --verify-universal "$app_path"
else
    swift build -c release
    binary_dir="$(swift build -c release --show-bin-path)"
    cp "$binary_dir/OpenRight" "$app_path/Contents/MacOS/OpenRight"
fi
framework="$project_root/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
[[ -d "$framework" ]] || { printf 'Resolved Sparkle framework not found: %s\n' "$framework" >&2; exit 1; }
ditto "$framework" "$app_path/Contents/Frameworks/Sparkle.framework"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
for resource in Resources/*; do
    [[ -f "$resource" && "$(basename "$resource")" != Info.plist ]] || continue
    cp "$resource" "$app_path/Contents/Resources/"
done
cp LICENSE "$app_path/Contents/Resources/LICENSE.txt"
swift scripts/make-icon.swift "$staging_dir/OpenRight.iconset"
iconutil -c icns "$staging_dir/OpenRight.iconset" -o "$app_path/Contents/Resources/AppIcon.icns"
if [[ "$release" == true ]]; then
    ./scripts/sign-app.sh --release "$app_path"
else
    ./scripts/sign-app.sh "$app_path"
fi
if [[ -e dist/OpenRight.app ]]; then rm -rf dist/OpenRight.app; fi
mv "$app_path" dist/OpenRight.app
printf 'Built %s/dist/OpenRight.app\n' "$project_root"

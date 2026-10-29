#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
mkdir -p dist
staging_dir="$(mktemp -d "$project_root/dist/.OpenRight.build.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
app_path="$staging_dir/OpenRight.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$binary_dir/OpenRight" "$app_path/Contents/MacOS/OpenRight"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
swift scripts/make-icon.swift "$staging_dir/OpenRight.iconset"
iconutil -c icns "$staging_dir/OpenRight.iconset" -o "$app_path/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier org.openright.app "$app_path"
codesign --verify --deep --strict "$app_path"
if [[ -e dist/OpenRight.app ]]; then
    rm -rf dist/OpenRight.app
fi
mv "$app_path" dist/OpenRight.app
printf 'Built %s/dist/OpenRight.app\n' "$project_root"

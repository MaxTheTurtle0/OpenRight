#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
if [[ ! -x dist/OpenRight.app/Contents/MacOS/OpenRight ]]; then
    ./scripts/build.sh
fi
install_dir="${OPENRIGHT_INSTALL_DIR:-$HOME/Applications}"
mkdir -p "$install_dir"
install_dir="$(cd "$install_dir" && pwd)"
staging_dir="$(mktemp -d "$install_dir/.OpenRight.install.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
ditto dist/OpenRight.app "$staging_dir/OpenRight.app"
codesign --verify --deep --strict "$staging_dir/OpenRight.app"
if [[ -e "$install_dir/OpenRight.app" ]]; then
    backup_path="$install_dir/OpenRight.previous.$(date +%Y%m%d%H%M%S).app.backup"
    if [[ -e "$backup_path" ]]; then
        printf 'Backup already exists: %s\n' "$backup_path" >&2
        exit 1
    fi
    mv "$install_dir/OpenRight.app" "$backup_path"
    printf 'Previous app saved to %s\n' "$backup_path"
fi
mv "$staging_dir/OpenRight.app" "$install_dir/OpenRight.app"
printf 'Installed %s/OpenRight.app\n' "$install_dir"
printf 'Open it with: open "%s/OpenRight.app"\n' "$install_dir"

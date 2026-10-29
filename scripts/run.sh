#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
app_binary="$project_root/dist/OpenRight.app/Contents/MacOS/OpenRight"
needs_build=false
if [[ ! -x "$app_binary" ]]; then
    needs_build=true
else
    while IFS= read -r source_path; do
        if [[ "$source_path" -nt "$app_binary" ]]; then
            needs_build=true
            break
        fi
    done < <(find Sources Resources scripts -type f -print; printf '%s\n' Package.swift)
fi
if [[ "$needs_build" == true ]]; then
    ./scripts/build.sh
fi
open "$project_root/dist/OpenRight.app"

#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
./scripts/build.sh
archive_path="$project_root/dist/OpenRight-0.1.0-$(uname -m).zip"
ditto -c -k --sequesterRsrc --keepParent dist/OpenRight.app "$archive_path"
archive_name="$(basename "$archive_path")"
(cd dist && shasum -a 256 "$archive_name" > "$archive_name.sha256")
printf 'Packaged %s\n' "$archive_path"

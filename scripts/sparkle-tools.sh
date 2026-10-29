#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -lt 1 ]]; then
    printf 'Usage: %s <generate_keys|generate_appcast|sign_update> [arguments...]\n' "$0" >&2
    exit 2
fi
tool="$1"
shift
case "$tool" in generate_keys|generate_appcast|sign_update) ;; *) printf 'Unknown Sparkle tool: %s\n' "$tool" >&2; exit 2 ;; esac
if [[ -n "${OPENRIGHT_SPARKLE_TOOLS_DIR:-}" ]]; then
    tool_path="$OPENRIGHT_SPARKLE_TOOLS_DIR/$tool"
else
    tool_path="$project_root/.build/artifacts/sparkle/Sparkle/bin/$tool"
fi
if [[ ! -x "$tool_path" ]]; then
    printf 'Sparkle tool missing: %s. Run swift package resolve first, or set OPENRIGHT_SPARKLE_TOOLS_DIR.\n' "$tool_path" >&2
    exit 1
fi
exec "$tool_path" "$@"

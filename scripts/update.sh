#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/sbin:/bin:${PATH:-}"
exec bash "$SCRIPT_DIR/upgrade.sh" "$@"

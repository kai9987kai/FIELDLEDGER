#!/usr/bin/env sh
# =====================================================================
# Launch the offline FIELDLEDGER GUI Workbench (Linux / macOS)
# Zero npm dependencies; invokes compiled GnuCOBOL build/fieldledger.
# =====================================================================
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
PORT="${1:-4173}"

if [ ! -x "$REPO_ROOT/build/fieldledger" ]; then
    echo "FIELDLEDGER COBOL binary not found; building first..."
    "$SCRIPT_DIR/build.sh"
fi

if ! command -v node >/dev/null 2>&1; then
    echo "ERROR: Node.js is required to run gui/server.mjs (zero npm dependencies)." >&2
    exit 1
fi

exec node "$REPO_ROOT/gui/server.mjs" --port "$PORT"

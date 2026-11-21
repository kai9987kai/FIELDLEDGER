#!/usr/bin/env sh
# =====================================================================
# FIELDLEDGER Build Script (Linux / macOS / Unix-like environments)
# Compiles all modular COBOL sources with GnuCOBOL and links build/fieldledger.
# =====================================================================
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_DIR="$REPO_ROOT/build"
OBJ_DIR="$BUILD_DIR/obj"
COPY_DIR="$REPO_ROOT/copybooks"
SRC_DIR="$REPO_ROOT/src"
OUT_BIN="$BUILD_DIR/fieldledger"

if [ "${1:-}" = "--clean" ]; then
    rm -rf "$BUILD_DIR"
fi

if ! command -v cobc >/dev/null 2>&1; then
    echo "ERROR: GnuCOBOL (cobc) is not installed or not in PATH." >&2
    echo "See docs/BUILD-INSTRUCTIONS.md for installation instructions." >&2
    exit 1
fi

mkdir -p "$OBJ_DIR"

echo "=== FIELDLEDGER Build (Unix / POSIX sh) ==="
echo "Compiler : $(cobc --version | head -n 1)"
echo "Flags    : -free -Wall -O2 -I copybooks"
echo "Output   : $OUT_BIN"

MODULES="
core/CONFIGURATION.cob
core/ERROR-HANDLING.cob
core/DATE-UTILS.cob
core/NUMERIC-UTILS.cob
core/COMMAND-PARSER.cob
ingestion/RECORD-NORMALISER.cob
ingestion/CSV-READER.cob
ingestion/DATA-IMPORT.cob
validation/VALIDATE-STUDY.cob
validation/VALIDATE-SOURCES.cob
validation/VALIDATE-SITES.cob
validation/VALIDATE-SURVEYS.cob
validation/VALIDATE-OBSERVATIONS.cob
validation/DUPLICATE-DETECTION.cob
ledger/EVIDENCE-LEDGER.cob
ledger/RUN-RECEIPT.cob
ecology/EFFORT-STANDARDISER.cob
ecology/SPECIES-AGGREGATOR.cob
ecology/SITE-SUMMARY.cob
analysis/BOOTSTRAP-ENGINE.cob
analysis/UNCERTAINTY-ENGINE.cob
analysis/SENSITIVITY-ENGINE.cob
analysis/BACI-ENGINE.cob
reporting/CSV-REPORTER.cob
reporting/JSON-REPORTER.cob
reporting/MARKDOWN-REPORTER.cob
reporting/HTML-REPORTER.cob
"

OBJ_LIST=""
for rel in $MODULES; do
    base=$(basename "$rel" .cob)
    obj="$OBJ_DIR/$base.o"
    echo "  [CC] $rel"
    cobc -c -free -Wall -O2 -I "$COPY_DIR" -o "$obj" "$SRC_DIR/$rel"
    OBJ_LIST="$OBJ_LIST $obj"
done

echo "  [LD] main.cob -> fieldledger"
# shellcheck disable=SC2086
cobc -x -free -Wall -O2 -I "$COPY_DIR" -o "$OUT_BIN" "$SRC_DIR/main.cob" $OBJ_LIST

echo "Build succeeded: $OUT_BIN"

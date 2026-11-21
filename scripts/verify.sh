#!/usr/bin/env sh
# =====================================================================
# FIELDLEDGER SHA-256 Input Manifest Verifier (Linux / macOS)
# Detects modified, missing, untracked CSV files, or corrupted manifests.
# =====================================================================
set -eu

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <study_path>" >&2
    exit 1
fi

STUDY_PATH="$1"
MANIFEST_FILE="$STUDY_PATH/manifest.sha256"

if [ ! -d "$STUDY_PATH" ]; then
    echo "ERROR: Study directory not found: $STUDY_PATH" >&2
    exit 1
fi

if [ ! -f "$MANIFEST_FILE" ]; then
    echo "ERROR: Manifest file not found: $MANIFEST_FILE" >&2
    exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
    HASH_TOOL="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    HASH_TOOL="shasum"
else
    echo "ERROR: Neither sha256sum nor shasum found." >&2
    exit 1
fi

FIRST_LINE=$(head -n 1 "$MANIFEST_FILE" | tr -d '\r')
case "$FIRST_LINE" in
    "# FIELDLEDGER SHA-256 INPUT MANIFEST"*) ;;
    *)
        echo "ERROR: Corrupted manifest header in $MANIFEST_FILE" >&2
        exit 1
        ;;
esac

CHECKED=0
FAILED=0
TMP_LIST=$(mktemp)
trap 'rm -f "$TMP_LIST"' EXIT

LINE_NO=0
while IFS= read -r raw_line || [ -n "$raw_line" ]; do
    LINE_NO=$((LINE_NO + 1))
    line=$(printf "%s" "$raw_line" | tr -d '\r')
    case "$line" in
        ""|\#*) continue ;;
    esac

    exp_hash=$(printf "%s\n" "$line" | awk '{print tolower($1)}')
    exp_size=$(printf "%s\n" "$line" | awk '{print $2}')
    rel_path=$(printf "%s\n" "$line" | awk '{ $1=""; $2=""; sub(/^  */, ""); print }')

    if ! printf "%s" "$exp_hash" | grep -Eq '^[0-9a-f]{64}$' || \
       ! printf "%s" "$exp_size" | grep -Eq '^[0-9]+$' || \
       [ -z "$rel_path" ]; then
        echo "[FAIL] Corrupted manifest entry on line $LINE_NO: $line" >&2
        FAILED=$((FAILED + 1))
        continue
    fi

    case "$rel_path" in
        /*|*..*)
            echo "[FAIL] Unsafe relative path on line $LINE_NO: $rel_path" >&2
            FAILED=$((FAILED + 1))
            continue
            ;;
    esac

    printf "%s\n" "$rel_path" >> "$TMP_LIST"
    target="$STUDY_PATH/$rel_path"
    if [ ! -f "$target" ]; then
        echo "[FAIL] Missing file: $rel_path" >&2
        FAILED=$((FAILED + 1))
        continue
    fi

    act_size=$(wc -c < "$target" | tr -d ' ')
    if [ "$HASH_TOOL" = "sha256sum" ]; then
        act_hash=$(sha256sum "$target" | awk '{print tolower($1)}')
    else
        act_hash=$(shasum -a 256 "$target" | awk '{print tolower($1)}')
    fi

    if [ "$act_size" != "$exp_size" ] || [ "$act_hash" != "$exp_hash" ]; then
        echo "[FAIL] INTEGRITY MISMATCH: $rel_path" >&2
        echo "       Expected: sha256=$exp_hash size=$exp_size" >&2
        echo "       Actual  : sha256=$act_hash size=$act_size" >&2
        FAILED=$((FAILED + 1))
    else
        echo "[OK]   $rel_path ($act_size bytes)"
    fi
    CHECKED=$((CHECKED + 1))
done < "$MANIFEST_FILE"

if [ "$CHECKED" -eq 0 ]; then
    echo "ERROR: Corrupted manifest (zero digest entries)." >&2
    exit 1
fi

for f in $(cd "$STUDY_PATH" && LC_ALL=C ls -1 *.csv 2>/dev/null | sort); do
    if ! grep -Fxq "$f" "$TMP_LIST"; then
        echo "[FAIL] Unexpected CSV file not in manifest: $f" >&2
        FAILED=$((FAILED + 1))
    fi
done

if [ "$FAILED" -gt 0 ]; then
    echo "MANIFEST VERIFICATION FAILED: $FAILED error(s) across $CHECKED entry/entries." >&2
    exit 1
fi

echo "MANIFEST VERIFIED: $CHECKED file(s) matched SHA-256 digest and byte size."
exit 0

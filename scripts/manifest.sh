#!/usr/bin/env sh
# =====================================================================
# FIELDLEDGER SHA-256 Input Manifest Generator (Linux / macOS)
# Uses OS-provided sha256sum (Linux) or shasum -a 256 (macOS).
# =====================================================================
set -eu

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <study_path>" >&2
    exit 1
fi

STUDY_PATH="$1"
if [ ! -d "$STUDY_PATH" ]; then
    echo "ERROR: Study directory not found: $STUDY_PATH" >&2
    exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
    HASH_TOOL="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    HASH_TOOL="shasum"
else
    echo "ERROR: Neither sha256sum nor shasum found on this system." >&2
    exit 1
fi

for req in study.csv sources.csv sites.csv surveys.csv observations.csv; do
    if [ ! -f "$STUDY_PATH/$req" ]; then
        echo "ERROR: Required dataset file missing: $req (in $STUDY_PATH)" >&2
        exit 1
    fi
done

DATASET_ID=$(awk -F',' 'NR==2 { gsub(/^"|"$/, "", $1); gsub(/\r$/, "", $1); print $1 }' "$STUDY_PATH/study.csv")
if [ -z "$DATASET_ID" ]; then
    DATASET_ID="UNKNOWN"
fi

TIMESTAMP_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
MANIFEST_FILE="$STUDY_PATH/manifest.sha256"

{
    echo "# FIELDLEDGER SHA-256 INPUT MANIFEST v1"
    echo "# dataset_id: $DATASET_ID"
    echo "# generated_utc: $TIMESTAMP_UTC"
    echo "# algorithm: SHA-256"
    echo "# format: <sha256_hex>  <file_size_bytes>  <relative_path>"

    for f in $(cd "$STUDY_PATH" && LC_ALL=C ls -1 *.csv 2>/dev/null | sort); do
        full="$STUDY_PATH/$f"
        if [ "$HASH_TOOL" = "sha256sum" ]; then
            digest=$(sha256sum "$full" | awk '{print tolower($1)}')
        else
            digest=$(shasum -a 256 "$full" | awk '{print tolower($1)}')
        fi
        size=$(wc -c < "$full" | tr -d ' ')
        printf "%s  %s  %s\n" "$digest" "$size" "$f"
    done
} > "$MANIFEST_FILE"

echo "Generated SHA-256 manifest: $MANIFEST_FILE"
echo "  Dataset ID : $DATASET_ID"
echo "  Generated  : $TIMESTAMP_UTC"

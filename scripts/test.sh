#!/usr/bin/env sh
# =====================================================================
# FIELDLEDGER Automated Test Suite (Linux / macOS / Unix-like)
# Builds FIELDLEDGER, compiles and runs native COBOL unit tests, and
# executes integration, statistical, validation, and integrity checks.
# =====================================================================
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_DIR="$REPO_ROOT/build"
OBJ_DIR="$BUILD_DIR/obj"
EXE="$BUILD_DIR/fieldledger"
UNIT_EXE="$BUILD_DIR/unit-tests"
TMP_OUT="$REPO_ROOT/output/test-runs-sh"

if [ ! -x "$EXE" ]; then
    "$SCRIPT_DIR/build.sh"
fi

rm -rf "$TMP_OUT"
mkdir -p "$TMP_OUT"

PASSED=0
FAILED=0

assert_ok() {
    name="$1"
    shift
    if "$@"; then
        PASSED=$((PASSED + 1))
        echo "  [PASS] $name"
    else
        FAILED=$((FAILED + 1))
        echo "  [FAIL] $name" >&2
    fi
}

assert_fail() {
    name="$1"
    shift
    if "$@"; then
        FAILED=$((FAILED + 1))
        echo "  [FAIL] $name (expected non-zero exit)" >&2
    else
        PASSED=$((PASSED + 1))
        echo "  [PASS] $name"
    fi
}

echo "=== 1. Native COBOL Unit Tests ==="
cobc -x -free -Wall -O2 -I "$REPO_ROOT/copybooks" -o "$UNIT_EXE" \
    "$REPO_ROOT/tests/unit/UNIT-TESTS.cob" \
    "$OBJ_DIR/CONFIGURATION.o" "$OBJ_DIR/ERROR-HANDLING.o" \
    "$OBJ_DIR/DATE-UTILS.o" "$OBJ_DIR/NUMERIC-UTILS.o" \
    "$OBJ_DIR/RECORD-NORMALISER.o" "$OBJ_DIR/CSV-READER.o" \
    "$OBJ_DIR/EFFORT-STANDARDISER.o" "$OBJ_DIR/BOOTSTRAP-ENGINE.o" \
    "$OBJ_DIR/UNCERTAINTY-ENGINE.o" "$OBJ_DIR/SENSITIVITY-ENGINE.o"
assert_ok "Native COBOL unit tests" "$UNIT_EXE"

echo "=== 2. Regression & Integration Tests ==="
assert_ok "CLI help" "$EXE" help >/dev/null
assert_fail "Reject invalid CLI flag" "$EXE" analyze baci --study "$REPO_ROOT/examples/wetland-demo" --out "$TMP_OUT/badcli" --bogus >/dev/null 2>&1
assert_ok "Init study with spaces in path" "$EXE" init --study "$TMP_OUT/study with spaces" >/dev/null

REF_OUT="$TMP_OUT/wetland-ref"
assert_ok "Analyze wetland-demo" "$EXE" analyze baci --study "$REPO_ROOT/examples/wetland-demo" --out "$REF_OUT" --seed 20261120 --bootstrap 2000 >/dev/null
assert_ok "Exact BACI +6.000000 and WITHHELD CI" grep -q ",8.000000,2.000000,6.000000,.*WITHHELD,NA,NA," "$REF_OUT/baci-results.csv"

echo "=== 3. Statistical Tests ==="
MVZ_OUT="$TMP_OUT/mvz"
assert_ok "Missing vs zero run" "$EXE" analyze baci --study "$REPO_ROOT/tests/fixtures/missing-vs-zero" --out "$MVZ_OUT" >/dev/null
assert_ok "SP_ZERO BACI=6.000000" grep -q "^SP_ZERO,.*,6.000000," "$MVZ_OUT/baci-results.csv"
assert_ok "SP_MISS BACI=3.000000 (missing != zero)" grep -q "^SP_MISS,.*,3.000000," "$MVZ_OUT/baci-results.csv"

UNEQ_OUT="$TMP_OUT/uneq"
assert_ok "Unequal surveys & effort rate" "$EXE" analyze baci --study "$REPO_ROOT/tests/fixtures/unequal-surveys" --out "$UNEQ_OUT" >/dev/null
assert_ok "Equal-site weighting BACI=8.000000" grep -q "^SP001,.*,10.000000,2.000000,8.000000," "$UNEQ_OUT/baci-results.csv"

BOOT_OUT1="$TMP_OUT/boot1"
BOOT_OUT2="$TMP_OUT/boot2"
assert_ok "Bootstrap >=5 sites run 1" "$EXE" analyze baci --study "$REPO_ROOT/tests/fixtures/bootstrap-large" --out "$BOOT_OUT1" --seed 20261120 --bootstrap 2000 >/dev/null
assert_ok "Bootstrap >=5 sites run 2" "$EXE" analyze baci --study "$REPO_ROOT/tests/fixtures/bootstrap-large" --out "$BOOT_OUT2" --seed 20261120 --bootstrap 2000 >/dev/null
assert_ok "Bootstrap REPORTED CI deterministic" cmp -s "$BOOT_OUT1/baci-results.csv" "$BOOT_OUT2/baci-results.csv"

echo "=== 4. Validation & Integrity Tests ==="
for bad in invalid-duplicate invalid-fk invalid-date invalid-status invalid-csv; do
    assert_fail "Reject $bad" "$EXE" analyze baci --study "$REPO_ROOT/tests/fixtures/$bad" --out "$TMP_OUT/$bad" >/dev/null 2>&1
done

MAN_DIR="$TMP_OUT/manifest-test"
cp -R "$REPO_ROOT/examples/wetland-demo" "$MAN_DIR"
assert_ok "Generate SHA-256 manifest" "$EXE" manifest --study "$MAN_DIR" >/dev/null
assert_ok "Verify unmodified manifest" "$EXE" verify --study "$MAN_DIR" >/dev/null
echo "OBS999,SRV001,SP002,1,DETECTED" >> "$MAN_DIR/observations.csv"
assert_fail "Detect modified input file" "$EXE" verify --study "$MAN_DIR" >/dev/null 2>&1

assert_ok "Regenerate report from matching receipt" "$EXE" report --study "$REPO_ROOT/examples/wetland-demo" --out "$REF_OUT" >/dev/null
assert_fail "Reject mismatched receipt study_id" "$EXE" report --study "$REPO_ROOT/tests/fixtures/missing-vs-zero" --out "$REF_OUT" >/dev/null 2>&1

echo "SUMMARY: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]

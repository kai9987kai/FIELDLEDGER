# FIELDLEDGER Development Log

Engineering record covering Phases 0 through 7: what was implemented, compiled, tested, passed, failed & resolved, and what remains intentionally scoped to future releases.

---

## Phase 0 — Environment & Feasibility Verification

- **Workspace inspection:** Inspected `c:\Users\kai99\Desktop\New folder (2)` (empty workspace). Detected `C:\msys64\ucrt64` with GCC 15.2.0 already installed; `cobc` not yet installed.
- **Toolchain installation:** Installed `mingw-w64-ucrt-x86_64-gnucobol` (`1~3.2-10`) via MSYS2 `pacman`.
- **Verified compiler:** `cobc (GnuCOBOL) 3.2.0` (`x86_64-w64-mingw32`, GMP, BDB, json-c, libxml2).
- **Platform finding & resolution:** Calling MSYS2 `cobc.exe` from native Windows PowerShell initially failed with `/ucrt64/share/gnucobol/config\default.conf: No such file or directory`. Resolved cleanly in `scripts/build.ps1` by exporting `COB_CONFIG_DIR`, `COB_COPY_DIR`, `COB_CFLAGS`, and `COB_LIBS` pointing to `C:\msys64\ucrt64\...` and staging the 10 MinGW runtime DLLs next to `build\fieldledger.exe`.
- **Feasibility probes passed:** Verified free-format compilation (`-free -Wall -O2`), command-line arguments with spaces (`ARGUMENT-NUMBER` / `ARGUMENT-VALUE`), `ARG 0` executable path resolution, `CBL_CREATE_DIR`, `CBL_CHECK_FILE_EXIST`, `LINE SEQUENTIAL` I/O, `COMP-3` / `COMP-5` precision, large `EXTERNAL` tables (250,000 rows), multi-module `COPY` linking, and native COBOL table `SORT` with `OCCURS DEPENDING ON`.

## Phase 1 — Foundation (`copybooks/`, `src/core/`, `src/ingestion/`)

- **Implemented:** 11 copybooks (`LIMITS`, `RUN-CONFIG`, `STUDY-RECORD`, `SOURCE-RECORD`, `SITE-RECORD`, `SURVEY-RECORD`, `OBSERVATION-RECORD`, `ERROR-RECORD`, `BACI-RESULT`, `CSV-WORK`, `UTILS-IFACE`), `CONFIGURATION.cob`, `ERROR-HANDLING.cob`, `DATE-UTILS.cob`, `NUMERIC-UTILS.cob`, `COMMAND-PARSER.cob`, `RECORD-NORMALISER.cob`, `CSV-READER.cob`, `DATA-IMPORT.cob`.
- **Initial catch:** Corrected two COBOL paragraphs (`REPORT-REQ-FIELD` in `VALIDATE-STUDY.cob`, `OPEN-STUDY-FILE` in `DATA-IMPORT.cob`) to use working-storage variables rather than paragraph `USING` clauses before compiling.

## Phase 2 — Validation (`src/validation/`)

- **Implemented:** `VALIDATE-STUDY.cob`, `VALIDATE-SOURCES.cob`, `VALIDATE-SITES.cob`, `VALIDATE-SURVEYS.cob`, `VALIDATE-OBSERVATIONS.cob`, `DUPLICATE-DETECTION.cob` (O(N log N) COBOL `SORT` + O(log N) binary search FK lookups).
- **Compiled:** All 14 Phase 1 & 2 modules compiled cleanly (`cobc -c -free -Wall -O2 -I copybooks`), **0 errors, 0 warnings**.

## Phase 3, 4, 5, 6 — Evidence Ledger, Ecological/BACI Engine, Uncertainty, Sensitivity, Reporting

- **Implemented:**
  - `copybooks/ANALYSIS-WORK.cpy`
  - `src/ledger/EVIDENCE-LEDGER.cob`, `src/ledger/RUN-RECEIPT.cob`
  - `src/ecology/EFFORT-STANDARDISER.cob`, `src/ecology/SPECIES-AGGREGATOR.cob`, `src/ecology/SITE-SUMMARY.cob`
  - `src/analysis/BOOTSTRAP-ENGINE.cob`, `src/analysis/UNCERTAINTY-ENGINE.cob`, `src/analysis/SENSITIVITY-ENGINE.cob`, `src/analysis/BACI-ENGINE.cob`
  - `src/reporting/CSV-REPORTER.cob`, `src/reporting/JSON-REPORTER.cob`, `src/reporting/MARKDOWN-REPORTER.cob`, `src/reporting/HTML-REPORTER.cob`
  - `src/main.cob`
  - Platform build & SHA-256 scripts: `scripts/build.ps1`, `scripts/build.sh`, `scripts/manifest.ps1`, `scripts/manifest.sh`, `scripts/verify.ps1`, `scripts/verify.sh`.
- **Compiled:** Full 28-module build via `scripts/build.ps1 -Clean` succeeded with **0 errors, 0 warnings**.
- **Smoke test passed:** `demo`, JSON parse via `ConvertFrom-Json`, `manifest`, `verify`, `report` all exited 0 with exact `+6.000000` BACI estimate and `WITHHELD` small-sample CI.
- **Polish fixes applied:**
  - Formatted `ERROR-HANDLING.cob` console summary counters with `Z(8)9` to remove leading zeroes.
  - Fixed spacing in `MARKDOWN-REPORTER.cob` table cells after `FUNCTION TRIM`.

## Phase 7 — Verification, Optimization, Benchmarks & Documentation

- **Implemented:** `examples/wetland-demo/`, 13 synthetic test fixtures under `tests/fixtures/`, native COBOL unit test suite `tests/unit/UNIT-TESTS.cob` (19 assertions), `scripts/test.ps1`, `scripts/test.sh`, `tests/integration/BENCHMARK.cob`, `tests/integration/benchmark.ps1`.
- **Test failures discovered and resolved during QA:**
  1. `scripts/build.ps1`: Windows temporarily locked an unchanged staged DLL (`libncursesw6.dll`) on rebuild -> updated `build.ps1` to skip copying identical already-staged DLLs.
  2. `tests/unit/UNIT-TESTS.cob`: Single-quote escape syntax in COBOL literal (`''` vs shell quote) -> fixed.
  3. `scripts/test.ps1` & `scripts/verify.ps1` & `scripts/manifest.ps1`: Under PowerShell `Set-StrictMode -Version Latest`, single-row `Import-Csv` / single-line `Get-Content` returns scalar rather than array -> wrapped in `@(...)`.
  4. `tests/fixtures/baci-zero-and-neg/study.csv`: Unquoted comma in `study_description` was legitimately caught by FIELDLEDGER's validation engine (`COLUMN_COUNT`) -> properly RFC 4180 quoted the description.
  5. `scripts/test.ps1`: Expected stderr from negative `verify` test tripped `$ErrorActionPreference = "Stop"` -> wrapped expected-failure calls in `Invoke-FL`.
- **Performance optimization verified:** Replaced inner-loop `COMP-3` accumulation and `FUNCTION MOD` calls in `BOOTSTRAP-ENGINE.cob` with exact 64-bit `COMP-5` micro-unit (`× 10^6`) summation and `DIVIDE ... REMAINDER` (zero precision loss). Reduced 50,000-observation / 25-species / B=2,000 end-to-end runtime from `21,990 ms` to `9,820 ms` (Stage 4 cut from `16,510 ms` to `7,760 ms`). Verified full maximum-capacity run (`250,000` observations, `10,000` surveys, `200` sites, `25` species, `B=2,000`) completed with 0 errors in `56,800 ms`.
- **Final Test Suite Result:** `19/19` native COBOL unit assertions passed; `37/37` total `scripts/test.ps1` checks passed, `0` failed.
- **Official Example Report Generated:** `examples/wetland-demo/manifest.sha256` verified and full outputs generated in `output/wetland-demo/`.

## Documented Version 1 Scope Boundaries (Intentionally Deferred to v2)

- Repeated-visit occupancy / detection-probability estimation (architecture hook `DET-MODEL-SPEC` implemented in v1; statistical model deferred to v2).
- Execution of `scripts/build.sh` and `scripts/test.sh` on a native Linux/macOS host (scripts authored strictly POSIX-compliant; verified on Windows via PowerShell — Linux execution awaits a Unix host).
- Disk-backed streaming beyond 250,000 observations (in-memory limits explicitly enforced with `RESOURCE_LIMIT` errors in v1).

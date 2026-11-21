# FIELDLEDGER Provenance & Data Integrity Model

## 1. End-to-End Traceability Chain

FIELDLEDGER links every reported scientific conclusion back to its immutable input dataset through four complementary mechanisms:

1. **Source Provenance (`sources.csv`):** Every survey record must reference a valid `source_id` documenting organisation, citation, licence, source type, and access date.
2. **SHA-256 Input Manifest (`manifest.sha256`):** Captures exact lowercase SHA-256 digests and byte sizes for every CSV input file in the study directory, generated and verified via OS-provided cryptographic tools (`PowerShell Get-FileHash -Algorithm SHA256` on Windows; `sha256sum` on Linux; `shasum -a 256` on macOS).
3. **Research Receipt (`research-receipt.json`):** Captures exact software version, GnuCOBOL version, run ID, timestamp, `study_id`, analysis configuration, active method policy, deterministic PRNG seed, bootstrap iterations, input manifest status/date, valid/rejected/excluded/missing record counts, warnings, and exact output filenames.
4. **Append-Only Evidence Ledger (`evidence-ledger.csv`):** Appends one RFC 4180 CSV row per validation or analysis execution (including failed/rejected validation runs) via `OPEN EXTEND`, preserving historical run records.

## 2. Integrity Verification Protocol

- `fieldledger manifest --study <PATH>` delegates to `scripts/manifest.ps1` (Windows) or `scripts/manifest.sh` (Unix) resolved relative to the `fieldledger` executable path (independent of current working directory). Source CSV files are read-only and never modified.
- `fieldledger verify --study <PATH>` delegates to `scripts/verify.ps1` / `scripts/verify.sh` and fails with a non-zero exit code if:
  - `manifest.sha256` is missing or its header/entry format is corrupted;
  - Any listed file is missing, changed in byte size, or differs in SHA-256 digest;
  - Any untracked `.csv` file was added to the study directory after manifest generation;
  - Any manifest path attempts directory traversal (`..` or absolute paths).

## 3. Verified Report Regeneration (`fieldledger report`)

`fieldledger report --study <PATH> --out <PATH>` enforces strict provenance binding via `src/ledger/RUN-RECEIPT.cob`:

1. Reads and validates `study.csv` in `--study` to obtain the authoritative `study_id`.
2. Parses `<out>/research-receipt.json`, confirming `application == "FIELDLEDGER"` and `validation_outcome == "PASSED"`.
3. Verifies `receipt.study_id == study.csv::study_id`. If missing, malformed, or mismatched, `report` aborts with exit code `5` (`FL-EXIT-INTEGRITY-ERR`).
4. Reloads verified `baci-results.csv`, `site-summaries.csv`, `data-quality.csv`, and `validation-report.csv` before regenerating `report.md` and `report.html`.

## 4. Honest Security Boundaries

- FIELDLEDGER does **not** substitute CRC32, timestamps, or record counts for cryptographic digests.
- FIELDLEDGER does **not** claim that a local append-only CSV file (`evidence-ledger.csv`) is cryptographically immutable; external immutability requires archiving `manifest.sha256`, `research-receipt.json`, and `evidence-ledger.csv` in version control, WORM storage, or a signed research deposit (e.g., Zenodo / institutional repository).
- Presence of `source_url` in `sources.csv` is provenance metadata only and does not imply external verification.

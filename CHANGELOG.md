# Changelog

All notable changes to FIELDLEDGER will be documented in this file.

## [1.0.0] - 2026-11-20

### Added
- Complete COBOL-first scientific computing platform compiled with GnuCOBOL 3.2.0 (`-free -Wall -O2`).
- 28 modular COBOL programs and 12 shared COPYBOOKS covering CLI parsing, RFC 4180 CSV ingestion, strict UTF-8 / BOM / line-length validation, referential integrity, O(N log N) duplicate detection, effort standardisation, BACI estimation, deterministic Park-Miller site-cluster bootstrap, leave-one-site-out sensitivity analysis, append-only evidence ledger, receipt verification, and offline reporting.
- Platform-specific SHA-256 integrity manifest adapters for Windows (`PowerShell Get-FileHash`) and Linux/macOS (`sha256sum` / `shasum -a 256`).
- Synthetic demonstration dataset (`examples/wetland-demo/`) with exact expected BACI effect of `+6.000000` detections/hour and pre-generated example scientific report (`output/wetland-demo/`).
- 13 synthetic test fixtures covering missingness vs. explicit zeros, unequal survey frequencies, zero/negative BACI effects, same-day transition exclusion, 6+6 site bootstrap, multi-method stratification, insufficient sites, duplicate IDs/keys, broken foreign keys, invalid calendar dates, mismatched observation statuses, malformed CSV, and HTML/JSON/CSV special-character escaping.
- Native COBOL unit test harness (`tests/unit/UNIT-TESTS.cob`), automated PowerShell and POSIX shell test suites (`scripts/test.ps1`, `scripts/test.sh`), and per-stage COBOL benchmark harness (`tests/integration/BENCHMARK.cob`, `tests/integration/benchmark.ps1`).
- Complete technical documentation (`docs/`), falsifiable research programme (`research/`), and development log (`docs/DEVELOPMENT-LOG.md`).

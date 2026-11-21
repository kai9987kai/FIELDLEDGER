# Contributing to FIELDLEDGER

Thank you for your interest in contributing to FIELDLEDGER. Because FIELDLEDGER is a scientific accountability and statistical computing platform, contributions must preserve mathematical accuracy, COBOL-first purity, and reproducibility.

## Engineering Standards

1. **COBOL-first scientific engine:** All ingestion, validation, statistical computation, ledger management, and reporting logic must remain in portable free-format GnuCOBOL (`>>SOURCE FORMAT FREE`). Shell and PowerShell scripts are restricted to build automation, testing, packaging, and OS-native SHA-256 adapters.
2. **Compiler cleanliness:** All COBOL modules must compile with zero warnings under `cobc -free -Wall -O2 -I copybooks`.
3. **Fixed-point precision:** Reported scientific and statistical quantities must use explicit `COMP-3` fixed-point representations with documented integer and decimal precision.
4. **No silent data repair:** Never silently coerce malformed dates, missing observations, invalid statuses, or out-of-range numbers into defaults. Reject invalid records clearly with file, row, and field identifiers.
5. **Principle of explicit uncertainty:** Never manufacture p-values or relax small-sample confidence-interval safeguards without explicit statistical justification and documentation.
6. **Honest scientific reporting:** Synthetic datasets must always be explicitly labelled synthetic. Never fabricate benchmarks, empirical results, or external citations.

## Submitting Changes

1. Build locally using `.\scripts\build.ps1` (Windows) or `./scripts/build.sh` (Linux/macOS).
2. Add or update unit tests in `tests/unit/UNIT-TESTS.cob` and integration/statistical fixtures under `tests/fixtures/`.
3. Execute the full test suite (`.\scripts\test.ps1` or `./scripts/test.sh`) and verify 0 failures.
4. Update relevant documentation under `docs/` and record notable changes in `CHANGELOG.md`.

# FIELDLEDGER Architecture

## 1. Architectural Overview

FIELDLEDGER is structured as a modular, statically linked GnuCOBOL application consisting of **28 free-format COBOL source files** (`src/`) sharing **12 typed COPYBOOKS** (`copybooks/`), complemented by lightweight platform scripts (`scripts/`) strictly limited to compilation, testing, and OS-native SHA-256 checksum generation/verification.

```
fieldledger (src/main.cob)
 ├── Core Utilities (src/core/)
 │    ├── CONFIGURATION.cob      OS/path detection, ARG0 resolution, timestamps, help
 │    ├── COMMAND-PARSER.cob     CLI command & flag parsing, range checks
 │    ├── ERROR-HANDLING.cob     Structured validation error/warning store
 │    ├── DATE-UTILS.cob         ISO 8601 validation, Gregorian leap years, ordinal days
 │    └── NUMERIC-UTILS.cob      Strict decimal/int parsing, COMP-3 formatting, CSV/JSON/HTML escaping
 ├── Ingestion Layer (src/ingestion/)
 │    ├── RECORD-NORMALISER.cob  CRLF stripping, UTF-8/BOM/UTF-16/NUL/length validation
 │    ├── CSV-READER.cob         RFC 4180 finite-state-machine parser
 │    └── DATA-IMPORT.cob        Study init, demo fixture generator, ordered import pipeline
 ├── Validation Layer (src/validation/)
 │    ├── VALIDATE-STUDY.cob     study.csv schema & single-row enforcement
 │    ├── VALIDATE-SOURCES.cob   sources.csv schema & provenance date checks
 │    ├── VALIDATE-SITES.cob     sites.csv schema, IMPACT/CONTROL enum, area_ha > 0
 │    ├── VALIDATE-SURVEYS.cob   surveys.csv schema, O(log N) FKs, PRE/POST/TRANSITION
 │    ├── VALIDATE-OBSERVATIONS.cob  observations.csv schema, FK, count/status consistency
 │    └── DUPLICATE-DETECTION.cob    O(N log N) COBOL SORT duplicate detection & index builder
 ├── Evidence Ledger (src/ledger/)
 │    ├── EVIDENCE-LEDGER.cob    Append-only evidence-ledger.csv + SHA-256 adapter invocation
 │    └── RUN-RECEIPT.cob        Receipt verification & CSV reload for `fieldledger report`
 ├── Ecological Engine (src/ecology/)
 │    ├── EFFORT-STANDARDISER.cob    Rate = Count * 60 / Survey_Minutes + v1 observation model spec
 │    ├── SPECIES-AGGREGATOR.cob     Method non-pooling stratification & O(N log N) slice index
 │    └── SITE-SUMMARY.cob           Per-site PRE/POST means, missingness, coverage, exclusions
 ├── Statistical Analysis Engine (src/analysis/)
 │    ├── BACI-ENGINE.cob            Equal-site-weighted BACI orchestration
 │    ├── BOOTSTRAP-ENGINE.cob       Deterministic Park-Miller LCG site-cluster bootstrap
 │    ├── UNCERTAINTY-ENGINE.cob     Small-sample (<5 sites/group) CI withholding policy
 │    └── SENSITIVITY-ENGINE.cob     Leave-one-site-out (LOSO) site-leverage analysis
 └── Reporting Layer (src/reporting/)
      ├── CSV-REPORTER.cob           validation-report.csv, data-quality.csv, baci-results.csv, site-summaries.csv
      ├── JSON-REPORTER.cob          RFC 8259 escaped research-receipt.json
      ├── MARKDOWN-REPORTER.cob      GitHub-readable report.md
      └── HTML-REPORTER.cob          Self-contained offline report.html with inline SVG
```

## 2. Numeric Precision & Representation

All scientific quantities use explicit COBOL fixed-point decimal (`COMP-3` packed decimal) definitions, avoiding binary floating-point rounding drift in reported summaries:

| Quantity | COBOL Picture | Usage | Valid Input Range / Notes |
|---|---|---|---|
| `count` | `PIC S9(9)` | `COMP-3` | Non-negative integer `0` to `999,999,999` |
| `survey_minutes` | `PIC S9(7)V9(4)` | `COMP-3` | Strictly positive `> 0`, up to 7 int / 4 decimal digits |
| `area_ha` | `PIC S9(9)V9(4)` | `COMP-3` | Strictly positive `> 0`, up to 9 int / 4 decimal digits |
| Observation rate, site means, BACI, CI, LOSO | `PIC S9(11)V9(6)` | `COMP-3` | 6 decimal places (`ROUNDED` on division) |
| Intermediate rate/change sums | `PIC S9(15)V9(6)` | `COMP-3` | Overflow-safe summation across up to 250,000 rows |
| Coverage percentage | `PIC S9(5)V9(2)` | `COMP-3` | `0.00` to `100.00` |
| Indices, counters, ordinal days | `PIC 9(9)` | `COMP-5` | Native binary integer |
| Park-Miller PRNG & scaled bootstrap micro-sums | `PIC S9(18)` | `COMP-5` | 64-bit signed integer; exact micro-unit scaling (`× 10^6`) |

## 3. Documented Resource Limits & Algorithmic Complexity

Explicit capacity constants in `copybooks/LIMITS.cpy` are checked on every record load. Exceeding any limit triggers `RESOURCE_LIMIT` (`exit code 4`) without silent truncation:

| Resource | v1.0.0 Limit | Memory Footprint (approx.) | Complexity |
|---|---:|---:|---|
| Sites (`sites.csv`) | 2,000 | ~0.5 MB | O(N log N) sort / O(log N) FK lookup |
| Sources (`sources.csv`) | 10,000 | ~8.8 MB | O(N log N) sort / O(log N) FK lookup |
| Surveys (`surveys.csv`) | 50,000 | ~19 MB | O(N log N) sort / O(log N) FK lookup |
| Observations (`observations.csv`) | 250,000 | ~42 MB | O(N log N) duplicate & stratum indexing |
| Distinct `(species, method)` strata | 2,000 | ~3.5 MB | Contiguous slice scan per stratum |
| Validation issues stored in memory | 50,000 | ~17 MB | Tracked overflow counter beyond 50,000 |
| Bootstrap replicates | 100 – 100,000 | ~1 MB | O(B · (N_imp + N_ctrl) + B log B) |
| Max CSV line length | 4,094 bytes | — | Rejected cleanly if exceeded |

Total static `EXTERNAL` working-storage footprint is approximately **92 MB**, avoiding heap fragmentation and Windows thread stack overflow.

## 4. Future Detection-Probability Extension Interface (Section 11)

FIELDLEDGER explicitly models the separation between:

1. **Underlying ecological state** (true occupancy $\psi$ or true abundance $N$)
2. **Observation process** (survey effort `survey_minutes`, protocol `method`, observer `observer_id`, detection probability $p$)
3. **Recorded observation** (`count`, `observation_status = DETECTED | NOT_DETECTED`, or explicit missingness)

In Version 1, `copybooks/BACI-RESULT.cpy` defines the `DET-MODEL-SPEC` record populated by `EFFORT-STANDARDISER.cob` and exported into `research-receipt.json`:

- `DMS-MODEL-ID = "EFFORT_RATE_V1"`
- `DMS-STATE-ESTIMATED = "OBSERVATION_RATE_ONLY"`
- `DMS-DETECTION-CORR = "FALSE"`
- `DMS-OCCUPANCY-HOOK = "OCCUPANCY_EXT_V2"`

Because `SURVEY-STORE` and `OBS-STORE` already preserve per-visit survey effort, observer identity, method, explicit non-detections, and visit-level missingness without collapsing visits before aggregation, a Version 2 repeated-visit occupancy or N-mixture module (`OCCUPANCY-ENGINE.cob`) can consume the same validated `EXTERNAL` stores without rewriting ingestion, validation, ledger, or reporting subsystems.

## 5. Measured Performance Benchmarks

Real measured timings on this machine (**Snapdragon X Plus (8-core) @ 3.30 GHz**, 16 GB RAM, Windows 11, `cobc (GnuCOBOL) 3.2.0`, flags `-free -Wall -O2 -I copybooks`) via `tests/integration/benchmark.ps1` and `tests/integration/BENCHMARK.cob`:

| Stage | 50,000 obs (100 sites, 2,000 surveys, 25 spp, B=2,000) | 250,000 obs (200 sites, 10,000 surveys, 25 spp, B=2,000) |
|---|---:|---:|
| Stage 1: CSV Ingestion + UTF-8 + Validation + O(log N) FK | 1,840 ms | 15,740 ms |
| Stage 2: O(N log N) Observation Duplicate Detection (ID + composite key) | 50 ms | 510 ms |
| Stage 3: Effort Standardisation + O(N log N) Species/Method Aggregation | 70 ms | 410 ms |
| Stage 4: BACI + Site-Cluster Bootstrap + LOSO Sensitivity | 7,760 ms | 39,910 ms |
| Stage 5: CSV + JSON + Markdown + HTML + Ledger Reports | 100 ms | 230 ms |
| **Total End-to-End** | **9,820 ms** | **56,800 ms** |

All benchmark runs reported `errors=0` and produced complete verified output bundles.

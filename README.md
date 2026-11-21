# FIELDLEDGER

**Ecological Evidence, Intervention & Accountability Engine**

A COBOL-first scientific computing platform for validating ecological observations, preserving research provenance, analysing environmental trends, and evaluating ecological interventions through reproducible statistical experiments.

---

## 1. Project Identity

FIELDLEDGER transforms fragmented ecological observations into structured, traceable, and independently reproducible research outputs. Its core objective is end-to-end auditability from the raw field observation to the reported intervention estimate, built in structured free-format COBOL with fixed-point decimal arithmetic (`COMP-3`).

FIELDLEDGER is scientific data infrastructure — not a general-purpose AI tool. It operates **100% offline**, requires **no cloud account, paid API, or GPU**, and ships zero external JavaScript or CDN dependencies in its generated reports.

---

## 2. The Research Problem

Ecological and biodiversity evaluations routinely merge datasets collected across organisations, survey periods, instruments, and protocols, creating recurring failure modes:

1. Inconsistent survey durations and measurement effort across sites.
2. Absent species records silently treated as zero counts.
3. Incompatible observation methods pooled without justification.
4. Unrecorded data filtering, exclusions, or transformations.
5. Confounding external environmental trends mistaken for intervention effects.
6. Non-reproducible statistical resampling and opaque calculations.
7. Reported conclusions disconnected from their source observations and input files.

FIELDLEDGER addresses these systematically using strict pre-analysis validation, explicit missingness accounting, equal-site-weighted Before-After-Control-Impact (BACI) estimation, deterministic site-cluster bootstrap uncertainty, SHA-256 input manifests, append-only run ledgers, and verifiable research receipts.

---

## 3. Core Design Principles

1. **Evidence before conclusions** — No statistical output is generated if validation fails.
2. **Missing is not zero** — Absent species rows are tracked as missingness and never converted into zero counts; true zeros must be explicitly recorded as `count = 0` with `observation_status = NOT_DETECTED`.
3. **Reproducibility** — Every run records dataset identity, configuration, compiler version, deterministic PRNG seed, manifest status, and output references in `research-receipt.json` and `evidence-ledger.csv`.
4. **Explicit uncertainty** — Nominal 95% site-cluster bootstrap intervals are reported only when at least 5 complete independent sites exist per group; smaller samples withhold inferential intervals with an explicit warning. P-values are never manufactured.
5. **Transparent calculations** — Every rate, site mean, exclusion reason, and sensitivity bound is written to inspectable CSV tables and fixed-point decimal arithmetic is fully documented.
6. **No scientific overclaiming** — Observational BACI estimates are never presented as proof of causation, and effort-standardised detection rates are never presented as true abundance.

---

## 4. Architecture

All scientific computation, CSV ingestion, validation, BACI estimation, bootstrap resampling, sensitivity analysis, provenance ledger management, and report generation are implemented in **28 modular free-format GnuCOBOL source files** sharing **12 COPYBOOKS**:

- `src/main.cob` — Top-level CLI orchestrator.
- `src/core/` — `CONFIGURATION`, `ERROR-HANDLING`, `COMMAND-PARSER`, `DATE-UTILS`, `NUMERIC-UTILS`.
- `src/ingestion/` — `RECORD-NORMALISER` (strict UTF-8/BOM/CRLF checks), `CSV-READER` (RFC 4180 finite-state parser), `DATA-IMPORT`.
- `src/validation/` — `VALIDATE-STUDY`, `VALIDATE-SOURCES`, `VALIDATE-SITES`, `VALIDATE-SURVEYS`, `VALIDATE-OBSERVATIONS`, `DUPLICATE-DETECTION` (O(N log N) COBOL `SORT`).
- `src/ledger/` — `EVIDENCE-LEDGER` (append-only run ledger + OS SHA-256 adapter bridge), `RUN-RECEIPT` (receipt verification & reload).
- `src/ecology/` — `EFFORT-STANDARDISER`, `SPECIES-AGGREGATOR` (method non-pooling stratification), `SITE-SUMMARY`.
- `src/analysis/` — `BACI-ENGINE`, `BOOTSTRAP-ENGINE` (Park-Miller LCG site-cluster resampling), `UNCERTAINTY-ENGINE`, `SENSITIVITY-ENGINE` (leave-one-site-out).
- `src/reporting/` — `CSV-REPORTER`, `JSON-REPORTER`, `MARKDOWN-REPORTER`, `HTML-REPORTER` (self-contained offline HTML5 + inline SVG).
- `scripts/` — Cross-platform build, test, and OS-native SHA-256 integrity adapters (`PowerShell Get-FileHash` on Windows; `sha256sum` / `shasum -a 256` on Linux/macOS).

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for memory layouts, numeric precision specifications, and the Version 2 detection-probability extension interface.

---

## 5. Language & Compiler Requirements

- **Primary language:** Modern structured free-format COBOL (`>>SOURCE FORMAT FREE`).
- **Verified compiler:** `cobc (GnuCOBOL) 3.2.0` (built with GCC/MinGW-w64 UCRT64 on Windows; compatible with GnuCOBOL 3.1+ / 3.2+ on Linux and macOS).
- **Compiler flags:** `-free -Wall -O2 -I copybooks`.
- **Official GnuCOBOL resources:**
  - https://gnucobol.sourceforge.io/
  - https://gnucobol.sourceforge.io/documentation.html

---

## 6. Build Instructions

### Windows (PowerShell)

```powershell
.\scripts\build.ps1
```

`build.ps1` auto-detects `cobc.exe` in `PATH` or MSYS2 (`C:\msys64\ucrt64\bin`), configures GnuCOBOL environment variables, compiles all 28 modules with `-free -Wall -O2`, links `build\fieldledger.exe`, and stages the MinGW runtime DLLs into `build\`.

### Linux / macOS (POSIX sh)

```sh
./scripts/build.sh
```

Produces `build/fieldledger`. See [docs/BUILD-INSTRUCTIONS.md](docs/BUILD-INSTRUCTIONS.md) for installing GnuCOBOL and packaging releases.

---

## 7. Demonstration & CLI Commands

```powershell
# Display commands, limits, and scientific limitations
.\build\fieldledger.exe help

# Initialise a new study directory with documented CSV templates
.\build\fieldledger.exe init --study ./my-study

# Run the built-in synthetic wetland demonstration end-to-end
.\build\fieldledger.exe demo --out ./output/demo

# Generate and verify a SHA-256 input integrity manifest
.\build\fieldledger.exe manifest --study examples/wetland-demo
.\build\fieldledger.exe verify --study examples/wetland-demo

# Validate a study dataset only
.\build\fieldledger.exe validate --study examples/wetland-demo --out output/val

# Execute BACI analysis with deterministic seed and bootstrap iterations
.\build\fieldledger.exe analyze baci `
  --study examples/wetland-demo `
  --out output/wetland-demo `
  --seed 20261120 `
  --bootstrap 2000

# Optional filters
.\build\fieldledger.exe analyze baci `
  --study tests/fixtures/multi-method `
  --out output/filtered `
  --species SP001 `
  --method point_count `
  --no-color

# Regenerate Markdown and HTML reports strictly from a verified research receipt
.\build\fieldledger.exe report --study examples/wetland-demo --out output/wetland-demo
```

### Offline Graphical Workbench (GUI)

FIELDLEDGER includes a zero-dependency local GUI workbench (`gui/server.mjs` + `gui/public/`) that invokes the compiled GnuCOBOL binary directly and renders its real CSV, JSON, manifest, and HTML outputs offline without duplicating scientific computation in JavaScript:

```powershell
# Windows (starts http://127.0.0.1:4173; add -OpenBrowser to launch browser automatically)
.\scripts\gui.ps1 -OpenBrowser
```

```sh
# Linux / macOS
./scripts/gui.sh
```

For `examples/wetland-demo` (explicitly synthetic reference fixture with 2 Impact and 2 Control sites), FIELDLEDGER calculates:

- Impact mean change: `+8.000000` detections/hour
- Control mean change: `+2.000000` detections/hour
- **BACI estimate:** `+6.000000` detections/hour
- **95% Bootstrap CI:** `WITHHELD` (`< 5` complete independent sites per group)

An example generated report bundle is included in `output/wetland-demo/`.

---

## 8. Input Data Schemas

Each study directory contains five UTF-8 RFC 4180 CSV files:

| File | Required Header | Key Rules |
|---|---|---|
| `study.csv` | `study_id,study_title,study_design,primary_outcome,primary_outcome_unit,study_description` | Exactly 1 metadata row in v1. |
| `sources.csv` | `source_id,source_type,source_title,organisation,citation,source_url,licence,accessed_date` | Unique `source_id`, valid ISO 8601 `accessed_date`. |
| `sites.csv` | `site_id,site_role,reference_date,area_ha,habitat_type,region_code` | Unique `site_id`, role strictly `IMPACT` or `CONTROL`, valid `reference_date`, `area_ha > 0`. |
| `surveys.csv` | `survey_id,site_id,survey_date,survey_minutes,method,observer_id,source_id` | Unique `survey_id`, valid FKs to `sites` and `sources`, valid ISO 8601 `survey_date`, `survey_minutes > 0`. |
| `observations.csv` | `observation_id,survey_id,species_code,count,observation_status` | Unique `observation_id` & `(survey_id, species_code)`, valid FK to `surveys`, `DETECTED => count > 0`, `NOT_DETECTED => count = 0`. |

Full field definitions and precision limits are documented in [docs/DATA-DICTIONARY.md](docs/DATA-DICTIONARY.md).

---

## 9. Output Descriptions

| Output File | Description |
|---|---|
| `validation-report.csv` | Every validation error, warning, and info record with severity, code, file, row, field, and explanation. |
| `data-quality.csv` | Valid/rejected counts, duplicates, PRE/POST/TRANSITION exclusions, explicit zeros, missing cells, coverage %, and manifest status. |
| `baci-results.csv` | Per-`(species_code, method)` BACI estimates, site counts, means, missingness, bootstrap CI status/bounds, LOSO sensitivity range, and warnings. |
| `site-summaries.csv` | Per-site PRE/POST survey and observation counts, means, site changes, coverage %, and explicit exclusion status (`COMPLETE`, `NO_PRE_OBSERVATIONS`, etc.). |
| `research-receipt.json` | Strictly valid JSON provenance receipt recording software/compiler version, configuration, manifest reference, seed, counts, warnings, and outputs. |
| `evidence-ledger.csv` | Append-only run audit log across repeated executions in the output directory. |
| `report.md` | GitHub-readable scientific report with methodology, results, warnings, and limitations. |
| `report.html` | Self-contained offline HTML5 report with inline SVG chart and strict HTML escaping. |

---

## 10. Test & Benchmark Instructions

### Run Automated Test Suite

```powershell
# Windows (runs 19 native COBOL unit assertions + 37 integration/statistical/integrity tests)
.\scripts\test.ps1

# Linux / macOS
./scripts/test.sh
```

### Run Per-Stage Performance Benchmarks

```powershell
.\tests\integration\benchmark.ps1 -Sites 100 -SurveysPerSite 20 -SpeciesCount 25 -Bootstrap 2000
```

Documented v1.0.0 capacity limits: **2,000 sites**, **50,000 surveys**, **250,000 observations**, **10,000 sources**, **2,000 species strata**, **100–100,000 bootstrap iterations**. Exceeding a limit raises a clear `RESOURCE_LIMIT` error rather than truncating data. See [docs/TESTING.md](docs/TESTING.md) for measured benchmark results.

---

## 11. Statistical Methodology & Scientific Limitations

- **Effort-Standardised Rate:** $\text{Rate} = \text{Count} \times 60 / \text{Survey\_Minutes}$ (`detections_per_hour`) in fixed-point `COMP-3` (`S9(11)V9(6) ROUNDED`).
- **Equal-Site-Weighted BACI:** $\text{BACI} = \overline{\Delta}_{\text{Impact}} - \overline{\Delta}_{\text{Control}}$, where each complete site contributes $\Delta_s = \overline{\text{Rate}}_{s,\text{POST}} - \overline{\text{Rate}}_{s,\text{PRE}}$.
- **Site-Cluster Bootstrap:** Park-Miller LCG (`a = 16807, m = 2147483647`) resampling independent complete sites with replacement; 95% percentile intervals (2.5th–97.5th) reported only when $n_{\text{Impact}} \ge 5$ and $n_{\text{Control}} \ge 5$.
- **Critical Limitations:** Version 1 measures observation rates — **not** true ecological abundance and **not** detection-probability-corrected occupancy. BACI estimates do **not** prove causation without defensible control comparability and parallel-trends assumptions.

See [docs/SCIENTIFIC-METHODOLOGY.md](docs/SCIENTIFIC-METHODOLOGY.md) and [docs/STATISTICAL-LIMITATIONS.md](docs/STATISTICAL-LIMITATIONS.md).

---

## 12. Roadmap & Research Programme

- [docs/RESEARCH-ROADMAP.md](docs/RESEARCH-ROADMAP.md) — Version 2 detection-probability/occupancy models, spatial diagnostics, and ecosystem integration.
- [research/HYPOTHESES.md](research/HYPOTHESES.md) — Falsifiable research hypotheses (H1–H3).
- [research/EXPERIMENT-DESIGN.md](research/EXPERIMENT-DESIGN.md) — Experimental design and intended research paper outline.
- [research/VALIDATION-PROTOCOL.md](research/VALIDATION-PROTOCOL.md) — Independent verification protocol.
- [docs/DEVELOPMENT-LOG.md](docs/DEVELOPMENT-LOG.md) — Phase-by-phase engineering and test log.

---

## Licence

Released under the [MIT License](LICENSE).

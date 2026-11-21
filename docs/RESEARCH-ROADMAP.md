# FIELDLEDGER Research & Engineering Roadmap

## Version 1.0.0 (Delivered)

- Complete free-format GnuCOBOL scientific data validation, provenance ledger, effort-standardised BACI estimation, deterministic site-cluster bootstrap, leave-one-site-out sensitivity analysis, OS-native SHA-256 manifests, verified research receipts, and self-contained offline Markdown/HTML/CSV/JSON reporting.
- Explicit observation-process hook (`DET-MODEL-SPEC` in `copybooks/BACI-RESULT.cpy`) documenting the `EFFORT_RATE_V1` boundary.

## Version 1.1 (Planned: Diagnostics & Scale)

- **Pre-intervention parallel-trends diagnostic:** When ≥2 pre-intervention time windows exist per site, quantify pre-period trend divergence between Impact and Control groups and report explicit parallel-trend diagnostic warnings.
- **Observer-effect stratification & diagnostic report:** Summarize detection-rate shifts across `observer_id` changes between PRE and POST periods.
- **Indexed file / streaming mode (BDB / external merge):** Extend capacity beyond the in-memory v1 limits (250,000 observations) using GnuCOBOL indexed files or disk-backed COBOL `SORT` for million-row national monitoring archives.

## Version 2.0 (Planned: Detection-Probability & Occupancy Modelling)

- **Repeated-visit occupancy engine (`OCCUPANCY-ENGINE.cob`):** Leverage the preserved per-visit effort (`survey_minutes`), observer (`observer_id`), method, explicit `NOT_DETECTED` records, and missing-visit structure to fit single-season and dynamic MacKenzie-style occupancy models separating occupancy probability ($\psi$) from detection probability ($p$).
- **N-mixture abundance estimation (`NMIXTURE-ENGINE.cob`):** Extend beyond detection rates for repeated count protocols where closure assumptions hold.
- **Covariate support (`covariates.csv`):** Optional environmental and detection covariates (weather, water level, vegetation cover) with full schema validation and provenance tracking.

## Version 2.1 (Planned: Ecosystem & Independent Auditing)

- **Cryptographically signed receipt bundles:** Optional detached OpenPGP / Sigstore signature verification adapters kept cleanly outside the COBOL scientific engine.
- **Read-only static dashboard consumer:** Optional external viewer consuming `baci-results.csv`, `site-summaries.csv`, and `research-receipt.json` without compromising the COBOL-first offline architecture.
- **Cross-implementation verification suite:** Automated numerical cross-checks of COBOL outputs against independent reference calculations in R for statistical validation papers.

# FIELDLEDGER Independent Validation & Audit Protocol

This protocol enables an independent reviewer or researcher to audit a completed FIELDLEDGER analysis from raw study files through final reports without trusting prior console output or summary prose.

---

## Step 1 — Verify Toolchain & Clean Build

1. Record OS, CPU architecture, and GnuCOBOL compiler version (`cobc --version`).
2. Perform a clean build from source:
   - Windows: `.\scripts\build.ps1 -Clean`
   - Linux/macOS: `./scripts/build.sh --clean`
3. Run the automated verification suite (`.\scripts\test.ps1` or `./scripts/test.sh`) and confirm 0 failed assertions across unit, regression, statistical, validation-rejection, and integrity tests.

---

## Step 2 — Verify Input Dataset Integrity

1. Locate the study directory `<STUDY>` and its archived `manifest.sha256`.
2. Execute:
   ```powershell
   .\build\fieldledger.exe verify --study <STUDY>
   ```
3. Confirm exit code `0` and inspect that every required input file (`study.csv`, `sources.csv`, `sites.csv`, `surveys.csv`, `observations.csv`) matched both SHA-256 digest and byte size.
4. Inspect `sources.csv` manually to confirm provenance metadata and whether the dataset is empirical or synthetic.

---

## Step 3 — Inspect Research Receipt & Re-Run Analysis

1. Inspect the archived `research-receipt.json` to extract:
   - `study_id`
   - `analysis_configuration.species_filter` and `active_method`
   - `bootstrap_configuration.seed` and `iterations`
2. Re-execute the identical analysis into a fresh clean directory `<AUDIT_OUT>`:
   ```powershell
   .\build\fieldledger.exe analyze baci `
     --study <STUDY> `
     --out <AUDIT_OUT> `
     --seed <SEED> `
     --bootstrap <ITERATIONS>
   ```
   *(Include `--species` and `--method` if set in `research-receipt.json`.)*
3. Confirm exit code `0` and check `validation-report.csv` for zero `ERROR` rows.

---

## Step 4 — Verify Numerical & Provenance Reproduction

1. Compare `<AUDIT_OUT>/baci-results.csv` and `<AUDIT_OUT>/site-summaries.csv` byte-for-byte against the original published outputs. Every reported 6-decimal quantity (including `baci_estimate`, `ci_95_low`, `ci_95_high`, `loso_min_baci`, `loso_max_baci`) must match identically.
2. Verify `data-quality.csv` to audit:
   - Rejected records (`records_rejected_total`)
   - Excluded same-day transition surveys/observations
   - Explicit zero counts (`NOT_DETECTED`) vs. missing species-survey cells
   - Overall species coverage percentage
3. Confirm that small-sample strata ($<5$ complete sites in either group) report `ci_status = WITHHELD` with `NA` interval bounds.
4. Test verified report regeneration:
   ```powershell
   .\build\fieldledger.exe report --study <STUDY> --out <AUDIT_OUT>
   ```
   and confirm `report.md` and `report.html` match the numerical tables in `baci-results.csv` and `site-summaries.csv`.

---

## Step 5 — Scientific Interpretation Checklist

Before citing any FIELDLEDGER output in a research publication, confirm:

- [ ] Reported quantities are explicitly described as effort-standardised observation rates (`detections_per_hour`), not true population size.
- [ ] Causal claims are NOT asserted solely from the BACI estimate without separate justification of control suitability and parallel trends.
- [ ] Missingness, site exclusions (`site-summaries.csv`), method stratification, and LOSO site-leverage bounds are disclosed alongside the point estimate.
- [ ] `manifest.sha256`, `research-receipt.json`, `baci-results.csv`, and `evidence-ledger.csv` are archived together with the exact software and GnuCOBOL versions.

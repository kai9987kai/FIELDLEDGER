# FIELDLEDGER Research Programme: Formal Hypotheses

This document defines three formal, falsifiable hypotheses guiding the empirical evaluation of FIELDLEDGER. None of these hypotheses is assumed to be true; each experimental design is constructed to detect null effects or counter-evidence where FIELDLEDGER offers no measurable improvement over standard ad-hoc analytical pipelines.

---

## Hypothesis H1 — Evidence Integrity

**Statement:** Explicit pre-analysis schema/referential/duplicate validation and SHA-256 provenance tracking reduce the probability that malformed, duplicated, or altered ecological records contaminate reported intervention estimates compared with standard unvalidated spreadsheet or script-based workflows.

- **Experimental Question:** Does enforcing FIELDLEDGER's blocking validation pipeline and SHA-256 manifest verification lower the rate of undetected data-corruption errors propagating into final BACI estimates compared with baseline ad-hoc analysis scripts?
- **Null Hypothesis ($H_0$):** The proportion of seeded data-integrity defects (broken foreign keys, duplicate records, invalid dates, inconsistent detection statuses, malformed CSV rows, and post-ingestion file mutations) that silently enter final reported BACI estimates does not differ between FIELDLEDGER and standard ad-hoc analysis pipelines (or FIELDLEDGER provides no reduction in silent contamination).
- **Alternative Hypothesis ($H_1$):** FIELDLEDGER yields a strictly lower rate of silent defect propagation into reported BACI estimates than baseline pipelines, with explicit error localisation (file, row, field).
- **Independent Variables:**
  1. Pipeline type: `FIELDLEDGER` (blocking validation + SHA-256 manifest verification) vs. `Baseline` (typical permissive CSV-import + regression/mean-difference scripts lacking blocking referential/status checks and manifest verification).
  2. Defect class and prevalence: seeded FK errors, duplicate keys, invalid calendar dates, `DETECTED`/`NOT_DETECTED` mismatches, malformed RFC 4180 quotes, and post-manifest file tampering.
- **Dependent Variables:**
  1. Silent contamination rate (fraction of corrupted datasets producing an unflagged BACI point estimate).
  2. Defect detection sensitivity (true positive rate) and localisation accuracy (correct file/row/field attribution).
  3. False-rejection rate on clean datasets.
- **Confounding Factors:**
  - Analyst experience and manual pre-cleaning effort prior to running baseline scripts.
  - Strictness of the chosen baseline script (an overly naive baseline could exaggerate FIELDLEDGER's advantage; a heavily engineered non-COBOL baseline could match it).
  - Real-world defect classes not represented in the seeded fault library (e.g., taxonomic misidentification or plausible-but-wrong numeric typos that pass schema checks).
- **Experimental Design:** Controlled fault-injection benchmark across $K$ clean synthetic and real ecological datasets with systematically injected single- and multi-defect perturbations evaluated blindly across FIELDLEDGER and multiple realistic baseline pipelines (including well-written R/Python data-cleaning scripts, not straw-man baselines).
- **Metrics:** Silent contamination rate (%), defect recall (%), localisation precision (%), false-alarm rate (%), and absolute bias $|\widehat{\text{BACI}}_{\text{corrupted}} - \widehat{\text{BACI}}_{\text{true}}|$ among unflagged runs.
- **Validation Dataset:** Expanded synthetic fault-injection suite seeded from `tests/fixtures/` plus curated open ecological monitoring datasets with blinded fault injection (clearly separating synthetic from empirical corpora).
- **Falsification Conditions:** $H_1$ is falsified if:
  1. FIELDLEDGER fails to block any schema/referential/duplicate/tamper defect within its documented specification; or
  2. Standard well-maintained R/Python validation pipelines achieve equal or lower silent contamination rates with lower analyst overhead, showing FIELDLEDGER offers no net integrity improvement; or
  3. Blocking validation induces excessive false rejections on legitimately formatted ecological archives without improving downstream estimate accuracy.
- **Known Limitations:** Schema and hash checks cannot detect domain-level errors that are syntactically valid (e.g., misidentifying species A as species B, or recording `18` instead of `81`).

---

## Hypothesis H2 — Observation-Process Awareness

**Statement:** Explicitly separating recorded observations (`DETECTED` vs. explicit `NOT_DETECTED`) from unobserved site-surveys (missingness) and stratifying incompatible observation methods reduces systematic bias in BACI estimates compared with pipelines that impute absent species rows as zero and pool mixed survey methods.

- **Experimental Question:** Under varying rates of partial survey reporting (missing species rows) and heterogeneous survey protocols, does FIELDLEDGER's missing-is-not-zero and method-stratification discipline reduce BACI estimation bias relative to zero-fill/pooled pipelines?
- **Null Hypothesis ($H_0$):** Mean absolute error (MAE) and signed bias of BACI point estimates relative to ground-truth simulated intervention effects do not differ between FIELDLEDGER (explicit non-zero missingness + method stratification) and conventional zero-fill / pooled-method pipelines.
- **Alternative Hypothesis ($H_1$):** Under missing-at-random (MAR) or differential-reporting missingness and mixed-method surveys, FIELDLEDGER exhibits lower BACI estimation bias than zero-fill and pooled-method pipelines.
- **Independent Variables:**
  1. Missingness mechanism: true absences explicitly logged vs. incomplete reporting (MCAR, MAR by period, or MNAR).
  2. Missingness rate ($0\%, 10\%, 25\%, 50\%$ of species-survey cells omitted).
  3. Observation-method mixture (single method vs. mixed protocols with distinct detection efficiencies).
- **Dependent Variables:**
  1. Signed BACI bias ($\widehat{\text{BACI}} - \text{BACI}_{\text{true}}$).
  2. Root Mean Squared Error (RMSE) and Mean Absolute Error (MAE) of BACI estimates.
  3. Proportion of analyses surfacing explicit missingness/method warnings.
- **Confounding Factors:**
  - If an ecological dataset actually uses presence-only logging where *every* omitted row genuinely represents a verified zero-count survey (complete checklist protocol), refusing to zero-fill could discard true zeroes and introduce bias in the opposite direction!
  - Differential detectability $p$ changing between PRE and POST periods (which neither v1 effort-rate estimator nor simple zero-fill resolves without v2 occupancy modelling).
- **Experimental Design:** Monte Carlo simulation across factorial combinations of true intervention effects ($\{-5, 0, +6\}$), missingness mechanisms (including a critical adversarial regime where omissions *are* true non-detections under checklist protocols), and multi-method mixing.
- **Metrics:** Bias, RMSE, variance, coverage diagnostic accuracy, and method-separation fidelity.
- **Validation Dataset:** Parameterised synthetic simulation grids grounded in `tests/fixtures/missing-vs-zero/` and `tests/fixtures/multi-method/`.
- **Falsification Conditions:** $H_1$ is falsified if:
  1. Across realistic ecological reporting protocols (especially complete-checklist datasets where absent rows encode non-detection), refusing zero-imputation increases RMSE/bias compared with zero-fill; or
  2. Method stratification reduces sample size per stratum so severely that estimator variance dominates bias reduction, yielding higher overall RMSE than pooled or covariate-adjusted models.
- **Known Limitations:** Version 1 still measures effort-standardised observation rates rather than detection-corrected occupancy or abundance; thus H2 tests bias from missingness/pooling conflation, not full imperfect-detection correction.

---

## Hypothesis H3 — Reproducible Intervention Analysis

**Statement:** Combining matched experimental receipts, deterministic fixed-point decimal computation, deterministic site-cluster resampling, and small-sample CI withholding improves independent numerical reproducibility and inferential calibration compared with non-deterministic, observation-level resampling workflows.

- **Experimental Question:** Do FIELDLEDGER's deterministic site-cluster bootstrap, equal-site weighting, and small-sample CI withholding produce higher independent bit-exact reproduction rates and more accurate empirical 95% confidence interval coverage than observation-level bootstrap or survey-weighted pipelines?
- **Null Hypothesis ($H_0$):** Neither independent reproduction consistency nor empirical 95% CI coverage (under repeated-visit within-site autocorrelation and varying site counts $n \in \{2, 4, 6, 10, 20\}$) improves under FIELDLEDGER relative to observation-level resampling and floating-point workflows.
- **Alternative Hypothesis ($H_1$):** FIELDLEDGER achieves exact cross-run/cross-machine numerical reproducibility from recorded receipts and seeds, prevents anti-conservative CI under-coverage caused by treating repeated visits within a site as independent units, and prevents misleading small-sample intervals when $n < 5$ sites per group.
- **Independent Variables:**
  1. Resampling unit: `site-cluster` (FIELDLEDGER) vs. `individual survey/observation` (naive bootstrap).
  2. Weighting scheme: `equal independent sites` vs. `survey-count weighted`.
  3. Number of sites per group ($n \in \{2, 3, 5, 8, 15, 30\}$) and within-site intra-class correlation ($\rho \in \{0.0, 0.3, 0.7\}$).
  4. Execution environment (Windows x64 vs. Linux x64/ARM64 GnuCOBOL builds).
- **Dependent Variables:**
  1. Exact numerical match rate across independent replications using only `research-receipt.json` + dataset + seed.
  2. Empirical 95% CI coverage probability under known data-generating processes.
  3. Rate of spurious inferential intervals reported for underpowered designs ($n < 5$).
- **Confounding Factors:**
  - Site-cluster percentile bootstrap itself can under-cover at modest site counts ($n = 5$ to $8$) compared with studentised ($t$-bootstrap) or wild cluster bootstrap methods.
  - Under $\rho = 0$ (zero within-site correlation) and balanced survey effort, observation-level and site-level methods may behave similarly.
- **Experimental Design:**
  - *Part A (Reproducibility audit):* Independent analysts on distinct OS/hardware platforms reconstruct runs strictly from archived study files, `manifest.sha256`, and `research-receipt.json`.
  - *Part B (Coverage simulation):* Hierarchical synthetic BACI datasets with known within-site correlation $\rho$ and unbalanced survey counts comparing empirical CI coverage of site-cluster vs. observation-level bootstrap across 1,000 Monte Carlo replicates.
- **Metrics:** Exact decimal agreement rate (6 decimal places), empirical 95% CI coverage %, median interval width, false-certainty rate at $n < 5$.
- **Validation Dataset:** Synthetic hierarchical BACI simulations anchored on `tests/fixtures/unequal-surveys/` and `tests/fixtures/bootstrap-large/`.
- **Falsification Conditions:** $H_1$ is falsified if:
  1. Identical inputs, compiler configuration, and seeds fail to reproduce identical 6-decimal outputs across independent runs or platforms; or
  2. Site-cluster percentile bootstrap exhibits worse coverage/MSE than well-specified mixed-effects or wild-cluster alternatives at $n \ge 5$ without offsetting transparency gains; or
  3. Withholding CIs at $n < 5$ causes researchers to over-rely on point estimates rather than improving statistical caution.
- **Known Limitations:** Fixed-point decimal reproducibility guarantees identical computation given identical inputs and software version, not robustness to model misspecification or unmeasured confounding.

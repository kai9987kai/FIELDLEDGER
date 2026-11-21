# FIELDLEDGER Experiment Design & Intended Research Paper Outline

> **Status Notice:** This document describes the planned empirical evaluation protocol and intended manuscript structure for FIELDLEDGER. It is a **research plan and paper outline**, not a claim that empirical field evaluations or peer-reviewed results have already been completed.

---

## 1. Evaluation Experimental Designs

### Experiment E1 — Fault-Injection Integrity Study (Testing H1)
- **Design:** Take $M = 10$ clean baseline BACI datasets (synthetic + public open ecological datasets once curated) and inject 8 controlled fault classes (broken `site_id` FK, broken `source_id` FK, broken `survey_id` FK, duplicate `observation_id`, duplicate `(survey_id, species_code)`, invalid non-leap date, `DETECTED`/`count=0` contradiction, malformed CSV quote, and post-manifest 1-byte modification).
- **Arms:** (A) FIELDLEDGER v1.0.0; (B) permissive baseline R/Python mean-difference script; (C) defensively written R/Python schema-validated script.
- **Outcome:** Compare silent contamination rates, localisation accuracy, false-positive rejections, and analyst debugging time.

### Experiment E2 — Missingness & Method-Stratification Simulation (Testing H2)
- **Design:** Factorial Monte Carlo simulation ($3 \times 4 \times 3$ design: true BACI $\in \{-5, 0, +6\}$; missingness $\in \{0\%, 10\%, 25\%, 50\%\}$ across MCAR, period-biased MAR, and adversarial complete-checklist true-zero omissions; single vs. dual observation methods).
- **Arms:** (A) FIELDLEDGER v1.0.0 (`missing != zero`, method stratification); (B) zero-fill + method-pooled BACI; (C) zero-fill + method-stratified BACI.
- **Outcome:** Bias, RMSE, and explicit mapping of regimes where FIELDLEDGER outperforms *and* adversarial checklist regimes where explicit non-detection logging is required.

### Experiment E3 — Reproducibility & Cluster-Bootstrap Calibration Study (Testing H3)
- **Design:**
  1. **Cross-platform replication:** Build and run FIELDLEDGER on Windows x64 (MinGW UCRT64), Linux x86_64 (GCC), and Linux/macOS ARM64 using identical datasets, `manifest.sha256`, and `research-receipt.json` configurations; verify bit-identical 6-decimal outputs in `baci-results.csv`.
  2. **Coverage calibration:** Simulate hierarchical site-visit BACI studies with $n \in \{2, 4, 5, 8, 15, 30\}$ sites/group, unbalanced visits per site (1 to 10 surveys), and intra-site correlation $\rho \in \{0.0, 0.3, 0.7\}$; compare empirical 95% CI coverage between FIELDLEDGER's site-cluster bootstrap and observation-level resampling.

---

## 2. Intended Research Paper Outline

### Proposed Title
**"FIELDLEDGER: A COBOL-Based Framework for Auditable Ecological Evidence Processing and Reproducible Intervention Analysis"**

*(Intended manuscript outline — empirical evaluations E1–E3 remain to be executed before submission.)*

### Section Outline

1. **Abstract (Planned)**
   - Motivation: ecological intervention analyses frequently suffer from undocumented data cleaning, silent missing-as-zero imputation, pseudoreplication, and fragile reproducibility.
   - Contribution: architecture and open-source implementation of FIELDLEDGER in modern free-format GnuCOBOL using fixed-point decimal arithmetic (`COMP-3`), blocking validation, equal-site-weighted BACI, deterministic site-cluster bootstrap, SHA-256 input manifests, and verifiable research receipts.
   - Summary of empirical results from E1–E3 (to be populated strictly after running experiments).

2. **Introduction**
   - Accountability gaps in biodiversity and restoration monitoring.
   - Why fixed-point decimal record-processing architecture (COBOL) is a compelling, auditable substrate for long-lived scientific data infrastructure.
   - Research objectives and hypotheses H1–H3.

3. **Related Work**
   - Ecological BACI designs and causal-inference assumptions (parallel trends, control selection, spatial/temporal pseudoreplication).
   - Data validation frameworks, Darwin Core / ecological data standards, and computational reproducibility tools.
   - Observation-process modelling (effort standardisation vs. MacKenzie occupancy and N-mixture models).

4. **System Design & Mathematical Specification**
   - Six design principles (evidence before conclusions, missing is not zero, reproducibility, explicit uncertainty, transparent calculations, no scientific overclaiming).
   - Modular COBOL architecture (28 programs, 12 copybooks, O(N log N) sorting/indexing, explicit `COMP-3` precision).
   - Mathematical formulation: effort standardisation, `TRANSITION` exclusion, method non-pooling, equal-site weighting, Park-Miller site-cluster bootstrap with small-sample CI withholding, and leave-one-site-out sensitivity.
   - Provenance model: OS-native SHA-256 manifest adapters, `research-receipt.json`, append-only `evidence-ledger.csv`, and verified report regeneration.
   - Extension interface (`DET-MODEL-SPEC`) for Version 2 detection-probability modelling.

5. **Verification, Software Quality & Performance**
   - Unit, integration, statistical, regression, and integrity test architecture (actual verified counts).
   - Real measured stage-level throughput benchmarks up to 250,000 observations with hardware and compiler metadata.

6. **Planned Empirical Evaluation (E1, E2, E3)**
   - Pre-registered protocols, falsification criteria, and baseline comparisons from `research/HYPOTHESES.md`.
   - Placeholder for empirical results (explicitly unpopulated until experiments run).

7. **Discussion & Limitations**
   - Honest appraisal of Version 1 boundaries: observation rates vs. true abundance, unmodelled detection probability, causal assumptions beyond software validation, small-sample percentile bootstrap coverage, and local filesystem ledger boundaries.
   - Engineering trade-offs of GnuCOBOL for scientific software (portability, exact decimal semantics, ecosystem friction vs. Python/R).

8. **Conclusion & Roadmap**
   - Path toward Version 2 repeated-visit occupancy modelling and long-term archival ecological evidence stewardship.

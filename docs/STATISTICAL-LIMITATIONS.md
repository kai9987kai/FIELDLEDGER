# FIELDLEDGER Statistical & Scientific Limitations

FIELDLEDGER is designed for scientific accountability, which requires stating clearly what Version 1 **cannot** establish.

## 1. Observation Rates Are Not True Abundance

Version 1 (`EFFORT_RATE_V1`) computes detections per observer-hour (`Count * 60 / Survey_Minutes`). Detection counts are the joint outcome of true ecological state (presence/abundance) and the observation process (species detectability, observer skill, weather, vegetation density, equipment sensitivity). A higher observation rate does not automatically prove a higher true population size.

## 2. Imperfect Detection Probability Is Not Corrected in v1

A species can be present at a site during a survey and still be recorded as `NOT_DETECTED` (`count = 0`). Version 1 does not yet fit hierarchical occupancy or N-mixture detection-probability models. Instead, it preserves survey effort, observer identity, method, explicit zeroes, and visit-level missingness so repeated-visit detection modelling can be layered in Version 2 without altering the data model.

## 3. BACI Does Not Prove Causation

A positive or negative BACI estimate measures a **differential before-after change** between designated impact and control sites. Interpreting that estimate as a causal intervention effect depends on assumptions that software alone cannot verify:

- **Control suitability:** Control sites must represent a valid counterfactual for how impact sites would have evolved absent the intervention.
- **Parallel trends:** Absent intervention, impact and control groups would have followed parallel trajectories over time.
- **No differential confounding:** No unmeasured disturbance, land-use change, weather anomaly, or hydrological shift differentially affected one group after the intervention date.
- **No spillover / contamination:** Intervention effects must not leak into control sites (SUTVA).
- **Sampling comparability:** Detection efficiency and protocol execution must remain comparable across periods and groups.

## 4. Small-Sample Bootstrap Limitations

With fewer than 5 complete independent sites per group, nonparametric site-cluster bootstrap resampling draws from too few discrete combinations to yield reliable tail percentiles. FIELDLEDGER therefore withholds the 95% interval below 5 sites per group. Even at 5–10 sites per group, percentile bootstrap intervals can exhibit under-coverage relative to their nominal 95% level and should be interpreted alongside the site-level table and leave-one-site-out (LOSO) sensitivity bounds.

## 5. Confidence Intervals Do Not Remove Bias

A narrow bootstrap confidence interval reflects low between-site variance among the sampled sites — it does **not** correct selection bias, missing-not-at-random (MNAR) survey omissions, misclassified reference dates, or flawed experimental design.

## 6. Provenance & Verification Boundaries

- **Synthetic data:** All built-in examples (`examples/wetland-demo/`) and fixtures (`tests/fixtures/`) are explicitly synthetic test data, not empirical ecological findings.
- **Source URLs:** Storing a URL in `sources.csv` documents provenance metadata; FIELDLEDGER does not fetch or externally validate URLs.
- **Append-only ledger:** `evidence-ledger.csv` provides a structured local audit trail, not cryptographic tamper-proof immutability on a host filesystem where a user holds write privileges. Cryptographic file-integrity detection relies on externally archived `manifest.sha256` digests verified via OS SHA-256 tools.

# FIELDLEDGER Scientific Methodology

## 1. Effort Standardisation

Ecological surveys frequently vary in duration. For every validated observation $i$ linked to survey $v(i)$ with positive duration $m_{v(i)} > 0$ minutes, FIELDLEDGER computes the effort-standardised observation rate:

$$r_i = \frac{\text{count}_i \times 60}{m_{v(i)}}$$

Expressed in `detections_per_hour` using fixed-point packed decimal arithmetic (`PIC S9(11)V9(6) COMP-3 ROUNDED`). Explicit non-detection observations (`count = 0`, `observation_status = NOT_DETECTED`) yield $r_i = 0.000000$.

**Important:** $r_i$ is an effort-standardised observation rate, **not** an estimate of true population abundance and **not** corrected for imperfect detection probability.

---

## 2. Temporal Classification & Transition Exclusion

Each survey date $d_v$ is compared against its site's `reference_date` $d^{\text{ref}}_{s(v)}$ using exact proleptic Gregorian ordinal day numbers:

- `PRE`: $d_v < d^{\text{ref}}_{s(v)}$
- `TRANSITION`: $d_v = d^{\text{ref}}_{s(v)}$
- `POST`: $d_v > d^{\text{ref}}_{s(v)}$

Same-day `TRANSITION` surveys and their linked observations are **excluded** from the primary PRE/POST BACI calculation and explicitly counted in `data-quality.csv`, `baci-results.csv`, `site-summaries.csv`, and `research-receipt.json`.

---

## 3. Observation-Method Non-Pooling Discipline

Different survey methods (e.g., `point_count` vs. `acoustic_recorder`) have incompatible detection processes and effort curves. FIELDLEDGER **never silently pools** distinct methods:

- If `--method <METHOD>` is provided, only surveys matching that exact method are included, and the selection is recorded in `research-receipt.json`.
- If `--method` is omitted and the study contains a single method, that method is automatically recorded as `active_method`.
- If `--method` is omitted and multiple methods exist, FIELDLEDGER stratifies analysis independently by `(species_code, method)` and emits an explicit `MULTI_METHOD_STRATIFIED` warning.

---

## 4. Site-Level Aggregation & Missingness Accounting

For each `(species_code, method)` stratum and each site $s$:

- Let $S_{s,\text{PRE}}$ and $S_{s,\text{POST}}$ be the counts of eligible non-transition surveys at site $s$ using that method.
- Let $O_{s,\text{PRE}}$ and $O_{s,\text{POST}}$ be the counts of **explicit** observations of that species (both `DETECTED` and explicit `NOT_DETECTED`) in those surveys.
- Missing cells are tracked explicitly as:
  $$M_s = (S_{s,\text{PRE}} - O_{s,\text{PRE}}) + (S_{s,\text{POST}} - O_{s,\text{POST}})$$
- Species-record coverage is:
  $$\text{Coverage}_s = \frac{O_{s,\text{PRE}} + O_{s,\text{POST}}}{S_{s,\text{PRE}} + S_{s,\text{POST}}} \times 100\%$$
- Absent rows are **never** converted to zero. Site-period means average strictly over explicit observations:
  $$\bar{r}_{s,\text{PRE}} = \frac{1}{O_{s,\text{PRE}}} \sum_{i \in \text{PRE}(s)} r_i, \qquad \bar{r}_{s,\text{POST}} = \frac{1}{O_{s,\text{POST}}} \sum_{i \in \text{POST}(s)} r_i$$
- A site is `COMPLETE` if and only if $O_{s,\text{PRE}} \ge 1$ and $O_{s,\text{POST}} \ge 1$. Otherwise, the site is excluded from the group estimate with an explicit recorded reason (`NO_PRE_OBSERVATIONS`, `NO_POST_OBSERVATIONS`, `NO_OBSERVATIONS`, or `EXCLUDED_TRANSITION_ONLY`).
- For each complete site $s$, the site-level change is:
  $$\Delta_s = \bar{r}_{s,\text{POST}} - \bar{r}_{s,\text{PRE}}$$

---

## 5. Equal-Site-Weighted BACI Estimator

Let $\mathcal{I}$ be the set of $n_I$ complete `IMPACT` sites and $\mathcal{C}$ be the set of $n_C$ complete `CONTROL` sites for the stratum. If $n_I \ge 1$ and $n_C \ge 1$:

$$\overline{\Delta}_{\text{Impact}} = \frac{1}{n_I} \sum_{s \in \mathcal{I}} \Delta_s, \qquad \overline{\Delta}_{\text{Control}} = \frac{1}{n_C} \sum_{s \in \mathcal{C}} \Delta_s$$

$$\widehat{\text{BACI}} = \overline{\Delta}_{\text{Impact}} - \overline{\Delta}_{\text{Control}}$$

Each independent site receives equal weight ($1/n_I$ or $1/n_C$), preventing frequently surveyed sites from dominating the group estimate. If $n_I = 0$ or $n_C = 0$, the estimate is reported as `NA` (`calculable = N`) with explicit warnings.

---

## 6. Deterministic Site-Cluster Bootstrap

Repeated surveys within the same site are temporally correlated and are not independent sampling units. FIELDLEDGER therefore resamples **whole sites** with replacement:

1. Seed the Park-Miller linear congruential generator:
   $$X_{t+1} = (16807 \cdot X_t) \bmod 2147483647$$
   implemented in exact 64-bit integer arithmetic (`PIC S9(18) COMP-5`) with rejection sampling to eliminate modulo bias.
2. For each iteration $b = 1, \dots, B$ (default $B = 2{,}000$; configurable $100 \le B \le 100{,}000$):
   - Draw $n_I$ complete impact sites with replacement and compute $\overline{\Delta}^{(b)}_{\text{Impact}}$.
   - Draw $n_C$ complete control sites with replacement and compute $\overline{\Delta}^{(b)}_{\text{Control}}$.
   - Store $\widehat{\text{BACI}}^{(b)} = \overline{\Delta}^{(b)}_{\text{Impact}} - \overline{\Delta}^{(b)}_{\text{Control}}$.
3. Sort $\{\widehat{\text{BACI}}^{(b)}\}_{b=1}^{B}$ in ascending order via COBOL table `SORT` ($O(B \log B)$).
4. Extract the nominal 95% percentile interval at $p = 0.025$ and $p = 0.975$ using linear interpolation on order-statistic position $q = 1 + p(B - 1)$.

**Small-Sample Safeguard:** The 95% percentile interval is reported **only** when $n_I \ge 5$ and $n_C \ge 5$. When fewer than 5 complete independent sites exist in either group, `ci_status` is set to `WITHHELD`, bounds are reported as `NA`, and a `SMALL_SAMPLE_CI_WITHHELD` warning is recorded. FIELDLEDGER never manufactures p-values.

---

## 7. Leave-One-Site-Out (LOSO) Sensitivity Analysis

Whenever $n_I \ge 2$ and $n_C \ge 2$, `SENSITIVITY-ENGINE.cob` recalculates $\widehat{\text{BACI}}$ after dropping each complete impact and control site one at a time, reporting the minimum and maximum LOSO BACI estimates alongside the single most influential site ID. This exposes whether a headline BACI estimate is driven by a single outlier site.

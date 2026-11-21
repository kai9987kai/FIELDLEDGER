# FIELDLEDGER Data Dictionary

All input files must be **UTF-8 encoded** (UTF-16 and invalid UTF-8 byte sequences are rejected; UTF-8 BOM on line 1 is stripped with an `INFO` log entry), conform to **RFC 4180 CSV** (quoted fields, embedded commas inside quotes, escaped double quotes `""`), and match exact headers. Maximum line length is **4,094 bytes**.

---

## 1. Input Schemas (Study Directory)

### `study.csv`
Exactly **1 metadata row** is required in Version 1.

| Column | Type | Required | Constraints |
|---|---|---|---|
| `study_id` | String (≤64) | Yes | Non-empty study identifier; matched against `research-receipt.json` by `report`. |
| `study_title` | String (≤256) | Yes | Human-readable study title. |
| `study_design` | String (≤64) | Yes | Expected `BACI` (other values trigger a warning). |
| `primary_outcome` | String (≤128) | Yes | E.g. `species_observations`. |
| `primary_outcome_unit` | String (≤64) | Yes | E.g. `detections_per_hour`. |
| `study_description` | String (≤512) | No | Free-text description; synthetic studies must state they are synthetic. |

### `sources.csv`
Up to **10,000** provenance records.

| Column | Type | Required | Constraints |
|---|---|---|---|
| `source_id` | String (≤64) | Yes | Unique across `sources.csv`. |
| `source_type` | String (≤64) | Yes | E.g. `scientific_publication`, `government_dataset`, `environmental_monitoring`, `survey_dataset`, `synthetic_test_dataset`. |
| `source_title` | String (≤160) | Yes | Title of source dataset or publication. |
| `organisation` | String (≤128) | Yes | Issuing or collecting organisation. |
| `citation` | String (≤192) | No | Bibliographic citation. |
| `source_url` | String (≤192) | No | Recorded for provenance only — never claimed externally verified. |
| `licence` | String (≤64) | No | E.g. `CC-BY-4.0`, `MIT`, `OGL-3.0`. |
| `accessed_date` | ISO Date | Yes | Strict `YYYY-MM-DD` Gregorian calendar date. |

### `sites.csv`
Up to **2,000** study sites.

| Column | Type | Required | Constraints |
|---|---|---|---|
| `site_id` | String (≤64) | Yes | Unique across `sites.csv`. |
| `site_role` | Enum | Yes | Strictly `IMPACT` or `CONTROL`. |
| `reference_date` | ISO Date | Yes | Strict `YYYY-MM-DD` (intervention date for IMPACT; matched reference date for CONTROL). |
| `area_ha` | Decimal (`S9(9)V9(4)`) | Yes | Strictly `> 0`. |
| `habitat_type` | String (≤64) | Yes | Non-empty habitat descriptor. |
| `region_code` | String (≤64) | Yes | Non-empty region identifier. |

### `surveys.csv`
Up to **50,000** survey events.

| Column | Type | Required | Constraints |
|---|---|---|---|
| `survey_id` | String (≤64) | Yes | Unique across `surveys.csv`. |
| `site_id` | String (≤64) | Yes | Foreign key referencing existing `sites.csv::site_id`. |
| `survey_date` | ISO Date | Yes | Strict `YYYY-MM-DD`. Classified vs site `reference_date` as `PRE` (`<`), `TRANSITION` (`=`), or `POST` (`>`). |
| `survey_minutes` | Decimal (`S9(7)V9(4)`) | Yes | Strictly `> 0`. Used for effort standardisation. |
| `method` | String (≤64) | Yes | Observation protocol (distinct methods are never silently pooled). |
| `observer_id` | String (≤64) | Yes | Non-empty observer identifier. |
| `source_id` | String (≤64) | Yes | Foreign key referencing existing `sources.csv::source_id`. |

### `observations.csv`
Up to **250,000** observation records.

| Column | Type | Required | Constraints |
|---|---|---|---|
| `observation_id` | String (≤48) | Yes | Unique across `observations.csv`. |
| `survey_id` | String (≤48) | Yes | Foreign key referencing existing `surveys.csv::survey_id`. |
| `species_code` | String (≤32) | Yes | Composite `(survey_id, species_code)` must be unique. |
| `count` | Integer (`S9(9)`) | Yes | Non-negative integer `>= 0`. |
| `observation_status` | Enum | Yes | Strictly `DETECTED` (requires `count > 0`) or `NOT_DETECTED` (requires `count = 0`). |

> **Critical Semantic Rule:** An absent `(survey_id, species_code)` row means the species was **unrecorded / missing** during that survey, **NOT** zero. Explicit zeroes must be recorded with `count = 0` and `observation_status = NOT_DETECTED`.

---

## 2. Output Schemas

### `validation-report.csv`
`severity,code,file,row,field,message`

### `data-quality.csv`
`metric,category,value,notes` — records dataset counts, rejections, duplicates, PRE/POST/TRANSITION counts, explicit zeros, missing cells, overall coverage percentage, and manifest status.

### `baci-results.csv`
33 columns covering `species_code`, `method`, `unit`, `calculable`, complete & excluded site counts (`impact_sites`, `control_sites`, `excluded_impact_sites`, `excluded_control_sites`), group means & changes (`impact_pre_mean`, `impact_post_mean`, `control_pre_mean`, `control_post_mean`, `impact_change`, `control_change`, `baci_estimate`), effort/coverage/missingness (`surveys_used`, `surveys_eligible`, `observations_used`, `explicit_zero_observations`, `missing_observations`, `transition_excluded_observations`, `coverage_pct`), bootstrap uncertainty (`bootstrap_seed`, `bootstrap_iterations`, `bootstrap_replicates`, `ci_status`, `ci_95_low`, `ci_95_high`), leave-one-site-out sensitivity (`loso_status`, `loso_min_baci`, `loso_max_baci`, `loso_most_influential_site`), and `warnings`. Non-calculable estimates and withheld CI bounds are emitted explicitly as `NA`.

### `site-summaries.csv`
17 columns detailing per-`(species_code, method, site_id)` PRE/POST/TRANSITION survey and observation counts, explicit zeros, missing rows, PRE/POST mean rates, `site_change`, `coverage_pct`, and `status` (`COMPLETE`, `NO_PRE_OBSERVATIONS`, `NO_POST_OBSERVATIONS`, `NO_OBSERVATIONS`, or `EXCLUDED_TRANSITION_ONLY`).

### `research-receipt.json`
RFC 8259 JSON object containing `application`, `version`, `gnucobol_version`, `run_id`, `timestamp`, `study_id`, `study_title`, `analysis_type`, `validation_outcome`, `analysis_configuration`, `bootstrap_configuration`, `input_manifest`, `record_counts`, `result_files`, `baci_summary`, and `warnings`.

### `evidence-ledger.csv`
Append-only run history containing `run_id`, `timestamp`, software/compiler versions, `study_id`, command, paths, filters, seed, bootstrap iterations, record counts, validation outcome, manifest status, receipt reference, and generated filenames.

### `manifest.sha256`
Line-oriented SHA-256 digest file generated in the study directory containing header metadata (`dataset_id`, `generated_utc`, `algorithm: SHA-256`) and sorted `<sha256_hex>  <file_size_bytes>  <relative_path>` lines for every CSV file in the study.

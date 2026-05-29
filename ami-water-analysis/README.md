# AMI Water-Use Analytics — R + Snowflake

An end-to-end **Advanced Metering Infrastructure (AMI) analysis** project built
in **R / RStudio** on data managed in **Snowflake**. It ingests hourly interval
water-meter reads and produces an *AMI Program Implementation Assessment*:
water-use trends, automated anomaly detection (leaks, continuous use, meter
errors), customer segmentation, and non-revenue water (NRW) analysis — delivered
as reusable scripts, a knitted report, and an interactive dashboard.

> **Portfolio note.** This was built as a work sample for a Water Resources
> Analyst role. It runs on a realistic **synthetic** AMI dataset (no client data
> is exposed) and is fully reproducible. The *same* code reads from a live
> Snowflake warehouse when credentials are configured.

---

## Why this project

It demonstrates each core responsibility of the role, mapped to concrete code:

| Job responsibility | Where it lives |
|---|---|
| Process & manage AMI data in **RStudio and Snowflake** | `R/02_snowflake_connect.R`, `sql/` |
| Design/maintain **data workflows and scripts** | `R/00`–`R/05`, `R/05_analysis.R` pipeline |
| Analyze **water-use trends** from consumption data | `R/05_analysis.R`, `reports/ami_assessment.Rmd` |
| **Visualize** via dashboards, reports, presentations | `dashboard/app.R`, `reports/ami_assessment.Rmd` |
| **Anomaly detection** (leaks, continuous use, meter errors) — replicable across clients | `R/03_anomaly_detection.R` |
| **Customer classification** methods reusable across clients | `R/04_customer_classification.R` |
| Troubleshoot **data-quality issues**, identify gaps | meter-error/stuck detectors + `sql/03` data-quality screens |
| **Non-revenue water loss** analysis | NRW section in `R/05` & the report |

---

## Quick start (synthetic data — no Snowflake needed)

```r
# From the project root, in RStudio or R:

# 1. Install packages (first run only) — open R/00_setup.R and uncomment the
#    install_if_missing(...) lines, or:
install.packages(c("tidyverse","lubridate","scales","DBI","odbc","config",
                   "rmarkdown","shiny","DT"))

# 2. Generate the synthetic AMI dataset (writes to data/)
source("R/01_generate_synthetic_ami.R")        # or: Rscript R/01_generate_synthetic_ami.R

# 3. Run the full analysis pipeline (writes tables + figures to output/)
source("R/05_analysis.R")

# 4. Knit the assessment report  ->  reports/ami_assessment.html
rmarkdown::render("reports/ami_assessment.Rmd")

# 5. Launch the interactive dashboard
shiny::runApp("dashboard")
```

Scale the dataset up from the command line:

```bash
Rscript R/01_generate_synthetic_ami.R 250 120   # 250 meters, 120 days
```

---

## Project structure

```
ami-water-analysis/
├── R/
│   ├── 00_setup.R                  # packages, theme, paths
│   ├── 01_generate_synthetic_ami.R # realistic synthetic AMI data generator
│   ├── 02_snowflake_connect.R      # Snowflake (DBI/odbc) + local-CSV loader
│   ├── 03_anomaly_detection.R      # leak / continuous / stuck / meter-error detectors
│   ├── 04_customer_classification.R# behavioural features + rule-based & k-means
│   └── 05_analysis.R               # end-to-end pipeline -> output/
├── sql/
│   ├── 01_create_tables.sql        # Snowflake DDL (warehouse, schema, tables)
│   ├── 02_load_data.sql            # stage + COPY INTO bulk load
│   └── 03_analysis_queries.sql     # server-side analytical queries
├── reports/
│   └── ami_assessment.Rmd          # knitted HTML "AMI assessment" report
├── dashboard/
│   └── app.R                       # interactive Shiny dashboard
├── data/                           # generated synthetic CSVs (committed)
├── output/                         # result tables + figures (committed)
├── config.yml.example              # Snowflake config template
└── README.md
```

---

## The methods

### Anomaly detection (`R/03_anomaly_detection.R`)
Transparent, parameterized detectors — each returns one auditable row per meter,
so results are easy to explain to non-technical stakeholders and to re-tune per
client:

- **Leak** — detects a *sustained step-up in overnight minimum flow*, discounted
  by the meter's own seasonal demand growth (so legitimate steady commercial
  baseload and summer ramps don't trigger false alarms). Estimates wasted volume
  for prioritization.
- **Continuous use** — meter essentially never reads zero (running toilet, stuck
  valve, process load).
- **Stuck / zero meter** — long run of identical/zero reads (register failure,
  lost AMI comms, vacancy) via run-length encoding.
- **Meter error** — physically impossible negative reads; plus isolated daily
  **spikes** flagged with a robust MAD z-score.

`run_all_detectors()` combines them into one per-meter table; `score_detections()`
validates results against the synthetic ground truth (currently **recall 1.0,
precision 0.75** — tuned to catch every real anomaly while keeping the analyst's
review list short).

### Customer classification (`R/04_customer_classification.R`)
- **Behavioural features** — average daily use, peakiness, overnight share,
  weekday/weekend ratio, summer/spring ratio. Portable across utilities because
  they describe *how* water is used, not the billing label.
- **Rule-based tiers + patterns** — transparent Low/Medium/High/Very-High tiers
  plus archetypes (e.g. *Irrigation-driven*, *High overnight / possible waste*).
- **K-means clustering** — unsupervised discovery of segments with readable
  per-cluster profiles.

---

## Connecting to a live Snowflake warehouse

The project runs on local CSVs by default. To use Snowflake instead:

1. Stand up the schema and load data:
   ```sql
   -- run in a Snowflake worksheet / SnowSQL
   !source sql/01_create_tables.sql
   !source sql/02_load_data.sql
   ```
2. Configure credentials (kept out of git):
   ```bash
   cp config.yml.example config.yml      # edit account/user/warehouse/...
   export SNOWFLAKE_PASSWORD='********'   # never stored in the repo
   ```
3. Everything else is unchanged — `load_interval_reads(source = "auto")` detects
   the config and pulls from Snowflake; `write_results_to_snowflake()` pushes the
   anomaly table back for downstream dashboards/alerts.

Requires the [Snowflake ODBC driver](https://docs.snowflake.com/en/developer-guide/odbc/odbc)
and the R `odbc` package.

---

## Data dictionary (synthetic)

**`meters.csv`** — one row per service connection: `meter_id`, `account_id`,
`customer_class` (Residential / Multi-family / Commercial / Irrigation),
`meter_size`, `route_id`, `install_year`, `latitude`, `longitude`.

**`interval_reads.csv`** — hourly reads: `meter_id`, `read_ts` (timestamp),
`consumption_gallons`. Generated with realistic diurnal + day-of-week + seasonal
patterns and injected data-quality issues (leaks, continuous use, stuck meters,
rollover errors).

**`system_supply.csv`** — daily `supplied_gallons` into the system (for NRW).

**`ground_truth_anomalies.csv`** — known injected issues per meter, used only to
score detector accuracy.

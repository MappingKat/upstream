# 05_analysis.R --------------------------------------------------------------
# Main analysis pipeline. Ties the modules together into an end-to-end
# "AMI Program Implementation Assessment" run:
#   1. Load interval reads (Snowflake or local synthetic data).
#   2. Run all anomaly detectors and score them against ground truth.
#   3. Build behavioural features and classify customers.
#   4. Compute non-revenue water (NRW) from system supply vs metered use.
#   5. Write tidy result tables + charts to output/ for the report & dashboard.
#
# Run from the project root:
#   Rscript R/05_analysis.R
# -----------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(lubridate)
  library(ggplot2)
  library(scales)
})

# Source the modules (works whether run from RStudio or Rscript).
source("R/02_snowflake_connect.R")
source("R/03_anomaly_detection.R")
source("R/04_customer_classification.R")
if (file.exists("R/00_setup.R")) try(source("R/00_setup.R"), silent = TRUE)

dir.create("output", showWarnings = FALSE)

# --- 1. Load data ------------------------------------------------------------
reads  <- load_interval_reads(source = "auto")   # auto -> Snowflake if configured
meters <- load_meters()

cat(sprintf("Loaded %s interval reads for %d meters (%s to %s)\n",
            format(nrow(reads), big.mark = ","), n_distinct(reads$meter_id),
            as.Date(min(reads$read_ts)), as.Date(max(reads$read_ts))))

# --- 2. Anomaly detection ----------------------------------------------------
anomalies <- run_all_detectors(reads)
anomalies <- anomalies %>% left_join(meters, by = "meter_id")

write_csv(anomalies, "output/anomaly_results.csv")

# Score against ground truth if available (synthetic-data mode only).
gt_path <- "data/ground_truth_anomalies.csv"
if (file.exists(gt_path)) {
  ground_truth <- read_csv(gt_path, show_col_types = FALSE)
  scores <- score_detections(anomalies, ground_truth)
  write_csv(scores, "output/detection_scores.csv")
  cat("\nDetection performance vs. ground truth:\n")
  print(scores)
}

cat("\nAnomaly summary:\n")
print(count(anomalies, primary_anomaly, name = "meters"))

# --- 3. Customer classification ---------------------------------------------
features <- build_usage_features(reads)
features_ruled <- classify_rule_based(features) %>%
  left_join(meters %>% select(meter_id, customer_class), by = "meter_id")
km <- classify_kmeans(features, k = 4)

write_csv(features_ruled, "output/customer_segments.csv")
write_csv(km$profile, "output/kmeans_cluster_profile.csv")

cat("\nUsage tier distribution:\n")
print(count(features_ruled, usage_tier, name = "meters"))
cat("\nUsage pattern distribution:\n")
print(count(features_ruled, usage_pattern, name = "meters"))

# --- 4. Non-revenue water (NRW) ---------------------------------------------
supply_path <- "data/system_supply.csv"
if (file.exists(supply_path)) {
  supply <- read_csv(supply_path, show_col_types = FALSE)
  daily_metered <- reads %>%
    mutate(supply_date = as_date(read_ts)) %>%
    group_by(supply_date) %>%
    summarise(metered_gallons = sum(consumption_gallons, na.rm = TRUE),
              .groups = "drop")
  nrw <- supply %>%
    mutate(supply_date = as_date(supply_date)) %>%
    inner_join(daily_metered, by = "supply_date") %>%
    mutate(
      nrw_gallons = supplied_gallons - metered_gallons,
      nrw_percent = 100 * nrw_gallons / supplied_gallons
    )
  write_csv(nrw, "output/nrw_daily.csv")
  cat(sprintf("\nAverage non-revenue water: %.1f%% (%s gal/day)\n",
              mean(nrw$nrw_percent, na.rm = TRUE),
              format(round(mean(nrw$nrw_gallons)), big.mark = ",")))
}

# --- 5. Charts for the report ------------------------------------------------
theme_set(theme_minimal(base_size = 12))

# 5a. System-wide daily demand
p_demand <- reads %>%
  mutate(read_date = as_date(read_ts)) %>%
  group_by(read_date) %>%
  summarise(gal = sum(consumption_gallons, na.rm = TRUE), .groups = "drop") %>%
  ggplot(aes(read_date, gal)) +
  geom_line(color = "#2c7fb8", linewidth = 0.7) +
  scale_y_continuous(labels = label_comma()) +
  labs(title = "System-wide daily metered demand",
       subtitle = "Synthetic AMI data; note the seasonal ramp into summer",
       x = NULL, y = "Gallons / day")
ggsave("output/fig_daily_demand.png", p_demand, width = 9, height = 4.5, dpi = 120)

# 5b. Average diurnal profile by customer class
p_diurnal <- reads %>%
  left_join(meters %>% select(meter_id, customer_class), by = "meter_id") %>%
  mutate(hr = hour(read_ts)) %>%
  group_by(customer_class, hr) %>%
  summarise(gal = mean(consumption_gallons, na.rm = TRUE), .groups = "drop") %>%
  ggplot(aes(hr, gal, color = customer_class)) +
  geom_line(linewidth = 0.9) +
  labs(title = "Average hourly use profile by customer class",
       x = "Hour of day", y = "Mean gallons / hour", color = NULL)
ggsave("output/fig_diurnal.png", p_diurnal, width = 9, height = 4.5, dpi = 120)

# 5c. Anomaly mix
p_anom <- anomalies %>%
  filter(any_anomaly) %>%
  count(primary_anomaly) %>%
  ggplot(aes(reorder(primary_anomaly, n), n, fill = primary_anomaly)) +
  geom_col(show.legend = FALSE) +
  coord_flip() +
  labs(title = "Flagged meters by anomaly type", x = NULL, y = "Meters")
ggsave("output/fig_anomalies.png", p_anom, width = 7, height = 4, dpi = 120)

# 5d. Spatial map of flagged meters (GIS view)
# Plots every service connection by location; anomalies are highlighted and
# sized by estimated wasted volume so field crews can see clustering at a glance.
map_df <- anomalies %>%
  mutate(
    status = if_else(any_anomaly, primary_anomaly, "normal"),
    sz = if_else(primary_anomaly == "leak", pmax(est_wasted_gallons, 1), 1)
  )
p_map <- ggplot() +
  geom_point(data = filter(map_df, !any_anomaly),
             aes(longitude, latitude), color = "grey75", size = 1.6, alpha = 0.7) +
  geom_point(data = filter(map_df, any_anomaly),
             aes(longitude, latitude, color = status, size = sz)) +
  scale_color_manual(values = c(leak = "#d7301f", continuous = "#fc8d59",
                                stuck = "#7a0177", meter_error = "#000000",
                                spike = "#fdae61"), name = "Anomaly") +
  scale_size_continuous(range = c(2, 8), guide = "none") +
  coord_quickmap() +
  labs(title = "Service-area map: flagged meters",
       subtitle = "Grey = normal; colored points = anomalies (leaks sized by est. waste)",
       x = "Longitude", y = "Latitude")
ggsave("output/fig_meter_map.png", p_map, width = 8, height = 6, dpi = 120)

cat("\nDone. Result tables and figures written to output/.\n")

# 04_customer_classification.R -----------------------------------------------
# Reusable customer-segmentation functions for AMI consumption data.
#
# Two complementary approaches, both replicable across clients:
#   1. build_usage_features() -- engineer behavioural features per meter.
#   2. classify_rule_based()  -- transparent, explainable usage tiers + patterns.
#   3. classify_kmeans()      -- unsupervised clustering for discovery.
#
# Behavioural features are what make segmentation portable: they describe HOW a
# customer uses water (peaky vs flat, indoor vs irrigation-driven, weekday vs
# weekend) independent of the utility's billing class.
#
# Dependencies: dplyr, lubridate (loaded via 00_setup.R).
# -----------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
})

# --- 1. Feature engineering --------------------------------------------------
build_usage_features <- function(reads) {
  reads %>%
    mutate(
      read_date = as_date(read_ts),
      hr        = hour(read_ts),
      dow       = wday(read_ts),               # 1 = Sunday
      is_weekend = dow %in% c(1, 7),
      is_night   = hr %in% c(0, 1, 2, 3, 4),
      month      = month(read_ts)
    ) %>%
    group_by(meter_id) %>%
    summarise(
      avg_daily_gal   = sum(consumption_gallons, na.rm = TRUE) /
                         n_distinct(read_date),
      peak_hourly_gal = max(consumption_gallons, na.rm = TRUE),
      base_hourly_gal = quantile(consumption_gallons, 0.10, na.rm = TRUE),
      # peakiness: ratio of peak to typical flow (irrigation/process = high)
      peak_to_median  = max(consumption_gallons, na.rm = TRUE) /
                         pmax(median(consumption_gallons, na.rm = TRUE), 0.01),
      night_share     = sum(consumption_gallons[is_night], na.rm = TRUE) /
                         pmax(sum(consumption_gallons, na.rm = TRUE), 0.01),
      weekend_ratio   = mean(consumption_gallons[is_weekend], na.rm = TRUE) /
                         pmax(mean(consumption_gallons[!is_weekend], na.rm = TRUE), 0.01),
      # seasonal sensitivity: late-summer vs spring average (irrigation signal)
      summer_ratio    = mean(consumption_gallons[month %in% 6:8], na.rm = TRUE) /
                         pmax(mean(consumption_gallons[month %in% 4:5], na.rm = TRUE), 0.01),
      .groups = "drop"
    ) %>%
    mutate(across(where(is.numeric), ~ifelse(is.finite(.), ., NA_real_)))
}

# --- 2. Rule-based classification (transparent & explainable) ----------------
# Produces two labels that water utilities actually use:
#   usage_tier     -- Low / Medium / High / Very High by avg daily volume.
#   usage_pattern  -- behavioural archetype from the engineered features.
classify_rule_based <- function(features,
                                tier_breaks = c(0, 100, 300, 800, Inf),
                                tier_labels = c("Low", "Medium", "High", "Very High")) {
  features %>%
    mutate(
      usage_tier = cut(avg_daily_gal, breaks = tier_breaks,
                       labels = tier_labels, right = FALSE),
      usage_pattern = case_when(
        summer_ratio  >= 1.8 & peak_to_median >= 6 ~ "Irrigation-driven",
        night_share   >= 0.30                       ~ "High overnight / possible waste",
        peak_to_median >= 8                          ~ "Highly peaked",
        weekend_ratio  <= 0.7                        ~ "Weekday / commercial-like",
        peak_to_median <= 3                          ~ "Flat / steady",
        TRUE                                         ~ "Typical indoor"
      )
    )
}

# --- 3. K-means clustering (unsupervised discovery) --------------------------
# Standardizes the behavioural features and clusters meters into `k` segments.
# Returns the features table with a `cluster` column plus the fitted model and
# a readable per-cluster profile to help name the segments.
classify_kmeans <- function(features, k = 4, seed = 42,
                            feature_cols = c("avg_daily_gal", "peak_to_median",
                                             "night_share", "weekend_ratio",
                                             "summer_ratio")) {
  mat <- features %>%
    select(all_of(feature_cols)) %>%
    mutate(across(everything(), ~ifelse(is.na(.), median(., na.rm = TRUE), .))) %>%
    scale()

  set.seed(seed)
  km <- kmeans(mat, centers = k, nstart = 25, iter.max = 50)

  out <- features %>% mutate(cluster = factor(km$cluster))

  profile <- out %>%
    group_by(cluster) %>%
    summarise(
      n_meters       = n(),
      avg_daily_gal  = round(mean(avg_daily_gal, na.rm = TRUE), 1),
      peak_to_median = round(mean(peak_to_median, na.rm = TRUE), 1),
      night_share    = round(mean(night_share, na.rm = TRUE), 3),
      summer_ratio   = round(mean(summer_ratio, na.rm = TRUE), 2),
      .groups = "drop"
    ) %>%
    arrange(desc(avg_daily_gal))

  list(data = out, model = km, profile = profile)
}

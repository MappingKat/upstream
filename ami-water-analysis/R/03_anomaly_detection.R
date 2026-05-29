# 03_anomaly_detection.R -----------------------------------------------------
# Reusable AMI anomaly-detection functions.
#
# Design goals (per the WRA role): methods that are transparent, parameterized,
# and replicable across clients. Each detector takes a tidy interval-read table
# and returns one row per meter with a flag + supporting evidence, so results
# are easy to audit and to roll up into a report or dashboard.
#
# Input schema expected everywhere:
#   meter_id  (chr)
#   read_ts   (POSIXct)  -- hourly interval timestamp
#   consumption_gallons (dbl)
#
# Dependencies: dplyr, lubridate, tidyr (loaded via 00_setup.R).
# -----------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(tidyr)
})

# --- Helper: nightly minimum flow -------------------------------------------
# The single most useful AMI leak signal. Overnight (low-activity) hours should
# drop near zero for most accounts; a persistent non-zero overnight minimum is
# the classic signature of a leak or a stuck-open fixture.
nightly_minimum_flow <- function(reads, night_hours = 1:4) {
  reads %>%
    mutate(read_date = as_date(read_ts), hr = hour(read_ts)) %>%
    filter(hr %in% night_hours) %>%
    group_by(meter_id, read_date) %>%
    summarise(night_min = min(consumption_gallons, na.rm = TRUE), .groups = "drop")
}

# --- 1. Leak detection (step-change in overnight minimum flow) ----------------
# Minimum-night-flow (MNF) analysis is the industry-standard leak signal, but a
# flat threshold misfires on customers (e.g. commercial) with legitimate steady
# overnight baseload. The key insight: a real leak STARTS and then persists, so
# the overnight minimum *steps up* and stays up. We compare the median overnight
# minimum in the recent window against the early window and flag a sustained
# jump. This catches new leaks while ignoring constant baseload.
#   min_step_gph -- minimum absolute increase in overnight flow (gallons/hour)
#   min_ratio    -- recent overnight flow must be this multiple of the early flow
#   recent_frac  -- fraction of the record treated as "recent" vs "early"
detect_leaks <- function(reads, min_step_gph = 1.0, min_ratio = 2.0,
                         recent_frac = 1/3) {
  # Overnight minimum flow, split into early vs recent windows.
  nmf <- nightly_minimum_flow(reads) %>%
    arrange(meter_id, read_date) %>%
    group_by(meter_id) %>%
    summarise(
      nights_observed   = n(),
      early_night_flow  = median(head(night_min, ceiling(n() * recent_frac)),
                                 na.rm = TRUE),
      recent_night_flow = median(tail(night_min, ceiling(n() * recent_frac)),
                                 na.rm = TRUE),
      .groups = "drop"
    )
  # Overall demand growth over the same windows, used to discount the portion of
  # the overnight rise that is just seasonal demand increasing across the board.
  growth <- reads %>%
    mutate(read_date = as_date(read_ts)) %>%
    group_by(meter_id, read_date) %>%
    summarise(daily_gal = sum(consumption_gallons, na.rm = TRUE), .groups = "drop") %>%
    arrange(meter_id, read_date) %>%
    group_by(meter_id) %>%
    summarise(
      early_daily  = median(head(daily_gal, ceiling(n() * recent_frac)), na.rm = TRUE),
      recent_daily = median(tail(daily_gal, ceiling(n() * recent_frac)), na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(demand_growth = recent_daily / pmax(early_daily, 1))

  nmf %>%
    left_join(growth, by = "meter_id") %>%
    mutate(
      # what overnight flow we'd expect from seasonal demand growth alone
      expected_night_flow = early_night_flow * demand_growth,
      # excess overnight flow beyond what seasonal growth explains -> leak signal
      step = recent_night_flow - expected_night_flow,
      is_leak = step > min_step_gph &
                recent_night_flow > min_ratio * pmax(expected_night_flow, 0.1) &
                recent_night_flow > min_step_gph,
      median_night_flow = recent_night_flow,
      est_wasted_gallons = if_else(
        is_leak, step * 24 * ceiling(nights_observed * recent_frac), 0),
      anomaly_type = if_else(is_leak, "leak", NA_character_)
    ) %>%
    arrange(desc(is_leak), desc(step))
}

# --- 2. Continuous-use detection --------------------------------------------
# Distinct from a slow leak: the meter NEVER reads zero in any hour. Signature
# of a running toilet, stuck valve, or process load. We measure the share of
# hours with non-zero flow and flag meters above `min_share`.
detect_continuous_use <- function(reads, zero_tol = 0.01, min_share = 0.995,
                                  min_hours = 24 * 14) {
  reads %>%
    group_by(meter_id) %>%
    summarise(
      hours_observed = n(),
      nonzero_share  = mean(consumption_gallons > zero_tol, na.rm = TRUE),
      min_hourly     = min(consumption_gallons, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      is_continuous = hours_observed >= min_hours &
                      nonzero_share >= min_share &
                      min_hourly > zero_tol,
      anomaly_type = if_else(is_continuous, "continuous", NA_character_)
    ) %>%
    arrange(desc(is_continuous), desc(nonzero_share))
}

# --- 3. Stuck / zero meter detection ----------------------------------------
# Flags meters with an unusually long run of identical (typically zero) reads --
# a sign of a failed register, lost AMI communication, or a vacant property.
# Uses run-length encoding to find the longest constant streak per meter.
detect_stuck_meters <- function(reads, max_zero_run = 48, zero_tol = 0.01) {
  longest_zero_run <- function(x) {
    is_zero <- x <= zero_tol
    if (!any(is_zero)) return(0L)
    r <- rle(is_zero)
    max(r$lengths[r$values], na.rm = TRUE)
  }
  reads %>%
    arrange(meter_id, read_ts) %>%
    group_by(meter_id) %>%
    summarise(
      hours_observed   = n(),
      zero_hours       = sum(consumption_gallons <= zero_tol, na.rm = TRUE),
      longest_zero_run = longest_zero_run(consumption_gallons),
      .groups = "drop"
    ) %>%
    mutate(
      is_stuck = longest_zero_run >= max_zero_run,
      anomaly_type = if_else(is_stuck, "stuck", NA_character_)
    ) %>%
    arrange(desc(longest_zero_run))
}

# --- 4. Meter-error & spike detection ---------------------------------------
# Two separate signals, kept distinct because they mean different things:
#   * meter_error -- NEGATIVE reads, which are physically impossible on a
#     forward-reading meter (register rollover, AMI decode error, bad estimate).
#   * spike -- a single day far above the meter's own typical daily total.
# Spikes are scored on DAILY totals (not raw hourly reads) with a robust MAD
# z-score, so ordinary diurnal peaks don't trip the detector.
detect_meter_errors <- function(reads, daily_spike_z = 12) {
  neg <- reads %>%
    group_by(meter_id) %>%
    summarise(
      hours_observed = n(),
      negative_reads = sum(consumption_gallons < 0, na.rm = TRUE),
      .groups = "drop"
    )
  daily <- reads %>%
    mutate(read_date = as_date(read_ts)) %>%
    group_by(meter_id, read_date) %>%
    summarise(daily_gal = sum(consumption_gallons, na.rm = TRUE), .groups = "drop")
  spikes <- daily %>%
    group_by(meter_id) %>%
    summarise(
      med_daily = median(daily_gal, na.rm = TRUE),
      mad_daily = mad(daily_gal, constant = 1.4826, na.rm = TRUE),
      max_daily = max(daily_gal, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      spike_z  = if_else(mad_daily > 0, (max_daily - med_daily) / mad_daily, 0),
      is_spike = mad_daily > 0 & spike_z > daily_spike_z
    )
  neg %>%
    left_join(spikes, by = "meter_id") %>%
    mutate(
      is_meter_error = negative_reads > 0,
      anomaly_type = case_when(
        negative_reads > 0 ~ "meter_error",
        is_spike           ~ "spike",
        TRUE               ~ NA_character_
      )
    ) %>%
    arrange(desc(negative_reads), desc(spike_z))
}

# --- Orchestrator: run every detector and build one tidy summary -------------
# Returns a per-meter table with a boolean column per detector plus a single
# `primary_anomaly` label (priority: meter_error > leak > continuous > stuck).
# This is the table the report and dashboard consume.
run_all_detectors <- function(reads,
                              leak_args = list(),
                              continuous_args = list(),
                              stuck_args = list(),
                              error_args = list()) {
  leaks      <- do.call(detect_leaks, c(list(reads), leak_args))
  continuous <- do.call(detect_continuous_use, c(list(reads), continuous_args))
  stuck      <- do.call(detect_stuck_meters, c(list(reads), stuck_args))
  errors     <- do.call(detect_meter_errors, c(list(reads), error_args))

  meters <- tibble(meter_id = sort(unique(reads$meter_id)))
  meters %>%
    left_join(leaks %>% select(meter_id, is_leak, median_night_flow,
                               est_wasted_gallons), by = "meter_id") %>%
    left_join(continuous %>% select(meter_id, is_continuous, nonzero_share),
              by = "meter_id") %>%
    left_join(stuck %>% select(meter_id, is_stuck, longest_zero_run),
              by = "meter_id") %>%
    left_join(errors %>% select(meter_id, is_meter_error, is_spike,
                                negative_reads, spike_z), by = "meter_id") %>%
    mutate(across(starts_with("is_"), ~replace_na(., FALSE))) %>%
    mutate(
      # priority order when a meter trips more than one detector
      primary_anomaly = case_when(
        is_meter_error ~ "meter_error",
        is_leak        ~ "leak",
        is_continuous  ~ "continuous",
        is_stuck       ~ "stuck",
        is_spike       ~ "spike",
        TRUE           ~ "normal"
      ),
      any_anomaly = primary_anomaly != "normal"
    )
}

# --- Scoring helper: compare detections to ground truth ----------------------
# Because the synthetic data ships with known injected issues, we can report
# precision/recall -- useful evidence that the methods actually work.
score_detections <- function(detected, ground_truth) {
  gt <- ground_truth %>%
    transmute(meter_id, truth = injected_issue)
  joined <- detected %>%
    select(meter_id, predicted = primary_anomaly) %>%
    left_join(gt, by = "meter_id") %>%
    mutate(
      truth_anom = truth != "none",
      pred_anom  = predicted != "normal"
    )
  tp <- sum(joined$truth_anom & joined$pred_anom)
  fp <- sum(!joined$truth_anom & joined$pred_anom)
  fn <- sum(joined$truth_anom & !joined$pred_anom)
  tibble(
    true_positive  = tp,
    false_positive = fp,
    false_negative = fn,
    precision = ifelse(tp + fp > 0, tp / (tp + fp), NA_real_),
    recall    = ifelse(tp + fn > 0, tp / (tp + fn), NA_real_)
  )
}

# 01_generate_synthetic_ami.R ------------------------------------------------
# Generate a realistic synthetic AMI (Advanced Metering Infrastructure) dataset.
#
# Why synthetic? Real utility consumption data is confidential. This generator
# produces hourly interval reads that *behave* like real AMI data -- diurnal
# peaks, day-of-week effects, summer irrigation, and a realistic mix of data
# quality problems (leaks, continuous use, stuck/zero meters, rollover errors).
# That makes the anomaly-detection and classification code demonstrable end to
# end without exposing any client data.
#
# Intentionally written in BASE R (no package dependencies) so it runs in any
# R installation. Output is two CSVs the rest of the project consumes:
#   data/meters.csv          -- one row per metered service connection
#   data/interval_reads.csv  -- hourly consumption (gallons) per meter
#   data/system_supply.csv   -- daily water supplied into the system (for NRW)
#
# Usage:
#   Rscript R/01_generate_synthetic_ami.R              # default (small sample)
#   Rscript R/01_generate_synthetic_ami.R 250 120      # 250 meters, 120 days
# -----------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
N_METERS <- if (length(args) >= 1) as.integer(args[1]) else 60
N_DAYS   <- if (length(args) >= 2) as.integer(args[2]) else 90
START_DATE <- as.Date("2025-04-01")   # spring -> summer, captures irrigation ramp
SEED <- 42

set.seed(SEED)
dir.create("data", showWarnings = FALSE)

# --- 1. Build the meter / customer roster -----------------------------------
classes <- c("Residential", "Multi-family", "Commercial", "Irrigation")
class_weights <- c(0.70, 0.12, 0.13, 0.05)   # typical utility mix
class_base_gpd <- c(                          # avg gallons/day baseline by class
  Residential = 180, `Multi-family` = 900, Commercial = 1200, Irrigation = 2500
)
meter_sizes <- c(Residential = "5/8\"", `Multi-family` = "1\"",
                 Commercial = "2\"", Irrigation = "1.5\"")

meter_class <- sample(classes, N_METERS, replace = TRUE, prob = class_weights)
# A simple geographic spread around a fictional service area (lat/lon).
center_lat <- 30.27; center_lon <- -97.74  # central Texas-ish
meters <- data.frame(
  meter_id      = sprintf("M%05d", seq_len(N_METERS)),
  account_id    = sprintf("A%06d", sample(100000:999999, N_METERS)),
  customer_class = meter_class,
  meter_size    = meter_sizes[meter_class],
  route_id      = sprintf("R%02d", sample(1:8, N_METERS, replace = TRUE)),
  install_year  = sample(1998:2024, N_METERS, replace = TRUE),
  latitude      = round(center_lat + rnorm(N_METERS, 0, 0.05), 6),
  longitude     = round(center_lon + rnorm(N_METERS, 0, 0.06), 6),
  stringsAsFactors = FALSE
)
# Per-meter random scale so households differ in size.
meters$base_gpd <- class_base_gpd[meter_class] * exp(rnorm(N_METERS, 0, 0.35))

# --- 2. Hourly shape profiles ------------------------------------------------
# Residential: morning + evening peaks. Commercial: business-hours plateau.
res_hour <- c(0.2,0.15,0.1,0.1,0.2,0.6,1.4,1.8,1.5,1.0,0.8,0.9,
              0.9,0.8,0.7,0.8,1.0,1.4,1.7,1.6,1.2,0.9,0.6,0.35)
com_hour <- c(0.2,0.2,0.2,0.2,0.3,0.5,0.8,1.2,1.5,1.6,1.6,1.6,
              1.5,1.6,1.6,1.5,1.3,1.0,0.7,0.5,0.4,0.3,0.25,0.2)
irr_hour <- rep(0.1, 24); irr_hour[c(4,5,6,21,22)] <- c(3,4,4,3,2)  # pre-dawn/evening watering
hour_profiles <- list(
  Residential = res_hour / mean(res_hour),
  `Multi-family` = res_hour / mean(res_hour),
  Commercial  = com_hour / mean(com_hour),
  Irrigation  = irr_hour / mean(irr_hour)
)

# Seasonal multiplier: usage climbs into summer (outdoor/irrigation demand).
seasonal_factor <- function(date) {
  doy <- as.integer(format(date, "%j"))
  1 + 0.45 * sin((doy - 110) / 365 * 2 * pi)   # peak ~ late June
}

# --- 3. Decide which meters get which data-quality issues --------------------
# These are the ground-truth anomalies the detection code should re-discover.
n_leak       <- max(1, round(N_METERS * 0.06))  # slow continuous leak
n_continuous <- max(1, round(N_METERS * 0.04))  # 24/7 nonzero (e.g., running toilet)
n_stuck      <- max(1, round(N_METERS * 0.03))  # meter reports zero / stuck
n_rollover   <- max(1, round(N_METERS * 0.02))  # negative reads (rollover/error)
idx <- sample(seq_len(N_METERS))
flag <- list(
  leak       = idx[1:n_leak],
  continuous = idx[(n_leak + 1):(n_leak + n_continuous)],
  stuck      = idx[(n_leak + n_continuous + 1):(n_leak + n_continuous + n_stuck)],
  rollover   = idx[(n_leak + n_continuous + n_stuck + 1):
                     (n_leak + n_continuous + n_stuck + n_rollover)]
)
meters$injected_issue <- "none"
meters$injected_issue[flag$leak]       <- "leak"
meters$injected_issue[flag$continuous] <- "continuous"
meters$injected_issue[flag$stuck]      <- "stuck"
meters$injected_issue[flag$rollover]   <- "rollover"

# --- 4. Generate the hourly interval reads -----------------------------------
timestamps <- seq(as.POSIXct(paste0(START_DATE, " 00:00:00"), tz = "UTC"),
                  by = "hour", length.out = N_DAYS * 24)
n_hours <- length(timestamps)
dates   <- as.Date(timestamps)
hours   <- as.integer(format(timestamps, "%H"))
dows    <- as.POSIXlt(timestamps)$wday          # 0 = Sunday
seas    <- seasonal_factor(dates)
weekend_mult <- ifelse(dows %in% c(0, 6), 1.12, 1.0)  # slightly higher on weekends

mean_event_gal <- 8   # avg gallons per fixture "event" (flush, faucet, cycle)
read_list <- vector("list", N_METERS)
for (i in seq_len(N_METERS)) {
  cls   <- meters$customer_class[i]
  shape <- hour_profiles[[cls]][hours + 1]
  mean_hourly <- meters$base_gpd[i] / 24
  expected <- mean_hourly * shape * seas * weekend_mult
  # Compound-Poisson usage: each hour sees a Poisson count of fixture events,
  # each contributing ~mean_event_gal. When expected demand is low (e.g. deep
  # night), many hours are genuinely ZERO -- exactly like real residential AMI.
  # That genuine intermittency is what lets the leak/continuous detectors work.
  n_events <- rpois(n_hours, lambda = expected / mean_event_gal)
  usage <- n_events * mean_event_gal * exp(rnorm(n_hours, 0, 0.3))

  issue <- meters$injected_issue[i]
  if (issue == "leak") {
    # leak begins partway through the period, adds a constant baseline flow that
    # never stops -- so overnight minimums jump from ~0 to a steady value.
    start_h <- sample(round(n_hours * 0.2):round(n_hours * 0.6), 1)
    leak_rate <- runif(1, 0.6, 1.5) * mean_hourly      # gph added continuously
    usage[start_h:n_hours] <- usage[start_h:n_hours] + leak_rate
  } else if (issue == "continuous") {
    # never drops to zero: enforce a persistent minimum flow
    floorflow <- runif(1, 0.25, 0.6) * mean_hourly
    usage <- pmax(usage, floorflow)
  } else if (issue == "stuck") {
    # meter stuck/zeros out for a multi-day stretch (comms or register failure)
    s <- sample(1:(n_hours - 24 * 10), 1)
    e <- s + 24 * sample(5:14, 1)
    usage[s:min(e, n_hours)] <- 0
  } else if (issue == "rollover") {
    # a handful of negative/implausible reads (register rollover or AMI error)
    bad <- sample(seq_len(n_hours), sample(3:8, 1))
    usage[bad] <- -abs(usage[bad]) * runif(length(bad), 2, 6)
  }

  read_list[[i]] <- data.frame(
    meter_id  = meters$meter_id[i],
    # explicit timestamp string so midnight reads keep their 00:00:00 component
    read_ts   = format(timestamps, "%Y-%m-%d %H:%M:%S"),
    consumption_gallons = round(usage, 2),
    stringsAsFactors = FALSE
  )
}
reads <- do.call(rbind, read_list)

# --- 5. System supply table (for non-revenue water analysis) -----------------
# Daily metered demand + assumed real+apparent losses => water supplied.
daily_metered <- aggregate(consumption_gallons ~ as.Date(read_ts),
                           data = reads, FUN = sum)
names(daily_metered) <- c("supply_date", "metered_gallons")
# Assume ~14% non-revenue water on average, varying day to day.
loss_frac <- pmin(0.30, pmax(0.05, rnorm(nrow(daily_metered), 0.14, 0.03)))
system_supply <- data.frame(
  supply_date     = daily_metered$supply_date,
  supplied_gallons = round(daily_metered$metered_gallons / (1 - loss_frac), 0)
)

# --- 6. Write outputs --------------------------------------------------------
# Drop the helper columns that wouldn't exist in a real meter export, but keep
# `injected_issue` in a separate ground-truth file so we can score detection.
ground_truth <- meters[, c("meter_id", "injected_issue")]
meters_out <- meters[, c("meter_id", "account_id", "customer_class", "meter_size",
                         "route_id", "install_year", "latitude", "longitude")]

write.csv(meters_out, "data/meters.csv", row.names = FALSE)
write.csv(reads, "data/interval_reads.csv", row.names = FALSE)
write.csv(system_supply, "data/system_supply.csv", row.names = FALSE)
write.csv(ground_truth, "data/ground_truth_anomalies.csv", row.names = FALSE)

cat(sprintf(
  "Generated %d meters x %d days = %s hourly reads\n  -> data/meters.csv, data/interval_reads.csv, data/system_supply.csv\n  -> ground truth: %d leak, %d continuous, %d stuck, %d rollover\n",
  N_METERS, N_DAYS, format(nrow(reads), big.mark = ","),
  n_leak, n_continuous, n_stuck, n_rollover
))

# 02_snowflake_connect.R -----------------------------------------------------
# Snowflake connectivity helpers.
#
# This project runs end-to-end on the bundled synthetic CSVs, so you do NOT
# need Snowflake to demo it. These helpers show how the same workflow connects
# to a live Snowflake warehouse -- which is the production data path the WRA
# role uses.
#
# Credentials are read from config.yml (which is git-ignored) or from
# environment variables. NEVER hard-code account passwords in scripts.
#
#   config.yml example (copy from config.yml.example):
#   default:
#     snowflake:
#       account:   "ab12345.us-east-1"
#       user:      "WRA_ANALYST"
#       warehouse: "ANALYTICS_WH"
#       database:  "WATER"
#       schema:    "AMI"
#       role:      "ANALYST_ROLE"
#
# Auth: uses the Snowflake ODBC driver via the {odbc} package. Password is taken
# from the SNOWFLAKE_PASSWORD environment variable (or key-pair / SSO if you
# configure the DSN that way).
# -----------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(DBI)
})

# --- Open a connection -------------------------------------------------------
snowflake_connect <- function(config_file = "config.yml") {
  if (!requireNamespace("odbc", quietly = TRUE)) {
    stop("Package 'odbc' is required for Snowflake. Install it via 00_setup.R.")
  }
  cfg <- config::get("snowflake", file = config_file)
  pwd <- Sys.getenv("SNOWFLAKE_PASSWORD")
  if (identical(pwd, "")) {
    stop("Set the SNOWFLAKE_PASSWORD environment variable before connecting.")
  }
  DBI::dbConnect(
    odbc::odbc(),
    Driver    = "SnowflakeDSIIDriver",
    Server    = paste0(cfg$account, ".snowflakecomputing.com"),
    UID       = cfg$user,
    PWD       = pwd,
    Warehouse = cfg$warehouse,
    Database  = cfg$database,
    Schema    = cfg$schema,
    Role      = cfg$role
  )
}

# --- Load interval reads from Snowflake or fall back to local CSV ------------
# The rest of the project calls this single function. If Snowflake credentials
# aren't configured it transparently reads the synthetic CSVs, so notebooks and
# the dashboard work identically in both modes.
load_interval_reads <- function(source = c("auto", "snowflake", "local"),
                                local_path = "data/interval_reads.csv",
                                config_file = "config.yml") {
  source <- match.arg(source)
  use_snowflake <- source == "snowflake" ||
    (source == "auto" && file.exists(config_file) &&
       !identical(Sys.getenv("SNOWFLAKE_PASSWORD"), ""))

  if (use_snowflake) {
    message("Loading interval reads from Snowflake ...")
    con <- snowflake_connect(config_file)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    reads <- DBI::dbGetQuery(con, "
      SELECT meter_id, read_ts, consumption_gallons
      FROM   interval_reads
    ")
  } else {
    message("Loading interval reads from local CSV: ", local_path)
    reads <- readr::read_csv(local_path, show_col_types = FALSE)
  }
  # read_ts may already be POSIXct (readr/Snowflake auto-parse) or a string;
  # only parse strings, otherwise as.character() would drop the time on midnight.
  if (!inherits(reads$read_ts, "POSIXct")) {
    reads$read_ts <- lubridate::ymd_hms(reads$read_ts, quiet = TRUE)
  }
  reads %>%
    dplyr::mutate(
      meter_id = as.character(meter_id),
      consumption_gallons = as.numeric(consumption_gallons)
    )
}

load_meters <- function(local_path = "data/meters.csv") {
  readr::read_csv(local_path, show_col_types = FALSE) %>%
    dplyr::mutate(meter_id = as.character(meter_id))
}

# --- Write analysis results back to Snowflake (optional) ---------------------
# Demonstrates the round-trip: push the per-meter anomaly table back so it can
# feed dashboards, alerts, or downstream models.
write_results_to_snowflake <- function(df, table_name,
                                       config_file = "config.yml",
                                       overwrite = TRUE) {
  con <- snowflake_connect(config_file)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  DBI::dbWriteTable(con, name = table_name, value = df, overwrite = overwrite)
  message("Wrote ", nrow(df), " rows to ", table_name)
}

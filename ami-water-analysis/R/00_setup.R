# 00_setup.R ------------------------------------------------------------------
# Project setup: install/load packages and define global options.
# Run this first (once) in a fresh RStudio session.
# -----------------------------------------------------------------------------

# Packages used across the project. The Snowflake packages (DBI, odbc) are only
# needed if you connect to a live warehouse; everything else runs on the
# bundled synthetic data with no external services.
required_packages <- c(
  "tidyverse",   # dplyr, ggplot2, tidyr, readr, lubridate, etc.
  "lubridate",   # date/time handling for interval reads
  "scales",      # axis formatting for charts
  "janitor",     # clean column names
  "config",      # read Snowflake credentials from config.yml
  "DBI",         # database interface (Snowflake)
  "odbc"         # ODBC driver layer for Snowflake
)

# Optional packages for the report and dashboard.
optional_packages <- c(
  "rmarkdown",   # knit the AMI assessment report
  "knitr",
  "shiny",       # interactive dashboard
  "DT",          # interactive tables in the dashboard
  "plotly",      # interactive charts
  "leaflet"      # map of flagged meters
)

install_if_missing <- function(pkgs) {
  missing <- pkgs[!(pkgs %in% rownames(installed.packages()))]
  if (length(missing)) {
    message("Installing: ", paste(missing, collapse = ", "))
    install.packages(missing, repos = "https://cloud.r-project.org")
  }
}

# Uncomment the next two lines the first time you run the project.
# install_if_missing(required_packages)
# install_if_missing(optional_packages)

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
})

# Global options ---------------------------------------------------------------
options(
  dplyr.summarise.inform = FALSE,
  scipen = 999
)

# Project paths (relative to project root) ------------------------------------
paths <- list(
  data   = "data",
  output = "output",
  sql    = "sql",
  R      = "R"
)

# A consistent ggplot theme for every chart in the project.
theme_water <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title    = element_text(face = "bold"),
      plot.subtitle = element_text(color = "grey35"),
      panel.grid.minor = element_blank(),
      legend.position = "bottom"
    )
}

# A small brand-ish palette used in charts and the dashboard.
water_palette <- c(
  normal       = "#2c7fb8",
  leak         = "#d7301f",
  continuous   = "#fc8d59",
  meter_error  = "#7a0177",
  spike        = "#fdae61",
  residential  = "#2c7fb8",
  commercial   = "#1b9e77",
  irrigation   = "#66a61e",
  multifamily  = "#7570b3"
)

message("Setup complete. Project root: ", normalizePath("."))

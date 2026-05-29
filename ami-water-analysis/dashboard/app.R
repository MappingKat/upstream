# dashboard/app.R ------------------------------------------------------------
# Interactive AMI analytics dashboard (Shiny).
#
# Run from the project ROOT so relative paths resolve:
#   shiny::runApp("dashboard")
# or from RStudio: open this file and click "Run App" (working dir must be the
# project root -- the app sets it defensively below).
#
# Tabs:
#   * Overview        -- system demand + diurnal profiles, filterable by class/route
#   * Anomalies       -- flagged meters table + per-meter interval trace
#   * Customer segments -- usage tiers / behavioural patterns
#   * Non-revenue water -- daily NRW trend
#
# Dependencies: shiny, DT, dplyr, tidyr, readr, lubridate, ggplot2, scales.
# -----------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(shiny); library(DT); library(dplyr); library(tidyr)
  library(readr); library(lubridate); library(ggplot2); library(scales)
})

# Resolve project root whether launched from root or from dashboard/.
if (file.exists("R/02_snowflake_connect.R")) {
  root <- "."
} else if (file.exists("../R/02_snowflake_connect.R")) {
  root <- ".."
} else {
  stop("Run the app from the project root: shiny::runApp('dashboard')")
}
source(file.path(root, "R/02_snowflake_connect.R"))
source(file.path(root, "R/03_anomaly_detection.R"))
source(file.path(root, "R/04_customer_classification.R"))

# --- Load + precompute once at startup --------------------------------------
reads  <- load_interval_reads(source = "auto",
                              local_path = file.path(root, "data/interval_reads.csv"),
                              config_file = file.path(root, "config.yml"))
meters <- load_meters(file.path(root, "data/meters.csv"))

anomalies <- run_all_detectors(reads) %>% left_join(meters, by = "meter_id")
features  <- build_usage_features(reads)
segments  <- classify_rule_based(features) %>%
  left_join(meters %>% select(meter_id, customer_class), by = "meter_id")

supply_path <- file.path(root, "data/system_supply.csv")
nrw <- NULL
if (file.exists(supply_path)) {
  daily_metered <- reads %>% mutate(d = as_date(read_ts)) %>%
    group_by(d) %>%
    summarise(metered = sum(consumption_gallons, na.rm = TRUE), .groups = "drop")
  nrw <- read_csv(supply_path, show_col_types = FALSE) %>%
    mutate(d = as_date(supply_date)) %>%
    inner_join(daily_metered, by = "d") %>%
    mutate(nrw_percent = 100 * (supplied_gallons - metered) / supplied_gallons)
}

classes <- sort(unique(meters$customer_class))
routes  <- sort(unique(meters$route_id))
pal <- c(normal = "#2c7fb8", leak = "#d7301f", continuous = "#fc8d59",
         stuck = "#7a0177", meter_error = "#000000", spike = "#fdae61")
theme_set(theme_minimal(base_size = 13))

# --- UI ---------------------------------------------------------------------
ui <- fluidPage(
  titlePanel("AMI Water-Use Analytics Dashboard"),
  sidebarLayout(
    sidebarPanel(
      width = 3,
      helpText("Synthetic AMI data. The same app reads live Snowflake data",
               "when credentials are configured."),
      checkboxGroupInput("classes", "Customer class", choices = classes,
                         selected = classes),
      selectInput("route", "Route", choices = c("All", routes), selected = "All"),
      hr(),
      htmlOutput("kpis")
    ),
    mainPanel(
      width = 9,
      tabsetPanel(
        tabPanel("Overview",
          br(),
          plotOutput("demand_plot", height = "280px"),
          plotOutput("diurnal_plot", height = "300px")),
        tabPanel("Anomalies",
          br(),
          fluidRow(
            column(5, plotOutput("anom_bar", height = "300px")),
            column(7,
              selectInput("anom_meter", "Inspect meter (interval trace):",
                          choices = NULL, width = "100%"),
              plotOutput("meter_trace", height = "240px"))
          ),
          hr(),
          h4("Flagged meters"),
          DTOutput("anom_table")),
        tabPanel("Customer segments",
          br(),
          fluidRow(
            column(6, plotOutput("tier_plot", height = "300px")),
            column(6, plotOutput("pattern_plot", height = "300px"))),
          hr(),
          DTOutput("seg_table")),
        tabPanel("Non-revenue water",
          br(),
          plotOutput("nrw_plot", height = "320px"),
          DTOutput("nrw_table"))
      )
    )
  )
)

# --- Server -----------------------------------------------------------------
server <- function(input, output, session) {

  sel_meters <- reactive({
    m <- meters %>% filter(customer_class %in% input$classes)
    if (input$route != "All") m <- m %>% filter(route_id == input$route)
    m$meter_id
  })
  f_reads     <- reactive(reads     %>% filter(meter_id %in% sel_meters()))
  f_anomalies <- reactive(anomalies %>% filter(meter_id %in% sel_meters()))
  f_segments  <- reactive(segments  %>% filter(meter_id %in% sel_meters()))

  observe({
    flagged <- f_anomalies() %>% filter(any_anomaly) %>% pull(meter_id)
    updateSelectInput(session, "anom_meter",
                      choices = if (length(flagged)) flagged else sel_meters())
  })

  output$kpis <- renderUI({
    a <- f_anomalies()
    tot <- sum(f_reads()$consumption_gallons[f_reads()$consumption_gallons > 0],
               na.rm = TRUE)
    HTML(sprintf(
      "<b>Meters:</b> %s<br><b>Flagged:</b> %s (%.0f%%)<br>
       <b>Leaks:</b> %s<br><b>Total volume:</b> %s gal",
      comma(nrow(a)), comma(sum(a$any_anomaly)),
      100 * mean(a$any_anomaly), comma(sum(a$primary_anomaly == "leak")),
      comma(round(tot))))
  })

  output$demand_plot <- renderPlot({
    f_reads() %>% mutate(d = as_date(read_ts)) %>%
      group_by(d) %>% summarise(g = sum(consumption_gallons, na.rm = TRUE),
                                .groups = "drop") %>%
      ggplot(aes(d, g)) + geom_line(color = "#2c7fb8", linewidth = 0.7) +
      scale_y_continuous(labels = comma) +
      labs(x = NULL, y = "Gallons / day", title = "Daily metered demand")
  })

  output$diurnal_plot <- renderPlot({
    f_reads() %>%
      left_join(meters %>% select(meter_id, customer_class), by = "meter_id") %>%
      mutate(hr = hour(read_ts)) %>%
      group_by(customer_class, hr) %>%
      summarise(g = mean(consumption_gallons, na.rm = TRUE), .groups = "drop") %>%
      ggplot(aes(hr, g, color = customer_class)) + geom_line(linewidth = 1) +
      labs(x = "Hour of day", y = "Mean gal/hr", color = NULL,
           title = "Average diurnal profile")
  })

  output$anom_bar <- renderPlot({
    f_anomalies() %>% filter(any_anomaly) %>% count(primary_anomaly) %>%
      ggplot(aes(reorder(primary_anomaly, n), n, fill = primary_anomaly)) +
      geom_col(show.legend = FALSE) + scale_fill_manual(values = pal) +
      coord_flip() + labs(x = NULL, y = "Meters", title = "Flagged by type")
  })

  output$meter_trace <- renderPlot({
    req(input$anom_meter)
    typ <- anomalies$primary_anomaly[anomalies$meter_id == input$anom_meter][1]
    reads %>% filter(meter_id == input$anom_meter) %>%
      ggplot(aes(read_ts, consumption_gallons)) +
      geom_line(color = "#2c7fb8", linewidth = 0.3) +
      labs(x = NULL, y = "Gallons / hour",
           title = paste0("Meter ", input$anom_meter, " (", typ, ")"))
  })

  output$anom_table <- renderDT({
    f_anomalies() %>% filter(any_anomaly) %>%
      transmute(meter_id, customer_class, route_id, anomaly = primary_anomaly,
                overnight_flow_gph = round(median_night_flow, 2),
                est_wasted_gallons = round(est_wasted_gallons),
                longest_zero_run, negative_reads) %>%
      arrange(desc(est_wasted_gallons)) %>%
      datatable(rownames = FALSE, options = list(pageLength = 8))
  })

  output$tier_plot <- renderPlot({
    f_segments() %>% count(usage_tier) %>%
      ggplot(aes(usage_tier, n, fill = usage_tier)) +
      geom_col(show.legend = FALSE) +
      labs(x = NULL, y = "Meters", title = "Usage tier")
  })

  output$pattern_plot <- renderPlot({
    f_segments() %>% count(usage_pattern) %>%
      ggplot(aes(reorder(usage_pattern, n), n)) +
      geom_col(fill = "#1b9e77") + coord_flip() +
      labs(x = NULL, y = "Meters", title = "Behavioural pattern")
  })

  output$seg_table <- renderDT({
    f_segments() %>%
      transmute(meter_id, customer_class, usage_tier, usage_pattern,
                avg_daily_gal = round(avg_daily_gal, 1),
                peak_to_median = round(peak_to_median, 1),
                summer_ratio = round(summer_ratio, 2)) %>%
      datatable(rownames = FALSE, options = list(pageLength = 8))
  })

  output$nrw_plot <- renderPlot({
    if (is.null(nrw)) return(NULL)
    ggplot(nrw, aes(d, nrw_percent)) +
      geom_line(color = "#d7301f", linewidth = 0.6) +
      geom_hline(yintercept = mean(nrw$nrw_percent), linetype = "dashed") +
      labs(x = NULL, y = "NRW (%)",
           title = sprintf("Daily non-revenue water (avg %.1f%%)",
                           mean(nrw$nrw_percent)))
  })

  output$nrw_table <- renderDT({
    if (is.null(nrw)) return(NULL)
    nrw %>% transmute(date = d, supplied_gallons,
                      metered_gallons = round(metered),
                      nrw_percent = round(nrw_percent, 1)) %>%
      datatable(rownames = FALSE, options = list(pageLength = 8))
  })
}

shinyApp(ui, server)

-- 01_create_tables.sql -------------------------------------------------------
-- Snowflake DDL for the AMI analytics schema.
-- Run once to stand up the warehouse objects this project reads from.
-- Mirrors the synthetic CSVs in data/ so the R workflow is identical whether it
-- reads local files or a live Snowflake warehouse.
-- ---------------------------------------------------------------------------

-- Warehouse / database / schema --------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS ANALYTICS_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND   = 60          -- suspend after 60s idle to control credit spend
  AUTO_RESUME    = TRUE
  INITIALLY_SUSPENDED = TRUE;

CREATE DATABASE IF NOT EXISTS WATER;
CREATE SCHEMA   IF NOT EXISTS WATER.AMI;

USE WAREHOUSE ANALYTICS_WH;
USE SCHEMA    WATER.AMI;

-- Meter / service-connection roster ----------------------------------------
CREATE OR REPLACE TABLE METERS (
    meter_id        STRING       NOT NULL,
    account_id      STRING,
    customer_class  STRING,                 -- Residential, Commercial, ...
    meter_size      STRING,
    route_id        STRING,
    install_year    NUMBER(4,0),
    latitude        FLOAT,
    longitude       FLOAT,
    CONSTRAINT pk_meters PRIMARY KEY (meter_id)
);

-- Hourly interval reads (the core AMI fact table) --------------------------
CREATE OR REPLACE TABLE INTERVAL_READS (
    meter_id            STRING       NOT NULL,
    read_ts             TIMESTAMP_NTZ NOT NULL,
    consumption_gallons FLOAT,
    CONSTRAINT fk_reads_meter FOREIGN KEY (meter_id) REFERENCES METERS(meter_id)
);

-- Clustering the fact table by meter + day keeps per-meter time-series scans
-- (the dominant query pattern for AMI analysis) fast and cheap.
ALTER TABLE INTERVAL_READS CLUSTER BY (meter_id, TO_DATE(read_ts));

-- Daily system supply (for non-revenue water) ------------------------------
CREATE OR REPLACE TABLE SYSTEM_SUPPLY (
    supply_date       DATE  NOT NULL,
    supplied_gallons  FLOAT,
    CONSTRAINT pk_supply PRIMARY KEY (supply_date)
);

-- Output table the R pipeline writes anomaly results back to ---------------
CREATE OR REPLACE TABLE ANOMALY_RESULTS (
    meter_id          STRING,
    primary_anomaly   STRING,
    any_anomaly       BOOLEAN,
    median_night_flow FLOAT,
    est_wasted_gallons FLOAT,
    longest_zero_run  NUMBER,
    negative_reads    NUMBER,
    customer_class    STRING,
    scored_at         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

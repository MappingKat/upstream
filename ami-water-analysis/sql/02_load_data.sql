-- 02_load_data.sql -----------------------------------------------------------
-- Load the synthetic CSVs into Snowflake via an internal stage + COPY INTO.
-- Demonstrates the standard Snowflake bulk-ingest pattern the WRA role uses to
-- onboard a utility's AMI extract.
-- ---------------------------------------------------------------------------

USE WAREHOUSE ANALYTICS_WH;
USE SCHEMA    WATER.AMI;

-- A reusable CSV file format (header row, comma-delimited, quoted strings) ---
CREATE OR REPLACE FILE FORMAT CSV_STD
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NA')
    EMPTY_FIELD_AS_NULL = TRUE;

-- Internal stage to upload the CSVs to -------------------------------------
CREATE OR REPLACE STAGE AMI_STAGE FILE_FORMAT = CSV_STD;

-- From SnowSQL (CLI), upload the local files to the stage:
--   PUT file://data/meters.csv          @AMI_STAGE;
--   PUT file://data/interval_reads.csv  @AMI_STAGE;
--   PUT file://data/system_supply.csv   @AMI_STAGE;

-- Bulk load each table ------------------------------------------------------
COPY INTO METERS
    FROM @AMI_STAGE/meters.csv
    FILE_FORMAT = (FORMAT_NAME = CSV_STD)
    ON_ERROR = 'ABORT_STATEMENT';

COPY INTO INTERVAL_READS
    FROM @AMI_STAGE/interval_reads.csv
    FILE_FORMAT = (FORMAT_NAME = CSV_STD)
    ON_ERROR = 'CONTINUE';   -- tolerate the occasional bad read; review rejects

COPY INTO SYSTEM_SUPPLY
    FROM @AMI_STAGE/system_supply.csv
    FILE_FORMAT = (FORMAT_NAME = CSV_STD)
    ON_ERROR = 'ABORT_STATEMENT';

-- Quick sanity checks -------------------------------------------------------
SELECT 'METERS' AS tbl, COUNT(*) AS rows FROM METERS
UNION ALL SELECT 'INTERVAL_READS', COUNT(*) FROM INTERVAL_READS
UNION ALL SELECT 'SYSTEM_SUPPLY',  COUNT(*) FROM SYSTEM_SUPPLY;

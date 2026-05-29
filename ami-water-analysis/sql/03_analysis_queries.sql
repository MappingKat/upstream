-- 03_analysis_queries.sql ----------------------------------------------------
-- Analytical Snowflake SQL for AMI consumption data.
-- These run server-side in the warehouse; the R workflow can call them directly
-- (via DBI::dbGetQuery) for heavy aggregations, then visualize the results.
-- Demonstrates the "push compute to Snowflake, pull results to R" pattern.
-- ---------------------------------------------------------------------------

USE WAREHOUSE ANALYTICS_WH;
USE SCHEMA    WATER.AMI;

-- 1. System-wide daily demand -----------------------------------------------
SELECT
    TO_DATE(read_ts)                  AS read_date,
    ROUND(SUM(consumption_gallons))   AS total_gallons,
    COUNT(DISTINCT meter_id)          AS active_meters
FROM INTERVAL_READS
GROUP BY 1
ORDER BY 1;

-- 2. Average diurnal (hour-of-day) profile by customer class ----------------
SELECT
    m.customer_class,
    HOUR(r.read_ts)                       AS hour_of_day,
    ROUND(AVG(r.consumption_gallons), 2)  AS avg_gallons
FROM INTERVAL_READS r
JOIN METERS m USING (meter_id)
GROUP BY 1, 2
ORDER BY 1, 2;

-- 3. Overnight minimum flow per meter (leak screening) ----------------------
-- The overnight minimum (hours 1-4) is the core leak signal: a persistently
-- non-zero overnight minimum indicates continuous flow when no one is using
-- water. Ranks meters by their typical overnight minimum.
WITH nightly AS (
    SELECT
        meter_id,
        TO_DATE(read_ts)              AS read_date,
        MIN(consumption_gallons)      AS night_min
    FROM INTERVAL_READS
    WHERE HOUR(read_ts) BETWEEN 1 AND 4
    GROUP BY 1, 2
)
SELECT
    meter_id,
    ROUND(MEDIAN(night_min), 2)              AS median_overnight_flow_gph,
    COUNT_IF(night_min > 0.5)                 AS nights_with_flow,
    COUNT(*)                                  AS nights_observed
FROM nightly
GROUP BY 1
HAVING median_overnight_flow_gph > 0.5
ORDER BY median_overnight_flow_gph DESC;

-- 4. Data-quality screen: negative / null reads -----------------------------
-- Negative consumption is physically impossible; surface meters reporting it.
SELECT
    meter_id,
    COUNT_IF(consumption_gallons < 0)  AS negative_reads,
    COUNT_IF(consumption_gallons IS NULL) AS null_reads,
    COUNT(*)                            AS total_reads,
    MIN(consumption_gallons)           AS min_read
FROM INTERVAL_READS
GROUP BY 1
HAVING negative_reads > 0 OR null_reads > 0
ORDER BY negative_reads DESC;

-- 5. Non-revenue water (NRW) by day -----------------------------------------
-- Compares water supplied into the system against total metered consumption.
SELECT
    s.supply_date,
    s.supplied_gallons,
    d.metered_gallons,
    s.supplied_gallons - d.metered_gallons                          AS nrw_gallons,
    ROUND(100.0 * (s.supplied_gallons - d.metered_gallons)
          / NULLIF(s.supplied_gallons, 0), 1)                       AS nrw_percent
FROM SYSTEM_SUPPLY s
JOIN (
    SELECT TO_DATE(read_ts) AS supply_date,
           SUM(consumption_gallons) AS metered_gallons
    FROM INTERVAL_READS
    GROUP BY 1
) d USING (supply_date)
ORDER BY s.supply_date;

-- 6. Top water users (targeting conservation outreach) ----------------------
SELECT
    m.meter_id,
    m.customer_class,
    m.route_id,
    ROUND(SUM(r.consumption_gallons))                       AS total_gallons,
    ROUND(SUM(r.consumption_gallons)
          / COUNT(DISTINCT TO_DATE(r.read_ts)), 1)          AS avg_daily_gallons
FROM INTERVAL_READS r
JOIN METERS m USING (meter_id)
GROUP BY 1, 2, 3
ORDER BY total_gallons DESC
LIMIT 25;

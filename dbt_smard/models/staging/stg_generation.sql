{{ config(
  materialized='table',
  partition_by={
    "field": "timestamp_utc",
    "data_type": "timestamp",
    "granularity": "day"
  },
) }}

SELECT
  timestamp_utc,
  DATETIME(timestamp_utc, 'Europe/Berlin') as berlin_time,
  DATE(DATETIME(timestamp_utc, 'Europe/Berlin')) as berlin_date,
  energy_type,
  category,
  value_mwh as generation_mwh,
  src.`date` as date_string,
  EXTRACT(YEAR FROM timestamp_utc) as year,
  EXTRACT(MONTH FROM timestamp_utc) as month,
  EXTRACT(HOUR FROM DATETIME(timestamp_utc, 'Europe/Berlin')) as hour_berlin,
  EXTRACT(QUARTER FROM timestamp_utc) as quarter,
  -- Optional: renewable energy share calculation
  NULL as renewable_share_pct
FROM {{ source('smard_raw', 'electricity_generation') }} as src
WHERE 1=1
  AND value_mwh IS NOT NULL
  AND timestamp_utc IS NOT NULL

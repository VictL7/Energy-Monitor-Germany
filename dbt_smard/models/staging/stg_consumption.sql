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
  grid_load,
  residual_load,
  pumped_storage_consumption,
  date as date_string,
  EXTRACT(YEAR FROM timestamp_utc) as year,
  EXTRACT(MONTH FROM timestamp_utc) as month,
  EXTRACT(HOUR FROM DATETIME(timestamp_utc, 'Europe/Berlin')) as hour_berlin,
  EXTRACT(QUARTER FROM timestamp_utc) as quarter
FROM {{ source('smard_raw', 'grid_consumption') }}
WHERE 1=1
  AND grid_load IS NOT NULL
  AND timestamp_utc IS NOT NULL

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
  price_eur_mwh,
  price_type,
  date as date_string,
  EXTRACT(YEAR FROM timestamp_utc) as year,
  EXTRACT(MONTH FROM timestamp_utc) as month,
  EXTRACT(HOUR FROM DATETIME(timestamp_utc, 'Europe/Berlin')) as hour_berlin,
  EXTRACT(QUARTER FROM timestamp_utc) as quarter,
  -- 价格分类
  CASE 
    WHEN price_eur_mwh < 0 THEN 'negative'
    WHEN price_eur_mwh < 20 THEN 'low'
    WHEN price_eur_mwh < 50 THEN 'medium'
    WHEN price_eur_mwh < 100 THEN 'high'
    ELSE 'very_high'
  END as price_category
FROM {{ source('smard_raw', 'electricity_prices') }}
WHERE 1=1
  AND price_eur_mwh IS NOT NULL
  AND timestamp_utc IS NOT NULL

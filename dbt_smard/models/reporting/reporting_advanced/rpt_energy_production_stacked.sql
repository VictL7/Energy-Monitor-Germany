{{ config(
  materialized='table',
  partition_by={
    "field": "date",
    "data_type": "date"
  },
  description='Energy Production Stacked Data - Support drill-down from Year to Day with energy type distribution'
) }}

-- Purpose: Support Tableau stacked column chart with year/month/day granularity by energy type distribution
-- Granularity: daily/monthly/yearly
-- Use Case: Visualize energy generation types as stacked chart + grid_load overlay line

WITH hourly_generation AS (
  SELECT
    stg_gen.berlin_date as date,
    stg_gen.hour_berlin,
    stg_gen.energy_type,
    SUM(stg_gen.generation_mwh) as generation_mwh
  FROM {{ ref('stg_generation') }} stg_gen
  WHERE stg_gen.berlin_date BETWEEN '2019-01-01' AND '2025-12-31'
  GROUP BY 1, 2, 3
),

hourly_with_load AS (
  SELECT
    hg.date,
    hg.hour_berlin,
    hg.energy_type,
    hg.generation_mwh,
    EXTRACT(YEAR FROM hg.date) as year,
    EXTRACT(MONTH FROM hg.date) as month,
    EXTRACT(DAYOFWEEK FROM hg.date) as day_of_week_num,
    FORMAT_DATE('%A', hg.date) as day_of_week_name,
    FORMAT_DATE('%b', hg.date) as month_short,
    COALESCE(cons.total_grid_load_mwh, 0) as grid_load_mwh
  FROM hourly_generation hg
  LEFT JOIN {{ ref('fct_energy_balance') }} cons
    ON hg.date = cons.date AND hg.hour_berlin = cons.hour_berlin
),

daily_aggregates AS (
  SELECT
    date,
    CAST(year as INT64) as year,
    CAST(month as INT64) as month,
    CAST(month_short as STRING) as month_short,
    CAST(day_of_week_num as INT64) as day_of_week_num,
    CAST(day_of_week_name as STRING) as day_of_week_name,
    energy_type,
    SUM(generation_mwh) as total_generation_mwh,
    AVG(grid_load_mwh) as avg_grid_load_mwh,
    'DAILY' as granularity
  FROM hourly_with_load
  GROUP BY date, year, month, month_short, day_of_week_num, day_of_week_name, energy_type
),

monthly_temp AS (
  SELECT
    CAST(year as INT64) as year,
    CAST(month as INT64) as month,
    CAST(month_short as STRING) as month_short,
    energy_type,
    LAST_DAY(DATE_TRUNC(DATE(CONCAT(CAST(year as STRING), '-', LPAD(CAST(month as STRING), 2, '0'), '-01')), MONTH)) as date,
    SUM(generation_mwh) as total_generation_mwh,
    AVG(grid_load_mwh) as avg_grid_load_mwh
  FROM hourly_with_load
  GROUP BY year, month, month_short, energy_type
),

monthly_aggregates AS (
  SELECT
    date,
    year,
    month,
    month_short,
    CAST(NULL as INT64) as day_of_week_num,
    CAST(NULL as STRING) as day_of_week_name,
    energy_type,
    total_generation_mwh,
    avg_grid_load_mwh,
    'MONTHLY' as granularity
  FROM monthly_temp
),

yearly_temp AS (
  SELECT
    year,
    energy_type,
    DATE(CONCAT(CAST(year as STRING), '-12-31')) as date,
    SUM(generation_mwh) as total_generation_mwh,
    AVG(grid_load_mwh) as avg_grid_load_mwh
  FROM hourly_with_load
  GROUP BY year, energy_type
),

yearly_aggregates AS (
  SELECT
    date,
    year,
    CAST(year as INT64) as month,
    CAST(year as STRING) as month_short,
    CAST(NULL as INT64) as day_of_week_num,
    CAST(NULL as STRING) as day_of_week_name,
    energy_type,
    total_generation_mwh,
    avg_grid_load_mwh,
    'YEARLY' as granularity
  FROM yearly_temp
)

SELECT
  *,
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM daily_aggregates

UNION ALL

SELECT
  *,
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM monthly_aggregates

UNION ALL

SELECT
  *,
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM yearly_aggregates

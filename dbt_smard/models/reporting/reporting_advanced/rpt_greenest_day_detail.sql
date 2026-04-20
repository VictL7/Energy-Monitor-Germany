{{ config(
  materialized='table',
  description='Greenest Day Detail - Hourly breakdown of the greenest day (energy production stacked + grid load)'
) }}

-- Purpose: Find the day with highest green energy sufficiency percentage, output 24-hour energy type distribution + grid_load
-- Use Case: Visualize full-day energy production stacked chart + grid_load overlay line, annotate total generation and surplus

WITH daily_green_stats AS (
  SELECT
    fct.date,
    FORMAT_DATE('%Y-%m-%d', fct.date) as date_str,
    COUNTIF(fct.avg_residual_load_mwh < 0) / 4 as green_sufficient_hours,
    ROUND(100.0 * COUNTIF(fct.avg_residual_load_mwh < 0) / COUNT(*), 2) as green_sufficient_pct,
    ROUND(SUM(fct.total_generation_mwh), 2) as total_generation_mwh,
    ROUND(SUM(fct.balance_gap_mwh), 2) as total_surplus_mwh,
    ROW_NUMBER() OVER (ORDER BY 100.0 * COUNTIF(fct.avg_residual_load_mwh < 0) / COUNT(*) DESC) as green_rank
  FROM {{ ref('fct_energy_balance') }} fct
  WHERE fct.date BETWEEN '2019-01-01' AND '2025-12-31'
  GROUP BY fct.date
),

greenest_day_id AS (
  SELECT
    date,
    date_str,
    green_sufficient_hours,
    green_sufficient_pct,
    total_generation_mwh,
    total_surplus_mwh
  FROM daily_green_stats
  WHERE green_rank = 1
),

hourly_generation AS (
  SELECT
    stg_gen.berlin_date as date,
    stg_gen.hour_berlin,
    stg_gen.energy_type,
    SUM(stg_gen.generation_mwh) as generation_mwh
  FROM {{ ref('stg_generation') }} stg_gen
  GROUP BY stg_gen.berlin_date, stg_gen.hour_berlin, stg_gen.energy_type
),

hourly_breakdown AS (
  SELECT
    gd.date,
    gd.date_str,
    fct.hour_berlin as hour,
    LPAD(CAST(fct.hour_berlin as STRING), 2, '0') as hour_str,
    gen.energy_type,
    ROUND(COALESCE(gen.generation_mwh, 0), 2) as generation_mwh,
    ROUND(fct.total_grid_load_mwh, 2) as grid_load_mwh,
    ROUND(fct.balance_gap_mwh, 2) as surplus_mwh,
    CASE WHEN fct.avg_residual_load_mwh < 0 THEN 'Green' ELSE 'Non-Green' END as green_flag,
    gd.green_sufficient_hours as day_green_hours,
    gd.green_sufficient_pct as day_green_pct,
    gd.total_generation_mwh as day_total_generation,
    gd.total_surplus_mwh as day_total_surplus
  FROM greenest_day_id gd
  LEFT JOIN {{ ref('fct_energy_balance') }} fct
    ON gd.date = fct.date
  LEFT JOIN hourly_generation gen
    ON gd.date = gen.date
    AND fct.hour_berlin = gen.hour_berlin
  ORDER BY fct.hour_berlin, gen.energy_type
)

SELECT
  *,
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM hourly_breakdown

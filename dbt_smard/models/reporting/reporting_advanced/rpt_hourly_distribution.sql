{{ config(
  materialized='table',
  description='Hourly Distribution - Percentage of intervals with renewable sufficiency by hour of day'
) }}

-- 目的：按小时(0-23)统计绿电充足率，看一天中什么时候最绿
-- 粒度：每小时1行（0-23 Berlin时间）
-- 指标：total_intervals, green_intervals, green_pct, avg_price, avg_grid_load

WITH hourly_stats AS (
  SELECT
    fct.hour_berlin as hour,
    LPAD(CAST(fct.hour_berlin as STRING), 2, '0') as hour_str,
    COUNT(*) as total_intervals,
    COUNTIF(fct.avg_residual_load_mwh < 0) as green_sufficient_intervals,
    COUNT(*) - COUNTIF(fct.avg_residual_load_mwh < 0) as non_green_intervals,
    ROUND(100.0 * COUNTIF(fct.avg_residual_load_mwh < 0) / COUNT(*), 2) as green_sufficient_pct,
    ROUND(AVG(fct.avg_residual_load_mwh), 2) as avg_residual_load_mwh,
    ROUND(AVG(fct.total_grid_load_mwh), 2) as avg_grid_load_mwh,
    ROUND(AVG(fct.total_generation_mwh), 2) as avg_generation_mwh,
    ROUND(AVG(CASE WHEN fct.avg_residual_load_mwh < 0 THEN fct.avg_price_eur_mwh END), 2) as avg_price_green,
    ROUND(AVG(CASE WHEN fct.avg_residual_load_mwh >= 0 THEN fct.avg_price_eur_mwh END), 2) as avg_price_non_green,
    COUNT(DISTINCT CASE WHEN fct.avg_residual_load_mwh < 0 THEN fct.date END) as green_days,
    COUNT(DISTINCT fct.date) as total_days
  FROM {{ ref('fct_energy_balance') }} fct
  WHERE fct.date BETWEEN '2019-01-01' AND '2025-12-31'
  GROUP BY fct.hour_berlin
)

SELECT
  hour,
  hour_str,
  total_intervals,
  green_sufficient_intervals,
  non_green_intervals,
  green_sufficient_pct,
  avg_residual_load_mwh,
  avg_grid_load_mwh,
  avg_generation_mwh,
  avg_price_green,
  avg_price_non_green,
  ROUND(avg_price_non_green - avg_price_green, 2) as price_diff_non_green_vs_green,
  green_days,
  total_days,
  ROUND(100.0 * green_days / total_days, 2) as green_days_pct,
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM hourly_stats
ORDER BY hour

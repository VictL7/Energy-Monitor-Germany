{{ config(
  materialized='table',
  description='Price Distribution - Scatter plot data for surplus vs non-surplus intervals'
) }}

-- 目的：过剩和非过剩时段的电价分布，用于散点图分析
-- 粒度：每个15分钟间隔1行
-- 指标：price_eur_mwh, grid_load, generation, surplus_flag, date, hour

WITH price_scatter_data AS (
  SELECT
    fct.date,
    FORMAT_DATE('%Y-%m-%d', fct.date) as date_str,
    EXTRACT(YEAR FROM fct.date) as year,
    EXTRACT(MONTH FROM fct.date) as month,
    fct.hour_berlin as hour,
    fct.avg_price_eur_mwh as price_eur_mwh,
    fct.total_grid_load_mwh as grid_load_mwh,
    fct.total_generation_mwh as generation_mwh,
    fct.balance_gap_mwh as surplus_mwh,
    fct.is_surplus as is_surplus,
    CASE WHEN fct.is_surplus = 1 THEN 'Surplus' ELSE 'Non-Surplus' END as surplus_flag,
    fct.avg_residual_load_mwh as residual_load_mwh,
    CASE WHEN fct.avg_residual_load_mwh < 0 THEN 'Green' ELSE 'Non-Green' END as green_flag,
    ROUND(SAFE_DIVIDE(fct.total_generation_mwh, fct.total_grid_load_mwh) * 100, 2) as renewable_share_pct
  FROM {{ ref('fct_energy_balance') }} fct
  WHERE fct.date BETWEEN '2019-01-01' AND '2025-12-31'
    AND fct.avg_price_eur_mwh IS NOT NULL
)

SELECT
  *,
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM price_scatter_data
ORDER BY date, hour

{{ config(
  materialized='table',
  description='Green Energy Sufficiency Summary - KPI Dashboard'
) }}

-- 粒度：KPI 摘要表（全期间 + 最近一年）
-- 用途：Tableau/BI 仪表板的KPI卡片
-- 更新频率：每天凌晨 dbt run

WITH full_period_stats AS (
  SELECT
    COUNT(*) as total_days,
    SUM(CASE WHEN renewable_sufficient_hours >= 12 THEN 1 ELSE 0 END) as green_sufficient_days,
    ROUND(100.0 * SUM(CASE WHEN renewable_sufficient_hours >= 12 THEN 1 ELSE 0 END) / COUNT(*), 2) as green_sufficient_pct,
    ROUND(AVG((total_generation_mwh - total_grid_load_mwh) / NULLIF(total_grid_load_mwh, 0) * 100), 2) as avg_renewable_share_pct,
    ROUND(AVG(total_generation_mwh - total_grid_load_mwh), 2) as avg_balance_gap_mwh,
    ROUND(AVG(avg_price_eur_mwh), 2) as avg_price_eur_mwh
  FROM {{ ref('rpt_daily_summary') }}
  WHERE date IS NOT NULL
),

latest_year_stats AS (
  SELECT
    EXTRACT(YEAR FROM MAX(date)) as latest_year,
    COUNT(*) as days_in_latest_year,
    SUM(CASE WHEN renewable_sufficient_hours >= 12 THEN 1 ELSE 0 END) as green_days_latest_year,
    ROUND(100.0 * SUM(CASE WHEN renewable_sufficient_hours >= 12 THEN 1 ELSE 0 END) / COUNT(*), 2) as green_pct_latest_year
  FROM {{ ref('rpt_daily_summary') }}
  WHERE date IS NOT NULL
    AND EXTRACT(YEAR FROM date) = (SELECT EXTRACT(YEAR FROM MAX(date)) FROM {{ ref('rpt_daily_summary') }})
)

SELECT
  'FULL_PERIOD' as metric_type,
  total_days,
  green_sufficient_days,
  green_sufficient_pct,
  avg_renewable_share_pct,
  avg_balance_gap_mwh,
  avg_price_eur_mwh,
  CAST(NULL as INT64) as days_in_period,
  CAST(NULL as INT64) as green_days_in_period,
  CAST(NULL as FLOAT64) as green_pct_in_period,
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM full_period_stats

UNION ALL

SELECT
  'LATEST_YEAR' as metric_type,
  CAST(NULL as INT64) as total_days,
  CAST(NULL as INT64) as green_sufficient_days,
  CAST(NULL as FLOAT64) as green_sufficient_pct,
  CAST(NULL as FLOAT64) as avg_renewable_share_pct,
  CAST(NULL as FLOAT64) as avg_balance_gap_mwh,
  CAST(NULL as FLOAT64) as avg_price_eur_mwh,
  days_in_latest_year,
  green_days_latest_year,
  green_pct_latest_year,
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM latest_year_stats

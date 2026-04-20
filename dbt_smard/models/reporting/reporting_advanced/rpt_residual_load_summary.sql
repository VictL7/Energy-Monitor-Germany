{{ config(
  materialized='table',
  description='Residual Load Summary - Full Period KPI (2019-2025)'
) }}

-- 目的：全期间Residual Load分析，显示总时段数、绿电时段数、比例、每天平均小时数
-- 粒度：单行输出，包含全期间统计

WITH residual_load_analysis AS (
  SELECT
    COUNT(DISTINCT fct.date) as total_days,
    COUNT(*) as total_15min_intervals,  -- 每天96个15分钟间隔
    COUNTIF(fct.avg_residual_load_mwh < 0) as green_sufficient_intervals,
    ROUND(100.0 * COUNTIF(fct.avg_residual_load_mwh < 0) / COUNT(*), 2) as green_sufficient_pct,
    ROUND(COUNTIF(fct.avg_residual_load_mwh < 0) / CAST(COUNT(DISTINCT fct.date) as FLOAT64) / 4, 2) as avg_green_hours_per_day,  -- 除以4因为每小时4个15分钟
    AVG(CASE WHEN fct.avg_residual_load_mwh < 0 THEN 1.0 ELSE 0 END) * 24 as avg_green_hours_per_day_v2,
    COUNT(DISTINCT CASE WHEN fct.avg_residual_load_mwh < 0 THEN fct.date END) as days_with_some_green_hours,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN fct.avg_residual_load_mwh < 0 THEN fct.date END) / COUNT(DISTINCT fct.date), 2) as days_with_green_pct,
    MIN(fct.date) as period_start_date,
    MAX(fct.date) as period_end_date
  FROM {{ ref('fct_energy_balance') }} fct
  WHERE fct.date BETWEEN '2019-01-01' AND '2025-12-31'
)

SELECT
  '2019-2025' as period,
  total_days,
  total_15min_intervals,
  green_sufficient_intervals,
  green_sufficient_pct,
  ROUND(avg_green_hours_per_day, 2) as avg_green_hours_per_day,
  days_with_some_green_hours,
  days_with_green_pct,
  period_start_date,
  period_end_date,
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM residual_load_analysis

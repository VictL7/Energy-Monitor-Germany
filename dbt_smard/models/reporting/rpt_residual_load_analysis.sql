{{ config(
  materialized='table',
  description='Residual Load Analysis Report - Green Energy Sufficiency Trends'
) }}

-- 粒度：1行 = 1年或1月
-- 用途：年度/月度绿电充足率、可再生能源占比、传统能源需求分析
-- 更新频率：每天凌晨 dbt run

WITH daily_aggregates AS (
  SELECT
    date,
    EXTRACT(YEAR FROM date) as year,
    EXTRACT(MONTH FROM date) as month,
    
    -- Renewable energy sufficiency: renewable_sufficient_hours = 24 means residual load was negative all day
    renewable_sufficient_hours as is_green_sufficient_hours,
    CASE WHEN renewable_sufficient_hours >= 12 THEN 1 ELSE 0 END as is_green_sufficient,
    
    -- Renewable energy metrics (as percentage of grid load)
    ROUND((total_generation_mwh - total_grid_load_mwh) / NULLIF(total_grid_load_mwh, 0) * 100, 2) as renewable_share_pct,
    
    -- Demand metrics
    total_grid_load_mwh,
    total_generation_mwh,
    ROUND((total_generation_mwh - total_grid_load_mwh) / NULLIF(total_grid_load_mwh, 0), 4) as avg_residual_ratio,
    
    -- Price metrics
    avg_price_eur_mwh,
    surplus_pct
    
  FROM {{ ref('rpt_daily_summary') }}
  WHERE date IS NOT NULL
),

yearly_stats AS (
  SELECT
    year,
    COUNT(*) as total_days,
    SUM(is_green_sufficient) as green_sufficient_days,
    ROUND(100.0 * SUM(is_green_sufficient) / COUNT(*), 2) as green_sufficient_pct,
    ROUND(AVG(renewable_share_pct), 2) as avg_renewable_share_pct,
    ROUND(AVG(avg_residual_ratio), 4) as avg_residual_ratio,
    ROUND(MIN(avg_residual_ratio), 4) as min_residual_ratio,
    ROUND(MAX(avg_residual_ratio), 4) as max_residual_ratio,
    ROUND(AVG(avg_price_eur_mwh), 2) as avg_price_eur_mwh,
    ROUND(STDDEV(avg_price_eur_mwh), 2) as stddev_price_eur_mwh
  FROM daily_aggregates
  GROUP BY year
),

monthly_stats AS (
  SELECT
    year,
    month,
    COUNT(*) as total_days,
    SUM(is_green_sufficient) as green_sufficient_days,
    ROUND(100.0 * SUM(is_green_sufficient) / COUNT(*), 2) as green_sufficient_pct,
    ROUND(AVG(renewable_share_pct), 2) as avg_renewable_share_pct,
    ROUND(AVG(avg_residual_ratio), 4) as avg_residual_ratio,
    ROUND(AVG(avg_price_eur_mwh), 2) as avg_price_eur_mwh,
    FORMAT_DATE('%B', DATE(CONCAT(CAST(year as STRING), '-', LPAD(CAST(month as STRING), 2, '0'), '-01'))) as month_name
  FROM daily_aggregates
  GROUP BY year, month
)

SELECT
  'YEARLY' as report_type,
  CAST(year as STRING) as period,
  CAST(year as STRING) as year_str,
  'Full Year' as month_name,  -- 用'Full Year'替代NULL，Tableau不会过滤
  CAST(NULL as INT64) as month_num,
  total_days,
  green_sufficient_days,
  green_sufficient_pct,
  avg_renewable_share_pct,
  avg_residual_ratio,
  min_residual_ratio,
  max_residual_ratio,
  avg_price_eur_mwh,
  stddev_price_eur_mwh,
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM yearly_stats

UNION ALL

SELECT
  'MONTHLY' as report_type,
  CONCAT(CAST(year as STRING), '-', LPAD(CAST(month as STRING), 2, '0')) as period,
  CAST(year as STRING) as year_str,
  month_name,
  month as month_num,
  total_days,
  green_sufficient_days,
  green_sufficient_pct,
  avg_renewable_share_pct,
  avg_residual_ratio,
  CAST(NULL as FLOAT64) as min_residual_ratio,
  CAST(NULL as FLOAT64) as max_residual_ratio,
  avg_price_eur_mwh,
  CAST(NULL as FLOAT64) as stddev_price_eur_mwh,
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM monthly_stats

ORDER BY period DESC

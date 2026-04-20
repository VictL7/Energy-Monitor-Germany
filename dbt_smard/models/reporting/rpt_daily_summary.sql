{{ config(
  materialized='table'
) }}

-- 粒度：1行 = 1天
-- 用途：Tableau KPI 仪表板、日度趋势分析
-- 更新频率：每天凌晨 dbt run
-- 预期行数：2,700 行（2019-2026年4月）

SELECT
  date,
  EXTRACT(YEAR FROM date) as year,
  EXTRACT(MONTH FROM date) as month,
  EXTRACT(QUARTER FROM date) as quarter,
  EXTRACT(WEEK FROM date) as week,
  EXTRACT(DAYOFWEEK FROM date) as day_of_week_num,
  FORMAT_DATE('%A', date) as day_of_week_name,
  
  -- 发电指标（所有能源）
  SUM(total_generation_mwh) as total_generation_mwh,
  AVG(total_generation_mwh) as avg_hourly_generation_mwh,
  MAX(total_generation_mwh) as max_hourly_generation_mwh,
  MIN(total_generation_mwh) as min_hourly_generation_mwh,
  STDDEV(total_generation_mwh) as stddev_generation_mwh,
  
  -- 需求指标
  SUM(total_grid_load_mwh) as total_grid_load_mwh,
  AVG(total_grid_load_mwh) as avg_hourly_load_mwh,
  MAX(total_grid_load_mwh) as max_hourly_load_mwh,
  MIN(total_grid_load_mwh) as min_hourly_load_mwh,
  
  -- 盈余指标
  SUM(balance_gap_mwh) as total_balance_gap_mwh,
  COUNTIF(is_surplus = 1) as surplus_hours,
  24 - COUNTIF(is_surplus = 1) as deficit_hours,
  ROUND(100.0 * COUNTIF(is_surplus = 1) / 24, 2) as surplus_pct,
  AVG(supply_ratio) as avg_supply_ratio,
  
  -- 电价指标
  AVG(avg_price_eur_mwh) as avg_price_eur_mwh,
  MIN(avg_price_eur_mwh) as min_price_eur_mwh,
  MAX(avg_price_eur_mwh) as max_price_eur_mwh,
  SUM(CASE WHEN avg_price_eur_mwh < 0 THEN 1 ELSE 0 END) as negative_price_hours,
  
  -- 绿电指标（Residual Load < 0）
  COUNTIF(avg_residual_load_mwh < 0) as renewable_sufficient_hours,
  ROUND(100.0 * COUNTIF(avg_residual_load_mwh < 0) / 24, 2) as renewable_sufficient_pct,
  
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM {{ ref('fct_energy_balance') }}
GROUP BY date, year, month, quarter, week, day_of_week_num, day_of_week_name

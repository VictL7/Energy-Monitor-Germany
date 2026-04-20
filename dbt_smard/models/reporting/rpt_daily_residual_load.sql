{{ config(
  materialized='table',
  description='Daily Residual Load Analysis - Green Energy Sufficiency Details',
  partition_by={
    "field": "date",
    "data_type": "date"
  }
) }}

-- 粒度：1行 = 1天
-- 用途：日度绿电充足率分析、季节性识别、最绿日期查询
-- 更新频率：每天凌晨 dbt run
-- 预期行数：2,700 行（2019-2026年）

SELECT
  date,
  EXTRACT(YEAR FROM date) as year,
  EXTRACT(MONTH FROM date) as month,
  EXTRACT(QUARTER FROM date) as quarter,
  EXTRACT(WEEK FROM date) as week,
  EXTRACT(DAYOFWEEK FROM date) as day_of_week_num,
  FORMAT_DATE('%A', date) as day_of_week_name,
  
  -- Daily generation and demand
  total_generation_mwh,
  total_grid_load_mwh,
  ROUND(total_generation_mwh - total_grid_load_mwh, 2) as balance_gap_mwh,
  
  -- Renewable energy metrics
  surplus_hours,
  deficit_hours,
  surplus_pct,
  
  -- Supply ratio analysis
  ROUND(avg_supply_ratio, 2) as avg_supply_ratio,
  
  -- Green energy sufficiency: renewable_sufficient_hours = 24 means residual load was negative all 24 hours
  -- This indicates renewables completely satisfied demand
  renewable_sufficient_hours,
  renewable_sufficient_pct,
  
  CASE WHEN renewable_sufficient_hours >= 12 THEN 1 ELSE 0 END as is_green_sufficient,
  
  -- Calculate renewable energy share (Generation / Grid Load)
  ROUND(
    (total_generation_mwh - total_grid_load_mwh) / NULLIF(total_grid_load_mwh, 0) * 100, 
    2
  ) as renewable_share_pct,
  
  -- Price metrics
  avg_price_eur_mwh,
  min_price_eur_mwh,
  max_price_eur_mwh,
  negative_price_hours,
  
  CURRENT_TIMESTAMP() as dbt_loaded_at
  
FROM {{ ref('rpt_daily_summary') }}

WHERE date IS NOT NULL

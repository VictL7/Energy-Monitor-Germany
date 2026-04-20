{{ config(
  materialized='table'
) }}

-- 粒度：1行 = 1小时
-- 用途：Tableau 热力图、时间序列详细分析
-- 更新频率：每天凌晨 dbt run
-- 预期行数：26,500 行（2019-2026年4月）

SELECT
  date,
  hour_berlin,
  EXTRACT(YEAR FROM date) as year,
  EXTRACT(MONTH FROM date) as month,
  EXTRACT(QUARTER FROM date) as quarter,
  EXTRACT(WEEK FROM date) as week,
  EXTRACT(DAYOFWEEK FROM date) as day_of_week_num,
  FORMAT_DATE('%A', date) as day_of_week_name,
  
  -- 从 fct_energy_balance 直接复制（已聚合）
  total_generation_mwh,
  total_grid_load_mwh,
  avg_residual_load_mwh,
  balance_gap_mwh,
  supply_ratio,
  is_surplus,
  avg_price_eur_mwh,
  min_price_eur_mwh,
  max_price_eur_mwh,
  negative_price_blocks,
  
  -- 增强维度
  CASE 
    WHEN supply_ratio > 1.2 THEN '充盈'
    WHEN supply_ratio > 1.0 THEN '盈余'
    WHEN supply_ratio > 0.95 THEN '平衡'
    ELSE '缺口'
  END as supply_status,
  
  CASE 
    WHEN avg_residual_load_mwh < 0 THEN '风光充分'
    WHEN avg_residual_load_mwh < 5000 THEN '风光充足'
    WHEN avg_residual_load_mwh < 10000 THEN '风光有利'
    ELSE '需补充'
  END as renewable_status,
  
  CASE 
    WHEN avg_price_eur_mwh < 0 THEN '负价格'
    WHEN avg_price_eur_mwh < 50 THEN '低价'
    WHEN avg_price_eur_mwh < 100 THEN '中价'
    WHEN avg_price_eur_mwh < 150 THEN '高价'
    ELSE '极高价'
  END as price_tier,
  
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM {{ ref('fct_energy_balance') }}

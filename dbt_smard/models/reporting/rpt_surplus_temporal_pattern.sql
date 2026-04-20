{{ config(
  materialized='table'
) }}

-- 粒度：1行 = 1个（月份 × 小时）组合
-- 用途：Tableau 过剩时刻的时间模式分析（按月份和小时分布）
-- 更新频率：每天凌晨 dbt run
-- 预期行数：~288 行（12月 × 24小时）

WITH surplus_moments AS (
  SELECT
    DATE(date) as date,
    EXTRACT(YEAR FROM date) as year,
    EXTRACT(MONTH FROM date) as month_num,
    FORMAT_DATE('%B', date) as month_name,
    hour_berlin,
    FORMAT_DATE('%A', date) as day_of_week_name,
    is_surplus,
    avg_residual_load_mwh,
    supply_ratio,
    avg_price_eur_mwh,
    total_generation_mwh,
    total_grid_load_mwh
  FROM {{ ref('fct_energy_balance') }}
),

month_hour_distribution AS (
  SELECT
    month_num,
    month_name,
    hour_berlin,
    
    -- 所有时刻统计
    COUNT(*) as total_15min_intervals,
    
    -- 过剩时刻统计
    COUNTIF(is_surplus = 1) as surplus_15min_intervals,
    ROUND(100.0 * COUNTIF(is_surplus = 1) / COUNT(*), 2) as surplus_rate_pct,
    
    -- 绿电指标（供应比例）
    AVG(CASE WHEN is_surplus = 1 THEN supply_ratio END) as avg_supply_ratio_surplus,
    AVG(CASE WHEN is_surplus = 0 THEN supply_ratio END) as avg_supply_ratio_deficit,
    
    -- 电价指标
    AVG(CASE WHEN is_surplus = 1 THEN avg_price_eur_mwh END) as avg_price_surplus,
    AVG(CASE WHEN is_surplus = 0 THEN avg_price_eur_mwh END) as avg_price_deficit,
    
    -- 负电价在过剩时刻的比例
    COUNTIF(is_surplus = 1 AND avg_price_eur_mwh < 0) as negative_price_in_surplus,
    ROUND(
      100.0 * COUNTIF(is_surplus = 1 AND avg_price_eur_mwh < 0) / 
      NULLIF(COUNTIF(is_surplus = 1), 0),
      2
    ) as negative_price_rate_in_surplus_pct,
    
    -- 残差负荷指标（绿电充分程度）
    AVG(CASE WHEN is_surplus = 1 THEN avg_residual_load_mwh END) as avg_residual_load_surplus,
    MIN(CASE WHEN is_surplus = 1 THEN avg_residual_load_mwh END) as min_residual_load_surplus
  FROM surplus_moments
  GROUP BY month_num, month_name, hour_berlin
)

SELECT
  month_num,
  month_name,
  hour_berlin,
  CASE 
    WHEN hour_berlin < 6 THEN 'Night (00-06)'
    WHEN hour_berlin < 12 THEN 'Morning (06-12)'
    WHEN hour_berlin < 18 THEN 'Afternoon (12-18)'
    ELSE 'Evening (18-24)'
  END as time_period,
  
  total_15min_intervals,
  surplus_15min_intervals,
  surplus_rate_pct,
  
  avg_supply_ratio_surplus,
  avg_supply_ratio_deficit,
  
  avg_price_surplus,
  avg_price_deficit,
  ROUND(
    COALESCE((avg_price_surplus - avg_price_deficit) / NULLIF(ABS(avg_price_deficit), 0) * 100, 0),
    2
  ) as price_diff_pct,
  
  negative_price_in_surplus,
  negative_price_rate_in_surplus_pct,
  
  avg_residual_load_surplus,
  min_residual_load_surplus,
  
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM month_hour_distribution

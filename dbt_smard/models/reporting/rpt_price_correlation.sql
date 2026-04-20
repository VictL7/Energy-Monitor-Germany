{{ config(
  materialized='table'
) }}

-- 粒度：1行 = 1天
-- 用途：Tableau 价格与绿电相关性分析
-- 更新频率：每天凌晨 dbt run
-- 预期行数：~2,700 行（2019-2026年4月）

SELECT
  DATE(date) as date,
  EXTRACT(YEAR FROM date) as year,
  EXTRACT(MONTH FROM date) as month,
  EXTRACT(QUARTER FROM date) as quarter,
  EXTRACT(WEEK FROM date) as week,
  FORMAT_DATE('%A', date) as day_of_week_name,
  
  -- 绿电指标（基于残差负荷）
  AVG(CASE WHEN avg_residual_load_mwh < 0 THEN 1 ELSE 0 END) as renewable_share_above_demand,
  STDDEV(avg_residual_load_mwh) as stddev_residual_load,
  
  -- 电价指标
  AVG(avg_price_eur_mwh) as avg_price_eur_mwh,
  MIN(avg_price_eur_mwh) as min_price_eur_mwh,
  MAX(avg_price_eur_mwh) as max_price_eur_mwh,
  STDDEV(avg_price_eur_mwh) as stddev_price_eur_mwh,
  
  -- 供应比例
  AVG(supply_ratio) as avg_supply_ratio,
  
  -- 过剩时段统计
  COUNTIF(is_surplus = 1) as surplus_hours_count,
  COUNTIF(is_surplus = 0) as deficit_hours_count,
  
  -- 按是否过剩的价格分布
  AVG(CASE WHEN is_surplus = 1 THEN avg_price_eur_mwh END) as avg_price_surplus_hours,
  AVG(CASE WHEN is_surplus = 0 THEN avg_price_eur_mwh END) as avg_price_deficit_hours,
  ROUND(
    (AVG(CASE WHEN is_surplus = 1 THEN avg_price_eur_mwh END) - 
     AVG(CASE WHEN is_surplus = 0 THEN avg_price_eur_mwh END)) / 
    NULLIF(AVG(CASE WHEN is_surplus = 0 THEN avg_price_eur_mwh END), 0) * 100,
    2
  ) as price_diff_pct_surplus_vs_deficit,
  
  -- 负电价指标
  COUNTIF(avg_price_eur_mwh < 0) as negative_price_hours,
  ROUND(100.0 * COUNTIF(avg_price_eur_mwh < 0) / 24, 2) as negative_price_pct,
  
  -- 极端电价事件
  COUNTIF(avg_price_eur_mwh < -100) as extreme_negative_price_hours,
  COUNTIF(avg_price_eur_mwh > 300) as extreme_high_price_hours,
  
  -- 绿电充分性指标
  COUNTIF(avg_residual_load_mwh < 0) as renewable_sufficient_hours,
  ROUND(100.0 * COUNTIF(avg_residual_load_mwh < 0) / 24, 2) as renewable_sufficient_pct,
  
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM {{ ref('fct_energy_balance') }}
GROUP BY date, year, month, quarter, week, day_of_week_name

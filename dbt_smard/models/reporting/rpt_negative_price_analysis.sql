{{ config(
  materialized='table'
) }}

-- 粒度：1行 = 1天
-- 用途：Tableau 负电价事件分析与趋势
-- 更新频率：每天凌晨 dbt run
-- 预期行数：~2,700 行（2019-2026年4月）

SELECT
  DATE(date) as date,
  EXTRACT(YEAR FROM date) as year,
  EXTRACT(MONTH FROM date) as month,
  EXTRACT(QUARTER FROM date) as quarter,
  EXTRACT(WEEK FROM date) as week,
  FORMAT_DATE('%A', date) as day_of_week_name,
  
  -- 负电价时刻计数
  COUNTIF(avg_price_eur_mwh < 0) as negative_price_hours,
  ROUND(100.0 * COUNTIF(avg_price_eur_mwh < 0) / 24, 2) as negative_price_pct,
  
  -- 极端负电价事件（< -100 EUR/MWh）
  COUNTIF(avg_price_eur_mwh < -100) as extreme_negative_price_hours,
  ROUND(100.0 * COUNTIF(avg_price_eur_mwh < -100) / 24, 2) as extreme_negative_price_pct,
  
  -- 负电价统计
  MIN(CASE WHEN avg_price_eur_mwh < 0 THEN avg_price_eur_mwh END) as min_negative_price,
  AVG(CASE WHEN avg_price_eur_mwh < 0 THEN avg_price_eur_mwh END) as avg_negative_price,
  MAX(CASE WHEN avg_price_eur_mwh < 0 THEN avg_price_eur_mwh END) as max_negative_price,
  
  -- 负电价与过剩的关系
  AVG(CASE WHEN avg_price_eur_mwh < 0 THEN supply_ratio END) as avg_supply_ratio_negative_price,
  COUNTIF(avg_price_eur_mwh < 0 AND is_surplus = 1) as negative_price_in_surplus_hours,
  ROUND(
    100.0 * COUNTIF(avg_price_eur_mwh < 0 AND is_surplus = 1) / 
    NULLIF(COUNTIF(avg_price_eur_mwh < 0), 0),
    2
  ) as negative_price_in_surplus_pct,
  
  -- 绿电过剩时的电价分布（包括负价）
  COUNTIF(is_surplus = 1 AND avg_price_eur_mwh >= -50) as surplus_high_price_hours,
  COUNTIF(is_surplus = 1 AND avg_price_eur_mwh < -50 AND avg_price_eur_mwh >= -150) as surplus_low_price_hours,
  COUNTIF(is_surplus = 1 AND avg_price_eur_mwh < -150) as surplus_extreme_price_hours,
  
  -- 分时段负电价发生率
  COUNTIF(avg_price_eur_mwh < 0 AND hour_berlin < 12) as negative_price_morning_hours,
  COUNTIF(avg_price_eur_mwh < 0 AND hour_berlin >= 12) as negative_price_evening_hours,
  
  -- 周期性指标
  AVG(avg_price_eur_mwh) as avg_daily_price,
  STDDEV(avg_price_eur_mwh) as stddev_daily_price,
  
  -- 残差负荷与负电价的关系
  AVG(CASE WHEN avg_price_eur_mwh < 0 THEN avg_residual_load_mwh END) as avg_residual_load_negative_price,
  MIN(CASE WHEN avg_price_eur_mwh < 0 THEN avg_residual_load_mwh END) as min_residual_load_negative_price,
  
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM {{ ref('fct_energy_balance') }}
GROUP BY date, year, month, quarter, week, day_of_week_name

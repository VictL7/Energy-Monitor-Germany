{{ config(
  materialized='table'
) }}

-- 粒度：小时级预计算价格指标
-- 用途：Tableau 价格时序、分布、热力图分析
-- 更新频率：每天凌晨 dbt run
-- 预期行数：8,800 行（小时粒度）

SELECT
  date,
  hour_berlin,
  EXTRACT(YEAR FROM date) as year,
  EXTRACT(MONTH FROM date) as month,
  EXTRACT(QUARTER FROM date) as quarter,
  EXTRACT(WEEK FROM date) as week,
  EXTRACT(DAYOFWEEK FROM date) as day_of_week_num,
  FORMAT_DATE('%A', date) as day_of_week_name,
  
  avg_price_eur_mwh,
  min_price_eur_mwh,
  max_price_eur_mwh,
  
  -- 基于日内排名
  ROW_NUMBER() OVER (
    PARTITION BY DATE(date) 
    ORDER BY avg_price_eur_mwh DESC
  ) as daily_price_rank_high,
  
  ROW_NUMBER() OVER (
    PARTITION BY DATE(date) 
    ORDER BY avg_price_eur_mwh ASC
  ) as daily_price_rank_low,
  
  -- 月度平均对比
  AVG(avg_price_eur_mwh) OVER (
    PARTITION BY DATE_TRUNC(date, MONTH)
  ) as monthly_avg_price,
  
  avg_price_eur_mwh - (
    AVG(avg_price_eur_mwh) OVER (PARTITION BY DATE_TRUNC(date, MONTH))
  ) as price_vs_monthly_avg,
  
  -- 价格等级
  CASE 
    WHEN avg_price_eur_mwh < 0 THEN '负价格'
    WHEN avg_price_eur_mwh < 30 THEN '极低价'
    WHEN avg_price_eur_mwh < 50 THEN '低价'
    WHEN avg_price_eur_mwh < 80 THEN '中价'
    WHEN avg_price_eur_mwh < 120 THEN '高价'
    ELSE '极高价'
  END as price_tier,
  
  negative_price_blocks,
  
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM {{ ref('fct_energy_balance') }}

{{ config(
  materialized='table'
) }}

-- 粒度：按时间周期聚合的可再生能源趋势指标
-- 用途：Tableau 绿能占比趋势、目标对标
-- 更新频率：每天凌晨 dbt run
-- 预期行数：2,400 行（按周期聚合）

WITH renewable_daily AS (
  SELECT
    berlin_date as date,
    EXTRACT(YEAR FROM berlin_date) as year,
    EXTRACT(MONTH FROM berlin_date) as month,
    EXTRACT(QUARTER FROM berlin_date) as quarter,
    EXTRACT(WEEK FROM berlin_date) as week,
    FORMAT_DATE('%A', berlin_date) as day_of_week_name,
    
    SUM(CASE WHEN category = 'renewable' THEN generation_mwh ELSE 0 END) as renewable_gen_mwh,
    SUM(generation_mwh) as total_gen_mwh,
    SUM(CASE WHEN category = 'renewable' THEN generation_mwh ELSE 0 END) / 
      NULLIF(SUM(generation_mwh), 0) as renewable_share_pct
  FROM {{ ref('mart_energy_mix') }}
  GROUP BY date, year, month, quarter, week, day_of_week_name
)

SELECT
  date,
  year,
  month,
  quarter,
  week,
  day_of_week_name,
  renewable_gen_mwh,
  total_gen_mwh,
  ROUND(renewable_share_pct * 100, 2) as renewable_share_pct_display,
  
  -- 滑动平均线
  ROUND(AVG(renewable_share_pct) OVER (
    ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) * 100, 2) as renewable_share_7day_avg_pct,
  
  ROUND(AVG(renewable_share_pct) OVER (
    ORDER BY date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
  ) * 100, 2) as renewable_share_30day_avg_pct,
  
  -- 月度对标
  ROUND(AVG(renewable_share_pct) OVER (
    PARTITION BY year, month
  ) * 100, 2) as monthly_renewable_avg_pct,
  
  -- 年度对标
  ROUND(AVG(renewable_share_pct) OVER (
    PARTITION BY year
  ) * 100, 2) as yearly_renewable_avg_pct,
  
  -- 环比增长
  ROUND((renewable_share_pct - LAG(renewable_share_pct) OVER (ORDER BY date)) * 100, 2) as daily_change_pct,
  
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM renewable_daily

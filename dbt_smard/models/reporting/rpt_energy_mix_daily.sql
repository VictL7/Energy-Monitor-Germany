{{ config(
  materialized='table'
) }}

-- 粒度：1行 = 1天 × 1种能源类型
-- 用途：Tableau 能源结构对比、堆积图
-- 更新频率：每天凌晨 dbt run
-- 预期行数：32,400 行（2.7K天 × 12种能源）

WITH daily_gen AS (
  SELECT
    berlin_date as date,
    EXTRACT(YEAR FROM berlin_date) as year,
    EXTRACT(MONTH FROM berlin_date) as month,
    EXTRACT(QUARTER FROM berlin_date) as quarter,
    EXTRACT(WEEK FROM berlin_date) as week,
    FORMAT_DATE('%A', berlin_date) as day_of_week_name,
    energy_type,
    category,
    SUM(generation_mwh) as total_generation_mwh,
    AVG(generation_mwh) as avg_hourly_generation_mwh,
    MAX(generation_mwh) as max_hourly_generation_mwh,
    COUNT(DISTINCT hour_berlin) as data_points,
    SUM(generation_revenue_eur) as total_revenue_eur,
    AVG(generation_share_pct) as avg_share_pct
  FROM {{ ref('mart_energy_mix') }}
  GROUP BY date, year, month, quarter, week, day_of_week_name, energy_type, category
)

SELECT
  *,
  ROUND(avg_share_pct * 100, 2) as share_pct_display,
  CASE 
    WHEN category = 'renewable' THEN 1
    WHEN category = 'nuclear' THEN 2
    WHEN category = 'fossil' THEN 3
    ELSE 4
  END as energy_category_priority,
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM daily_gen

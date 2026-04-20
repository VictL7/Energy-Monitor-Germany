{{ config(
  materialized='table',
  description='Monthly Surplus Distribution - Count of surplus vs non-surplus intervals by month'
) }}

-- 目的：按月份统计过剩和非过剩的时段数，看哪个月最容易过剩
-- 粒度：每月1行
-- 指标：total_intervals, surplus_intervals, surplus_pct, avg_price (surplus vs non-surplus)

WITH monthly_aggregates AS (
  SELECT
    EXTRACT(YEAR FROM fct.date) as year,
    EXTRACT(MONTH FROM fct.date) as month,
    COUNT(*) as total_intervals,
    COUNTIF(fct.is_surplus = 1) as surplus_intervals,
    COUNT(*) - COUNTIF(fct.is_surplus = 1) as non_surplus_intervals,
    ROUND(100.0 * COUNTIF(fct.is_surplus = 1) / COUNT(*), 2) as surplus_pct,
    ROUND(AVG(CASE WHEN fct.is_surplus = 1 THEN fct.avg_price_eur_mwh END), 2) as avg_price_surplus,
    ROUND(AVG(CASE WHEN fct.is_surplus = 0 THEN fct.avg_price_eur_mwh END), 2) as avg_price_non_surplus,
    COUNT(DISTINCT CASE WHEN fct.is_surplus = 1 THEN fct.date END) as surplus_days,
    COUNT(DISTINCT fct.date) as total_days
  FROM {{ ref('fct_energy_balance') }} fct
  WHERE fct.date BETWEEN '2019-01-01' AND '2025-12-31'
  GROUP BY EXTRACT(YEAR FROM fct.date), EXTRACT(MONTH FROM fct.date)
)

SELECT
  year,
  month,
  FORMAT_DATE('%B', DATE(CONCAT(CAST(year as STRING), '-', LPAD(CAST(month as STRING), 2, '0'), '-01'))) as month_name,
  CONCAT(CAST(year as STRING), '-', LPAD(CAST(month as STRING), 2, '0')) as year_month,
  total_intervals,
  surplus_intervals,
  non_surplus_intervals,
  surplus_pct,
  avg_price_surplus,
  avg_price_non_surplus,
  ROUND(avg_price_surplus - avg_price_non_surplus, 2) as price_diff_surplus_vs_non,
  surplus_days,
  total_days,
  ROUND(100.0 * surplus_days / total_days, 2) as surplus_days_pct,
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM monthly_aggregates
ORDER BY year, month

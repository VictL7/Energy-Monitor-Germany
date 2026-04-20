{{ config(
  materialized='table',
  description='Top 10 Greenest Days - Most hours with renewable energy sufficiency'
) }}

-- Purpose: Identify top 10 days with most hours of renewable energy sufficiency with key metrics
-- Granularity: one row per day
-- Metrics: green_sufficient_hours, green_sufficient_pct, avg_renewable_share, avg_grid_load

WITH daily_green_stats AS (
  SELECT
    fct.date,
    EXTRACT(YEAR FROM fct.date) as year,
    EXTRACT(MONTH FROM fct.date) as month,
    FORMAT_DATE('%Y-%m-%d', fct.date) as date_str,
    FORMAT_DATE('%A', fct.date) as day_name,
    -- Count of intervals with green energy sufficiency (15-minute units)
    COUNTIF(fct.avg_residual_load_mwh < 0) as green_sufficient_intervals,
    -- Convert to hours (4 x 15-minute intervals per hour)
    COUNTIF(fct.avg_residual_load_mwh < 0) / 4 as green_sufficient_hours,
    ROUND(100.0 * COUNTIF(fct.avg_residual_load_mwh < 0) / COUNT(*), 2) as green_sufficient_pct,
    -- Average renewable energy share
    ROUND(AVG(SAFE_DIVIDE(fct.total_generation_mwh - fct.total_grid_load_mwh, fct.total_grid_load_mwh)) * 100, 2) as avg_renewable_share_pct,
    -- Grid Load metrics
    ROUND(AVG(fct.total_grid_load_mwh), 2) as avg_grid_load_mwh,
    ROUND(SUM(fct.total_generation_mwh), 2) as total_generation_mwh,
    ROUND(SUM(fct.balance_gap_mwh), 2) as total_surplus_mwh,
    ROUND(AVG(fct.avg_price_eur_mwh), 2) as avg_price_eur_mwh
  FROM {{ ref('fct_energy_balance') }} fct
  WHERE fct.date BETWEEN '2019-01-01' AND '2025-12-31'
  GROUP BY fct.date, year, month
),

ranked_days AS (
  SELECT
    *,
    ROW_NUMBER() OVER (ORDER BY green_sufficient_hours DESC) as green_rank
  FROM daily_green_stats
)

SELECT
  green_rank,
  date,
  year,
  month,
  date_str,
  day_name,
  green_sufficient_hours,
  green_sufficient_pct,
  avg_renewable_share_pct,
  avg_grid_load_mwh,
  total_generation_mwh,
  total_surplus_mwh,
  avg_price_eur_mwh,
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM ranked_days
WHERE green_rank <= 10
ORDER BY green_rank

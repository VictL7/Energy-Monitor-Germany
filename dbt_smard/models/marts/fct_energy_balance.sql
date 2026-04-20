{{ config(
  materialized='table',
  partition_by={
    "field": "date",
    "data_type": "date"
  },
) }}

-- Daily aggregation: Energy balance fact table
-- Granularity: Aggregated by date and hour (across all energy categories)
-- Purpose: Overall energy balance analysis
WITH gen_total AS (
  SELECT
    stg_gen.berlin_date as date,
    stg_gen.hour_berlin,
    SUM(stg_gen.generation_mwh) as total_generation_mwh,
    COUNT(DISTINCT stg_gen.energy_type) as energy_types_count,
    COUNT(DISTINCT stg_gen.category) as energy_categories_count
  FROM {{ ref('stg_generation') }} stg_gen
  GROUP BY 1, 2
),

cons_agg AS (
  SELECT
    stg_cons.berlin_date as date,
    stg_cons.hour_berlin,
    AVG(stg_cons.grid_load) as total_grid_load_mwh,  -- Average 15-minute data to hourly
    AVG(stg_cons.residual_load) as avg_residual_load_mwh
  FROM {{ ref('stg_consumption') }} stg_cons
  GROUP BY 1, 2
),

price_agg AS (
  SELECT
    stg_price.berlin_date as date,
    stg_price.hour_berlin,
    AVG(stg_price.price_eur_mwh) as avg_price_eur_mwh,
    MIN(stg_price.price_eur_mwh) as min_price_eur_mwh,
    MAX(stg_price.price_eur_mwh) as max_price_eur_mwh,
    COUNTIF(stg_price.price_category = 'negative') as negative_price_blocks
  FROM {{ ref('stg_prices') }} stg_price
  GROUP BY 1, 2
)

SELECT
  gen_total.date,
  gen_total.hour_berlin,
  gen_total.total_generation_mwh,
  gen_total.energy_types_count,
  gen_total.energy_categories_count,
  cons_agg.total_grid_load_mwh,
  cons_agg.avg_residual_load_mwh,
  price_agg.avg_price_eur_mwh,
  price_agg.min_price_eur_mwh,
  price_agg.max_price_eur_mwh,
  price_agg.negative_price_blocks,
  -- 计算指标（基于整体能源平衡）
  SAFE_DIVIDE(gen_total.total_generation_mwh, cons_agg.total_grid_load_mwh) as supply_ratio,
  gen_total.total_generation_mwh - cons_agg.total_grid_load_mwh as balance_gap_mwh,
  CASE WHEN gen_total.total_generation_mwh > cons_agg.total_grid_load_mwh THEN 1 ELSE 0 END as is_surplus,
  EXTRACT(YEAR FROM gen_total.date) as year,
  EXTRACT(MONTH FROM gen_total.date) as month,
  EXTRACT(QUARTER FROM gen_total.date) as quarter
FROM gen_total
LEFT JOIN cons_agg USING (date, hour_berlin)
LEFT JOIN price_agg USING (date, hour_berlin)
WHERE 1=1

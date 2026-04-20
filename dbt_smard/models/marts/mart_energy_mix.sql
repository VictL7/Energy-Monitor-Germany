{{ config(
  materialized='incremental',
  unique_key=['timestamp_utc', 'energy_type'],
  on_schema_change='fail',
  partition_by={
    "field": "timestamp_utc",
    "data_type": "timestamp",
    "granularity": "day"
  },
) }}

-- 能源混合表：JOIN 发电 + 消耗 + 电价
-- 粒度：15分钟
-- Incremental: 仅插入/更新新数据

WITH gen AS (
  SELECT
    timestamp_utc,
    berlin_date,
    berlin_time,
    hour_berlin,
    energy_type,
    category,
    generation_mwh as value_mwh,
    year,
    month,
    quarter,
    ROW_NUMBER() OVER (PARTITION BY timestamp_utc, energy_type ORDER BY energy_type) as rn
  FROM {{ ref('stg_generation') }}
  {% if execute and flags.FULL_REFRESH == False %}
    WHERE timestamp_utc >= (SELECT COALESCE(MAX(timestamp_utc), TIMESTAMP('1970-01-01')) FROM {{ this }})
  {% endif %}
),

cons AS (
  SELECT
    timestamp_utc,
    grid_load,
    residual_load,
    pumped_storage_consumption
  FROM {{ ref('stg_consumption') }}
  {% if execute and flags.FULL_REFRESH == False %}
    WHERE timestamp_utc >= (SELECT COALESCE(MAX(timestamp_utc), TIMESTAMP('1970-01-01')) FROM {{ ref('stg_consumption') }})
  {% endif %}
),

prices AS (
  SELECT
    timestamp_utc,
    price_eur_mwh,
    price_type,
    price_category
  FROM {{ ref('stg_prices') }}
  {% if execute and flags.FULL_REFRESH == False %}
    WHERE timestamp_utc >= (SELECT COALESCE(MAX(timestamp_utc), TIMESTAMP('1970-01-01')) FROM {{ ref('stg_prices') }})
  {% endif %}
)

SELECT
  gen.timestamp_utc,
  gen.berlin_date,
  gen.berlin_time,
  gen.hour_berlin,
  gen.energy_type,
  gen.category,
  gen.value_mwh as generation_mwh,
  cons.grid_load,
  cons.residual_load,
  cons.pumped_storage_consumption,
  prices.price_eur_mwh,
  prices.price_type,
  prices.price_category,
  -- 计算指标（行级别）
  -- 注意：surplus_deficit 应在聚合层计算（见 fct_energy_balance），不在行级别
  SAFE_DIVIDE(gen.value_mwh, cons.grid_load) as generation_share_pct,
  prices.price_eur_mwh * gen.value_mwh as generation_revenue_eur,
  gen.year,
  gen.month,
  gen.quarter,
  CURRENT_TIMESTAMP() as dbt_updated_at
FROM gen
LEFT JOIN cons USING (timestamp_utc)
LEFT JOIN prices USING (timestamp_utc)
WHERE gen.rn = 1

{{ config(
  materialized='table',
  partition_by=none
) }}

-- 维度表：能源类型
-- 不分区：维度表
SELECT DISTINCT
  energy_type,
  category,
  CASE 
    WHEN category = 'renewable' THEN 1
    ELSE 0
  END as is_renewable,
  ROW_NUMBER() OVER (ORDER BY category, energy_type) as energy_type_key
FROM `zeta-medley-473321-r6.smard_dbt.stg_generation`
ORDER BY category, energy_type

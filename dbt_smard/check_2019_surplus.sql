-- 2019 年数据对比查询
WITH gen_2019 AS (
  SELECT 
    timestamp_utc,
    SUM(generation_mwh) as total_generation_mwh
  FROM `zeta-medley-473321.smard_dbt.stg_generation`
  WHERE EXTRACT(YEAR FROM timestamp_utc) = 2019
  GROUP BY 1
),
cons_2019 AS (
  SELECT 
    timestamp_utc,
    grid_load
  FROM `zeta-medley-473321.smard_dbt.stg_consumption`
  WHERE EXTRACT(YEAR FROM timestamp_utc) = 2019
),
merged AS (
  SELECT 
    CASE WHEN g.total_generation_mwh > c.grid_load THEN 1 ELSE 0 END as is_surplus
  FROM gen_2019 g
  LEFT JOIN cons_2019 c USING (timestamp_utc)
)
SELECT 
  COUNT(*) as total_records,
  SUM(is_surplus) as surplus_count,
  ROUND(100.0 * SUM(is_surplus) / COUNT(*), 2) as surplus_pct
FROM merged;

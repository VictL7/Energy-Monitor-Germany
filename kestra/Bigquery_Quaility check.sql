-- ✓ 验证数据量
SELECT 
  'electricity_generation' as table_name,
  COUNT(*) as row_count,
  COUNT(DISTINCT energy_type) as energy_types,
  MIN(timestamp_utc) as min_ts,
  MAX(timestamp_utc) as max_ts
FROM `zeta-medley-473321-r6.smard_raw.electricity_generation`
WHERE EXTRACT(YEAR FROM timestamp_utc) = 2019
UNION ALL
SELECT 
  'grid_consumption',
  COUNT(*),
  0,
  MIN(timestamp_utc),
  MAX(timestamp_utc)
FROM `zeta-medley-473321-r6.smard_raw.grid_consumption`
WHERE EXTRACT(YEAR FROM timestamp_utc) = 2019
UNION ALL
SELECT 
  'electricity_prices',
  COUNT(*),
  0,
  MIN(timestamp_utc),
  MAX(timestamp_utc)
FROM `zeta-medley-473321-r6.smard_raw.electricity_prices`
WHERE EXTRACT(YEAR FROM timestamp_utc) = 2019;

-- ✓ 检查NULL值
SELECT 
  'generation' as table_name,
  COUNTIF(timestamp_utc IS NULL) as null_timestamp,
  COUNTIF(value_mwh IS NULL) as null_value,
  COUNTIF(energy_type IS NULL) as null_energy_type
FROM `zeta-medley-473321-r6.smard_raw.electricity_generation`
WHERE EXTRACT(YEAR FROM timestamp_utc) = 2019
UNION ALL
SELECT 
  'consumption',
  COUNTIF(timestamp_utc IS NULL),
  COUNTIF(grid_load IS NULL),
  0
FROM `zeta-medley-473321-r6.smard_raw.grid_consumption`
WHERE EXTRACT(YEAR FROM timestamp_utc) = 2019
UNION ALL
SELECT 
  'prices',
  COUNTIF(timestamp_utc IS NULL),
  COUNTIF(price_eur_mwh IS NULL),
  0
FROM `zeta-medley-473321-r6.smard_raw.electricity_prices`
WHERE EXTRACT(YEAR FROM timestamp_utc) = 2019;

-- ✓ 时间序列连续性（应该每15分钟一条）
SELECT 
  'generation - 15min intervals check' as check_name,
  COUNT(*) as total_records,
  COUNT(DISTINCT timestamp_utc) as unique_timestamps,
  COUNT(*) / COUNT(DISTINCT energy_type) as expected_per_type
FROM `zeta-medley-473321-r6.smard_raw.electricity_generation`
WHERE EXTRACT(YEAR FROM timestamp_utc) = 2019
  AND energy_type = 'biomass'
LIMIT 1;

-- ✓ 数值范围检查
SELECT 
  'generation values' as metric,
  MIN(value_mwh) as min_val,
  MAX(value_mwh) as max_val,
  AVG(value_mwh) as avg_val
FROM `zeta-medley-473321-r6.smard_raw.electricity_generation`
WHERE EXTRACT(YEAR FROM timestamp_utc) = 2019
UNION ALL
SELECT 
  'grid_load values',
  MIN(grid_load),
  MAX(grid_load),
  AVG(grid_load)
FROM `zeta-medley-473321-r6.smard_raw.grid_consumption`
WHERE EXTRACT(YEAR FROM timestamp_utc) = 2019
UNION ALL
SELECT 
  'prices EUR/MWh',
  MIN(price_eur_mwh),
  MAX(price_eur_mwh),
  AVG(price_eur_mwh)
FROM `zeta-medley-473321-r6.smard_raw.electricity_prices`
WHERE EXTRACT(YEAR FROM timestamp_utc) = 2019;

# Reporting Layer - Tableau 优化

这一层为 **Tableau** 专门设计。包含所有预计算、预聚合的表，保证 Tableau 仪表板秒级响应。

## 为什么需要 Reporting 层？

| 场景 | Looker | Tableau |
|------|--------|---------|
| 直接用 mart（420K行） | ✅ 秒级（BI-Engine缓存） | ❌ 15-30秒（现场聚合） |
| 用 reporting（2.7K行） | ✅ 毫秒（直接返回） | ✅✅ 毫秒（预聚合） |

## 表设计清单

### 1. **rpt_daily_summary**（日度汇总）

```sql
{{ config(
  materialized='table',
  partition_by={ "field": "date", "data_type": "date" },
  cluster_by=['energy_category']
) }}

-- 粒度：1行 = 1天
-- 用途：Tableau KPI 仪表板、趋势分析
-- 更新频率：每天凌晨 dbt run

SELECT
  date,
  EXTRACT(YEAR FROM date) as year,
  EXTRACT(MONTH FROM date) as month,
  EXTRACT(QUARTER FROM date) as quarter,
  EXTRACT(WEEK FROM date) as week,
  FORMAT_DATE('%A', date) as day_of_week,
  
  -- 发电指标（所有能源）
  SUM(total_generation_mwh) as total_generation_mwh,
  AVG(total_generation_mwh) as avg_hourly_generation_mwh,
  MAX(total_generation_mwh) as max_hourly_generation_mwh,
  MIN(total_generation_mwh) as min_hourly_generation_mwh,
  STDDEV(total_generation_mwh) as stddev_generation_mwh,
  
  -- 需求指标
  SUM(total_grid_load_mwh) as total_grid_load_mwh,
  AVG(total_grid_load_mwh) as avg_hourly_load_mwh,
  MAX(total_grid_load_mwh) as max_hourly_load_mwh,
  MIN(total_grid_load_mwh) as min_hourly_load_mwh,
  
  -- 盈余指标
  SUM(balance_gap_mwh) as total_balance_gap_mwh,
  COUNTIF(is_surplus = 1) as surplus_hours,
  24 - COUNTIF(is_surplus = 1) as deficit_hours,
  ROUND(100.0 * COUNTIF(is_surplus = 1) / 24, 2) as surplus_pct,
  AVG(supply_ratio) as avg_supply_ratio,
  
  -- 电价指标
  AVG(avg_price_eur_mwh) as avg_price_eur_mwh,
  MIN(avg_price_eur_mwh) as min_price_eur_mwh,
  MAX(avg_price_eur_mwh) as max_price_eur_mwh,
  SUM(CASE WHEN avg_price_eur_mwh < 0 THEN 1 ELSE 0 END) as negative_price_hours,
  
  -- 绿电指标
  COUNTIF(avg_residual_load_mwh < 0) as renewable_sufficient_hours,
  ROUND(100.0 * COUNTIF(avg_residual_load_mwh < 0) / 24, 2) as renewable_sufficient_pct,
  
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM {{ ref('fct_energy_balance') }}
GROUP BY date, year, month, quarter, week, day_of_week
```

**预期行数**：2,700 行（2019-2026年4月）  
**用途**：
- KPI卡片（总发电、总需求、盈余率）
- 日度趋势线图
- 月度对比柱图
- 季节性分析

---

### 2. **rpt_hourly_summary**（小时汇总）

```sql
-- 粒度：1行 = 1小时
-- 用途：Tableau 详细时间序列分析、小时热力图
-- 行数：26.5K（2019-2026年4月）

SELECT
  date,
  hour_berlin,
  EXTRACT(YEAR FROM date) as year,
  EXTRACT(MONTH FROM date) as month,
  EXTRACT(QUARTER FROM date) as quarter,
  FORMAT_DATE('%A', date) as day_of_week,
  
  -- 从 fct_energy_balance 直接复制（已聚合）
  total_generation_mwh,
  total_grid_load_mwh,
  avg_residual_load_mwh,
  balance_gap_mwh,
  supply_ratio,
  is_surplus,
  avg_price_eur_mwh,
  negative_price_blocks,
  
  -- 增强指标
  CASE 
    WHEN supply_ratio > 1.2 THEN '充盈'
    WHEN supply_ratio > 1.0 THEN '盈余'
    WHEN supply_ratio > 0.95 THEN '平衡'
    ELSE '缺口'
  END as supply_status,
  
  CASE 
    WHEN avg_residual_load_mwh < 0 THEN '风光充分'
    WHEN avg_residual_load_mwh < 5000 THEN '风光充足'
    WHEN avg_residual_load_mwh < 10000 THEN '风光有利'
    ELSE '需补充'
  END as renewable_status,
  
  CASE 
    WHEN avg_price_eur_mwh < 0 THEN '负价格'
    WHEN avg_price_eur_mwh < 50 THEN '低价'
    WHEN avg_price_eur_mwh < 100 THEN '中价'
    ELSE '高价'
  END as price_tier,
  
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM {{ ref('fct_energy_balance') }}
```

**用途**：
- 时间热力图（小时 vs 日期，色值为价格）
- 小时级细粒度分析
- 特定时段对比

---

### 3. **rpt_energy_mix_daily**（能源日度分解）

```sql
-- 粒度：1行 = 1天 × 1种能源
-- 用途：Tableau 能源结构对比、类型排序
-- 行数：32.4K（2.7K天 × 12种能源）

WITH daily_gen AS (
  SELECT
    berlin_date as date,
    EXTRACT(YEAR FROM berlin_date) as year,
    EXTRACT(MONTH FROM berlin_date) as month,
    EXTRACT(QUARTER FROM berlin_date) as quarter,
    FORMAT_DATE('%A', berlin_date) as day_of_week,
    energy_type,
    category,
    SUM(generation_mwh) as total_generation_mwh,
    AVG(generation_share_pct) as avg_share_pct,
    COUNT(DISTINCT hour_berlin) as data_points,
    SUM(generation_revenue_eur) as total_revenue_eur
  FROM {{ ref('mart_energy_mix') }}
  GROUP BY date, year, month, quarter, day_of_week, energy_type, category
)

SELECT
  *,
  ROUND(avg_share_pct * 100, 2) as share_pct_display,
  CASE 
    WHEN category = 'renewable' THEN 1
    WHEN category = 'nuclear' THEN 2
    ELSE 3
  END as energy_priority,
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM daily_gen
ORDER BY date DESC, energy_priority, total_generation_mwh DESC
```

**用途**：
- 堆积柱图（日期 vs 能源类型）
- 能源类型排序过滤
- 可再生 vs 化石对比

---

### 4. **rpt_price_analysis**（电价分析）

```sql
-- 粒度：预计算的电价指标
-- 用途：Tableau 价格趋势、分布分析
-- 行数：8.8K（小时粒度）

SELECT
  date,
  hour_berlin,
  EXTRACT(YEAR FROM date) as year,
  EXTRACT(MONTH FROM date) as month,
  FORMAT_DATE('%A', date) as day_of_week,
  
  avg_price_eur_mwh,
  min_price_eur_mwh,
  max_price_eur_mwh,
  
  -- 基于小时的价格排名
  ROW_NUMBER() OVER (
    PARTITION BY DATE(date) 
    ORDER BY avg_price_eur_mwh DESC
  ) as daily_price_rank_high,
  
  ROW_NUMBER() OVER (
    PARTITION BY DATE(date) 
    ORDER BY avg_price_eur_mwh ASC
  ) as daily_price_rank_low,
  
  -- 与平均值对比
  AVG(avg_price_eur_mwh) OVER (
    PARTITION BY DATE_TRUNC(date, MONTH)
  ) as monthly_avg_price,
  
  avg_price_eur_mwh - (
    AVG(avg_price_eur_mwh) OVER (PARTITION BY DATE_TRUNC(date, MONTH))
  ) as price_vs_monthly_avg,
  
  CASE 
    WHEN avg_price_eur_mwh < 0 THEN '负价格'
    WHEN avg_price_eur_mwh < 50 THEN '低价'
    WHEN avg_price_eur_mwh < 100 THEN '中价'
    ELSE '高价'
  END as price_category,
  
  negative_price_blocks,
  
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM {{ ref('fct_energy_balance') }}
```

**用途**：
- 价格时间序列
- 价格分布直方图
- 负价格事件标记

---

### 5. **rpt_renewable_trend**（绿能趋势）

```sql
-- 粒度：按时间周期聚合的绿能指标
-- 用途：Tableau 可再生占比趋势、关键指标
-- 行数：2.4K（按周期聚合）

WITH renewable_daily AS (
  SELECT
    berlin_date as date,
    EXTRACT(YEAR FROM berlin_date) as year,
    EXTRACT(MONTH FROM berlin_date) as month,
    EXTRACT(QUARTER FROM berlin_date) as quarter,
    EXTRACT(WEEK FROM berlin_date) as week,
    FORMAT_DATE('%A', berlin_date) as day_of_week,
    
    SUM(CASE WHEN category = 'renewable' THEN generation_mwh ELSE 0 END) as renewable_gen_mwh,
    SUM(generation_mwh) as total_gen_mwh,
    SUM(CASE WHEN category = 'renewable' THEN generation_mwh ELSE 0 END) / 
      NULLIF(SUM(generation_mwh), 0) as renewable_share_pct
  FROM {{ ref('mart_energy_mix') }}
  GROUP BY date, year, month, quarter, week, day_of_week
)

SELECT
  date,
  year,
  month,
  quarter,
  week,
  day_of_week,
  renewable_gen_mwh,
  total_gen_mwh,
  ROUND(renewable_share_pct * 100, 2) as renewable_share_pct_display,
  
  -- 滑动平均（7天/30天）
  AVG(renewable_share_pct) OVER (
    ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) as renewable_share_7day_avg,
  
  AVG(renewable_share_pct) OVER (
    ORDER BY date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
  ) as renewable_share_30day_avg,
  
  -- 月度对标
  AVG(renewable_share_pct) OVER (
    PARTITION BY year, month
  ) as monthly_renewable_avg,
  
  -- 年度对标
  AVG(renewable_share_pct) OVER (
    PARTITION BY year
  ) as yearly_renewable_avg,
  
  CURRENT_TIMESTAMP() as dbt_loaded_at
FROM renewable_daily
```

**用途**：
- 可再生占比趋势线（年度/月度对标）
- 增长率计算
- 目标进度跟踪

---

## 部署步骤

### Step 1: 创建 reporting 表定义文件

```bash
mkdir -p dbt_smard/models/reporting

# 创建 5 个表
cat > dbt_smard/models/reporting/rpt_daily_summary.sql << 'EOF'
{{ config(materialized='table', partition_by={"field": "date", "data_type": "date"}) }}
-- ... SQL 内容
EOF

# 重复创建其他 4 个表...
```

### Step 2: 更新 dbt_project.yml

```yaml
models:
  smard_dbt:
    reporting:
      materialized: table
      partition_by:
        field: date
        data_type: date
      tags: ["reporting", "tableau"]
```

### Step 3: 运行 dbt

```bash
dbt run -s reporting
# 或仅生成特定表
dbt run -s rpt_daily_summary
```

### Step 4: 在 Tableau 中连接

1. Data → New Data Source → BigQuery
2. 选择表：`rpt_daily_summary`, `rpt_energy_mix_daily` 等
3. 拖拽字段，秒速构建仪表板！

---

## 性能指标

| 表名 | 行数 | 大小 | 查询时间 | 更新频率 |
|------|------|------|---------|---------|
| `rpt_daily_summary` | 2.7K | 5 MB | <100ms | 每天 |
| `rpt_hourly_summary` | 26.5K | 50 MB | <500ms | 每天 |
| `rpt_energy_mix_daily` | 32.4K | 60 MB | <500ms | 每天 |
| `rpt_price_analysis` | 8.8K | 15 MB | <200ms | 每天 |
| `rpt_renewable_trend` | 2.4K | 4 MB | <100ms | 每天 |

**总大小**：~134 MB（可忽略不计）  
**总更新时间**：~5-10 分钟  
**Tableau 响应时间**：<1秒（所有查询）

---

## Tableau 使用示例

### 示例 1: KPI 仪表板

```
数据源：rpt_daily_summary
┌────────────────────────────────────┐
│ 过去 30 天平均                      │
├────────────────────────────────────┤
│ 📊 总发电：528,000 MWh             │
│ 📉 总需求：502,000 MWh             │
│ ✅ 盈余率：105.2%                   │
│ 🌱 绿能占比：42.3%                  │
│ 💰 平均电价：€65.42/MWh            │
└────────────────────────────────────┘

维度过滤：
- 按年/月/周过滤
- 按能源类别过滤
```

### 示例 2: 能源结构堆积图

```
数据源：rpt_energy_mix_daily
X 轴：date（按月分组）
Y 轴：total_generation_mwh
颜色：energy_type（12种颜色）

→ 显示过去 24 个月的能源结构演变
→ 可视化可再生占比增长
```

### 示例 3: 价格热力图

```
数据源：rpt_hourly_summary
行：date
列：hour_berlin (0-23)
色值：avg_price_eur_mwh

→ 发现峰值价格规律
→ 识别负价格时段
```

---

## 维护清单

- [ ] 每周检查表大小（不应超过 200 MB）
- [ ] 每月验证行数增长（应该线性增长，~30 行/天）
- [ ] 每季度审查 Tableau 查询性能（应该 <1 秒）
- [ ] 半年审查报表层是否需要新增维度

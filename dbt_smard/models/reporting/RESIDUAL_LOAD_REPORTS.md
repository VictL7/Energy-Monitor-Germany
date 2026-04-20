# Green Energy Sufficiency Analysis - dbt Reports

## 📊 Overview

这组dbt报告模型基于Python笔记本分析，将绿电充足率、可再生能源占比等关键指标数据化、可视化。

## 🎯 Three Report Models

### 1. **rpt_residual_load_analysis** (年/月汇总)
- **类型**: Table
- **粒度**: 按年份和月份聚合
- **主要指标**:
  - `green_sufficient_pct`: 绿电充足时段占比 (当renewable_sufficient_hours >= 12时)
  - `avg_renewable_share_pct`: 平均可再生能源占比
  - `avg_residual_ratio`: 平均剩余负荷比率（负数表示绿电过剩）
  - `avg_price_eur_mwh`: 日均电价
  
**SQL逻辑**:
- 从 `rpt_daily_summary` 读取每日数据
- 按年份/月份聚合计算统计指标
- 使用UNION ALL合并年度和月度统计结果

**用途**: 
- 年度绿电转型进度报告
- 月度季节性分析
- 电价与绿电充足率相关性分析

---

### 2. **rpt_daily_residual_load** (日度明细)
- **类型**: Partitioned Table (按date分区)
- **粒度**: 每天1行
- **主要指标**:
  - `renewable_sufficient_hours`: 当日residual_load < 0的小时数（0-24）
  - `renewable_sufficient_pct`: 百分比
  - `is_green_sufficient`: 布尔标志（>= 12小时标记为充足）
  - `renewable_share_pct`: 该天可再生能源占比
  - `surplus_hours`, `deficit_hours`: 生成量 vs 消费量对比

**SQL逻辑**:
- 从 `rpt_daily_summary` 直接投影日度数据
- 按date分区存储，支持高效查询

**用途**:
- Tableau/Looker日期范围过滤
- 查找最绿的日期
- 季节性分析drill-down

---

### 3. **rpt_green_energy_kpi** (KPI仪表板)
- **类型**: Table
- **粒度**: 两行（全期间 + 最近一年）
- **主要指标**:
  - `metric_type`: 'FULL_PERIOD' 或 'LATEST_YEAR'
  - `total_days` / `green_sufficient_days`: 天数统计
  - `green_sufficient_pct`: 关键KPI
  - `avg_renewable_share_pct`: 平均绿色能源占比

**SQL逻辑**:
- 计算整个数据期间的统计
- 单独计算最近一个完整年份的统计
- UNION两个结果供仪表板选择

**用途**:
- Tableau KPI卡片（大屏展示）
- 实时绿能转型进度指标
- 年度对比基准线

---

## 📈 Key Metrics Definitions

### Residual Load (剩余负荷)
```
Residual Load = Grid Load - (Wind + Solar)
```
- **< 0**: 可再生能源已完全满足需求（绿电充足）
- **> 0**: 需要化石燃料补充的部分

### Green Energy Sufficiency
```
绿电充足时段 = Residual Load < 0 的小时数
绿电充足率 = 绿电充足小时数 / 24小时 * 100%
```

### Renewable Share (可再生能源占比)
```
Renewable Share = (Total Generation - Grid Load) / Grid Load * 100%
```
- 当 > 0% 时表示发电过剩可向邻国出口

---

## 🔄 Update Frequency & Dependencies

| 报告 | 更新频率 | 依赖 | 行数 |
|------|---------|------|------|
| rpt_residual_load_analysis | 每天凌晨 | rpt_daily_summary | ~104行 (8年yearly + 96月份monthly) |
| rpt_daily_residual_load | 每天凌晨 | rpt_daily_summary | ~2,700行 |
| rpt_green_energy_kpi | 每天凌晨 | rpt_daily_summary | 2行 |

**Tableau 适配说明**:
- `rpt_residual_load_analysis` 中 YEARLY 行的 `month_name` 字段值为 `'Full Year'` (不是 NULL)
- 这样做是为了避免 Tableau 在用月份作为列名/维度时过滤掉年度汇总行
- 增加了 `month_num` 字段便于排序（NULL for YEARLY rows）

---

## 💡 Example Queries

### 查询最绿的月份
```sql
SELECT
  year,
  month,
  green_sufficient_pct,
  avg_renewable_share_pct
FROM `project.smard_dbt.rpt_residual_load_analysis`
WHERE report_type = 'MONTHLY'
ORDER BY green_sufficient_pct DESC
LIMIT 5
```

### 查询全年绿电充足率
```sql
SELECT
  year,
  green_sufficient_pct,
  avg_renewable_share_pct
FROM `project.smard_dbt.rpt_residual_load_analysis`
WHERE report_type = 'YEARLY'
ORDER BY year DESC
```

### 查询最近30天绿电统计
```sql
SELECT
  date,
  renewable_sufficient_hours,
  renewable_sufficient_pct,
  renewable_share_pct,
  avg_price_eur_mwh
FROM `project.smard_dbt.rpt_daily_residual_load`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
ORDER BY date DESC
```

### 获取KPI指标
```sql
SELECT *
FROM `project.smard_dbt.rpt_green_energy_kpi`
WHERE metric_type IN ('FULL_PERIOD', 'LATEST_YEAR')
```

---

## 🚀 How to Run

```bash
# 运行所有三个报告
dbt run --select rpt_residual_load_analysis rpt_daily_residual_load rpt_green_energy_kpi

# 或单独运行某个报告
dbt run --select rpt_residual_load_analysis
dbt run --select rpt_daily_residual_load
dbt run --select rpt_green_energy_kpi
```

---

## 📌 Notes

1. **数据源**: 所有报告基于 `fct_energy_balance` 表（通过 `rpt_daily_summary` 聚合）
2. **时间范围**: 2019-01-01 至当前日期
3. **时区**: 所有时间戳已转换到Europe/Berlin时区
4. **分区**: rpt_daily_residual_load 按date分区以优化查询性能
5. **更新延迟**: 前一天数据在凌晨更新完成

---

## 🆕 高级报告系统

在 `reporting_advanced/` 文件夹中有**7个增强报告模型**，提供更丰富的分析维度:

1. **rpt_energy_production_stacked** - 能源类型堆叠+drill-down (年/月/日)
2. **rpt_residual_load_summary** - 全期间KPI汇总表
3. **rpt_top_greenest_days** - Top 10最绿日期排行
4. **rpt_greenest_day_detail** - 最绿那天的24小时详细分解
5. **rpt_monthly_surplus_distribution** - 月份过剩热力图数据
6. **rpt_hourly_distribution** - 一天中各小时的绿电分布
7. **rpt_price_distribution** - 电价与绿电的散点分析

详见 `reporting_advanced/REPORTING_TABLEAU_GUIDE.md` 了解Tableau配置细节。


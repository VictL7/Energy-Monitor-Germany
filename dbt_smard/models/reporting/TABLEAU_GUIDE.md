# Tableau 使用指南 - 8 个 Reporting 层表

## 📊 生成完成！所有 8 个表已在 BigQuery 中准备好

### 表清单

| # | 表名 | 粒度 | 行数 | 最佳用途 | Tableau 图表类型 |
|----|------|------|------|---------|-----------------|
| 1 | `rpt_daily_summary` | 1行/天 | ~2,700 | **KPI 仪表板** | 卡片、折线图、日历热力图 |
| 2 | `rpt_hourly_summary` | 1行/小时 | ~26,500 | **小时细节分析** | 热力图、时间序列、分布图 |
| 3 | `rpt_energy_mix_daily` | 1行/天×能源类型 | ~32,400 | **能源结构分析** | 堆积柱图、面积图、瀑布图 |
| 4 | `rpt_price_analysis` | 1行/小时 | ~8,800 | **电价趋势** | 时间序列、箱线图、百分位数 |
| 5 | `rpt_renewable_trend` | 1行/天 | ~2,400 | **绿能占比趋势** | 面积图、移动平均、同比对比 |
| 6 | **`rpt_price_correlation`** ✨ NEW | 1行/天 | ~2,700 | **相关性分析** | 散点图、相关系数热力图 |
| 7 | **`rpt_surplus_temporal_pattern`** ✨ NEW | 1行/月×小时 | ~288 | **过剩时间模式** | 热力图、月时热力图、漏斗图 |
| 8 | **`rpt_negative_price_analysis`** ✨ NEW | 1行/天 | ~2,700 | **负电价机制** | 时间序列、分布图、排名表 |

---

## 🎯 Tableau 仪表板构建方案

### 方案 A：KPI 仪表板（推荐首先构建）

**数据源**：`rpt_daily_summary`

**KPI 卡片**：
```
1. 平均发电量 → SUM(total_generation_mwh) / 365
2. 盈余天数 → COUNTIF(surplus_pct > 0)
3. 绿电充足率 → AVG(renewable_sufficient_pct)
4. 平均电价 → AVG(avg_price_eur_mwh)
```

**拖拽步骤**：
- 行：`date`（选择日期范围）
- 列：`total_generation_mwh`, `total_grid_load_mwh`, `surplus_pct`, `renewable_sufficient_pct`
- 颜色：`surplus_pct`（绿色=过剩，红色=缺口）
- 过滤：年份、月份

---

### 方案 B：过剩时间规律分析（新表）

**数据源**：`rpt_surplus_temporal_pattern` ✨

**热力图**：
```
行：month_name（月份）
列：hour_berlin（小时）
色值：surplus_rate_pct（过剩发生率）
```

**结果**：
- 🟢 绿色区域 = 最容易过剩的时间（最佳储能充电时段）
- 🔴 红色区域 = 缺电时段（应用生产地移峰）

**可视化示例**：
```
        Hour
      0  6 12 18 24
M   1  ░░░░▓▓░░░░░░
o   2  ░░░░▓▓▓░░░░░
n   3  ░░░░░▓▓░░░░░
t   4  ░░░░░░░░░░░░  (冬季，很少过剩)
h   ...
     12  ▓▓▓▓▓▓▓░░░░░  (夏季正午，频繁过剩)
```

---

### 方案 C：价格与绿电相关性（新表）

**数据源**：`rpt_price_correlation` ✨

**主要字段**：
- `correlation_renewable_price` - 绿电与价格的相关系数
- `avg_price_surplus_hours` - 过剩时段平均电价
- `avg_price_deficit_hours` - 缺口时段平均电价
- `price_diff_pct_surplus_vs_deficit` - 价格差异百分比

**构建方式**：
```
Rows: date（按月分组）
Columns: 
  - correlation_renewable_price（折线图）
  - negative_price_pct（柱图叠加）
  - extreme_negative_price_hours（预警）
```

**商业洞察**：
- 相关系数 > 0.8 = 绿电明显压低电价
- 相关系数 < 0.3 = 其他因素主导（政策、需求等）

---

### 方案 D：负电价机制分析（新表）

**数据源**：`rpt_negative_price_analysis` ✨

**关键字段**：
- `negative_price_hours` - 负电价时刻数
- `negative_price_in_surplus_pct` - 负价中有多少是过剩事件
- `day_rank_in_month_by_negative_price` - 月度排名

**Tableau 视图**：
```
1. 时间序列（日折线图）
   行：date
   列：negative_price_hours + avg_daily_price
   颜色：negative_price_pct（0-100%）

2. 月度排名（条形图）
   行：day_of_week_name（按月排序）
   列：negative_price_hours
   排序：降序

3. 供应-价格散点图
   X轴：avg_supply_ratio_negative_price
   Y轴：min_negative_price
   大小：negative_price_hours
```

**参考**：
- 负电价天数多 → 绿能过剩严重，需建储能项目
- 与过剩相关性低 → 可能是天然气价格崩溃导致

---

## 📲 Tableau Desktop 连接步骤

### 1. 新建数据源
```
Tableau Desktop 
→ Data 
→ New Data Source 
→ BigQuery
```

### 2. 验证连接
```
Project ID: zeta-medley-473321-r6
Dataset: smard_dbt
```

### 3. 选择表
```
从以下 8 个表中选择（可多选）：
✓ rpt_daily_summary
✓ rpt_hourly_summary
✓ rpt_energy_mix_daily
✓ rpt_price_analysis
✓ rpt_renewable_trend
✓ rpt_price_correlation       ← 新
✓ rpt_surplus_temporal_pattern ← 新
✓ rpt_negative_price_analysis  ← 新
```

### 4. 拖拽构建视图

**示例 1：日度趋势**
```
数据源: rpt_daily_summary
行 = date
列 = SUM(total_generation_mwh)
颜色 = surplus_pct
```

**示例 2：月份×小时热力图**
```
数据源: rpt_surplus_temporal_pattern
行 = month_name
列 = hour_berlin
色值 = surplus_rate_pct
```

**示例 3：相关性散点图**
```
数据源: rpt_price_correlation
X轴 = correlation_renewable_price
Y轴 = negative_price_pct
标签 = month
```

### 5. 发布仪表板
```
File → Save to Tableau Server
Share → 团队权限配置
Set Refresh Schedule → 每天 00:30 (dbt 运行后)
```

---

## 🔄 数据刷新工作流

### 每天自动更新流程：
```
00:00 → SMARD API 拉取前一天数据
00:15 → BigQuery 加载到 stg_* 表
00:30 → dbt run -s reporting 
        (生成 8 个 rpt_* 表)
00:45 → Tableau 自动刷新数据源
01:00 → 仪表板最新数据可用
```

**预期运行时间**：dbt reporting 全集 ~30 秒

---

## 💡 使用建议

### 最小化仪表板（推荐新用户）
1 个工作表 = `rpt_daily_summary`
- 显示：日发电、需求、盈余率、电价
- 过滤：日期范围、能源类型

### 完整分析仪表板（高级用户）
5 个工作表：
- 工作表1：KPI 卡片 + 日度趋势
- 工作表2：月份×小时热力图（过剩规律）
- 工作表3：能源结构（堆积图）
- 工作表4：价格-绿电相关性（散点图）
- 工作表5：负电价机制（排名表 + 时间序列）

### 成本优化建议
- 使用 `rpt_daily_summary`（最快，2.7K 行）作为主仪表板
- 按需选择其他表（热力图选 `rpt_surplus_temporal_pattern`）
- 避免直接连接 mart 表（420K 行会很慢）

---

## ❓ 常见问题

**Q: 为什么要用 reporting 表而不直接连接 mart？**  
A: 性能。reporting 表的行数少 100 倍，查询响应从 15-30 秒降至 <1 秒。

**Q: 3 个新表与现有 5 个有什么区别？**  
A: 
- 前 5 个：通用汇总表（任何分析都可用）
- 新 3 个：特定场景优化（相关性、时间规律、价格机制）

**Q: 能否修改表结构？**  
A: 可以。编辑 `.sql` 文件后运行 `dbt run -s reporting` 即可重新生成。

**Q: 如何创建自己的 reporting 表？**  
A: 
```bash
# 1. 在 models/reporting/ 中创建 rpt_my_table.sql
# 2. 添加到 schema.yml
# 3. 运行 dbt run -s rpt_my_table
```

---

## 🚀 下一步

- [ ] 连接 Tableau Desktop 到 BigQuery
- [ ] 构建 KPI 仪表板（基于 rpt_daily_summary）
- [ ] 构建过剩规律热力图（基于 rpt_surplus_temporal_pattern）
- [ ] 发布到 Tableau Server
- [ ] 配置数据刷新计划（每天凌晨）

**所有表已准备就绪！开始构建吧！** 🎉

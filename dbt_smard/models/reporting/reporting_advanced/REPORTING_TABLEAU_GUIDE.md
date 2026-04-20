# Advanced Reporting Guide - Tableau配置手册

这份指南帮助你在Tableau中快速创建7个高效的可视化报告。所有数据源均已在BigQuery中准备好，可直接连接使用。

---

## 📊 7个报告概览

| # | 报告名称 | BigQuery表 | 图表类型 | 主要维度 | 主要指标 |
|---|---------|----------|---------|---------|---------|
| 1 | 能源生产堆叠+Drill-Down | `rpt_energy_production_stacked` | 堆叠柱状图 + 线图 | date, energy_type, granularity | generation_mwh, grid_load_mwh |
| 2 | Residual Load全期间汇总 | `rpt_residual_load_summary` | 数值卡片/表格 | (无维度) | 总时段数、绿电时段数、比例、平均小时数 |
| 3 | Top 10最绿日期 | `rpt_top_greenest_days` | 排序表格 | date, day_name | green_sufficient_hours, avg_renewable_share_pct |
| 4 | 最绿那天详细数据 | `rpt_greenest_day_detail` | 堆叠柱状图 + 虚线 | hour, energy_type | generation_mwh, grid_load_mwh, surplus_mwh |
| 5 | 月份过剩分布 | `rpt_monthly_surplus_distribution` | 热力图/柱状图 | year_month | surplus_pct, surplus_days_pct, price_diff |
| 6 | 小时绿电分布 | `rpt_hourly_distribution` | 柱状图 + 折线 | hour, hour_str | green_sufficient_pct, avg_price_diff |
| 7 | 电价散点分布 | `rpt_price_distribution` | 散点图 | surplus_flag, green_flag | price_eur_mwh, generation_mwh, grid_load_mwh |

---

## 📌 报告1: 能源生产堆叠+Drill-Down (年/月/日)

### 数据源
- **表**: `rpt_energy_production_stacked`
- **行数**: ~78万 (日度) + ~9.6万 (月度) + ~56 (年度)
- **关键字段**: `date`, `granularity` (DAILY/MONTHLY/YEARLY), `energy_type`, `total_generation_mwh`, `avg_grid_load_mwh`

### Tableau配置

**步骤1: 创建Calculated Field**
```
[Granularity Order] = 
IF [Granularity] = 'YEARLY' THEN 1
ELSEIF [Granularity] = 'MONTHLY' THEN 2
ELSE 3 END
```

**步骤2: 建立Sheet配置**
| 元素 | 配置 |
|------|------|
| **行** | `Date` (持续，按月聚合作为默认) |
| **列** | `Energy Type` (排序：Biomass, Hydro, Nuclear, Wind Offshore, Wind Onshore, Solar, ...) |
| **大小** | `Granularity` (用于drill-down) |
| **值** | `SUM(Total Generation MWh)` (堆叠) |
| **辅助轴** | `AVG(Avg Grid Load MWh)` (线型，黑色虚线) |
| **筛选** | `Granularity` (用户选择粒度) |
| **颜色** | `Energy Type` (预设能源类型配色) |

**步骤3: Drill-Down设置**
- Rows: `Date` → `Date` (按年/月/日) → 用户可逐级下钻
- 或创建参数让用户选择 `Granularity` 值

**步骤4: 格式化**
- 柱子宽度: 自适应
- 线宽: 2px
- 线型: --（虚线）
- 轴标题: "Generation (MWh)" 和 "Grid Load (MWh)"
- 调色板: 为每种能源类型分配固定颜色 (Solar=黄, Wind=蓝, Nuclear=红等)

**建议图表尺寸**:
- 宽度: 1200px
- 高度: 600px

---

## 📌 报告2: Residual Load全期间汇总KPI卡片

### 数据源
- **表**: `rpt_residual_load_summary`
- **行数**: 1行
- **关键字段**: `total_days`, `total_15min_intervals`, `green_sufficient_intervals`, `green_sufficient_pct`, `avg_green_hours_per_day`, `days_with_green_pct`

### Tableau配置

**步骤1: 创建4个KPI卡片**

| 卡片 | 字段 | 格式 |
|------|------|------|
| **绿电充足时段数** | `[Green Sufficient Intervals]` | 数值卡, 格式: #,##0 |
| **绿电充足比例** | `[Green Sufficient Pct]` | 仪表盘, 0-100% |
| **平均每天绿电小时** | `[Avg Green Hours Per Day]` | 数值卡, 格式: 0.00 小时 |
| **含有绿电时段的天数占比** | `[Days With Green Pct]` | 数值卡, 格式: 0.00% |

**步骤2: Tableau Dashboard组合**
- 排列方式: 2×2 网格或水平排列
- 卡片大小: 400×250px
- 字体大小: 标题 18pt, 数值 36pt

---

## 📌 报告3: Top 10最绿的日期

### 数据源
- **表**: `rpt_top_greenest_days`
- **行数**: 10行 (固定)
- **关键字段**: `green_rank`, `date`, `day_name`, `green_sufficient_hours`, `green_sufficient_pct`, `avg_renewable_share_pct`

### Tableau配置

**步骤1: 建表Sheet**
| 行 | 配置 |
|----|------|
| **行** | `Date (格式: YYYY-MM-DD)`, `Day Name`, `Green Rank` |
| **列值** | `Green Sufficient Hours`, `Green Sufficient Pct`, `Avg Renewable Share Pct` |

**步骤2: 排序
- 按 `Green Rank` 升序排序 (1-10)

**步骤3: 条件格式**
- `Green Sufficient Pct` 列: 应用色阶 (绿色 = 高, 白色 = 低)
- 字体: 数据字体 11pt, 表头 bold 12pt

**建议表格尺寸**:
- 宽度: 900px
- 高度: 450px

---

## 📌 报告4: 最绿那天详细小时数据

### 数据源
- **表**: `rpt_greenest_day_detail`
- **行数**: ~24行 (一天的小时数 × 能源类型数)
- **关键字段**: `hour`, `hour_str`, `energy_type`, `generation_mwh`, `grid_load_mwh`, `surplus_mwh`, `day_total_generation`, `day_total_surplus`

### Tableau配置

**步骤1: 建立主Sheet**
| 元素 | 配置 |
|------|------|
| **行** | `Hour Str` (0-23) |
| **列** | `Energy Type` |
| **值** | `SUM(Generation MWh)` (堆叠) + `AVG(Grid Load MWh)` (线) |
| **颜色** | `Energy Type` |

**步骤2: 添加虚线 (Grid Load)**
- 在值区放入第二个 `AVG(Grid Load MWh)`
- 设为双轴、同步轴范围
- 线宽: 2.5px, 颜色: 黑色, 线型: 虚线

**步骤3: 添加标注**
在图表右上角或下方添加Calculated Field显示:
```
[Daily Summary] = 
"日期: " + [Date Str] + " | 总发电量: " + STR(INT([Day Total Generation])) + " MWh | 过剩: " + STR(INT([Day Total Surplus])) + " MWh"
```

**步骤4: 格式化**
- 堆叠柱宽: 自适应
- 轴标题: "Generation by Hour (MWh)" 
- 说明文字: 显示日期、总发电量、surplus

**建议图表尺寸**:
- 宽度: 1000px
- 高度: 500px

---

## 📌 报告5: 月份过剩分布 (热力图)

### 数据源
- **表**: `rpt_monthly_surplus_distribution`
- **行数**: ~84行 (7年 × 12月)
- **关键字段**: `year_month`, `surplus_pct`, `surplus_days_pct`, `avg_price_surplus`, `avg_price_non_surplus`, `price_diff_surplus_vs_non`

### Tableau配置

**步骤1: 创建热力图**
| 元素 | 配置 |
|------|------|
| **行** | `Year` |
| **列** | `Month` (或 `Month Name`) |
| **颜色** | `Surplus Pct` (色阶: 白 0% → 黄 50% → 红 100%) |
| **大小** (可选) | `Surplus Days Pct` |
| **Tooltip** | `Year`, `Month Name`, `Surplus Pct`, `Avg Price Surplus`, `Avg Price Non Surplus` |

**步骤2: 月份排序**
- 确保 `Month` 按 1-12 顺序排列 (使用Month数值而非名称)

**步骤3: 格式化**
- 色阶颜色: 从白 (#ffffff) → 黄 (#ffff00) → 深红 (#cc0000)
- 单元格大小: 80×60px
- 文字: 显示百分比数值在格子中心 (12pt, bold白色)

**建议图表尺寸**:
- 宽度: 900px
- 高度: 400px

---

## 📌 报告6: 小时绿电分布 (一天中什么时候最绿)

### 数据源
- **表**: `rpt_hourly_distribution`
- **行数**: 24行 (每小时一行: 0-23)
- **关键字段**: `hour`, `hour_str`, `green_sufficient_pct`, `avg_grid_load_mwh`, `avg_price_green`, `avg_price_non_green`, `price_diff_non_green_vs_green`

### Tableau配置

**步骤1: 双轴图表**
| 元素 | 配置 |
|------|------|
| **行** | 无 |
| **列** | `Hour Str` (0-23, 排序) |
| **值1** | `Green Sufficient Pct` (柱状图, 绿色) |
| **值2** | `Price Diff Non Green vs Green` (折线, 蓝色或红色) |

**步骤2: 轴设置**
- 左轴: "Green Sufficiency %" (0-100%)
- 右轴: "Price Difference (€/MWh)" (自动或手动范围)

**步骤3: 格式化**
- 柱宽: 自适应
- 线宽: 2px
- 柱颜色: 渐变绿 (低 #ffffff, 高 #00cc00)
- 线颜色: 若值>0(过剩价格低)则绿, 若值<0(非过剩价格低)则红

**建议图表尺寸**:
- 宽度: 1000px
- 高度: 450px

---

## 📌 报告7: 电价散点分布 (过剩vs非过剩)

### 数据源
- **表**: `rpt_price_distribution`
- **行数**: ~122万行 (全期间15分钟数据)
- **关键字段**: `price_eur_mwh`, `grid_load_mwh`, `generation_mwh`, `surplus_flag`, `green_flag`, `renewable_share_pct`

### Tableau配置

**步骤1: 创建散点图**
| 元素 | 配置 |
|------|------|
| **行** | `Price Eur MWh` (连续) |
| **列** | `Renewable Share Pct` (连续) |
| **颜色** | `Surplus Flag` (过剩=绿, 非过剩=红) |
| **大小** | `Grid Load MWh` (点大小表示负荷大小) |
| **详细信息** | `Date`, `Hour`, `Green Flag`, `Generation MWh`, `Grid Load MWh` |

**步骤2: 筛选器**
- 添加 `Surplus Flag` 筛选器 (用户可选 Surplus/Non-Surplus/All)
- 添加 `Year` 或 `Month` 筛选器 (允许用户按时间范围筛选)

**步骤3: 趋势线**
- 为每个 `Surplus Flag` 分组添加趋势线 (线性)
- 显示 R² 值

**步骤4: 格式化**
- 点透明度: 40% (因为数据量大)
- 过剩点颜色: 绿色 (#00cc00)
- 非过剩点颜色: 红色 (#ff3333)
- 点大小范围: 2-15px
- 网格: 显示, 浅灰色

**建议图表尺寸**:
- 宽度: 1200px
- 高度: 700px

**数据量提示**: 
- 为避免性能问题,建议添加时间过滤器默认显示最近30天或某一个月的数据
- 或在Tableau中创建Extract以加速渲染

---

## 🎨 Tableau全局格式建议

### 颜色方案 - 能源类型标准色

为了跨报告1、4保持一致性,建议统一配色:

```
Biomass: #8B4513 (棕色)
Hydro: #4169E1 (皇家蓝)
Nuclear: #DC143C (鲜红)
Wind Offshore: #1E90FF (道奇蓝)
Wind Onshore: #87CEEB (天空蓝)
Solar: #FFD700 (金色)
Other: #808080 (灰色)
```

在Tableau中设置: 
1. 右键 `Energy Type` → Edit Colors
2. 粘贴上述颜色映射
3. Assign colors 按能源类型

### 字体与排版

- **标题**: Arial, 16pt, Bold, 深灰色 (#333333)
- **表头**: Arial, 12pt, Bold, 白底深蓝 (#003366)
- **数据**: Arial, 11pt, 黑色
- **说明文字**: Arial, 10pt, 浅灰色 (#666666)

### Dashboard布局

**推荐布局方案**:
```
┌─────────────────────────────────┐
│  报告1: 能源生产堆叠 (年/月/日) │ (占60%宽, 60%高)
├─────────────────────────────────┤
│ 报告2 (25%) │ 报告3 (35%)        │ (占40%宽)
├─────────────────────────────────┤
│ 报告5: 月份热力图 (占100%)       │ (占100%宽, 30%高)
├─────────────────────────────────┤
│ 报告6: 小时分布 (占50%) │ 报告7 │ (散点图)
└─────────────────────────────────┘
```

---

## 🔧 连接BigQuery的步骤

1. 在Tableau中: **Data** → **New Data Source** → **Google BigQuery**
2. 输入项目ID: `zeta-medley-473321-r6`
3. 选择数据集: `smard_dbt`
4. 分别拖入以下表:
   - `rpt_energy_production_stacked`
   - `rpt_residual_load_summary`
   - `rpt_top_greenest_days`
   - `rpt_greenest_day_detail`
   - `rpt_monthly_surplus_distribution`
   - `rpt_hourly_distribution`
   - `rpt_price_distribution`

5. 每个表作为单独的数据源，创建相应的Sheet和Dashboard

---

## 📊 性能优化提示

| 表名 | 行数 | 建议Tableau Extract? | 刷新频率 |
|------|------|-----|------|
| rpt_energy_production_stacked | ~80万 | 是 (按日期分区Extract) | 每天凌晨 |
| rpt_residual_load_summary | 1 | 否 | 每小时 |
| rpt_top_greenest_days | 10 | 否 | 每天 |
| rpt_greenest_day_detail | ~24 | 否 | 每天 |
| rpt_monthly_surplus_distribution | ~84 | 否 | 每天 |
| rpt_hourly_distribution | 24 | 否 | 每小时 |
| rpt_price_distribution | ~120万 | 是 (按月分区Extract) | 按需 |

---

## 🚀 创建高级分析

### 自定义计算字段示例

在Tableau中创建以下Calculated Fields扩展分析:

**1. 按年对比绿电占比**
```
[YoY Green Growth %] = 
([Green Sufficient Pct] - LOOKUP([Green Sufficient Pct], -1)) / LOOKUP([Green Sufficient Pct], -1)
```

**2. 电价与绿电的相关性系数**
```
[Price Green Correlation] = 
CORR([Avg Price Green], [Green Sufficient Hours])
```

**3. 过剩时段的平均储能机会**
```
[Storage Opportunity MWh] = 
IF [Green Flag] = 'Green' THEN [Surplus MWh] ELSE 0 END
```

---

## 📞 故障排除

| 问题 | 解决方案 |
|------|---------|
| 表格加载很慢 | 创建Tableau Extract并按日期/年份分区 |
| 聚合值不正确 | 检查SUM vs AVG的使用 (日度用SUM, 小时用AVG) |
| 颜色不匹配 | 确保 `Energy Type` 值完全一致 (包括大小写) |
| Drill-down不工作 | 确保 `Date` 字段格式为DATE, 在Rows中设置层级 |
| 散点图太密集 | 使用Alpha透明度 (40%), 或添加时间过滤器 |

---

## 📝 建议的后续步骤

1. ✅ 创建上述7个Sheets
2. ✅ 将它们组织到Dashboard中
3. ✅ 添加时间过滤器 (Year, Month, Date range)
4. ✅ 设置Refresh Schedule (每天凌晨, dbt运行完成后30分钟)
5. ✅ 发布到Tableau Server/Online供团队访问
6. ✅ 创建告警规则 (如 Green Sufficient Pct > 5% 时发送通知)
7. ✅ 集成到Executive Dashboard并计划周/月报告


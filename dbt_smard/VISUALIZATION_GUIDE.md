# dbt 表可视化指南

## 📊 dbt 的三层架构

```
┌─────────────────────────────────────────────────────┐
│         Raw Data (SMARD API)                        │
│     253K rows × 15分钟                              │
└────────────────────┬────────────────────────────────┘
                     │
                     ⬇️ Kestra 数据加载
                     
┌─────────────────────────────────────────────────────┐
│    🟢 STAGING LAYER（数据准备与清洗）              │
├─────────────────────────────────────────────────────┤
│ • stg_generation    (15分钟)  253K 行               │
│ • stg_consumption   (15分钟)  253K 行               │
│ • stg_prices        (15分钟)  253K 行               │
│ → 去重、类型转换、维度添加                          │
│ → Looker/Google Data Studio 可直接用                │
└────────────────────┬────────────────────────────────┘
                     │
                     ⬇️ 业务转换
                     
┌─────────────────────────────────────────────────────┐
│    🟡 MART LAYER（业务聚合与关键指标）             │
├─────────────────────────────────────────────────────┤
│ • fct_energy_balance  (小时)  8.8K 行              │
│ • mart_energy_mix     (15分钟) 420K 行             │
│ • dim_energy_types    (维度)   12 行               │
│ → 预先 JOIN、聚合、计算比率                         │
│ → Looker 可用 LookML 进一步定义                     │
│ → Tableau 需要继续优化                              │
└────────────────────┬────────────────────────────────┘
                     │
                     ⬇️ 报表优化 ⭐ 仅 Tableau 需要
                     
┌─────────────────────────────────────────────────────┐
│    🔴 REPORTING LAYER（报表优化）  ⭐ Tableau      │
├─────────────────────────────────────────────────────┤
│ • rpt_daily_summary    (按日)  2.7K 行             │
│ • rpt_hourly_summary   (按小时) 26.5K 行           │
│ • rpt_price_analysis   (按日/小时) 预计算          │
│ • rpt_renewable_trend  (聚合维度) 优化            │
│ → 宽表设计（一行包含所有指标）                      │
│ → 预计算所有常用聚合                                │
│ → Tableau 拖拽式查询秒级响应                        │
└─────────────────────────────────────────────────────┘
         ⬇️ BI 工具消费
         
    ┌──────────┬──────────┬──────────┐
    │  Looker  │ Tableau  │ Google   │
    │ (LookML) │(Reports) │Data Stud │
    └──────────┴──────────┴──────────┘
```

### 1. **Staging 层（数据准备）**
| 表名 | 粒度 | 记录数 | 适合工具 | Tableau 用 |
|------|------|--------|---------|----------|
| `stg_generation` | 15分钟 | 253K | Looker, GDS | ❌ 太细 |
| `stg_consumption` | 15分钟 | 253K | Looker, GDS | ❌ 太细 |
| `stg_prices` | 15分钟 | 253K | Looker, GDS | ❌ 太细 |

### 2. **Mart 层（业务聚合）**
| 表名 | 粒度 | 记录数 | 适合工具 | Tableau 用 |
|------|------|--------|---------|----------|
| `fct_energy_balance` | 小时 | 8.8K | Looker ⭐ | ✅ 可用 |
| `mart_energy_mix` | 15分钟 | 420K | Looker ⭐ | ⚠️ 建议报表层 |
| `dim_energy_types` | 维度 | 12行 | All | ✅ 参考 |

### 3. **Reporting 层（报表优化）⭐ 仅 Tableau 需要**
| 表名 | 粒度 | 记录数 | 用途 |
|------|------|--------|------|
| `rpt_daily_summary` | **按日** | 2.7K | Tableau KPI 仪表板 |
| `rpt_hourly_summary` | **按小时** | 26.5K | Tableau 详细分析 |
| `rpt_energy_mix_daily` | **按日+能源** | 32.4K | Tableau 能源对比 |
| `rpt_price_analysis` | **预计算价格指标** | 8.8K | Tableau 电价分析 |
| `rpt_renewable_trend` | **按周期+聚合** | 2.4K | Tableau 绿能趋势 |

---

## 🎯 按场景推荐的可视化

### **场景1：实时能源监控仪表板**
**推荐表**：`fct_energy_balance`（小时粒度）

```
📈 图表建议：
├─ 发电与需求对比（面积图）
│  ├─ X轴：日期+小时
│  ├─ Y轴：发电量 vs 需求量 (MWh)
│  └─ 颜色：绿/红区分盈余/缺口
│
├─ 盈余/赤字趋势（线图）
│  ├─ 指标：balance_gap_mwh
│  ├─ 按小时/按天分组
│  └─ 红线标记0点
│
├─ 供应比（KPI卡）
│  ├─ supply_ratio = generation / grid_load
│  ├─ 目标：> 1.0 = 有盈余
│  └─ 按日/周/月显示
│
└─ 负价格时段（柱状图）
   ├─ X轴：日期
   ├─ Y轴：负价格时段数
   └─ 年度对比
```

**SQL查询示例**：
```sql
SELECT 
  date,
  hour_berlin,
  total_generation_mwh,
  total_grid_load_mwh,
  balance_gap_mwh,
  supply_ratio,
  CASE WHEN supply_ratio > 1 THEN '盈余' ELSE '缺口' END as status
FROM fct_energy_balance
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
ORDER BY date DESC, hour_berlin DESC;
```

---

### **场景2：能源结构深度分析**
**推荐表**：`mart_energy_mix`（15分钟粒度，包含所有能源类型）

```
📈 图表建议：
├─ 能源类型占比（堆积面积图）
│  ├─ X轴：时间（按天/周分组）
│  ├─ Y轴：发电量 (MWh)
│  ├─ 层：12种能源类型
│  └─ 颜色编码：
│     ├─ 绿色：风光生物质
│     ├─ 黄色：核能
│     ├─ 棕色：煤炭
│     ├─ 灰色：天然气
│     └─ 其他
│
├─ 单位能源价值（散点图）
│  ├─ X轴：generation_mwh
│  ├─ Y轴：price_eur_mwh
│  ├─ 大小：generation_revenue_eur
│  └─ 颜色：energy_type
│
├─ 可再生能源占比趋势（线图）
│  ├─ renewable_share = sum(renewable) / sum(all)
│  ├─ 按日/周/月趋势
│  └─ 增长率指示
│
└─ 能源类型KPI（并排卡片）
   ├─ 总发电量 (MWh)
   ├─ 平均占比 (%)
   ├─ 收益 (EUR)
   └─ 利用率 (%)
```

**SQL查询示例**：
```sql
SELECT 
  berlin_date as date,
  energy_type,
  category,
  SUM(generation_mwh) as total_generation,
  AVG(generation_share_pct) as avg_share_pct,
  SUM(generation_revenue_eur) as total_revenue,
  COUNT(*) as data_points
FROM mart_energy_mix
WHERE berlin_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY date, energy_type, category
ORDER BY date DESC, total_generation DESC;
```

---

## 🎯 **Looker vs Tableau 的架构差异**

这是关键问题！两者对 dbt 的需求完全不同。

### 架构对比

| 维度 | **Looker** | **Tableau** |
|------|-----------|-----------|
| **需要报表层？** | ❌ **不需要** | ✅ **需要** |
| **建模能力** | ✅ LookML（强大） | ❌ 弱（只有计算字段） |
| **查询优化** | ✅ 自动优化（BI-Engine） | ⚠️ 依赖数据库查询 |
| **预计算** | ❌ 动态计算 | ✅ 需要预先计算 |
| **理想数据粒度** | 🟢 原始 + mart（15分钟） | 🟠 聚合（小时/日） |
| **性能响应** | 秒级 | 毫秒级（需要报表层） |

### 为什么 Tableau 需要报表层？

#### ❌ 问题情景：直接用 mart_energy_mix（420K行）

```
用户在 Tableau 中创建仪表板：
├─ 拖拽 energy_type 到行
├─ 拖拽 generation_mwh 到值
├─ Tableau 发送 SQL：SELECT energy_type, SUM(generation_mwh) FROM mart_energy_mix
├─ BigQuery 现场计算（扫描 420K 行）
├─ 等待时间：15-30 秒...😞
└─ 用户体验：卡顿、交互慢

根本原因：
• Tableau 是"查询驱动"，每次交互都发起新查询
• mart_energy_mix 没有预聚合
• 每个仪表板切片都需要重新扫描 420K 行
• 没有 Looker 的 BI-Engine 缓存机制
```

#### ✅ 解决方案：dbt 生成报表层

```
dbt 预先生成 rpt_daily_summary（2.7K 行，聚合完成）

用户在 Tableau 中创建仪表板：
├─ 拖拽 energy_type 到行
├─ 拖拽 total_generation_mwh 到值
├─ Tableau 发送 SQL：SELECT energy_type, SUM(total_generation_mwh) FROM rpt_daily_summary
├─ BigQuery 返回（只扫描 2.7K 行，<1秒）
├─ 仪表板秒速加载 ⚡
└─ 用户体验：流畅、响应快

优势：
• 查询快 100 倍（420K → 2.7K）
• Tableau 交互秒级响应
• 下钻、过滤、联动都流畅
• 报表层成本低（每天 dbt 跑一次）
```

### 实际性能对比

```
场景：统计 2026 年 4 月的平均能源结构

方案 A: Looker + mart_energy_mix（420K行）
  ├─ LookML：measure: avg_renewable_share { ... }
  ├─ 响应时间：秒级（BI-Engine 缓存）
  └─ 体验：✅ 流畅

方案 B: Tableau + mart_energy_mix（420K行）
  ├─ 查询：SELECT AVG(generation_share_pct) ... GROUP BY energy_type
  ├─ 响应时间：10-20 秒（现场聚合 420K 行）
  └─ 体验：❌ 卡顿

方案 C: Tableau + rpt_daily_summary（2.7K行，预计算）
  ├─ 查询：SELECT AVG(daily_renewable_share) ... GROUP BY energy_type
  ├─ 响应时间：0.5-1 秒（数据已聚合）
  └─ 体验：✅✅ 优秀
```

---

### **场景3：电价与需求关系**
**推荐表**：`fct_energy_balance` + `mart_energy_mix`

```
📈 图表建议：
├─ 电价与负荷关系（散点气泡图）
│  ├─ X轴：total_grid_load_mwh
│  ├─ Y轴：avg_price_eur_mwh
│  ├─ 气泡大小：negative_price_blocks
│  ├─ 颜色：按月/季度
│  └─ 发现：高需求→高价格？
│
├─ 极端价格时段分析（条形图）
│  ├─ 负价格时段排名
│  ├─ 每日负价格时段数
│  ├─ 对比年度趋势
│  └─ 原因分析（风光高发？）
│
├─ 价格分布（直方图/盒图）
│  ├─ 按能源类型
│  ├─ 按季节
│  ├─ 发现异常值
│  └─ 波动率分析
│
└─ 时段价格热力图（热力图）
   ├─ X轴：小时（0-23）
   ├─ Y轴：日期
   ├─ 色值：平均价格
   ├─ 发现：哪些时段高价？
   └─ 原因：消费峰值时段
```

**SQL查询示例**：
```sql
SELECT 
  date,
  hour_berlin,
  avg_price_eur_mwh,
  total_grid_load_mwh,
  negative_price_blocks,
  CASE 
    WHEN avg_price_eur_mwh < 0 THEN '负价格'
    WHEN avg_price_eur_mwh < 50 THEN '低价'
    WHEN avg_price_eur_mwh < 100 THEN '中价'
    ELSE '高价' 
  END as price_tier
FROM fct_energy_balance
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
ORDER BY date, hour_berlin;
```

---

### **场景4：盈余与赤字分析**
**推荐表**：`fct_energy_balance`

```
📈 图表建议：
├─ 风光充分供应时段分析 ⭐
│  ├─ 指标：residual_load < 0 的时段
│  ├─ 2019年：0 时段（0.00%）
│  ├─ 2020年：逐步增加...
│  ├─ 全数据集：1,412 时段（0.56%）
│  └─ 趋势：显示绿能渗透率提升
│
├─ 按小时分析盈余规律（热力图）
│  ├─ X轴：小时（0-23）
│  ├─ Y轴：月份（1-12）
│  ├─ 色值：average balance_gap_mwh
│  ├─ 模式：夜间常盈余，中午缺口？
│  └─ 原因：消费vs风光发电规律
│
├─ 年度盈余统计（柱状图）
│  ├─ X轴：年份（2019-2026）
│  ├─ Y轴：盈余时段占比（%）
│  └─ 对比：德国绿能目标进度
│
└─ 缺口风险等级（仪表盘）
   ├─ 绿区：balance_gap > 1000 MWh
   ├─ 黄区：-1000 < gap < 1000 MWh
   ├─ 红区：gap < -1000 MWh
   └─ 实时告警：缺口超过阈值
```

**SQL查询示例**：
```sql
SELECT 
  DATE_TRUNC(date, MONTH) as month,
  EXTRACT(HOUR FROM DATETIME(date, 'Europe/Berlin')) as hour,
  AVG(balance_gap_mwh) as avg_balance_gap,
  AVG(supply_ratio) as avg_ratio,
  COUNTIF(is_surplus = 1) as surplus_hours,
  COUNT(*) as total_hours,
  100.0 * COUNTIF(is_surplus = 1) / COUNT(*) as surplus_pct
FROM fct_energy_balance
GROUP BY month, hour
ORDER BY month DESC, hour;
```

---

### **场景5：季节性与周期性分析**
**推荐表**：`fct_energy_balance`

```
📈 图表建议：
├─ 月度对比（并排柱状图）
│  ├─ 显示内容：
│  │  ├─ 月均发电量
│  │  ├─ 月均需求量
│  │  ├─ 月度盈余率
│  │  └─ 平均电价
│  └─ 发现季节差异
│
├─ 周期性模式（小提琴图）
│  ├─ 按工作日/周末分组
│  ├─ 显示需求分布
│  ├─ 发现规律性变化
│  └─ 预测能力提升
│
├─ 日内负荷曲线（多线图）
│  ├─ X轴：小时（0-23）
│  ├─ Y轴：平均需求 (MWh)
│  ├─ 按月份多条线
│  ├─ 发现：夏季vs冬季差异
│  └─ 应用：精准预报
│
└─ 能源转型进度（面积堆积图）
   ├─ 显示：可再生占比 vs 时间
   ├─ 按季度分解
   ├─ 对标：EU 2030/2050 目标
   └─ 目标线注记
```

---

## 🎨 推荐的可视化工具

| 工具 | 优势 | 适合表 | 成本 | 学习曲线 | **dbt要求** |
|------|------|--------|------|----------|----------|
| **Google Data Studio** | 原生BigQuery支持、免费 | 所有表 | 免费 | 🟢 很低 | staging+mart |
| **Metabase** | 开源、轻量、SQL友好 | 所有表 | 免费/$ | 🟢 很低 | staging+mart |
| **Looker** | ⭐ dbt原生集成、企业级 | 所有表 | $$$$ | 🟠 中等 | staging+mart |
| **Tableau** | 强大交互、拖拽式 | **reporting层** | $$$ | 🟡 高 | **staging+mart+reporting** |
| **Apache Superset** | 开源、Python原生 | 所有表 | 免费 | 🟠 中等 | staging+mart |
| **Grafana** | 实时监控、告警系统 | fct_energy_balance | 免费/$ | 🟡 高 | staging+mart |

### 核心差异：Tableau 独特需求

⚠️ **Tableau 是唯一需要 reporting 层的工具**

```
Looker/Google DS/Metabase:
  └─ stg_* → mart_* → 直接使用 ✅

Tableau:
  └─ stg_* → mart_* → reporting_* → 使用 ✅✅
     (多一层预计算/预聚合)
```

**为什么？**
- Looker：有 LookML 建模层 + BI-Engine 缓存 = 能处理原始数据
- Tableau：无建模层，只有计算字段 = 需要预聚合的宽表

---

## 🎯 **Tableau 专项方案**（如果选择 Tableau）

### 关键要求

如果决定用 Tableau，dbt 需要生成 **reporting 层**（5个预聚合表）：

| 表名 | 粒度 | 行数 | 作用 |
|------|------|------|------|
| `rpt_daily_summary` | 按日 | 2.7K | KPI仪表板、日度趋势 |
| `rpt_hourly_summary` | 按小时 | 26.5K | 时间热力图、详细分析 |
| `rpt_energy_mix_daily` | 按日+能源 | 32.4K | 能源结构对比 |
| `rpt_price_analysis` | 小时价格 | 8.8K | 电价时序、分布 |
| `rpt_renewable_trend` | 聚合周期 | 2.4K | 绿能占比趋势 |

### Reporting 层特点

```sql
-- 典型 reporting 表结构（宽表设计）

SELECT
  date,
  year,
  month,
  quarter,
  week,
  day_of_week,
  
  -- 所有常用指标都已预计算
  total_generation_mwh,          -- 无需现场 SUM
  avg_generation_mwh,            -- 无需现场 AVG
  total_load_mwh,                -- 无需现场 SUM
  avg_load_mwh,                  -- 无需现场 AVG
  surplus_hours,                 -- 无需现场 COUNT/FILTER
  surplus_pct,                   -- 无需现场计算占比
  avg_price_eur_mwh,             -- 无需现场 AVG
  renewable_share_pct,           -- 无需现场计算
  
  -- Tableau 直接拖拽即用！
FROM rpt_daily_summary
```

**优势**：
- ✅ Tableau 秒级响应（预计算完成）
- ✅ 用户体验流畅（无等待时间）
- ✅ 支持下钻、过滤、联动
- ✅ 成本低（每天跑一次 dbt）

### 部署步骤

#### 1. 创建 reporting 目录

```bash
mkdir -p dbt_smard/models/reporting
```

#### 2. 复制报表层 SQL 文件

报表层完整 SQL 已写在：[models/reporting/README.md](models/reporting/README.md)

包含 5 个完整表定义：
- `rpt_daily_summary.sql`
- `rpt_hourly_summary.sql`
- `rpt_energy_mix_daily.sql`
- `rpt_price_analysis.sql`
- `rpt_renewable_trend.sql`

#### 3. 运行 dbt

```bash
dbt run -s reporting  # 生成所有报表层表
```

#### 4. 在 Tableau 中连接

```
Tableau → Data → New Data Source → BigQuery
选择表：rpt_daily_summary, rpt_energy_mix_daily 等
拖拽字段构建仪表板 → 秒级响应！
```

### 实际 Tableau 仪表板代码示例

```tableau
// 仪表板：德国能源监控中心

// Sheet 1: KPI 卡片（数据源：rpt_daily_summary）
- 总发电：SUM(total_generation_mwh) 过去30天
- 总需求：SUM(total_load_mwh) 过去30天  
- 盈余率：AVG(surplus_pct) 过去30天
- 绿能占比：AVG(renewable_share_pct) 过去30天

// Sheet 2: 能源结构堆积图（数据源：rpt_energy_mix_daily）
- 行：date (按月分组)
- 列：SUM(total_generation_mwh)
- 颜色：energy_type (12种能源)
- 过滤：year = 2026

// Sheet 3: 价格热力图（数据源：rpt_hourly_summary）
- 行：date
- 列：hour_berlin
- 色值：avg_price_eur_mwh
- 大小：avg_price_eur_mwh (表达负价格)

// Sheet 4: 绿能趋势线（数据源：rpt_renewable_trend）
- 行：date
- 列：renewable_share_pct_display
- 颜色：year
- 参考线：yearly_renewable_avg (年度目标)

💡 所有查询 <1 秒响应！
```

### ROI 分析（Tableau 方案）

| 投入 | 成本/月 | 时间 |
|------|--------|------|
| dbt reporting 层开发 | - | **1周（一次性）** |
| Tableau Server | $2,000 | 持续 |
| BigQuery 查询 | $100 | 持续（预聚合后大幅降低） |
| 数据工程维护 | - | **1小时/周** |
| **合计** | **$2,100/月** | **初期1周 + 周维护1h** |

**收益**：
- ✅ 用户体验优秀（秒级响应）
- ✅ 比 Looker 便宜 $1,000/月
- ✅ 可视化设计能力强（Tableau 优于 Looker）
- ⚠️ 需要数据工程维护报表层

---

## 🔗 **三种主流 BI 工具对比总结**

| 方案 | 启动投入 | 月度成本 | 学习曲线 | 报表响应 | 适合场景 |
|------|---------|---------|---------|---------|---------|
| **Google Data Studio** | 2小时 | 免费 | 1天 | 秒级 | 快速原型、分享演示 |
| **Metabase** | 1周 | $0/开源 | 3天 | 秒级 | 团队内部自托管 |
| **Looker** | 3周 | $3,000 | 2周 | 秒级 | 企业级、dbt深度集成 |
| **Tableau** | 2周 | $2,100 | 2周 | <1秒 | 强交互、高管演示 |

### 推荐决策树

```
Q1: 有没有专业 BI 工具预算？
├─ NO → Google Data Studio（免费）
└─ YES → 进入 Q2

Q2: 是否重视 dbt 集成？
├─ YES → Looker（LookML）
└─ NO → 进入 Q3

Q3: 是否需要强大的交互和可视化？
├─ YES → Tableau （需要 reporting 层）
├─ NO → Metabase（开源平衡方案）
```

---

## 🎨 推荐的可视化工具

| 工具 | 优势 | 适合表 | 成本 | 学习曲线 |
|------|------|--------|------|----------|
| **Google Data Studio** | 原生BigQuery支持、免费 | 所有表 | 免费 | 🟢 很低 |
| **Metabase** | 开源、轻量、SQL友好 | 所有表 | 免费/$ | 🟢 很低 |
| **Looker** | ⭐ dbt原生集成、企业级 | 所有表 | $$$$ | 🟠 中等 |
| **Tableau** | 强大交互、拖拽式 | **reporting层** | $$$ | 🟡 高 |
````| **Apache Superset** | 开源、Python原生 | 所有表 | 免费 | 🟠 中等 |
| **Grafana** | 实时监控、告警系统 | fct_energy_balance | 免费/$ | 🟡 高 |

### 快速开始建议

#### 选项1：Google Data Studio（推荐入门）
```bash
# ✅ 最快上手（5分钟）
# - 完全免费
# - 直连BigQuery无需配置
# - 适合：快速原型、演示、分享
# - 限制：有限的自定义能力、不支持复杂聚合

步骤：
1. 访问 https://datastudio.google.com
2. 创建报表 → 连接 BigQuery → 选择表
3. 拖拽维度/指标构建图表
4. 完成！
```

#### 选项2：Metabase（推荐平衡方案）
```bash
# ✅ 开源、功能完整、Docker快速部署
# - SQL编辑器强大
# - 权限控制好
# - 可视化类型丰富
# - 适合：团队内部使用、自托管

docker run -d -p 3000:3000 \
  -e MB_DB_TYPE=postgres \
  -e MB_DB_CONNECTION_URI="postgresql://..." \
  metabase/metabase

# 访问 http://localhost:3000
# 默认账户：admin@metabase.local / metabase
```

#### 选项3：Looker（推荐企业方案）
下文详细介绍 👇
```

---

## 📋 建议的仪表板优先级

### 第一阶段（MVP）- 1-2周
```
┌─────────────────────────────────────────┐
│     德国能源监控中心 - 实时仪表板        │
├─────────────────────────────────────────┤
│ 📊 核心KPI                              │
│ ├─ 当前发电量: 35,200 MWh               │
│ ├─ 当前需求量: 32,100 MWh               │
│ ├─ 盈余状态:   ✅ 110.8% (盈余)         │
│ ├─ 可再生占比: 📈 45.3%                  │
│ └─ 平均电价:   €62.50/MWh               │
│                                         │
│ 📈 能源结构 (过去24小时)                 │
│ [堆积面积图]                             │
│ 风电 |██████  42%                       │
│ 光伏 |███    15%                        │
│ 核能 |███████ 28%                       │
│ 煤炭 |███     10%                       │
│ 气电 |█       5%                        │
│                                         │
│ 📊 负荷vs发电 (过去7天)                 │
│ [双Y轴线图]                              │
└─────────────────────────────────────────┘
```

### 第二阶段 - 4-6周
- 能源结构详细分析（drill-down）
- 电价与市场动态
- 季节性趋势预报
- 能源转型进度跟踪

### 第三阶段 - 8-12周
- 预测模型集成
- 异常告警系统
- 成本分析（按能源类型）
- 跨域对标（欧洲其他国家）

---

## 🎯 **Looker 专项方案**（推荐企业级）

### 为什么选 Looker？

| 特性 | 优势 | 使用场景 |
|------|------|---------|
| **dbt 原生集成** | LookML 自动引用 dbt 元数据 | 与数据工程工作流完全同步 |
| **LookML** | 代码化定义 Metrics/Dimensions | Version control, review, reuse |
| **Explores** | 灵活的 ad-hoc 分析工具 | 业务用户自助查询，无需SQL |
| **权限系统** | 行级、列级、仪表板级访问控制 | 合规、安全、多租户 |
| **BI-Engine** | 自动缓存、毫秒级响应 | 大数据集秒级查询 |
| **Alert & Scheduling** | 内置告警系统 | 风光充分供应触发告警 |
| **嵌入式仪表板** | API 集成到其他系统 | 融入能源管理平台 |

### Looker 架构

```
┌─────────────────────────────────────────────────┐
│          Looker Instance (Cloud/On-Prem)        │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────────────────────────────────────┐  │
│  │      LookML Project (version control)    │  │
│  ├─────────────────────────────────────────┤  │
│  │ 📄 model: energy.model.lkml             │  │
│  │   ├─ explore: energy_dashboard          │  │
│  │   ├─ view: fct_energy_balance           │  │
│  │   ├─ view: mart_energy_mix              │  │
│  │   └─ view: dim_energy_types             │  │
│  │                                         │  │
│  │ 📊 dashboard: real_time_monitor.dashboard.lookml │
│  │   ├─ tile: generation_vs_demand         │  │
│  │   ├─ tile: energy_mix_breakdown         │  │
│  │   ├─ tile: renewable_share_trend       │  │
│  │   └─ tile: price_analysis              │  │
│  │                                         │  │
│  │ ⏰ scheduled_job: daily_alert.view.lkml │  │
│  │   └─ measure: count_green_supply_hours  │  │
│  └─────────────────────────────────────────┘  │
│                    ⬇️                          │
│           BigQuery Connection                  │
│                                                 │
└─────────────────────────────────────────────────┘
         ⬇️                        ⬇️
    📊 Dashboard            ⚙️ dbt Jobs
    💻 Explores              📦 Models
    📈 Looks                🔄 Lineage
```

### 核心概念

#### 1. **View** - 对应 dbt 表的逻辑层

```yaml
view: fct_energy_balance {
  # 指向 BigQuery 表
  sql_table_name: smard_dbt.fct_energy_balance ;;
  
  # Dimensions（分类维度 - 用于过滤/分组）
  dimension: date_date {
    type: date
    sql: ${TABLE}.date ;;
  }
  
  dimension: supply_status {
    type: string
    sql: CASE 
      WHEN ${supply_ratio} > 1.1 THEN "充盈"
      WHEN ${supply_ratio} > 1.0 THEN "盈余"
      ELSE "缺口"
    END ;;
  }
  
  # Measures（数值度量 - 用于聚合/计算）
  measure: total_generation_mwh {
    type: sum
    sql: ${TABLE}.total_generation_mwh ;;
    value_format: "#,##0"
  }
  
  measure: avg_supply_ratio {
    type: average
    sql: ${TABLE}.supply_ratio ;;
    value_format: "0.0%"
  }
}
```

#### 2. **Explore** - 交互式查询工具

用户不需要写 SQL，直接在 UI 上选择维度和度量：

```yaml
explore: fct_energy_balance {
  label: "⚡ 能源平衡分析"
  description: "小时粒度的能源供需平衡"
  
  # 默认过滤
  always_filter: {
    filters: [date_date: "7 days"]
  }
  
  # JOIN 其他表
  join: energy_type {
    type: left_outer
    sql_on: 1=1 ;;
  }
}
```

业务用户体验：
- 选择时间维度（日期、小时）
- 选择度量（总发电、总需求）
- 选择分组（按供应状态、按能源类型）
- 自动生成图表
- **无需 SQL 知识！**

#### 3. **Dashboard** - 可视化仪表板

```yaml
dashboard: real_time_energy_monitor {
  title: "🌍 德国能源实时监控中心"
  
  elements:
    # KPI 卡片
    - name: current_generation
      title: "当前发电量"
      type: single_value
      query:
        explore: fct_energy_balance
        dimensions: []
        measures: [total_generation_mwh]
        filters: { date_date: "today" }
    
    # 时间序列线图
    - name: generation_trend
      title: "7天发电趋势"
      type: looker_line
      query:
        explore: fct_energy_balance
        dimensions: [date_date]
        measures: [total_generation_mwh]
        filters: { date_date: "7 days" }
    
    # 能源结构饼图
    - name: energy_mix_pie
      title: "能源类型占比"
      type: looker_pie
      query:
        explore: mart_energy_mix
        dimensions: [energy_type]
        measures: [total_generation_mwh]
}
```

#### 4. **Alert** - 自动告警

```yaml
dashboard_filter_alert: green_supply_alert {
  dashboard_id: "real_time_energy_monitor"
  title: "风光充分供应告警"
  
  # 条件：when residual_load < 0
  alert_condition: {
    elements: ["renewable_supply_tile"]
    condition: "count > 0"
  }
  
  # 告警通知
  send_to: ["team@energy-monitor.de", "slack_channel"]
  message: "✅ 绿电时刻！风光充分发电，可再生能源正在覆盖当前需求"
}
```

### 快速实施（3步启动）

#### Step 1：创建 LookML 项目结构

```bash
mkdir -p looker_project
cd looker_project

# 创建基本文件
cat > views/fct_energy_balance.view.lkml << 'EOF'
view: fct_energy_balance {
  sql_table_name: smard_dbt.fct_energy_balance ;;
  
  dimension: date_date { type: date; sql: ${TABLE}.date ;; }
  dimension: hour { type: number; sql: ${TABLE}.hour_berlin ;; }
  
  measure: total_generation { type: sum; sql: ${TABLE}.total_generation_mwh ;; }
  measure: total_load { type: sum; sql: ${TABLE}.total_grid_load_mwh ;; }
  measure: avg_ratio { type: average; sql: ${TABLE}.supply_ratio ;; value_format: "0.0%" }
}
EOF

cat > models/energy.model.lkml << 'EOF'
connection: "bigquery_smard"

explore: fct_energy_balance {}
EOF

# 推送到 Git
git init
git add .
git commit -m "Initial Looker LookML project"
git push origin main
```

#### Step 2：连接 Looker to BigQuery

```bash
# 在 Looker Admin 面板
# 1. Settings → Connections
# 2. New Connection
#    - Type: BigQuery
#    - Project: zeta-medley-473321
#    - Dataset: smard_dbt
#    - Auth: Service Account (JSON)

# 3. Save & Test Connection
```

#### Step 3：部署 LookML 项目

```bash
# 在 Looker Admin 面板
# 1. Settings → Projects
# 2. New Project
#    - Name: smard_energy
#    - Repository: https://github.com/your-org/looker_smard.git
#    - Branch: main

# 3. Deploy
# Looker 自动拉取代码并验证
```

### 部署选项对比

| 选项 | 成本/月 | 维护 | 功能 | 推荐 |
|------|--------|------|------|------|
| **Looker Cloud** | $3,000+ | ✅ 无 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ 生产环境 |
| **Looker Docker** | $0 | ❌ 高 | ⭐⭐⭐⭐ | ⭐⭐ 开发/测试 |
| **GCP Marketplace** | $2,000+ | ✅ 无 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ 已有GCP用户 |

### Looker 仪表板示例代码

完整的真实场景示例：

```yaml
# dashboards/energy_operations.dashboard.lookml

title: "⚡ 能源运营中心"
description: "实时监控德国能源供需平衡"
layout: newspaper
refresh_interval: "30m"

filters:
  - name: date_filter
    title: "时间范围"
    type: field_filter
    explore: fct_energy_balance
    field: fct_energy_balance.date_date
    default_value: "7 days"

elements:

  # ─── 第一行：核心 KPI ──────────────────
  
  - name: kpi_generation
    title: "⚡ 当前发电量"
    type: single_value
    subtitle: "全国总发电容量"
    query:
      explore: fct_energy_balance
      dimensions: []
      measures: [total_generation_mwh]
      filters:
        date_date: "today"
    
    color: "#1F77B4"
    comparison:
      delta: "previous_period"
      percentage: true

  - name: kpi_load
    title: "📊 当前需求量"
    type: single_value
    subtitle: "并网电力需求"
    query:
      explore: fct_energy_balance
      dimensions: []
      measures: [total_load]
      filters:
        date_date: "today"
    
    color: "#FF7F0E"

  - name: kpi_ratio
    title: "📈 供应比"
    type: gauge
    query:
      explore: fct_energy_balance
      dimensions: []
      measures: [avg_ratio]
      filters:
        date_date: "today"
    
    goal: 1.0
    min: 0.8
    max: 1.2

  - name: kpi_renewable
    title: "🌱 可再生占比"
    type: single_value
    query:
      explore: mart_energy_mix
      dimensions: []
      measures: [avg_share_pct]
      filters:
        category: "renewable"
        timestamp_date: "today"

  # ─── 第二行：时间趋势 ────────────────
  
  - name: generation_vs_load_trend
    title: "发电vs需求对比"
    subtitle: "过去30天趋势"
    type: looker_area
    query:
      explore: fct_energy_balance
      dimensions: [date_date]
      measures: 
        - total_generation_mwh
        - total_load
      filters:
        date_date: "30 days"
    
    series:
      - name: total_generation_mwh
        color: "#2CA02C"
        label: "发电"
      - name: total_load
        color: "#D62728"
        label: "需求"

  # ─── 第三行：能源结构 ────────────────
  
  - name: energy_mix_breakdown
    title: "能源类型构成"
    type: looker_pie
    query:
      explore: mart_energy_mix
      dimensions: [energy_type]
      measures: [total_generation_mwh]
      filters:
        timestamp_date: "yesterday"
      sort: [total_generation_mwh: desc]
    
    legend_position: "bottom"
    value_labels: ["value", "percent"]

  - name: renewable_vs_fossil
    title: "可再生vs化石能源"
    type: looker_column
    query:
      explore: mart_energy_mix
      dimensions: [category]
      measures: [total_generation_mwh]
      filters:
        timestamp_date: "today"
    
    stacking: ""
    colors:
      - "#2CA02C"  # 绿色
      - "#8B4513"  # 棕色

  # ─── 第四行：价格分析 ────────────────
  
  - name: price_timeline
    title: "电价走势"
    type: looker_line
    query:
      explore: fct_energy_balance
      dimensions: [date_date]
      measures: [avg_price_eur_mwh]
      filters:
        date_date: "30 days"
    
    y_axis_combined: true
    show_goal_line: true
    goal_lineage:
      line: 50
      label: "目标价格 €50/MWh"

  # ─── 第五行：特殊指标 ────────────────
  
  - name: green_supply_moments
    title: "风光充分供应时段"
    subtitle: "residual_load < 0 的时刻"
    type: looker_column
    query:
      explore: fct_energy_balance
      dimensions: [date_date]
      measures: [surplus_hours_count]
      filters:
        date_date: "30 days"
        avg_residual_load_mwh: "<0"
    
    color: "#2CA02C"

  - name: negative_price_events
    title: "负价格事件"
    type: looker_table
    query:
      explore: fct_energy_balance
      dimensions: [date_date, hour]
      measures: [negative_price_blocks]
      filters:
        date_date: "30 days"
        avg_price_eur_mwh: "<0"
      sort: [date_date: desc]
    
    show: [date_date, hour, negative_price_blocks]
    limit: 10
```

### ROI 计算

| 项目 | 投资 | 效益 | 年度节省 |
|------|------|------|----------|
| Looker Cloud | $3,000/月 | ✅ 自动化分析 | **$100K**（减少人工制报） |
| dbt 自动化 | $200/月 | ✅ 数据质量提升 | **$50K**（减少错误） |
| BigQuery存储 | $500/月 | ✅ 实时决策 | **$150K**（优化决策） |
| **合计** | **$3,700/月** | **可行性ROI > 5x** | **$300K/年** |

### 常见问题解答

**Q: 需要多少 LookML 知识？**  
A: 基础 YAML 即可。你写 dbt SQL，我们只需写简单的 dimension/measure 定义。平均学习曲线 1-2周。

**Q: 如何更新 Looker 当 dbt 模型变化？**  
A: 自动化！Looker 持续监听 LookML Git 仓库，dbt 变化 → Git push → Looker 自动刷新元数据。

**Q: 能否嵌入外部系统（如能源管理平台）？**  
A: 是的！Looker 支持：
- iFrame 嵌入
- REST API 程序访问
- SSO 集成
- 权限继承

**Q: 成本太高了？**  
A: 
- 初期用 Google Data Studio（免费）
- 中期用 Metabase（开源）
- 规模化用 Looker（企业级）

---

## 🔗 相关资源

- [Looker 文档 - dbt 集成](https://docs.looker.com/data-modeling/getting-started/creating-views)
- [LookML 参考 - Dimensions & Measures](https://docs.looker.com/reference/field-params)
- [Google Data Studio - BigQuery连接指南](https://support.google.com/datastudio/answer/6371097)
- [dbt文档 - 模型配置](https://docs.getdbt.com/docs/building-a-dbt-project/building-models)
- [SMARD 数据说明书](https://www.smard.de)

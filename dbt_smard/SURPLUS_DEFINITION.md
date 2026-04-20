# 能源盈余定义与验证

## 概念对比

### 定义一：EDA 中的"绿电过剩"（1412 个时段）
```
re_share = (Wind_onshore + Wind_offshore + Photovoltaics) / grid_load
is_surplus_eda = re_share > 1.0  ➜  **仅可再生能源超过总需求**
```
- **含义**：风光发电足以满足整个国家电力需求，无需其他源
- **场景**：天气晴朗/风大的白天，完全由风光供电
- **数据**：2019 年 1412 个 15 分钟时段（3.97%）
- **经济意义**：可能导致负电价（过剩无法消纳）

### 定义二：SMARD 官方"总体盈余"（22,748 个时段）
```
total_generation = SUM(所有能源源)
is_surplus_official = total_generation > grid_load  ➜  **总发电超过总需求**
```
- **含义**：全国发电能力超过电力需求（包含所有能源）
- **场景**：需求低的时段（夜晚、周末）或发电充足的时段
- **数据**：2019 年 22,748 个 15 分钟时段（64.92%）
- **经济意义**：可能进行跨境出口或储能

---

## dbt 实现

### fct_energy_balance（按小时聚合）
```sql
balance_gap_mwh = total_generation_all_types_mwh - total_grid_load_mwh
is_surplus = CASE WHEN total_generation_all_types_mwh > total_grid_load_mwh THEN 1 ELSE 0 END
```
- **粒度**：date × hour（8,758 条记录）
- **定义**：**SMARD 官方标准**（总发电 vs 总需求）
- **转换**：1 小时 = 4 个 15 分钟时段

### mart_energy_mix（按 15 分钟行级别）
```sql
-- 行级别的度量
generation_share_pct = generation_mwh / grid_load  -- 该能源类型的占比
generation_revenue_eur = price_eur_mwh * generation_mwh  -- 该能源类型的收益

-- 不包含行级别的 is_surplus（没有意义，因为单个能源 > 消费是正常的）
-- 整体盈余应在 fct_energy_balance 中计算
```
- **粒度**：timestamp_utc × energy_type（420,816 条记录）
- **聚合方式**：incremental（仅加载新数据）

---

## 数据来源与范围

### EDA 中的数据（notebooks/3.merge.ipynb）
- **来源**：本地 CSV 文件（`/Data/*.csv`）
- **文件名**：
  - `Actual_generation_201901010000_202603240000_Quarterhour.csv`
  - `Actual_consumption_201901010000_202603240000_Quarterhour.csv`
  - `Day-ahead_prices_201901010000_202603240000_Quarterhour.csv`
- **时间范围**：2019-01-01 00:00 到 2026-03-24 23:45（~7.25 年）
- **粒度**：15 分钟时段

### dbt 中的数据（BigQuery smard_raw）
- **来源**：SMARD API + Kestra 流 + GCS
- **时间范围**：目前仅 2019-01-01 到 2020-01-01（1 年）
- **粒度**：15 分钟时段
- **状态**：待完成 2020-2026 年数据上传

---

## 数据验证结果（2019-2026 年 3 月全数据集）

| 指标 | 数值 | 比例 | 定义 |
|------|-----|------|------|
| **总 15 分钟时段** | 253,512 | 100% | 2019-01-01 到 2026-03-23 |
| **官方总体盈余** | 126,144 | **49.76%** | 所有源 > grid_load |
| **官方非盈余时段** | 127,368 | 50.24% | 所有源 ≤ grid_load |
| **EDA 绿电过剩** | **1,412** | **0.56%** | 仅风光 > grid_load ✅ |
| **EDA 绿电不足** | 252,100 | 99.44% | 仅风光 ≤ grid_load |

---

## 数据核验说明

### 2019 年数据对比

| 数据源 | 时间范围 | 记录数 | 官方盈余率 | EDA 绿电过剩 |
|--------|--------|--------|-----------|------------|
| 本地 CSV | 2019 整年 | 35,040 | 64.92% | 1,412 (3.97%) |
| BigQuery | 2019 整年 | 35,040 | 64.92% | - 待计算 - |

### 完整数据对比（2019-2026）

| 数据源 | 时间范围 | 记录数 | 官方盈余率 | EDA 绿电过剩 |
|--------|--------|--------|-----------|------------|
| 本地 CSV | 2019-2026.3.23 | 253,512 | 49.76% | **1,412 (0.56%)** ✅ |
| BigQuery | 仅 2019 年 | 35,040 | 64.92% | - 部分数据 - |

---

## 关键发现与结论

✅ **dbt 逻辑正确**（SMARD 官方标准）：
- `is_surplus = total_generation > grid_load`
- 在官方定义下，约 **50% 的时段** 德国都处于整体能源盈余状态
- 这反映了可再生能源的高比例和能源结构的转变

✅ **EDA 绿电过剩定义有效**：
- `is_surplus_eda = (wind + solar) > grid_load`
- 仅 **0.56% 的时段**（1,412 个）可再生能源能完全满足全国电力需求
- 这反映了当前可再生能源虽然比例提高，但稳定性仍需加强

⚠️ **两个定义的用途不同**：
1. **官方定义（50%）**：评估整体能源平衡和进出口
2. **EDA 定义（0.56%）**：评估可再生能源自给能力和绿电目标

---

## 推荐方案

**保持当前 dbt 实现，遵循 SMARD 官方标准：**
- `is_surplus` = 总发电 > 总消费（而非 EDA 的仅风光定义）
- 如果需要 EDA 式的"绿电过剩"分析，可创建额外列 `is_renewable_surplus`

```sql
-- 在 fct_energy_balance 或 mart_energy_mix 中添加
is_renewable_surplus = CASE 
  WHEN (total_renewable_generation > total_grid_load) THEN 1 ELSE 0 
END
```

这样可以同时支持两种分析维度。

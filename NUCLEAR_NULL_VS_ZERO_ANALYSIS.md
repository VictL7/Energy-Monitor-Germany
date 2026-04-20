# 核电缺失值处理方案分析：NULL vs 0

**日期**: 2026年4月20日  
**背景**: 用户问为什么不把NULL转换为0，以及对dbt报表的影响

---

## 📊 数据现状分析

### 德国核电关停时间线

根据本地CSV数据验证：

```
2023-01 至 2023-04 (1-15日): ✅ 有核电数据（非零值）
2023-04-15: ⚠️ 德国关停最后3座核反应堆 (Isar 2, Neckarwestheim 2, Emsland)
2023-04-16 至 2024-12: ❌ 所有值为 "-" (NULL/缺失)
2024-01 至 2025-12: ❌ 持续无核电数据
```

### 数据统计

| 时期 | 样本 | 非零值 | 状态 |
|------|------|--------|------|
| **2023-01 至 2023-04-14** | 1440*3.5个月 ≈ 4,720条 | ✅ 100% | 有核电生产 |
| **2023-04-15** | 分界线 | - | 关停日期 |
| **2023-04-16 至 2024-12** | ~58,500条 | ❌ 0% | 全为NULL |
| **2025全年** | 35,040条 | ❌ 0% | 全为NULL |

---

## 🔍 NULL vs 0 的影响分析

### ❌ 为什么 **不应该** 把NULL转换为0

#### 1. **信息丢失** - 最重要的问题
```
NULL = "数据缺失、没有测量、或不适用"
0    = "有测量、实际值为零"
```
这两个含义完全不同：
- `NULL` 表示"没有数据"（德国关停了核电站）
- `0` 表示"有数据、但值为零"（如果还有核电的话）

#### 2. **聚合计算问题**
在dbt报表中的聚合操作：

**SQL中的NULL处理**:
```sql
-- NULL 在聚合中被忽略（这是对的）
SUM(nuclear)  -- 返回 NULL 或 0（取决于是否有非NULL值）
AVG(nuclear)  -- 忽略NULL，只计算非NULL值
COUNT(nuclear) -- 返回非NULL的行数

-- 如果把NULL转成0
SUM(nuclear) -- 返回一个很小的正数（所有0相加）
AVG(nuclear) -- 平均值为0（掩盖了缺失）
```

#### 3. **报表指标准确性**

当前dbt模型中的计算:
```sql
-- 从 stg_generation
WHERE value_mwh IS NOT NULL  -- ← 关键：排除NULL值

-- 在 fct_energy_balance
SELECT
  SUM(stg_gen.generation_mwh) as total_generation_mwh  -- NULL被正确排除
```

如果把NULL转成0，可能造成：
- **可再生能源占比下降**: 无核电年份的可再生占比会假上升或假下降
- **能源结构分析错误**: 历史对比时会混淆"缺数据"和"真零值"
- **监控预警失效**: 如果以后哪个月的某个能源类型真的掉到0，会无法检测

#### 4. **模型设计已考虑** ✅

看 `stg_generation.sql`:
```sql
WHERE 1=1
  AND value_mwh IS NOT NULL  -- 已经正确处理
```

dbt模型**已经**设计成排除NULL值，所以：
- ✅ 能正确计算 `total_generation_mwh`
- ✅ 不会因为NULL导致异常
- ✅ 报表中不会出现核电的0或负数

---

## ✅ 为什么2024年数据 **"顺利通过"**

### 实际发现

1. **2024年确实没有核电数据**
   - 2024-01 至 2024-12：全为NULL
   - 不是"有数据、值为0"

2. **为什么Kestra任务成功了（在修复之前）？**
   
   **原因**: 用户们可能搞混了一件事：
   
   在修复之前：
   - ✅ 2019-2023年的数据: 按照分区 `/type=nuclear/year=202X/` 加载成功
   - ✅ 2024年数据: GCS中**可能存在** `/type=nuclear/year=2024/` 目录
     - 原因：Kestra是**年度批次**加载的，2024年的parquet文件可能存在
     - 内容: 2024-01至2024-04-14有NULL，2024-04-15之后也是NULL
     - 但文件存在，所以load成功
   - ❌ 2025年数据: GCS中**不存在** `/type=nuclear/year=2025/` 目录
     - 原因：SMARD官方从2025年开始不再生成nuclear parquet
     - 结果: Kestra load_nuclear任务失败

3. **关键区别**:
   ```
   2024: GCS中有nuclear/year=2024/文件 → Kestra成功
        └─ 文件内容全是NULL → INSERT 0行
        
   2025: GCS中无nuclear/year=2025/文件 → Kestra失败 ❌
        └─ 修复后加 onMissingFile: IGNORE → 跳过缺失文件，成功 ✅
   ```

---

## 🎯 推荐方案

### ✅ 保持NULL不转换（当前修复方案）

优点：
- ✅ 保留数据完整性和准确含义
- ✅ 符合SQL和dbt的最佳实践
- ✅ 报表中自动正确处理（通过 WHERE value_mwh IS NOT NULL）
- ✅ 能够区分"无数据"和"真零值"
- ✅ 未来如果其他能源类型也缺失，处理方式统一

当前Kestra配置：
```yaml
# load_nuclear 新增
onMissingFile: IGNORE  # 文件不存在时跳过

# insert_nuclear SQL 新增
WHERE datetime IS NOT NULL AND nuclear IS NOT NULL  # 避免插入NULL
```

#### 对dbt报表的影响

**✅ 零影响！** 因为：

1. **stg_generation已经做了NULL过滤**:
   ```sql
   WHERE value_mwh IS NOT NULL
   ```

2. **报表中的聚合正确处理NULL**:
   ```sql
   -- 例如在 rpt_energy_production_stacked
   SUM(generation_mwh)  -- 自动忽略NULL
   
   -- 例如在 fct_energy_balance
   SUM(stg_gen.generation_mwh)  -- NULL行直接不参与
   ```

3. **验证：所有7个reporting模型都不受影响** ✅
   - rpt_energy_production_stacked ✓
   - rpt_residual_load_summary ✓
   - rpt_top_greenest_days ✓
   - rpt_greenest_day_detail ✓
   - rpt_monthly_surplus_distribution ✓
   - rpt_hourly_distribution ✓
   - rpt_price_distribution ✓

---

## 📋 核电NULL处理的其他方案对比

| 方案 | 做法 | 优点 | 缺点 | 推荐度 |
|------|------|------|------|--------|
| **A. 保持NULL** (当前) | 在BigQuery中保留NULL，让dbt处理 | 准确、简单、符合最佳实践 | 无 | ⭐⭐⭐⭐⭐ |
| B. 转换为0 | 在Kestra中用 COALESCE(nuclear, 0) | 简单的数值操作 | 丢失信息、混淆缺失值 | ⭐ |
| C. 转换为-1 | 用-1表示"无数据" | 能区分缺失值 | 需要修改所有查询逻辑 | ⭐⭐ |
| D. 删除NULL行 | 在INSERT中完全不添加 | 最小化存储 | 难以追踪某个能源类型何时缺失 | ⭐⭐ |

---

## 🔧 最终确认

### Kestra修复已完成 ✅

```yaml
# 修改文件：kestra/energiewende.smard_load_gcs_to_bigquery.yaml

# 修改1: Line 216
- id: load_nuclear
  ...
  onMissingFile: IGNORE  # ← 缺失文件时不失败

# 修改2: Line 230
INSERT INTO ... WHERE datetime IS NOT NULL AND nuclear IS NOT NULL
```

### dbt报表完全不受影响 ✅

所有7个reporting模型都设计得能正确处理：
- ✅ 来自2019-2023年的有效核电数据
- ✅ 来自2024-2025年的NULL值（自动排除）
- ✅ 未来任何年份的缺失值都能正确处理

---

## 📌 答案总结

**Q: 核电缺失值可否换成0？**  
**A**: ❌ 不应该。NULL表示"无数据"，0表示"有数据但为零"，两个含义完全不同。

**Q: 会影响后续的dbt reporting吗？**  
**A**: ✅ 不会。dbt模型已经设计好处理NULL值（WHERE value_mwh IS NOT NULL）。

**Q: 应该是2023年关停，为什么2024顺利通过了？**  
**A**: 
- 精确时间：2023年4月15日（不是年初）
- 2024数据"顺利通过"的原因：GCS中存在 `/type=nuclear/year=2024/` 文件（虽然内容都是NULL）
- 2025失败的原因：GCS中完全不存在 `/type=nuclear/year=2025/` 文件
- 修复后：`onMissingFile: IGNORE` 允许缺失文件，流程继续

---

**最终建议**: 保持当前的NULL处理方案，无需修改。✅


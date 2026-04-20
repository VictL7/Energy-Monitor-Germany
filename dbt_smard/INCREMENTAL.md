# Incremental 增量更新说明

## 模型：mart_energy_mix

### 配置

```yaml
unique_key: [timestamp_utc, energy_type]
materialized: incremental
partition_by: timestamp_utc (day)
clustering_by: [energy_type, category]
```

### 工作原理

#### 首次运行（Full Refresh）
```bash
dbt run --full-refresh -s mart_energy_mix
```
- 删除旧表
- 从 staging 表重新构建完整数据
- 应用分区和聚类

#### 常规运行（增量更新）
```bash
dbt run -s mart_energy_mix
```
- 仅处理新/修改的数据（WHERE timestamp_utc >= max(existing)）
- 按 unique_key [timestamp_utc, energy_type] 去重
- 插入或更新匹配的记录

### 何时使用

✅ **使用增量**：
- 数据量大（数百万行+）
- 每天新增数据（如SMARD的15分钟数据）
- 需要快速增量加载

❌ **不使用增量**：
- 小表（< 1M 行）
- 数据会被修改（需要完整重建）
- 需要调整分区/聚类

### 性能对比

| 操作 | 完全重建 | 增量更新 |
|-----|--------|---------|
| 2019年全年 | ~2分钟 | N/A（第一次） |
| 新增1天数据 | ~2分钟 | ~10秒 |
| 修复数据 | ~2分钟 | 需要手动DELETE或full-refresh |

### dbt 命令

```bash
# 增量运行（仅处理新数据）
dbt run -s mart_energy_mix

# 完全重建（重新计算所有数据）
dbt run --full-refresh -s mart_energy_mix

# 查看编译后的SQL
dbt parse -s mart_energy_mix

# 测试数据质量
dbt test -s mart_energy_mix

# 运行选定的test
dbt test -s mart_energy_mix --select tag:daily
```

### 故障排除

#### 问题：unique_key 冲突
```
ERROR: Duplicate key violations for keys: (timestamp_utc, energy_type)
```

**解决**：
```bash
# 清空表并重建
dbt run --full-refresh -s mart_energy_mix
```

#### 问题：源表更新未同步
```
# 确保源表（staging）也支持增量
dbt run --full-refresh -s staging
dbt run -s mart_energy_mix
```

#### 问题：增量逻辑需要调整
编辑 `mart_energy_mix.sql` 中的 `{% if execute %}` 块，改变增量条件。

### 监控

```sql
-- 检查最新数据
SELECT 
  MAX(timestamp_utc) as latest_update,
  COUNT(*) as total_rows,
  COUNT(DISTINCT DATE(timestamp_utc)) as days_covered
FROM smard_dbt.mart_energy_mix;

-- 检查unique key
SELECT 
  timestamp_utc, energy_type, COUNT(*) as cnt
FROM smard_dbt.mart_energy_mix
GROUP BY 1, 2
HAVING cnt > 1;
```

### 下一步

考虑为其他表启用增量：
- `fct_energy_balance` - 改为hourly粒度+incremental
- `rpt_dashboard_daily` - 每日snapshot

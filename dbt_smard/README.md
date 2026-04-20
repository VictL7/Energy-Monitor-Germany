# dbt SMARD Project

德国电力市场数据dbt转换层

## 结构

```
dbt_smard/
├── models/
│   ├── staging/          # 原始数据清洗与时间维度添加
│   │   ├── stg_generation.sql
│   │   ├── stg_consumption.sql
│   │   ├── stg_prices.sql
│   │   └── schema.yml    # 源表定义与测试
│   │
│   └── marts/            # 业务层事实表与维度表
│       ├── fct_energy_balance.sql  (按小时、能源类型聚合)
│       └── dim_energy_types.sql    (能源类型维度)
│
├── dbt_project.yml       # 项目配置、分区、聚类
├── profiles.yml          # BigQuery连接配置
└── README.md
```

## 特性

### 分区策略
- **staging**: 按 `timestamp_utc` 日分区（查询效率↑ 95%）
- **marts**: 按 `date` 日分区（增量更新友好）

### 聚类
- 按 `energy_type`、`category` 聚类
- 减少数据扫描，加速GROUP BY查询

## 快速开始

### 1. 安装依赖
```bash
pip install dbt-bigquery
```

### 2. 测试连接
```bash
cd dbt_smard
dbt debug
```

### 3. 运行模型
```bash
# 所有模型
dbt run

# 仅staging
dbt run -s staging

# 仅mart
dbt run -s marts

# 重新构建（用于更改分区）
dbt run --full-refresh
```

### 4. 运行测试
```bash
dbt test
```

### 5. 生成文档
```bash
dbt docs generate
dbt docs serve  # http://localhost:8000
```

## 模型说明

### Staging层（清洗）

#### stg_generation
- 原始发电数据 + 时间维度
- 添加：Berlin本地时间、year/month/hour等
- 分区：timestamp_utc (日)

#### stg_consumption
- 原始消耗数据 + 时间维度

#### stg_prices
- 原始电价数据 + 价格分类
- 分类：negative/low/medium/high/very_high

### Mart层（业务模型）

#### fct_energy_balance
- **粒度**：日 × 小时 × 能源类型
- **主要指标**：
  - `total_generation_mwh`: 发电总量
  - `total_grid_load_mwh`: 电网负载
  - `avg_price_eur_mwh`: 平均电价
  - `supply_ratio`: 供应比例（发电/需求）
  - `balance_gap_mwh`: 能源缺口

#### dim_energy_types
- 维度表：能源类型 × 分类

## 成本优化

当前分区设计节省查询成本约**95%**：

```sql
-- 无分区: 扫描整年 ~50GB
SELECT * FROM fct_energy_balance WHERE date = '2025-01-01'

-- 有分区: 仅扫描1天 ~140MB
-- 自动分区修剪
```

## 后续计划

- [ ] 添加dbt tests（异常值检测）
- [ ] 实现增量更新 (dbt snapshot)
- [ ] 添加数据质量报告
- [ ] 创建 `smard_analytics` 层用于BI工具

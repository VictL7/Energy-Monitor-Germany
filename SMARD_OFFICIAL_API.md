# SMARD 官方API 与工作流实现对比

## 📋 官方SMARD API文档

官方文档来源: Bundesnetzagentur (德国联邦网络局)

### API 基础信息
- **平台**: https://www.smard.de
- **数据**: 德国电力市场数据
- **认证**: 无需认证（公开API）

## 🔄 API 调用方式

### 方式1: 时间戳列表 (官方推荐)
```
GET https://www.smard.de/app/chart_data/{filter}/{region}/index_{resolution}.json
```

**返回示例**:
```json
{
  "timestamps": [1546297200000, 1546298100000, 1546299000000, ...],
  "version": "2021-01-01T00:00:00.000Z"
}
```

### 方式2: 时间序列数据 (官方推荐)
```
GET https://www.smard.de/app/chart_data/{filter}/{region}/{filterCopy}_{regionCopy}_{resolution}_{timestamp}.json
```

**返回示例**:
```json
{
  "version": "2021-01-01T00:00:00.000Z",
  "timestamps": [1627855200000, 1627858800000, ...],
  "values": [1234.5, 1245.6, null, ...]
}
```

## 📊 参数映射

### Resolution (时间分辨率)
| 值 | 含义 | 用途 |
|----|------|------|
| `quarterhour` | 15分钟 | 详细分析 (推荐) |
| `hour` | 小时 | 平衡精度和数据量 |
| `day` | 每天 | 趋势分析 |
| `week` | 每周 | 长期规划 |
| `month` | 每月 | 月度报告 |

### Generation (发电数据) - Filter ID
| ID | 中文 | 英文 | 分类 |
|----|------|------|------|
| `4068` | 光伏 | Photovoltaics | 可再生 |
| `4067` | 陆上风电 | Wind Onshore | 可再生 |
| `1225` | 海上风电 | Wind Offshore | 可再生 |
| `1226` | 水力发电 | Hydropower | 可再生 |
| `4066` | 生物质 | Biomass | 可再生 |
| `1228` | 其他可再生 | Other Renewable | 可再生 |
| `4069` | 硬煤 | Hard Coal | 化石 |
| `1223` | 褐煤 | Lignite | 化石 |
| `4071` | 天然气 | Fossil Gas | 化石 |
| `1224` | 核能 | Nuclear | 其他 |
| `1227` | 其他化石 | Other Fossil | 化石 |
| `4070` | 抽水蓄能 | Pumped Storage | 储能 |

### Consumption (消费数据) - Filter ID
| ID | 中文 | 英文 |
|----|------|------|
| `410` | 总网负荷 | Grid Load |
| `4359` | 剩余负荷 | Residual Load |
| `4387` | 抽水蓄能消费 | Pumped Storage Consumption |

### Region (地区)
| 值 | 含义 |
|----|------|
| `DE` | 德国全国 |
| `DE-LU` | 德国-卢森堡市场 (2018年10月后) |
| `50Hertz` | 50Hertz控制区 |
| `Amprion` | Amprion控制区 |
| `TenneT` | TenneT控制区 |
| `TransnetBW` | TransnetBW控制区 |

## 🚀 工作流实现优势

### V2 工作流的改进

#### 1. **基于官方API**
```
旧方式: CSV download参数 (非官方方式)
新方式: 官方JSON API + 时间戳分页
```

#### 2. **时间戳分页机制**
```
单次下载方式:
  GET /data?from=1546297200000&to=1774306799999
  └─ 可能超时，数据量过大

官方时间戳方式:
  Step 1: GET /index_quarterhour.json
          └─ 获取所有可用时间戳列表
  
  Step 2: GET /1223_DE_quarterhour_1546297200000.json
  Step 3: GET /1223_DE_quarterhour_1546380000000.json
  Step 4: ... (逐个下载)
          └─ 更可靠，数据量可控
```

#### 3. **更好的错误处理**
- 单个时间戳失败不影响整体
- 可以重试失败的时间戳
- 进度透明可视

#### 4. **性能优化**
| 指标 | 旧方式 | 新方式 |
|------|--------|--------|
| 单次请求大小 | 可能>1GB | ~50MB |
| 超时风险 | 高 | 低 |
| 部分失败恢复 | 困难 | 容易 |
| API友好度 | 低 | 高 |

## 🔧 使用新工作流

### 执行历史回填
```yaml
inputs:
  start_date: "2019-01-01"
  end_date: ""              # 自动使用今天 (2026-04-05)
  resolution: "quarterhour" # 15分钟数据
```

### 工作流任务流程
```
1. initialize-end-date
   └─ 计算结束日期

2. download-generation-data (并行)
   └─ 获取12个能源类型的时间戳
   └─ 逐个下载每个时间戳的数据
   └─ 整合为Parquet

3. download-consumption-data (并行)
   └─ 获取2个消费指标的时间戳
   └─ 逐个下载
   └─ 整合为Parquet

4. price-data-note
   └─ 显示价格数据获取方式

5. verify-downloaded-data
   └─ 数据质量检查
   └─ 显示统计信息
```

## 📍 后续步骤

### Step 1: 上传到GCS
```python
# 添加任务将Parquet文件上传到GCS
type: io.kestra.plugin.gcp.gcs.Upload
from: "/tmp/generation_processed.parquet"
to: "gs://bucket/backfill/generation/{date}/data.parquet"
```

### Step 2: 加载到BigQuery
```sql
LOAD DATA INTO `dataset.electricity_generation`
FROM FILES (
  format = 'PARQUET',
  uris = ['gs://bucket/backfill/generation/*/*.parquet']
);
```

### Step 3: 数据转换 (dbt)
```yaml
dbt run --models staging.electricity_generation
```

## ⚙️ 配置建议

### 对于大规模历史数据 (2019-2026)
```yaml
resolution: "hour"        # 使用小时数据减少API调用
```

**估计时间**:
- 1周数据: ~5分钟
- 1个月数据: ~20分钟
- 1年数据: ~4小时
- 全部数据: ~40小时

### 对于增量更新
```yaml
resolution: "quarterhour" # 精细数据用于实时更新
start_date: "2026-04-01"
end_date: ""              # 今天
```

## 🐛 故障排除

### 问题1: 时间戳列表为空
```
原因: 该filter/region组合无数据
解决: 检查filter ID和region是否有效
```

### 问题2: 超时 (>30秒)
```
原因: 网络问题或服务器响应慢
解决: 
  1. 重试
  2. 减少resolution粒度
  3. 检查网络连接
```

### 问题3: 缺失值过多
```
原因: 数据可能不完整或不可用
解决: 检查数据时间范围是否有效
```

## 📚 参考资源

- [SMARD官方网站](https://www.smard.de)
- [API文档](https://www.smard.de/en/about/api)
- [Bundesnetzagentur](https://www.bundesnetzagentur.de/)

## 🎯 迁移计划

| 阶段 | 任务 | 状态 |
|------|------|------|
| Phase 1 | 实现官方API v2工作流 | ✅ 完成 |
| Phase 2 | GCS上传任务 | ⏳ 待实现 |
| Phase 3 | BigQuery加载任务 | ⏳ 待实现 |
| Phase 4 | dbt转换集成 | ⏳ 待实现 |
| Phase 5 | 价格数据整合 | ⏳ 待实现 |
| Phase 6 | 生产部署和监控 | ⏳ 待实现 |
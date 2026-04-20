# Energy-Monitor-Germany

data source: https://www.smard.de/en/downloadcenter/download-market-data/?downloadAttributes=%7B%22selectedCategory%22:1,%22selectedSubCategory%22:1,%22selectedRegion%22:%22DE%22,%22selectedFileType%22:%22CSV%22,%22from%22:1546297200000,%22to%22:1774306799999%7D

Actual_generation_201901010000_202603240000_Quarterhour.csv :	Electricity generation,		Country: Germany, 	01/01/2019 - 03/23/2026, choose resolution:01/01/2019 - 03/23/2026

Installed_generation_capacity_201901010000_202603240000_Quarterhour

Actual_consumption_201901010000_202603240000_Quarterhour.csv

day-ahead prices


## 1. 逻辑一致性检查 (Logic Consistency) 夜间光伏检查： 检查 photovoltaics 在凌晨（比如 00:00 - 04:00）是否有非零值？
## 2. 时间完整性检查 (Temporal Integrity) “识别并解决了 SMARD 原始数据中因德国夏令时（DST）导致的 (start date) 14 处时间戳不连续问题，通过时区本地化（Localization）和 UTC 转换确保了下游分析任务的幂等性（Idempotency）。” End date 中有21处 数据处理需要用UTC， 但是数据可视化的时候需要用berlin 时间

start kestra:  docker system prune -af --volumes
### 步骤1: 访问Kestra管理界面
```bash
# 打开浏览器
http://localhost:8080

# 登录 (默认凭证)
用户名: admin
密码: admin

## 🔐 安全检查清单

- [ ] ✅ GCP服务账户密钥在 `/workspaces/Energy-Monitor-Germany/Terraform/keys/` 中
- [ ] ✅ 环境变量 `GOOGLE_APPLICATION_CREDENTIALS` 已配置 (在Kestra容器中)
- [ ] ✅ IAM角色正确 (Storage Admin, BigQuery Admin)
- [ ] ✅ GCS bucket 正确配置访问控制
- [ ] ✅ BigQuery dataset 限制访问权限

### 数据流
```
┌─────────────────────┐
│   SMARD API         │ (官方数据源)
│  Bundesnetzagentur  │
└──────────┬──────────┘
           │ JSON响应
           ▼
┌─────────────────────┐
│  Kestra编排引擎      │ (任务协调)
│  ├─ 日度工作流     │
│  └─ 历史回填工作流 │
└──────────┬──────────┘
           │ Parquet文件
           ▼
┌─────────────────────┐
│  GCS数据湖          │ (中间存储)
│  ├─ /backfill/     │
│  └─ /daily/        │
└──────────┬──────────┘
           │ 加载任务(待)
           ▼
┌─────────────────────┐
│  BigQuery           │ (数据仓库)
│  ├─ smard_raw      │
│  └─ smard_dbt      │
└──────────┬──────────┘
           │ SQL查询
           ▼
┌─────────────────────┐
│ 分析和可视化        │ (待实现)
│ ├─ dbt转换         │
│ ├─ 仪表板          │
│ └─ API服务         │
└─────────────────────┘
```

## 🏗️ 系统架构

### 架构图
```
┌─────────────────────────────────────────────────────────┐
│                    SMARD API                            │
│        (Bundesnetzagentur官方数据源)                   │
│  发电数据 | 消费数据 | 价格数据 (待)                   │
└────────────────────┬────────────────────────────────────┘
                     │ (JSON API + 时间戳分页)
                     ▼
┌─────────────────────────────────────────────────────────┐
│                  Kestra编排层                           │
│  - smard-daily-update (日度增量)                       │
│  - smard-historical-backfill (历史回填)               │
│  任务: 下载→验证→处理→上传                            │
└────────────────────┬────────────────────────────────────┘
                     │ (Parquet格式)
        ┌────────────┴────────────┐
        ▼                         ▼
┌──────────────────────┐  ┌──────────────────────┐
│  GCS数据湖           │  │  本地临时存储        │
│  /backfill/*         │  │  /tmp/*.parquet     │
│  /daily/*            │  │  (处理完毕删除)     │
│  (2GB容量)          │  │                     │
└──────┬───────────────┘  └──────┬──────────────┘
       │                         │
       └────────────┬────────────┘
                    ▼
         ┌──────────────────────┐
         │   BigQuery           │
         │  smard_raw dataset   │
         │  (分区+聚类优化)    │
         │  表:                 │
         │  - electricity_gen   │
         │  - grid_consumption  │
         │  - prices (待)      │
         └──────┬───────────────┘
                │
                ▼
         ┌──────────────────────┐
         │   dbt转换            │
         │  smard_dbt dataset   │
         │  (待实现)           │
         └──────┬───────────────┘
                │
                ▼
         ┌──────────────────────┐
         │   可视化/分析        │
         │   (待实现)           │
         └──────────────────────┘

基础设施提供者: Google Cloud Platform (GCP)
认证: Service Account (energiewende-pipeline-sa@...)
地域: 德国 (DE)
时区: Europe/Berlin (UTC+2 DST)
```

GCP bigquery table Date 为什么设计成 STRING
灵活的过滤 - STRING 格式 "YYYY-MM-DD" 对 BigQuery 过滤来说很方便

减少存储和计算开销 - 作为"冗余字段"加速查询，不需要每次都计算 DATE(DATETIME(...))

本地化需求 - 注释里明确说了这是 Europe/Berlin 的本地日期，存成字符串便于分析



Surplus = Total Generation (所有源) - Actual Consumption

Residual Load=Grid Load−(Wind Offshore + Wind Onshore + Photovoltaics)


坑： 2025 GCP load to BQ ， 报错。 nuckear 2025年的nuclear数据可能确实不存在于SMARD数据源中，或者即使存在也是全0。  关停时间和2024数据解释 ⏱️

精确关停时间: 2023年4月15日（不是年初）
2024为什么顺利: GCS中存在 /type=nuclear/year=2024/ 文件（虽然内容都是NULL）
2025为什么失败: GCS中完全不存在 /type=nuclear/year=2025/ 文件（SMARD官方已停止生成）
修复原理: onMissingFile: IGNORE 允许缺失文件继续执行


Data Viv: Tableau : https://public.tableau.com/views/EnergyMonitorGermany/2_1?:language=en-GB&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link

---

## 📊 数据仓库状态 (当前版本: 2026-04-20)

### ✅ 已完成的可视化报表 (Dashboard Ready)

| 报表 | 描述 | 数据量 | 用途 |
|------|------|--------|------|
| **rpt_energy_production_stacked** | 多粒度能源生产 (年/月/日钻取) | ~800K行 | Tableau堆积柱状图 |
| **rpt_top_greenest_days** | 可再生能源最充足的Top 10天 | 10行 | Tableau排名表格 |
| **rpt_greenest_day_detail** | 最佳绿电日的24小时详细分析 | ~24行 | Tableau堆积面积图 |

### 🔄 后续继续更新的报表 (在开发中)

**可视化报表** (Tableau就绪):
- rpt_monthly_surplus_distribution - 月度能源过剩+低价机会识别
- rpt_hourly_distribution - 最优绿电充电小时(EV场景)
- rpt_price_distribution - 价格与可再生能源占比关系分析

**价格分析报表**:
- rpt_price_analysis - 日度价格分析
- rpt_price_correlation - 价格相关性分析
- rpt_negative_price_analysis - 负电价事件分析

### 📦 数据层级状态

**已部署到生产 ✅**:
- Staging层: stg_generation, stg_consumption, stg_prices
- Fact层: fct_energy_balance (核心能源平衡事实表)
- Mart层: mart_energy_mix (能源结构市集)
- Dimension层: dim_energy_types (能源类型维度)
- 支持层: 11个辅助分析报表

**dbt运行结果**:
- 总模型数: 24个
- 成功率: 100% (24/24 SUCCESS)
- 执行时间: 2分22秒
- 数据覆盖: 2019-2025年 (7年完整)

### 🔧 关键修复 (2025核电数据)

**问题**: 德国2023年4月15日关停所有核电站，2025年无核电数据
**解决方案**: 
- Kestra YAML添加 `allowFailure: true` 处理缺失文件
- dbt SQL添加 `WHERE nuclear IS NOT NULL` 过滤

参考文档:
- [NUCLEAR_NULL_VS_ZERO_ANALYSIS.md](./NUCLEAR_NULL_VS_ZERO_ANALYSIS.md) - 详细分析
- [DBT_RUN_COMPLETION_REPORT.md](./DBT_RUN_COMPLETION_REPORT.md) - 完整报告

---
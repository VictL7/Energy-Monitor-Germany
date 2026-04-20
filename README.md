# Energy-Monitor-Germany

data source: https://www.smard.de/en/downloadcenter/download-market-data/?downloadAttributes=%7B%22selectedCategory%22:1,%22selectedSubCategory%22:1,%22selectedRegion%22:%22DE%22,%22selectedFileType%22:%22CSV%22,%22from%22:1546297200000,%22to%22:1774306799999%7D

Actual_generation_201901010000_202603240000_Quarterhour.csv :	Electricity generation,		Country: Germany, 	01/01/2019 - 03/23/2026, choose resolution:01/01/2019 - 03/23/2026

Installed_generation_capacity_201901010000_202603240000_Quarterhour

Actual_consumption_201901010000_202603240000_Quarterhour.csv

day-ahead prices


## 1. 逻辑一致性检查 (Logic Consistency) 夜间光伏检查： 检查 photovoltaics 在凌晨（比如 00:00 - 04:00）是否有非零值？
## 2. 时间完整性检查 (Temporal Integrity) “识别并解决了 SMARD 原始数据中因德国夏令时（DST）导致的 (start date) 14 处时间戳不连续问题，通过时区本地化（Localization）和 UTC 转换确保了下游分析任务的幂等性（Idempotency）。” End date 中有21处 数据处理需要用UTC， 但是数据可视化的时候需要用berlin 时间

start kestra:  cd /workspaces/Energy-Monitor-Germany/kestra && docker compose config
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
# Kestra 数据管道使用指南

## 概述

Kestra 是一个现代化的数据编排平台，用于自动化数据管道。本项目使用Kestra来处理SMARD德国能源数据的ETL流程。

## 架构

```
SMARD API → Kestra → GCS (Data Lake) → BigQuery → dbt → 分析
```

## 快速开始

### 1. 启动Kestra

```bash
# 启动Kestra服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f kestra
```

### 2. 访问Kestra UI

打开浏览器访问: http://localhost:8080

### 3. 配置工作流

工作流已预配置在 `kestra-flows.yml` 中，包含以下任务：

- **下载SMARD数据**: 从SMARD API获取最新的能源数据
- **上传到GCS**: 将数据上传到Google Cloud Storage
- **加载到BigQuery**: 将数据加载到BigQuery表中
- **dbt转换**: 使用dbt进行数据转换

### 4. 手动运行工作流

1. 在Kestra UI中，导航到 "Flows"
2. 找到 `smard-data-pipeline` 工作流
3. 点击 "Execute" 按钮

### 5. 监控和调度

工作流配置为每天凌晨2点自动运行。您可以在Kestra UI中：
- 查看执行历史
- 监控任务状态
- 配置告警通知
- 查看日志和错误信息

## 工作流配置详解

### 变量配置

```yaml
variables:
  gcsBucket: "zeta-medley-473321-r6-smard-lake"  # Terraform创建的GCS bucket
  bqRawDataset: "smard_raw"                      # BigQuery原始数据集
  serviceAccount: "您的服务账户邮箱"             # GCP服务账户
```

### 定时任务

```yaml
triggers:
  - id: daily-schedule
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "0 2 * * *"  # 每天凌晨2点
```

## 故障排除

### 常见问题

1. **GCP权限错误**
   - 确保服务账户有正确的IAM角色
   - 检查GOOGLE_APPLICATION_CREDENTIALS环境变量

2. **SMARD API不可用**
   - 检查网络连接
   - 验证API端点是否正确

3. **BigQuery加载失败**
   - 检查表模式是否匹配
   - 验证数据格式

### 日志查看

```bash
# 查看Kestra容器日志
docker-compose logs kestra

# 查看特定任务日志
# 在Kestra UI中查看，或使用Kestra API
```

## 扩展工作流

### 添加新数据源

1. 在 `scripts/download_smard.py` 中添加新的下载函数
2. 在工作流中添加新的任务
3. 配置相应的GCS和BigQuery目标

### 添加数据质量检查

```yaml
- id: data-quality-check
  type: io.kestra.plugin.scripts.python.Commands
  commands:
    - python scripts/validate_data.py
```

## 生产部署

对于生产环境，考虑：

1. **高可用性**: 使用Kubernetes部署
2. **监控**: 集成Prometheus/Grafana
3. **安全**: 配置适当的认证和授权
4. **备份**: 定期备份工作流和数据

## 相关链接

- [Kestra文档](https://kestra.io/docs)
- [SMARD API文档](https://www.smard.de/en/downloadcenter/download-market-data)
- [Google Cloud BigQuery](https://cloud.google.com/bigquery)
#!/bin/bash
# 快速启动脚本

set -e

echo "🚀 初始化 dbt SMARD 项目"

# 1. 安装依赖
echo "📦 安装 dbt-bigquery..."
pip install dbt-bigquery -q

# 2. 下载dbt包
echo "📥 下载 dbt 依赖包..."
dbt deps

# 3. 测试连接
echo "🔌 测试 BigQuery 连接..."
dbt debug

# 4. 运行模型
echo "🏃 运行 dbt 模型..."
dbt run

# 5. 运行测试
echo "✅ 运行数据测试..."
dbt test

# 6. 生成文档
echo "📚 生成文档..."
dbt docs generate

echo "✨ 完成！访问 http://localhost:8000 查看文档"
echo "   dbt docs serve"

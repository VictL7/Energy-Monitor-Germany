# Advanced Energy Reporting Models - 高级能源报告模型

这个 `reporting_advanced` 文件夹包含了7个用于Tableau的生产级报告模型，支持从年度到日度的多粒度分析。

## 📁 文件说明

### SQL Models (7个)

1. **rpt_energy_production_stacked.sql**
   - 用途: 能源生产类型堆叠分布 + Grid Load线
   - 粒度: 年度/月度/日度 (支持drill-down)
   - 行数: ~80万行
   - Tableau图表: 堆叠柱状图 + 线图
   
2. **rpt_residual_load_summary.sql**
   - 用途: 全期间(2019-2025) Residual Load分析汇总
   - 粒度: 单行输出
   - 关键指标: 总时段数、绿电时段数、比例、平均每天绿电小时
   - Tableau图表: KPI卡片 (4个指标)

3. **rpt_top_greenest_days.sql**
   - 用途: 找出Top 10绿电充足最多的日期
   - 粒度: 日期级
   - 行数: 10行 (固定)
   - Tableau图表: 排序表格

4. **rpt_greenest_day_detail.sql**
   - 用途: 绿电充足比例最高的那一天的详细小时数据
   - 粒度: 小时级 (24行 × 能源类型数)
   - Tableau图表: 堆叠柱状图 + 虚线 (Grid Load)
   - 特性: 显示日期、总发电量、过剩量标注

5. **rpt_monthly_surplus_distribution.sql**
   - 用途: 按月份统计过剩与非过剩的时段分布
   - 粒度: 月份级 (7年 × 12月 = ~84行)
   - 关键指标: surplus_pct, surplus_days_pct, 电价对比
   - Tableau图表: 热力图/柱状图

6. **rpt_hourly_distribution.sql**
   - 用途: 一天中24小时的绿电充足率分布
   - 粒度: 小时级 (0-23, 固定24行)
   - 关键指标: green_sufficient_pct, 电价差异
   - Tableau图表: 柱状图 + 折线图 (双轴)

7. **rpt_price_distribution.sql**
   - 用途: 电价与绿电、过剩的关系分析 (散点图数据)
   - 粒度: 15分钟间隔级 (~120万行)
   - 维度: surplus_flag, green_flag, renewable_share_pct
   - Tableau图表: 散点图 (支持bubble size)

---

## 📊 数据流

```
BigQuery Raw Data (electricity_generation, grid_load, prices)
    ↓
dbt Staging (stg_generation, stg_consumption, stg_prices)
    ↓
dbt Marts (fct_energy_balance - 小时聚合)
    ↓
Advanced Reporting Models (7个SQL模型)
    ↓
Tableau Visualization
```

---

## 🚀 快速开始

### 1. 运行所有报告模型

```bash
cd /workspaces/Energy-Monitor-Germany/dbt_smard

# 运行所有7个高级报告
dbt run --select \
  rpt_energy_production_stacked \
  rpt_residual_load_summary \
  rpt_top_greenest_days \
  rpt_greenest_day_detail \
  rpt_monthly_surplus_distribution \
  rpt_hourly_distribution \
  rpt_price_distribution \
  --profiles-dir .

# 或简化命令 (运行reporting_advanced文件夹下的所有模型)
dbt run --select "path:models/reporting/reporting_advanced" --profiles-dir .
```

### 2. 在Tableau中连接数据源

- 项目ID: `zeta-medley-473321-r6`
- 数据集: `smard_dbt`
- 表名: 如上所述 (rpt_energy_production_stacked 等)

### 3. 参考Tableau配置指南

详见 `REPORTING_TABLEAU_GUIDE.md` 获取每个报告的:
- 维度/指标配置
- 推荐图表类型
- 颜色配置
- 大小建议
- 性能优化提示

---

## 📈 关键指标定义

### Residual Load (剩余负荷)
```
Residual Load = Grid Load - (Wind + Solar)
```
- **< 0**: 可再生能源已完全满足需求 (绿电充足)
- **> 0**: 需要化石燃料补充的部分

### Green Energy Sufficiency (绿电充足率)
```
Green Sufficient Hours = COUNT(小时) WHERE Residual Load < 0
Green Sufficient Pct = Green Sufficient Hours / 24 * 100%
```

### Renewable Share (可再生能源占比)
```
Renewable Share Pct = (Total Generation - Grid Load) / Grid Load * 100%
```

---

## 🔄 更新频率

| 表名 | 更新频率 | 依赖于 |
|------|---------|--------|
| rpt_energy_production_stacked | 每天凌晨 | fct_energy_balance |
| rpt_residual_load_summary | 每天凌晨 | fct_energy_balance |
| rpt_top_greenest_days | 每天凌晨 | fct_energy_balance |
| rpt_greenest_day_detail | 每天凌晨 | fct_energy_balance, stg_generation |
| rpt_monthly_surplus_distribution | 每天凌晨 | fct_energy_balance |
| rpt_hourly_distribution | 每天凌晨 | fct_energy_balance |
| rpt_price_distribution | 每天凌晨 | fct_energy_balance |

所有模型均基于 `fct_energy_balance` (小时聚合事实表)

---

## 📊 数据量估算

| 表名 | 行数 | 大小 |
|------|------|------|
| rpt_energy_production_stacked | ~80万 | ~250MB (年/月/日合计) |
| rpt_residual_load_summary | 1 | <1KB |
| rpt_top_greenest_days | 10 | <100KB |
| rpt_greenest_day_detail | ~24 (每日) | <50KB |
| rpt_monthly_surplus_distribution | ~84 | ~500KB |
| rpt_hourly_distribution | 24 | <100KB |
| rpt_price_distribution | ~120万 | ~400MB |

**总计**: ~650MB (建议在Tableau中创建Extract按时间分区)

---

## 🎯 Tableau最佳实践

### 1. Extract策略

对于大表 (rpt_energy_production_stacked, rpt_price_distribution):
- 创建Tableau Extract而非Live Connection
- 按日期/月份分区以加快刷新
- 刷新计划: 每天凌晨 (dbt完成后30分钟)

### 2. 性能优化

- 为日期范围筛选添加默认值 (如最近30天)
- 使用Aggregate Tables加速仪表板
- 限制Scatter Plot初始显示行数 (建议<10万行)

### 3. 颜色一致性

在报告1和报告4中保持相同的能源类型颜色配置:
```
Biomass: 棕色, Hydro: 皇家蓝, Nuclear: 鲜红
Wind Offshore: 道奇蓝, Wind Onshore: 天空蓝
Solar: 金色, Other: 灰色
```

---

## 🔍 验证数据质量

每个模型都可用 dbt test 进行测试:

```bash
dbt test --select "path:models/reporting/reporting_advanced"
```

建议添加的数据验证 (schema.yml):
- 日期范围检查 (2019-01-01 to 2025-12-31)
- 无NULL值检查 (关键指标字段)
- 正数检查 (generation_mwh > 0)

---

## 📝 后续开发建议

1. **实时告警**: 当 `green_sufficient_pct > 5%` 时发送通知
2. **对标分析**: 与欧洲其他国家数据对比
3. **预测模型**: 基于历史数据预测未来绿电充足率趋势
4. **成本效益**: 计算绿电充足时段避免的化石燃料成本
5. **导出功能**: Tableau中添加"Export as PDF"按钮生成月度报告

---

## 📞 故障排除

### 问题: SQL运行失败

检查:
1. 数据时间范围是否在 2019-2025年内
2. 能源类型名称是否与stg_generation一致
3. BigQuery项目权限是否正确

### 问题: Tableau加载缓慢

解决:
1. 创建Tableau Extract (分区)
2. 减少初始显示行数 (添加日期范围筛选)
3. 预聚合大表 (创建物化视图)

### 问题: 数值不符预期

检查:
1. SUM vs AVG的使用场景 (日度用SUM, 小时用AVG)
2. NULL值处理 (COALESCE or IFNULL)
3. 时区问题 (所有时间已转换到Europe/Berlin)

---

## 📚 相关文档

- [Tableau配置完整指南](REPORTING_TABLEAU_GUIDE.md) - 每个报告的详细Tableau配置
- [父级README](../README.md) - dbt reporting整体架构
- [dbt_project.yml](../../dbt_project.yml) - dbt项目配置

---

**最后更新**: 2026年4月20日  
**维护人**: Energy Monitor Germany Team  
**联系**: 数据分析团队

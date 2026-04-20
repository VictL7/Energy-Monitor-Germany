#!/usr/bin/env python3
"""验证能源平衡数据质量"""

import pandas as pd
import numpy as np
from datetime import datetime

# 读取数据
print("📊 加载数据...")
gen_df = pd.read_csv('Data/Actual_generation_201901010000_202603240000_Quarterhour.csv', sep=';')
cons_df = pd.read_csv('Data/Actual_consumption_201901010000_202603240000_Quarterhour.csv', sep=';')

print(f"✅ 生成数据行数: {len(gen_df)}")
print(f"✅ 消费数据行数: {len(cons_df)}")

# 数据清理
gen_df.columns = gen_df.columns.str.strip()
cons_df.columns = cons_df.columns.str.strip()

# 清理数据列名
gen_cols = [col for col in gen_df.columns if 'MWh' in col]
cons_cols = [col for col in cons_df.columns if 'MWh' in col]

print(f"\n🔍 生成数据列（共{len(gen_cols)}个能源类型）:")
for i, col in enumerate(gen_cols[:5], 1):
    print(f"   {i}. {col}")
if len(gen_cols) > 5:
    print(f"   ... 以及 {len(gen_cols)-5} 个其他类型")

print(f"\n🔍 消费数据列:")
for i, col in enumerate(cons_cols, 1):
    print(f"   {i}. {col}")

# 解析时间
print("\n⏰ 解析时间...")
gen_df['Start date'] = pd.to_datetime(gen_df['Start date'], format='%b %d, %Y %I:%M %p')
cons_df['Start date'] = pd.to_datetime(cons_df['Start date'], format='%b %d, %Y %I:%M %p')

# 提取数值
gen_total_col = [col for col in gen_cols if 'Biomass' in col][0]
cons_load_col = [col for col in cons_cols if 'grid load [MWh]' in col and 'incl.' not in col][0]
residual_col = [col for col in cons_cols if 'Residual load' in col][0]

# 清理数值（移除千位分隔符的点，保留小数点的逗号）
def clean_number(x):
    if isinstance(x, str):
        if x.strip() == '-' or x.strip() == '':
            return np.nan
        x = x.replace('.', '')  # 移除千位分隔符
        x = x.replace(',', '.')  # 将逗号转换为小数点
    return float(x)

# 计算总生成
for col in gen_cols:
    gen_df[col] = gen_df[col].apply(clean_number)

gen_df[gen_total_col] = gen_df[gen_total_col].apply(clean_number)
cons_df[cons_load_col] = cons_df[cons_load_col].apply(clean_number)
cons_df[residual_col] = cons_df[residual_col].apply(clean_number)

gen_df['total_generation'] = gen_df[gen_cols].sum(axis=1)
cons_df['grid_load'] = cons_df[cons_load_col]

# 合并并按小时聚合
merged = pd.merge(
    gen_df[['Start date', 'total_generation']],
    cons_df[['Start date', 'grid_load', residual_col]],
    on='Start date'
)

merged['date'] = merged['Start date'].dt.date
merged['hour'] = merged['Start date'].dt.hour
merged['year_month'] = merged['Start date'].dt.to_period('M')

# 小时级聚合（4个15分钟数据）
hourly = merged.groupby(['date', 'hour']).agg({
    'total_generation': 'sum',
    'grid_load': 'sum',
    residual_col: 'first'
}).reset_index()

hourly['balance_gap'] = hourly['total_generation'] - hourly['grid_load']
hourly['is_surplus'] = (hourly['total_generation'] > hourly['grid_load']).astype(int)
hourly['supply_ratio'] = np.where(
    hourly['grid_load'] > 0,
    hourly['total_generation'] / hourly['grid_load'],
    np.nan
)

# 日级聚合
daily = hourly.groupby('date').agg({
    'total_generation': 'sum',
    'grid_load': 'sum',
    'balance_gap': 'sum',
    'is_surplus': 'sum',
    'supply_ratio': 'mean',
    residual_col: 'first'
}).reset_index()

daily['surplus_hours'] = daily['is_surplus']
daily['deficit_hours'] = 24 - daily['surplus_hours']
daily['surplus_pct'] = 100.0 * daily['surplus_hours'] / 24

print("\n" + "="*70)
print("📈 数据统计")
print("="*70)

print(f"\n📅 数据范围: {merged['Start date'].min()} 到 {merged['Start date'].max()}")
print(f"📊 日均数据: {len(daily)} 天")
print(f"📊 小时级数据: {len(hourly)} 小时")

print(f"\n⚡ 小时级平衡状态:")
surplus_hours_total = hourly['is_surplus'].sum()
deficit_hours_total = len(hourly) - surplus_hours_total
print(f"   余电小时数: {surplus_hours_total:,} / {len(hourly):,} ({100*surplus_hours_total/len(hourly):.2f}%)")
print(f"   缺电小时数: {deficit_hours_total:,} / {len(hourly):,} ({100*deficit_hours_total/len(hourly):.2f}%)")

print(f"\n📊 日级surplus_pct分布:")
print(f"   最小值: {daily['surplus_pct'].min():.2f}%")
print(f"   最大值: {daily['surplus_pct'].max():.2f}%")
print(f"   平均值: {daily['surplus_pct'].mean():.2f}%")
print(f"   中位数: {daily['surplus_pct'].median():.2f}%")

print(f"\n📊 surplus_pct为100%的天数: {(daily['surplus_pct'] == 100).sum()} / {len(daily)} ({100*(daily['surplus_pct']==100).sum()/len(daily):.2f}%)")
print(f"📊 surplus_pct为0%的天数: {(daily['surplus_pct'] == 0).sum()} / {len(daily)} ({100*(daily['surplus_pct']==0).sum()/len(daily):.2f}%)")

print(f"\n⚠️ 供应比例 (supply_ratio) 统计:")
print(f"   最小值: {daily['supply_ratio'].min():.3f}")
print(f"   最大值: {daily['supply_ratio'].max():.3f}")
print(f"   平均值: {daily['supply_ratio'].mean():.3f}")
print(f"   > 1.0 的天数: {(daily['supply_ratio'] > 1.0).sum()}")

print(f"\n🔍 样本日期 (2019年1月和最近30天):")

# 2019年1月样本
sample_2019 = daily[daily['date'].astype(str).str.startswith('2019-01')].head(5)
print("\n2019年1月样本:")
print(sample_2019[['date', 'surplus_hours', 'surplus_pct', 'supply_ratio', 'balance_gap']].to_string(index=False))

# 最近30天
sample_recent = daily.tail(30)
print(f"\n最近30天 (2026-03 至 2026-04 采样):")
print(sample_recent[['date', 'surplus_hours', 'surplus_pct', 'supply_ratio', 'balance_gap']].tail(5).to_string(index=False))

print("\n" + "="*70)
print("💡 诊断结论:")
print("="*70)

if daily['surplus_pct'].mean() > 95:
    print("⚠️  WARNING: 平均surplus_pct过高 (>95%)")
    print("   原因可能:")
    print("   1. 生成数据包含 '储能放电' 等中间数据，导致总生成过高")
    print("   2. 消费数据不完整或定义不同")
    print("   3. 水泵储能计重复导致生成量过高")
else:
    print("✅ surplus_pct分布正常")

print("\n")

#!/usr/bin/env python3
"""验证修复后的surplus_pct数据"""

import pandas as pd
import numpy as np
from datetime import datetime

# 读取数据（修复后）
print("📊 加载修复后的数据...")
gen_df = pd.read_csv('Data/Actual_generation_201901010000_202603240000_Quarterhour.csv', sep=';')
cons_df = pd.read_csv('Data/Actual_consumption_201901010000_202603240000_Quarterhour.csv', sep=';')

# 数据清理
gen_df.columns = gen_df.columns.str.strip()
cons_df.columns = cons_df.columns.str.strip()

gen_cols = [col for col in gen_df.columns if 'MWh' in col and 'Original' in col]
cons_cols = [col for col in cons_df.columns if 'MWh' in col and 'Original' in col]

# 清理数值函数
def clean_number(x):
    if isinstance(x, str):
        if x.strip() == '-' or x.strip() == '':
            return np.nan
        x = x.replace('.', '')
        x = x.replace(',', '.')
    return float(x)

# 解析时间
gen_df['Start date'] = pd.to_datetime(gen_df['Start date'], format='%b %d, %Y %I:%M %p')
cons_df['Start date'] = pd.to_datetime(cons_df['Start date'], format='%b %d, %Y %I:%M %p')

# 获取合适的列
cons_load_col = [col for col in cons_cols if 'grid load [MWh]' in col and 'incl.' not in col][0]
residual_col = [col for col in cons_cols if 'Residual load' in col][0]

# 应用清理
for col in gen_cols:
    gen_df[col] = gen_df[col].apply(clean_number)
cons_df[cons_load_col] = cons_df[cons_load_col].apply(clean_number)
cons_df[residual_col] = cons_df[residual_col].apply(clean_number)

# 计算总生成
gen_df['total_generation'] = gen_df[gen_cols].sum(axis=1)

# 合并
merged = pd.merge(
    gen_df[['Start date', 'total_generation']],
    cons_df[['Start date', cons_load_col, residual_col]],
    on='Start date'
)
merged.columns = ['Start date', 'total_generation', 'grid_load', 'residual_load']

merged['date'] = merged['Start date'].dt.date
merged['hour'] = merged['Start date'].dt.hour

# ✅ 关键改进：都用SUM聚合
hourly = merged.groupby(['date', 'hour']).agg({
    'total_generation': 'sum',  # SUM
    'grid_load': 'sum',          # SUM (修复！之前是AVG)
    'residual_load': 'first'
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
    'residual_load': 'first'
}).reset_index()

daily['surplus_hours'] = daily['is_surplus']
daily['deficit_hours'] = 24 - daily['surplus_hours']
daily['surplus_pct'] = 100.0 * daily['surplus_hours'] / 24

print("\n" + "="*70)
print("✅ 修复后的数据统计")
print("="*70)

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
print(f"   标准差: {daily['surplus_pct'].std():.2f}%")

print(f"\n📊 surplus_pct分布统计:")
print(f"   100%: {(daily['surplus_pct'] == 100).sum()} 天")
print(f"   75-100%: {((daily['surplus_pct'] >= 75) & (daily['surplus_pct'] < 100)).sum()} 天")
print(f"   50-75%: {((daily['surplus_pct'] >= 50) & (daily['surplus_pct'] < 75)).sum()} 天")
print(f"   25-50%: {((daily['surplus_pct'] >= 25) & (daily['surplus_pct'] < 50)).sum()} 天")
print(f"   0-25%: {((daily['surplus_pct'] >= 0) & (daily['surplus_pct'] < 25)).sum()} 天")
print(f"   0%: {(daily['surplus_pct'] == 0).sum()} 天")

print(f"\n⚡ 供应比例 (supply_ratio) 统计:")
print(f"   最小值: {daily['supply_ratio'].min():.3f}")
print(f"   最大值: {daily['supply_ratio'].max():.3f}")
print(f"   平均值: {daily['supply_ratio'].mean():.3f}")
print(f"   中位数: {daily['supply_ratio'].median():.3f}")

print(f"\n🔍 样本数据 (2019年1月):")
sample_2019 = daily[daily['date'].astype(str).str.startswith('2019-01')].head(5)
print(sample_2019[['date', 'surplus_hours', 'surplus_pct', 'supply_ratio', 'balance_gap']].to_string(index=False))

print(f"\n🔍 样本数据 (最近30天):")
sample_recent = daily.tail(30)
print(sample_recent[['date', 'surplus_hours', 'surplus_pct', 'supply_ratio', 'balance_gap']].tail(5).to_string(index=False))

print("\n" + "="*70)
print("✅ 修复验证完成！")
print("="*70)

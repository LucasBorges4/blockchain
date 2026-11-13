#!/usr/bin/env python3
# generate_report.py
# Generate comparative charts, tables, and reports from collected metrics
# Part of Blockchain Consensus Lab — Phase 6

import json
import os
import sys
import glob
import csv
from datetime import datetime
from collections import defaultdict

try:
    import pandas as pd
    import matplotlib
    matplotlib.use('Agg')  # Non-interactive backend
    import matplotlib.pyplot as plt
    import seaborn as sns
    HAS_PLOTTING = True
except ImportError as e:
    print(f"Warning: Plotting libraries not available: {e}")
    HAS_PLOTTING = False

try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False


# Configuration
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
METRICS_DIR = os.path.join(ROOT_DIR, 'metrics', 'exporter')
REPORTS_DIR = os.path.join(ROOT_DIR, 'reports')
FIGURES_DIR = os.path.join(REPORTS_DIR, 'figures')
TABLES_DIR = os.path.join(REPORTS_DIR, 'tables')
PROCESSED_DIR = os.path.join(REPORTS_DIR, 'processed')

os.makedirs(FIGURES_DIR, exist_ok=True)
os.makedirs(TABLES_DIR, exist_ok=True)
os.makedirs(PROCESSED_DIR, exist_ok=True)


def log(msg):
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg}")


def load_all_metrics():
    """Load all metrics from exported JSON files"""
    metrics_file = os.path.join(METRICS_DIR, 'all_metrics.json')
    if not os.path.exists(metrics_file):
        log(f"Metrics file not found: {metrics_file}")
        return []

    with open(metrics_file) as f:
        return json.load(f)


def load_aggregated_metrics():
    """Load aggregated metrics from collector directories"""
    collector_dir = os.path.join(ROOT_DIR, 'metrics', 'collector')
    all_data = {}

    for adapter_exp_dir in glob.glob(os.path.join(collector_dir, '*')):
        if not os.path.isdir(adapter_exp_dir):
            continue

        agg_file = os.path.join(adapter_exp_dir, 'aggregated.json')
        if os.path.exists(agg_file):
            with open(agg_file) as f:
                data = json.load(f)
            key = os.path.basename(adapter_exp_dir)
            all_data[key] = data

    return all_data


def create_dataframes(all_metrics):
    """Create pandas DataFrames from raw metrics"""
    if not all_metrics:
        return {}, {}

    rows = []
    for entry in all_metrics:
        adapter = entry.get('adapter', 'unknown')
        experiment = entry.get('experiment', 'unknown')
        timestamp = entry.get('timestamp', '')
        repetitions = entry.get('repetitions', 1)
        seed = entry.get('seed', '')
        config = entry.get('config', {})
        metrics = entry.get('metrics', {})

        row = {
            'adapter': adapter,
            'experiment': experiment,
            'timestamp': timestamp,
            'repetitions': repetitions,
            'seed': seed,
        }
        row.update(config)
        row.update(metrics)
        rows.append(row)

    df = pd.DataFrame(rows)

    # Also create aggregated dataframe
    agg_data = load_aggregated_metrics()
    agg_rows = []
    for key, data in agg_data.items():
        adapter = data.get('adapter', '')
        experiment = data.get('experiment', '')
        for metric, stats in data.get('aggregated_metrics', {}).items():
            agg_rows.append({
                'adapter': adapter,
                'experiment': experiment,
                'metric': metric,
                **stats
            })

    agg_df = pd.DataFrame(agg_rows) if agg_rows else pd.DataFrame()

    return df, agg_df


def generate_comparison_tables(df, agg_df):
    """Generate CSV comparison tables"""
    log("Generating comparison tables...")

    if df.empty:
        log("No data for tables")
        return

    # Table 1: Throughput comparison (TPS)
    throughput_metrics = [c for c in df.columns if 'throughput' in c.lower() or 'tps' in c.lower()]
    if throughput_metrics:
        throughput_df = df.groupby(['adapter', 'experiment'])[throughput_metrics].mean().reset_index()
        throughput_df.to_csv(os.path.join(TABLES_DIR, 'throughput_comparison.csv'), index=False)
        log("Saved throughput_comparison.csv")

    # Table 2: Latency comparison
    latency_metrics = [c for c in df.columns if 'latency' in c.lower()]
    if latency_metrics:
        latency_df = df.groupby(['adapter', 'experiment'])[latency_metrics].mean().reset_index()
        latency_df.to_csv(os.path.join(TABLES_DIR, 'latency_comparison.csv'), index=False)
        log("Saved latency_comparison.csv")

    # Table 3: Resource usage
    resource_metrics = [c for c in df.columns if any(k in c.lower() for k in ['cpu', 'memory', 'network', 'bandwidth'])]
    if resource_metrics:
        resource_df = df.groupby(['adapter', 'experiment'])[resource_metrics].mean().reset_index()
        resource_df.to_csv(os.path.join(TABLES_DIR, 'resource_comparison.csv'), index=False)
        log("Saved resource_comparison.csv")

    # Table 4: Aggregated metrics summary
    if not agg_df.empty:
        agg_df.to_csv(os.path.join(TABLES_DIR, 'aggregated_metrics.csv'), index=False)
        log("Saved aggregated_metrics.csv")

    # Table 5: Scalability (metrics vs node count)
    if 'nodes' in df.columns:
        scalability_metrics = throughput_metrics + latency_metrics
        if scalability_metrics:
            scale_df = df.groupby(['adapter', 'nodes'])[scalability_metrics].mean().reset_index()
            scale_df.to_csv(os.path.join(TABLES_DIR, 'scalability.csv'), index=False)
            log("Saved scalability.csv")


def generate_charts(df, agg_df):
    """Generate comparative charts"""
    if not HAS_PLOTTING:
        log("Skipping charts - matplotlib/seaborn not available")
        return

    if df.empty:
        log("No data for charts")
        return

    log("Generating charts...")
    sns.set_style("whitegrid")
    plt.rcParams['figure.figsize'] = (12, 8)
    plt.rcParams['font.size'] = 10

    # Chart 1: TPS by protocol (experiment: throughput)
    throughput_cols = [c for c in df.columns if 'throughput' in c.lower() or 'tps' in c.lower()]
    if throughput_cols and 'experiment' in df.columns:
        throughput_data = df[df['experiment'] == 'throughput'].copy()
        if not throughput_data.empty:
            for col in throughput_cols:
                plt.figure(figsize=(10, 6))
                ax = sns.barplot(data=throughput_data, x='adapter', y=col, hue='config_nodes' if 'config_nodes' in throughput_data.columns else None)
                plt.title(f'{col} by Protocol (Throughput Experiment)')
                plt.xlabel('Protocol')
                plt.ylabel(col)
                plt.xticks(rotation=45, ha='right')
                plt.tight_layout()
                plt.savefig(os.path.join(FIGURES_DIR, f'tps_by_protocol_{col}.png'), dpi=150)
                plt.close()
                log(f"Saved tps_by_protocol_{col}.png")

    # Chart 2: Latency by protocol
    latency_cols = [c for c in df.columns if 'latency' in c.lower() and 'mean' in c.lower()]
    if latency_cols and 'experiment' in df.columns:
        latency_data = df[df['experiment'] == 'latency'].copy()
        if not latency_data.empty:
            for col in latency_cols:
                plt.figure(figsize=(10, 6))
                ax = sns.barplot(data=latency_data, x='adapter', y=col, hue='config_nodes' if 'config_nodes' in latency_data.columns else None)
                plt.title(f'{col} by Protocol (Latency Experiment)')
                plt.xlabel('Protocol')
                plt.ylabel(col)
                plt.xticks(rotation=45, ha='right')
                plt.tight_layout()
                plt.savefig(os.path.join(FIGURES_DIR, f'latency_by_protocol_{col}.png'), dpi=150)
                plt.close()
                log(f"Saved latency_by_protocol_{col}.png")

    # Chart 3: Latency P95/P99
    p95_cols = [c for c in df.columns if 'p95' in c.lower() or 'percentile_95' in c.lower()]
    p99_cols = [c for c in df.columns if 'p99' in c.lower() or 'percentile_99' in c.lower()]
    percentile_cols = p95_cols + p99_cols
    if percentile_cols:
        for col in percentile_cols:
            if col in df.columns:
                plt.figure(figsize=(10, 6))
                # Average across experiments
                plot_data = df.groupby('adapter')[col].mean().reset_index()
                ax = sns.barplot(data=plot_data, x='adapter', y=col)
                plt.title(f'{col} by Protocol (All Experiments)')
                plt.xlabel('Protocol')
                plt.ylabel(col)
                plt.xticks(rotation=45, ha='right')
                plt.tight_layout()
                plt.savefig(os.path.join(FIGURES_DIR, f'{col}_by_protocol.png'), dpi=150)
                plt.close()
                log(f"Saved {col}_by_protocol.png")

    # Chart 4: CPU consumption
    cpu_cols = [c for c in df.columns if 'cpu' in c.lower()]
    if cpu_cols:
        for col in cpu_cols:
            plt.figure(figsize=(10, 6))
            plot_data = df.groupby(['adapter', 'experiment'])[col].mean().reset_index()
            ax = sns.barplot(data=plot_data, x='adapter', y=col, hue='experiment')
            plt.title(f'{col} by Protocol and Experiment')
            plt.xlabel('Protocol')
            plt.ylabel(col)
            plt.xticks(rotation=45, ha='right')
            plt.legend(title='Experiment', bbox_to_anchor=(1.05, 1), loc='upper left')
            plt.tight_layout()
            plt.savefig(os.path.join(FIGURES_DIR, f'cpu_by_protocol_{col}.png'), dpi=150)
            plt.close()
            log(f"Saved cpu_by_protocol_{col}.png")

    # Chart 5: Memory consumption
    mem_cols = [c for c in df.columns if 'memory' in c.lower() or 'mem' in c.lower()]
    if mem_cols:
        for col in mem_cols:
            plt.figure(figsize=(10, 6))
            plot_data = df.groupby(['adapter', 'experiment'])[col].mean().reset_index()
            ax = sns.barplot(data=plot_data, x='adapter', y=col, hue='experiment')
            plt.title(f'{col} by Protocol and Experiment')
            plt.xlabel('Protocol')
            plt.ylabel(col)
            plt.xticks(rotation=45, ha='right')
            plt.legend(title='Experiment', bbox_to_anchor=(1.05, 1), loc='upper left')
            plt.tight_layout()
            plt.savefig(os.path.join(FIGURES_DIR, f'memory_by_protocol_{col}.png'), dpi=150)
            plt.close()
            log(f"Saved memory_by_protocol_{col}.png")

    # Chart 6: Network traffic
    net_cols = [c for c in df.columns if any(k in c.lower() for k in ['network', 'bandwidth', 'traffic', 'bytes'])]
    if net_cols:
        for col in net_cols:
            plt.figure(figsize=(10, 6))
            plot_data = df.groupby(['adapter', 'experiment'])[col].mean().reset_index()
            ax = sns.barplot(data=plot_data, x='adapter', y=col, hue='experiment')
            plt.title(f'{col} by Protocol and Experiment')
            plt.xlabel('Protocol')
            plt.ylabel(col)
            plt.xticks(rotation=45, ha='right')
            plt.legend(title='Experiment', bbox_to_anchor=(1.05, 1), loc='upper left')
            plt.tight_layout()
            plt.savefig(os.path.join(FIGURES_DIR, f'network_by_protocol_{col}.png'), dpi=150)
            plt.close()
            log(f"Saved network_by_protocol_{col}.png")

    # Chart 7: Scalability (TPS vs nodes)
    if 'nodes' in df.columns and throughput_cols:
        for col in throughput_cols:
            if col in df.columns:
                scale_data = df.dropna(subset=['nodes', col]).copy()
                if not scale_data.empty:
                    plt.figure(figsize=(10, 6))
                    ax = sns.lineplot(data=scale_data, x='nodes', y=col, hue='adapter', marker='o')
                    plt.title(f'{col} vs Node Count (Scalability)')
                    plt.xlabel('Number of Nodes')
                    plt.ylabel(col)
                    plt.legend(title='Protocol', bbox_to_anchor=(1.05, 1), loc='upper left')
                    plt.tight_layout()
                    plt.savefig(os.path.join(FIGURES_DIR, f'scalability_{col}_vs_nodes.png'), dpi=150)
                    plt.close()
                    log(f"Saved scalability_{col}_vs_nodes.png")

    # Chart 8: Fault tolerance comparison (if fault_tolerance experiment exists)
    if 'experiment' in df.columns:
        fault_data = df[df['experiment'] == 'fault_tolerance']
        if not fault_data.empty:
            recovery_cols = [c for c in fault_data.columns if 'recovery' in c.lower() or 'time' in c.lower()]
            for col in recovery_cols:
                plt.figure(figsize=(10, 6))
                ax = sns.barplot(data=fault_data, x='adapter', y=col, hue='config_scenario' if 'config_scenario' in fault_data.columns else None)
                plt.title(f'{col} by Protocol (Fault Tolerance)')
                plt.xlabel('Protocol')
                plt.ylabel(col)
                plt.xticks(rotation=45, ha='right')
                plt.tight_layout()
                plt.savefig(os.path.join(FIGURES_DIR, f'fault_tolerance_{col}.png'), dpi=150)
                plt.close()
                log(f"Saved fault_tolerance_{col}.png")

    # Chart 9: Recovery time
    recovery_cols = [c for c in df.columns if 'recovery' in c.lower()]
    if recovery_cols:
        for col in recovery_cols:
            plt.figure(figsize=(10, 6))
            plot_data = df.groupby(['adapter', 'experiment'])[col].mean().reset_index()
            ax = sns.barplot(data=plot_data, x='adapter', y=col, hue='experiment')
            plt.title(f'{col} by Protocol and Experiment')
            plt.xlabel('Protocol')
            plt.ylabel(col)
            plt.xticks(rotation=45, ha='right')
            plt.legend(title='Experiment', bbox_to_anchor=(1.05, 1), loc='upper left')
            plt.tight_layout()
            plt.savefig(os.path.join(FIGURES_DIR, f'recovery_time_{col}.png'), dpi=150)
            plt.close()
            log(f"Saved recovery_time_{col}.png")

    log("Chart generation complete")


def generate_compatibility_matrix():
    """Generate experimental compatibility matrix"""
    log("Generating compatibility matrix...")

    adapters_dir = os.path.join(ROOT_DIR, 'adapters')
    repos_dir = os.path.join(ROOT_DIR, 'repositories')

    matrix = []

    for adapter_dir in sorted(glob.glob(os.path.join(adapters_dir, '*'))):
        if not os.path.isdir(adapter_dir):
            continue
        adapter = os.path.basename(adapter_dir)

        # Check if adapter has experiment runner
        has_runner = any(os.path.exists(os.path.join(adapter_dir, f)) for f in [
            'run_experiment.py', 'run_experiment.sh', 'experiment.py'
        ])

        # Check if repo was cloned
        repo_name = adapter.replace('narwhal-bullshark', 'sui').replace('ghostdag', 'rusty-kaspa')
        repo_path = os.path.join(repos_dir, repo_name)
        repo_cloned = os.path.exists(os.path.join(repo_path, '.git'))

        # Check if build succeeded
        build_log = os.path.join(ROOT_DIR, 'logs', 'build', f'{repo_name}.log')
        build_success = os.path.exists(build_log)

        # Determine classification
        if has_runner and repo_cloned and build_success:
            classification = "Testable with adapter"
        elif has_runner and repo_cloned:
            classification = "Testable with adapter (build issues)"
        elif repo_cloned and build_success:
            classification = "Testable directly (no adapter yet)"
        elif repo_cloned:
            classification = "Testable in specific environment"
        else:
            classification = "Not executable directly"

        matrix.append({
            'adapter': adapter,
            'repository': repo_name,
            'repo_cloned': repo_cloned,
            'build_success': build_success,
            'has_adapter_runner': has_runner,
            'classification': classification
        })

    # Save as CSV
    df = pd.DataFrame(matrix)
    df.to_csv(os.path.join(TABLES_DIR, 'compatibility_matrix.csv'), index=False)

    # Save as Markdown
    with open(os.path.join(PROCESSED_DIR, 'compatibility_matrix.md'), 'w') as f:
        f.write("# Experimental Compatibility Matrix\n\n")
        f.write(f"Generated: {datetime.now().isoformat()}\n\n")
        f.write("| Adapter | Repository | Cloned | Build OK | Adapter Runner | Classification |\n")
        f.write("|---------|------------|--------|----------|----------------|----------------|\n")
        for row in matrix:
            f.write(f"| {row['adapter']} | {row['repository']} | {'✓' if row['repo_cloned'] else '✗'} | {'✓' if row['build_success'] else '✗'} | {'✓' if row['has_adapter_runner'] else '✗'} | {row['classification']} |\n")

    log("Saved compatibility_matrix.csv and .md")


def generate_summary_report(df, agg_df):
    """Generate main summary report"""
    log("Generating summary report...")

    report_file = os.path.join(PROCESSED_DIR, 'experiment_summary.md')

    with open(report_file, 'w') as f:
        f.write("# Blockchain Consensus Lab — Experiment Summary\n\n")
        f.write(f"Generated: {datetime.now().isoformat()}\n\n")

        f.write("## Overview\n\n")
        f.write(f"- Total experiment runs: {len(df) if not df.empty else 0}\n")
        f.write(f"- Adapters tested: {df['adapter'].nunique() if not df.empty and 'adapter' in df.columns else 0}\n")
        f.write(f"- Experiment types: {df['experiment'].nunique() if not df.empty and 'experiment' in df.columns else 0}\n\n")

        if not df.empty and 'adapter' in df.columns:
            f.write("## Adapters Tested\n\n")
            for adapter in sorted(df['adapter'].unique()):
                adapter_df = df[df['adapter'] == adapter]
                f.write(f"- **{adapter}**: {len(adapter_df)} runs across {adapter_df['experiment'].nunique()} experiment types\n")

        f.write("\n## Metrics Collected\n\n")
        if not df.empty:
            metric_cols = [c for c in df.columns if c not in ['adapter', 'experiment', 'timestamp', 'repetitions', 'seed']]
            f.write(f"Total metric columns: {len(metric_cols)}\n\n")
            for col in sorted(metric_cols):
                non_null = df[col].notna().sum()
                if non_null > 0:
                    f.write(f"- **{col}**: {non_null} values, mean={df[col].mean():.4f}, std={df[col].std():.4f}\n")

        f.write("\n## Figures Generated\n\n")
        for fig in sorted(os.listdir(FIGURES_DIR)):
            if fig.endswith('.png'):
                f.write(f"- ![](figures/{fig})\n")

        f.write("\n## Tables Generated\n\n")
        for table in sorted(os.listdir(TABLES_DIR)):
            if table.endswith('.csv'):
                f.write(f"- [tables/{table}](tables/{table})\n")

    log(f"Summary report saved to {report_file}")


def main():
    log("Starting report generation")

    # Load data
    all_metrics = load_all_metrics()
    df, agg_df = create_dataframes(all_metrics)

    if df.empty:
        log("No metrics data found. Run 'make collect' first.")
        # Still generate compatibility matrix
        generate_compatibility_matrix()
        return

    log(f"Loaded {len(df)} metric records from {len(all_metrics)} result files")

    # Generate outputs
    generate_comparison_tables(df, agg_df)
    generate_charts(df, agg_df)
    generate_compatibility_matrix()
    generate_summary_report(df, agg_df)

    log("Report generation complete")


if __name__ == '__main__':
    main()
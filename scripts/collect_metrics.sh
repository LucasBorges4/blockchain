#!/usr/bin/env bash
# collect_metrics.sh
# Collect and aggregate metrics from experiment results
# Part of Blockchain Consensus Lab — Phase 5

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BENCHMARKS_DIR="$ROOT_DIR/benchmarks"
METRICS_DIR="$ROOT_DIR/metrics"
REPORTS_DIR="$ROOT_DIR/reports/raw"
LOGS_DIR="$ROOT_DIR/logs/metrics"

mkdir -p "$METRICS_DIR/collector" "$METRICS_DIR/parser" "$METRICS_DIR/exporter" "$REPORTS_DIR" "$LOGS_DIR"

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
success() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $*"; }
error() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $*"; }

# Find all result files
find_result_files() {
    find "$BENCHMARKS_DIR/results" -name "*.json" -type f 2>/dev/null | sort
}

# Parse a single result file and extract metrics
parse_result_file() {
    local file="$1"
    local adapter exp_name timestamp
    local basename=$(basename "$file" .json)

    # Parse filename: adapter_experiment_timestamp.json
    if [[ "$basename" =~ ^(.+)_(.+)_([0-9]+)$ ]]; then
        adapter="${BASH_REMATCH[1]}"
        exp_name="${BASH_REMATCH[2]}"
        timestamp="${BASH_REMATCH[3]}"
    else
        warn "Could not parse filename: $basename"
        return 1
    fi

    # Extract metrics using jq if available, otherwise Python
    if command -v jq >/dev/null 2>&1; then
        parse_with_jq "$file" "$adapter" "$exp_name" "$timestamp"
    else
        parse_with_python "$file" "$adapter" "$exp_name" "$timestamp"
    fi
}

parse_with_jq() {
    local file="$1" adapter="$2" exp_name="$3" timestamp="$4"

    # Extract metrics assuming standard JSON structure
    jq -r --arg adapter "$adapter" --arg exp "$exp_name" --arg ts "$timestamp" '
        {
            adapter: $adapter,
            experiment: $exp,
            timestamp: $ts,
            repetitions: .repetitions // 1,
            seed: .seed // null,
            config: .config // {},
            metrics: .metrics // {},
            raw_data: .raw_data // []
        }
    ' "$file"
}

parse_with_python() {
    local file="$1" adapter="$2" exp_name="$3" timestamp="$4"

    python3 -c "
import json, sys
with open('$file') as f:
    data = json.load(f)
result = {
    'adapter': '$adapter',
    'experiment': '$exp_name',
    'timestamp': '$timestamp',
    'repetitions': data.get('repetitions', 1),
    'seed': data.get('seed'),
    'config': data.get('config', {}),
    'metrics': data.get('metrics', {}),
    'raw_data': data.get('raw_data', [])
}
print(json.dumps(result))
"
}

# Compute statistics from raw data
compute_statistics() {
    local values_json="$1"
    python3 -c "
import json, statistics, sys
values = json.loads('$values_json')
if not values:
    print(json.dumps({}))
    sys.exit(0)
vals = [float(v) for v in values if v is not None]
if not vals:
    print(json.dumps({}))
    sys.exit(0)
result = {
    'count': len(vals),
    'mean': statistics.mean(vals),
    'median': statistics.median(vals),
    'stdev': statistics.stdev(vals) if len(vals) > 1 else 0,
    'min': min(vals),
    'max': max(vals),
    'p50': statistics.median(vals),
    'p95': sorted(vals)[int(len(vals) * 0.95)] if len(vals) > 1 else vals[0],
    'p99': sorted(vals)[int(len(vals) * 0.99)] if len(vals) > 1 else vals[0]
}
print(json.dumps(result))
"
}

# Aggregate metrics across repetitions
aggregate_metrics() {
    local adapter="$1"
    local experiment="$2"
    local output_dir="$METRICS_DIR/collector/${adapter}_${experiment}"

    mkdir -p "$output_dir"

    log "Aggregating metrics for $adapter / $experiment"

    # Find all result files for this adapter/experiment
    local files=()
    while IFS= read -r file; do
        files+=("$file")
    done < <(find "$BENCHMARKS_DIR/results" -name "${adapter}_${experiment}_*.json" -type f 2>/dev/null | sort)

    if [[ ${#files[@]} -eq 0 ]]; then
        warn "No result files found for $adapter / $experiment"
        return 1
    fi

    log "Found ${#files[@]} result files"

    # Merge all raw data and compute statistics
    python3 <<PYEOF
import json
import statistics
import sys
from collections import defaultdict

all_metrics = defaultdict(list)
configs = []

for f in ${files[@]}:
    with open(f) as fh:
        data = json.load(fh)
    configs.append(data.get('config', {}))
    metrics = data.get('metrics', {})
    raw = data.get('raw_data', [])

    for key, value in metrics.items():
        if isinstance(value, list):
            all_metrics[key].extend(value)
        else:
            all_metrics[key].append(value)

    # Also check raw_data for metric arrays
    if isinstance(raw, list):
        for entry in raw:
            if isinstance(entry, dict):
                for k, v in entry.items():
                    if isinstance(v, (int, float)):
                        all_metrics[f"raw_{k}"].append(v)

# Compute statistics
results = {}
for key, values in all_metrics.items():
    vals = [float(v) for v in values if v is not None]
    if not vals:
        continue
    results[key] = {
        'count': len(vals),
        'mean': statistics.mean(vals),
        'median': statistics.median(vals),
        'stdev': statistics.stdev(vals) if len(vals) > 1 else 0,
        'min': min(vals),
        'max': max(vals),
        'p50': statistics.median(vals),
        'p95': sorted(vals)[int(len(vals) * 0.95)] if len(vals) > 1 else vals[0],
        'p99': sorted(vals)[int(len(vals) * 0.99)] if len(vals) > 1 else vals[0]
    }

output = {
    'adapter': '$adapter',
    'experiment': '$experiment',
    'file_count': ${#files[@]},
    'configs': configs,
    'aggregated_metrics': results
}

with open('$output_dir/aggregated.json', 'w') as f:
    json.dump(output, f, indent=2)

# Also export CSV for each metric
import csv
for key, stats in results.items():
    csv_file = '$output_dir/{key}.csv'.format(key=key.replace('/', '_'))
    with open(csv_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['statistic', 'value'])
        for stat, val in stats.items():
            writer.writerow([stat, val])

print('Aggregated metrics saved to $output_dir')
PYEOF

    success "Aggregation complete for $adapter / $experiment"
}

# Export all metrics to unified format
export_all_metrics() {
    local export_dir="$METRICS_DIR/exporter"
    mkdir -p "$export_dir"

    log "Exporting all metrics to unified format..."

    python3 <<PYEOF
import json, os, csv, glob
from datetime import datetime

export_dir = '$export_dir'
results_dir = '$BENCHMARKS_DIR/results'

all_results = []

for json_file in glob.glob(os.path.join(results_dir, '*.json')):
    with open(json_file) as f:
        data = json.load(f)
    all_results.append(data)

# Combined JSON
with open(os.path.join(export_dir, 'all_metrics.json'), 'w') as f:
    json.dump(all_results, f, indent=2)

# Combined CSV (flattened)
if all_results:
    # Get all possible metric keys
    all_keys = set()
    for r in all_results:
        for k in r.get('metrics', {}).keys():
            all_keys.add(k)

    with open(os.path.join(export_dir, 'all_metrics.csv'), 'w', newline='') as f:
        writer = csv.writer(f)
        header = ['adapter', 'experiment', 'timestamp', 'repetitions', 'seed'] + sorted(all_keys)
        writer.writerow(header)

        for r in all_results:
            row = [
                r.get('adapter', ''),
                r.get('experiment', ''),
                r.get('timestamp', ''),
                r.get('repetitions', 1),
                r.get('seed', '')
            ]
            metrics = r.get('metrics', {})
            for key in sorted(all_keys):
                val = metrics.get(key, '')
                if isinstance(val, list):
                    val = ';'.join(str(v) for v in val)
                row.append(val)
            writer.writerow(row)

print(f'Exported {len(all_results)} result files to {export_dir}')
PYEOF

    success "All metrics exported to $export_dir"
}

# Generate metrics summary report
generate_metrics_report() {
    local report_file="$REPORTS_DIR/metrics_summary.md"

    log "Generating metrics summary report..."

    cat >"$report_file" <<'EOF'
# Metrics Collection Summary

Generated: $(date)

## Aggregated Metrics by Adapter/Experiment
EOF

    for agg_dir in "$METRICS_DIR/collector"/*/; do
        if [[ -d "$agg_dir" ]]; then
            local name=$(basename "$agg_dir")
            echo "" >>"$report_file"
            echo "### $name" >>"$report_file"
            echo "" >>"$report_file"

            if [[ -f "$agg_dir/aggregated.json" ]]; then
                python3 <<PYEOF >>"$report_file"
import json
with open('$agg_dir/aggregated.json') as f:
    data = json.load(f)

print("| Metric | Count | Mean | Median | StdDev | Min | Max | P95 | P99 |")
print("|--------|-------|------|--------|--------|-----|-----|-----|-----|")

for metric, stats in data.get('aggregated_metrics', {}).items():
    print(f"| {metric} | {stats.get('count',0)} | {stats.get('mean',0):.4f} | {stats.get('median',0):.4f} | {stats.get('stdev',0):.4f} | {stats.get('min',0):.4f} | {stats.get('max',0):.4f} | {stats.get('p95',0):.4f} | {stats.get('p99',0):.4f} |")
PYEOF
            fi
        fi
    done

    success "Metrics summary report saved to $report_file"
}

main() {
    log "Starting metrics collection phase"

    # Parse all result files
    local files=()
    while IFS= read -r file; do
        files+=("$file")
    done < <(find_result_files)

    if [[ ${#files[@]} -eq 0 ]]; then
        warn "No experiment result files found in $BENCHMARKS_DIR/results"
        warn "Run 'make experiment' first"
        exit 0
    fi

    log "Found ${#files[@]} result files"

    # Aggregate per adapter/experiment
    local processed=()
    for file in "${files[@]}"; do
        local basename=$(basename "$file" .json)
        if [[ "$basename" =~ ^(.+)_(.+)_([0-9]+)$ ]]; then
            local adapter="${BASH_REMATCH[1]}"
            local exp="${BASH_REMATCH[2]}"
            local key="${adapter}_${exp}"
            if [[ ! " ${processed[*]} " =~ " ${key} " ]]; then
                aggregate_metrics "$adapter" "$exp"
                processed+=("$key")
            fi
        fi
    done

    # Export all
    export_all_metrics

    # Generate report
    generate_metrics_report

    success "Metrics collection phase complete"
}

main "$@"
#!/usr/bin/env bash
# run_experiments.sh
# Run controlled experiments for all configured adapters
# Part of Blockchain Consensus Lab — Phase 4

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ADAPTERS_DIR="$ROOT_DIR/adapters"
EXPERIMENTS_DIR="$ROOT_DIR/experiments"
BENCHMARKS_DIR="$ROOT_DIR/benchmarks"
LOGS_DIR="$ROOT_DIR/logs/experiment"
REPORTS_DIR="$ROOT_DIR/reports/raw"

mkdir -p "$LOGS_DIR" "$REPORTS_DIR" "$BENCHMARKS_DIR/results"

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
success() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $*"; }
error() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $*"; }

# Experiment configuration
REPETITIONS="${BCL_EXPERIMENT_REPETITIONS:-5}"
TIMEOUT="${BCL_EXPERIMENT_TIMEOUT:-3600}"
SEED="${BCL_RANDOM_SEED:-42}"

# Node counts for scalability
NODE_COUNTS=(${BCL_SCALABILITY_NODE_COUNTS:-"4 7 10 16 25 50"})
# Transaction loads for throughput
TX_LOADS=(${BCL_THROUGHPUT_LOADS:-"100 1000 10000 100000"})

# Available adapters (directories that exist)
get_available_adapters() {
    local adapters=()
    for adapter_dir in "$ADAPTERS_DIR"/*/; do
        if [[ -d "$adapter_dir" ]]; then
            local name=$(basename "$adapter_dir")
            # Check if adapter has run_experiment script or Python module
            if [[ -f "$adapter_dir/run_experiment.py" ]] || [[ -f "$adapter_dir/run_experiment.sh" ]] || [[ -f "$adapter_dir/experiment.py" ]]; then
                adapters+=("$name")
            fi
        fi
    done
    echo "${adapters[@]}"
}

# Run a single experiment for an adapter
run_adapter_experiment() {
    local adapter="$1"
    local experiment_type="$2"
    local params="$3"
    local adapter_dir="$ADAPTERS_DIR/$adapter"
    local log_file="$LOGS_DIR/${adapter}_${experiment_type}.log"
    local result_file="$BENCHMARKS_DIR/results/${adapter}_${experiment_type}_$(date +%s).json"

    log "Running $experiment_type experiment for $adapter with params: $params"

    if [[ -f "$adapter_dir/run_experiment.py" ]]; then
        python3 "$adapter_dir/run_experiment.py" \
            --experiment "$experiment_type" \
            --params "$params" \
            --repetitions "$REPETITIONS" \
            --seed "$SEED" \
            --output "$result_file" \
            2>&1 | tee -a "$log_file"
    elif [[ -f "$adapter_dir/run_experiment.sh" ]]; then
        bash "$adapter_dir/run_experiment.sh" \
            "$experiment_type" \
            "$params" \
            "$REPETITIONS" \
            "$SEED" \
            "$result_file" \
            2>&1 | tee -a "$log_file"
    elif [[ -f "$adapter_dir/experiment.py" ]]; then
        python3 "$adapter_dir/experiment.py" \
            --experiment "$experiment_type" \
            --params "$params" \
            --repetitions "$REPETITIONS" \
            --seed "$SEED" \
            --output "$result_file" \
            2>&1 | tee -a "$log_file"
    else
        warn "No experiment runner found for $adapter"
        return 1
    fi

    if [[ -f "$result_file" ]]; then
        success "$adapter $experiment_type completed, results in $result_file"
        return 0
    else
        error "$adapter $experiment_type failed to produce results"
        return 1
    fi
}

# Experiment A: Basic Functionality
run_experiment_basic() {
    local adapter="$1"
    log "=== Experiment A: Basic Functionality for $adapter ==="
    run_adapter_experiment "$adapter" "basic" "nodes=4,tx_count=100,msg_size=256,duration=60"
}

# Experiment B: Scalability
run_experiment_scalability() {
    local adapter="$1"
    log "=== Experiment B: Scalability for $adapter ==="
    for nodes in "${NODE_COUNTS[@]}"; do
        log "Testing with N=$nodes nodes"
        run_adapter_experiment "$adapter" "scalability" "nodes=$nodes,tx_count=1000,duration=120"
    done
}

# Experiment C: Latency
run_experiment_latency() {
    local adapter="$1"
    log "=== Experiment C: Latency for $adapter ==="
    run_adapter_experiment "$adapter" "latency" "nodes=4,tx_count=10000,measure_latency=true"
}

# Experiment D: Throughput
run_experiment_throughput() {
    local adapter="$1"
    log "=== Experiment D: Throughput for $adapter ==="
    for load in "${TX_LOADS[@]}"; do
        log "Testing with load=$load transactions"
        run_adapter_experiment "$adapter" "throughput" "nodes=4,tx_count=$load,duration=300"
    done
}

# Experiment E: Fault Tolerance
run_experiment_fault_tolerance() {
    local adapter="$1"
    log "=== Experiment E: Fault Tolerance for $adapter ==="
    local scenarios=(${BCL_FAULT_SCENARIOS:-"node_crash leader_crash partition byzantine recovery"})
    for scenario in "${scenarios[@]}"; do
        log "Testing fault scenario: $scenario"
        run_adapter_experiment "$adapter" "fault_tolerance" "nodes=7,scenario=$scenario,duration=180"
    done
}

# Experiment F: Network Conditions
run_experiment_network_conditions() {
    local adapter="$1"
    log "=== Experiment F: Network Conditions for $adapter ==="
    local latencies=(${BCL_NET_LATENCY_MS:-"0 10 50 100 200"})
    local jitters=(${BCL_NET_JITTER_MS:-"0 5 10 20"})
    local losses=(${BCL_NET_LOSS_PCT:-"0 0.1 1 5"})

    for latency in "${latencies[@]}"; do
        for jitter in "${jitters[@]}"; do
            for loss in "${losses[@]}"; do
                log "Testing network: latency=${latency}ms, jitter=${jitter}ms, loss=${loss}%"
                run_adapter_experiment "$adapter" "network_conditions" \
                    "nodes=4,latency_ms=$latency,jitter_ms=$jitter,loss_pct=$loss,duration=120"
            done
        done
    done
}

# Main experiment runner for an adapter
run_all_experiments_for_adapter() {
    local adapter="$1"
    log "Starting all experiments for adapter: $adapter"

    run_experiment_basic "$adapter" || warn "Basic experiment failed for $adapter"
    run_experiment_scalability "$adapter" || warn "Scalability experiment failed for $adapter"
    run_experiment_latency "$adapter" || warn "Latency experiment failed for $adapter"
    run_experiment_throughput "$adapter" || warn "Throughput experiment failed for $adapter"
    run_experiment_fault_tolerance "$adapter" || warn "Fault tolerance experiment failed for $adapter"
    run_experiment_network_conditions "$adapter" || warn "Network conditions experiment failed for $adapter"

    success "All experiments completed for $adapter"
}

# Generate experiment summary
generate_experiment_summary() {
    local summary_file="$REPORTS_DIR/experiment_summary.md"
    local json_file="$REPORTS_DIR/experiment_summary.json"

    log "Generating experiment summary..."

    cat >"$summary_file" <<EOF
# Experiment Execution Summary

Generated: $(date)
Repetitions per experiment: $REPETITIONS
Random seed: $SEED

## Adapters Tested
EOF

    local adapters=($(get_available_adapters))
    for adapter in "${adapters[@]}"; do
        echo "- $adapter" >>"$summary_file"
    done

    cat >>"$summary_file" <<'EOF'

## Experiment Matrix

| Adapter | Basic | Scalability | Latency | Throughput | Fault Tolerance | Network Conditions |
|---------|-------|-------------|---------|------------|-----------------|-------------------|
EOF

    for adapter in "${adapters[@]}"; do
        local basic="✓" scalability="✓" latency="✓" throughput="✓" fault="✓" network="✓"
        # Check if result files exist
        for exp in basic scalability latency throughput fault_tolerance network_conditions; do
            if ! ls "$BENCHMARKS_DIR/results/${adapter}_${exp}_"*.json >/dev/null 2>&1; then
                case $exp in
                    basic) basic="✗" ;;
                    scalability) scalability="✗" ;;
                    latency) latency="✗" ;;
                    throughput) throughput="✗" ;;
                    fault_tolerance) fault="✗" ;;
                    network_conditions) network="✗" ;;
                esac
            fi
        done
        echo "| $adapter | $basic | $scalability | $latency | $throughput | $fault | $network |" >>"$summary_file"
    done

    # JSON summary
    cat >"$json_file" <<EOF
{
  "generated": "$(date -Iseconds)",
  "repetitions": $REPETITIONS,
  "seed": $SEED,
  "adapters": [
EOF

    local first=true
    for adapter in "${adapters[@]}"; do
        if [[ "$first" == true ]]; then
            first=false
        else
            echo "," >>"$json_file"
        fi
        echo "    \"$adapter\"" >>"$json_file"
    done

    cat >>"$json_file" <<EOF
  ],
  "node_counts": [$(printf '"%s",' "${NODE_COUNTS[@]}" | sed 's/,$//')],
  "tx_loads": [$(printf '"%s",' "${TX_LOADS[@]}" | sed 's/,$//')]
}
EOF

    success "Experiment summary saved to $summary_file and $json_file"
}

main() {
    log "Starting experiment phase"
    log "Repetitions: $REPETITIONS, Timeout: ${TIMEOUT}s, Seed: $SEED"

    local adapters=($(get_available_adapters))

    if [[ ${#adapters[@]} -eq 0 ]]; then
        warn "No adapters with experiment runners found in $ADAPTERS_DIR"
        warn "Run 'make adapters' first to build adapters"
        exit 0
    fi

    log "Found adapters: ${adapters[*]}"

    for adapter in "${adapters[@]}"; do
        run_all_experiments_for_adapter "$adapter"
    done

    generate_experiment_summary

    success "Experiment phase complete"
}

main "$@"
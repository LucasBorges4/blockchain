#!/usr/bin/env python3
"""
Adapter Template for Blockchain Consensus Lab
==============================================

This is a template for creating experiment adapters for each consensus protocol.
Copy this file to adapters/<protocol>/experiment.py and implement the abstract methods.

Each adapter must implement:
- configure(config): Set up the network with given configuration
- start_network(num_nodes): Start the validator nodes
- submit_workload(workload): Submit transactions/operations
- collect_metrics(): Collect metrics from the running network
- stop_network(): Cleanly shut down the network

The adapter should output results in the standard JSON format:
{
    "adapter": "protocol_name",
    "experiment": "experiment_type",
    "timestamp": "unix_timestamp",
    "repetitions": 5,
    "seed": 42,
    "config": {...},
    "metrics": {...},
    "raw_data": [...]
}
"""

import abc
import json
import time
import argparse
import subprocess
import tempfile
import os
import sys
from pathlib import Path
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict


@dataclass
class ExperimentConfig:
    """Configuration for an experiment run"""
    experiment_type: str  # basic, scalability, latency, throughput, fault_tolerance, network_conditions
    nodes: int = 4
    tx_count: int = 1000
    msg_size: int = 256
    duration: int = 60
    latency_ms: int = 0
    jitter_ms: int = 0
    loss_pct: float = 0.0
    bandwidth_mbps: int = 0
    scenario: str = ""
    seed: int = 42
    repetitions: int = 5
    extra: Dict[str, Any] = None

    def __post_init__(self):
        if self.extra is None:
            self.extra = {}


@dataclass
class ExperimentResult:
    """Result of a single experiment repetition"""
    repetition: int
    success: bool
    metrics: Dict[str, Any]
    raw_data: List[Dict[str, Any]]
    error: Optional[str] = None
    duration_seconds: float = 0.0


class ConsensusAdapter(abc.ABC):
    """Abstract base class for consensus protocol adapters"""

    def __init__(self, name: str, repo_path: str):
        self.name = name
        self.repo_path = Path(repo_path)
        self.network_dir = None
        self.processes = []
        self.config = None

    @abc.abstractmethod
    def configure(self, config: ExperimentConfig) -> bool:
        """
        Configure the adapter with experiment parameters.
        Set up config files, genesis, keys, etc.
        Return True on success.
        """
        pass

    @abc.abstractmethod
    def start_network(self, num_nodes: int) -> bool:
        """
        Start the validator network with num_nodes.
        Return True if all nodes started successfully.
        """
        pass

    @abc.abstractmethod
    def submit_workload(self, workload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Submit a workload (transactions, operations) to the network.
        Return dict with results: submitted, confirmed, failed, latencies, etc.
        """
        pass

    @abc.abstractmethod
    def collect_metrics(self) -> Dict[str, Any]:
        """
        Collect metrics from the running network.
        Return dict with metrics: throughput, latency, cpu, memory, etc.
        """
        pass

    @abc.abstractmethod
    def stop_network(self) -> bool:
        """
        Stop all nodes and clean up.
        Return True on clean shutdown.
        """
        pass

    def run_experiment(self, config: ExperimentConfig) -> Dict[str, Any]:
        """
        Run a complete experiment with multiple repetitions.
        This is the main entry point called by the experiment runner.
        """
        results = []
        all_metrics = {}
        all_raw_data = []

        for rep in range(config.repetitions):
            print(f"[{self.name}] Repetition {rep + 1}/{config.repetitions}")
            rep_seed = config.seed + rep

            # Set seed for reproducibility
            import random
            random.seed(rep_seed)

            start_time = time.time()
            rep_result = self._run_single_repetition(config, rep_seed)
            duration = time.time() - start_time

            results.append(rep_result)
            if rep_result.success:
                # Aggregate metrics
                for key, value in rep_result.metrics.items():
                    if key not in all_metrics:
                        all_metrics[key] = []
                    if isinstance(value, list):
                        all_metrics[key].extend(value)
                    else:
                        all_metrics[key].append(value)
                all_raw_data.extend(rep_result.raw_data)

        # Compute aggregate statistics
        aggregated = self._compute_statistics(all_metrics)

        return {
            "adapter": self.name,
            "experiment": config.experiment_type,
            "timestamp": str(int(time.time())),
            "repetitions": config.repetitions,
            "seed": config.seed,
            "config": asdict(config),
            "metrics": aggregated,
            "raw_data": all_raw_data
        }

    def _run_single_repetition(self, config: ExperimentConfig, seed: int) -> ExperimentResult:
        """Run a single experiment repetition"""
        try:
            # Configure
            if not self.configure(config):
                return ExperimentResult(
                    repetition=0, success=False, metrics={}, raw_data=[],
                    error="Configuration failed"
                )

            # Start network
            if not self.start_network(config.nodes):
                return ExperimentResult(
                    repetition=0, success=False, metrics={}, raw_data=[],
                    error="Network startup failed"
                )

            # Wait for network to stabilize
            time.sleep(5)

            # Submit workload based on experiment type
            workload = self._create_workload(config)
            workload_result = self.submit_workload(workload)

            # Collect metrics
            metrics = self.collect_metrics()

            # Stop network
            self.stop_network()

            return ExperimentResult(
                repetition=0, success=True, metrics=metrics,
                raw_data=[workload_result] if workload_result else [],
                duration_seconds=0
            )

        except Exception as e:
            self.stop_network()  # Try to clean up
            return ExperimentResult(
                repetition=0, success=False, metrics={}, raw_data=[],
                error=str(e)
            )

    def _create_workload(self, config: ExperimentConfig) -> Dict[str, Any]:
        """Create workload based on experiment type"""
        base_workload = {
            "tx_count": config.tx_count,
            "msg_size": config.msg_size,
            "duration": config.duration,
        }

        if config.experiment_type == "basic":
            return {**base_workload, "type": "basic"}
        elif config.experiment_type == "scalability":
            return {**base_workload, "type": "scalability", "nodes": config.nodes}
        elif config.experiment_type == "latency":
            return {**base_workload, "type": "latency", "measure_latency": True}
        elif config.experiment_type == "throughput":
            return {**base_workload, "type": "throughput"}
        elif config.experiment_type == "fault_tolerance":
            return {**base_workload, "type": "fault_tolerance", "scenario": config.scenario}
        elif config.experiment_type == "network_conditions":
            return {**base_workload, "type": "network_conditions",
                    "latency_ms": config.latency_ms, "jitter_ms": config.jitter_ms,
                    "loss_pct": config.loss_pct, "bandwidth_mbps": config.bandwidth_mbps}
        else:
            return base_workload

    def _compute_statistics(self, metrics: Dict[str, List[float]]) -> Dict[str, Any]:
        """Compute statistics from collected metrics"""
        import statistics

        result = {}
        for key, values in metrics.items():
            if not values:
                continue
            # Flatten if nested lists
            flat_values = []
            for v in values:
                if isinstance(v, list):
                    flat_values.extend([float(x) for x in v if x is not None])
                elif v is not None:
                    flat_values.append(float(v))

            if not flat_values:
                continue

            result[key] = {
                "count": len(flat_values),
                "mean": statistics.mean(flat_values),
                "median": statistics.median(flat_values),
                "stdev": statistics.stdev(flat_values) if len(flat_values) > 1 else 0,
                "min": min(flat_values),
                "max": max(flat_values),
                "p50": statistics.median(flat_values),
                "p95": sorted(flat_values)[int(len(flat_values) * 0.95)] if len(flat_values) > 1 else flat_values[0],
                "p99": sorted(flat_values)[int(len(flat_values) * 0.99)] if len(flat_values) > 1 else flat_values[0],
            }

        return result


def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description="Run consensus experiment")
    parser.add_argument("--experiment", required=True, choices=[
        "basic", "scalability", "latency", "throughput", "fault_tolerance", "network_conditions"
    ])
    parser.add_argument("--params", required=True, help="Comma-separated key=value pairs")
    parser.add_argument("--repetitions", type=int, default=5)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--output", required=True, help="Output JSON file")
    return parser.parse_args()


def parse_params(param_str: str) -> Dict[str, Any]:
    """Parse comma-separated key=value pairs"""
    params = {}
    for pair in param_str.split(','):
        if '=' in pair:
            key, value = pair.split('=', 1)
            # Try to convert to appropriate type
            if value.lower() in ('true', 'false'):
                value = value.lower() == 'true'
            else:
                try:
                    value = int(value)
                except ValueError:
                    try:
                        value = float(value)
                    except ValueError:
                        pass  # Keep as string
            params[key.strip()] = value
    return params


def main(adapter_class):
    """Main entry point for adapter script"""
    args = parse_args()
    params = parse_params(args.params)

    config = ExperimentConfig(
        experiment_type=args.experiment,
        repetitions=args.repetitions,
        seed=args.seed,
        **params
    )

    # Instantiate adapter (repo path relative to project root)
    repo_path = os.path.join(os.path.dirname(__file__), '..', '..', 'repositories', adapter_class.repo_name)
    adapter = adapter_class(repo_path)

    try:
        result = adapter.run_experiment(config)

        # Write output
        with open(args.output, 'w') as f:
            json.dump(result, f, indent=2)

        print(f"Experiment completed. Results written to {args.output}")
        sys.exit(0)

    except Exception as e:
        print(f"Experiment failed: {e}")
        sys.exit(1)


# =============================================================================
# EXAMPLE IMPLEMENTATION (to be customized per protocol)
# =============================================================================

class TemplateAdapter(ConsensusAdapter):
    """Template adapter - replace with protocol-specific implementation"""

    repo_name = "template-protocol"

    def configure(self, config: ExperimentConfig) -> bool:
        """Generate config files, genesis, keys for the network"""
        print(f"[{self.name}] Configuring network with {config.nodes} nodes")
        # TODO: Generate config files, genesis, keys
        # Example: write config to self.network_dir / "config.toml"
        return True

    def start_network(self, num_nodes: int) -> bool:
        """Start validator processes"""
        print(f"[{self.name}] Starting {num_nodes} nodes")
        # TODO: Launch node processes, store PIDs in self.processes
        # Example: subprocess.Popen([...], cwd=self.network_dir)
        return True

    def submit_workload(self, workload: Dict[str, Any]) -> Dict[str, Any]:
        """Submit transactions to the network"""
        print(f"[{self.name}] Submitting workload: {workload}")
        # TODO: Use client/cli to submit transactions
        # Return: {"submitted": N, "confirmed": M, "latencies": [...], ...}
        return {"submitted": workload.get("tx_count", 0), "confirmed": 0, "latencies": []}

    def collect_metrics(self) -> Dict[str, Any]:
        """Collect metrics from running nodes"""
        print(f"[{self.name}] Collecting metrics")
        # TODO: Query metrics endpoints, parse logs, use system tools
        # Return: {"throughput_tps": 100, "latency_mean_ms": 50, "cpu_percent": 50, ...}
        return {}

    def stop_network(self) -> bool:
        """Stop all nodes"""
        print(f"[{self.name}] Stopping network")
        # TODO: Terminate processes, clean up
        for proc in self.processes:
            proc.terminate()
        self.processes = []
        return True


if __name__ == "__main__":
    # This allows running the adapter directly for testing
    # Replace TemplateAdapter with your actual adapter class
    main(TemplateAdapter)
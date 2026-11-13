#!/usr/bin/env python3
"""
CometBFT Adapter for Blockchain Consensus Lab
==============================================

Implements experiment interface for CometBFT (Tendermint) consensus.
"""

import json
import time
import subprocess
import tempfile
import os
import sys
import shutil
from pathlib import Path
from typing import Dict, List, Any, Optional

# Add template to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from template_adapter import ConsensusAdapter, ExperimentConfig, ExperimentResult, parse_args, parse_params, main


class CometBFTAdapter(ConsensusAdapter):
    """CometBFT experiment adapter"""

    repo_name = "cometbft"

    def __init__(self, repo_path: str):
        super().__init__("cometbft", repo_path)
        self.binary_path = None
        self.network_dir = None
        self.node_processes = []
        self.rpc_ports = []

    def configure(self, config: ExperimentConfig) -> bool:
        """Set up CometBFT testnet configuration"""
        print(f"[{self.name}] Configuring {config.nodes} node testnet")

        # Find cometbft binary
        self.binary_path = self._find_binary()
        if not self.binary_path:
            print(f"[{self.name}] ERROR: cometbft binary not found")
            return False

        # Create temporary network directory
        self.network_dir = Path(tempfile.mkdtemp(prefix=f"cometbft_{config.experiment_type}_"))
        print(f"[{self.name}] Network directory: {self.network_dir}")

        # Generate validator keys and config for each node
        for i in range(config.nodes):
            node_dir = self.network_dir / f"node{i}"
            node_dir.mkdir(parents=True)

            # Initialize node
            result = subprocess.run([
                str(self.binary_path), "init",
                "--home", str(node_dir)
            ], capture_output=True, text=True)

            if result.returncode != 0:
                print(f"[{self.name}] ERROR: Failed to init node {i}: {result.stderr}")
                return False

        # Generate genesis with all validators
        # Use first node's genesis as base, then add other validators
        self._generate_genesis(config.nodes)

        # Configure each node
        for i in range(config.nodes):
            self._configure_node(i, config)

        return True

    def _find_binary(self) -> Optional[Path]:
        """Find cometbft binary in build directory or PATH"""
        # Check build directory first
        build_paths = [
            self.repo_path / "build" / "cometbft",
            self.repo_path / "cometbft",
        ]
        for p in build_paths:
            if p.exists() and os.access(p, os.X_OK):
                return p

        # Check PATH
        result = subprocess.run(["which", "cometbft"], capture_output=True, text=True)
        if result.returncode == 0:
            return Path(result.stdout.strip())

        return None

    def _generate_genesis(self, num_nodes: int):
        """Generate genesis file with all validators"""
        # Use first node as base
        base_node = self.network_dir / "node0"
        genesis_file = base_node / "config" / "genesis.json"

        # Read base genesis
        with open(genesis_file) as f:
            genesis = json.load(f)

        # Collect validator pubkeys from all nodes
        validators = []
        for i in range(num_nodes):
            node_dir = self.network_dir / f"node{i}"
            priv_key_file = node_dir / "config" / "priv_validator_key.json"
            if priv_key_file.exists():
                with open(priv_key_file) as f:
                    key_data = json.load(f)
                validators.append({
                    "address": key_data["address"],
                    "pub_key": key_data["pub_key"],
                    "power": "10",
                    "name": f"validator{i}"
                })

        genesis["validators"] = validators
        genesis["initial_height"] = "1"

        # Write updated genesis to all nodes
        for i in range(num_nodes):
            node_genesis = self.network_dir / f"node{i}" / "config" / "genesis.json"
            with open(node_genesis, 'w') as f:
                json.dump(genesis, f, indent=2)

    def _configure_node(self, node_index: int, config: ExperimentConfig):
        """Configure individual node (peers, RPC, etc.)"""
        node_dir = self.network_dir / f"node{node_index}"
        config_file = node_dir / "config" / "config.toml"

        # Read config
        with open(config_file) as f:
            content = f.read()

        # Configure P2P
        peers = []
        for i in range(config.nodes):
            if i != node_index:
                peers.append(f"node{i}@localhost:{26656 + i}")
        persistent_peers = ",".join(peers)

        # Configure ports
        p2p_port = 26656 + node_index
        rpc_port = 26657 + node_index
        self.rpc_ports.append(rpc_port)

        # Replace config values
        content = content.replace('persistent_peers = ""', f'persistent_peers = "{persistent_peers}"')
        content = content.replace('laddr = "tcp://0.0.0.0:26656"', f'laddr = "tcp://0.0.0.0:{p2p_port}"')
        content = content.replace('laddr = "tcp://127.0.0.1:26657"', f'laddr = "tcp://127.0.0.1:{rpc_port}"')

        # Write back
        with open(config_file, 'w') as f:
            f.write(content)

    def start_network(self, num_nodes: int) -> bool:
        """Start all CometBFT nodes"""
        print(f"[{self.name}] Starting {num_nodes} nodes")

        for i in range(num_nodes):
            node_dir = self.network_dir / f"node{i}"
            log_file = node_dir / "cometbft.log"

            # Start node
            proc = subprocess.Popen([
                str(self.binary_path), "node",
                "--home", str(node_dir)
            ], stdout=open(log_file, 'w'), stderr=subprocess.STDOUT)

            self.node_processes.append(proc)
            time.sleep(1)  # Stagger startup

        # Wait for nodes to be ready
        print(f"[{self.name}] Waiting for nodes to start...")
        time.sleep(5)

        # Check health
        for i, rpc_port in enumerate(self.rpc_ports):
            for _ in range(10):
                try:
                    result = subprocess.run([
                        "curl", "-s", f"http://localhost:{rpc_port}/health"
                    ], capture_output=True, text=True, timeout=5)
                    if result.returncode == 0:
                        print(f"[{self.name}] Node {i} healthy on port {rpc_port}")
                        break
                except Exception:
                    pass
                time.sleep(1)
            else:
                print(f"[{self.name}] WARNING: Node {i} health check failed")

        return True

    def submit_workload(self, workload: Dict[str, Any]) -> Dict[str, Any]:
        """Submit transactions via CometBFT RPC"""
        print(f"[{self.name}] Submitting workload: {workload}")

        tx_count = workload.get("tx_count", 100)
        tx_size = workload.get("msg_size", 256)

        # Generate dummy transactions
        txs = []
        for i in range(tx_count):
            # Simple key-value transaction
            tx = f"key{i}=value{'x' * (tx_size - 10)}".encode()
            txs.append(tx.hex())

        # Submit via broadcast_tx_commit to first node
        rpc_port = self.rpc_ports[0] if self.rpc_ports else 26657

        latencies = []
        confirmed = 0
        failed = 0

        for tx_hex in txs:
            start = time.time()
            try:
                result = subprocess.run([
                    "curl", "-s", "-X", "POST",
                    f"http://localhost:{rpc_port}/broadcast_tx_commit",
                    "-H", "Content-Type: application/json",
                    "-d", json.dumps({
                        "jsonrpc": "2.0",
                        "id": 1,
                        "method": "broadcast_tx_commit",
                        "params": {"tx": f"0x{tx_hex}"}
                    })
                ], capture_output=True, text=True, timeout=10)

                latency = (time.time() - start) * 1000  # ms
                latencies.append(latency)

                if result.returncode == 0:
                    resp = json.loads(result.stdout)
                    if "result" in resp and resp["result"].get("check_tx", {}).get("code", 1) == 0:
                        confirmed += 1
                    else:
                        failed += 1
                else:
                    failed += 1

            except Exception as e:
                failed += 1
                latencies.append((time.time() - start) * 1000)

        return {
            "submitted": tx_count,
            "confirmed": confirmed,
            "failed": failed,
            "latencies_ms": latencies,
            "avg_latency_ms": sum(latencies) / len(latencies) if latencies else 0
        }

    def collect_metrics(self) -> Dict[str, Any]:
        """Collect metrics from running nodes"""
        metrics = {}

        # Get consensus metrics from first node
        if self.rpc_ports:
            rpc_port = self.rpc_ports[0]
            try:
                # Get consensus state
                result = subprocess.run([
                    "curl", "-s", f"http://localhost:{rpc_port}/consensus_state"
                ], capture_output=True, text=True, timeout=5)

                if result.returncode == 0:
                    state = json.loads(result.stdout)
                    # Extract useful metrics
                    metrics["consensus_height"] = state.get("result", {}).get("height", 0)
            except Exception:
                pass

            # Get network info
            try:
                result = subprocess.run([
                    "curl", "-s", f"http://localhost:{rpc_port}/net_info"
                ], capture_output=True, text=True, timeout=5)

                if result.returncode == 0:
                    net_info = json.loads(result.stdout)
                    peers = net_info.get("result", {}).get("peers", [])
                    metrics["connected_peers"] = len(peers)
            except Exception:
                pass

        # System metrics (basic)
        try:
            import psutil
            metrics["cpu_percent"] = psutil.cpu_percent(interval=1)
            metrics["memory_mb"] = psutil.virtual_memory().used / (1024 * 1024)
        except ImportError:
            pass

        return metrics

    def stop_network(self) -> bool:
        """Stop all nodes"""
        print(f"[{self.name}] Stopping network")

        for proc in self.node_processes:
            proc.terminate()

        # Wait for processes to exit
        for proc in self.node_processes:
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()

        self.node_processes = []

        # Clean up network directory
        if self.network_dir and self.network_dir.exists():
            shutil.rmtree(self.network_dir, ignore_errors=True)

        return True


if __name__ == "__main__":
    main(CometBFTAdapter)
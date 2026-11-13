#!/usr/bin/env python3
"""
Bitcoin Regtest Adapter for Blockchain Consensus Lab
=====================================================

Implements experiment interface for Bitcoin Core in regtest mode.
Note: Bitcoin uses Nakamoto consensus (PoW) with probabilistic finality.
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


class BitcoinAdapter(ConsensusAdapter):
    """Bitcoin Core regtest experiment adapter"""

    repo_name = "bitcoin"

    def __init__(self, repo_path: str):
        super().__init__("bitcoin", repo_path)
        self.bitcoind_path = None
        self.bitcoin_cli_path = None
        self.network_dir = None
        self.node_processes = []
        self.rpc_ports = []
        self.rpc_user = "bcl"
        self.rpc_pass = "bclpass"

    def configure(self, config: ExperimentConfig) -> bool:
        """Set up Bitcoin regtest network"""
        print(f"[{self.name}] Configuring {config.nodes} node regtest network")

        # Find binaries
        self.bitcoind_path = self._find_binary("bitcoind")
        self.bitcoin_cli_path = self._find_binary("bitcoin-cli")

        if not self.bitcoind_path or not self.bitcoin_cli_path:
            print(f"[{self.name}] ERROR: bitcoind or bitcoin-cli not found")
            return False

        # Create network directory
        self.network_dir = Path(tempfile.mkdtemp(prefix=f"bitcoin_{config.experiment_type}_"))
        print(f"[{self.name}] Network directory: {self.network_dir}")

        # Generate config for each node
        for i in range(config.nodes):
            node_dir = self.network_dir / f"node{i}"
            node_dir.mkdir(parents=True)

            rpc_port = 18443 + i
            p2p_port = 18444 + i
            self.rpc_ports.append(rpc_port)

            # Write bitcoin.conf
            conf_content = f"""regtest=1
server=1
daemon=0
rpcuser={self.rpc_user}
rpcpassword={self.rpc_pass}
rpcport={rpc_port}
port={p2p_port}
bind=127.0.0.1
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
fallbackfee=0.0001
txindex=1
"""
            with open(node_dir / "bitcoin.conf", 'w') as f:
                f.write(conf_content)

        # Add peer connections
        for i in range(config.nodes):
            node_dir = self.network_dir / f"node{i}"
            with open(node_dir / "bitcoin.conf", 'a') as f:
                for j in range(config.nodes):
                    if i != j:
                        f.write(f"addnode=127.0.0.1:{18444 + j}\n")

        return True

    def _find_binary(self, name: str) -> Optional[Path]:
        """Find binary in build directory or PATH"""
        build_paths = [
            self.repo_path / "src" / name,
            self.repo_path / "build" / "src" / name,
        ]
        for p in build_paths:
            if p.exists() and os.access(p, os.X_OK):
                return p

        result = subprocess.run(["which", name], capture_output=True, text=True)
        if result.returncode == 0:
            return Path(result.stdout.strip())

        return None

    def start_network(self, num_nodes: int) -> bool:
        """Start all Bitcoin nodes in regtest mode"""
        print(f"[{self.name}] Starting {num_nodes} regtest nodes")

        for i in range(num_nodes):
            node_dir = self.network_dir / f"node{i}"
            log_file = node_dir / "bitcoind.log"

            # Start bitcoind
            proc = subprocess.Popen([
                str(self.bitcoind_path),
                "-datadir=" + str(node_dir),
                "-conf=" + str(node_dir / "bitcoin.conf"),
                "-debug=net",
                "-debug=mempool"
            ], stdout=open(log_file, 'w'), stderr=subprocess.STDOUT)

            self.node_processes.append(proc)
            time.sleep(2)  # Stagger startup

        # Wait for nodes to be ready
        print(f"[{self.name}] Waiting for nodes to start...")
        time.sleep(10)

        # Check RPC connectivity
        for i, rpc_port in enumerate(self.rpc_ports):
            for _ in range(20):
                try:
                    result = subprocess.run([
                        str(self.bitcoin_cli_path),
                        f"-rpcport={rpc_port}",
                        f"-rpcuser={self.rpc_user}",
                        f"-rpcpassword={self.rpc_pass}",
                        "-datadir=" + str(self.network_dir / f"node{i}"),
                        "getblockchaininfo"
                    ], capture_output=True, text=True, timeout=5)

                    if result.returncode == 0:
                        print(f"[{self.name}] Node {i} ready on RPC port {rpc_port}")
                        break
                except Exception:
                    pass
                time.sleep(1)
            else:
                print(f"[{self.name}] WARNING: Node {i} RPC not responding")

        # Generate initial blocks for mining rewards
        self._generate_initial_blocks(num_nodes)

        return True

    def _generate_initial_blocks(self, num_nodes: int):
        """Generate initial blocks so nodes have mature coins"""
        print(f"[{self.name}] Generating initial blocks")

        for i in range(num_nodes):
            rpc_port = self.rpc_ports[i]
            node_dir = self.network_dir / f"node{i}"

            # Create a wallet
            subprocess.run([
                str(self.bitcoin_cli_path),
                f"-rpcport={rpc_port}",
                f"-rpcuser={self.rpc_user}",
                f"-rpcpassword={self.rpc_pass}",
                "-datadir=" + str(node_dir),
                "createwallet", f"wallet{i}", "false", "false", "", "false", "false"
            ], capture_output=True, text=True)

            # Generate 101 blocks (100 for maturity + 1)
            subprocess.run([
                str(self.bitcoin_cli_path),
                f"-rpcport={rpc_port}",
                f"-rpcuser={self.rpc_user}",
                f"-rpcpassword={self.rpc_pass}",
                "-datadir=" + str(node_dir),
                "generatetoaddress", "101",
                subprocess.run([
                    str(self.bitcoin_cli_path),
                    f"-rpcport={rpc_port}",
                    f"-rpcuser={self.rpc_user}",
                    f"-rpcpassword={self.rpc_pass}",
                    "-datadir=" + str(node_dir),
                    "getnewaddress", "", "legacy"
                ], capture_output=True, text=True).stdout.strip()
            ], capture_output=True, text=True)

    def submit_workload(self, workload: Dict[str, Any]) -> Dict[str, Any]:
        """Submit transactions to Bitcoin regtest network"""
        print(f"[{self.name}] Submitting workload: {workload}")

        tx_count = workload.get("tx_count", 100)
        # In regtest, we mine blocks to confirm transactions

        # Use first node for submitting
        rpc_port = self.rpc_ports[0]
        node_dir = self.network_dir / "node0"

        # Get address to send to
        addr_result = subprocess.run([
            str(self.bitcoin_cli_path),
            f"-rpcport={rpc_port}",
            f"-rpcuser={self.rpc_user}",
            f"-rpcpassword={self.rpc_pass}",
            "-datadir=" + str(node_dir),
            "getnewaddress", "", "legacy"
        ], capture_output=True, text=True)

        if addr_result.returncode != 0:
            return {"submitted": 0, "confirmed": 0, "failed": tx_count, "error": "No address"}

        dest_address = addr_result.stdout.strip()

        # Send transactions
        txids = []
        for i in range(tx_count):
            result = subprocess.run([
                str(self.bitcoin_cli_path),
                f"-rpcport={rpc_port}",
                f"-rpcuser={self.rpc_user}",
                f"-rpcpassword={self.rpc_pass}",
                "-datadir=" + str(node_dir),
                "sendtoaddress", dest_address, "0.001"
            ], capture_output=True, text=True)

            if result.returncode == 0:
                txids.append(result.stdout.strip())

        # Mine a block to confirm
        mine_result = subprocess.run([
            str(self.bitcoin_cli_path),
            f"-rpcport={rpc_port}",
            f"-rpcuser={self.rpc_user}",
            f"-rpcpassword={self.rpc_pass}",
            "-datadir=" + str(node_dir),
            "generatetoaddress", "1", dest_address
        ], capture_output=True, text=True)

        confirmed = 0
        if mine_result.returncode == 0:
            confirmed = len(txids)

        return {
            "submitted": len(txids),
            "confirmed": confirmed,
            "failed": tx_count - len(txids),
            "txids": txids,
            "block_mined": mine_result.returncode == 0
        }

    def collect_metrics(self) -> Dict[str, Any]:
        """Collect metrics from Bitcoin nodes"""
        metrics = {}

        # Get mempool info from first node
        if self.rpc_ports:
            rpc_port = self.rpc_ports[0]
            node_dir = self.network_dir / "node0"

            try:
                result = subprocess.run([
                    str(self.bitcoin_cli_path),
                    f"-rpcport={rpc_port}",
                    f"-rpcuser={self.rpc_user}",
                    f"-rpcpassword={self.rpc_pass}",
                    "-datadir=" + str(node_dir),
                    "getmempoolinfo"
                ], capture_output=True, text=True, timeout=5)

                if result.returncode == 0:
                    info = json.loads(result.stdout)
                    metrics["mempool_size"] = info.get("size", 0)
                    metrics["mempool_bytes"] = info.get("bytes", 0)
                    metrics["mempool_usage"] = info.get("usage", 0)
            except Exception:
                pass

            # Get blockchain info
            try:
                result = subprocess.run([
                    str(self.bitcoin_cli_path),
                    f"-rpcport={rpc_port}",
                    f"-rpcuser={self.rpc_user}",
                    f"-rpcpassword={self.rpc_pass}",
                    "-datadir=" + str(node_dir),
                    "getblockchaininfo"
                ], capture_output=True, text=True, timeout=5)

                if result.returncode == 0:
                    info = json.loads(result.stdout)
                    metrics["block_height"] = info.get("blocks", 0)
                    metrics["difficulty"] = info.get("difficulty", 0)
                    metrics["verification_progress"] = info.get("verificationprogress", 0)
            except Exception:
                pass

            # Get network info
            try:
                result = subprocess.run([
                    str(self.bitcoin_cli_path),
                    f"-rpcport={rpc_port}",
                    f"-rpcuser={self.rpc_user}",
                    f"-rpcpassword={self.rpc_pass}",
                    "-datadir=" + str(node_dir),
                    "getnetworkinfo"
                ], capture_output=True, text=True, timeout=5)

                if result.returncode == 0:
                    info = json.loads(result.stdout)
                    metrics["connections"] = info.get("connections", 0)
            except Exception:
                pass

        # System metrics
        try:
            import psutil
            metrics["cpu_percent"] = psutil.cpu_percent(interval=1)
            metrics["memory_mb"] = psutil.virtual_memory().used / (1024 * 1024)
        except ImportError:
            pass

        return metrics

    def stop_network(self) -> bool:
        """Stop all Bitcoin nodes"""
        print(f"[{self.name}] Stopping network")

        # Stop via RPC
        for i, rpc_port in enumerate(self.rpc_ports):
            node_dir = self.network_dir / f"node{i}"
            subprocess.run([
                str(self.bitcoin_cli_path),
                f"-rpcport={rpc_port}",
                f"-rpcuser={self.rpc_user}",
                f"-rpcpassword={self.rpc_pass}",
                "-datadir=" + str(node_dir),
                "stop"
            ], capture_output=True, text=True, timeout=10)

        # Wait for processes
        for proc in self.node_processes:
            try:
                proc.wait(timeout=15)
            except subprocess.TimeoutExpired:
                proc.kill()

        self.node_processes = []

        # Clean up
        if self.network_dir and self.network_dir.exists():
            shutil.rmtree(self.network_dir, ignore_errors=True)

        return True


if __name__ == "__main__":
    main(BitcoinAdapter)
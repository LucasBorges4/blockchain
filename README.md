# Blockchain Consensus Lab

Experimental environment for cloning, building, testing, and benchmarking 12 blockchain consensus algorithms.

## Overview

This project implements a systematic framework for experimental evaluation of blockchain consensus protocols. It follows Spec-Driven Development (SDD) methodology with clear phases, acceptance criteria, and automated tooling.

## Target Protocols

| # | Algorithm | Repository | Language | Type |
|---|---|---|---|---|
| 1 | Nakamoto Consensus (Bitcoin PoW) | [bitcoin/bitcoin](https://github.com/bitcoin/bitcoin) | C++ | Production |
| 2 | Gasper (Ethereum PoS) | [ethereum/consensus-specs](https://github.com/ethereum/consensus-specs) | Python/MD | Specification |
| 3 | HotStuff | [relab/hotstuff](https://github.com/relab/hotstuff) | C++ | Academic Prototype |
| 4 | Narwhal + Bullshark | [MystenLabs/sui](https://github.com/MystenLabs/sui) | Rust | Production (Sui) |
| 5 | Avalanche | [ava-labs/avalanchego](https://github.com/ava-labs/avalanchego) | Go | Production |
| 6 | Algorand BA* | [algorand/go-algorand](https://github.com/algorand/go-algorand) | Go | Production |
| 7 | CometBFT (Tendermint) | [cometbft/cometbft](https://github.com/cometbft/cometbft) | Go | Production |
| 8 | Solana Tower BFT | [anza-xyz/agave](https://github.com/anza-xyz/agave) | Rust | Production |
| 9 | Ouroboros | [IntersectMBO/ouroboros-consensus](https://github.com/IntersectMBO/ouroboros-consensus) | Haskell | Academic/Production |
| 10 | HoneyBadgerBFT | [initc3/HoneyBadgerBFT-Python](https://github.com/initc3/HoneyBadgerBFT-Python) | Python | Academic Prototype |
| 11 | PHANTOM / GHOSTDAG | [kaspanet/rusty-kaspa](https://github.com/kaspanet/rusty-kaspa) | Rust | Production |
| 12 | Stellar Consensus Protocol | [stellar/stellar-core](https://github.com/stellar/stellar-core) | C++ | Production |

## Quick Start

```bash
# Full setup (clone, check deps, build, test)
make setup

# Or step by step:
make clone      # Clone all 12 repositories
make check      # Verify dependencies & versions
make build      # Compile all projects
make test       # Run native tests
make adapters   # Build/verify adapters
make experiment # Run experiments
make benchmark  # Run benchmark suite
make report     # Generate charts & reports
```

## Project Structure

```
blockchain-consensus-lab/
├── SPEC.md                 # Full specification (read first)
├── Makefile                # Automation commands
├── docker-compose.yml      # Containerized environments
├── .env.example            # Environment variables template
├── repositories/           # Cloned upstream repos (12)
├── adapters/               # Experiment adapters per protocol
├── experiments/            # Experiment definitions & configs
├── scripts/                # Automation scripts
├── benchmarks/             # Workloads, configs, results
├── metrics/                # Collection, parsing, export
├── reports/                # Raw, processed, figures, tables
└── logs/                   # Build & test logs
```

## Requirements

- Linux (tested on Manjaro/Arch)
- Git, Make, Bash
- Docker or Podman (for isolation)
- Python 3.10+
- Per-language toolchains (see `make check` output):
  - C++: gcc/clang, cmake, make
  - Go: go 1.21+
  - Rust: cargo, rustc 1.70+
  - Haskell: ghc, cabal/stack
  - Python: 3.10+, pip

## Documentation

- **[SPEC.md](SPEC.md)** — Complete specification with phases, acceptance criteria, and deliverables
- **`reports/processed/`** — Generated reports (after running experiments)
- **`reports/figures/`** — Comparative charts (after `make report`)

## Experiment Categories

1. **Basic Functionality** — Consensus establishment & operation processing
2. **Scalability** — Varying node count (4, 7, 10, 16, 25, 50)
3. **Latency** — Submission to confirmation (mean, P95, P99)
4. **Throughput** — Varying load (100 to 100k transactions)
5. **Fault Tolerance** — Crashes, partitions, Byzantine behavior
6. **Network Conditions** — Latency, jitter, loss, bandwidth limits

## Output Formats

- Raw data: CSV, JSON (`benchmarks/results/`, `reports/raw/`)
- Processed: Markdown tables (`reports/tables/`)
- Visualizations: PNG charts (`reports/figures/`)
- Logs: Text (`logs/`)

## Reproducibility

Each experiment run records:
- Exact repository commits
- Toolchain versions
- Configuration parameters
- Random seeds
- Environment details

## License

Experimental research code. Individual repositories retain their original licenses.

## Contributing

This is a research framework. See SPEC.md for extension points.
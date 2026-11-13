# Blockchain Consensus Lab — Specification Document

## 1. Project Overview

**Project Name:** blockchain-consensus-lab  
**Purpose:** Experimental environment for cloning, building, testing, and benchmarking 12 blockchain consensus algorithms  
**Type:** Engineering & experimentation (not production system)  
**Methodology:** Spec-Driven Development (SDD)

## 2. Target Repositories & Protocols

| # | Algorithm | Repository | Type | Language | Status |
|---|---|---|---|---|---|
| 1 | Nakamoto Consensus / Bitcoin PoW | https://github.com/bitcoin/bitcoin | Production implementation | C++ | ⬜ Pending |
| 2 | Gasper / Ethereum PoS | https://github.com/ethereum/consensus-specs | Specification + reference tests | Python/Markdown | ⬜ Pending |
| 3 | HotStuff | https://github.com/relab/hotstuff | Academic prototype | C++ | ⬜ Pending |
| 4 | Narwhal + Bullshark | https://github.com/MystenLabs/sui | Production (Sui blockchain) | Rust | ⬜ Pending |
| 5 | Avalanche | https://github.com/ava-labs/avalanchego | Production implementation | Go | ⬜ Pending |
| 6 | Algorand BA* | https://github.com/algorand/go-algorand | Production implementation | Go | ⬜ Pending |
| 7 | Tendermint / CometBFT | https://github.com/cometbft/cometbft | Production implementation | Go | ⬜ Pending |
| 8 | Solana Tower BFT | https://github.com/anza-xyz/agave | Production implementation | Rust | ⬜ Pending |
| 9 | Ouroboros | https://github.com/IntersectMBO/ouroboros-consensus | Academic/Production (Cardano) | Haskell | ⬜ Pending |
| 10 | HoneyBadgerBFT | https://github.com/initc3/HoneyBadgerBFT-Python | Academic prototype | Python | ⬜ Pending |
| 11 | PHANTOM / GHOSTDAG | https://github.com/kaspanet/rusty-kaspa | Production implementation | Rust | ⬜ Pending |
| 12 | Stellar Consensus Protocol (SCP) | https://github.com/stellar/stellar-core | Production implementation | C++ | ⬜ Pending |

### Special Notes
- **Ethereum consensus-specs**: Not a full client; contains specs and reference tests only
- **Sui (Narwhal/Bullshark)**: Need to identify consensus-specific components within the larger repo
- **HotStuff & HoneyBadgerBFT**: Academic prototypes - document maturity level
- **Rusty-Kaspa**: Implements GHOSTDAG; may not reproduce all PHANTOM experiments
- **CometBFT**: Successor to Tendermint Core

## 3. Directory Structure

```
blockchain-consensus-lab/
│
├── README.md
├── SPEC.md
├── docker-compose.yml
├── Makefile
├── .env.example
│
├── repositories/
│   ├── bitcoin/
│   ├── ethereum-consensus-specs/
│   ├── hotstuff/
│   ├── sui/
│   ├── avalanchego/
│   ├── go-algorand/
│   ├── cometbft/
│   ├── agave/
│   ├── ouroboros-consensus/
│   ├── honeybadger/
│   ├── rusty-kaspa/
│   └── stellar-core/
│
├── adapters/
│   ├── bitcoin/
│   ├── ethereum/
│   ├── hotstuff/
│   ├── narwhal-bullshark/
│   ├── avalanche/
│   ├── algorand/
│   ├── cometbft/
│   ├── solana/
│   ├── ouroboros/
│   ├── honeybadger/
│   ├── ghostdag/
│   └── stellar/
│
├── experiments/
│   ├── baseline/
│   ├── scalability/
│   ├── latency/
│   ├── fault-tolerance/
│   ├── throughput/
│   └── network-conditions/
│
├── scripts/
│   ├── clone_repositories.sh
│   ├── check_dependencies.sh
│   ├── build_all.sh
│   ├── run_tests.sh
│   ├── run_experiments.sh
│   └── collect_metrics.sh
│
├── benchmarks/
│   ├── workloads/
│   ├── configurations/
│   └── results/
│
├── metrics/
│   ├── collector/
│   ├── parser/
│   └── exporter/
│
├── reports/
│   ├── raw/
│   ├── processed/
│   ├── figures/
│   └── tables/
│
└── logs/
```

## 4. Phase Specifications

### Phase 1: Cloning & Configuration (Stage 2)
**Objective:** Automated cloning of all 12 repositories with version tracking

**Acceptance Criteria:**
- [ ] All 12 repositories cloned to `repositories/`
- [ ] Origin URL recorded for each
- [ ] Exact commit hash recorded for each
- [ ] Dependencies identified per repository
- [ ] Compiler/tool versions verified
- [ ] Execution environment prepared
- [ ] Version conflicts documented
- [ ] Installation report generated (`reports/raw/installation_report.md`)

**Commands to implement:**
```bash
make clone          # Clone all repositories
make check          # Check dependencies & versions
```

### Phase 2: Compilation & Native Tests (Stage 3)
**Objective:** Build each project per official documentation and run native tests

**Acceptance Criteria per repository:**
- [ ] Official build procedure identified and documented
- [ ] Project compiles successfully (or failure documented with cause)
- [ ] Unit tests executed and results recorded
- [ ] Integration tests executed and results recorded
- [ ] System tests executed and results recorded
- [ ] Errors and missing dependencies logged
- [ ] Individual build logs saved to `logs/build/<repo>.log`
- [ ] Test logs saved to `logs/test/<repo>.log`
- [ ] Compilation report generated with schema:
  ```
  protocolo | repositorio | commit | ambiente | dependencias | compilacao | testes_unitarios | testes_integracao | testes_sistema | resultado | observacoes
  ```

**Commands to implement:**
```bash
make build          # Build all repositories
make test           # Run native tests for all repositories
```

### Phase 3: Experimentation Environments / Adapters (Stage 4)
**Objective:** Create adapters providing common experimentation interface

**Adapter Interface (conceptual):**
```python
class ConsensusAdapter:
    def configure(self, config: Dict) -> bool
    def start_network(self, num_nodes: int) -> bool
    def submit_workload(self, workload: Workload) -> Result
    def collect_metrics(self) -> Metrics
    def stop_network(self) -> bool
```

**Acceptance Criteria per adapter:**
- [ ] Node initialization supported
- [ ] Participant count configuration
- [ ] Consensus parameter configuration
- [ ] Transaction/message generation
- [ ] Load submission
- [ ] Metrics collection
- [ ] Controlled shutdown
- [ ] Results export (CSV/JSON)
- [ ] Documented limitations (what's NOT supported)

**Commands to implement:**
```bash
make adapters       # Build/verify all adapters
```

### Phase 4: Experimental Tests (Stage 5)
**Objective:** Execute 6 experiment categories

#### Experiment A: Basic Functionality
- **Variables:** Node count, transaction count, message size, execution time
- **Verify:** Correct initialization, agreement, data integrity, finalization, no inconsistencies

#### Experiment B: Scalability
- **Node counts:** N = 4, 7, 10, 16, 25, 50 (protocol-permitting)
- **Metrics:** Consensus time, throughput, latency, CPU, memory, network traffic

#### Experiment C: Latency
- **Measure:** Time from submission to confirmation (per protocol's finality definition)
- **Collect:** Mean, median, P95, P99, std dev
- **Distinguish:** Initial confirmation, probabilistic confirmation, deterministic finality

#### Experiment D: Throughput
- **Load levels:** 100, 1,000, 10,000, 100,000 transactions
- **Metrics:** TPS (processed), TPS (confirmed), rejected, pending, total processing time

#### Experiment E: Fault Tolerance
- **Scenarios:** Node crash, leader crash, communication delay, message loss, network partition, Byzantine behavior, node recovery
- **Verify:** Safety, liveness, consensus continuity, recovery, state divergence

#### Experiment F: Network Conditions
- **Conditions:** Low-latency LAN, artificial latency, jitter, packet loss, bandwidth limits
- **Record:** Exact configuration per scenario

**Execution Requirements:**
- Minimum 5 repetitions per experiment
- Fixed seeds where applicable
- Configuration & environment recorded
- Raw data stored (CSV/JSON)
- Statistics computed (mean, median, std dev, percentiles)

**Commands to implement:**
```bash
make experiment     # Run all configured experiments
make benchmark      # Run validated benchmark experiments
```

### Phase 5: Metrics Collection (Stage 6)
**Objective:** Automated collection of standardized metrics

| Metric | Unit | Collection Method |
|---|---|---|
| Throughput | TPS | Adapter + parser |
| Latency (mean) | ms/s | Adapter + parser |
| Latency P95 | ms/s | Adapter + parser |
| Latency P99 | ms/s | Adapter + parser |
| CPU | % | System monitoring |
| Memory | MB/GB | System monitoring |
| Network Traffic | MB/s | System monitoring |
| Consensus Messages | count | Adapter |
| Communication Volume | bytes | Adapter |
| Recovery Time | s | Adapter |
| Operations Confirmed | count | Adapter |
| Operations Rejected | count | Adapter |

**Differentiation:** Consensus messages vs data dissemination messages

**Commands to implement:**
```bash
make collect        # Collect metrics from experiment runs
```

### Phase 6: Standardization & Comparability (Stage 7)
**Objective:** Create experimental compatibility matrix

**Classification per protocol:**
- [ ] Directly testable
- [ ] Testable with adapter
- [ ] Testable via reference tests only
- [ ] Testable only in specific environment
- [ ] Not directly executable

**Non-comparable markings:** When experiment doesn't apply to architecture (e.g., DAG protocols evaluated as linear chains)

**Output:** `reports/processed/compatibility_matrix.md`

### Phase 7: Visualization (Stage 8)
**Objective:** Auto-generate comparative charts

**Required Charts:**
1. TPS by protocol
2. Mean latency by protocol
3. Latency P95 & P99
4. CPU consumption
5. Memory consumption
6. Network traffic
7. Scalability vs node count
8. Behavior under faults
9. Recovery time

**Chart Requirements:**
- Protocol identification
- Units labeled
- Experimental configuration noted
- Node count noted
- Repetition count noted
- Non-comparable results marked

**Tools:** Python, Pandas, Matplotlib/Seaborn

**Output:** `reports/figures/*.png`, `reports/tables/*.csv`

**Commands to implement:**
```bash
make report         # Generate all charts, tables, reports
```

### Phase 8: Automation (Stage 9)
**Objective:** Single-command execution pipeline

**Makefile Targets:**
```bash
make setup          # Full environment setup (clone + check + build)
make clone          # Clone repositories only
make check          # Verify dependencies & versions
make build          # Compile all projects
make test           # Run native tests
make adapters       # Build/verify adapters
make experiment     # Run experiments
make benchmark      # Run benchmark suite
make collect        # Collect metrics
make report         # Generate visualizations & reports
make clean          # Clean build artifacts (non-destructive)
make distclean      # Full clean (confirm required)
```

**Safety:** No destructive commands without confirmation

## 5. Quality Requirements

- [ ] Modular code organization
- [ ] Reproducible scripts (fixed versions, pinned dependencies)
- [ ] Detailed logging (stdout + file)
- [ ] Versioned configurations (in repo)
- [ ] Project isolation (no shared mutable state)
- [ ] Error handling with clear messages
- [ ] Installation documentation
- [ ] Results export (CSV, JSON)
- [ ] Commit hashes recorded for all repos
- [ ] Separation: real results vs reference/spec results

## 6. Environment

- **Primary:** Linux Manjaro (Arch-based)
- **Portability:** Architecture should adapt to other Linux distros
- **Containerization:** Docker/Podman for isolation where needed
- **Tools:** Git, Make, Bash, Python 3.10+, Docker/Podman

## 7. Execution Order (Mandatory)

1. **Stage 1** ✓ Create structure & SPEC.md (this document)
2. **Stage 2** Clone 12 repos & record versions
3. **Stage 3** Verify dependencies & compilability
3. **Stage 4** Run native tests
4. **Stage 5** Classify experimental viability per protocol
5. **Stage 6** Implement adapters
6. **Stage 7** Run controlled experiments
7. **Stage 8** Collect metrics & generate reports

**Rule:** Do not advance past critical failures. Document blockers and proceed only on independent paths.

## 8. Deliverables (Final)

1. [ ] Functional organized project
2. [ ] 12 cloned repositories (where accessible)
3. [ ] Compilation report (`reports/processed/compilation_report.md`)
4. [ ] Native test report (`reports/processed/native_test_report.md`)
5. [ ] Implemented adapters (`adapters/*/`)
6. [ ] Executable experiments (`experiments/*/`)
8. [ ] Raw data (CSV/JSON in `benchmarks/results/`, `reports/raw/`)
9. [ ] Comparative charts (`reports/figures/`)
10. [ ] Reproduction documentation (`README.md`, `docs/`)
11. [ ] Tested protocols matrix (`reports/processed/compatibility_matrix.md`)

## 9. Acceptance Criteria for Project Completion

Another researcher must be able to:
- [ ] Clone this repository
- [ ] Run `make setup` (or equivalent steps)
- [ ] Identify exact versions/commits used
- [ ] Execute experiments via `make experiment`
- [ ] Verify results match reported data
- [ ] Extend/modify experiments

---

**Document Version:** 1.0  
**Created:** $(date -I)  
**Status:** Stage 1 Complete — Ready for Stage 2 Implementation
# Blockchain Consensus Lab — Makefile
# Automation for cloning, building, testing, and benchmarking 12 consensus protocols

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Project root
ROOT_DIR := $(shell pwd)
REPOS_DIR := $(ROOT_DIR)/repositories
ADAPTERS_DIR := $(ROOT_DIR)/adapters
EXPERIMENTS_DIR := $(ROOT_DIR)/experiments
SCRIPTS_DIR := $(ROOT_DIR)/scripts
BENCHMARKS_DIR := $(ROOT_DIR)/benchmarks
METRICS_DIR := $(ROOT_DIR)/metrics
REPORTS_DIR := $(ROOT_DIR)/reports
LOGS_DIR := $(ROOT_DIR)/logs

# Repository definitions: name | url | subdir (if different)
REPOS := \
	bitcoin|https://github.com/bitcoin/bitcoin.git|bitcoin \
	ethereum-consensus-specs|https://github.com/ethereum/consensus-specs.git|ethereum-consensus-specs \
	hotstuff|https://github.com/relab/hotstuff.git|hotstuff \
	sui|https://github.com/MystenLabs/sui.git|sui \
	avalanchego|https://github.com/ava-labs/avalanchego.git|avalanchego \
	go-algorand|https://github.com/algorand/go-algorand.git|go-algorand \
	cometbft|https://github.com/cometbft/cometbft.git|cometbft \
	agave|https://github.com/anza-xyz/agave.git|agave \
	ouroboros-consensus|https://github.com/IntersectMBO/ouroboros-consensus.git|ouroboros-consensus \
	honeybadger|https://github.com/initc3/HoneyBadgerBFT-Python.git|honeybadger \
	rusty-kaspa|https://github.com/kaspanet/rusty-kaspa.git|rusty-kaspa \
	stellar-core|https://github.com/stellar/stellar-core.git|stellar-core

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# ============================================================================
# HELP
# ============================================================================
help:
	@echo "$(BLUE)Blockchain Consensus Lab — Available Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Setup & Configuration:$(NC)"
	@echo "  make setup          - Full environment setup (clone + check + build)"
	@echo "  make clone          - Clone all 12 repositories"
	@echo "  make check          - Verify dependencies & toolchain versions"
	@echo ""
	@echo "$(GREEN)Build & Test:$(NC)"
	@echo "  make build          - Compile all projects (per official docs)"
	@echo "  make test           - Run native tests for all repositories"
	@echo "  make adapters       - Build/verify experiment adapters"
	@echo ""
	@echo "$(GREEN)Experiments & Benchmarks:$(NC)"
	@echo "  make experiment     - Run all configured experiments"
	@echo "  make benchmark      - Run validated benchmark suite"
	@echo "  make collect        - Collect metrics from experiment runs"
	@echo "  make report         - Generate charts, tables, and reports"
	@echo ""
	@echo "$(GREEN)Maintenance:$(NC)"
	@echo "  make clean          - Clean build artifacts (non-destructive)"
	@echo "  make distclean      - Full clean including cloned repos (requires confirmation)"
	@echo "  make status         - Show status of all repositories"
	@echo "  make versions       - Show recorded commit hashes"
	@echo ""

# ============================================================================
# SETUP PIPELINE
# ============================================================================
setup: clone check build test
	@echo "$(GREEN)✓ Setup complete$(NC)"

# ============================================================================
# PHASE 1: CLONE REPOSITORIES
# ============================================================================
clone:
	@$(SCRIPTS_DIR)/clone_repositories.sh

record-versions:
	@$(SCRIPTS_DIR)/clone_repositories.sh && echo "$(GREEN)Versions recorded$(NC)"

# Record commit hashes after clone
record-versions:
	@echo "$(BLUE)Recording repository versions...$(NC)"
	@mkdir -p $(REPORTS_DIR)/raw
	@echo "# Repository Versions" > $(REPORTS_DIR)/raw/versions.md
	@echo "" >> $(REPORTS_DIR)/raw/versions.md
	@echo "| Repository | Commit Hash | Branch | Date |" >> $(REPORTS_DIR)/raw/versions.md
	@echo "|------------|-------------|--------|------|" >> $(REPORTS_DIR)/raw/versions.md
	@for repo in $(shell echo $(REPOS) | tr ' ' '\n' | cut -d'|' -f3); do \
		if [ -d "$(REPOS_DIR)/$$repo/.git" ]; then \
			hash=$$(cd $(REPOS_DIR)/$$repo && git rev-parse HEAD); \
			branch=$$(cd $(REPOS_DIR)/$$repo && git branch --show-current); \
			date=$$(cd $(REPOS_DIR)/$$repo && git log -1 --format=%ci); \
			url=$$(echo $(REPOS) | tr ' ' '\n' | grep "|$$repo|" | cut -d'|' -f2); \
			echo "| [$$repo]($$url) | \`$$hash\` | $$branch | $$date |" >> $(REPORTS_DIR)/raw/versions.md; \
		else \
			echo "| $$repo | NOT CLONED | - | - |" >> $(REPORTS_DIR)/raw/versions.md; \
		fi; \
	done
	@echo "$(GREEN)✓ Versions recorded to $(REPORTS_DIR)/raw/versions.md$(NC)"

# ============================================================================
# PHASE 2: CHECK DEPENDENCIES
# ============================================================================
check:
	@echo "$(BLUE)Checking dependencies and toolchain versions...$(NC)"
	@mkdir -p $(LOGS_DIR)/check
	@$(SCRIPTS_DIR)/check_dependencies.sh 2>&1 | tee $(LOGS_DIR)/check/dependencies.log
	@echo "$(GREEN)✓ Dependency check complete$(NC)"

# ============================================================================
# PHASE 3: BUILD ALL PROJECTS
# ============================================================================
build:
	@echo "$(BLUE)Building all projects...$(NC)"
	@mkdir -p $(LOGS_DIR)/build
	@$(SCRIPTS_DIR)/build_all.sh 2>&1 | tee $(LOGS_DIR)/build/build_all.log
	@echo "$(GREEN)✓ Build phase complete$(NC)"

# ============================================================================
# PHASE 4: RUN NATIVE TESTS
# ============================================================================
test:
	@echo "$(BLUE)Running native tests for all repositories...$(NC)"
	@mkdir -p $(LOGS_DIR)/test
	@$(SCRIPTS_DIR)/run_tests.sh 2>&1 | tee $(LOGS_DIR)/test/test_all.log
	@echo "$(GREEN)✓ Test phase complete$(NC)"

# ============================================================================
# PHASE 5: BUILD ADAPTERS
# ============================================================================
adapters:
	@echo "$(BLUE)Building/verifying experiment adapters...$(NC)"
	@mkdir -p $(LOGS_DIR)/adapters
	@for adapter in $(ADAPTERS_DIR)/*/; do \
		if [ -f "$$adapter/Makefile" ] || [ -f "$$adapter/build.sh" ] || [ -f "$$adapter/pyproject.toml" ] || [ -f "$$adapter/Cargo.toml" ] || [ -f "$$adapter/go.mod" ]; then \
			echo "$(YELLOW)Building adapter: $$(basename $$adapter)$(NC)"; \
			cd $$adapter && $(MAKE) build 2>&1 | tee -a $(LOGS_DIR)/adapters/adapters.log || true; \
		else \
			echo "$(YELLOW)No build system found for $$(basename $$adapter), skipping$(NC)"; \
		fi; \
	done
	@echo "$(GREEN)✓ Adapters phase complete$(NC)"

# ============================================================================
# PHASE 6: RUN EXPERIMENTS
# ============================================================================
experiment:
	@echo "$(BLUE)Running experiments...$(NC)"
	@mkdir -p $(LOGS_DIR)/experiment
	@$(SCRIPTS_DIR)/run_experiments.sh 2>&1 | tee $(LOGS_DIR)/experiment/experiments.log
	@echo "$(GREEN)✓ Experiment phase complete$(NC)"

benchmark: experiment collect report
	@echo "$(GREEN)✓ Benchmark suite complete$(NC)"

# ============================================================================
# PHASE 7: COLLECT METRICS
# ============================================================================
collect:
	@echo "$(BLUE)Collecting metrics...$(NC)"
	@mkdir -p $(LOGS_DIR)/metrics
	@$(SCRIPTS_DIR)/collect_metrics.sh 2>&1 | tee $(LOGS_DIR)/metrics/collect.log
	@echo "$(GREEN)✓ Metrics collection complete$(NC)"

# ============================================================================
# PHASE 8: GENERATE REPORTS
# ============================================================================
report:
	@echo "$(BLUE)Generating reports and visualizations...$(NC)"
	@mkdir -p $(LOGS_DIR)/report
	@python3 $(SCRIPTS_DIR)/generate_report.py 2>&1 | tee $(LOGS_DIR)/report/generate.log
	@echo "$(GREEN)✓ Report generation complete$(NC)"

# ============================================================================
# STATUS & INFO
# ============================================================================
status:
	@echo "$(BLUE)Repository Status:$(NC)"
	@for repo in $(shell echo $(REPOS) | tr ' ' '\n' | cut -d'|' -f3); do \
		if [ -d "$(REPOS_DIR)/$$repo/.git" ]; then \
			cd $(REPOS_DIR)/$$repo && \
			branch=$$(git branch --show-current 2>/dev/null || echo "detached"); \
			hash=$$(git rev-parse --short HEAD 2>/dev/null); \
			changes=$$(git status --porcelain 2>/dev/null | wc -l); \
			if [ $$changes -eq 0 ]; then \
				echo "  $(GREEN)✓$(NC) $$repo [$$branch] $$hash"; \
			else \
				echo "  $(YELLOW)⚠$(NC) $$repo [$$branch] $$hash ($$changes uncommitted changes)"; \
			fi; \
		else \
			echo "  $(RED)✗$(NC) $$repo (not cloned)"; \
		fi; \
	done

versions:
	@if [ -f $(REPORTS_DIR)/raw/versions.md ]; then \
		cat $(REPORTS_DIR)/raw/versions.md; \
	else \
		echo "$(YELLOW)No versions recorded yet. Run 'make record-versions'$(NC)"; \
	fi

# ============================================================================
# CLEANUP
# ============================================================================
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@for repo in $(shell echo $(REPOS) | tr ' ' '\n' | cut -d'|' -f3); do \
		if [ -d "$(REPOS_DIR)/$$repo" ]; then \
			cd $(REPOS_DIR)/$$repo && \
			if [ -f "Makefile" ]; then make clean 2>/dev/null || true; fi; \
			if [ -f "Cargo.toml" ]; then cargo clean 2>/dev/null || true; fi; \
			if [ -f "go.mod" ]; then go clean -cache 2>/dev/null || true; fi; \
			if [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true; fi; \
		fi; \
	done
	@rm -rf $(LOGS_DIR)/build $(LOGS_DIR)/test $(LOGS_DIR)/adapters
	@echo "$(GREEN)✓ Clean complete$(NC)"

distclean:
	@echo "$(RED)WARNING: This will delete ALL cloned repositories and generated data!$(NC)"
	@read -p "Are you sure? Type 'yes' to confirm: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		rm -rf $(REPOS_DIR)/* $(ADAPTERS_DIR)/* $(EXPERIMENTS_DIR)/* $(BENCHMARKS_DIR)/results $(METRICS_DIR)/* $(REPORTS_DIR)/* $(LOGS_DIR)/*; \
		echo "$(GREEN)✓ Full clean complete$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

# ============================================================================
# PHONY TARGETS
# ============================================================================
.PHONY: help setup clone record-versions check build test adapters experiment benchmark collect report status versions clean distclean
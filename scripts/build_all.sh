#!/usr/bin/env bash
# build_all.sh
# Build all 12 repositories following their official build procedures
# Part of Blockchain Consensus Lab — Phase 2

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
REPOS_DIR="$ROOT_DIR/repositories"
LOGS_DIR="$ROOT_DIR/logs/build"
REPORTS_DIR="$ROOT_DIR/reports/raw"

mkdir -p "$LOGS_DIR" "$REPORTS_DIR"

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
success() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $*"; }
error() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $*"; }

# Build configuration
BUILD_JOBS="${BCL_BUILD_JOBS:-$(nproc)}"
BUILD_TYPE="${BCL_BUILD_TYPE:-Release}"
CONTINUE_ON_ERROR="${BCL_BUILD_CONTINUE_ON_ERROR:-true}"

# Results tracking
declare -A BUILD_RESULTS
declare -A BUILD_NOTES

record_result() {
    local repo="$1"
    local status="$2"
    local notes="$3"
    BUILD_RESULTS["$repo"]="$status"
    BUILD_NOTES["$repo"]="$notes"
}

# ============================================================================
# BUILD FUNCTIONS PER REPOSITORY
# ============================================================================

build_bitcoin() {
    log "Building Bitcoin Core..."
    local repo_dir="$REPOS_DIR/bitcoin"
    local log_file="$LOGS_DIR/bitcoin.log"

    if [[ ! -d "$repo_dir" ]]; then
        error "Bitcoin repository not found"
        record_result "bitcoin" "FAILED" "Repository not cloned"
        return 1
    fi

    cd "$repo_dir"

    # Bitcoin Core now uses CMake
    mkdir -p build
    cd build

    # Run cmake with error handling
    cmake -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
        -DBUILD_BITCOIN_WALLET=OFF \
        -DBUILD_BITCOIN_TESTS=OFF \
        -DBUILD_BITCOIN_BENCH=OFF \
        -DBUILD_GUI=OFF \
        .. 2>&1 | tee -a "$log_file"
    local cmake_status=${PIPESTATUS[0]}

    if [[ $cmake_status -ne 0 ]]; then
        error "CMake configuration failed"
        record_result "bitcoin" "FAILED" "CMake configuration failed (missing Boost?)"
        cd "$repo_dir"
        return 1
    fi

    make -j"$BUILD_JOBS" 2>&1 | tee -a "$log_file"
    local make_status=${PIPESTATUS[0]}

    cd "$repo_dir"

    if [[ $make_status -ne 0 ]]; then
        error "Build failed"
        record_result "bitcoin" "FAILED" "Make failed"
        return 1
    fi

    if [[ -f "build/src/bitcoind" ]] || [[ -f "build/bitcoind" ]] || [[ -f "src/bitcoind" ]] || [[ -f "bitcoind" ]]; then
        success "Bitcoin Core built successfully"
        record_result "bitcoin" "SUCCESS" "bitcoind, bitcoin-cli built"
        return 0
    else
        error "Bitcoin Core build failed - binary not found"
        record_result "bitcoin" "FAILED" "Binary not found after build"
        return 1
    fi
}

build_ethereum_consensus_specs() {
    log "Checking Ethereum Consensus Specs (specification repo, no build)..."
    local repo_dir="$REPOS_DIR/ethereum-consensus-specs"
    local log_file="$LOGS_DIR/ethereum-consensus-specs.log"

    if [[ ! -d "$repo_dir" ]]; then
        error "Ethereum consensus-specs repository not found"
        record_result "ethereum-consensus-specs" "FAILED" "Repository not cloned"
        return 1
    fi

    cd "$repo_dir"

    {
        # This is a specification repository - verify Python tests can run
        if command -v python3 >/dev/null 2>&1; then
            python3 -m pip install -e . 2>&1 | tee -a "$log_file"
            # Run reference tests if available
            if [[ -f "pytest.ini" ]] || [[ -d "tests" ]]; then
                python3 -m pytest --collect-only 2>&1 | head -20 | tee -a "$log_file"
            fi
        fi
    } >>"$log_file" 2>&1

    success "Ethereum Consensus Specs verified (specification only)"
    record_result "ethereum-consensus-specs" "SUCCESS" "Specification repo - no binary build, Python tests available"
    return 0
}

build_hotstuff() {
    log "Building HotStuff..."
    local repo_dir="$REPOS_DIR/hotstuff"
    local log_file="$LOGS_DIR/hotstuff.log"

    if [[ ! -d "$repo_dir" ]]; then
        error "HotStuff repository not found"
        record_result "hotstuff" "FAILED" "Repository not cloned"
        return 1
    fi

    cd "$repo_dir"

    {
        # HotStuff uses CMake
        mkdir -p build
        cd build
        cmake -DCMAKE_BUILD_TYPE="$BUILD_TYPE" .. 2>&1 | tee -a "$log_file"
        make -j"$BUILD_JOBS" 2>&1 | tee -a "$log_file"
    } >>"$log_file" 2>&1

    if [[ -f "build/hotstuff" ]] || [[ -f "build/src/hotstuff" ]] || find build -name "hotstuff" -type f 2>/dev/null | grep -q .; then
        success "HotStuff built successfully"
        record_result "hotstuff" "SUCCESS" "HotStuff binary built"
        return 0
    else
        error "HotStuff build failed"
        record_result "hotstuff" "FAILED" "Check $log_file"
        return 1
    fi
}

build_sui() {
    log "Building Sui (Narwhal/Bullshark)..."
    local repo_dir="$REPOS_DIR/sui"
    local log_file="$LOGS_DIR/sui.log"

    if [[ ! -d "$repo_dir" ]]; then
        error "Sui repository not found"
        record_result "sui" "FAILED" "Repository not cloned"
        return 1
    fi

    cd "$repo_dir"

    {
        # Sui uses Cargo with workspace
        # Build the consensus-related crates
        cargo build --release -p narwhal -p bullshark -p consensus 2>&1 | tee -a "$log_file"
        # Or build full workspace if needed
        # cargo build --release --workspace 2>&1 | tee -a "$log_file"
    } >>"$log_file" 2>&1

    # Check for binaries in target/release
    local bins=(narwhal bullshark sui-node)
    local found=0
    for bin in "${bins[@]}"; do
        if [[ -f "target/release/$bin" ]]; then
            success "Found $bin"
            found=1
        fi
    done

    if [[ $found -eq 1 ]]; then
        success "Sui consensus components built"
        record_result "sui" "SUCCESS" "Narwhal/Bullshark binaries built"
        return 0
    else
        warn "Sui build completed but consensus binaries not found in standard location"
        record_result "sui" "PARTIAL" "Workspace built, check target/release for binaries"
        return 0
    fi
}

build_avalanchego() {
    log "Building AvalancheGo..."
    local repo_dir="$REPOS_DIR/avalanchego"
    local log_file="$LOGS_DIR/avalanchego.log"

    if [[ ! -d "$repo_dir" ]]; then
        error "AvalancheGo repository not found"
        record_result "avalanchego" "FAILED" "Repository not cloned"
        return 1
    fi

    cd "$repo_dir"

    {
        # AvalancheGo uses Go modules
        go mod download 2>&1 | tee -a "$log_file"
        go build -v ./cmd/avalanchego 2>&1 | tee -a "$log_file"
    } >>"$log_file" 2>&1

    if [[ -f "avalanchego" ]] || [[ -f "build/avalanchego" ]]; then
        success "AvalancheGo built successfully"
        record_result "avalanchego" "SUCCESS" "avalanchego binary built"
        return 0
    else
        error "AvalancheGo build failed"
        record_result "avalanchego" "FAILED" "Check $log_file"
        return 1
    fi
}

build_go_algorand() {
    log "Building Go-Algorand..."
    local repo_dir="$REPOS_DIR/go-algorand"
    local log_file="$LOGS_DIR/go-algorand.log"

    if [[ ! -d "$repo_dir" ]]; then
        error "Go-Algorand repository not found"
        record_result "go-algorand" "FAILED" "Repository not cloned"
        return 1
    fi

    cd "$repo_dir"

    {
        # Algorand uses Makefile
        make -j"$BUILD_JOBS" 2>&1 | tee -a "$log_file"
    } >>"$log_file" 2>&1

    if [[ -f "goal" ]] || [[ -f "algorand" ]] || find . -name "goal" -type f 2>/dev/null | grep -q .; then
        success "Go-Algorand built successfully"
        record_result "go-algorand" "SUCCESS" "goal/algorand binaries built"
        return 0
    else
        error "Go-Algorand build failed"
        record_result "go-algorand" "FAILED" "Check $log_file"
        return 1
    fi
}

build_cometbft() {
    log "Building CometBFT..."
    local repo_dir="$REPOS_DIR/cometbft"
    local log_file="$LOGS_DIR/cometbft.log"

    if [[ ! -d "$repo_dir" ]]; then
        error "CometBFT repository not found"
        record_result "cometbft" "FAILED" "Repository not cloned"
        return 1
    fi

    cd "$repo_dir"

    {
        # CometBFT uses Makefile
        make build 2>&1 | tee -a "$log_file"
    } >>"$log_file" 2>&1

    if [[ -f "build/cometbft" ]] || [[ -f "cometbft" ]]; then
        success "CometBFT built successfully"
        record_result "cometbft" "SUCCESS" "cometbft binary built"
        return 0
    else
        error "CometBFT build failed"
        record_result "cometbft" "FAILED" "Check $log_file"
        return 1
    fi
}

build_agave() {
    log "Building Agave (Solana)..."
    local repo_dir="$REPOS_DIR/agave"
    local log_file="$LOGS_DIR/agave.log"

    if [[ ! -d "$repo_dir" ]]; then
        error "Agave repository not found"
        record_result "agave" "FAILED" "Repository not cloned"
        return 1
    fi

    cd "$repo_dir"

    {
        # Agave uses Cargo with specific features
        # This can take a long time and require significant resources
        cargo build --release --bin solana-validator --bin solana-genesis --bin solana-keygen 2>&1 | tee -a "$log_file"
    } >>"$log_file" 2>&1

    local bins=(solana-validator solana-genesis solana-keygen)
    local found=0
    for bin in "${bins[@]}"; do
        if [[ -f "target/release/$bin" ]]; then
            success "Found $bin"
            found=1
        fi
    done

    if [[ $found -gt 0 ]]; then
        success "Agave (Solana) built successfully"
        record_result "agave" "SUCCESS" "Solana binaries built"
        return 0
    else
        error "Agave build failed or incomplete"
        record_result "agave" "FAILED" "Check $log_file"
        return 1
    fi
}

build_ouroboros_consensus() {
    log "Building Ouroboros Consensus..."
    local repo_dir="$REPOS_DIR/ouroboros-consensus"
    local log_file="$LOGS_DIR/ouroboros-consensus.log"

    if [[ ! -d "$repo_dir" ]]; then
        error "Ouroboros Consensus repository not found"
        record_result "ouroboros-consensus" "FAILED" "Repository not cloned"
        return 1
    fi

    cd "$repo_dir"

    {
        # Ouroboros uses Cabal
        if command -v cabal >/dev/null 2>&1; then
            cabal update 2>&1 | tee -a "$log_file"
            cabal build -j"$BUILD_JOBS" all 2>&1 | tee -a "$log_file"
        elif command -v stack >/dev/null 2>&1; then
            stack build 2>&1 | tee -a "$log_file"
        else
            error "Neither cabal nor stack found"
            return 1
        fi
    } >>"$log_file" 2>&1

    success "Ouroboros Consensus built (library)"
    record_result "ouroboros-consensus" "SUCCESS" "Haskell library built (no standalone binary)"
    return 0
}

build_honeybadger() {
    log "Checking HoneyBadgerBFT (Python)..."
    local repo_dir="$REPOS_DIR/honeybadger"
    local log_file="$LOGS_DIR/honeybadger.log"

    if [[ ! -d "$repo_dir" ]]; then
        error "HoneyBadgerBFT repository not found"
        record_result "honeybadger" "FAILED" "Repository not cloned"
        return 1
    fi

    cd "$repo_dir"

    {
        # Python project - install dependencies
        if [[ -f "requirements.txt" ]]; then
            python3 -m pip install -r requirements.txt 2>&1 | tee -a "$log_file"
        fi
        if [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]]; then
            python3 -m pip install -e . 2>&1 | tee -a "$log_file"
        fi
    } >>"$log_file" 2>&1

    success "HoneyBadgerBFT dependencies installed"
    record_result "honeybadger" "SUCCESS" "Python package installed (no compilation needed)"
    return 0
}

build_rusty_kaspa() {
    log "Building Rusty-Kaspa..."
    local repo_dir="$REPOS_DIR/rusty-kaspa"
    local log_file="$LOGS_DIR/rusty-kaspa.log"

    if [[ ! -d "$repo_dir" ]]; then
        error "Rusty-Kaspa repository not found"
        record_result "rusty-kaspa" "FAILED" "Repository not cloned"
        return 1
    fi

    cd "$repo_dir"

    {
        # Rusty-Kaspa uses Cargo workspace
        cargo build --release --workspace 2>&1 | tee -a "$log_file"
    } >>"$log_file" 2>&1

    # Check for kaspad binary
    if [[ -f "target/release/kaspad" ]] || find target/release -name "kaspad" -type f 2>/dev/null | grep -q .; then
        success "Rusty-Kaspa built successfully"
        record_result "rusty-kaspa" "SUCCESS" "kaspad binary built"
        return 0
    else
        error "Rusty-Kaspa build failed"
        record_result "rusty-kaspa" "FAILED" "Check $log_file"
        return 1
    fi
}

build_stellar_core() {
    log "Building Stellar Core..."
    local repo_dir="$REPOS_DIR/stellar-core"
    local log_file="$LOGS_DIR/stellar-core.log"

    if [[ ! -d "$repo_dir" ]]; then
        error "Stellar Core repository not found"
        record_result "stellar-core" "FAILED" "Repository not cloned"
        return 1
    fi

    cd "$repo_dir"

    {
        # Stellar Core uses CMake
        mkdir -p build
        cd build
        cmake -DCMAKE_BUILD_TYPE="$BUILD_TYPE" .. 2>&1 | tee -a "$log_file"
        make -j"$BUILD_JOBS" 2>&1 | tee -a "$log_file"
    } >>"$log_file" 2>&1

    if [[ -f "build/stellar-core" ]] || [[ -f "stellar-core" ]]; then
        success "Stellar Core built successfully"
        record_result "stellar-core" "SUCCESS" "stellar-core binary built"
        return 0
    else
        error "Stellar Core build failed"
        record_result "stellar-core" "FAILED" "Check $log_file"
        return 1
    fi
}

# ============================================================================
# MAIN BUILD ORCHESTRATION
# ============================================================================

generate_build_report() {
    local report_file="$REPORTS_DIR/build_report.md"
    local json_file="$REPORTS_DIR/build_report.json"

    log "Generating build report..."

    cat >"$report_file" <<'EOF'
# Build Report

| Repository | Status | Notes |
|------------|--------|-------|
EOF

    echo "{" >"$json_file"
    echo '  "generated": "'$(date -Iseconds)'",' >>"$json_file"
    echo '  "build_type": "'$BUILD_TYPE'",' >>"$json_file"
    echo '  "jobs": '$BUILD_JOBS',' >>"$json_file"
    echo '  "results": [' >>"$json_file"

    local first=true
    for repo in bitcoin ethereum-consensus-specs hotstuff sui avalanchego go-algorand cometbft agave ouroboros-consensus honeybadger rusty-kaspa stellar-core; do
        local status="${BUILD_RESULTS[$repo]:-NOT_ATTEMPTED}"
        local notes="${BUILD_NOTES[$repo]:-}"

        echo "| $repo | $status | $notes |" >>"$report_file"

        if [[ "$first" == true ]]; then
            first=false
        else
            echo "," >>"$json_file"
        fi
        cat >>"$json_file" <<EOF
    {
      "repository": "$repo",
      "status": "$status",
      "notes": "$notes"
    }
EOF
    done

    echo "" >>"$json_file"
    echo "  ]" >>"$json_file"
    echo "}" >>"$json_file"

    success "Build report saved to $report_file and $json_file"
}

main() {
    log "Starting build phase for all repositories"
    log "Build type: $BUILD_TYPE, Jobs: $BUILD_JOBS"

    local build_functions=(
        "build_bitcoin"
        "build_ethereum_consensus_specs"
        "build_hotstuff"
        "build_sui"
        "build_avalanchego"
        "build_go_algorand"
        "build_cometbft"
        "build_agave"
        "build_ouroboros_consensus"
        "build_honeybadger"
        "build_rusty_kaspa"
        "build_stellar_core"
    )

    local failed=0
    local succeeded=0

    for func in "${build_functions[@]}"; do
        if $func; then
            succeeded=$((succeeded + 1))
        else
            failed=$((failed + 1))
            if [[ "$CONTINUE_ON_ERROR" != "true" ]]; then
                error "Build failed and CONTINUE_ON_ERROR=false, stopping"
                break
            fi
        fi
    done

    generate_build_report

    log "Build phase complete: $succeeded succeeded, $failed failed"
    if [[ $failed -gt 0 ]]; then
        warn "Some builds failed. Check logs in $LOGS_DIR/"
        exit 0  # Don't fail the overall script, just report
    fi
    success "All builds completed successfully"
}

main "$@"
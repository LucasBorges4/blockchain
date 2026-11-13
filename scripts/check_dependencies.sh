#!/usr/bin/env bash
# check_dependencies.sh
# Verify dependencies and toolchain versions for all 12 repositories
# Part of Blockchain Consensus Lab — Phase 1

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
REPORTS_DIR="$ROOT_DIR/reports/raw"
LOGS_DIR="$ROOT_DIR/logs/check"

mkdir -p "$REPORTS_DIR" "$LOGS_DIR"

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
success() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $*"; }
error() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $*"; }

# Version comparison
version_ge() {
    # Returns 0 if $1 >= $2
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

check_command() {
    local cmd="$1"
    local min_version="${2:-}"
    local version_flag="${3:---version}"
    local version_regex="${4:-}"

    if command -v "$cmd" >/dev/null 2>&1; then
        local version
        version=$($cmd $version_flag 2>&1 | head -n1)
        if [[ -n "$version_regex" ]]; then
            version=$(echo "$version" | grep -oE "$version_regex" | head -n1)
        fi
        if [[ -n "$min_version" && -n "$version" ]]; then
            if version_ge "$version" "$min_version"; then
                success "$cmd $version (>= $min_version)"
                return 0
            else
                warn "$cmd $version (< $min_version required)"
                return 1
            fi
        else
            success "$cmd found: $version"
            return 0
        fi
    else
        error "$cmd not found"
        return 1
    fi
}

check_pkg_config() {
    local pkg="$1"
    local min_version="${2:-}"

    if pkg-config --exists "$pkg" 2>/dev/null; then
        local version
        version=$(pkg-config --modversion "$pkg" 2>/dev/null || echo "unknown")
        if [[ -n "$min_version" && "$version" != "unknown" ]]; then
            if version_ge "$version" "$min_version"; then
                success "pkg-config: $pkg $version (>= $min_version)"
                return 0
            else
                warn "pkg-config: $pkg $version (< $min_version required)"
                return 1
            fi
        else
            success "pkg-config: $pkg found ($version)"
            return 0
        fi
    else
        error "pkg-config: $pkg not found"
        return 1
    fi
}

# Check system dependencies
check_system_deps() {
    log "=== System Dependencies ==="

    local failed=0

    # Essential tools
    check_command git || ((failed++))
    check_command make || ((failed++))
    check_command cmake "3.20" || ((failed++))
    check_command pkg-config || ((failed++))
    check_command curl || ((failed++))
    check_command wget || ((failed++))
    check_command python3 "3.10" || ((failed++))
    check_command pip3 "22.0" || ((failed++))

    # C/C++ toolchain
    check_command gcc "11" "--version" "[0-9]+\.[0-9]+" || ((failed++))
    check_command g++ "11" "--version" "[0-9]+\.[0-9]+" || ((failed++))
    check_command clang "14" "--version" "[0-9]+\.[0-9]+" || ((failed++))

    # Libraries
    check_pkg_config openssl "1.1" || ((failed++))
    check_pkg_config libssl "1.1" || ((failed++))
    check_pkg_config zlib || ((failed++))
    check_pkg_config libevent || ((failed++))

    return $failed
}

# Check Go toolchain
check_go() {
    log "=== Go Toolchain ==="

    local failed=0
    if command -v go >/dev/null 2>&1; then
        local version
        version=$(go version | grep -oE 'go[0-9]+\.[0-9]+' | sed 's/go//')
        success "go $version"
        if ! version_ge "$version" "1.21"; then
            warn "go $version < 1.21 required"
            ((failed++))
        fi
    else
        error "go not found"
        ((failed++))
    fi
    return $failed
}

# Check Rust toolchain
check_rust() {
    log "=== Rust Toolchain ==="

    local failed=0
    if command -v rustc >/dev/null 2>&1; then
        local version
        version=$(rustc --version | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        success "rustc $version"
        if ! version_ge "$version" "1.70"; then
            warn "rustc $version < 1.70 required"
            ((failed++))
        fi
    else
        error "rustc not found"
        ((failed++))
    fi

    if command -v cargo >/dev/null 2>&1; then
        local version
        version=$(cargo --version | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        success "cargo $version"
    else
        error "cargo not found"
        ((failed++))
    fi
    return $failed
}

# Check Haskell toolchain
check_haskell() {
    log "=== Haskell Toolchain ==="

    local failed=0
    if command -v ghc >/dev/null 2>&1; then
        local version
        version=$(ghc --numeric-version 2>/dev/null || echo "unknown")
        success "ghc $version"
        if [[ "$version" != "unknown" ]] && ! version_ge "$version" "9.4"; then
            warn "ghc $version < 9.4 required"
            ((failed++))
        fi
    else
        error "ghc not found"
        ((failed++))
    fi

    if command -v cabal >/dev/null 2>&1; then
        local version
        version=$(cabal --numeric-version 2>/dev/null || echo "unknown")
        success "cabal $version"
    else
        warn "cabal not found (may use stack instead)"
    fi

    if command -v stack >/dev/null 2>&1; then
        local version
        version=$(stack --numeric-version 2>/dev/null || echo "unknown")
        success "stack $version"
    fi

    return $failed
}

# Check Python toolchain
check_python() {
    log "=== Python Toolchain ==="

    local failed=0
    if command -v python3 >/dev/null 2>&1; then
        local version
        version=$(python3 --version | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        success "python3 $version"
        if ! version_ge "$version" "3.10"; then
            warn "python3 $version < 3.10 required"
            ((failed++))
        fi
    else
        error "python3 not found"
        ((failed++))
    fi

    if command -v pip3 >/dev/null 2>&1; then
        local version
        version=$(pip3 --version | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        success "pip3 $version"
    else
        error "pip3 not found"
        ((failed++))
    fi

    # Check for virtualenv/venv support
    if python3 -m venv --help >/dev/null 2>&1; then
        success "venv module available"
    else
        warn "venv module not available"
    fi

    return $failed
}

# Check Docker/Podman
check_containers() {
    log "=== Container Runtime ==="

    local failed=0
    if command -v docker >/dev/null 2>&1; then
        local version
        version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        success "docker $version"
        if docker info >/dev/null 2>&1; then
            success "docker daemon accessible"
        else
            warn "docker daemon not accessible (permission?)"
        fi
    elif command -v podman >/dev/null 2>&1; then
        local version
        version=$(podman --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        success "podman $version"
    else
        warn "Neither docker nor podman found (optional for isolated builds)"
    fi

    if command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1; then
        success "docker-compose available"
    else
        warn "docker-compose not found"
    fi

    return $failed
}

# Check network simulation tools
check_network_tools() {
    log "=== Network Simulation Tools ==="

    local failed=0
    if command -v tc >/dev/null 2>&1; then
        success "tc (traffic control) available"
    else
        warn "tc not found (required for network condition experiments)"
        ((failed++))
    fi

    if command -v iperf3 >/dev/null 2>&1; then
        success "iperf3 available"
    else
        warn "iperf3 not found (optional, for bandwidth testing)"
    fi

    return $failed
}

# Check monitoring tools
check_monitoring() {
    log "=== Monitoring Tools ==="

    if command -v prometheus >/dev/null 2>&1; then
        success "prometheus available"
    else
        log "prometheus not installed (will use Docker if monitoring profile enabled)"
    fi

    if command -v grafana-server >/dev/null 2>&1; then
        success "grafana available"
    else
        log "grafana not installed (will use Docker if monitoring profile enabled)"
    fi

    return 0
}

# Generate dependency report
generate_report() {
    local report_file="$REPORTS_DIR/dependencies.md"
    local json_file="$REPORTS_DIR/dependencies.json"

    log "Generating dependency report..."

    cat >"$report_file" <<'EOF'
# Dependency Check Report

Generated: $(date)

## System Tools
EOF

    # This would be better with actual data capture, keeping simple for now
    cat >>"$report_file" <<'EOF'

| Tool | Version | Required | Status |
|------|---------|----------|--------|
| git | $(git --version 2>/dev/null | cut -d' ' -f3) | any | $(command -v git >/dev/null && echo "✓" || echo "✗") |
| make | $(make --version 2>/dev/null | head -n1 | cut -d' ' -f3) | any | $(command -v make >/dev/null && echo "✓" || echo "✗") |
| cmake | $(cmake --version 2>/dev/null | head -n1 | cut -d' ' -f3) | >= 3.20 | $(command -v cmake >/dev/null && echo "✓" || echo "✗") |
| gcc | $(gcc --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+') | >= 11 | $(command -v gcc >/dev/null && echo "✓" || echo "✗") |
| clang | $(clang --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+') | >= 14 | $(command -v clang >/dev/null && echo "✓" || echo "✗") |
| go | $(go version 2>/dev/null | grep -oE 'go[0-9]+\.[0-9]+' | sed 's/go//') | >= 1.21 | $(command -v go >/dev/null && echo "✓" || echo "✗") |
| rustc | $(rustc --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+') | >= 1.70 | $(command -v rustc >/dev/null && echo "✓" || echo "✗") |
| cargo | $(cargo --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+') | >= 1.70 | $(command -v cargo >/dev/null && echo "✓" || echo "✗") |
| ghc | $(ghc --numeric-version 2>/dev/null) | >= 9.4 | $(command -v ghc >/dev/null && echo "✓" || echo "✗") |
| python3 | $(python3 --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+') | >= 3.10 | $(command -v python3 >/dev/null && echo "✓" || echo "✗") |
| docker | $(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+') | any | $(command -v docker >/dev/null && echo "✓" || echo "✗") |

## Per-Repository Requirements

| Repository | Language | Key Dependencies |
|------------|----------|------------------|
| bitcoin | C++ | gcc/clang, cmake, libevent, openssl, boost, zmq |
| ethereum-consensus-specs | Python/MD | python3, pip, pytest |
| hotstuff | C++ | gcc/clang, cmake, openssl, protobuf, gtest |
| sui | Rust | rustc, cargo, protoc |
| avalanchego | Go | go 1.21+ |
| go-algorand | Go | go 1.21+ |
| cometbft | Go | go 1.21+ |
| agave | Rust | rustc, cargo, llvm/clang |
| ouroboros-consensus | Haskell | ghc 9.4+, cabal/stack |
| honeybadger | Python | python3, pytest, asyncio |
| rusty-kaspa | Rust | rustc, cargo, rocksdb |
| stellar-core | C++ | gcc/clang, cmake, libsodium, rocksdb, libpq |

EOF

    # JSON report
    cat >"$json_file" <<EOF
{
  "generated": "$(date -Iseconds)",
  "system": {
    "git": "$(git --version 2>/dev/null | cut -d' ' -f3 || echo 'not_found')",
    "make": "$(make --version 2>/dev/null | head -n1 | cut -d' ' -f3 || echo 'not_found')",
    "cmake": "$(cmake --version 2>/dev/null | head -n1 | cut -d' ' -f3 || echo 'not_found')",
    "gcc": "$(gcc --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' || echo 'not_found')",
    "clang": "$(clang --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' || echo 'not_found')",
    "go": "$(go version 2>/dev/null | grep -oE 'go[0-9]+\.[0-9]+' | sed 's/go//' || echo 'not_found')",
    "rustc": "$(rustc --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' || echo 'not_found')",
    "cargo": "$(cargo --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' || echo 'not_found')",
    "ghc": "$(ghc --numeric-version 2>/dev/null || echo 'not_found')",
    "python3": "$(python3 --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' || echo 'not_found')",
    "docker": "$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo 'not_found')"
  }
}
EOF

    success "Dependency report saved to $report_file and $json_file"
}

# Main
main() {
    log "Starting dependency check"
    local total_failed=0

    check_system_deps || total_failed=$((total_failed + $?))
    check_go || total_failed=$((total_failed + $?))
    check_rust || total_failed=$((total_failed + $?))
    check_haskell || total_failed=$((total_failed + $?))
    check_python || total_failed=$((total_failed + $?))
    check_containers || total_failed=$((total_failed + $?))
    check_network_tools || total_failed=$((total_failed + $?))
    check_monitoring || total_failed=$((total_failed + $?))

    generate_report

    if [[ $total_failed -gt 0 ]]; then
        warn "Dependency check completed with $total_failed issue(s)"
        warn "Some repositories may not build correctly"
        exit 0  # Don't fail the build, just warn
    else
        success "All dependencies satisfied"
    fi
}

main "$@"
#!/usr/bin/env bash
# clone_repositories.sh
# Clone all 12 blockchain consensus repositories and record versions
# Part of Blockchain Consensus Lab — Phase 1

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
REPOS_DIR="$ROOT_DIR/repositories"
REPORTS_DIR="$ROOT_DIR/reports/raw"
LOGS_DIR="$ROOT_DIR/logs/clone"

# Repository definitions: name|url|subdir
REPOS=(
    "bitcoin|https://github.com/bitcoin/bitcoin.git|bitcoin"
    "ethereum-consensus-specs|https://github.com/ethereum/consensus-specs.git|ethereum-consensus-specs"
    "hotstuff|https://github.com/relab/hotstuff.git|hotstuff"
    "sui|https://github.com/MystenLabs/sui.git|sui"
    "avalanchego|https://github.com/ava-labs/avalanchego.git|avalanchego"
    "go-algorand|https://github.com/algorand/go-algorand.git|go-algorand"
    "cometbft|https://github.com/cometbft/cometbft.git|cometbft"
    "agave|https://github.com/anza-xyz/agave.git|agave"
    "ouroboros-consensus|https://github.com/IntersectMBO/ouroboros-consensus.git|ouroboros-consensus"
    "honeybadger|https://github.com/initc3/HoneyBadgerBFT-Python.git|honeybadger"
    "rusty-kaspa|https://github.com/kaspanet/rusty-kaspa.git|rusty-kaspa"
    "stellar-core|https://github.com/stellar/stellar-core.git|stellar-core"
)

# Clone depth from env or default to full
CLONE_DEPTH="${BCL_CLONE_DEPTH:-0}"

mkdir -p "$REPOS_DIR" "$REPORTS_DIR" "$LOGS_DIR"

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $*"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $*"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $*"
}

# Clone or update a single repository
clone_repo() {
    local repo_info="$1"
    local name url subdir
    name=$(echo "$repo_info" | cut -d'|' -f1)
    url=$(echo "$repo_info" | cut -d'|' -f2)
    subdir=$(echo "$repo_info" | cut -d'|' -f3)
    local target_dir="$REPOS_DIR/$subdir"
    local log_file="$LOGS_DIR/${name}.log"

    log "Processing $name ($url)"

    if [[ -d "$target_dir/.git" ]]; then
        log "Repository $name exists, updating..."
        {
            cd "$target_dir"
            git fetch origin --prune
            # Try to get commit from env override
            local commit_var="BCL_${name^^}_COMMIT"
            commit_var=${commit_var//-/_}
            local target_commit="${!commit_var:-}"
            if [[ -n "$target_commit" ]]; then
                log "Checking out specific commit: $target_commit"
                git checkout "$target_commit"
            else
                git pull --ff-only
            fi
        } >>"$log_file" 2>&1
        success "$name updated"
    else
        log "Cloning $name..."
        local clone_cmd="git clone"
        if [[ "$CLONE_DEPTH" -gt 0 ]]; then
            clone_cmd="$clone_cmd --depth $CLONE_DEPTH"
        fi
        {
            $clone_cmd "$url" "$target_dir"
            # Check out specific commit if provided
            local commit_var="BCL_${name^^}_COMMIT"
            commit_var=${commit_var//-/_}
            local target_commit="${!commit_var:-}"
            if [[ -n "$target_commit" ]]; then
                log "Checking out specific commit: $target_commit"
                cd "$target_dir"
                git fetch origin "$target_commit" 2>/dev/null || true
                git checkout "$target_commit" 2>/dev/null || warn "Could not checkout $target_commit"
            fi
        } >>"$log_file" 2>&1
        success "$name cloned"
    fi
}

# Record version info for all repositories
record_versions() {
    local versions_file="$REPORTS_DIR/versions.md"
    local json_file="$REPORTS_DIR/versions.json"

    log "Recording repository versions..."

    echo "# Repository Versions" >"$versions_file"
    echo "" >>"$versions_file"
    echo "| Repository | Commit Hash | Branch | Date | URL |" >>"$versions_file"
    echo "|------------|-------------|--------|------|-----|" >>"$versions_file"

    # JSON array
    echo "[" >"$json_file"
    local first=true

    for repo_info in "${REPOS[@]}"; do
        local name url subdir
        name=$(echo "$repo_info" | cut -d'|' -f1)
        url=$(echo "$repo_info" | cut -d'|' -f2)
        subdir=$(echo "$repo_info" | cut -d'|' -f3)
        local target_dir="$REPOS_DIR/$subdir"

        if [[ -d "$target_dir/.git" ]]; then
            local hash branch date
            hash=$(cd "$target_dir" && git rev-parse HEAD 2>/dev/null || echo "unknown")
            branch=$(cd "$target_dir" && git branch --show-current 2>/dev/null || echo "detached")
            date=$(cd "$target_dir" && git log -1 --format=%ci 2>/dev/null || echo "unknown")
            local short_hash="${hash:0:12}"

            echo "| [$name]($url) | \`$short_hash\` | $branch | $date | $url |" >>"$versions_file"

            if [[ "$first" == true ]]; then
                first=false
            else
                echo "," >>"$json_file"
            fi
            cat >>"$json_file" <<EOF
  {
    "name": "$name",
    "url": "$url",
    "subdir": "$subdir",
    "commit": "$hash",
    "short_commit": "$short_hash",
    "branch": "$branch",
    "date": "$date"
  }
EOF
        else
            echo "| $name | NOT CLONED | - | - | $url |" >>"$versions_file"
            if [[ "$first" == true ]]; then
                first=false
            else
                echo "," >>"$json_file"
            fi
            cat >>"$json_file" <<EOF
  {
    "name": "$name",
    "url": "$url",
    "subdir": "$subdir",
    "commit": null,
    "short_commit": null,
    "branch": null,
    "date": null,
    "error": "not_cloned"
  }
EOF
        fi
    done

    echo "" >>"$json_file"
    echo "]" >>"$json_file"

    success "Versions recorded to $versions_file and $json_file"
}

# Main execution
main() {
    log "Starting repository cloning phase"
    log "Target directory: $REPOS_DIR"
    log "Clone depth: $CLONE_DEPTH"

    local failed=()

    for repo_info in "${REPOS[@]}"; do
        local name
        name=$(echo "$repo_info" | cut -d'|' -f1)
        if ! clone_repo "$repo_info"; then
            error "Failed to clone/update $name"
            failed+=("$name")
        fi
    done

    record_versions

    if [[ ${#failed[@]} -gt 0 ]]; then
        error "Failed repositories: ${failed[*]}"
        exit 1
    fi

    success "All repositories cloned successfully"
    log "Run 'make check' to verify dependencies"
}

main "$@"
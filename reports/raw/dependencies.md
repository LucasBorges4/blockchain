# Dependency Check Report

Generated: $(date)

## System Tools

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


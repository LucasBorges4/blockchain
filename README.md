# Blockchain Consensus Lab

Ambiente experimental para clonar, compilar, testar e fazer benchmark de 12 algoritmos de consenso blockchain.

## Visão Geral

Este projeto implementa um framework sistemático para avaliação experimental de protocolos de consenso blockchain. Segue metodologia de Desenvolvimento Orientado por Especificações (SDD) com fases claras, critérios de aceitação e ferramentas automatizadas.

## Protocolos Alvo

| # | Algoritmo | Repositório | Linguagem | Tipo |
|---|---|---|---|---|
| 1 | Nakamoto Consensus (Bitcoin PoW) | [bitcoin/bitcoin](https://github.com/bitcoin/bitcoin) | C++ | Produção |
| 2 | Gasper (Ethereum PoS) | [ethereum/consensus-specs](https://github.com/ethereum/consensus-specs) | Python/MD | Especificação |
| 3 | HotStuff | [relab/hotstuff](https://github.com/relab/hotstuff) | C++ | Protótipo Acadêmico |
| 4 | Narwhal + Bullshark | [MystenLabs/sui](https://github.com/MystenLabs/sui) | Rust | Produção (Sui) |
| 5 | Avalanche | [ava-labs/avalanchego](https://github.com/ava-labs/avalanchego) | Go | Produção |
| 6 | Algorand BA* | [algorand/go-algorand](https://github.com/algorand/go-algorand) | Go | Produção |
| 7 | CometBFT (Tendermint) | [cometbft/cometbft](https://github.com/cometbft/cometbft) | Go | Produção |
| 8 | Solana Tower BFT | [anza-xyz/agave](https://github.com/anza-xyz/agave) | Rust | Produção |
| 9 | Ouroboros | [IntersectMBO/ouroboros-consensus](https://github.com/IntersectMBO/ouroboros-consensus) | Haskell | Acadêmico/Produção |
| 10 | HoneyBadgerBFT | [initc3/HoneyBadgerBFT-Python](https://github.com/initc3/HoneyBadgerBFT-Python) | Python | Protótipo Acadêmico |
| 11 | PHANTOM / GHOSTDAG | [kaspanet/rusty-kaspa](https://github.com/kaspanet/rusty-kaspa) | Rust | Produção |
| 12 | Stellar Consensus Protocol | [stellar/stellar-core](https://github.com/stellar/stellar-core) | C++ | Produção |

## Início Rápido

```bash
# Configuração completa (clona, verifica deps, compila, testa)
make setup

# Ou passo a passo:
make clone      # Clona todos os 12 repositórios
make check      # Verifica dependências e versões
make build      # Compila todos os projetos
make test       # Executa testes nativos
make adapters   # Compila/verifica adaptadores de experimento
make experiment # Executa experimentos
make benchmark  # Executa suite de benchmarks
make report     # Gera gráficos e relatórios
```

## Estrutura do Projeto

```
blockchain-consensus-lab/
├── SPEC.md                 # Especificação completa (leia primeiro)
├── Makefile                # Comandos de automação
├── docker-compose.yml      # Ambientes containerizados
├── .env.example            # Template de variáveis de ambiente
├── repositories/           # Repositórios upstream clonados (12)
├── adapters/               # Adaptadores de experimento por protocolo
├── experiments/            # Definições e configs de experimentos
├── scripts/                # Scripts de automação
├── benchmarks/             # Workloads, configs, resultados
├── metrics/                # Coleta, parsing, exportação
├── reports/                # Raw, processados, figuras, tabelas
└── logs/                   # Logs de build e teste
```

## Requisitos

- Linux (testado em Manjaro/Arch)
- Git, Make, Bash
- Docker ou Podman (para isolamento)
- Python 3.10+
- Toolchains por linguagem (veja `make check`):
  - C++: gcc/clang, cmake, make
  - Go: go 1.21+
  - Rust: cargo, rustc 1.70+
  - Haskell: ghc, cabal/stack
  - Python: 3.10+, pip

## Documentação

- **[SPEC.md](SPEC.md)** — Especificação completa com fases, critérios de aceitação e entregáveis
- **`reports/processed/`** — Relatórios gerados (após executar experimentos)
- **`reports/figures/`** — Gráficos comparativos (após `make report`)

## Categorias de Experimentos

Cada categoria responde a uma questão fundamental sobre o comportamento do protocolo:

| Categoria | Pergunta Central | Por Que É Importante |
|-----------|------------------|----------------------|
| **1. Funcionalidade Básica** | O protocolo consegue chegar a consenso e processar operações? | Validação mínima — se falha aqui, nada mais importa |
| **2. Escalabilidade** | Como o desempenho muda ao aumentar participantes (4→50 nós)? | Protocolos BFT tipicamente degradam O(n²) ou O(n³); PoW/PoS escalam diferente |
| **3. Latência** | Quanto tempo da submissão até a finalidade (média, P95, P99)? | Finalidade probabilística (Bitcoin) vs determinística (BFT) — métricas distintas |
| **4. Throughput** | Qual a taxa sustentável variando carga (100→100k tx)? | Distinguir capacidade de execução vs throughput efetivo de consenso |
| **5. Tolerância a Falhas** | O consenso mantém segurança/vivacidade sob falhas reais? | Crash/partição ≠ comportamento Bizantino; testar cenários específicos |
| **6. Condições de Rede** | Como latência, jitter, perda e banda afetam o protocolo? | Redes reais não são LANs ideais; tc/netem simulam condições adversas |

**Design das variáveis:**
- **Repetições mínimas: 5** — permite estatística (média, desvio, percentis)
- **Seeds fixas** — reprodutibilidade exata
- **Configuração versionada** — cada experimento carrega seu `config.json`

## Formatos de Saída

| Formato | Uso | Por Que |
|---------|-----|---------|
| **JSON** (`reports/raw/`, `benchmarks/results/`) | Dados brutos completos, aninhados, tipados | Parsing programático, preserva estrutura original, schema evolutivo |
| **CSV** (`reports/tables/`, `metrics/exporter/`) | Tabelas planas para análise estatística | Compatível com Pandas, R, Excel, SQLite; ideal para pivot tables |
| **Markdown** (`reports/processed/`, `reports/tables/`) | Relatórios legíveis por humanos, versionáveis | Git-diff amigável, renderiza no GitHub/GitLab, documentação viva |
| **PNG** (`reports/figures/`) | Gráficos comparativos prontos para publicação | Matplotlib/Seaborn com DPI 150+, temas consistentes, legendas completas |

**Pipeline de dados:**
```
Experimento → JSON bruto (por repetição)
    → Agregação (metrics/collector) → JSON agregado + CSV por métrica
    → Exportação unificada (metrics/exporter) → all_metrics.json + all_metrics.csv
    → Geração de relatório (scripts/generate_report.py) → Tabelas MD + Gráficos PNG
```

## Organização dos Scripts

```
scripts/
├── clone_repositories.sh      # Fase 1: Clona 12 repos, registra commits, gera versions.md/json
├── check_dependencies.sh      # Fase 1: Verifica toolchains (C++, Go, Rust, Haskell, Python), gera dependencies.md/json
├── build_all.sh               # Fase 2: Compila cada repo seguindo docs oficiais, logs individuais, build_report.md/json
├── run_tests.sh               # Fase 3: Executa testes nativos (unit, integration, system), test_report.md/json
├── run_experiments.sh         # Fase 4: Orquestra 6 experimentos por adapter, salva JSON por repetição
├── collect_metrics.sh         # Fase 5: Parseia JSONs, agrega estatísticas (média, mediana, P95, P99, desvio), exporta CSV
├── generate_report.py         # Fase 6-7: Pandas + Matplotlib → tabelas comparativas, 9 gráficos, matriz de compatibilidade
└── Makefile targets           # Orquestração: setup, clone, check, build, test, adapters, experiment, benchmark, collect, report, clean
```

**Princípios de design dos scripts:**
- **`set -euo pipefail`** — falha rápida em erros, pipes propagam falhas
- **Subshells isolados** — cada build/teste roda em contexto próprio, não contamina estado global
- **`CONTINUE_ON_ERROR=true`** — padrão: continua nos demais repos se um falha (não para o pipeline)
- **Logs duplicados** — `tee` envia para stdout (visibilidade) e arquivo (persistência)
- **Relatórios duplos** — Markdown (humano) + JSON (máquina) para cada fase
- **Idempotência** — `make clone` atualiza se já existe; `make build` recompila incrementalmente

## Reprodutibilidade

Cada execução de experimento registra:
- Commits exatos dos repositórios
- Versões de toolchains
- Parâmetros de configuração
- Seeds aleatórios
- Detalhes do ambiente

## Licença

Código de pesquisa experimental. Repositórios individuais mantêm suas licenças originais.

## Contribuição

Este é um framework de pesquisa. Veja SPEC.md para pontos de extensão.
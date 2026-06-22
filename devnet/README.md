# ZenStaker local devnet

One `docker compose` that brings up a complete local environment:

1. **anvil** — local EVM node (chain id `31337`) on `:8545`
2. **contracts** — one-shot job that deploys the stack with
   `script/DeployZenStakerTestnet.s.sol` (test ERC20 + IdentityEarningPowerCalculator
   + `ZenStakerUpgradeable` impl + ERC1967 proxy)
3. **postgres + ipfs** — graph-node backing services
4. **graph-node** — indexer, pointed at anvil
5. **subgraph-deployer** — one-shot job that reads the freshly deployed proxy
   address from the forge broadcast file, generates `subgraph.devnet.yaml` and
   deploys the subgraph to the local graph-node

The two one-shot jobs are ordered via compose conditions:
`contracts` waits for anvil to be healthy, and `subgraph-deployer` waits for
`contracts` to finish successfully **and** for graph-node to start.

## Requirements

- Docker + Docker Compose v2
- The Foundry git submodules present (`lib/forge-std`, `lib/openzeppelin-contracts`).
  If missing: `git submodule update --init --recursive` from the repo root.

## Run

From this `devnet/` folder:

```bash
docker compose up            # follow logs in the foreground
# or
docker compose up -d         # background
```

First run is slower: the foundry image downloads solc 0.8.28, graph-node
initializes its DB, and the subgraph dependencies install if needed.

When everything is up:

| Service          | URL                                                   |
| ---------------- | ----------------------------------------------------- |
| Anvil RPC        | http://localhost:8545                                 |
| GraphQL          | http://localhost:8000/subgraphs/name/zen-staker       |
| Graph admin RPC  | http://localhost:8020                                 |

Find the deployed addresses (token, calculator, impl, proxy) in the logs of the
`contracts` service, or in
`broadcast/DeployZenStakerTestnet.s.sol/31337/run-latest.json`.

## Stop / reset

```bash
docker compose down          # stop containers, keep chain + index data
docker compose down -v       # also remove containers and networks
rm -rf data/                 # wipe postgres + ipfs state for a clean slate
```

Because anvil state is in-memory, a restart of the `anvil` service produces a
**fresh chain** — re-run `docker compose up` so the `contracts` and
`subgraph-deployer` jobs redeploy against it.

## Notes

- The deployer uses anvil's default account #3
  (`0x7c8521...`, address `0x90F7...`) — a publicly known, pre-funded dev key.
  Never use it outside a local devnet.
- `network: mainnet` in the generated manifest is just the label that matches
  graph-node's `ethereum` env var; the underlying chain is anvil (31337).
- `anvil --block-time 2` keeps the chain head advancing so graph-node keeps
  indexing. Send transactions via `cast` against `:8545` to exercise the
  contracts and watch entities appear in the GraphQL playground.
- The `contracts` and `subgraph-deployer` jobs run as UID/GID `1000` by default
  so files written into the mounted repo stay owned by you. Override with
  `DEVNET_UID` / `DEVNET_GID` if your host user differs:
  `DEVNET_UID=$(id -u) DEVNET_GID=$(id -g) docker compose up`.
```

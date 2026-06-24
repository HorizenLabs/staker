#!/usr/bin/env bash
# Reads the deployed ZenStaker proxy address from the forge broadcast file,
# generates a devnet subgraph manifest and deploys it to the local graph-node.
# Runs inside a node image. Working dir: /repo/subgraphs.
set -euo pipefail

BROADCAST="/repo/broadcast/DeployZenStakerTestnet.s.sol/31337/run-latest.json"
TEMPLATE="/repo/devnet/subgraph.devnet.template.yaml"
MANIFEST="subgraph.devnet.yaml"
SUBGRAPH_NAME="zen-staker"

GRAPH_NODE_STATUS="http://graph-node:8030/graphql"

# Idempotency: graph-node + postgres persist across restarts and resume
# indexing on their own. If the subgraph is already deployed, skip.
echo "[subgraph] waiting for graph-node status endpoint at ${GRAPH_NODE_STATUS} ..."
until node -e 'fetch(process.argv[1]).then(()=>process.exit(0)).catch(()=>process.exit(1))' "${GRAPH_NODE_STATUS}" 2>/dev/null; do
  sleep 2
done
ALREADY=$(node -e '
  fetch(process.argv[1], {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ query: "{ indexingStatusForCurrentVersion(subgraphName: \"" + process.argv[2] + "\", pending: false) { synced health } }" }),
  })
    .then(r => r.json())
    .then(j => { const s = j && j.data && j.data.indexingStatusForCurrentVersion; process.stdout.write(s ? "yes" : "no"); })
    .catch(() => process.stdout.write("no"));
' "${GRAPH_NODE_STATUS}" "${SUBGRAPH_NAME}")
if [ "${ALREADY}" = "yes" ]; then
  echo "[subgraph] ${SUBGRAPH_NAME} already deployed on graph-node, skipping (resumed from persisted state)."
  echo "[subgraph] GraphQL: http://localhost:8000/subgraphs/name/${SUBGRAPH_NAME}"
  exit 0
fi

echo "[subgraph] reading proxy address from broadcast..."
PROXY_ADDRESS=$(node -e '
  const t = require(process.argv[1]).transactions;
  const proxy = t.filter(x => x.contractName === "ERC1967Proxy").pop();
  if (!proxy) { console.error("ERC1967Proxy not found in broadcast"); process.exit(1); }
  process.stdout.write(proxy.contractAddress);
' "${BROADCAST}")
echo "[subgraph] ZenStaker proxy: ${PROXY_ADDRESS}"

# Generate the manifest with the freshly deployed address.
sed "s|__PROXY_ADDRESS__|${PROXY_ADDRESS}|g" "${TEMPLATE}" > "${MANIFEST}"

# node_modules is mounted from the host; install only if missing.
if [ ! -x "./node_modules/.bin/graph" ]; then
  echo "[subgraph] installing dependencies..."
  npm install --no-audit --no-fund
fi
GRAPH="./node_modules/.bin/graph"

echo "[subgraph] codegen + build..."
"${GRAPH}" codegen "${MANIFEST}"
"${GRAPH}" build "${MANIFEST}"

echo "[subgraph] waiting for graph-node admin endpoint at ${GRAPH_NODE} ..."
until "${GRAPH}" create --node "${GRAPH_NODE}" "${SUBGRAPH_NAME}" >/dev/null 2>&1; do
  sleep 3
done

echo "[subgraph] deploying..."
"${GRAPH}" deploy \
  --node "${GRAPH_NODE}" \
  --ipfs "${IPFS_URL}" \
  --version-label "v0.0.1" \
  "${SUBGRAPH_NAME}" "${MANIFEST}"

echo "[subgraph] done. GraphQL: http://localhost:8000/subgraphs/name/${SUBGRAPH_NAME}"

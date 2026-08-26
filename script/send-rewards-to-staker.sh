#!/usr/bin/env bash
# Polls RewardAccumulator.nextRewardTime() and waits — printing live progress — until the
# reward window elapses, then broadcasts SendRewardsToStaker.s.sol (which calls only
# sendRewardsToStaker()).
#
# The wait/poll loop lives here in bash rather than inside the Solidity script: forge only
# flushes console2 logs after the whole run() call returns, so a Solidity-side wait loop
# prints nothing while it's waiting, even across a multi-hour/day gap.
#
# Required environment variables (e.g. from .env):
#   REWARD_ACCUMULATOR_ADDRESS — address of the deployed RewardAccumulator
#   PRIVATE_KEY                — broadcaster private key (hex, with or without 0x prefix)
#
# Optional:
#   RPC_ALIAS      — foundry.toml [rpc_endpoints] alias (or a raw RPC URL), defaults to "mainnet"
#   POLL_INTERVAL  — seconds between chain checks while waiting, defaults to 60

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

: "${REWARD_ACCUMULATOR_ADDRESS:?REWARD_ACCUMULATOR_ADDRESS must be set}"
: "${PRIVATE_KEY:?PRIVATE_KEY must be set}"

RPC_ALIAS="${RPC_ALIAS:-mainnet}"
POLL_INTERVAL="${POLL_INTERVAL:-2}"

while true; do
  next_reward_time=$(cast call "$REWARD_ACCUMULATOR_ADDRESS" "nextRewardTime()(uint256)" \
    --rpc-url "$RPC_ALIAS" | awk '{print $1}')
  now=$(date +%s)
  remaining=$((next_reward_time - now))

  if [ "$remaining" -le 0 ]; then
    echo "[$(date -u +%FT%TZ)] Reward window reached, sending rewards to staker..."
    break
  fi

  echo "[$(date -u +%FT%TZ)] Waiting for reward window: ${remaining}s remaining (next check in ${POLL_INTERVAL}s)"
  sleep "$POLL_INTERVAL"
done

forge script script/SendRewardsToStaker.s.sol --rpc-url "$RPC_ALIAS" --broadcast -vvvv

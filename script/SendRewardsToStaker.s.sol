// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {RewardAccumulator} from "../src/RewardAccumulator.sol";

/// @notice Calls RewardAccumulator.sendRewardsToStaker() — and only that. Reverts with
/// RewardAccumulator.WaitForNextRewardTime if the reward window hasn't elapsed yet.
/// @dev sendRewardsToStaker() is permissionless in open mode (see RewardAccumulator's dev notes), so
/// PRIVATE_KEY only needs to be funded for gas, no special role required.
/// Use `script/send-rewards-to-staker.sh` to poll and wait (with live progress output) for the
/// window to open before invoking this — a Solidity wait loop inside the script can't stream
/// progress, since forge only prints console2 logs after the whole run() call finishes.
/// Required environment variables:
///   REWARD_ACCUMULATOR_ADDRESS — address of the deployed RewardAccumulator
///   PRIVATE_KEY                — broadcaster private key (hex, with or without 0x prefix)
contract SendRewardsToStaker is Script {
  function run() external {
    address accumulatorAddress = vm.envAddress("REWARD_ACCUMULATOR_ADDRESS");
    uint256 broadcasterKey = vm.envUint("PRIVATE_KEY");

    RewardAccumulator accumulator = RewardAccumulator(accumulatorAddress);

    vm.startBroadcast(broadcasterKey);
    accumulator.sendRewardsToStaker();
    vm.stopBroadcast();

    console2.log("Sent accumulated rewards to staker");
  }
}

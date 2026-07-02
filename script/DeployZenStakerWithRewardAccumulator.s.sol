// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEarningPowerCalculator} from "../src/interfaces/IEarningPowerCalculator.sol";
import {IdentityEarningPowerCalculator} from
  "../src/calculators/IdentityEarningPowerCalculator.sol";
import {ZenStaker} from "../src/ZenStaker.sol";
import {RewardAccumulator} from "../src/RewardAccumulator.sol";

/// @notice Deploys IdentityEarningPowerCalculator, ZenStaker, and RewardAccumulator.
/// Required environment variables:
///   ZEN_TOKEN_ADDRESS        — address of the deployed ZEN ERC20 token
///   ADMIN_ADDRESS            — address of the Horizen multisig (becomes staker admin)
///   PRIVATE_KEY              — deployer private key (hex, with or without 0x prefix)
///   REWARD_NOTIFIER_ADDRESS  — additional address to authorize as reward notifier
///
/// Optional:
///   MAX_BUMP_TIP             — uint256, defaults to 0
///   TIME_WINDOW              — uint256, defaults to 30 days
///   WHITELIST_ENABLED        — bool, defaults to false
contract DeployZenStakerWithRewardAccumulator is Script {
  function run()
    external
    returns (
      IdentityEarningPowerCalculator calculator,
      ZenStaker staker,
      RewardAccumulator accumulator
    )
  {
    address zenToken = vm.envAddress("ZEN_TOKEN_ADDRESS");
    address admin = vm.envAddress("ADMIN_ADDRESS");
    address rewardNotifier = vm.envAddress("REWARD_NOTIFIER_ADDRESS");
    uint256 maxBumpTip = vm.envOr("MAX_BUMP_TIP", uint256(0));
    uint256 timeWindow = vm.envOr("TIME_WINDOW", uint256(30 days));
    bool whitelistEnabled = vm.envOr("WHITELIST_ENABLED", false);
    uint256 deployerKey = vm.envUint("PRIVATE_KEY");

    vm.startBroadcast(deployerKey);

    calculator = new IdentityEarningPowerCalculator();
    console2.log("IdentityEarningPowerCalculator:", address(calculator));

    staker = new ZenStaker(
      IERC20(zenToken),
      IEarningPowerCalculator(address(calculator)),
      maxBumpTip,
      admin
    );
    console2.log("ZenStaker:                    ", address(staker));

    accumulator = new RewardAccumulator(
      staker,
      ERC20(zenToken),
      timeWindow,
      whitelistEnabled
    );
    console2.log("RewardAccumulator:           ", address(accumulator));

    staker.setRewardNotifier(address(accumulator), true);
    staker.setRewardNotifier(rewardNotifier, true);

    console2.log("Admin:                        ", admin);
    console2.log("ZEN token:                    ", zenToken);
    console2.log("Additional reward notifier:   ", rewardNotifier);
    console2.log("Time window:                  ", timeWindow);
    console2.log("Whitelist enabled:            ", whitelistEnabled);

    vm.stopBroadcast();
  }
}

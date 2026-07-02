// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {RewardAccumulator} from "../src/RewardAccumulator.sol";
import {Staker} from "../src/Staker.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Reward Token", "MRT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockStaker {
    uint256 public lastNotifiedAmount;

    function notifyRewardAmount(uint256 amount) external {
        lastNotifiedAmount = amount;
    }
}

contract RewardAccumulatorTest is Test {
    RewardAccumulator internal accumulator;
    MockERC20 internal rewardToken;
    MockStaker internal mockStaker;

    function setUp() public {
        rewardToken = new MockERC20();
        mockStaker = new MockStaker();
        accumulator = new RewardAccumulator(
            Staker(address(mockStaker)),
            rewardToken,
            1 days,
            false
        );
    }

    function test_transferRewards_increasesAccumulatedRewards() public {
        uint256 amount = 1_000e18;
        address user = address(0xBEEF);

        rewardToken.mint(user, amount);

        vm.prank(user);
        rewardToken.approve(address(accumulator), amount);

        vm.prank(user);
        accumulator.transferAndNotifyRewards(amount);

        assertEq(rewardToken.balanceOf(address(accumulator)), amount);
        assertEq(accumulator.accumulatedRewards(), amount);
    }

    function test_sendRewardsToStaker_revertsBeforeNextRewardTime() public {
        uint256 amount = 500e18;
        address user = address(0xBEEF);

        rewardToken.mint(user, amount);

        vm.prank(user);
        rewardToken.approve(address(accumulator), amount);

        vm.prank(user);
        accumulator.transferAndNotifyRewards(amount);

        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.WaitForNextRewardTime.selector, accumulator.nextRewardTime()));
        accumulator.sendRewardsToStaker();
    }

    function test_sendRewardsToStaker_sendsRewardsAndResetsState() public {
        uint256 amount = 500e18;
        address user = address(0xBEEF);

        rewardToken.mint(user, amount);

        vm.prank(user);
        rewardToken.approve(address(accumulator), amount);

        vm.prank(user);
        accumulator.transferAndNotifyRewards(amount);

        uint256 previousNextRewardTime = accumulator.nextRewardTime();

        vm.warp(block.timestamp + 2 days);
        accumulator.sendRewardsToStaker();

        assertEq(rewardToken.balanceOf(address(mockStaker)), amount);
        assertEq(mockStaker.lastNotifiedAmount(), amount);
        assertEq(accumulator.accumulatedRewards(), 0);
        assertEq(accumulator.nextRewardTime(), previousNextRewardTime + 1 days);
    }
}

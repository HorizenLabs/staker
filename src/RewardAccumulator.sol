// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import {Staker} from "./Staker.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RewardAccumulator is Ownable {

    Staker public immutable staker;
    ERC20 public immutable rewardToken;

    uint256 public lastRewardTime;
    uint256 public timeWindow;
    bool public whitelistEnabled;
    mapping(address => bool) public whitelist;
    uint256 public accumulatedRewards;

    error NotWhitelisted();
    error WaitForNextRewardTime(uint256 nextRewardTime);
    error TransferDontFound();

    modifier onlyWhitelisted() {
        if (whitelistEnabled && !whitelist[msg.sender]) {
            revert NotWhitelisted();
        }
        _;
    }
    
    constructor(Staker _staker, ERC20 _rewardToken, uint256 _timeWindow, bool _whitelistEnabled) Ownable(msg.sender) {
        staker = _staker;
        rewardToken = _rewardToken;
        timeWindow = _timeWindow;
        whitelistEnabled = _whitelistEnabled;
        lastRewardTime = block.timestamp;
    }

    // Admin functions
    function setTimeWindow(uint256 _timeWindow) external onlyOwner {
        timeWindow = _timeWindow;
    }

    function setWhitelistEnabled(bool enabled) external onlyOwner {
        whitelistEnabled = enabled;
    }

    function setWhitelist(address user, bool enabled) external onlyOwner {
        whitelist[user] = enabled;
    }

    function nextRewardTime() public view returns (uint256) {
        return lastRewardTime + timeWindow;
    }

    //RewardAccumulator functions

    function transferAndNotifyRewards(uint256 amount) external onlyWhitelisted {
        // transfer tokens in this contract
        SafeERC20.safeTransferFrom(rewardToken, msg.sender, address(this), amount);
        // update accumulated rewards
        accumulatedRewards += amount;
    }

    //invoke this method after safeTransferFrom if you prefer to transfer them manually and then notify the contract - use the same exact amount as the one you transferred to the contract
    function notifyRewardsAlreadyTransferred(uint256 amount) external onlyWhitelisted {
        // check that the amount transferred in is equal to the amount specified
        if (rewardToken.balanceOf(address(this)) - accumulatedRewards != amount) {
            revert TransferDontFound();
        }
        // update accumulated rewards
        accumulatedRewards += amount;
    }
    
    function sendRewardsToStaker() public {
        if (block.timestamp < nextRewardTime()) {
            revert WaitForNextRewardTime(nextRewardTime());
        }

        uint256 rewardAmount = accumulatedRewards;

        // transfer accumulated rewards to staker
        SafeERC20.safeTransfer(rewardToken, address(staker), rewardAmount);
        // notify the staker that rewards were transferred in
        staker.notifyRewardAmount(rewardAmount);
        // reset accumulated rewards
        accumulatedRewards = 0;
        // update last reward time
        lastRewardTime += timeWindow;
    }
        
}
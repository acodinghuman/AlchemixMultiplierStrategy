// Mostly copied from strategy StrategyMakerV2_ETH-C
// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

interface GemLike {
    function approve(address, uint256) external;

    function transfer(address, uint256) external;

    function transferFrom(
        address,
        address,
        uint256
    ) external;

    function deposit() external payable;

    function withdraw(uint256) external;
}

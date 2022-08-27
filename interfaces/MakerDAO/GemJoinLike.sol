// Mostly copied from strategy StrategyMakerV2_ETH-C
// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.4;

import "./GemLike.sol";

interface GemJoinLike {
    function dec() external returns (uint256);

    function gem() external returns (GemLike);

    function join(address, uint256) external payable;

    function exit(address, uint256) external;
}

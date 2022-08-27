// Mostly copied from strategy StrategyMakerV2_ETH-C
// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

interface DssAutoLine {
    function exec(bytes32 _ilk) external returns (uint256);
}

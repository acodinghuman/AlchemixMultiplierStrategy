// Mostly copied from strategy StrategyMakerV2_ETH-C
// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

interface SpotLike {
    function live() external view returns (uint256);

    function par() external view returns (uint256);

    function vat() external view returns (address);

    function ilks(bytes32) external view returns (address, uint256);
}

// Mostly copied from strategy StrategyMakerV2_ETH-C
// SPDX-License-Identifier: AGPL-3.0

import "./VatLike.sol";
import "./GemLike.sol";

pragma solidity 0.8.4;

interface DaiJoinLike {
    function vat() external returns (VatLike);

    function dai() external returns (GemLike);

    function join(address, uint256) external payable;

    function exit(address, uint256) external;
}

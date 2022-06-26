// SPDX-License-Identifier: TBD (To Be Done)
pragma solidity >=0.5.0;

// The interface to the library OracleLibrary.sol form uniswap v3-periphery
// The reason for such behaviour is that the solidity versions (OracleLibrary speifies under 0.8.0) does not match
// So the OracleLibrary will be deployed separately and this interface will be used to access it.
interface IOracleLibrary {
    /// @notice Given a tick and a token amount, calculates the amount of token received in exchange
    /// @param tick Tick value used to calculate the quote
    /// @param baseAmount Amount of token to be converted
    /// @param baseToken Address of an ERC20 token contract used as the baseAmount denomination
    /// @param quoteToken Address of an ERC20 token contract used as the quoteAmount denomination
    /// @return quoteAmount Amount of quoteToken received for baseAmount of baseToken
    function getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) external pure returns (uint256 quoteAmount);
}

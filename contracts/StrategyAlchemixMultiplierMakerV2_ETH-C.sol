// SPDX-License-Identifier: TBD (To Be Done)
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "../interfaces/Uniswap/IOracleLibrary.sol";
import "../interfaces/Aave/v2/ILendingPool.sol";
import "../interfaces/Aave/v2/ILendingPoolAddressesProvider.sol";
import "../interfaces/Aave/v2/IFlashLoanReceiver.sol";
import "../interfaces/Aave/v2/FlashLoanReceiverBase.sol";
import "../interfaces/Alchemix/IAlchemistV2.sol";
import "../interfaces/Alchemix/ITokenAdapter.sol";
import "../interfaces/Curve/ICurvePool.sol";
import "../interfaces/Curve/ICurveMetaPool.sol";
import "../interfaces/Curve/ICurveMetaPoolFactory.sol";
import "../interfaces/Yearn/BaseStrategy.sol";
import "./tempconsole.sol";

contract StrategyAlchemixMultiplierMakerV2_ETH_C is FlashLoanReceiverBase {
    using SafeMath for uint256;

    // DAI token address 0x6B175474E89094C44Da98b954EedeAC495271d0F
    address constant daiContractAddress =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // yDAI address
    address constant ydaiContractAddress =
        0xdA816459F1AB5631232FE5e97a05BBBb94970c95;

    // Alchemix yDai Adapter
    // I use this contract for ydai price per share discovery (to be used in liquidation process) instead of yDai contract itself because
    // the process seems to be more an Alchemix thing than a Yearn one and one approach would be to stay closer to Alchemix
    address constant ydaiAdapterAddress =
        0xA7AA5BE408B817A516b40Daea7a919664f13f193;

    // Alusd token address
    address constant alusdAddress = 0xBC6DA0FE9aD5f3b0d58160288917AA56653660E9;

    // Alchemix contract address
    address constant alchemistContractAddress =
        0x5C6374a2ac4EBC38DeA0Fc1F8716e5Ea1AdD94dd;

    // WETH Token address
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Want token
    address constant want = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Alchemist contract
    IAlchemistV2 alchemist = IAlchemistV2(alchemistContractAddress);

    // Curve Metapool Factory Address
    address constant curveMetaPoolFactoryAddress =
        0xB9fC157394Af804a3578134A6585C0dc9cc990d4;

    // The uniswap pool used to get price for ethToWant function
    // The method is based on https://www.youtube.com/watch?v=tGW8MoiNj54 and
    // https://github.com/t4sk/uniswap-v3-twap/blob/main/contracts/UniswapV3Twap.sol
    // To get the address pool to pass to the constructor the getPool funcion on IUniswapV3Factory could be used or
    // etherscan.io with the proper factory address from https://docs.uniswap.org/protocol/reference/deployments
    // ( for example 0x1F98431c8aD98523631AE4a59f267346ea31F984 )
    address uniswapPriceOraclePool;

    // The uniswap oracle library
    IOracleLibrary uniswapOracleLibrary;

    // DAI token
    IERC20 internal constant DAI = IERC20(daiContractAddress);

    ILendingPoolAddressesProvider
        internal constant lendingPoolAddressesProvider =
        ILendingPoolAddressesProvider(
            0xAcc030EF66f9dFEAE9CbB0cd1B25654b82cFA8d5
        );

    constructor(address _uniswapPriceOraclePool, address _uniswapOracleLibrary)
        FlashLoanReceiverBase(lendingPoolAddressesProvider)
    {
        uniswapPriceOraclePool = _uniswapPriceOraclePool;
        uniswapOracleLibrary = IOracleLibrary(_uniswapOracleLibrary);
    }

    function investBorrowedDaiIntoAlchemix(uint256 amount) external {
        tempconsole.log("Strategy main function entered.");

        // Transfering the borrowed dai to the strategy
        DAI.transferFrom(msg.sender, address(this), amount);

        tempconsole.log("The specified amount of dai transfered.");

        // Starting the flash loan process
        address receiverAddress = address(this);
        address[] memory assets = new address[](1);
        assets[0] = daiContractAddress;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount.mul(2);

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        address onBehalfOf = address(this);
        bytes memory params = "";
        uint16 referralCode = 0;

        tempconsole.log("Before calling flashloan.");

        LENDING_POOL.flashLoan(
            receiverAddress,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );

        tempconsole.log("After calling flashloan.");
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        tempconsole.log(
            "Flashloan call strated. Requested premium is: ",
            premiums[0]
        );

        // Approving Dai for Alchemix
        DAI.approve(alchemistContractAddress, amounts[0]);
        tempconsole.log("Dai approved for the alchemix");

        // TODO: depositing underlying token needs more study, the internal _wrap function talks about slippage
        // Depositing the flash loaned amount to Alchemix smart contract
        uint256 depositShares = alchemist.depositUnderlying(
            ydaiContractAddress,
            amounts[0],
            address(this),
            0
        );
        tempconsole.log("Dai deposited to Alchemix: ", depositShares);

        // Mint the derived tokens
        uint256 mintedTokens = mintTheDerivedToken(amounts[0], depositShares);

        // Gettinng the appropriate pool
        ICurveMetaPool pool = ICurveMetaPool(
            findTheAppropriteCurvePool(alusdAddress, daiContractAddress)
        );

        tempconsole.log("CurveMetaPool found.");

        // Approve alUSD for Curve Meta Pool
        IERC20(alusdAddress).approve(address(pool), mintedTokens);

        // Required amount
        // TODO: Slippage should be decided about
        uint256 requiredDaiAmount = mintedTokens.mul(980).div(1000);

        // Exchanging the minted token for Dai
        // TODO: Where these indecies come from, I copied from etherscan successful transactions
        uint256 converted = pool.exchange_underlying(
            0,
            1,
            mintedTokens,
            requiredDaiAmount
        );

        tempconsole.log("alUSD exchanged. The resulting Dai is: ", converted);

        // withdrawing the required amount
        withdrawTheRequiredAmount(amounts[0].div(2), converted, premiums[0]);

        // Approving Dai for Aave
        approveDaiForLendingPool(amounts[0] + premiums[0]);

        tempconsole.log(
            "Dai balance before flashloan return is: ",
            DAI.balanceOf(address(this))
        );

        // Dummy return
        return true;
    }

    function mintTheDerivedToken(
        uint256 flashloanedAmount,
        uint256 depositShares
    ) internal returns (uint256) {
        // Half of the flash loaned amount
        uint256 halfAmount = flashloanedAmount.div(2);

        // Obtaining the rate for coverting yield generating asset to base asset
        ITokenAdapter tokenAdapter = ITokenAdapter(ydaiAdapterAddress);
        uint256 yieldTokenPrice = tokenAdapter.price();

        // uint256 tokensToBeMinted = (depositShares * yieldTokenPrice) / (2 * 1e18) ;
        // ToDo: The 1e18 should be looked at
        uint256 tokensToBeMinted = halfAmount - 1e18;

        console.log("yield token price: ", yieldTokenPrice);

        console.log("Number of tokens to be minted: ", tokensToBeMinted);

        // Minting respective alchemix token for half of deposited amount
        // TOFO: mint value should be considered
        alchemist.mint(tokensToBeMinted, address(this));

        tempconsole.log("alUSD minted: ", tokensToBeMinted);

        // TODO: To be removed in final release
        logAlUSDBalance();

        return tokensToBeMinted;
    }

    function withdrawTheRequiredAmount(
        uint256 halfAmount,
        uint256 converted,
        uint256 premium
    ) internal {
        // Finding out how much remained which we should return to close flash loan successfully
        uint256 notConverted = halfAmount - converted;

        // liquidating the not converted amount + fee
        uint256 amountToLiquidate = notConverted + premium;

        tempconsole.log("Amount to liquidate: ", amountToLiquidate);

        // Obtaining the rate for coverting yield generating asset to base asset
        ITokenAdapter tokenAdapter = ITokenAdapter(ydaiAdapterAddress);
        uint256 yieldTokenPrice = tokenAdapter.price();

        // Calculating the yield generating token amount to liquidate
        // TODO: This formula may need some review, because the division operation may give some less value than actually required
        // +1e18 is currently added to cover possible rounding problems
        uint256 yieldAmountToLiquidate = amountToLiquidate
            .div(yieldTokenPrice)
            .mul(1e18) + 10e18;

        // Actual liquidation
        alchemist.liquidate(
            ydaiContractAddress,
            yieldAmountToLiquidate,
            yieldAmountToLiquidate
        );

        tempconsole.log("Liquidation completed.");

        // Withdrawing the Dai
        // alchemist.withdrawUnderlying(ydaiContractAddress, yieldAmountToLiquidate, address(this), amountToLiquidate);
        uint256 withdrawnAmount = alchemist.withdrawUnderlying(
            ydaiContractAddress,
            yieldAmountToLiquidate,
            address(this),
            0
        );

        tempconsole.log(
            "Withdraw completed, amount withdrawn: ",
            withdrawnAmount
        );
    }

    function approveDaiForLendingPool(uint256 amount) internal {
        address lendingPoolAddress = address(LENDING_POOL);
        IERC20 daiContract = IERC20(daiContractAddress);
        daiContract.approve(lendingPoolAddress, amount);
    }

    function logAlUSDBalance() internal view {
        uint256 alusdBalance = IERC20(alusdAddress).balanceOf(address(this));

        tempconsole.log("alusd balance.", alusdBalance);
    }

    function findTheAppropriteCurvePool(
        address sourceTokenAddress,
        address destinationTokenAddress
    ) internal view returns (address) {
        // Finding the pool
        ICurveMetaPoolFactory metaPoolFactory = ICurveMetaPoolFactory(
            curveMetaPoolFactoryAddress
        );

        // Finding the pool
        return
            metaPoolFactory.find_pool_for_coins(
                sourceTokenAddress,
                destinationTokenAddress,
                0
            );
    }

    /**
     * @notice This Strategy's name.
     * @return This Strategy's name.
     */
    function name() external view returns (string memory) {
        return "StrategyAlchemixMultiplierMakerV2_ETH_C_V1";
    }

    /**
     * @notice Updates the uniswap pool address which is used it ethToWant function
     * @param _uniswapPriceOraclePool The new uniswap pool address, see the description for uniswapPriceOraclePool
     * for more details
     */
    function updateUniswapPriceOraclePool(address _uniswapPriceOraclePool)
        external
        onlyAuthorized
    {
        require(_uniswapPriceOraclePool != address(0), "pool doesn't exist");
        uniswapPriceOraclePool = _uniswapPriceOraclePool;
    }

    /**
     * @notice
     *  Provide an accurate conversion from `_amtInWei` (denominated in wei)
     *  to `want` (using the native decimal characteristics of `want`).
     *  The current implementation uses uniswap version 3 to do the coversion, more details could be found in
     *  uniswapPriceOraclePool docmentation
     * @param _amtInWei The amount (in wei/1e-18 ETH) to convert to `want`
     * @return The amount in `want` of `_amtInWei` converted to `want`
     **/
    function ethToWant(uint256 _amtInWei) public view returns (uint256) {
        // As of 26 June 2022 about 121.4 milion ETHs are mined, which is about 121.4 * 10^6 * 10^18 Wei or 121.4 * 10^24 Wei
        // This consumes about 86.65 bits and is far from 128 bits
        // 128 bit limitation is for the function getQuoteAtTick
        require(
            _amtInWei <= type(uint128).max,
            "Input values larger than uint128.max are not currently supported."
        );

        if (
            _amtInWei == 0 ||
            _amtInWei == type(uint256).max ||
            address(want) == address(weth) // 1:1 change
        ) {
            return _amtInWei;
        }

        uint32[] memory secondsAgos = new uint32[](2);
        uint32 secondsAgo = 60; // 1 minute ago
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        // int56 since tick * time = int24 * uint32
        // 56 = 24 + 32
        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(
            uniswapPriceOraclePool
        ).observe(secondsAgos);

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];

        // int56 / uint32 = int24
        int24 tick = int24(tickCumulativesDelta / int32(secondsAgo));
        // Always round to negative infinity
        /*
        int doesn't round down when it is negative
        int56 a = -3
        -3 / 10 = -3.3333... so round down to -4
        but we get
        a / 10 = -3
        so if tickCumulativeDelta < 0 and division has remainder, then round
        down
        */
        if (
            tickCumulativesDelta < 0 &&
            (tickCumulativesDelta % int32(secondsAgo) != 0)
        ) {
            tick--;
        }

        uint256 amountOut = uniswapOracleLibrary.getQuoteAtTick(
            tick,
            uint128(_amtInWei),
            weth,
            want
        );

        return amountOut;
    }

    // ToDo: After BaseStrategy Inheritance override should be added
    function protectedTokens() internal view returns (address[] memory) {
        address[] memory protected = new address[](3);
        protected[0] = daiContractAddress;
        protected[1] = ydaiContractAddress;
        protected[3] = alusdAddress;
        return protected;
    }

    // ToDo: The folowing functions should be removed when BaseStrategy implementation is finished
    modifier onlyAuthorized() {
        _onlyAuthorized();
        _;
    }

    function _onlyAuthorized() internal {
        require(msg.sender == strategist || msg.sender == governance);
    }

    address public strategist;

    address public governance;
}

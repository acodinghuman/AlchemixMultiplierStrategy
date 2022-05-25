// SPDX-License-Identifier: TBD (To Be Done)
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/Aave/v2/ILendingPool.sol";
import "../interfaces/Aave/v2/ILendingPoolAddressesProvider.sol";
import "../interfaces/Aave/v2/IFlashLoanReceiver.sol";
import "../interfaces/Aave/v2/FlashLoanReceiverBase.sol";
import "../interfaces/Alchemix/IAlchemistV2.sol";
import "../interfaces/Alchemix/ITokenAdapter.sol";
import "../interfaces/Curve/ICurvePool.sol";
import "../interfaces/Curve/ICurveMetaPool.sol";
import "../interfaces/Curve/ICurveMetaPoolFactory.sol";
import "./tempconsole.sol";

contract StrategyAlchemixMultiplierMakerV2_ETH_C is FlashLoanReceiverBase {

  using SafeMath for uint256;
  
  // DAI token address 0x6B175474E89094C44Da98b954EedeAC495271d0F
  address constant daiContractAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

  // yDAI address
  address constant ydaiContractAddress = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;

  // Alchemix yDai Adapter
  // I use this contract for ydai price per share discovery (to be used in liquidation process) instead of yDai contract itself because
  // the process seems to be more an Alchemix thing than a Yearn one and one approach would be to stay closer to Alchemix
  address constant ydaiAdapterAddress = 0xA7AA5BE408B817A516b40Daea7a919664f13f193;

  // Alusd token address
  address constant alusdAddress = 0xBC6DA0FE9aD5f3b0d58160288917AA56653660E9;

  // Alchemix contract address
  address constant alchemistContractAddress = 0x5C6374a2ac4EBC38DeA0Fc1F8716e5Ea1AdD94dd;

  // Alchemist contract
  IAlchemistV2 alchemist = IAlchemistV2(alchemistContractAddress);

  // Curve Metapool Factory Address
  address constant curveMetaPoolFactoryAddress = 0xB9fC157394Af804a3578134A6585C0dc9cc990d4;

  // DAI token
  IERC20 internal constant DAI = IERC20(daiContractAddress);

  ILendingPoolAddressesProvider internal constant lendingPoolAddressesProvider = 
	ILendingPoolAddressesProvider(0xAcc030EF66f9dFEAE9CbB0cd1B25654b82cFA8d5);  

  constructor() FlashLoanReceiverBase(lendingPoolAddressesProvider)
  {
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

  LENDING_POOL.flashLoan(receiverAddress, assets, amounts, modes,
	onBehalfOf, params, referralCode);

  tempconsole.log("After calling flashloan.");

  }

  function executeOperation(address[] calldata assets, uint256[] calldata amounts,
	uint256[] calldata premiums, address initiator, bytes calldata params) external override returns(bool)
  {  
  tempconsole.log("Flashloan call strated. Requested premium is: ", premiums[0]);

  // Approving Dai for Alchemix
  DAI.approve(alchemistContractAddress, amounts[0]);
  tempconsole.log("Dai approved for the alchemix");

  // TODO: depositing underlying token needs more study, the internal _wrap function talks about slippage
  // Depositing the flash loaned amount to Alchemix smart contract
  uint256 depositShares = alchemist.depositUnderlying(ydaiContractAddress, amounts[0], address(this), 0);
  tempconsole.log("Dai deposited to Alchemix: ", depositShares);

  // Mint the derived tokens
  uint256 mintedTokens = mintTheDerivedToken(amounts[0], depositShares);

  // Gettinng the appropriate pool
  ICurveMetaPool pool = ICurveMetaPool(findTheAppropriteCurvePool(alusdAddress, daiContractAddress));

  tempconsole.log("CurveMetaPool found.");

  // Approve alUSD for Curve Meta Pool
  IERC20(alusdAddress).approve(address(pool), mintedTokens);  

  // Required amount
  // TODO: Slippage should be decided about
  uint256 requiredDaiAmount = mintedTokens.mul(980).div(1000);

  // Exchanging the minted token for Dai
  // TODO: Where these indecies come from, I copied from etherscan successful transactions
  uint256 converted = pool.exchange_underlying(0, 1, mintedTokens, requiredDaiAmount);

  tempconsole.log("alUSD exchanged. The resulting Dai is: ", converted);

  // withdrawing the required amount
  withdrawTheRequiredAmount(amounts[0].div(2), converted, premiums[0]);

  // Approving Dai for Aave
  approveDaiForLendingPool(amounts[0] + premiums[0]);

  tempconsole.log("Dai balance before flashloan return is: ", DAI.balanceOf(address(this)));
  
  // Dummy return 
  return true;
  }

  function mintTheDerivedToken(uint256 flashloanedAmount, uint256 depositShares) internal returns (uint256)
  {
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
  alchemist.mint(tokensToBeMinted , address(this));

  tempconsole.log("alUSD minted: ", tokensToBeMinted);

  // TODO: To be removed in final release
  logAlUSDBalance();

  return tokensToBeMinted;
  }

  function withdrawTheRequiredAmount(uint256 halfAmount, uint256 converted, uint256 premium) internal
  {
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
    uint256 yieldAmountToLiquidate = amountToLiquidate.div(yieldTokenPrice).mul(1e18) + 10e18;

    // Actual liquidation
    alchemist.liquidate(ydaiContractAddress, yieldAmountToLiquidate, yieldAmountToLiquidate);

    tempconsole.log("Liquidation completed.");

    // Withdrawing the Dai
    // alchemist.withdrawUnderlying(ydaiContractAddress, yieldAmountToLiquidate, address(this), amountToLiquidate);
    uint256 withdrawnAmount = alchemist.withdrawUnderlying(ydaiContractAddress, yieldAmountToLiquidate, address(this), 0);

    tempconsole.log("Withdraw completed, amount withdrawn: ", withdrawnAmount);
  }

  function approveDaiForLendingPool(uint256 amount) internal
  {
    address lendingPoolAddress = address(LENDING_POOL);
    IERC20 daiContract = IERC20(daiContractAddress);
    daiContract.approve(lendingPoolAddress, amount);
  }

  function logAlUSDBalance() internal view
  {
  uint256 alusdBalance = IERC20(alusdAddress).balanceOf(address(this));

  tempconsole.log("alusd balance.", alusdBalance);
  }

  function findTheAppropriteCurvePool(address sourceTokenAddress, address destinationTokenAddress) internal view returns (address)
  {
  // Finding the pool
  ICurveMetaPoolFactory metaPoolFactory = ICurveMetaPoolFactory(curveMetaPoolFactoryAddress);

  // Finding the pool
  return metaPoolFactory.find_pool_for_coins(sourceTokenAddress, destinationTokenAddress, 0);
  }
}

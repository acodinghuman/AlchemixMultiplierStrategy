// SPDX-License-Identifier: TBD (To Be Done)
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/Aave/v2/ILendingPool.sol";
import "../interfaces/Aave/v2/ILendingPoolAddressesProvider.sol";
import "../interfaces/Aave/v2/IFlashLoanReceiver.sol";
import "../interfaces/Aave/v2/FlashLoanReceiverBase.sol";
import "../interfaces/Alchemix/IAlchemistV2.sol";
import "../interfaces/Curve/ICurvePool.sol";
import "../interfaces/Curve/ICurveMetaPool.sol";
import "../interfaces/Curve/ICurveMetaPoolFactory.sol";
import "./tempconsole.sol";

contract StrategyAlchemixMultiplierMakerV2_ETH_C is FlashLoanReceiverBase {

  using SafeMath for uint256;
  
  // DAI token address 0x6B175474E89094C44Da98b954EedeAC495271d0F
  address constant daiContractAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

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
  
  // Transfering the borrowed dai to the strategy
  DAI.transferFrom(msg.sender, address(this), amount);

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

  LENDING_POOL.flashLoan(receiverAddress, assets, amounts, modes,
	onBehalfOf, params, referralCode);
  }

  function executeOperation(address[] calldata assets, uint256[] calldata amounts,
	uint256[] calldata premiums, address initiator, bytes calldata params) external override returns(bool)
  {  
  // Depositing the flash loaned amount to Alchemix smart contract
  alchemist.deposit(daiContractAddress, amounts[0], address(this));
  tempconsole.log("Alchemix deposit called");

  // Half of the flash loaned amount
  uint256 halfAmount = amounts[0].div(2);

  // Minting respective alchemix token for half of deposited amount
  alchemist.mint(halfAmount, address(this));

  // Gettinng the appropriate pool
  ICurveMetaPool pool = ICurveMetaPool(findTheAppropriteCurvePool(alusdAddress, daiContractAddress));

  // Required amount
  // TODO: Slippage should be decided about
  uint256 requiredDaiAmount = halfAmount.mul(995).div(1000);

  // Exchanging the minted token for Dai
  // alUSD index is 0
  // In 3crv, we have 0: Dai, 1: USDC, 2: Tether
  uint256 converted = pool.exchange_underlying(0, 0, halfAmount, requiredDaiAmount);

  // Finding out how much remained which we should return to close flash loan successfully 
  uint256 notConverted = halfAmount - converted;

  // liquidating the not converted amount + fee
  uint256 amountToLiquidate = notConverted + premiums[0];
  alchemist.liquidate(daiContractAddress, amountToLiquidate, amountToLiquidate);

  // Withdrawing the Dai
  alchemist.withdraw(daiContractAddress, amountToLiquidate, address(this));

  // Approving Dai for Aave
  approveDaiForLendingPool(amounts[0]);
  
  // Dummy return 
  return true;
  }

  function approveDaiForLendingPool(uint256 amount) internal
  {
    address lendingPoolAddress = address(LENDING_POOL);
    IERC20 daiContract = IERC20(daiContractAddress);
    daiContract.approve(lendingPoolAddress, amount);
  }

  function findTheAppropriteCurvePool(address sourceTokenAddress, address destinationTokenAddress) internal view returns (address)
  {
  // Finding the pool
  ICurveMetaPoolFactory metaPoolFactory = ICurveMetaPoolFactory(curveMetaPoolFactoryAddress);

  // Finding the pool
  return metaPoolFactory.find_pool_for_coins(sourceTokenAddress, destinationTokenAddress, 0);
  }
}

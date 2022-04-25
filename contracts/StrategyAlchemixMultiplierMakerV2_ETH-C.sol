// SPDX-License-Identifier: TBD (To Be Done)
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/Aave/v2/ILendingPool.sol";
import "../interfaces/Aave/v2/ILendingPoolAddressesProvider.sol";
import "../interfaces/Aave/v2/IFlashLoanReceiver.sol";
import "../interfaces/Aave/v2/FlashLoanReceiverBase.sol";

contract Strategy is FlashLoanReceiverBase {

  using SafeMath for uint256;
  
  // DAI token address 0x6B175474E89094C44Da98b954EedeAC495271d0F
  address constant daiContractAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

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

  /*  
  // Getting the flash loan
  ILendingPoolAddressesProvider lendingPoolAddressesProvider = 
	ILendingPoolAddressesProvider(0xAcc030EF66f9dFEAE9CbB0cd1B25654b82cFA8d5);

  // Getting the lending pool address
  address lendingPoolAddress = lendingPoolAddressesProvider.getLendingPool();

  // Getting the lending pool
  ILendingPool lendingPool = ILendingPool(lendingPoolAddress);
  */

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
  return true;
  }
}

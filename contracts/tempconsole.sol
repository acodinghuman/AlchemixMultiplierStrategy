// SPDX-License-Identifier: MIT
// To remove dependency on hardhat, hardhat import should be removed, and the log methods should be emptied.
// The dependency on hardhat will probably removed in further stages of development

pragma solidity >= 0.6.0;

import "hardhat/console.sol";

library tempconsole {
   function log(string memory message) external view {
        console.log(message);
        }
}


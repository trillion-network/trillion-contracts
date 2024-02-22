// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// dummy token for testing rescue function
contract Ramen is ERC20 {
    constructor(uint256 initialSupply) ERC20("Ramen", "RMN") {
        _mint(msg.sender, initialSupply);
    }
}

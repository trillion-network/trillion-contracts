// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Rescuable is AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant RESCUER_ROLE = keccak256("RESCUER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Rescue tokens from contract
     * @param token     ERC20 token contract address
     * @param to        Recipient address
     * @param amount    The amount of tokens to withdraw
     */
    function rescue(IERC20 token, address to, uint256 amount) external onlyRole(RESCUER_ROLE) {
        token.safeTransfer(to, amount);
    }
}

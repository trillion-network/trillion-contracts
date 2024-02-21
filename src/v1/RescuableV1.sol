// SPDX-License-Identifier: MIT
// solhint-disable func-name-mixedcase
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Rescuable Token
 * @dev Allows tokens to be rescued by a "rescuer" role
 * @custom:security-contact snggeng@gmail.com
 */
abstract contract RescuableV1 is Initializable {
    using SafeERC20 for IERC20;

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
    function _rescue(IERC20 token, address to, uint256 amount) internal {
        token.safeTransfer(to, amount);
    }

    /**
     * @dev Internal initializer function using OZ naming convention __{ContractName}_init
     *
     * Contract inheriting from this should call this function in thei public initialize() function
     */
    function __ERC20Rescuable_init() internal onlyInitializing {}
}

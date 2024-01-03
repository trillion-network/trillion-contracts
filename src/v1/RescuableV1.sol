// SPDX-License-Identifier: MIT
// solhint-disable func-name-mixedcase
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract RescuableV1 is Initializable, ContextUpgradeable, ERC20Upgradeable {
    using SafeERC20 for IERC20;

    /**
     * @dev Rescue tokens from contract
     * @param token     ERC20 token contract address
     * @param to        Recipient address
     * @param amount    The amount of tokens to withdraw
     */
    function rescue(IERC20 token, address to, uint256 amount) public virtual {
        token.safeTransfer(to, amount);
    }

    function __ERC20Rescuable_init() internal onlyInitializing {}

    function __ERC20Rescuable_init_unchained() internal onlyInitializing {}
}

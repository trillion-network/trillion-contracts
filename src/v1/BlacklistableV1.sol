// SPDX-License-Identifier: MIT
// solhint-disable func-name-mixedcase
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

error CallerBlacklisted(address account);

/**
 * @title Blacklistable Token
 * @dev Allows accounts to be blacklisted by a "blacklister" role
 */
abstract contract BlacklistableV1 is Initializable, ContextUpgradeable, ERC20Upgradeable {
    mapping(address accountAddress => bool blacklisted) internal _blacklisted;

    event Blacklisted(address indexed account);
    event UnBlacklisted(address indexed account);

    /**
     * @dev Throws if argument account is blacklisted.
     * @param account The address to check.
     */
    modifier notBlacklisted(address account) {
        if (_blacklisted[account]) {
            revert CallerBlacklisted(account);
        }
        _;
    }

    /**
     * @dev Adds account to blacklist
     * @param account The address to blacklist
     */
    function blacklist(address account) public virtual {
        _blacklisted[account] = true;
        emit Blacklisted(account);
    }

    /**
     * @dev Removes account from blacklist
     * @param account The address to remove from the blacklist
     */
    function unBlacklist(address account) public virtual {
        _blacklisted[account] = false;
        emit UnBlacklisted(account);
    }

    /**
     * @dev Checks if account is blacklisted
     * @param account The address to check
     */
    function isBlacklisted(address account) public view returns (bool) {
        return _blacklisted[account];
    }

    function __ERC20Blacklistable_init() internal onlyInitializing {}

    function __ERC20Blacklistable_init_unchained() internal onlyInitializing {}
}

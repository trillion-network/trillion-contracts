// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./BlacklistableV1.sol";
import "./RescuableV1.sol";

/// @custom:security-contact snggeng@gmail.com
contract FiatTokenV1 is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    ERC20BurnableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable,
    BlacklistableV1,
    RescuableV1
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant RESCUER_ROLE = keccak256("RESCUER_ROLE");
    bytes32 public constant BLACKLISTER_ROLE = keccak256("BLACKLISTER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address pauser,
        address minter,
        address upgrader,
        address rescuer,
        address blacklister,
        string memory tokenName,
        string memory tokenSymbol
    ) public initializer {
        __ERC20_init(tokenName, tokenSymbol);
        __ERC20Pausable_init();
        __ERC20Burnable_init();
        __AccessControl_init();
        __ERC20Permit_init(tokenName);
        __UUPSUpgradeable_init();
        __ERC20Rescuable_init();
        __ERC20Blacklistable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
        _grantRole(RESCUER_ROLE, rescuer);
        _grantRole(BLACKLISTER_ROLE, blacklister);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(uint256 value) public override(ERC20BurnableUpgradeable) onlyRole(MINTER_ROLE) {
        super.burn(value);
    }

    function burnFrom(address account, uint256 value) public override(ERC20BurnableUpgradeable) onlyRole(MINTER_ROLE) {
        super.burnFrom(account, value);
    }

    function rescue(IERC20 token, address to, uint256 amount) public override(RescuableV1) onlyRole(RESCUER_ROLE) {
        super.rescue(token, to, amount);
    }

    function blacklist(address account) public override(BlacklistableV1) onlyRole(BLACKLISTER_ROLE) {
        super.blacklist(account);
    }

    function unBlacklist(address account) public override(BlacklistableV1) onlyRole(BLACKLISTER_ROLE) {
        super.unBlacklist(account);
    }

    function version() public pure virtual returns (string memory) {
        return "v1";
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
        notBlacklisted(from)
        notBlacklisted(to)
    {
        super._update(from, to, value);
    }
}

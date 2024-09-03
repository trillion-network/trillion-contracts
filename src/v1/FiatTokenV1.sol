// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./BlacklistableV1.sol";
import "./RescuableV1.sol";

error UnauthorizedInitialization(address addr);

/// @custom:security-contact snggeng@gmail.com
contract FiatTokenV1 is
    Initializable,
    ERC20Upgradeable,
    ERC20CappedUpgradeable,
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
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @dev reserve storage slots so that future upgrades do not affect storage layout of child contracts
    /// when extra variables are added, reduce the appropriate slots from the storage gap
    /// See https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#storage-gaps
    uint256[50] private __gap;
    /// @dev maximum token supply for contract
    /// for reference, in 2023, there's about ~2.3 trillion USD in circulation
    /// we set the max supply to 1 trillion tokens (1e12 * 1e18 = 1e30 wei)
    /// if we need more than 1 trillion tokens, we can increase the max supply
    uint256 public constant MAX_TOKEN_SUPPLY = 1e30;
    /// @dev only trusted addresses can deploy the contract
    mapping(address trustedAddress => bool isTrusted) private _trustedAddresses;

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
        // trusted addresses owned by Trillion
        _trustedAddresses[address(0x66787300CCc33F17643a02635ca96d54301aE2a8)] = true;
        _trustedAddresses[address(0x10eEA4B3d154a30CE70c771D21dFDa85d77a0A16)] = true;

        if (!_trustedAddresses[msg.sender]) {
            revert UnauthorizedInitialization(msg.sender);
        }

        __ERC20_init(tokenName, tokenSymbol);
        __ERC20Capped_init(MAX_TOKEN_SUPPLY);
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

    function burn(uint256 value) public override(ERC20BurnableUpgradeable) onlyRole(BURNER_ROLE) {
        super.burn(value);
    }

    function burnFrom(address account, uint256 value) public override(ERC20BurnableUpgradeable) onlyRole(BURNER_ROLE) {
        super.burnFrom(account, value);
    }

    function rescue(IERC20 token, address to, uint256 amount) public onlyRole(RESCUER_ROLE) {
        super._rescue(token, to, amount);
    }

    function blacklist(address account) public onlyRole(BLACKLISTER_ROLE) {
        super._blacklist(account);
    }

    function unBlacklist(address account) public onlyRole(BLACKLISTER_ROLE) {
        super._unBlacklist(account);
    }

    function addTrustedAddress(address newTrustedAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _trustedAddresses[newTrustedAddress] = true;
    }

    function removeTrustedAddress(address trustedAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _trustedAddresses[trustedAddress] = false;
    }

    function isTrustedAddress(address addr) public view returns (bool) {
        return _trustedAddresses[addr];
    }

    function version() public pure virtual returns (string memory) {
        return "1";
    }

    function decimals() public pure virtual override returns (uint8) {
        return 6;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20CappedUpgradeable, ERC20PausableUpgradeable)
        notBlacklisted(from)
        notBlacklisted(to)
    {
        super._update(from, to, value);
    }
}

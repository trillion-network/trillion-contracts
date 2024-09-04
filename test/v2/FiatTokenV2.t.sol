// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

import {Test, console2} from "forge-std/Test.sol";
import {UnauthorizedInitialization} from "../../src/v1/FiatTokenV1.sol";
import {FiatTokenV2} from "../../src/v2/FiatTokenV2.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC20CappedUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CallerBlacklisted} from "../../src/v1/BlacklistableV1.sol";
import {Ramen} from "../../src/mocks/Ramen.sol";
// import {FiatTokenV99} from "../../src/mocks/FiatTokenV99.sol";

// mock contract to test upgrades
contract FiatTokenV99 is FiatTokenV2 {
    // solhint-disable-next-line foundry-test-functions
    function version() public pure virtual override(FiatTokenV2) returns (string memory) {
        return "99";
    }
}

contract FiatTokenV2Test is Test {
    FiatTokenV2 public fiatTokenV2;
    ERC1967Proxy public proxy;
    address public owner;
    address public defaultAdmin;
    address public pauser;
    address public minter;
    address public upgrader;
    address public rescuer;
    address public blacklister;
    address public unauthorized;
    address public burner;
    address public trustedAddress;
    string public tokenName = "FiatTokenV2";
    string public tokenSymbol = "FIAT";

    // events
    event Blacklisted(address indexed account);
    event UnBlacklisted(address indexed account);

    function setUp() public {
        owner = address(this);
        defaultAdmin = vm.addr(1);
        pauser = vm.addr(2);
        minter = vm.addr(3);
        upgrader = vm.addr(4);
        rescuer = vm.addr(5);
        blacklister = vm.addr(6);
        unauthorized = vm.addr(7);
        burner = vm.addr(8);
        trustedAddress = address(0x66787300CCc33F17643a02635ca96d54301aE2a8);

        // Deploy the token implementation
        fiatTokenV2 = new FiatTokenV2();

        // Deploy the proxy and initialize the contract through the proxy
        vm.prank(trustedAddress);
        proxy = new ERC1967Proxy(
            address(fiatTokenV2),
            abi.encodeCall(
                fiatTokenV2.initialize,
                (defaultAdmin, pauser, minter, upgrader, rescuer, blacklister, tokenName, tokenSymbol)
            )
        );

        // Attach the FiatTokenV2 interface to the deployed proxy
        fiatTokenV2 = FiatTokenV2(address(proxy));

        // Grant BURNER_ROLE to burner
        fiatTokenV2.initializeV2(burner);
    }

    function testUnauthorizedInitialization() public {
        // redeploy new proxy and try to initialize implementation with unauthorized address
        fiatTokenV2 = new FiatTokenV2();
        vm.expectRevert(abi.encodeWithSelector(UnauthorizedInitialization.selector, unauthorized));
        vm.prank(unauthorized);
        proxy = new ERC1967Proxy(
            address(fiatTokenV2),
            abi.encodeCall(
                fiatTokenV2.initialize,
                (defaultAdmin, pauser, minter, upgrader, rescuer, blacklister, tokenName, tokenSymbol)
            )
        );
    }

    // Initialization grants roles

    function testInitializedRoles() public {
        assertEq(fiatTokenV2.hasRole(fiatTokenV2.DEFAULT_ADMIN_ROLE(), defaultAdmin), true);
        assertEq(fiatTokenV2.hasRole(fiatTokenV2.PAUSER_ROLE(), pauser), true);
        assertEq(fiatTokenV2.hasRole(fiatTokenV2.MINTER_ROLE(), minter), true);
        assertEq(fiatTokenV2.hasRole(fiatTokenV2.UPGRADER_ROLE(), upgrader), true);
        assertEq(fiatTokenV2.hasRole(fiatTokenV2.RESCUER_ROLE(), rescuer), true);
        assertEq(fiatTokenV2.hasRole(fiatTokenV2.BLACKLISTER_ROLE(), blacklister), true);
        assertEq(fiatTokenV2.hasRole(fiatTokenV2.BURNER_ROLE(), burner), true);
    }

    // ERC 20 behavior

    function testVersion() public {
        assertEq(fiatTokenV2.version(), "2");
    }

    function testName() public {
        assertEq(fiatTokenV2.name(), tokenName);
    }

    function testSymbol() public {
        assertEq(fiatTokenV2.symbol(), tokenSymbol);
    }

    function testDecimals() public {
        assertEq(fiatTokenV2.decimals(), 6);
    }

    function testBalanceOf() public {
        assertEq(fiatTokenV2.balanceOf(owner), 0);
        vm.prank(minter);
        fiatTokenV2.mint(owner, 100);
        assertEq(fiatTokenV2.balanceOf(owner), 100);
    }

    function testTotalSupply() public {
        assertEq(fiatTokenV2.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV2.mint(owner, 100);
        assertEq(fiatTokenV2.totalSupply(), 100);
    }

    function testApprove() public {
        assertEq(fiatTokenV2.allowance(owner, unauthorized), 0);
        vm.prank(owner);
        fiatTokenV2.approve(unauthorized, 100);
        assertEq(fiatTokenV2.allowance(owner, unauthorized), 100);
    }

    function testMint() public {
        assertEq(fiatTokenV2.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV2.mint(owner, 100);
        assertEq(fiatTokenV2.totalSupply(), 100);
        assertEq(fiatTokenV2.balanceOf(owner), 100);
    }

    function testMintUnauthorized() public {
        assertEq(fiatTokenV2.totalSupply(), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, fiatTokenV2.MINTER_ROLE()
            )
        );
        vm.prank(unauthorized);
        fiatTokenV2.mint(owner, 100);
    }

    function testMintAboveCap() public {
        assertEq(fiatTokenV2.cap(), 1e30);
        assertEq(fiatTokenV2.totalSupply(), 0);
        vm.expectRevert(abi.encodeWithSelector(ERC20CappedUpgradeable.ERC20ExceededCap.selector, 1e31, 1e30));
        vm.prank(minter);
        fiatTokenV2.mint(owner, 1e31);

        // nothing minted
        assertEq(fiatTokenV2.totalSupply(), 0);
    }

    function testBurn() public {
        assertEq(fiatTokenV2.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV2.mint(burner, 100);
        assertEq(fiatTokenV2.totalSupply(), 100);
        assertEq(fiatTokenV2.balanceOf(burner), 100);
        vm.prank(burner);
        fiatTokenV2.burnBurner(100);
        assertEq(fiatTokenV2.totalSupply(), 0);
        assertEq(fiatTokenV2.balanceOf(burner), 0);
    }

    function testBurnMustBeLessThanBalance() public {
        assertEq(fiatTokenV2.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV2.mint(burner, 100);
        assertEq(fiatTokenV2.totalSupply(), 100);
        assertEq(fiatTokenV2.balanceOf(burner), 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                burner, // from
                100, // fromBalance
                101 // value
            )
        );
        vm.prank(burner);
        fiatTokenV2.burnBurner(101);
    }

    function testBurnUnauthorized() public {
        assertEq(fiatTokenV2.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV2.mint(owner, 100);
        assertEq(fiatTokenV2.totalSupply(), 100);
        assertEq(fiatTokenV2.balanceOf(owner), 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized, // address
                fiatTokenV2.BURNER_ROLE() // role
            )
        );
        vm.prank(unauthorized);
        fiatTokenV2.burnBurner(100);
    }

    function testBurnFrom() public {
        assertEq(fiatTokenV2.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV2.mint(unauthorized, 100);
        assertEq(fiatTokenV2.totalSupply(), 100);
        assertEq(fiatTokenV2.balanceOf(unauthorized), 100);
        vm.prank(unauthorized);
        // needs to be burner as only account with BURNER_ROLE allowed to burn
        fiatTokenV2.approve(burner, 100);
        assertEq(fiatTokenV2.allowance(unauthorized, burner), 100);
        vm.prank(burner);
        fiatTokenV2.burnFromBurner(unauthorized, 100);
        assertEq(fiatTokenV2.totalSupply(), 0);
        assertEq(fiatTokenV2.balanceOf(unauthorized), 0);
    }

    function testTransfer() public {
        assertEq(fiatTokenV2.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV2.mint(minter, 100);
        assertEq(fiatTokenV2.totalSupply(), 100);
        assertEq(fiatTokenV2.balanceOf(minter), 100);
        vm.prank(minter);
        fiatTokenV2.transfer(unauthorized, 100);
        assertEq(fiatTokenV2.balanceOf(minter), 0);
        assertEq(fiatTokenV2.balanceOf(unauthorized), 100);
    }

    function testTransferMustBeAtLeaseBalance() public {
        assertEq(fiatTokenV2.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV2.mint(minter, 100);
        assertEq(fiatTokenV2.totalSupply(), 100);
        assertEq(fiatTokenV2.balanceOf(minter), 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                minter, // from
                100, // fromBalance
                101 // value
            )
        );
        vm.prank(minter);
        fiatTokenV2.transfer(unauthorized, 101);
    }

    function testTransferCannotBeToZeroAddress() public {
        assertEq(fiatTokenV2.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV2.mint(minter, 100);
        assertEq(fiatTokenV2.totalSupply(), 100);
        assertEq(fiatTokenV2.balanceOf(minter), 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InvalidReceiver.selector,
                address(0) // to
            )
        );
        vm.prank(minter);
        fiatTokenV2.transfer(address(0), 100);
    }

    function testTransferFrom() public {
        assertEq(fiatTokenV2.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV2.mint(minter, 100);
        assertEq(fiatTokenV2.totalSupply(), 100);
        assertEq(fiatTokenV2.balanceOf(minter), 100);
        vm.prank(minter);
        fiatTokenV2.approve(unauthorized, 100);
        vm.prank(unauthorized);
        fiatTokenV2.transferFrom(minter, unauthorized, 100);
        assertEq(fiatTokenV2.balanceOf(minter), 0);
        assertEq(fiatTokenV2.balanceOf(unauthorized), 100);
    }

    function testPause() public {
        assertEq(fiatTokenV2.paused(), false);
        vm.prank(pauser);
        fiatTokenV2.pause();
        assertEq(fiatTokenV2.paused(), true);
        // when contract is paused, not allowed to mint, burn, or transfer
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(minter);
        fiatTokenV2.mint(owner, 100);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(minter);
        fiatTokenV2.transfer(unauthorized, 100);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(burner);
        fiatTokenV2.burnBurner(100);
    }

    function testPauseUnauthorized() public {
        assertEq(fiatTokenV2.paused(), false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, fiatTokenV2.PAUSER_ROLE()
            )
        );
        vm.prank(unauthorized);
        fiatTokenV2.pause();
    }

    function testUnpause() public {
        assertEq(fiatTokenV2.paused(), false);
        vm.prank(pauser);
        fiatTokenV2.pause();
        assertEq(fiatTokenV2.paused(), true);
        vm.prank(pauser);
        fiatTokenV2.unpause();
        assertEq(fiatTokenV2.paused(), false);
    }

    function testUnpauseUnauthorized() public {
        assertEq(fiatTokenV2.paused(), false);
        vm.prank(pauser);
        fiatTokenV2.pause();
        assertEq(fiatTokenV2.paused(), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, fiatTokenV2.PAUSER_ROLE()
            )
        );
        vm.prank(unauthorized);
        fiatTokenV2.unpause();
    }

    function testPaused() public {
        assertEq(fiatTokenV2.paused(), false);
        vm.prank(pauser);
        fiatTokenV2.pause();
        assertEq(fiatTokenV2.paused(), true);
    }

    function testRescue() public {
        Ramen gld = new Ramen(100);
        gld.transfer(address(fiatTokenV2), 100);
        assertEq(gld.balanceOf(address(fiatTokenV2)), 100);
        vm.prank(rescuer);
        fiatTokenV2.rescue(gld, unauthorized, 100);
        assertEq(gld.balanceOf(address(fiatTokenV2)), 0);
    }

    function testBlacklistMinter() public {
        // mint tokens to minter account
        // for simplicity, we blacklist the minter account since it has permissions to transfer and mint
        vm.prank(minter);
        fiatTokenV2.mint(minter, 100);
        assertEq(fiatTokenV2.balanceOf(minter), 100);

        // blacklist minter account
        assertEq(fiatTokenV2.isBlacklisted(minter), false);
        vm.expectEmit();
        emit Blacklisted(minter);
        vm.prank(blacklister);
        fiatTokenV2.blacklist(minter);
        assertEq(fiatTokenV2.isBlacklisted(minter), true);
        // once blacklisted, not allowed to transfer
        vm.expectRevert(abi.encodeWithSelector(CallerBlacklisted.selector, minter));
        vm.prank(minter);
        fiatTokenV2.transfer(minter, 100);
        // not allowed to mint
        vm.expectRevert(abi.encodeWithSelector(CallerBlacklisted.selector, minter));
        vm.prank(minter);
        fiatTokenV2.mint(minter, 100);
    }

    function testBlacklistBurner() public {
        // mint tokens to burner account
        // for simplicity, we blacklist the burner account since it has permissions to burn
        vm.prank(minter);
        fiatTokenV2.mint(burner, 100);
        assertEq(fiatTokenV2.balanceOf(burner), 100);

        // blacklist minter account
        assertEq(fiatTokenV2.isBlacklisted(burner), false);
        vm.expectEmit();
        emit Blacklisted(burner);
        vm.prank(blacklister);
        fiatTokenV2.blacklist(burner);
        assertEq(fiatTokenV2.isBlacklisted(burner), true);
        // once blacklisted, not allowed to transfer
        vm.expectRevert(abi.encodeWithSelector(CallerBlacklisted.selector, burner));
        vm.prank(burner);
        fiatTokenV2.transfer(burner, 100);
        // not allowed to burn
        vm.expectRevert(abi.encodeWithSelector(CallerBlacklisted.selector, burner));
        vm.prank(burner);
        fiatTokenV2.burnBurner(100);
    }

    function testUnblacklistMinter() public {
        // blacklist minter account
        assertEq(fiatTokenV2.isBlacklisted(minter), false);
        vm.expectEmit();
        emit Blacklisted(minter);
        vm.prank(blacklister);
        fiatTokenV2.blacklist(minter);
        assertEq(fiatTokenV2.isBlacklisted(minter), true);
        // unblacklist minter account
        vm.expectEmit();
        emit UnBlacklisted(minter);
        vm.prank(blacklister);
        fiatTokenV2.unBlacklist(minter);
        assertEq(fiatTokenV2.isBlacklisted(minter), false);
        // once unblacklisted, allowed to mint
        vm.prank(minter);
        fiatTokenV2.mint(minter, 100);
        // allowed to transfer
        vm.prank(minter);
        fiatTokenV2.transfer(unauthorized, 100);
        // no balance left after transferring and burning
        assertEq(fiatTokenV2.balanceOf(minter), 0);
    }

    function testUnblacklistBurner() public {
        // mint 100 for to burner first
        vm.prank(minter);
        fiatTokenV2.mint(burner, 100);
        // blacklist burner account
        assertEq(fiatTokenV2.isBlacklisted(burner), false);
        vm.expectEmit();
        emit Blacklisted(burner);
        vm.prank(blacklister);
        fiatTokenV2.blacklist(burner);
        assertEq(fiatTokenV2.isBlacklisted(burner), true);
        // unblacklist burner account
        vm.expectEmit();
        emit UnBlacklisted(burner);
        vm.prank(blacklister);
        fiatTokenV2.unBlacklist(burner);
        assertEq(fiatTokenV2.isBlacklisted(burner), false);
        // once unblacklisted, allowed to burn
        vm.prank(burner);
        fiatTokenV2.burnBurner(100);
        // no balance left after transferring and burning
        assertEq(fiatTokenV2.balanceOf(burner), 0);
    }

    function testBlacklistUnauthorized() public {
        assertEq(fiatTokenV2.isBlacklisted(minter), false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, fiatTokenV2.BLACKLISTER_ROLE()
            )
        );
        vm.prank(unauthorized);
        fiatTokenV2.blacklist(minter);
    }

    function testUnblacklistUnauthorized() public {
        assertEq(fiatTokenV2.isBlacklisted(minter), false);
        vm.prank(blacklister);
        fiatTokenV2.blacklist(minter);
        assertEq(fiatTokenV2.isBlacklisted(minter), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, fiatTokenV2.BLACKLISTER_ROLE()
            )
        );
        vm.prank(unauthorized);
        fiatTokenV2.unBlacklist(minter);
    }

    // Access control

    function testGrantRole() public {
        bytes32 upgraderRole = fiatTokenV2.UPGRADER_ROLE();
        assertEq(fiatTokenV2.hasRole(upgraderRole, unauthorized), false);
        vm.prank(defaultAdmin);
        fiatTokenV2.grantRole(upgraderRole, unauthorized);
        assertEq(fiatTokenV2.hasRole(upgraderRole, unauthorized), true);
    }

    function testGrantBurnerRole() public {
        bytes32 burnerRole = fiatTokenV2.BURNER_ROLE();
        assertEq(fiatTokenV2.hasRole(burnerRole, unauthorized), false);
        vm.prank(defaultAdmin);
        fiatTokenV2.grantRole(burnerRole, unauthorized);
        assertEq(fiatTokenV2.hasRole(burnerRole, unauthorized), true);
    }

    function testGrantRoleUnauthorized() public {
        bytes32 upgraderRole = fiatTokenV2.UPGRADER_ROLE();
        assertEq(fiatTokenV2.hasRole(upgraderRole, unauthorized), false);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, fiatTokenV2.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        fiatTokenV2.grantRole(upgraderRole, unauthorized);
        assertEq(fiatTokenV2.hasRole(upgraderRole, unauthorized), false);
    }

    function testHasRole() public {
        bytes32 upgraderRole = fiatTokenV2.UPGRADER_ROLE();
        assertEq(fiatTokenV2.hasRole(upgraderRole, unauthorized), false);
        assertEq(fiatTokenV2.hasRole(upgraderRole, upgrader), true);
    }

    function testGetRoleAdmin() public {
        assertEq(fiatTokenV2.getRoleAdmin(fiatTokenV2.UPGRADER_ROLE()), fiatTokenV2.DEFAULT_ADMIN_ROLE());
    }

    function testRevokeRole() public {
        bytes32 upgraderRole = fiatTokenV2.UPGRADER_ROLE();
        assertEq(fiatTokenV2.hasRole(upgraderRole, upgrader), true);
        vm.prank(defaultAdmin);
        fiatTokenV2.revokeRole(upgraderRole, upgrader);
        assertEq(fiatTokenV2.hasRole(upgraderRole, upgrader), false);
    }

    function testRevokeRoleUnauthorized() public {
        bytes32 upgraderRole = fiatTokenV2.UPGRADER_ROLE();
        assertEq(fiatTokenV2.hasRole(upgraderRole, upgrader), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, fiatTokenV2.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        fiatTokenV2.revokeRole(upgraderRole, unauthorized);
    }

    function testRenounceRole() public {
        bytes32 upgraderRole = fiatTokenV2.UPGRADER_ROLE();
        assertEq(fiatTokenV2.hasRole(upgraderRole, upgrader), true);
        vm.prank(upgrader); // caller needs to be the one renouncing their own role
        fiatTokenV2.renounceRole(upgraderRole, upgrader);
        assertEq(fiatTokenV2.hasRole(upgraderRole, upgrader), false);
    }

    // Upgradeability

    function testUpgradeToAndCall() public {
        // new implementation contract
        FiatTokenV99 fiatTokenV99 = new FiatTokenV99();
        address newImplementationAddress = address(fiatTokenV99);
        assertEq(fiatTokenV99.version(), "99");
        assertEq(fiatTokenV2.version(), "2");
        // upgrade contract
        vm.prank(upgrader);
        fiatTokenV2.upgradeToAndCall(newImplementationAddress, "");
        address updatedImplementationAddress = Upgrades.getImplementationAddress(address(proxy));
        // verify implementation address is updated
        assertEq(newImplementationAddress, updatedImplementationAddress);
        // verify version() function implementation is updated
        assertEq(fiatTokenV2.version(), "99");
    }

    // Trusted addresses

    function testAddTrustedAddress() public {
        assertEq(fiatTokenV2.isTrustedAddress(unauthorized), false);
        vm.prank(defaultAdmin);
        fiatTokenV2.addTrustedAddress(unauthorized);
        assertEq(fiatTokenV2.isTrustedAddress(unauthorized), true);
    }

    function testRemoveTrustedAddress() public {
        assertEq(fiatTokenV2.isTrustedAddress(trustedAddress), true);
        vm.prank(defaultAdmin);
        fiatTokenV2.removeTrustedAddress(trustedAddress);
        assertEq(fiatTokenV2.isTrustedAddress(trustedAddress), false);
    }

    function testIsTrustedAddress() public {
        assertEq(fiatTokenV2.isTrustedAddress(trustedAddress), true);
        assertEq(fiatTokenV2.isTrustedAddress(unauthorized), false);
    }
}

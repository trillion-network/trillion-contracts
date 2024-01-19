// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

import {Test, console2} from "forge-std/Test.sol";
import {FiatTokenV1} from "../../src/v1/FiatTokenV1.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CallerBlacklisted} from "../../src/v1/BlacklistableV1.sol";
import {Ramen} from "../mocks/Ramen.sol";
import {FiatTokenV99} from "../mocks/FiatTokenV99.sol";

contract FiatTokenV1Test is Test {
    FiatTokenV1 public fiatTokenV1;
    ERC1967Proxy public proxy;
    address public owner;
    address public defaultAdmin;
    address public pauser;
    address public minter;
    address public upgrader;
    address public rescuer;
    address public blacklister;
    address public unauthorized;
    string public tokenName = "FiatTokenV1";
    string public tokenSymbol = "FIAT";

    function setUp() public {
        owner = address(this);
        defaultAdmin = vm.addr(1);
        pauser = vm.addr(2);
        minter = vm.addr(3);
        upgrader = vm.addr(4);
        rescuer = vm.addr(5);
        blacklister = vm.addr(6);
        unauthorized = vm.addr(7);

        // Deploy the token implementation
        fiatTokenV1 = new FiatTokenV1();
        // Deploy the proxy and initialize the contract through the proxy
        proxy = new ERC1967Proxy(
            address(fiatTokenV1),
            abi.encodeCall(
                fiatTokenV1.initialize,
                (defaultAdmin, pauser, minter, upgrader, rescuer, blacklister, tokenName, tokenSymbol)
            )
        );
        // Attach the FiatTokenV1 interface to the deployed proxy
        fiatTokenV1 = FiatTokenV1(address(proxy));
    }

    // Initialization grants roles

    function testInitializedRoles() public {
        assertEq(fiatTokenV1.hasRole(fiatTokenV1.DEFAULT_ADMIN_ROLE(), defaultAdmin), true);
        assertEq(fiatTokenV1.hasRole(fiatTokenV1.PAUSER_ROLE(), pauser), true);
        assertEq(fiatTokenV1.hasRole(fiatTokenV1.MINTER_ROLE(), minter), true);
        assertEq(fiatTokenV1.hasRole(fiatTokenV1.UPGRADER_ROLE(), upgrader), true);
        assertEq(fiatTokenV1.hasRole(fiatTokenV1.RESCUER_ROLE(), rescuer), true);
        assertEq(fiatTokenV1.hasRole(fiatTokenV1.BLACKLISTER_ROLE(), blacklister), true);
    }

    // ERC 20 behavior

    function testVersion() public {
        assertEq(fiatTokenV1.version(), "v1");
    }

    function testName() public {
        assertEq(fiatTokenV1.name(), tokenName);
    }

    function testSymbol() public {
        assertEq(fiatTokenV1.symbol(), tokenSymbol);
    }

    function testDecimals() public {
        assertEq(fiatTokenV1.decimals(), 18);
    }

    function testBalanceOf() public {
        assertEq(fiatTokenV1.balanceOf(owner), 0);
        vm.prank(minter);
        fiatTokenV1.mint(owner, 100);
        assertEq(fiatTokenV1.balanceOf(owner), 100);
    }

    function testTotalSupply() public {
        assertEq(fiatTokenV1.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV1.mint(owner, 100);
        assertEq(fiatTokenV1.totalSupply(), 100);
    }

    function testApprove() public {
        assertEq(fiatTokenV1.allowance(owner, unauthorized), 0);
        vm.prank(owner);
        fiatTokenV1.approve(unauthorized, 100);
        assertEq(fiatTokenV1.allowance(owner, unauthorized), 100);
    }

    function testMint() public {
        assertEq(fiatTokenV1.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV1.mint(owner, 100);
        assertEq(fiatTokenV1.totalSupply(), 100);
        assertEq(fiatTokenV1.balanceOf(owner), 100);
    }

    function testMintUnauthorized() public {
        assertEq(fiatTokenV1.totalSupply(), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, fiatTokenV1.MINTER_ROLE()
            )
        );
        vm.prank(unauthorized);
        fiatTokenV1.mint(owner, 100);
    }

    function testBurn() public {
        assertEq(fiatTokenV1.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV1.mint(minter, 100);
        assertEq(fiatTokenV1.totalSupply(), 100);
        assertEq(fiatTokenV1.balanceOf(minter), 100);
        vm.prank(minter);
        fiatTokenV1.burn(100);
        assertEq(fiatTokenV1.totalSupply(), 0);
        assertEq(fiatTokenV1.balanceOf(minter), 0);
    }

    function testBurnMustBeLessThanBalance() public {
        assertEq(fiatTokenV1.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV1.mint(minter, 100);
        assertEq(fiatTokenV1.totalSupply(), 100);
        assertEq(fiatTokenV1.balanceOf(minter), 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                minter, // from
                100, // fromBalance
                101 // value
            )
        );
        vm.prank(minter);
        fiatTokenV1.burn(101);
    }

    function testBurnUnauthorized() public {
        assertEq(fiatTokenV1.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV1.mint(owner, 100);
        assertEq(fiatTokenV1.totalSupply(), 100);
        assertEq(fiatTokenV1.balanceOf(owner), 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized, // address
                fiatTokenV1.MINTER_ROLE() // role
            )
        );
        vm.prank(unauthorized);
        fiatTokenV1.burn(100);
    }

    function testBurnFrom() public {
        assertEq(fiatTokenV1.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV1.mint(unauthorized, 100);
        assertEq(fiatTokenV1.totalSupply(), 100);
        assertEq(fiatTokenV1.balanceOf(unauthorized), 100);
        vm.prank(unauthorized);
        // needs to be minter as only account with MINTER_ROLE allowed to burn
        fiatTokenV1.approve(minter, 100);
        assertEq(fiatTokenV1.allowance(unauthorized, minter), 100);
        vm.prank(minter);
        fiatTokenV1.burnFrom(unauthorized, 100);
        assertEq(fiatTokenV1.totalSupply(), 0);
        assertEq(fiatTokenV1.balanceOf(unauthorized), 0);
    }

    function testTransfer() public {
        assertEq(fiatTokenV1.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV1.mint(minter, 100);
        assertEq(fiatTokenV1.totalSupply(), 100);
        assertEq(fiatTokenV1.balanceOf(minter), 100);
        vm.prank(minter);
        fiatTokenV1.transfer(unauthorized, 100);
        assertEq(fiatTokenV1.balanceOf(minter), 0);
        assertEq(fiatTokenV1.balanceOf(unauthorized), 100);
    }

    function testTransferMustBeAtLeaseBalance() public {
        assertEq(fiatTokenV1.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV1.mint(minter, 100);
        assertEq(fiatTokenV1.totalSupply(), 100);
        assertEq(fiatTokenV1.balanceOf(minter), 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                minter, // from
                100, // fromBalance
                101 // value
            )
        );
        vm.prank(minter);
        fiatTokenV1.transfer(unauthorized, 101);
    }

    function testTransferCannotBeToZeroAddress() public {
        assertEq(fiatTokenV1.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV1.mint(minter, 100);
        assertEq(fiatTokenV1.totalSupply(), 100);
        assertEq(fiatTokenV1.balanceOf(minter), 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InvalidReceiver.selector,
                address(0) // to
            )
        );
        vm.prank(minter);
        fiatTokenV1.transfer(address(0), 100);
    }

    function testTransferFrom() public {
        assertEq(fiatTokenV1.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV1.mint(minter, 100);
        assertEq(fiatTokenV1.totalSupply(), 100);
        assertEq(fiatTokenV1.balanceOf(minter), 100);
        vm.prank(minter);
        fiatTokenV1.approve(unauthorized, 100);
        vm.prank(unauthorized);
        fiatTokenV1.transferFrom(minter, unauthorized, 100);
        assertEq(fiatTokenV1.balanceOf(minter), 0);
        assertEq(fiatTokenV1.balanceOf(unauthorized), 100);
    }

    function testPause() public {
        assertEq(fiatTokenV1.paused(), false);
        vm.prank(pauser);
        fiatTokenV1.pause();
        assertEq(fiatTokenV1.paused(), true);
        // when contract is paused, not allowed to mint, burn, or transfer
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(minter);
        fiatTokenV1.mint(owner, 100);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(minter);
        fiatTokenV1.transfer(unauthorized, 100);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(minter);
        fiatTokenV1.burn(100);
    }

    function testPauseUnauthorized() public {
        assertEq(fiatTokenV1.paused(), false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, fiatTokenV1.PAUSER_ROLE()
            )
        );
        vm.prank(unauthorized);
        fiatTokenV1.pause();
    }

    function testUnpause() public {
        assertEq(fiatTokenV1.paused(), false);
        vm.prank(pauser);
        fiatTokenV1.pause();
        assertEq(fiatTokenV1.paused(), true);
        vm.prank(pauser);
        fiatTokenV1.unpause();
        assertEq(fiatTokenV1.paused(), false);
    }

    function testUnpauseUnauthorized() public {
        assertEq(fiatTokenV1.paused(), false);
        vm.prank(pauser);
        fiatTokenV1.pause();
        assertEq(fiatTokenV1.paused(), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, fiatTokenV1.PAUSER_ROLE()
            )
        );
        vm.prank(unauthorized);
        fiatTokenV1.unpause();
    }

    function testPaused() public {
        assertEq(fiatTokenV1.paused(), false);
        vm.prank(pauser);
        fiatTokenV1.pause();
        assertEq(fiatTokenV1.paused(), true);
    }

    function testRescue() public {
        Ramen gld = new Ramen(100);
        gld.transfer(address(fiatTokenV1), 100);
        assertEq(gld.balanceOf(address(fiatTokenV1)), 100);
        vm.prank(rescuer);
        fiatTokenV1.rescue(gld, unauthorized, 100);
        assertEq(gld.balanceOf(address(fiatTokenV1)), 0);
    }

    function testBlacklist() public {
        // mint tokens to minter account
        // for simplicity, we blacklist the minter account since it has permissions to transfer, mint and burn
        vm.prank(minter);
        fiatTokenV1.mint(minter, 100);
        assertEq(fiatTokenV1.balanceOf(minter), 100);

        // blacklist minter account
        assertEq(fiatTokenV1.isBlacklisted(minter), false);
        vm.prank(blacklister);
        fiatTokenV1.blacklist(minter);
        assertEq(fiatTokenV1.isBlacklisted(minter), true);
        // once blacklisted, not allowed to transfer
        vm.expectRevert(abi.encodeWithSelector(CallerBlacklisted.selector, minter));
        vm.prank(minter);
        fiatTokenV1.transfer(minter, 100);
        // not allowed to burn
        vm.expectRevert(abi.encodeWithSelector(CallerBlacklisted.selector, minter));
        vm.prank(minter);
        fiatTokenV1.burn(100);
        // not allowed to mint
        vm.expectRevert(abi.encodeWithSelector(CallerBlacklisted.selector, minter));
        vm.prank(minter);
        fiatTokenV1.mint(minter, 100);
    }

    function testUnblacklist() public {
        // blacklist minter account
        assertEq(fiatTokenV1.isBlacklisted(minter), false);
        vm.prank(blacklister);
        fiatTokenV1.blacklist(minter);
        assertEq(fiatTokenV1.isBlacklisted(minter), true);
        // unblacklist minter account
        vm.prank(blacklister);
        fiatTokenV1.unBlacklist(minter);
        assertEq(fiatTokenV1.isBlacklisted(minter), false);
        // once unblacklisted, allowed to mint
        vm.prank(minter);
        fiatTokenV1.mint(minter, 100);
        // allowed to transfer
        vm.prank(minter);
        fiatTokenV1.transfer(unauthorized, 50);
        // allowed to burn
        vm.prank(minter);
        fiatTokenV1.burn(50);
        // no balance left after transferring and burning
        assertEq(fiatTokenV1.balanceOf(minter), 0);
    }

    function testBlacklistUnauthorized() public {
        assertEq(fiatTokenV1.isBlacklisted(minter), false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, fiatTokenV1.BLACKLISTER_ROLE()
            )
        );
        vm.prank(unauthorized);
        fiatTokenV1.blacklist(minter);
    }

    function testUnblacklistUnauthorized() public {
        assertEq(fiatTokenV1.isBlacklisted(minter), false);
        vm.prank(blacklister);
        fiatTokenV1.blacklist(minter);
        assertEq(fiatTokenV1.isBlacklisted(minter), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, fiatTokenV1.BLACKLISTER_ROLE()
            )
        );
        vm.prank(unauthorized);
        fiatTokenV1.unBlacklist(minter);
    }

    // Access control

    function testGrantRole() public {
        bytes32 upgraderRole = fiatTokenV1.UPGRADER_ROLE();
        assertEq(fiatTokenV1.hasRole(upgraderRole, unauthorized), false);
        vm.prank(defaultAdmin);
        fiatTokenV1.grantRole(upgraderRole, unauthorized);
        assertEq(fiatTokenV1.hasRole(upgraderRole, unauthorized), true);
    }

    function testGrantRoleUnauthorized() public {
        bytes32 upgraderRole = fiatTokenV1.UPGRADER_ROLE();
        assertEq(fiatTokenV1.hasRole(upgraderRole, unauthorized), false);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, fiatTokenV1.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        fiatTokenV1.grantRole(upgraderRole, unauthorized);
        assertEq(fiatTokenV1.hasRole(upgraderRole, unauthorized), false);
    }

    function testHasRole() public {
        bytes32 upgraderRole = fiatTokenV1.UPGRADER_ROLE();
        assertEq(fiatTokenV1.hasRole(upgraderRole, unauthorized), false);
        assertEq(fiatTokenV1.hasRole(upgraderRole, upgrader), true);
    }

    function testGetRoleAdmin() public {
        assertEq(fiatTokenV1.getRoleAdmin(fiatTokenV1.UPGRADER_ROLE()), fiatTokenV1.DEFAULT_ADMIN_ROLE());
    }

    function testRevokeRole() public {
        bytes32 upgraderRole = fiatTokenV1.UPGRADER_ROLE();
        assertEq(fiatTokenV1.hasRole(upgraderRole, upgrader), true);
        vm.prank(defaultAdmin);
        fiatTokenV1.revokeRole(upgraderRole, upgrader);
        assertEq(fiatTokenV1.hasRole(upgraderRole, upgrader), false);
    }

    function testRevokeRoleUnauthorized() public {
        bytes32 upgraderRole = fiatTokenV1.UPGRADER_ROLE();
        assertEq(fiatTokenV1.hasRole(upgraderRole, upgrader), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, fiatTokenV1.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        fiatTokenV1.revokeRole(upgraderRole, unauthorized);
    }

    function testRenounceRole() public {
        bytes32 upgraderRole = fiatTokenV1.UPGRADER_ROLE();
        assertEq(fiatTokenV1.hasRole(upgraderRole, upgrader), true);
        vm.prank(upgrader); // caller needs to be the one renouncing their own role
        fiatTokenV1.renounceRole(upgraderRole, upgrader);
        assertEq(fiatTokenV1.hasRole(upgraderRole, upgrader), false);
    }

    // Upgradeability

    function testUpgradeToAndCall() public {
        // new implementation contract
        FiatTokenV99 fiatTokenV99 = new FiatTokenV99();
        address newImplementationAddress = address(fiatTokenV99);
        assertEq(fiatTokenV1.version(), "v1");
        // upgrade contract
        vm.prank(upgrader);
        fiatTokenV1.upgradeToAndCall(newImplementationAddress, "");
        address updatedImplementationAddress = Upgrades.getImplementationAddress(address(proxy));
        // verify implementation address is updated
        assertEq(newImplementationAddress, updatedImplementationAddress);
        // verify version() function implementation is updated
        assertEq(fiatTokenV1.version(), "v99");
    }
}

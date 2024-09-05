// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

import {Test, console2} from "forge-std/Test.sol";
import {FiatTokenV1} from "../../src/v1/FiatTokenV1.sol";
import {FiatTokenV2} from "../../src/v2/FiatTokenV2.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CallerBlacklisted} from "../../src/v1/BlacklistableV1.sol";

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

        // Assign BURNER_ROLE to burner
        bytes32 burnerRole = fiatTokenV2.BURNER_ROLE();
        vm.prank(defaultAdmin);
        fiatTokenV2.grantRole(burnerRole, burner);
    }

    // ERC 20 behavior

    function testVersion() public {
        assertEq(fiatTokenV2.version(), "2");
    }

    function testBurnByBurner() public {
        assertEq(fiatTokenV2.totalSupply(), 0);
        vm.prank(minter);
        fiatTokenV2.mint(burner, 100);
        assertEq(fiatTokenV2.totalSupply(), 100);
        assertEq(fiatTokenV2.balanceOf(burner), 100);
        vm.prank(burner);
        fiatTokenV2.burnByBurner(100);
        assertEq(fiatTokenV2.totalSupply(), 0);
        assertEq(fiatTokenV2.balanceOf(burner), 0);
    }

    function testBurnByBurnerMustBeLessThanBalance() public {
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
        fiatTokenV2.burnByBurner(101);
    }

    function testBurnByBurnerUnauthorized() public {
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
        fiatTokenV2.burnByBurner(100);
    }

    function testBurnerPause() public {
        assertEq(fiatTokenV2.paused(), false);
        vm.prank(pauser);
        fiatTokenV2.pause();
        assertEq(fiatTokenV2.paused(), true);
        // when contract is paused, not allowed to burn
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(burner);
        fiatTokenV2.burnByBurner(100);
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
        fiatTokenV2.burnByBurner(100);
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
        fiatTokenV2.burnByBurner(100);
        // no balance left after transferring and burning
        assertEq(fiatTokenV2.balanceOf(burner), 0);
    }

    // Access control

    function testGrantBurnerRole() public {
        bytes32 burnerRole = fiatTokenV2.BURNER_ROLE();
        assertEq(fiatTokenV2.hasRole(burnerRole, unauthorized), false);
        vm.prank(defaultAdmin);
        fiatTokenV2.grantRole(burnerRole, unauthorized);
        assertEq(fiatTokenV2.hasRole(burnerRole, unauthorized), true);
    }

    function testRevokeBurnerRole() public {
        bytes32 burnerRole = fiatTokenV2.BURNER_ROLE();
        vm.prank(defaultAdmin);
        fiatTokenV2.grantRole(burnerRole, unauthorized);
        assertEq(fiatTokenV2.hasRole(burnerRole, unauthorized), true);

        vm.prank(defaultAdmin);
        fiatTokenV2.revokeRole(burnerRole, unauthorized);
        assertEq(fiatTokenV2.hasRole(burnerRole, unauthorized), false);
    }

    function testRenounceBurnerRole() public {
        bytes32 burnerRole = fiatTokenV2.BURNER_ROLE();
        vm.prank(defaultAdmin);
        fiatTokenV2.grantRole(burnerRole, unauthorized);
        assertEq(fiatTokenV2.hasRole(burnerRole, unauthorized), true);

        vm.prank(unauthorized); // caller needs to be the one renouncing their own role
        fiatTokenV2.renounceRole(burnerRole, unauthorized);
        assertEq(fiatTokenV2.hasRole(burnerRole, unauthorized), false);
    }

    // Upgradeability

    function testUpgradeToAndCall() public {
        // new implementation contract
        FiatTokenV1 fiatTokenV1 = new FiatTokenV1();
        vm.prank(trustedAddress);
        ERC1967Proxy proxyV1 = new ERC1967Proxy(
            address(fiatTokenV1),
            abi.encodeCall(
                fiatTokenV1.initialize,
                (defaultAdmin, pauser, minter, upgrader, rescuer, blacklister, tokenName, tokenSymbol)
            )
        );

        // Attach the FiatTokenV1 interface to the deployed proxy
        fiatTokenV1 = FiatTokenV1(address(proxyV1));

        FiatTokenV2 fiatTokenV2New = new FiatTokenV2();
        address newImplementationAddress = address(fiatTokenV2New);
        assertEq(fiatTokenV1.version(), "1");
        assertEq(fiatTokenV2New.version(), "2");

        // upgrade contract
        vm.prank(upgrader);
        fiatTokenV1.upgradeToAndCall(newImplementationAddress, "");
        address updatedImplementationAddress = Upgrades.getImplementationAddress(address(proxyV1));
        // verify implementation address is updated
        assertEq(newImplementationAddress, updatedImplementationAddress);
        // verify version() function implementation is updated
        assertEq(fiatTokenV1.version(), "2");
    }
}

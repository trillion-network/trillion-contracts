// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {BlacklistableV1} from "../../src/v1/BlacklistableV1.sol";

contract Blacklistable is BlacklistableV1 {
    // solhint-disable-next-line foundry-test-functions
    function initialize() public initializer {
        __ERC20Blacklistable_init();
    }

    function blacklist(address account) external {
        super._blacklist(account);
    }

    function unBlacklist(address account) external {
        super._unBlacklist(account);
    }
}

contract BlacklistableV1Test is Test {
    Blacklistable public blacklistable;

    function setUp() external {
        blacklistable = new Blacklistable();
    }

    function testBlacklist() external {
        address account = address(0x123);
        blacklistable.blacklist(account);
        assertEq(blacklistable.isBlacklisted(account), true);
    }

    function testUnBlacklist() external {
        address account = address(0x123);
        blacklistable.blacklist(account);
        blacklistable.unBlacklist(account);
        assertEq(!blacklistable.isBlacklisted(account), true);
    }
}

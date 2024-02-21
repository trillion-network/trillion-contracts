// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ramen} from "../../src/mocks/Ramen.sol";
import {RescuableV1} from "../../src/v1/RescuableV1.sol";

contract Rescuable is RescuableV1 {
    // solhint-disable-next-line foundry-test-functions
    function initialize() public initializer {
        __ERC20Rescuable_init();
    }
}

contract RescuableV1Test is Test {
    Rescuable public rescuable;
    Ramen public ramen;
    address public rescueDestination = address(0x123);

    function setUp() external {
        rescuable = new Rescuable();
        ramen = new Ramen(100);
        ramen.transfer(address(rescuable), 100);
    }

    function testRescue() external {
        IERC20 token = IERC20(address(ramen));
        assertEq(token.balanceOf(address(rescuable)), 100);
        rescuable.rescue(token, rescueDestination, 100);
        assertEq(token.balanceOf(address(rescuable)), 0);
        assertEq(token.balanceOf(rescueDestination), 100);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FiatTokenV1} from "../../src/v1/FiatTokenV1.sol";

// mock contract used for testing upgrade
contract FiatTokenV99 is FiatTokenV1 {
    function version() public pure override(FiatTokenV1) returns (string memory) {
        return "v99";
    }
}

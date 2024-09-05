// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../v1/FiatTokenV1.sol";

/// @custom:security-contact snggeng@gmail.com
contract FiatTokenV2 is FiatTokenV1 {
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    function burnByBurner(uint256 value) public onlyRole(BURNER_ROLE) {
        _burn(_msgSender(), value);
    }

    function version() public pure virtual override(FiatTokenV1) returns (string memory) {
        return "2";
    }
}

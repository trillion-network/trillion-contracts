// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../v1/FiatTokenV1.sol";

/// @custom:security-contact snggeng@gmail.com
contract FiatTokenV2 is FiatTokenV1 {
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    function burn(uint256 value) public override(FiatTokenV1) onlyRole(BURNER_ROLE) {
        super.burn(value);
    }

    function burnFrom(address account, uint256 value) public override(FiatTokenV1) onlyRole(BURNER_ROLE) {
        super.burnFrom(account, value);
    }

    function version() public pure virtual override(FiatTokenV1) returns (string memory) {
        return "2";
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../v1/FiatTokenV1.sol";

/// @custom:security-contact snggeng@gmail.com
contract FiatTokenV2 is FiatTokenV1 {
    uint8 internal _initializedVersion;
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    function initializeV2(address burner) external {
        // solhint-disable-next-line reason-string
        require(_initializedVersion == 0);

        _grantRole(BURNER_ROLE, burner);

        _initializedVersion = 1;
    }

    function burnBurner(uint256 value) public onlyRole(BURNER_ROLE) {
        _burn(_msgSender(), value);
    }

    function burnFromBurner(address account, uint256 value) public onlyRole(BURNER_ROLE) {
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }

    function version() public pure virtual override(FiatTokenV1) returns (string memory) {
        return "2";
    }
}

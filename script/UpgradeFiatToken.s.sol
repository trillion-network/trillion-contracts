// SPDX-License-Identifier: MIT
// solhint-disable no-console
pragma solidity ^0.8.20;

import "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {FiatTokenV1} from "../src/v1/FiatTokenV1.sol";

contract DeployFiatToken is Script {
    function run() public {
        // needs to be the private key of the account with the upgrader role
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address fiatTokenProxyAddress = vm.envAddress("FIAT_TOKEN_PROXY_ADDRESS");
        // set current implementation reference
        Options memory opts;
        opts.referenceContract = "FiatTokenV1.sol";
        // upgrade contract
        Upgrades.upgradeProxy(fiatTokenProxyAddress, "FiatTokenV2.sol", "", opts);
        console2.log("FiatTokenV1 upgraded to version 2");
        vm.stopBroadcast();
    }
}

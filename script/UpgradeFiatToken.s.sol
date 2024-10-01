// SPDX-License-Identifier: MIT
// solhint-disable no-console
pragma solidity ^0.8.20;

import "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {FiatTokenV2} from "../src/v2/FiatTokenV2.sol";

contract UpgradeFiatToken is Script {
    function run() public {
        vm.startBroadcast();
        address fiatTokenProxyAddress = vm.envAddress("FIAT_TOKEN_PROXY_ADDRESS");
        // set current implementation reference
        Options memory opts;
        opts.referenceContract = "FiatTokenV1.sol";
        // upgrade contract
        Upgrades.upgradeProxy(fiatTokenProxyAddress, "FiatTokenV2.sol", "", opts);
        console2.log("FiatToken upgrade successful");
        vm.stopBroadcast();
    }
}

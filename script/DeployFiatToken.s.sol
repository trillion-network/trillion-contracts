// SPDX-License-Identifier: MIT
// solhint-disable no-console
pragma solidity ^0.8.20;

import "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {FiatTokenV1} from "../src/v1/FiatTokenV1.sol";

contract DeployFiatToken is Script {
    function run() public {
        address defaultAdmin = vm.envAddress("DEFAULT_ADMIN_ADDRESS");
        address pauser = vm.envAddress("PAUSER_ADDRESS");
        address minter = vm.envAddress("MINTER_ADDRESS");
        address upgrader = vm.envAddress("UPGRADER_ADDRESS");
        address rescuer = vm.envAddress("RESCUER_ADDRESS");
        address blacklister = vm.envAddress("BLACKLISTER_ADDRESS");
        string memory tokenName = vm.envString("TOKEN_NAME");
        string memory tokenSymbol = vm.envString("TOKEN_SYMBOL");

        vm.startBroadcast();
        address uupsProxy = Upgrades.deployUUPSProxy(
            "FiatTokenV1.sol",
            abi.encodeCall(
                FiatTokenV1.initialize,
                (defaultAdmin, pauser, minter, upgrader, rescuer, blacklister, tokenName, tokenSymbol)
            )
        );
        console2.log("FiatTokenV1 deployed at address: %s", uupsProxy);
        vm.stopBroadcast();
    }
}

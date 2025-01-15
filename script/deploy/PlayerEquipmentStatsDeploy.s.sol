// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PlayerEquipmentStats} from "../../src/PlayerEquipmentStats.sol";

contract PlayerEquipmentStatsDeploy is Script {
    function run() public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(deployerPrivateKey);
        PlayerEquipmentStats equipmentStats = new PlayerEquipmentStats();
        vm.stopBroadcast();

        console2.log("\n=== Deployed Address ===");
        console2.log("PlayerEquipmentStats:", address(equipmentStats));
    }
}

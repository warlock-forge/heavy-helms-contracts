// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PlayerNameRegistry} from "../../src/PlayerNameRegistry.sol";
import {MonsterNameRegistry} from "../../src/MonsterNameRegistry.sol";
import {NameLibrary} from "../../src/lib/NameLibrary.sol";

contract NameRegistryDeploy is Script {
    function run() public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy and initialize PlayerNameRegistry
        PlayerNameRegistry nameRegistry = new PlayerNameRegistry();
        string[] memory setANames = NameLibrary.getInitialNameSetA();
        string[] memory setBNames = NameLibrary.getInitialNameSetB();
        string[] memory surnameList = NameLibrary.getInitialSurnames();

        nameRegistry.addNamesToSetA(setANames);
        nameRegistry.addNamesToSetB(setBNames);
        nameRegistry.addSurnames(surnameList);

        // Deploy and initialize MonsterNameRegistry
        MonsterNameRegistry monsterNameRegistry = new MonsterNameRegistry();
        string[] memory monsterNames = NameLibrary.getInitialMonsterNames();
        monsterNameRegistry.addMonsterNames(monsterNames);

        vm.stopBroadcast();

        console2.log("\n=== Deployed Addresses ===");
        console2.log("PlayerNameRegistry:", address(nameRegistry));
        console2.log("MonsterNameRegistry:", address(monsterNameRegistry));
    }
}

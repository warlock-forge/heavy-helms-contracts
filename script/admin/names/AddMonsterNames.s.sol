// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MonsterNameRegistry} from "../../../src/fighters/registries/names/MonsterNameRegistry.sol";
import {MonsterNameLibrary} from "../../../src/fighters/registries/names/lib/MonsterNameLibrary.sol";

contract AddMonsterNames is Script {
    function setUp() public {}

    function run(address monsterNameRegistryAddress) public {
        // Get values from .env
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast();

        MonsterNameRegistry monsterNameRegistry = MonsterNameRegistry(monsterNameRegistryAddress);

        // Add goblin names (indices 5-34)
        string[] memory goblinNames = MonsterNameLibrary.getGoblinNames();
        monsterNameRegistry.addMonsterNames(goblinNames);

        // Add undead names (indices 35-64)
        string[] memory undeadNames = MonsterNameLibrary.getUndeadNames();
        monsterNameRegistry.addMonsterNames(undeadNames);

        // Add demon names (indices 65-94)
        string[] memory demonNames = MonsterNameLibrary.getDemonNames();
        monsterNameRegistry.addMonsterNames(demonNames);

        vm.stopBroadcast();

        console2.log("\n=== Monster Names Added ===");
        console2.log("MonsterNameRegistry:", address(monsterNameRegistry));
        console2.log("Goblin names added: 30 (indices 5-34)");
        console2.log("Undead names added: 30 (indices 35-64)");
        console2.log("Demon names added: 30 (indices 65-94)");
        console2.log("Total new names: 90");
    }
}

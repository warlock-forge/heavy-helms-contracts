// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {PlayerNameRegistry} from "../../src/fighters/registries/names/PlayerNameRegistry.sol";
import {MonsterNameRegistry} from "../../src/fighters/registries/names/MonsterNameRegistry.sol";
import {NameLibrary} from "../../src/fighters/registries/names/lib/NameLibrary.sol";

contract NameRegistryDeploy is Script {
    function run() public {
        // Get values from .env
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast();

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

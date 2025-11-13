// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Monster} from "../../../src/fighters/Monster.sol";
import {MonsterSkinNFT} from "../../../src/nft/skins/MonsterSkinNFT.sol";
import {MonsterLibrary} from "../../../src/fighters/lib/MonsterLibrary.sol";

contract CreateMonster is Script {
    function setUp() public {}

    function run(address monsterAddr, uint256 monsterType, uint256 monsterVersion, uint16 skinTokenId, uint16 nameIndex)
        public
    {
        // Get values from .env
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast();

        Monster monster = Monster(monsterAddr);

        uint32 monsterId;

        if (monsterType == 0) {
            // Goblin
            if (monsterVersion == 1) {
                monsterId = MonsterLibrary.createGoblinMonster001(monster, skinTokenId, nameIndex);
                console2.log("Created Goblin Monster 001 with ID:", monsterId);
            } else {
                revert("Invalid goblin version");
            }
        } else if (monsterType == 1) {
            // Undead
            if (monsterVersion == 1) {
                monsterId = MonsterLibrary.createUndeadMonster001(monster, skinTokenId, nameIndex);
                console2.log("Created Undead Monster 001 with ID:", monsterId);
            } else {
                revert("Invalid undead version");
            }
        } else if (monsterType == 2) {
            // Demon
            if (monsterVersion == 1) {
                monsterId = MonsterLibrary.createDemonMonster001(monster, skinTokenId, nameIndex);
                console2.log("Created Demon Monster 001 with ID:", monsterId);
            } else {
                revert("Invalid demon version");
            }
        } else {
            revert("Invalid monster type");
        }

        console2.log("Monster ID:", monsterId);
        console2.log("Name Index:", nameIndex);
        console2.log("Skin Token ID:", skinTokenId);

        vm.stopBroadcast();
    }
}

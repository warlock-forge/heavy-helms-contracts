// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {MonsterBattleGame} from "../../src/game/modes/MonsterBattleGame.sol";
import {Player} from "../../src/fighters/Player.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";

contract MonsterBattleGameDeployScript is Script {
    function setUp() public {}

    function run(
        address gameEngineAddr,
        address payable playerAddr,
        address monsterAddr,
        address vrfCoordinator,
        uint256 subscriptionId,
        bytes32 keyHash,
        address playerTicketsAddr
    ) public {
        require(gameEngineAddr != address(0), "GameEngine address cannot be zero");
        require(playerAddr != address(0), "Player address cannot be zero");
        require(monsterAddr != address(0), "Monster address cannot be zero");
        require(vrfCoordinator != address(0), "VRF Coordinator address cannot be zero");
        require(playerTicketsAddr != address(0), "PlayerTickets address cannot be zero");

        vm.startBroadcast();

        // Deploy MonsterBattleGame
        MonsterBattleGame monsterBattleGame = new MonsterBattleGame(
            gameEngineAddr, playerAddr, monsterAddr, vrfCoordinator, subscriptionId, keyHash, playerTicketsAddr
        );

        // Whitelist MonsterBattleGame in Player contract
        // MonsterBattleGame can kill players, so retire: true
        Player playerContract = Player(playerAddr);
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: true, immortal: false, experience: true});
        playerContract.setGameContractPermission(address(monsterBattleGame), perms);

        // Whitelist MonsterBattleGame in PlayerTickets contract
        PlayerTickets playerTicketsContract = PlayerTickets(playerTicketsAddr);
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: true,
            playerSlots: true,
            nameChanges: true,
            weaponSpecialization: true,
            armorSpecialization: true,
            duels: true,
            dailyResets: true,
            attributeSwaps: true
        });
        playerTicketsContract.setGameContractPermission(address(monsterBattleGame), ticketPerms);

        console2.log("\n=== Deployed MonsterBattleGame ===");
        console2.log("MonsterBattleGame:", address(monsterBattleGame));
        console2.log("MonsterBattleGame whitelisted in Player contract (retire: true)");
        console2.log("MonsterBattleGame whitelisted in PlayerTickets contract");
        console2.log("\n=== Post-Deploy Reminders ===");
        console2.log("1. Add MonsterBattleGame as VRF consumer on Chainlink dashboard");
        console2.log("2. Call addMonsterAvailability() to enable monsters per difficulty tier");

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {TournamentGame} from "../../src/game/modes/TournamentGame.sol";
import {GameEngine} from "../../src/game/engine/GameEngine.sol";
import {Player} from "../../src/fighters/Player.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";

contract TournamentGameDeployScript is Script {
    function setUp() public {}

    function run(
        address gameEngineAddr,
        address payable playerAddr,
        address defaultPlayerAddr,
        address playerTicketsAddr
    ) public {
        require(gameEngineAddr != address(0), "GameEngine address cannot be zero");
        require(playerAddr != address(0), "Player address cannot be zero");
        require(defaultPlayerAddr != address(0), "DefaultPlayer address cannot be zero");
        require(playerTicketsAddr != address(0), "PlayerTickets address cannot be zero");

        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy TournamentGame
        TournamentGame tournamentGame =
            new TournamentGame(gameEngineAddr, playerAddr, defaultPlayerAddr, playerTicketsAddr);

        // Whitelist TournamentGame in Player contract with RETIRE permission for death mechanics
        Player playerContract = Player(playerAddr);
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: true, attributes: true, immortal: false, experience: false});
        playerContract.setGameContractPermission(address(tournamentGame), perms);

        // Whitelist TournamentGame in PlayerTickets contract for reward minting
        PlayerTickets playerTicketsContract = PlayerTickets(playerTicketsAddr);
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: true,
            playerSlots: true,
            nameChanges: true,
            weaponSpecialization: true,
            armorSpecialization: true,
            duels: true,
            dailyResets: true
        });
        playerTicketsContract.setGameContractPermission(address(tournamentGame), ticketPerms);

        console2.log("\n=== Deployed Addresses ===");
        console2.log("TournamentGame:", address(tournamentGame));
        console2.log("TournamentGame whitelisted in Player contract with RETIRE permission");
        console2.log("TournamentGame whitelisted in PlayerTickets contract for all rewards");
        console2.log("Initial tournament size:", tournamentGame.currentTournamentSize());
        console2.log("Initial lethality factor:", tournamentGame.lethalityFactor());

        vm.stopBroadcast();
    }
}

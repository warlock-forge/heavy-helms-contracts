// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {GauntletGame} from "../../../src/game/modes/GauntletGame.sol";
import {Fighter} from "../../../src/fighters/Fighter.sol";
import {IPlayer} from "../../../src/interfaces/fighters/IPlayer.sol";

contract AddPlayersGauntletScript is Script {
    function setUp() public {}

    function run(address gauntletGameAddr, uint32[] memory playerIds) public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        GauntletGame gauntletGame = GauntletGame(payable(gauntletGameAddr));
        IPlayer playerContract = IPlayer(gauntletGame.playerContract());

        console2.log("\n=== Queue Players ===");
        uint256 playersSize = playerIds.length;
        for (uint256 i = 0; i < playersSize; i++) {
            // Get player's current equipped skin
            IPlayer.PlayerStats memory playerStats = playerContract.getPlayer(playerIds[i]);

            // Create loadout for player using their current skin
            Fighter.PlayerLoadout memory loadout =
                Fighter.PlayerLoadout({playerId: playerIds[i], skin: playerStats.skin, stance: playerStats.stance});

            // Queue player for gauntlet
            gauntletGame.queueForGauntlet(loadout);
            console2.log("Player ID:", playerIds[i]);
        }

        vm.stopBroadcast();
    }
}

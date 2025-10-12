// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {GauntletGame} from "../../../src/game/modes/GauntletGame.sol";

contract RemovePlayersGauntletScript is Script {
    function setUp() public {}

    function run(address gauntletGameAddr, uint32[] memory playerIds) public {
        // Get values from .env
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast();

        GauntletGame gauntletGame = GauntletGame(payable(gauntletGameAddr));

        console2.log("\n=== Un-Queue Players ===");
        uint256 playersSize = playerIds.length;
        for (uint256 i = 0; i < playersSize; i++) {
            // Un-Queue player for gauntlet
            gauntletGame.withdrawFromQueue(playerIds[i]);
            console2.log("Player ID:", playerIds[i]);
        }

        vm.stopBroadcast();
    }
}

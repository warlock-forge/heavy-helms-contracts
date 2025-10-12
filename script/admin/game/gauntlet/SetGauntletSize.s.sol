// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {GauntletGame} from "../../../../src/game/modes/GauntletGame.sol";

contract SetGauntletSizeScript is Script {
    function setUp() public {}

    function run(address gauntletGameAddr, uint8 size) public {
        // Get values from .env
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast();

        GauntletGame gauntletGame = GauntletGame(gauntletGameAddr);

        // --- NEW LOGIC: Disable, Set, Enable ---
        console2.log("Disabling game...");
        gauntletGame.setGameEnabled(false);

        console2.log("Setting gauntlet size to:", size);
        gauntletGame.setGauntletSize(size);

        console2.log("Re-enabling game...");
        gauntletGame.setGameEnabled(true);
        // --- END NEW LOGIC ---

        console2.log("Gauntlet size set successfully.");

        vm.stopBroadcast();
    }
}

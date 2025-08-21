// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {GauntletGame} from "../../src/game/modes/GauntletGame.sol";
import {GameEngine} from "../../src/game/engine/GameEngine.sol";
import {Player} from "../../src/fighters/Player.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";

contract GauntletGameDeployScript is Script {
    function setUp() public {}

    function run(address gameEngineAddr, address playerAddr, address defaultPlayerAddr, address playerTicketsAddr)
        public
    {
        // Deploy all 3 bracket contracts
        deployGauntletBracket(
            gameEngineAddr, playerAddr, defaultPlayerAddr, playerTicketsAddr, GauntletGame.LevelBracket.LEVELS_1_TO_4
        );
        deployGauntletBracket(
            gameEngineAddr, playerAddr, defaultPlayerAddr, playerTicketsAddr, GauntletGame.LevelBracket.LEVELS_5_TO_9
        );
        deployGauntletBracket(
            gameEngineAddr, playerAddr, defaultPlayerAddr, playerTicketsAddr, GauntletGame.LevelBracket.LEVEL_10
        );
    }

    function deployGauntletBracket(
        address gameEngineAddr,
        address playerAddr,
        address defaultPlayerAddr,
        address playerTicketsAddr,
        GauntletGame.LevelBracket bracket
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

        // Deploy GauntletGame with specified bracket
        GauntletGame gauntletGame =
            new GauntletGame(gameEngineAddr, playerAddr, defaultPlayerAddr, bracket, playerTicketsAddr);

        // Whitelist GauntletGame in Player contract
        Player playerContract = Player(playerAddr);
        IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
            record: true,
            retire: false,
            attributes: false,
            immortal: false,
            experience: false
        });
        playerContract.setGameContractPermission(address(gauntletGame), perms);

        console2.log("\n=== Deployed Addresses ===");
        console2.log("GauntletGame:", address(gauntletGame));
        console2.log("Level Bracket:", uint8(bracket));
        console2.log("GauntletGame whitelisted in Player contract");

        vm.stopBroadcast();
    }
}

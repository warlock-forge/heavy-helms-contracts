// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Game} from "../src/Game.sol";
import {Player} from "../src/Player.sol";
import {GameStats} from "../src/GameStats.sol";
import {GameEngine} from "../src/GameEngine.sol";
import {PlayerSkinRegistry} from "../src/PlayerSkinRegistry.sol";

contract GameScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy contracts in correct order
        GameStats gameStats = new GameStats();
        PlayerSkinRegistry skinRegistry = new PlayerSkinRegistry(address(0));
        Player playerContract = new Player(address(skinRegistry), address(gameStats));
        GameEngine gameEngine = new GameEngine();

        Game game = new Game(address(gameEngine), address(playerContract), address(gameStats), address(skinRegistry));

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Game} from "../src/Game.sol";
import {GameEngine} from "../src/GameEngine.sol";

contract UpdateGameEngineScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PK");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy new GameEngine
        GameEngine newGameEngine = new GameEngine();
        console2.log("New GameEngine deployed at:", address(newGameEngine));

        // Address of your deployed Game contract
        address gameAddress = 0xfb6B0f32d557053D36D8dBC7cb5DfEBDC807E311; // Replace with your Game contract address
        Game game = Game(gameAddress);

        // Update Game contract to use new GameEngine
        game.setGameEngine(address(newGameEngine));
        console2.log("Game contract updated to use new GameEngine");

        vm.stopBroadcast();
    }
}

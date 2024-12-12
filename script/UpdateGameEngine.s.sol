// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Game} from "../src/Game.sol";
import {GameEngine} from "../src/GameEngine.sol";

contract UpdateGameEngineScript is Script {
    function setUp() public {}

    function run(address gameContractAddr) public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");
        
        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy new GameEngine
        GameEngine newGameEngine = new GameEngine();
        console2.log("New GameEngine deployed at:", address(newGameEngine));

        // Get the Game contract
        Game game = Game(gameContractAddr);
        
        // Update the GameEngine
        game.setGameEngine(address(newGameEngine));
        console2.log("Game contract updated with new engine");

        vm.stopBroadcast();
    }
}

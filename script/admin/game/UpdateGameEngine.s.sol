// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {BaseGame} from "../../../src/BaseGame.sol";

contract UpdateGameEngineScript is Script {
    function setUp() public {}

    function run(address newGameEngineAddr, address gameContractAddr) public {
        require(newGameEngineAddr != address(0), "GameEngine address cannot be zero");
        require(gameContractAddr != address(0), "Game contract address cannot be zero");

        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(deployerPrivateKey);

        // Cast the address to BaseGame since all game contracts inherit from it
        BaseGame game = BaseGame(gameContractAddr);

        // Update the GameEngine
        game.setGameEngine(newGameEngineAddr);
        console2.log("Game contract at", gameContractAddr, "updated to use GameEngine at:", newGameEngineAddr);

        vm.stopBroadcast();
    }
}

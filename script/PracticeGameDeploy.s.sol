// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {PracticeGame} from "../src/PracticeGame.sol";
import {GameEngine} from "../src/GameEngine.sol";
import {Player} from "../src/Player.sol";

contract PracticeGameDeployScript is Script {
    function setUp() public {}

    function run(address gameEngineAddr, address playerAddr) public {
        require(gameEngineAddr != address(0), "GameEngine address cannot be zero");
        require(playerAddr != address(0), "Player address cannot be zero");

        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy PracticeGame
        PracticeGame practiceGame = new PracticeGame(
            gameEngineAddr,
            playerAddr
        );

        console2.log("Deployed Addresses:");
        console2.log("PracticeGame:", address(practiceGame));

        vm.stopBroadcast();
    }
}

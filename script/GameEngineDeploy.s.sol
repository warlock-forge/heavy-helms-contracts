// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {GameEngine} from "../src/GameEngine.sol";

contract GameEngineDeployScript is Script {
    function setUp() public {}

    function run() public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy GameEngine
        GameEngine gameEngine = new GameEngine();

        console2.log("\n=== Deployed Addresses ===");
        console2.log("GameEngine:", address(gameEngine));

        vm.stopBroadcast();
    }
}

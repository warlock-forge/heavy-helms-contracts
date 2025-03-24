// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Player} from "../../../src/fighters/Player.sol";
import {IPlayerNameRegistry} from "../../../src/interfaces/fighters/registries/names/IPlayerNameRegistry.sol";
import {IPlayer} from "../../../src/interfaces/fighters/IPlayer.sol";

contract CreatePlayerScript is Script {
    function setUp() public {}

    function run(address playerContractAddr, bool isFemale) public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        // Get the deployed Player contract
        Player player = Player(playerContractAddr);

        // Request player creation with 0.001 ETH fee
        uint256 requestId = player.requestCreatePlayer{value: 0.001 ether}(isFemale);
        console2.log("Player creation requested with ID:", requestId);
        console2.log("Waiting for VRF fulfillment by Gelato operator...");
        vm.stopBroadcast();
    }
}

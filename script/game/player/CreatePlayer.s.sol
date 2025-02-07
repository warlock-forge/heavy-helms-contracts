// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Player} from "../../../src/Player.sol";
import {IPlayerNameRegistry} from "../../../src/interfaces/IPlayerNameRegistry.sol";
import {IPlayer} from "../../../src/interfaces/IPlayer.sol";

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

        // Note: At this point you need to wait for the VRF fulfillment
        // The Gelato operator will call fulfillRandomness() with the random number
        // After that, you can get your player ID using getPlayerIds()

        // Get the player ID (this will only work after VRF fulfillment)
        uint32[] memory playerIds = player.getPlayerIds(msg.sender);
        if (playerIds.length > 0) {
            uint32 playerId = playerIds[playerIds.length - 1];
            console2.log("Player created with ID:", playerId);

            // Get and display player stats
            IPlayer.PlayerStats memory stats = player.getPlayer(playerId);
            console2.log("\nPlayer Stats:");
            console2.log("Strength:", stats.strength);
            console2.log("Constitution:", stats.constitution);
            console2.log("Size:", stats.size);
            console2.log("Agility:", stats.agility);
            console2.log("Stamina:", stats.stamina);
            console2.log("Luck:", stats.luck);

            // Get and display player name
            (string memory firstName, string memory surname) =
                IPlayerNameRegistry(player.nameRegistry()).getFullName(stats.firstNameIndex, stats.surnameIndex);
            console2.log("\nPlayer Name:", firstName, surname);
        }

        vm.stopBroadcast();
    }
}

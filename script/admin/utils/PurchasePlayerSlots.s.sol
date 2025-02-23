// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Player} from "../../../src/fighters/Player.sol";

contract PurchasePlayerSlotsScript is Script {
    function setUp() public {}

    function run(address playerContractAddr) public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        // Get the deployed Player contract
        Player player = Player(playerContractAddr);

        // Calculate cost for next slot batch
        address owner = vm.addr(deployerPrivateKey);
        uint256 cost = player.getNextSlotBatchCost(owner);

        // Purchase 5 slots
        player.purchasePlayerSlots{value: cost}();

        // Log the results
        uint256 newSlotCount = player.getPlayerSlots(owner);
        console2.log("Purchased 5 player slots for", cost, "wei");
        console2.log("New total slot count:", newSlotCount);

        vm.stopBroadcast();
    }
}

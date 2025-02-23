// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Player} from "../../../src/fighters/Player.sol";

contract WithdrawPlayerFeesScript is Script {
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

        // Withdraw fees
        player.withdrawFees();
        console2.log("Fees withdrawn from Player contract:", playerContractAddr);

        vm.stopBroadcast();
    }
}

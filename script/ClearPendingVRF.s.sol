// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Player} from "../src/Player.sol";

contract ClearPendingVRFScript is Script {
    function setUp() public {}

    function run(address playerContractAddr, address walletToClear) public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        // Get the deployed Player contract
        Player player = Player(playerContractAddr);

        // Clear the pending VRF requests for the wallet
        player.clearPendingRequestsForAddress(walletToClear);
        console2.log("Cleared pending VRF requests for wallet:", walletToClear);

        vm.stopBroadcast();
    }
}

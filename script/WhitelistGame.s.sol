// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Player} from "../src/Player.sol";

contract WhitelistGameScript is Script {
    function setUp() public {}

    function run(address gameAddr, address playerAddr) public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        Player playerContract = Player(playerAddr);

        // Whitelist the Game contract
        playerContract.setGameContractTrust(gameAddr, true);
        console.log("Game contract whitelisted:", gameAddr);

        vm.stopBroadcast();
    }
}

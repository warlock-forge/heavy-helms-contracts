// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DuelGame} from "../../../src/DuelGame.sol";

contract CancelDuelScript is Script {
    function setUp() public {}

    function run(address duelGameAddr, uint256 challengeId) public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        DuelGame duelGame = DuelGame(payable(duelGameAddr));

        // Cancel the challenge
        duelGame.cancelChallenge(challengeId);
        console.log("Challenge cancelled:", challengeId);

        vm.stopBroadcast();
    }
}

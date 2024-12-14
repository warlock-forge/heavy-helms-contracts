// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DuelGame} from "../src/DuelGame.sol";
import {GameEngine} from "../src/GameEngine.sol";

contract CheckDuelResultScript is Script {
    function setUp() public {}

    function run(address duelGameAddr, uint256 challengeId) public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        DuelGame duelGame = DuelGame(payable(duelGameAddr));

        // Get challenge details
        (uint32 challengerId, uint32 defenderId, uint256 wagerAmount, uint256 createdBlock,,, bool fulfilled) =
            duelGame.challenges(challengeId);

        console.log("Challenge ID:", challengeId);
        console.log("Challenger ID:", challengerId);
        console.log("Defender ID:", defenderId);
        console.log("Wager Amount:", wagerAmount);
        console.log("Created Block:", createdBlock);
        console.log("Fulfilled:", fulfilled);

        if (fulfilled) {
            console.log("Duel has been completed!");
            // You can check the DuelComplete event logs to see who won
        } else if (duelGame.hasPendingRequest(challengeId)) {
            console.log("Duel is still pending VRF completion");
        } else {
            console.log("Challenge is not active or has expired");
        }

        vm.stopBroadcast();
    }
}

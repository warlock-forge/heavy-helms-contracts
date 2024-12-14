// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DuelGame} from "../src/DuelGame.sol";
import {IGameEngine} from "../src/interfaces/IGameEngine.sol";
import {IPlayer} from "../src/interfaces/IPlayer.sol";

contract DuelPlayersScript is Script {
    function setUp() public {}

    function run(address duelGameAddr, uint32 challengerId, uint32 defenderId) public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        DuelGame duelGame = DuelGame(payable(duelGameAddr));
        IPlayer playerContract = IPlayer(duelGame.playerContract());

        // Get challenger's current equipped skin
        IPlayer.PlayerStats memory challengerStats = playerContract.getPlayer(challengerId);
        // Get defender's current equipped skin
        IPlayer.PlayerStats memory defenderStats = playerContract.getPlayer(defenderId);

        // Create loadout for challenger using their current skin
        IGameEngine.PlayerLoadout memory challengerLoadout = IGameEngine.PlayerLoadout({
            playerId: challengerId,
            skinIndex: challengerStats.skinIndex,
            skinTokenId: challengerStats.skinTokenId
        });

        // Create loadout for defender using their current skin
        IGameEngine.PlayerLoadout memory defenderLoadout = IGameEngine.PlayerLoadout({
            playerId: defenderId,
            skinIndex: defenderStats.skinIndex,
            skinTokenId: defenderStats.skinTokenId
        });

        // Get minimum duel fee
        uint256 minDuelFee = duelGame.minDuelFee();
        uint256 wagerAmount = 1 wei;

        // Initiate challenge with minimum fee and 1 wei wager
        uint256 challengeId =
            duelGame.initiateChallenge{value: minDuelFee + wagerAmount}(challengerLoadout, defenderId, wagerAmount);

        console2.log("\n=== Challenge Initiated ===");
        console2.log("Challenge ID:", challengeId);
        console2.log("Challenger ID:", challengerId);
        console2.log("Defender ID:", defenderId);
        console2.log("Wager Amount:", wagerAmount);

        // Accept challenge
        duelGame.acceptChallenge{value: wagerAmount}(challengeId, defenderLoadout);

        console2.log("\n=== Challenge Accepted ===");
        console2.log("Challenge ID:", challengeId);

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DuelGame} from "../../../src/game/modes/DuelGame.sol";
import {Fighter} from "../../../src/fighters/Fighter.sol";
import {IPlayer} from "../../../src/interfaces/fighters/IPlayer.sol";

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
        Fighter.PlayerLoadout memory challengerLoadout =
            Fighter.PlayerLoadout({playerId: challengerId, skin: challengerStats.skin});

        // Create loadout for defender using their current skin
        Fighter.PlayerLoadout memory defenderLoadout =
            Fighter.PlayerLoadout({playerId: defenderId, skin: defenderStats.skin});

        // Get minimum duel fee
        uint256 minDuelFee = duelGame.minDuelFee();

        uint256 challengeId = duelGame.initiateChallenge{value: minDuelFee}(challengerLoadout, defenderId, 0);

        console2.log("\n=== Challenge Initiated ===");
        console2.log("Challenge ID:", challengeId);

        // Accept challenge
        duelGame.acceptChallenge(challengeId, defenderLoadout);

        console2.log("\n=== Challenge Accepted ===");
        console2.log("Challenge ID:", challengeId);

        vm.stopBroadcast();
    }
}

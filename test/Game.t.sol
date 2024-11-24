// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Game} from "../src/Game.sol";
import {Player} from "../src/Player.sol";
import "../src/interfaces/IPlayer.sol";

contract GameTest is Test {
    Game public game;
    Player public playerContract;

    // Add mapping to track player IDs
    mapping(address => uint256) playerIds;

    function setUp() public {
        // Check if we're in CI environment
        try vm.envString("CI") returns (string memory) {
            // In CI: use mock data
            vm.warp(1_000_000);
            vm.roll(16_000_000);
            vm.prevrandao(bytes32(uint256(0x1234567890)));
        } catch {
            // Local dev: require live blockchain data
            try vm.envString("RPC_URL") returns (string memory rpcUrl) {
                vm.createSelectFork(rpcUrl);
            } catch {
                revert(
                    "RPC_URL environment variable not set - tests require live blockchain data for local development"
                );
            }
        }

        // Deploy Player first, then Game
        playerContract = new Player();
        game = new Game(address(playerContract));
    }

    function _generateRandomSeed(address playerAddress) private view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp, 
                    block.prevrandao, 
                    blockhash(block.number - 1), 
                    playerAddress, 
                    address(this)
                )
            )
        );
    }

    function testBasicCombat() public {
        address player1 = address(1);
        address player2 = address(2);

        // Create players and store their IDs
        vm.prank(player1);
        (uint256 p1Id, IPlayer.PlayerStats memory p1Stats) = playerContract.createPlayer(_generateRandomSeed(player1));
        require(p1Stats.strength != 0, "P1 creation failed");
        playerIds[player1] = p1Id;

        vm.prank(player2);
        (uint256 p2Id, IPlayer.PlayerStats memory p2Stats) = playerContract.createPlayer(_generateRandomSeed(player2));
        require(p2Stats.strength != 0, "P2 creation failed");
        playerIds[player2] = p2Id;

        // Get initial states using player IDs
        (uint256 p1InitialHealth, uint256 p1InitialStamina) = playerContract.getPlayerState(p1Id);
        (uint256 p2InitialHealth, uint256 p2InitialStamina) = playerContract.getPlayerState(p2Id);

        uint256 combatSeed = uint256(keccak256(abi.encodePacked(block.timestamp, "combat")));
        bytes memory packedResults = game.playGame(p1Id, p2Id, combatSeed);
        console2.log("\nRaw combat results:");
        console2.logBytes(packedResults);

        (uint256 winner, Game.WinCondition condition, Game.CombatAction[] memory actions) =
            game.decodeCombatLog(packedResults);

        uint256 currentP1Health = p1InitialHealth;
        uint256 currentP1Stamina = p1InitialStamina;
        uint256 currentP2Health = p2InitialHealth;
        uint256 currentP2Stamina = p2InitialStamina;

        for (uint256 i = 0; i < actions.length; i++) {
            Game.CombatAction memory action = actions[i];

            console2.log("\n=== Round %d ===", i + 1);
            console2.log("Player 1: %s", _getCombatResultString(action.p1Result));
            console2.log("  Damage: %d", action.p1Damage);
            console2.log("  Stamina Used: %d", action.p1StaminaLost);
            console2.log("Player 2: %s", _getCombatResultString(action.p2Result));
            console2.log("  Damage: %d", action.p2Damage);
            console2.log("  Stamina Used: %d", action.p2StaminaLost);

            // Update state
            currentP1Health = action.p2Damage >= currentP1Health ? 0 : currentP1Health - action.p2Damage;
            currentP2Health = action.p1Damage >= currentP2Health ? 0 : currentP2Health - action.p1Damage;
            currentP1Stamina = action.p1StaminaLost >= currentP1Stamina ? 0 : currentP1Stamina - action.p1StaminaLost;
            currentP2Stamina = action.p2StaminaLost >= currentP2Stamina ? 0 : currentP2Stamina - action.p2StaminaLost;

            console2.log("After Round %d:", i + 1);
            console2.log("  P1 Health/Stamina: %d/%d", currentP1Health, currentP1Stamina);
            console2.log("  P2 Health/Stamina: %d/%d", currentP2Health, currentP2Stamina);

            // Validate combat results
            assertTrue(action.p1Damage <= 50, "P1 damage too high");
            assertTrue(action.p2Damage <= 50, "P2 damage too high");
            assertTrue(action.p1StaminaLost <= 30, "P1 stamina loss too high");
            assertTrue(action.p2StaminaLost <= 30, "P2 stamina loss too high");

            if (currentP1Health == 0 || currentP2Health == 0) {
                if (i < actions.length - 1) {
                    console2.log("Combat continued after fatal damage");
                    fail();
                }
            }
        }

        console2.log("\n=== Combat Summary ===");
        console2.log("Winner: Player %d", winner);
        console2.log(
            "Win Condition: %s",
            condition == Game.WinCondition.HEALTH
                ? "Health Depletion"
                : condition == Game.WinCondition.EXHAUSTION ? "Stamina Exhaustion" : "Maximum Rounds"
        );
    }

    function logRound(Game.CombatAction memory action) internal pure {
        console2.log("Player 1:", _getCombatResultString(action.p1Result));
        console2.log("- Damage Done:", action.p1Damage);
        console2.log("- Stamina Used:", action.p1StaminaLost);
        console2.log("Player 2:", _getCombatResultString(action.p2Result));
        console2.log("- Damage Done:", action.p2Damage);
        console2.log("- Stamina Used:", action.p2StaminaLost);
    }

    function _getCombatResultString(Game.CombatResultType resultType) internal pure returns (string memory) {
        if (resultType == Game.CombatResultType.ATTACK) return "Attack";
        if (resultType == Game.CombatResultType.MISS) return "Miss";
        if (resultType == Game.CombatResultType.BLOCK) return "Block";
        if (resultType == Game.CombatResultType.COUNTER) return "Counter";
        if (resultType == Game.CombatResultType.DODGE) return "Dodge";
        if (resultType == Game.CombatResultType.HIT) return "Hit";
        return "Unknown";
    }

    function testSpecificScenarios() public {
        address[5] memory playerAddresses = 
            [makeAddr("player1"), makeAddr("player2"), makeAddr("player3"), makeAddr("player4"), makeAddr("player5")];
        uint256[5] memory gamePlayerIds;

        // Create players and store their IDs
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(playerAddresses[i]);
            (uint256 pId, IPlayer.PlayerStats memory pStats) = playerContract.createPlayer(_generateRandomSeed(playerAddresses[i]));
            require(pStats.strength != 0, "Player creation failed");
            gamePlayerIds[i] = pId;
            playerIds[playerAddresses[i]] = pId;
        }

        // Use player IDs for combat
        for (uint256 i = 0; i < 5; i++) {
            bytes memory results = game.playGame(
                gamePlayerIds[i], 
                gamePlayerIds[(i + 1) % 5], 
                _generateRandomSeed(playerAddresses[i])
            );

            // Track action counts
            uint256 attackCount = 0;
            uint256 blockCount = 0;
            uint256 dodgeCount = 0;
            uint256 counterCount = 0;
            uint256 missCount = 0;
            uint256 hitCount = 0;

            // Calculate total rounds (skip 2 bytes for winner/condition, then 6 bytes per round)
            uint256 totalRounds = (results.length - 2) / 6;

            // Skip first 2 bytes (winner and condition)
            for (uint256 j = 2; j < results.length; j += 6) {
                // First player action
                uint8 p1Result = uint8(bytes1(results[j]));
                if (p1Result == uint8(Game.CombatResultType.ATTACK)) attackCount++;
                if (p1Result == uint8(Game.CombatResultType.BLOCK)) blockCount++;
                if (p1Result == uint8(Game.CombatResultType.DODGE)) dodgeCount++;
                if (p1Result == uint8(Game.CombatResultType.COUNTER)) counterCount++;
                if (p1Result == uint8(Game.CombatResultType.MISS)) missCount++;
                if (p1Result == uint8(Game.CombatResultType.HIT)) hitCount++;

                // Second player action
                uint8 p2Result = uint8(bytes1(results[j + 3]));
                if (p2Result == uint8(Game.CombatResultType.ATTACK)) attackCount++;
                if (p2Result == uint8(Game.CombatResultType.BLOCK)) blockCount++;
                if (p2Result == uint8(Game.CombatResultType.DODGE)) dodgeCount++;
                if (p2Result == uint8(Game.CombatResultType.COUNTER)) counterCount++;
                if (p2Result == uint8(Game.CombatResultType.MISS)) missCount++;
                if (p2Result == uint8(Game.CombatResultType.HIT)) hitCount++;
            }

            console2.log("\nCombat", i + 1, "Results:");
            console2.log("  Winner: Player", uint8(bytes1(results[0])));
            console2.log(
                "  Win Condition:",
                uint8(bytes1(results[1])) == 0 ? "Health" : uint8(bytes1(results[1])) == 1 ? "Exhaustion" : "Max Rounds"
            );
            console2.log("  Combat Summary:");
            console2.log("    Total Rounds:", totalRounds);
            console2.log("    Attacks:", attackCount);
            console2.log("    Blocks:", blockCount);
            console2.log("    Dodges:", dodgeCount);
            console2.log("    Counters:", counterCount);
            console2.log("    Misses:", missCount);
            console2.log("    Hits:", hitCount);
            console2.log("");
        }
    }

    function processCombatLog(bytes memory results) internal view returns (uint256 expectedWinner) {
        (uint256 winner,, Game.CombatAction[] memory actions) = game.decodeCombatLog(results);

        // Track state for validation using player IDs
        (uint256 currentP1Health, uint256 currentP1Stamina) = playerContract.getPlayerState(playerIds[address(1)]);
        (uint256 currentP2Health, uint256 currentP2Stamina) = playerContract.getPlayerState(playerIds[address(2)]);

        for (uint256 i = 0; i < actions.length; i++) {
            Game.CombatAction memory action = actions[i];

            console2.log("\nRound %d", (i / 6) + 1);

            console2.log("Player 1:", _getCombatResultString(Game.CombatResultType(action.p1Result)));
            console2.log("- Damage Done:", action.p1Damage);
            console2.log("- Stamina Used:", action.p1StaminaLost);

            console2.log("Player 2:", _getCombatResultString(Game.CombatResultType(action.p2Result)));
            console2.log("- Damage Done:", action.p2Damage);
            console2.log("- Stamina Used:", action.p2StaminaLost);

            console2.log("Current State:");
            console2.log("P1 Health/Stamina: %d / %d", currentP1Health, currentP1Stamina);
            console2.log("P2 Health/Stamina: %d / %d", currentP2Health, currentP2Stamina);

            // Update state tracking
            currentP1Health = action.p2Damage >= currentP1Health ? 0 : currentP1Health - action.p2Damage;
            currentP2Health = action.p1Damage >= currentP2Health ? 0 : currentP2Health - action.p1Damage;
            currentP1Stamina = action.p1StaminaLost >= currentP1Stamina ? 0 : currentP1Stamina - action.p1StaminaLost;
            currentP2Stamina = action.p2StaminaLost >= currentP2Stamina ? 0 : currentP2Stamina - action.p2StaminaLost;
        }

        // Return winner based on the winner byte
        return winner;
    }
}

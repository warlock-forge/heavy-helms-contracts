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

        // Deploy Player with max 5 players per address
        playerContract = new Player(5);
        game = new Game(address(playerContract));
    }

    function testBasicCombat() public {
        address player1 = address(1);
        address player2 = address(2);

        // Create players without randomSeed
        vm.prank(player1);
        (uint256 p1Id, IPlayer.PlayerStats memory p1Stats) = playerContract.createPlayer();
        require(p1Stats.strength != 0, "P1 creation failed");
        playerIds[player1] = p1Id;

        vm.prank(player2);
        (uint256 p2Id, IPlayer.PlayerStats memory p2Stats) = playerContract.createPlayer();
        require(p2Stats.strength != 0, "P2 creation failed");
        playerIds[player2] = p2Id;

        // Get initial states using player IDs
        (uint256 p1InitialHealth, uint256 p1InitialStamina) = playerContract.getPlayerState(p1Id);
        (uint256 p2InitialHealth, uint256 p2InitialStamina) = playerContract.getPlayerState(p2Id);

        uint256 combatSeed = uint256(keccak256(abi.encodePacked(block.timestamp, "combat")));
        bytes memory packedResults = game.playGame(p1Id, p2Id, combatSeed);
        console2.log("\nRaw combat results:");
        console2.logBytes(packedResults);

        (uint256 winner,, Game.CombatAction[] memory actions) = game.decodeCombatLog(packedResults);

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
        string memory winnerStr = winner == 1 ? "Player 1" : "Player 2";
        uint256 winnerId = winner == 1 ? p1Id : p2Id;
        console2.log("      Winner: %s (ID: 0x%x)", winnerStr, winnerId);
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

        // First create all quinque players with their IDs
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(playerAddresses[i]);
            (uint256 pId,) = playerContract.createPlayer();
            gamePlayerIds[i] = pId;
            playerIds[playerAddresses[i]] = pId;

            console2.log("\nQuinque Player created:");
            console2.log("Address: %s", playerAddresses[i]);
            console2.log("ID: 0x%x", pId);
        }

        // Combat between pairs
        for (uint256 i = 0; i < 5; i++) {
            uint256 firstId = gamePlayerIds[i];
            uint256 secondId = gamePlayerIds[(i + 1) % 5];

            // Randomly decide which ID goes into Player 1 position
            bool switchPositions =
                uint256(keccak256(abi.encodePacked("position", block.timestamp, block.prevrandao, i))) % 2 == 1;

            uint256 combatSeed =
                uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, playerAddresses[i], i)));

            bytes memory results;
            if (switchPositions) {
                results = game.playGame(secondId, firstId, combatSeed);
            } else {
                results = game.playGame(firstId, secondId, combatSeed);
            }

            console2.log("\nCombat %d (Seed: 0x%x):", i + 1, combatSeed);
            console2.log("Player 1 (Quinque ID: 0x%x)", switchPositions ? secondId : firstId);
            console2.log("vs");
            console2.log("Player 2 (Quinque ID: 0x%x)", switchPositions ? firstId : secondId);

            // Get the winner (1 or 2) from combat log
            (uint256 winnerNum,,) = game.decodeCombatLog(results);

            console2.log("\nDebug - Raw winner number: %d", winnerNum);

            // Store the actual player IDs used in combat
            uint256 p1Id = switchPositions ? secondId : firstId;
            uint256 p2Id = switchPositions ? firstId : secondId;

            // Convert winner number to actual player ID and string
            uint256 winnerId = winnerNum == 1 ? p1Id : p2Id;
            string memory winnerStr = winnerNum == 1 ? "Player 1" : "Player 2";

            // Add debug info to verify IDs
            console2.log("Player 1 ID: 0x%x", p1Id);
            console2.log("Player 2 ID: 0x%x", p2Id);
            console2.log("\nWinner: %s (Quinque ID: 0x%x)", winnerStr, winnerId);
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

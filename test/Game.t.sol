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

    // Add min function
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

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

        // Create players
        vm.prank(player1);
        (uint256 p1Id, IPlayer.PlayerStats memory p1Stats) = playerContract.createPlayer();
        require(p1Stats.strength != 0, "P1 creation failed");
        playerIds[player1] = p1Id;

        vm.prank(player2);
        (uint256 p2Id, IPlayer.PlayerStats memory p2Stats) = playerContract.createPlayer();
        require(p2Stats.strength != 0, "P2 creation failed");
        playerIds[player2] = p2Id;

        uint256 combatSeed = uint256(keccak256(abi.encodePacked(block.timestamp, "combat")));
        bytes memory packedResults = game.playGame(p1Id, p2Id, combatSeed);

        console2.log("\nRaw combat results:");
        console2.logBytes(packedResults);

        // Decode and validate combat results
        (uint256 winner, Game.WinCondition condition, Game.CombatAction[] memory actions) =
            game.decodeCombatLog(packedResults);

        // Validate results
        for (uint256 i = 0; i < actions.length; i++) {
            Game.CombatAction memory action = actions[i];
            assertTrue(action.p1Damage <= 5000, "P1 damage too high");
            assertTrue(action.p2Damage <= 5000, "P2 damage too high");
            assertTrue(action.p1StaminaLost <= 30, "P1 stamina loss too high");
            assertTrue(action.p2StaminaLost <= 30, "P2 stamina loss too high");
        }

        console2.log("\n=== Combat Summary ===");
        console2.log("Winner: Player %d", winner);
        console2.log("Rounds: %d", actions.length);
        console2.log("Win Condition: %s", _getWinConditionString(condition));
    }

    function testSpecificScenarios() public {
        address[5] memory playerAddresses =
            [makeAddr("player1"), makeAddr("player2"), makeAddr("player3"), makeAddr("player4"), makeAddr("player5")];
        uint256[5] memory gamePlayerIds;

        // Create all players silently
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(playerAddresses[i]);
            (uint256 pId,) = playerContract.createPlayer();
            gamePlayerIds[i] = pId;
            playerIds[playerAddresses[i]] = pId;
        }

        // Combat between pairs
        for (uint256 i = 0; i < 5; i++) {
            uint256 firstId = gamePlayerIds[i];
            uint256 secondId = gamePlayerIds[(i + 1) % 5];

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

            (uint256 winnerNum, Game.WinCondition condition, Game.CombatAction[] memory actions) =
                game.decodeCombatLog(results);

            string memory winnerStr = switchPositions
                ? (winnerNum == 1 ? "Player 2" : "Player 1")
                : (winnerNum == 1 ? "Player 1" : "Player 2");

            string memory conditionStr = _getWinConditionString(condition);
            string memory message = string.concat(
                "Combat ",
                vm.toString(i + 1),
                ": ",
                winnerStr,
                " won after ",
                vm.toString(actions.length),
                " rounds (",
                conditionStr,
                ")"
            );
            console2.log(message);
        }
    }

    // Helper function to convert win condition to string
    function _getWinConditionString(Game.WinCondition condition) internal pure returns (string memory) {
        if (condition == Game.WinCondition.HEALTH) return "KO";
        if (condition == Game.WinCondition.EXHAUSTION) return "Exhaustion";
        if (condition == Game.WinCondition.MAX_ROUNDS) return "Max Rounds";
        return "Unknown";
    }
}

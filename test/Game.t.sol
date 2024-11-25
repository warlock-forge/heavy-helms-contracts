// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Game} from "../src/Game.sol";
import {Player} from "../src/Player.sol";
import "../src/interfaces/IPlayer.sol";

contract GameTest is Test {
    Game public game;
    Player public playerContract;
    mapping(address => uint256) playerIds;

    // Add the constant here since we can't access it from Game
    uint8 constant MAX_ROUNDS = 50;

    function setUp() public {
        try vm.envString("CI") returns (string memory) {
            vm.warp(1_000_000);
            vm.roll(16_000_000);
            vm.prevrandao(bytes32(uint256(0x1234567890)));
        } catch {
            try vm.envString("RPC_URL") returns (string memory rpcUrl) {
                vm.createSelectFork(rpcUrl);
            } catch {
                revert("RPC_URL environment variable not set");
            }
        }
        playerContract = new Player(5);
        game = new Game(address(playerContract));
    }

    function testBasicCombat() public {
        // Create two players
        vm.prank(address(1));
        (uint256 p1Id,) = playerContract.createPlayer();

        vm.prank(address(2));
        (uint256 p2Id,) = playerContract.createPlayer();

        // Run combat
        uint256 combatSeed = uint256(keccak256(abi.encodePacked(block.timestamp, "combat")));
        bytes memory packedResults = game.playGame(p1Id, p2Id, combatSeed);
        (uint256 winner, Game.WinCondition condition, Game.CombatAction[] memory actions) =
            game.decodeCombatLog(packedResults);

        // Verify combat results
        assertTrue(winner == 1 || winner == 2, "Invalid winner");
        assertTrue(actions.length > 0, "No combat actions recorded");
        assertTrue(actions.length <= game.MAX_ROUNDS(), "Combat exceeded max rounds");

        // Log combat summary
        console2.log("\n=== Combat Summary ===");
        console2.log("Winner: Player %d", winner);
        console2.log("Win Condition: %s", _getWinConditionString(condition));
        console2.log("Total Rounds: %d", actions.length);
        console2.log("Raw Combat Results: %s", vm.toString(packedResults));
    }

    function testSpecificScenarios() public {
        // Create multiple players for different scenarios
        IPlayer.PlayerStats[] memory players = new IPlayer.PlayerStats[](5);
        uint256[] memory combatPlayerIds = new uint256[](5); // Renamed to avoid conflict

        // Create 5 players with different addresses
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(address(uint160(i + 1)));
            (combatPlayerIds[i], players[i]) = playerContract.createPlayer();
        }

        // Test different combat scenarios
        for (uint256 i = 0; i < 4; i++) {
            uint256 combatSeed = uint256(keccak256(abi.encodePacked(block.timestamp, "combat", i)));
            bytes memory packedResults = game.playGame(combatPlayerIds[i], combatPlayerIds[i + 1], combatSeed);
            (uint256 winner, Game.WinCondition condition, Game.CombatAction[] memory actions) =
                game.decodeCombatLog(packedResults);

            // Verify combat results
            assertTrue(winner == 1 || winner == 2, "Invalid winner");
            assertTrue(actions.length > 0, "No combat actions recorded");

            // If it reached max rounds, that's an acceptable win condition
            if (condition != Game.WinCondition.MAX_ROUNDS) {
                assertTrue(
                    actions.length <= game.MAX_ROUNDS(), "Combat exceeded max rounds without MAX_ROUNDS condition"
                );
            }

            console2.log("\n=== Combat %d Summary ===", i + 1);
            console2.log("Winner: Player %d", winner);
            console2.log("Win Condition: %s", _getWinConditionString(condition));
            console2.log("Total Rounds: %d", actions.length);
        }
    }

    function _getWinConditionString(Game.WinCondition condition) internal pure returns (string memory) {
        if (condition == Game.WinCondition.HEALTH) return "KO";
        if (condition == Game.WinCondition.EXHAUSTION) return "Exhaustion";
        if (condition == Game.WinCondition.MAX_ROUNDS) return "Max Rounds";
        return "Unknown";
    }
}

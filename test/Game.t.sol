// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Game} from "../src/Game.sol";

contract GameTest is Test {
    Game public game;

    function setUp() public {
        // For CI environment, use a mock chain
        try vm.envString("RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl);
        } catch {
            // If RPC_URL is not available, use a local mock setup
            vm.warp(1_000_000);
            vm.roll(16_000_000);
            // Mock prevrandao value
            vm.prevrandao(bytes32(uint256(0x1234567890)));
        }
        game = new Game();
    }

    function _generateRandomSeed(address player) private view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.prevrandao, blockhash(block.number - 1), player, address(this))
            )
        );
    }

    function _validatePlayerAttributes(Game.Player memory player, string memory context) private pure {
        assertTrue(player.strength >= 3, string.concat(context, ": Strength below minimum"));
        assertTrue(player.constitution >= 3, string.concat(context, ": Constitution below minimum"));
        assertTrue(player.agility >= 3, string.concat(context, ": Agility below minimum"));
        assertTrue(player.stamina >= 3, string.concat(context, ": Stamina below minimum"));

        assertTrue(player.strength <= 21, string.concat(context, ": Strength above maximum"));
        assertTrue(player.constitution <= 21, string.concat(context, ": Constitution above maximum"));
        assertTrue(player.agility <= 21, string.concat(context, ": Agility above maximum"));
        assertTrue(player.stamina <= 21, string.concat(context, ": Stamina above maximum"));

        int16 total =
            int16(player.strength) + int16(player.constitution) + int16(player.agility) + int16(player.stamina);
        assertEq(total, 48, string.concat(context, ": Total attributes should be 48"));
    }

    function testCreatePlayer() public {
        address player = address(1);

        // First creation should succeed
        vm.prank(player);
        uint256 randomSeed = _generateRandomSeed(player);
        Game.Player memory newPlayer = game.createPlayer(randomSeed);
        _validatePlayerAttributes(newPlayer, "Single player test");

        // Second creation with same address should revert
        vm.prank(player);
        vm.expectRevert(Game.PLAYER_EXISTS.selector);
        game.createPlayer(_generateRandomSeed(player));
    }

    function testMultiplePlayers() public {
        string memory stats = "";
        for (uint256 i = 0; i < 5; i++) {
            address player = address(uint160(i + 1));
            vm.prank(player);

            uint256 randomSeed = _generateRandomSeed(player);
            Game.Player memory newPlayer = game.createPlayer(randomSeed);
            _validatePlayerAttributes(newPlayer, string.concat("Player ", vm.toString(i + 1)));

            stats = string.concat(
                stats,
                i == 0 ? "" : " | ",
                string.concat(
                    "P",
                    vm.toString(i + 1),
                    ": ",
                    vm.toString(uint8(newPlayer.strength)),
                    "/",
                    vm.toString(uint8(newPlayer.constitution)),
                    "/",
                    vm.toString(uint8(newPlayer.agility)),
                    "/",
                    vm.toString(uint8(newPlayer.stamina))
                )
            );
        }
        console2.log("Player Stats (STR/CON/AGI/STA):", stats);
    }

    function testBasicCombat() public {
        // Create two players with different builds
        address player1 = address(1);
        address player2 = address(2);

        // Create players
        vm.prank(player1);
        Game.Player memory p1 = game.createPlayer(_generateRandomSeed(player1));

        vm.prank(player2);
        Game.Player memory p2 = game.createPlayer(_generateRandomSeed(player2));

        // Get initial states
        (uint256 p1InitialHealth, uint256 p1InitialStamina) = game.getPlayerState(player1);
        (uint256 p2InitialHealth, uint256 p2InitialStamina) = game.getPlayerState(player2);

        // Debug logs before combat
        console2.log("\n=== Pre-Combat State ===");
        console2.log("Player 1:");
        console2.log("- STR:", p1.strength);
        console2.log("- CON:", p1.constitution);
        console2.log("- AGI:", p1.agility);
        console2.log("- STA:", p1.stamina);
        console2.log("- Initial Health/Stamina:", p1InitialHealth, "/", p1InitialStamina);

        console2.log("\nPlayer 2:");
        console2.log("- STR:", p2.strength);
        console2.log("- CON:", p2.constitution);
        console2.log("- AGI:", p2.agility);
        console2.log("- STA:", p2.stamina);
        console2.log("- Initial Health/Stamina:", p2InitialHealth, "/", p2InitialStamina);

        // Combat seed debug
        uint256 combatSeed = uint256(keccak256(abi.encodePacked(block.timestamp, "combat")));
        console2.log("\nCombat Seed:", combatSeed);

        vm.recordLogs();

        try game.playGame(player1, player2, combatSeed) returns (bytes memory packedResults, address winner) {
            console2.log("Combat completed successfully");
            console2.log("\n=== Combat Log ===");

            // Enhanced action logging
            for (uint256 i = 0; i < packedResults.length; i += 6) {
                console2.log("\nRound", (i / 6) + 1);
                uint8 p1Result = uint8(packedResults[i]);
                uint8 p1Damage = uint8(packedResults[i + 1]);
                uint8 p1StaminaLost = uint8(packedResults[i + 2]);
                uint8 p2Result = uint8(packedResults[i + 3]);
                uint8 p2Damage = uint8(packedResults[i + 4]);
                uint8 p2StaminaLost = uint8(packedResults[i + 5]);

                console2.log("Player 1:", _getCombatResultString(Game.CombatResultType(p1Result)));
                console2.log("- Damage Done:", p1Damage);
                console2.log("- Stamina Used:", p1StaminaLost);

                console2.log("Player 2:", _getCombatResultString(Game.CombatResultType(p2Result)));
                console2.log("- Damage Done:", p2Damage);
                console2.log("- Stamina Used:", p2StaminaLost);

                // Get updated states
                (uint256 p1Health, uint256 p1Stamina) = game.getPlayerState(player1);
                (uint256 p2Health, uint256 p2Stamina) = game.getPlayerState(player2);

                console2.log("P1 Health/Stamina:", p1Health, "/", p1Stamina);
                console2.log("P2 Health/Stamina:", p2Health, "/", p2Stamina);
            }
            console2.log("\nFinal Winner:", winner == player1 ? "Player 1" : "Player 2");
        } catch Error(string memory reason) {
            console2.log("Error:", reason);
        }
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
        // Test specific combat scenarios
        address player1 = address(1);
        address player2 = address(2);

        // Create players with specific stats for testing
        vm.prank(player1);
        game.createPlayer(_generateRandomSeed(player1));

        vm.prank(player2);
        game.createPlayer(_generateRandomSeed(player2));

        // Test multiple combats with different seeds
        for (uint256 i = 0; i < 5; i++) {
            uint256 combatSeed = uint256(keccak256(abi.encodePacked(block.timestamp, i)));

            vm.recordLogs();
            (bytes memory packedResults, address winner) = game.playGame(player1, player2, combatSeed);

            console2.log("\nCombat", i + 1, "Results:");
            console2.log("Total Actions:", packedResults.length / 6);
            console2.log("Winner:", winner == player1 ? "Player 1" : "Player 2");
        }
    }

    function testCombatMath() public {
        address player1 = address(1);
        address player2 = address(2);

        vm.prank(player1);
        game.createPlayer(_generateRandomSeed(player1));

        vm.prank(player2);
        game.createPlayer(_generateRandomSeed(player2));

        // Add debug logging for calculated stats
        (uint256 p1Health, uint256 p1Stamina) = game.getPlayerState(player1);
        (uint256 p2Health, uint256 p2Stamina) = game.getPlayerState(player2);

        console2.log("\nPlayer 1 Stats:");
        console2.log("Health:", p1Health);
        console2.log("Stamina:", p1Stamina);

        console2.log("\nPlayer 2 Stats:");
        console2.log("Health:", p2Health);
        console2.log("Stamina:", p2Stamina);

        // Continue with combat test...
    }
}

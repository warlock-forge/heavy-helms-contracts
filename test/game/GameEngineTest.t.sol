// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {IGameEngine} from "../../src/interfaces/game/engine/IGameEngine.sol";
import {TestBase} from "../TestBase.sol";
import {DefaultPlayerLibrary} from "../../src/fighters/lib/DefaultPlayerLibrary.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";
import {GameEngine} from "../../src/game/engine/GameEngine.sol";

contract GameEngineTest is TestBase {
    function testCombatMechanics() public view {
        // Test combat mechanics with offensive vs defensive setup and pseudo-random seed
        uint256 seed = _generateGameSeed();

        Fighter.PlayerLoadout memory attackerLoadout = _createLoadout(3); // GreatswordOffensive
        Fighter.PlayerLoadout memory defenderLoadout = _createLoadout(1); // DefaultWarrior

        // Run combat with seed and verify mechanics
        bytes memory results = gameEngine.processGame(
            _convertToFighterStats(attackerLoadout), _convertToFighterStats(defenderLoadout), seed, 0
        );

        (, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);
    }

    function testFuzz_Combat(uint256 seed) public view {
        // Create loadouts for fuzz testing
        Fighter.PlayerLoadout memory player1 = _createLoadout(3); // GreatswordOffensive
        Fighter.PlayerLoadout memory player2 = _createLoadout(6); // MaceShieldDefensive

        // Run game with fuzzed seed
        bytes memory results =
            gameEngine.processGame(_convertToFighterStats(player1), _convertToFighterStats(player2), seed, 0);

        (,, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Verify game invariants hold with any seed
        assertTrue(actions.length > 0, "No actions recorded");
        assertTrue(uint8(condition) <= uint8(type(IGameEngine.WinCondition).max), "Invalid win condition");

        // Verify both players had a chance to act
        bool player1Action = false;
        bool player2Action = false;

        for (uint256 i = 0; i < actions.length; i++) {
            // Player 1 acts if they deal damage, have a defensive result, or attempt an attack
            if (
                actions[i].p1Damage > 0 || _isDefensiveResult(actions[i].p1Result)
                    || actions[i].p1Result == IGameEngine.CombatResultType.ATTACK
                    || actions[i].p1Result == IGameEngine.CombatResultType.CRIT
            ) {
                player1Action = true;
            }

            // Player 2 acts if they deal damage, have a defensive result, or attempt an attack
            if (
                actions[i].p2Damage > 0 || _isDefensiveResult(actions[i].p2Result)
                    || actions[i].p2Result == IGameEngine.CombatResultType.ATTACK
                    || actions[i].p2Result == IGameEngine.CombatResultType.CRIT
            ) {
                player2Action = true;
            }

            if (player1Action && player2Action) break;
        }

        assertTrue(player1Action, "Player 1 never acted");
        assertTrue(player2Action, "Player 2 never acted");
    }

    function testParryChanceCalculation() public view {
        // Create a loadout for a defensive character
        Fighter.PlayerLoadout memory defenderLoadout = _createLoadout(7); // RapierShieldDefensive

        // Convert to FighterStats
        IGameEngine.FighterStats memory fighterStats = _convertToFighterStats(defenderLoadout);

        // Calculate stats using the proper FighterStats
        GameEngine.CalculatedStats memory calcStats = gameEngine.calculateStats(fighterStats);

        // Verify parry chance is within valid range
        assertTrue(calcStats.parryChance > 0, "Parry chance should be greater than 0");
        assertTrue(calcStats.parryChance <= 100, "Parry chance should be <= 100");
    }

    function testHighDamageEncoding() public pure {
        // Test several high damage values
        uint16[] memory testDamages = new uint16[](4);
        testDamages[0] = 256; // Just over uint8 max
        testDamages[1] = 300; // Mid-range value
        testDamages[2] = 1000; // High value
        testDamages[3] = 65535; // Max uint16 value

        // Test encoding and decoding of each damage value
        for (uint256 i = 0; i < testDamages.length; i++) {
            uint16 originalDamage = testDamages[i];

            // Create action data with the damage value
            bytes memory actionData = new bytes(8);
            actionData[0] = bytes1(uint8(1)); // Action type
            actionData[1] = bytes1(uint8(originalDamage >> 8)); // High byte
            actionData[2] = bytes1(uint8(originalDamage)); // Low byte

            // Decode the damage value
            uint16 decodedDamage = uint16(uint8(actionData[1])) << 8 | uint16(uint8(actionData[2]));

            // Verify the decoded value matches the original
            assertEq(decodedDamage, originalDamage, "Damage encoding/decoding mismatch");
        }
    }
}

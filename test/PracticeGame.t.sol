// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {PracticeGame} from "../src/PracticeGame.sol";
import {GameEngine} from "../src/GameEngine.sol";
import {Player} from "../src/Player.sol";
import {PlayerSkinRegistry} from "../src/PlayerSkinRegistry.sol";
import {DefaultPlayerSkinNFT} from "../src/DefaultPlayerSkinNFT.sol";
import "./utils/TestBase.sol";
import "../src/lib/DefaultPlayerLibrary.sol";
import {IGameDefinitions} from "../src/interfaces/IGameDefinitions.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";

contract PracticeGameTest is TestBase {
    PracticeGame public practiceGame;

    function setUp() public override {
        super.setUp();

        // Deploy Game contracts
        practiceGame = new PracticeGame(address(gameEngine), address(playerContract));
    }

    function testBasicCombat() public {
        // Test basic combat functionality with pseudo-random seed
        uint256 seed = _generateGameSeed();

        GameEngine.PlayerLoadout memory player1 = _createLoadout(chars.greatswordOffensive, true, false, playerContract);
        GameEngine.PlayerLoadout memory player2 =
            _createLoadout(chars.swordAndShieldDefensive, true, false, playerContract);

        // Run the game with seed and verify the result format
        bytes memory results = gameEngine.processGame(_convertToLoadout(player1), _convertToLoadout(player2), seed, 0);
        (uint256 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Basic validation
        super._assertValidCombatResult(winner, version, condition, actions, player1.playerId, player2.playerId);
    }

    function testCombatMechanics() public {
        // Test combat mechanics with offensive vs defensive setup and pseudo-random seed
        uint256 seed = _generateGameSeed();

        GameEngine.PlayerLoadout memory attackerLoadout =
            _createLoadout(chars.greatswordOffensive, true, false, playerContract);
        GameEngine.PlayerLoadout memory defenderLoadout =
            _createLoadout(chars.quarterstaffDefensive, true, false, playerContract);

        // Run combat with seed and verify mechanics
        bytes memory results =
            gameEngine.processGame(_convertToLoadout(attackerLoadout), _convertToLoadout(defenderLoadout), seed, 0);
        (uint256 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Verify basic mechanics
        super._assertValidCombatResult(
            winner, version, condition, actions, attackerLoadout.playerId, defenderLoadout.playerId
        );

        // Verify combat actions
        bool hasOffensiveAction = false;
        bool hasDefensiveAction = false;

        for (uint256 i = 0; i < actions.length; i++) {
            if (_isOffensiveAction(actions[i])) hasOffensiveAction = true;
            if (_isDefensiveAction(actions[i])) hasDefensiveAction = true;
            if (hasOffensiveAction && hasDefensiveAction) break;
        }

        assertTrue(hasOffensiveAction, "No offensive actions occurred in combat");
        assertTrue(hasDefensiveAction, "No defensive actions occurred in combat");
    }

    function testFuzzCombat(uint256 seed) public {
        // Create loadouts for fuzz testing
        GameEngine.PlayerLoadout memory player1 = _createLoadout(chars.greatswordOffensive, true, false, playerContract);
        GameEngine.PlayerLoadout memory player2 =
            _createLoadout(chars.swordAndShieldDefensive, true, false, playerContract);

        // Run game with fuzzed seed
        bytes memory results = gameEngine.processGame(_convertToLoadout(player1), _convertToLoadout(player2), seed, 0);
        (uint256 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Verify game invariants hold with any seed
        assertTrue(winner == player1.playerId || winner == player2.playerId, "Invalid winner");
        assertTrue(actions.length > 0, "No actions recorded");
        assertTrue(uint8(condition) <= uint8(type(GameEngine.WinCondition).max), "Invalid win condition");

        // Verify both players had a chance to act
        bool player1Action = false;
        bool player2Action = false;

        for (uint256 i = 0; i < actions.length; i++) {
            if (actions[i].p1Damage > 0 || _isDefensiveResult(actions[i].p1Result)) player1Action = true;
            if (actions[i].p2Damage > 0 || _isDefensiveResult(actions[i].p2Result)) player2Action = true;
            if (player1Action && player2Action) break;
        }

        assertTrue(player1Action, "Player 1 never acted");
        assertTrue(player2Action, "Player 2 never acted");
    }

    function testSpecificScenarios() public {
        // Test specific combat scenarios with different character combinations
        bytes memory results;

        // Scenario 1: Greatsword vs Sword and Shield (Offensive vs Defensive)
        GameEngine.PlayerLoadout memory loadout1A =
            _createLoadout(chars.greatswordOffensive, true, false, playerContract);
        GameEngine.PlayerLoadout memory loadout1B =
            _createLoadout(chars.swordAndShieldDefensive, true, false, playerContract);
        results = practiceGame.play(loadout1A, loadout1B);
        (uint256 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(winner, version, condition, actions, loadout1A.playerId, loadout1B.playerId);

        // Scenario 2: Battleaxe vs Rapier and Shield (Offensive vs Defensive)
        GameEngine.PlayerLoadout memory loadout2A =
            _createLoadout(chars.battleaxeOffensive, true, false, playerContract);
        GameEngine.PlayerLoadout memory loadout2B =
            _createLoadout(chars.rapierAndShieldDefensive, true, false, playerContract);
        results = practiceGame.play(loadout2A, loadout2B);
        (winner, version, condition, actions) = gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(winner, version, condition, actions, loadout2A.playerId, loadout2B.playerId);

        // Scenario 3: Spear vs Quarterstaff (Balanced vs Defensive)
        GameEngine.PlayerLoadout memory loadout3A = _createLoadout(chars.spearBalanced, true, false, playerContract);
        GameEngine.PlayerLoadout memory loadout3B =
            _createLoadout(chars.quarterstaffDefensive, true, false, playerContract);
        results = practiceGame.play(loadout3A, loadout3B);
        (winner, version, condition, actions) = gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(winner, version, condition, actions, loadout3A.playerId, loadout3B.playerId);

        // Scenario 4: Greatsword vs Rapier and Shield (Offensive vs Defensive)
        GameEngine.PlayerLoadout memory loadout4A =
            _createLoadout(chars.greatswordOffensive, true, false, playerContract);
        GameEngine.PlayerLoadout memory loadout4B =
            _createLoadout(chars.rapierAndShieldDefensive, true, false, playerContract);
        results = practiceGame.play(loadout4A, loadout4B);
        (winner, version, condition, actions) = gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(winner, version, condition, actions, loadout4A.playerId, loadout4B.playerId);
    }

    function testDefensiveActions() public {
        // Test defensive mechanics with specific character loadouts
        GameEngine.PlayerLoadout memory attackerLoadout =
            _createLoadout(chars.greatswordOffensive, true, false, playerContract);
        GameEngine.PlayerLoadout memory defenderLoadout =
            _createLoadout(chars.quarterstaffDefensive, true, false, playerContract);

        // Get defender's stats to verify defensive capabilities
        IPlayer.PlayerStats memory defenderStats = playerContract.getPlayer(defenderLoadout.playerId);
        GameEngine.CalculatedStats memory calcStats = gameEngine.calculateStats(defenderStats);

        // Run combat and analyze defensive actions
        bytes memory results = practiceGame.play(attackerLoadout, defenderLoadout);
        (uint256 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Verify defensive actions occurred
        bool hasDefensiveAction = false;
        for (uint256 i = 0; i < actions.length; i++) {
            if (_isDefensiveAction(actions[i])) {
                hasDefensiveAction = true;
                break;
            }
        }
        assertTrue(hasDefensiveAction, "No defensive actions occurred in combat");
    }

    function testParryChanceCalculation() public {
        // Test parry chance calculation for a defensive character
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(chars.rapierAndShieldDefensive);
        GameEngine.CalculatedStats memory calcStats = gameEngine.calculateStats(stats);

        // Verify parry chance is within valid range
        assertTrue(calcStats.parryChance > 0, "Parry chance should be greater than 0");
        assertTrue(calcStats.parryChance <= 100, "Parry chance should be <= 100");
    }

    function testCombatLogStructure() public {
        // Test the structure and decoding of combat logs
        GameEngine.PlayerLoadout memory p1Loadout =
            _createLoadout(chars.greatswordOffensive, true, false, playerContract);
        GameEngine.PlayerLoadout memory p2Loadout =
            _createLoadout(chars.quarterstaffDefensive, true, false, playerContract);

        bytes memory results = practiceGame.play(p1Loadout, p2Loadout);
        (uint256 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Verify combat log structure
        super._assertValidCombatResult(winner, version, condition, actions, p1Loadout.playerId, p2Loadout.playerId);

        // Verify action structure
        for (uint256 i = 0; i < actions.length; i++) {
            assertTrue(
                uint8(actions[i].p1Result) <= uint8(type(GameEngine.CombatResultType).max),
                string.concat("Invalid action type at index ", vm.toString(i))
            );
        }
    }

    function testStanceInteractions() public {
        // Test how different stances interact with each other
        GameEngine.PlayerLoadout memory p1Loadout =
            _createLoadout(chars.greatswordOffensive, true, false, playerContract);
        GameEngine.PlayerLoadout memory p2Loadout =
            _createLoadout(chars.quarterstaffDefensive, true, false, playerContract);

        bytes memory results = practiceGame.play(p1Loadout, p2Loadout);
        (uint256 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(winner, version, condition, actions, p1Loadout.playerId, p2Loadout.playerId);
    }

    function testStanceModifiers() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }

        // Get stance modifiers for logging
        GameEngine.StanceMultiplier memory stance =
            gameEngine.getStanceMultiplier(IGameDefinitions.FightingStance.Defensive);
        console2.log(
            "Stance Mods - Block:%d Parry:%d Dodge:%d", stance.blockChance, stance.parryChance, stance.dodgeChance
        );

        // Test scenarios with different weapon matchups
        console2.log("\n=== Scenario 1 ===");
        console2.log("Offensive: Greatsword vs Defensive: SwordAndShield");
        runStanceScenario(chars.greatswordOffensive, chars.swordAndShieldDefensive, 20);

        // Roll forward to get new entropy
        vm.roll(block.number + 100);
        vm.warp(block.timestamp + 1200);

        console2.log("\n=== Scenario 2 ===");
        console2.log("Offensive: Battleaxe vs Defensive: SwordAndShield");
        runStanceScenario(chars.battleaxeOffensive, chars.swordAndShieldDefensive, 20);

        // Roll forward again
        vm.roll(block.number + 100);
        vm.warp(block.timestamp + 1200);

        console2.log("\n=== Scenario 3 ===");
        console2.log("Offensive: Spear vs Defensive: SwordAndShield");
        runStanceScenario(chars.spearBalanced, chars.swordAndShieldDefensive, 20);
    }

    function runStanceScenario(uint32 player1Id, uint32 player2Id, uint256 rounds) internal {
        IGameEngine.PlayerLoadout memory p1Loadout = _createLoadout(player1Id, true, false, playerContract);
        IGameEngine.PlayerLoadout memory p2Loadout = _createLoadout(player2Id, true, false, playerContract);

        uint256 p1Wins = 0;
        uint256 p2Wins = 0;
        uint256 totalRounds = 0;

        for (uint256 i = 0; i < rounds; i++) {
            // Get entropy from the forked chain
            uint256 seed = uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp + i, block.prevrandao, blockhash(block.number - (i % 256)), msg.sender, i
                    )
                )
            );

            // Move time and blocks forward for new entropy
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 12); // ~12 second blocks

            // Run game with seed from forked chain
            bytes memory results =
                gameEngine.processGame(_convertToLoadout(p1Loadout), _convertToLoadout(p2Loadout), seed, 0);
            (uint32 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions)
            = gameEngine.decodeCombatLog(results);

            if (winner == p1Loadout.playerId) p1Wins++;
            else if (winner == p2Loadout.playerId) p2Wins++;

            totalRounds += actions.length;
        }

        // Log results
        console2.log("Scenario Results:");
        console2.log("Offensive Player #%d Wins: %d (%d%%)", p1Loadout.playerId, p1Wins, (p1Wins * 100) / rounds);
        console2.log("Defensive Player #%d Wins: %d (%d%%)", p2Loadout.playerId, p2Wins, (p2Wins * 100) / rounds);
        console2.log("Average Rounds: %d", totalRounds / rounds);

        // Verify both players can win
        assertTrue(p1Wins > 0, "Offensive stance never won");
        assertTrue(p2Wins > 0, "Defensive stance never won");
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

    function getWeaponName(IGameDefinitions.WeaponType weapon) internal pure returns (string memory) {
        if (weapon == IGameDefinitions.WeaponType.Greatsword) return "Greatsword";
        if (weapon == IGameDefinitions.WeaponType.Battleaxe) return "Battleaxe";
        if (weapon == IGameDefinitions.WeaponType.Spear) return "Spear";
        if (weapon == IGameDefinitions.WeaponType.SwordAndShield) return "SwordAndShield";
        if (weapon == IGameDefinitions.WeaponType.MaceAndShield) return "MaceAndShield";
        if (weapon == IGameDefinitions.WeaponType.Quarterstaff) return "Quarterstaff";
        return "Unknown";
    }

    function getArmorName(IGameDefinitions.ArmorType armor) internal pure returns (string memory) {
        if (armor == IGameDefinitions.ArmorType.Leather) return "Leather";
        if (armor == IGameDefinitions.ArmorType.Chain) return "Chain";
        if (armor == IGameDefinitions.ArmorType.Plate) return "Plate";
        return "Unknown";
    }

    function isOffensiveAction(GameEngine.CombatAction memory action) internal pure returns (bool) {
        return _isOffensiveAction(action);
    }

    function isDefensiveAction(GameEngine.CombatAction memory action) internal pure returns (bool) {
        return _isDefensiveAction(action);
    }

    function isDefensiveResult(GameEngine.CombatResultType result) internal pure returns (bool) {
        return _isDefensiveResult(result);
    }
}

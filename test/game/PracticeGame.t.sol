// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {PracticeGame} from "../../src/game/modes/PracticeGame.sol";
import {Player} from "../../src/fighters/Player.sol";
import {PlayerSkinRegistry} from "../../src/fighters/registries/skins/PlayerSkinRegistry.sol";
import {DefaultPlayerSkinNFT} from "../../src/nft/skins/DefaultPlayerSkinNFT.sol";
import "../TestBase.sol";
import {DefaultPlayerLibrary} from "../../src/fighters/lib/DefaultPlayerLibrary.sol";
import {PlayerNameRegistry} from "../../src/fighters/registries/names/PlayerNameRegistry.sol";
import {IGameEngine} from "../../src/interfaces/game/engine/IGameEngine.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";

contract PracticeGameTest is TestBase {
    PracticeGame public practiceGame;

    function setUp() public override {
        super.setUp();
        practiceGame = new PracticeGame(
            address(gameEngine), address(playerContract), address(defaultPlayerContract), address(monsterContract)
        );
    }

    function testBasicCombat() public {
        // Test basic combat functionality with pseudo-random seed
        uint256 seed = _generateGameSeed();

        Fighter.PlayerLoadout memory player1 =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1);
        Fighter.PlayerLoadout memory player2 =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.MaceAndShieldDefensive) + 1);

        bytes memory results = practiceGame.play(player1, player2);
        (bool player1Won, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);
    }

    function testCombatMechanics() public {
        // Test combat mechanics with offensive vs defensive setup and pseudo-random seed
        uint256 seed = _generateGameSeed();

        Fighter.PlayerLoadout memory attackerLoadout =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1);
        Fighter.PlayerLoadout memory defenderLoadout =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.DefaultWarrior) + 1);

        // Get the appropriate Fighter contracts
        Fighter attackerFighter = _getFighterContract(attackerLoadout.playerId);
        Fighter defenderFighter = _getFighterContract(defenderLoadout.playerId);

        // Run combat with seed and verify mechanics
        bytes memory results = gameEngine.processGame(
            attackerFighter.convertToFighterStats(attackerLoadout),
            defenderFighter.convertToFighterStats(defenderLoadout),
            seed,
            0
        );

        (bool player1Won, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);
    }

    function testFuzz_Combat(uint256 seed) public {
        // Create loadouts for fuzz testing
        Fighter.PlayerLoadout memory player1 =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1);
        Fighter.PlayerLoadout memory player2 =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.MaceAndShieldDefensive) + 1);

        // Get the appropriate Fighter contracts
        Fighter p1Fighter = _getFighterContract(player1.playerId);
        Fighter p2Fighter = _getFighterContract(player2.playerId);

        // Run game with fuzzed seed
        bytes memory results = gameEngine.processGame(
            p1Fighter.convertToFighterStats(player1), p2Fighter.convertToFighterStats(player2), seed, 0
        );

        (bool player1Won, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Verify game invariants hold with any seed
        assertTrue(actions.length > 0, "No actions recorded");
        assertTrue(uint8(condition) <= uint8(type(IGameEngine.WinCondition).max), "Invalid win condition");

        // Verify both players had a chance to act
        bool player1Action = false;
        bool player2Action = false;

        for (uint256 i = 0; i < actions.length; i++) {
            // Player 1 acts if they deal damage, have a defensive result, or attempt an attack
            if (actions[i].p1Damage > 0 || _isDefensiveResult(actions[i].p1Result) || 
                actions[i].p1Result == IGameEngine.CombatResultType.ATTACK || 
                actions[i].p1Result == IGameEngine.CombatResultType.CRIT) {
                player1Action = true;
            }
            
            // Player 2 acts if they deal damage, have a defensive result, or attempt an attack
            if (actions[i].p2Damage > 0 || _isDefensiveResult(actions[i].p2Result) || 
                actions[i].p2Result == IGameEngine.CombatResultType.ATTACK || 
                actions[i].p2Result == IGameEngine.CombatResultType.CRIT) {
                player2Action = true;
            }
            
            if (player1Action && player2Action) break;
        }

        assertTrue(player1Action, "Player 1 never acted");
        assertTrue(player2Action, "Player 2 never acted");
    }

    function testSpecificScenarios() public {
        bytes memory results;
        bool player1Won;
        uint16 version;
        GameEngine.WinCondition condition;
        GameEngine.CombatAction[] memory actions;

        // Scenario 1: Greatsword vs Sword and Shield (Offensive vs Defensive)
        Fighter.PlayerLoadout memory loadout1A =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1);
        Fighter.PlayerLoadout memory loadout1B =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.MaceAndShieldDefensive) + 1);
        results = practiceGame.play(loadout1A, loadout1B);
        (player1Won, version, condition, actions) = gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);

        // Scenario 2: Battleaxe vs Rapier and Shield (Offensive vs Defensive)
        Fighter.PlayerLoadout memory loadout2A =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.BattleaxeOffensive) + 1);
        Fighter.PlayerLoadout memory loadout2B =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.RapierAndShieldDefensive) + 1);
        results = practiceGame.play(loadout2A, loadout2B);
        (player1Won, version, condition, actions) = gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);

        // Scenario 3: Spear vs Quarterstaff (Balanced vs Defensive)
        Fighter.PlayerLoadout memory loadout3A =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.SpearBalanced) + 1);
        Fighter.PlayerLoadout memory loadout3B =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.DefaultWarrior) + 1);
        results = practiceGame.play(loadout3A, loadout3B);
        (player1Won, version, condition, actions) = gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);

        // Scenario 4: Greatsword vs Rapier and Shield (Offensive vs Defensive)
        Fighter.PlayerLoadout memory loadout4A =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1);
        Fighter.PlayerLoadout memory loadout4B =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.RapierAndShieldDefensive) + 1);
        results = practiceGame.play(loadout4A, loadout4B);
        (player1Won, version, condition, actions) = gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);
    }

    function testParryChanceCalculation() public {
        // Create a loadout for a defensive character
        Fighter.PlayerLoadout memory defenderLoadout =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.RapierAndShieldDefensive) + 1);

        // Get the appropriate Fighter contract and convert to FighterStats
        Fighter defender = _getFighterContract(defenderLoadout.playerId);
        IGameEngine.FighterStats memory fighterStats = defender.convertToFighterStats(defenderLoadout);

        // Calculate stats using the proper FighterStats
        GameEngine.CalculatedStats memory calcStats = gameEngine.calculateStats(fighterStats);

        // Verify parry chance is within valid range
        assertTrue(calcStats.parryChance > 0, "Parry chance should be greater than 0");
        assertTrue(calcStats.parryChance <= 100, "Parry chance should be <= 100");
    }

    function testCombatLogStructure() public {
        // Test the structure and decoding of combat logs
        Fighter.PlayerLoadout memory p1Loadout =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1);
        Fighter.PlayerLoadout memory p2Loadout =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.DefaultWarrior) + 1);

        bytes memory results = practiceGame.play(p1Loadout, p2Loadout);
        (bool player1Won, uint16 version, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions)
        = gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);

        // Verify action structure
        for (uint256 i = 0; i < actions.length; i++) {
            assertTrue(
                uint8(actions[i].p1Result) <= uint8(type(IGameEngine.CombatResultType).max),
                string.concat("Invalid action type at index ", vm.toString(i))
            );
        }

        // Verify that at least one player has a non-zero stamina cost in at least one action
        bool foundNonZeroStamina = false;
        for (uint256 i = 0; i < actions.length; i++) {
            if (actions[i].p1StaminaLost > 0 || actions[i].p2StaminaLost > 0) {
                foundNonZeroStamina = true;
                break;
            }
        }

        assertTrue(foundNonZeroStamina, "No actions had stamina costs greater than zero");

        // Verify that specific actions have appropriate stamina costs
        bool attackActionFound = false;
        for (uint256 i = 0; i < actions.length; i++) {
            // Check if player 1 is attacking
            if (
                actions[i].p1Result == IGameEngine.CombatResultType.ATTACK
                    || actions[i].p1Result == IGameEngine.CombatResultType.CRIT
            ) {
                assertTrue(actions[i].p1StaminaLost > 0, "Attack action should have stamina cost");
                attackActionFound = true;
                break;
            }
            // Check if player 2 is attacking
            if (
                actions[i].p2Result == IGameEngine.CombatResultType.ATTACK
                    || actions[i].p2Result == IGameEngine.CombatResultType.CRIT
            ) {
                assertTrue(actions[i].p2StaminaLost > 0, "Attack action should have stamina cost");
                attackActionFound = true;
                break;
            }
        }

        assertTrue(attackActionFound, "No attack actions found in combat log");
    }

    function testStanceInteractions() public {
        // Test how different stances interact with each other
        Fighter.PlayerLoadout memory p1Loadout =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1);
        Fighter.PlayerLoadout memory p2Loadout =
            _createLoadout(uint16(DefaultPlayerLibrary.CharacterType.DefaultWarrior) + 1);

        bytes memory results = practiceGame.play(p1Loadout, p2Loadout);
        (bool player1Won, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);
    }

    function testStanceModifiers() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }

        // Get stance modifiers for logging
        GameEngine.StanceMultiplier memory stance = gameEngine.getStanceMultiplier(gameEngine.STANCE_DEFENSIVE());
        console2.log(
            "Stance Mods - Block:%d Parry:%d Dodge:%d", stance.blockChance, stance.parryChance, stance.dodgeChance
        );

        // Test scenarios with different weapon matchups
        console2.log("\n=== Scenario 1 ===");
        console2.log("Offensive: Greatsword vs Defensive: SwordAndShield");
        runStanceScenario(
            uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1,
            uint16(DefaultPlayerLibrary.CharacterType.MaceAndShieldDefensive) + 1,
            20
        );

        // Roll forward to get new entropy
        vm.roll(block.number + 100);
        vm.warp(block.timestamp + 1200);

        console2.log("\n=== Scenario 2 ===");
        console2.log("Offensive: Battleaxe vs Defensive: SwordAndShield");
        runStanceScenario(
            uint16(DefaultPlayerLibrary.CharacterType.BattleaxeOffensive) + 1,
            uint16(DefaultPlayerLibrary.CharacterType.MaceAndShieldDefensive) + 1,
            20
        );

        // Roll forward again
        vm.roll(block.number + 100);
        vm.warp(block.timestamp + 1200);

        console2.log("\n=== Scenario 3 ===");
        console2.log("Offensive: Spear vs Defensive: SwordAndShield");
        runStanceScenario(
            uint16(DefaultPlayerLibrary.CharacterType.SpearBalanced) + 1,
            uint16(DefaultPlayerLibrary.CharacterType.MaceAndShieldDefensive) + 1,
            20
        );
    }

    function runStanceScenario(uint16 attackerType, uint16 defenderType, uint256 rounds) internal {
        Fighter.PlayerLoadout memory attacker = _createLoadout(attackerType);
        Fighter.PlayerLoadout memory defender = _createLoadout(defenderType);

        // Get the appropriate Fighter contracts
        Fighter attackerFighter = _getFighterContract(attacker.playerId);
        Fighter defenderFighter = _getFighterContract(defender.playerId);

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
            bytes memory results = gameEngine.processGame(
                attackerFighter.convertToFighterStats(attacker),
                defenderFighter.convertToFighterStats(defender),
                seed,
                0
            );

            (
                bool player1Won,
                uint16 version,
                IGameEngine.WinCondition condition,
                IGameEngine.CombatAction[] memory actions
            ) = gameEngine.decodeCombatLog(results);

            if (player1Won) p1Wins++;
            else p2Wins++; // If player1Won is false, player 2 won

            totalRounds += actions.length;
        }

        // Log results
        console2.log("Scenario Results:");
        console2.log("Offensive Player #%d Wins: %d (%d%%)", attacker.playerId, p1Wins, (p1Wins * 100) / rounds);
        console2.log("Defensive Player #%d Wins: %d (%d%%)", defender.playerId, p2Wins, (p2Wins * 100) / rounds);
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
}

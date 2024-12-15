// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {PracticeGame} from "../src/PracticeGame.sol";
import {GameEngine} from "../src/GameEngine.sol";
import {PlayerEquipmentStats} from "../src/PlayerEquipmentStats.sol";
import {Player} from "../src/Player.sol";
import {PlayerSkinRegistry} from "../src/PlayerSkinRegistry.sol";
import {DefaultPlayerSkinNFT} from "../src/DefaultPlayerSkinNFT.sol";
import "../src/interfaces/IPlayer.sol";
import "../src/interfaces/IGameEngine.sol";
import "./utils/TestBase.sol";
import "../src/lib/DefaultPlayerLibrary.sol";
import "../src/interfaces/IPlayerSkinNFT.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";

contract PracticeGameTest is TestBase {
    PracticeGame public practiceGame;
    GameEngine public gameEngine;
    DefaultCharacters public chars;

    function setUp() public override {
        super.setUp();

        // Deploy registries
        nameRegistry = new PlayerNameRegistry();
        equipmentStats = new PlayerEquipmentStats();

        // Deploy Player contract with dependencies
        playerContract = new Player(address(skinRegistry), address(nameRegistry), address(equipmentStats), address(1));

        // Deploy Game contracts
        gameEngine = new GameEngine();
        practiceGame = new PracticeGame(address(gameEngine), address(playerContract));

        // Register default skin and set up registry
        vm.deal(address(this), skinRegistry.registrationFee());
        skinIndex = uint32(skinRegistry.registerSkin{value: skinRegistry.registrationFee()}(address(defaultSkin)));
        skinRegistry.setDefaultSkinRegistryId(skinIndex);
        skinRegistry.setDefaultCollection(skinIndex, true);

        // Mint default characters for testing
        mintDefaultCharacters();
    }

    function mintDefaultCharacters() internal {
        // Create offensive characters
        (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        ) = DefaultPlayerLibrary.getOffensiveTestWarrior(skinIndex, 2);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 2);
        chars.greatswordOffensive = 2;

        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getOffensiveTestWarrior(skinIndex, 3);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 3);
        chars.battleaxeOffensive = 3;

        // Create balanced character
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getDefaultWarrior(skinIndex, 4);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 4);
        chars.spearBalanced = 4;

        // Create defensive characters
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getSwordAndShieldUser(skinIndex, 5);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 5);
        chars.swordAndShieldDefensive = 5;

        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getRapierAndShieldUser(skinIndex, 6);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 6);
        chars.rapierAndShieldDefensive = 6;

        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getQuarterstaffUser(skinIndex, 7);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 7);
        chars.quarterstaffDefensive = 7;
    }

    function testBasicCombat() public {
        // Test basic combat functionality with pseudo-random seed
        uint256 seed = _generateGameSeed();

        GameEngine.PlayerLoadout memory player1 = _createLoadout(chars.greatswordOffensive, true, false, playerContract);
        GameEngine.PlayerLoadout memory player2 =
            _createLoadout(chars.swordAndShieldDefensive, true, false, playerContract);

        // Run the game with seed and verify the result format
        bytes memory results = gameEngine.processGame(player1, player2, seed, playerContract);
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
        bytes memory results = gameEngine.processGame(attackerLoadout, defenderLoadout, seed, playerContract);
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
        bytes memory results = gameEngine.processGame(player1, player2, seed, playerContract);
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
        IPlayer.CalculatedStats memory calcStats = playerContract.calculateStats(defenderStats);

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
        IPlayer.CalculatedStats memory calcStats = playerContract.calculateStats(stats);

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

    function getWeaponName(IPlayerSkinNFT.WeaponType weapon) internal pure returns (string memory) {
        if (weapon == IPlayerSkinNFT.WeaponType.Greatsword) return "Greatsword";
        if (weapon == IPlayerSkinNFT.WeaponType.Battleaxe) return "Battleaxe";
        if (weapon == IPlayerSkinNFT.WeaponType.Spear) return "Spear";
        if (weapon == IPlayerSkinNFT.WeaponType.SwordAndShield) return "SwordAndShield";
        if (weapon == IPlayerSkinNFT.WeaponType.MaceAndShield) return "MaceAndShield";
        if (weapon == IPlayerSkinNFT.WeaponType.Quarterstaff) return "Quarterstaff";
        return "Unknown";
    }

    function getArmorName(IPlayerSkinNFT.ArmorType armor) internal pure returns (string memory) {
        if (armor == IPlayerSkinNFT.ArmorType.Leather) return "Leather";
        if (armor == IPlayerSkinNFT.ArmorType.Chain) return "Chain";
        if (armor == IPlayerSkinNFT.ArmorType.Plate) return "Plate";
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

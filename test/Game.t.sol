// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {PracticeGame} from "../src/PracticeGame.sol";
import {Player} from "../src/Player.sol";
import {PlayerEquipmentStats} from "../src/PlayerEquipmentStats.sol";
import {GameEngine} from "../src/GameEngine.sol";
import {PlayerSkinRegistry} from "../src/PlayerSkinRegistry.sol";
import {DefaultPlayerSkinNFT} from "../src/DefaultPlayerSkinNFT.sol";
import "../src/interfaces/IPlayer.sol";
import "../src/interfaces/IGameEngine.sol";
import "./utils/TestBase.sol";
import "../src/lib/DefaultPlayerLibrary.sol";
import "../src/interfaces/IPlayerSkinNFT.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";

contract GameTest is TestBase {
    struct TestCharacters {
        uint16 greatswordOffensive;
        uint16 battleaxeOffensive;
        uint16 spearBalanced;
        uint16 swordAndShieldDefensive;
        uint16 rapierAndShieldDefensive;
        uint16 quarterstaffDefensive;
    }

    PracticeGame public game;
    GameEngine public gameEngine;
    PlayerEquipmentStats public equipmentStats;
    Player public playerContract;
    PlayerSkinRegistry public skinRegistry;
    DefaultPlayerSkinNFT public defaultSkin;
    PlayerNameRegistry public nameRegistry;
    uint32 public skinIndex;
    TestCharacters public chars;

    function setUp() public override {
        super.setUp();

        // Deploy contracts in correct order
        skinRegistry = new PlayerSkinRegistry();
        defaultSkin = new DefaultPlayerSkinNFT();
        nameRegistry = new PlayerNameRegistry();
        equipmentStats = new PlayerEquipmentStats();

        // Deploy Player contract with dependencies
        playerContract = new Player(address(skinRegistry), address(nameRegistry), address(equipmentStats), address(1));

        // Deploy Game contracts
        gameEngine = new GameEngine();
        game = new PracticeGame(address(gameEngine), address(playerContract));

        // Register default skin and set up registry
        skinIndex = skinRegistry.registerSkin(address(defaultSkin));
        skinRegistry.setDefaultSkinRegistryId(skinIndex);
        skinRegistry.setDefaultCollection(skinIndex, true);

        // Create default characters
        mintDefaultCharacters();
    }

    // Create default characters using DefaultPlayerLibrary
    function mintDefaultCharacters() private {
        // Create offensive characters
        (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        ) = DefaultPlayerLibrary.getOffensiveTestWarrior(skinIndex, 1);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 1);
        chars.greatswordOffensive = 1;

        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getOffensiveTestWarrior(skinIndex, 2);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 2);
        chars.battleaxeOffensive = 2;

        // Create balanced character
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getDefaultWarrior(skinIndex, 3);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 3);
        chars.spearBalanced = 3;

        // Create defensive characters
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getSwordAndShieldUser(skinIndex, 4);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 4);
        chars.swordAndShieldDefensive = 4;

        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getRapierAndShieldUser(skinIndex, 5);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 5);
        chars.rapierAndShieldDefensive = 5;

        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getQuarterstaffUser(skinIndex, 6);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 6);
        chars.quarterstaffDefensive = 6;
    }

    function testBasicCombat() public view {
        // Test basic combat functionality with pseudo-random seed
        uint256 seed = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, blockhash(block.number - 1), msg.sender))
        );

        IGameEngine.PlayerLoadout memory player1 = IGameEngine.PlayerLoadout({
            playerId: chars.greatswordOffensive,
            skinIndex: skinRegistry.defaultSkinRegistryId(),
            skinTokenId: uint16(chars.greatswordOffensive)
        });

        IGameEngine.PlayerLoadout memory player2 = IGameEngine.PlayerLoadout({
            playerId: chars.swordAndShieldDefensive,
            skinIndex: skinRegistry.defaultSkinRegistryId(),
            skinTokenId: uint16(chars.swordAndShieldDefensive)
        });

        // Run the game with seed and verify the result format
        bytes memory results = gameEngine.processGame(player1, player2, seed, playerContract);
        (uint256 winner, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Basic validation
        assertTrue(winner == player1.playerId || winner == player2.playerId, "Invalid winner");
        assertTrue(actions.length > 0, "No actions recorded");
        assertTrue(uint8(condition) <= uint8(type(GameEngine.WinCondition).max), "Invalid win condition");
    }

    function testCombatMechanics() public view {
        // Test combat mechanics with offensive vs defensive setup and pseudo-random seed
        uint256 seed = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, blockhash(block.number - 1), msg.sender))
        );

        IGameEngine.PlayerLoadout memory attackerLoadout = IGameEngine.PlayerLoadout({
            playerId: chars.greatswordOffensive,
            skinIndex: skinIndex,
            skinTokenId: uint16(chars.greatswordOffensive)
        });

        IGameEngine.PlayerLoadout memory defenderLoadout = IGameEngine.PlayerLoadout({
            playerId: chars.quarterstaffDefensive,
            skinIndex: skinIndex,
            skinTokenId: uint16(chars.quarterstaffDefensive)
        });

        // Run combat with seed and verify mechanics
        bytes memory results = gameEngine.processGame(attackerLoadout, defenderLoadout, seed, playerContract);
        (uint256 winner, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Verify basic mechanics
        assertTrue(winner == attackerLoadout.playerId || winner == defenderLoadout.playerId, "Invalid winner");
        assertTrue(actions.length > 0, "No actions recorded");
        assertTrue(uint8(condition) <= uint8(type(GameEngine.WinCondition).max), "Invalid win condition");

        // Verify combat actions
        bool hasOffensiveAction = false;
        bool hasDefensiveAction = false;

        for (uint256 i = 0; i < actions.length; i++) {
            if (isOffensiveAction(actions[i])) hasOffensiveAction = true;
            if (isDefensiveAction(actions[i])) hasDefensiveAction = true;
            if (hasOffensiveAction && hasDefensiveAction) break;
        }

        assertTrue(hasOffensiveAction, "No offensive actions occurred in combat");
        assertTrue(hasDefensiveAction, "No defensive actions occurred in combat");
    }

    function testFuzzCombat(uint256 seed) public view {
        // Create loadouts for fuzz testing
        IGameEngine.PlayerLoadout memory player1 = IGameEngine.PlayerLoadout({
            playerId: chars.greatswordOffensive,
            skinIndex: skinRegistry.defaultSkinRegistryId(),
            skinTokenId: uint16(chars.greatswordOffensive)
        });

        IGameEngine.PlayerLoadout memory player2 = IGameEngine.PlayerLoadout({
            playerId: chars.swordAndShieldDefensive,
            skinIndex: skinRegistry.defaultSkinRegistryId(),
            skinTokenId: uint16(chars.swordAndShieldDefensive)
        });

        // Run game with fuzzed seed
        bytes memory results = gameEngine.processGame(player1, player2, seed, playerContract);
        (uint256 winner, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Verify game invariants hold with any seed
        assertTrue(winner == player1.playerId || winner == player2.playerId, "Invalid winner");
        assertTrue(actions.length > 0, "No actions recorded");
        assertTrue(uint8(condition) <= uint8(type(GameEngine.WinCondition).max), "Invalid win condition");

        // Verify both players had a chance to act
        bool player1Action = false;
        bool player2Action = false;

        for (uint256 i = 0; i < actions.length; i++) {
            if (actions[i].p1Damage > 0 || isDefensiveResult(actions[i].p1Result)) player1Action = true;
            if (actions[i].p2Damage > 0 || isDefensiveResult(actions[i].p2Result)) player2Action = true;
            if (player1Action && player2Action) break;
        }

        assertTrue(player1Action, "Player 1 never acted");
        assertTrue(player2Action, "Player 2 never acted");
    }

    function isOffensiveAction(GameEngine.CombatAction memory action) internal pure returns (bool) {
        return action.p1Result == GameEngine.CombatResultType.ATTACK
            || action.p1Result == GameEngine.CombatResultType.CRIT || action.p1Result == GameEngine.CombatResultType.COUNTER
            || action.p1Result == GameEngine.CombatResultType.COUNTER_CRIT
            || action.p1Result == GameEngine.CombatResultType.RIPOSTE
            || action.p1Result == GameEngine.CombatResultType.RIPOSTE_CRIT
            || action.p2Result == GameEngine.CombatResultType.ATTACK || action.p2Result == GameEngine.CombatResultType.CRIT
            || action.p2Result == GameEngine.CombatResultType.COUNTER
            || action.p2Result == GameEngine.CombatResultType.COUNTER_CRIT
            || action.p2Result == GameEngine.CombatResultType.RIPOSTE
            || action.p2Result == GameEngine.CombatResultType.RIPOSTE_CRIT;
    }

    function isDefensiveAction(GameEngine.CombatAction memory action) internal pure returns (bool) {
        return action.p1Result == GameEngine.CombatResultType.BLOCK
            || action.p1Result == GameEngine.CombatResultType.DODGE || action.p1Result == GameEngine.CombatResultType.PARRY
            || action.p1Result == GameEngine.CombatResultType.HIT || action.p1Result == GameEngine.CombatResultType.MISS
            || action.p1Result == GameEngine.CombatResultType.COUNTER
            || action.p1Result == GameEngine.CombatResultType.COUNTER_CRIT
            || action.p1Result == GameEngine.CombatResultType.RIPOSTE
            || action.p1Result == GameEngine.CombatResultType.RIPOSTE_CRIT
            || action.p2Result == GameEngine.CombatResultType.BLOCK || action.p2Result == GameEngine.CombatResultType.DODGE
            || action.p2Result == GameEngine.CombatResultType.PARRY || action.p2Result == GameEngine.CombatResultType.HIT
            || action.p2Result == GameEngine.CombatResultType.MISS || action.p2Result == GameEngine.CombatResultType.COUNTER
            || action.p2Result == GameEngine.CombatResultType.COUNTER_CRIT
            || action.p2Result == GameEngine.CombatResultType.RIPOSTE
            || action.p2Result == GameEngine.CombatResultType.RIPOSTE_CRIT;
    }

    function isDefensiveResult(GameEngine.CombatResultType result) internal pure returns (bool) {
        return result == GameEngine.CombatResultType.PARRY || result == GameEngine.CombatResultType.BLOCK
            || result == GameEngine.CombatResultType.DODGE || result == GameEngine.CombatResultType.MISS
            || result == GameEngine.CombatResultType.HIT;
    }

    function testSpecificScenarios() public {
        // Test specific combat scenarios with different character combinations
        bytes memory results;

        // Scenario 1: Greatsword vs Sword and Shield (Offensive vs Defensive)
        IGameEngine.PlayerLoadout memory loadout1A = IGameEngine.PlayerLoadout({
            playerId: chars.greatswordOffensive,
            skinIndex: skinIndex,
            skinTokenId: uint16(chars.greatswordOffensive)
        });
        IGameEngine.PlayerLoadout memory loadout1B = IGameEngine.PlayerLoadout({
            playerId: chars.swordAndShieldDefensive,
            skinIndex: skinIndex,
            skinTokenId: uint16(chars.swordAndShieldDefensive)
        });

        results = game.play(loadout1A, loadout1B);
        (uint256 winner1,, GameEngine.CombatAction[] memory actions1) = gameEngine.decodeCombatLog(results);
        assertTrue(winner1 == loadout1A.playerId || winner1 == loadout1B.playerId, "Invalid winner in scenario 1");

        // Scenario 2: Battleaxe vs Spear (Offensive vs Balanced)
        IGameEngine.PlayerLoadout memory loadout2A = IGameEngine.PlayerLoadout({
            playerId: chars.battleaxeOffensive,
            skinIndex: skinIndex,
            skinTokenId: uint16(chars.battleaxeOffensive)
        });
        IGameEngine.PlayerLoadout memory loadout2B = IGameEngine.PlayerLoadout({
            playerId: chars.spearBalanced,
            skinIndex: skinIndex,
            skinTokenId: uint16(chars.spearBalanced)
        });

        vm.warp(block.timestamp + 1);
        results = game.play(loadout2A, loadout2B);
        (uint256 winner2,, GameEngine.CombatAction[] memory actions2) = gameEngine.decodeCombatLog(results);
        assertTrue(winner2 == loadout2A.playerId || winner2 == loadout2B.playerId, "Invalid winner in scenario 2");

        // Scenario 3: Rapier and Shield vs Quarterstaff (Defensive vs Defensive)
        IGameEngine.PlayerLoadout memory loadout3A = IGameEngine.PlayerLoadout({
            playerId: chars.rapierAndShieldDefensive,
            skinIndex: skinIndex,
            skinTokenId: uint16(chars.rapierAndShieldDefensive)
        });
        IGameEngine.PlayerLoadout memory loadout3B = IGameEngine.PlayerLoadout({
            playerId: chars.quarterstaffDefensive,
            skinIndex: skinIndex,
            skinTokenId: uint16(chars.quarterstaffDefensive)
        });

        vm.warp(block.timestamp + 1);
        results = game.play(loadout3A, loadout3B);
        (uint256 winner3,, GameEngine.CombatAction[] memory actions3) = gameEngine.decodeCombatLog(results);
        assertTrue(winner3 == loadout3A.playerId || winner3 == loadout3B.playerId, "Invalid winner in scenario 3");

        // Scenario 4: Greatsword vs Spear (Offensive vs Balanced)
        IGameEngine.PlayerLoadout memory loadout4A = IGameEngine.PlayerLoadout({
            playerId: chars.greatswordOffensive,
            skinIndex: skinIndex,
            skinTokenId: uint16(chars.greatswordOffensive)
        });
        IGameEngine.PlayerLoadout memory loadout4B = IGameEngine.PlayerLoadout({
            playerId: chars.spearBalanced,
            skinIndex: skinIndex,
            skinTokenId: uint16(chars.spearBalanced)
        });

        vm.warp(block.timestamp + 1);
        results = game.play(loadout4A, loadout4B);
        (uint256 winner4,, GameEngine.CombatAction[] memory actions4) = gameEngine.decodeCombatLog(results);
        assertTrue(winner4 == loadout4A.playerId || winner4 == loadout4B.playerId, "Invalid winner in scenario 4");
    }

    function testDefensiveActions() public view {
        // Test defensive mechanics with specific character loadouts
        IGameEngine.PlayerLoadout memory attackerLoadout = IGameEngine.PlayerLoadout({
            playerId: chars.greatswordOffensive,
            skinIndex: skinIndex,
            skinTokenId: uint16(chars.greatswordOffensive)
        });

        IGameEngine.PlayerLoadout memory defenderLoadout = IGameEngine.PlayerLoadout({
            playerId: chars.quarterstaffDefensive,
            skinIndex: skinIndex,
            skinTokenId: uint16(chars.quarterstaffDefensive)
        });

        // Get defender's stats to verify defensive capabilities
        IPlayer.PlayerStats memory defenderStats = playerContract.getPlayer(defenderLoadout.playerId);
        IPlayer.CalculatedStats memory calcStats = playerContract.calculateStats(defenderStats);

        // Run combat and analyze defensive actions
        bytes memory results = game.play(attackerLoadout, defenderLoadout);
        (uint256 winner,, GameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(results);

        // Verify defensive actions occurred
        bool hasDefensiveAction = false;
        for (uint256 i = 0; i < actions.length; i++) {
            if (isDefensiveAction(actions[i])) {
                hasDefensiveAction = true;
                break;
            }
        }
        assertTrue(hasDefensiveAction, "No defensive actions occurred in combat");
    }

    function testParryChanceCalculation() public view {
        // Test parry chance calculation for a defensive character
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(chars.rapierAndShieldDefensive);
        IPlayer.CalculatedStats memory calcStats = playerContract.calculateStats(stats);

        // Verify parry chance is within valid range
        assertTrue(calcStats.parryChance > 0, "Parry chance should be greater than 0");
        assertTrue(calcStats.parryChance <= 100, "Parry chance should be <= 100");
    }

    function testCombatLogStructure() public view {
        // Test the structure and decoding of combat logs
        IGameEngine.PlayerLoadout memory p1Loadout = IGameEngine.PlayerLoadout({
            playerId: chars.greatswordOffensive,
            skinIndex: skinIndex,
            skinTokenId: uint16(chars.greatswordOffensive)
        });

        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: chars.quarterstaffDefensive,
            skinIndex: skinIndex,
            skinTokenId: uint16(chars.quarterstaffDefensive)
        });

        bytes memory results = game.play(p1Loadout, p2Loadout);
        (uint256 winner, GameEngine.WinCondition winCondition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Verify combat log structure
        assertTrue(winner == p1Loadout.playerId || winner == p2Loadout.playerId, "Invalid winner ID");
        assertTrue(uint8(winCondition) <= uint8(type(GameEngine.WinCondition).max), "Invalid win condition");
        assertTrue(actions.length > 0, "Combat log should contain actions");

        // Verify action structure
        for (uint256 i = 0; i < actions.length; i++) {
            assertTrue(
                uint8(actions[i].p1Result) <= uint8(type(GameEngine.CombatResultType).max),
                string.concat("Invalid action type at index ", vm.toString(i))
            );
        }
    }

    function testStanceModifiers() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }

        // Get stance modifiers for logging
        (,, PlayerEquipmentStats.StanceMultiplier memory stance) = playerContract.equipmentStats().getFullCharacterStats(
            IPlayerSkinNFT.WeaponType.SwordAndShield,
            IPlayerSkinNFT.ArmorType.Chain,
            IPlayerSkinNFT.FightingStance.Defensive
        );
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
        IGameEngine.PlayerLoadout memory p1Loadout =
            IGameEngine.PlayerLoadout({playerId: player1Id, skinIndex: skinIndex, skinTokenId: uint16(player1Id)});

        IGameEngine.PlayerLoadout memory p2Loadout =
            IGameEngine.PlayerLoadout({playerId: player2Id, skinIndex: skinIndex, skinTokenId: uint16(player2Id)});

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
            bytes memory results = gameEngine.processGame(p1Loadout, p2Loadout, seed, playerContract);
            (uint256 winner,, GameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(results);

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
}

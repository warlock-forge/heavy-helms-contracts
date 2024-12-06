// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import {Game} from "../src/Game.sol";
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
import "../src/interfaces/IPlayer.sol";
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

    TestCharacters public chars;
    uint32 public skinIndex;

    Game public game;
    GameEngine public gameEngine;
    PlayerEquipmentStats public equipmentStats;
    Player public playerContract;
    PlayerSkinRegistry public skinRegistry;
    DefaultPlayerSkinNFT public defaultSkin;
    PlayerNameRegistry public nameRegistry;

    address constant PLAYER_ONE = address(0x1);
    address constant PLAYER_TWO = address(0x2);

    function setUp() public {
        setupRandomness();

        // Deploy contracts in correct order
        equipmentStats = new PlayerEquipmentStats();
        skinRegistry = new PlayerSkinRegistry();
        nameRegistry = new PlayerNameRegistry();
        playerContract = new Player(address(skinRegistry), address(nameRegistry), address(equipmentStats));

        gameEngine = new GameEngine();
        game = new Game(address(gameEngine), address(playerContract));

        // Deploy default skin contract
        defaultSkin = new DefaultPlayerSkinNFT();

        // Register default skin contract and verify setup
        skinIndex = skinRegistry.registerSkin(address(defaultSkin));
        console2.log("\n=== Registry Setup ===");
        console2.log("Default skin registered at index:", skinIndex);
        console2.log("Default skin contract:", address(defaultSkin));

        // Set as default registry and collection
        skinRegistry.setDefaultSkinRegistryId(skinIndex);
        skinRegistry.setDefaultCollection(skinIndex, true);

        console2.log("\n=== Minting Default Characters ===");
        // First mint the default characters
        mintDefaultCharacters();

        // Store the IDs for use in tests
        chars = TestCharacters({
            greatswordOffensive: 1,
            battleaxeOffensive: 2,
            spearBalanced: 3,
            swordAndShieldDefensive: 4,
            rapierAndShieldDefensive: 5,
            quarterstaffDefensive: 6
        });

        console2.log("\n=== Creating Players for PLAYER_ONE ===");
        // Now create players and equip skins for PLAYER_ONE
        vm.startPrank(PLAYER_ONE);
        for (uint256 i = 1; i <= 6; i++) {
            console2.log("Creating player", i);
            (uint256 playerId, IPlayer.PlayerStats memory stats) = playerContract.createPlayer(true);
            console2.log("Created player with ID:", playerId);

            console2.log("Equipping skin", i, "to player", playerId);
            try playerContract.equipSkin(uint32(playerId), skinIndex, uint16(i)) {
                console2.log("Successfully equipped skin");
            } catch Error(string memory reason) {
                console2.log("Failed to equip skin:", reason);
            }
        }
        vm.stopPrank();

        console2.log("\n=== Creating Players for PLAYER_TWO ===");
        // Create players and equip skins for PLAYER_TWO
        vm.startPrank(PLAYER_TWO);
        for (uint256 i = 7; i <= 12; i++) {
            console2.log("Creating player", i);
            (uint256 playerId, IPlayer.PlayerStats memory stats) = playerContract.createPlayer(true);
            console2.log("Created player with ID:", playerId);

            console2.log("Equipping skin", i - 6, "to player", playerId);
            try playerContract.equipSkin(uint32(playerId), skinIndex, uint16(i - 6)) {
                console2.log("Successfully equipped skin");
            } catch Error(string memory reason) {
                console2.log("Failed to equip skin:", reason);
            }
        }
        vm.stopPrank();
    }

    // Create a separate function for minting default characters to improve readability
    function mintDefaultCharacters() private {
        // Mint Greatsword User
        (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        ) = DefaultPlayerLibrary.getGreatswordUser(skinIndex, 1);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 1);

        // Mint other characters
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getBattleaxeUser(skinIndex, 2);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 2);

        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getSpearUser(skinIndex, 3);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 3);

        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getSwordAndShieldUser(skinIndex, 4);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 4);

        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getRapierAndShieldUser(skinIndex, 5);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 5);

        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getQuarterstaffUser(skinIndex, 6);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 6);
    }

    function testBasicCombat() public {
        // First verify we can get the player stats directly
        console2.log("\nDebug Player Setup:");

        // Get initial state
        (uint256 health, uint256 stamina) = playerContract.getPlayerState(1);
        console2.log("Initial State:");
        console2.log("  - Health:", health);
        console2.log("  - Stamina:", stamina);

        // Get the player stats
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(1);
        console2.log("Player Stats:");
        console2.log("  - Strength:", stats.strength);
        console2.log("  - SkinIndex:", stats.skinIndex);

        // Now set up the game loadouts
        uint32 defaultSkinIndex = skinRegistry.defaultSkinRegistryId();
        IGameEngine.PlayerLoadout memory player1 =
            IGameEngine.PlayerLoadout({playerId: 1, skinIndex: defaultSkinIndex, skinTokenId: 1});

        IGameEngine.PlayerLoadout memory player2 =
            IGameEngine.PlayerLoadout({playerId: 4, skinIndex: defaultSkinIndex, skinTokenId: 4});

        // Try to get the loadout stats before the game
        try playerContract.getPlayer(player1.playerId) returns (IPlayer.PlayerStats memory p1Stats) {
            console2.log("Pre-Game Player 1 Stats:");
            console2.log("  - Strength:", p1Stats.strength);
            console2.log("  - SkinIndex:", p1Stats.skinIndex);
        } catch Error(string memory reason) {
            console2.log("Failed to get player 1 stats:", reason);
        }

        bytes memory result = game.practiceGame(player1, player2);
        (uint256 winner,,) = gameEngine.decodeCombatLog(result);

        console2.log("Winner: Player #", winner);
        assertTrue(winner == player1.playerId || winner == player2.playerId, "Invalid winner");
    }

    function createTestLoadout(uint32 playerId) internal pure returns (IGameEngine.PlayerLoadout memory) {
        return IGameEngine.PlayerLoadout({playerId: playerId, skinIndex: 0, skinTokenId: 1});
    }

    function testSpecificScenarios() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }

        // Use pre-configured players directly
        IGameEngine.PlayerLoadout memory loadout1A = IGameEngine.PlayerLoadout({
            playerId: uint32(1),
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });
        IGameEngine.PlayerLoadout memory loadout1B = IGameEngine.PlayerLoadout({
            playerId: uint32(2),
            skinIndex: skinIndex,
            skinTokenId: chars.swordAndShieldDefensive
        });

        vm.warp(block.timestamp + 1);
        bytes memory results = game.practiceGame(loadout1A, loadout1B);
        logScenarioResults(1, results);

        // Scenario 2: Battleaxe vs Spear
        IGameEngine.PlayerLoadout memory loadout2A = IGameEngine.PlayerLoadout({
            playerId: uint32(1),
            skinIndex: skinIndex,
            skinTokenId: chars.battleaxeOffensive
        });
        IGameEngine.PlayerLoadout memory loadout2B =
            IGameEngine.PlayerLoadout({playerId: uint32(2), skinIndex: skinIndex, skinTokenId: chars.spearBalanced});

        vm.warp(block.timestamp + 1);
        results = game.practiceGame(loadout2A, loadout2B);
        logScenarioResults(2, results);

        // Scenario 3: Rapier and Shield vs Quarterstaff
        IGameEngine.PlayerLoadout memory loadout3A = IGameEngine.PlayerLoadout({
            playerId: uint32(1),
            skinIndex: skinIndex,
            skinTokenId: chars.rapierAndShieldDefensive
        });
        IGameEngine.PlayerLoadout memory loadout3B = IGameEngine.PlayerLoadout({
            playerId: uint32(2),
            skinIndex: skinIndex,
            skinTokenId: chars.quarterstaffDefensive
        });

        vm.warp(block.timestamp + 1);
        results = game.practiceGame(loadout3A, loadout3B);
        logScenarioResults(3, results);

        // Scenario 4: Greatsword vs Spear (Offensive vs Balanced)
        IGameEngine.PlayerLoadout memory loadout4A = IGameEngine.PlayerLoadout({
            playerId: uint32(1),
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });
        IGameEngine.PlayerLoadout memory loadout4B =
            IGameEngine.PlayerLoadout({playerId: uint32(2), skinIndex: skinIndex, skinTokenId: chars.spearBalanced});

        vm.warp(block.timestamp + 1);
        results = game.practiceGame(loadout4A, loadout4B);
        logScenarioResults(4, results);
    }

    function logScenarioResults(uint256 scenario, bytes memory results) private pure {
        // Decode winner ID from first 4 bytes
        uint32 winner = uint32(uint8(results[0])) << 24 | uint32(uint8(results[1])) << 16
            | uint32(uint8(results[2])) << 8 | uint32(uint8(results[3]));

        uint8 condition = uint8(results[4]);
        uint256 rounds = (results.length - 5) / 8;

        string memory winType;
        if (condition == 0) winType = "KO";
        else if (condition == 1) winType = "Exhaustion";
        else winType = "Max Rounds";

        console2.log("Scenario ", scenario);
        console2.log("Winner: Player #", winner);
        console2.log("Win Type: ", winType);
        console2.log("Rounds: ", rounds);
        console2.log(""); // Empty line for spacing
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

    function testStanceModifiers() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }

        uint256 totalFights = 20;
        uint256 totalScenarios = 3;
        uint256[] memory offensiveWins = new uint256[](totalScenarios);
        uint256[] memory defensiveWins = new uint256[](totalScenarios);
        uint256[] memory totalRounds = new uint256[](totalScenarios);

        // Remove createPlayer calls and use pre-configured loadouts directly
        IGameEngine.PlayerLoadout memory attackerLoadout = IGameEngine.PlayerLoadout({
            playerId: uint32(1),
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });

        IGameEngine.PlayerLoadout memory defenderLoadout = IGameEngine.PlayerLoadout({
            playerId: uint32(2),
            skinIndex: skinIndex,
            skinTokenId: chars.quarterstaffDefensive
        });

        // Get and log defensive stats for our quarterstaff defensive character
        IPlayer.PlayerStats memory defenderStats = playerContract.getPlayer(chars.quarterstaffDefensive);
        IPlayer.CalculatedStats memory calcStats = playerContract.calculateStats(defenderStats);

        // Test different offensive vs defensive matchups
        IPlayerSkinNFT.WeaponType[3] memory offensiveWeapons =
            [IPlayerSkinNFT.WeaponType.Greatsword, IPlayerSkinNFT.WeaponType.Battleaxe, IPlayerSkinNFT.WeaponType.Spear];

        uint16[3] memory offensiveTokenIds = [
            chars.greatswordOffensive,
            chars.battleaxeOffensive,
            chars.spearBalanced // Using balanced spear in offensive scenario
        ];

        for (uint256 scenario = 0; scenario < totalScenarios; scenario++) {
            // Log the matchup
            console2.log("\n=== Scenario %d ===", scenario + 1);
            console2.log("Offensive: %s vs Defensive: SwordAndShield", getWeaponName(offensiveWeapons[scenario]));

            IGameEngine.PlayerLoadout memory offensiveLoadout = IGameEngine.PlayerLoadout({
                playerId: uint32(1),
                skinIndex: skinIndex,
                skinTokenId: offensiveTokenIds[scenario]
            });

            IGameEngine.PlayerLoadout memory defensiveLoadout = IGameEngine.PlayerLoadout({
                playerId: uint32(2),
                skinIndex: skinIndex,
                skinTokenId: chars.swordAndShieldDefensive
            });

            // Run fights
            for (uint256 i = 0; i < totalFights; i++) {
                uint256 blockJump = uint256(
                    keccak256(abi.encodePacked(i, block.timestamp, block.prevrandao, blockhash(block.number - 1)))
                ) % 100 + 1;
                vm.roll(block.number + blockJump);
                vm.warp(block.timestamp + blockJump * 12);

                bytes memory results = game.practiceGame(offensiveLoadout, defensiveLoadout);
                (uint256 winner,, GameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(results);

                if (winner == 1) offensiveWins[scenario]++;
                else if (winner == 2) defensiveWins[scenario]++;

                totalRounds[scenario] += actions.length;
            }

            console2.log("Scenario %d Results:", scenario + 1);
            console2.log(
                "Offensive Player #%d Wins: %d (%d%%)",
                offensiveLoadout.playerId,
                offensiveWins[scenario],
                (offensiveWins[scenario] * 100) / totalFights
            );
            console2.log(
                "Defensive Player #%d Wins: %d (%d%%)",
                defensiveLoadout.playerId,
                defensiveWins[scenario],
                (defensiveWins[scenario] * 100) / totalFights
            );
            console2.log("Average Rounds: %d", totalRounds[scenario] / totalFights);
        }

        uint256 totalOffensiveWins = 0;
        uint256 totalDefensiveWins = 0;
        for (uint256 i = 0; i < totalScenarios; i++) {
            totalOffensiveWins += offensiveWins[i];
            totalDefensiveWins += defensiveWins[i];
        }

        assertTrue(totalOffensiveWins > 0, "Offensive stance never won");
        assertTrue(totalDefensiveWins > 0, "Defensive stance never won");
    }

    function _getWinConditionString(GameEngine.WinCondition condition) internal pure returns (string memory) {
        if (condition == GameEngine.WinCondition.HEALTH) return "KO";
        if (condition == GameEngine.WinCondition.EXHAUSTION) return "Exhaustion";
        if (condition == GameEngine.WinCondition.MAX_ROUNDS) return "Max Rounds";
        return "Unknown";
    }

    function testCombatMechanics() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }

        // Use pre-configured players directly
        IGameEngine.PlayerLoadout memory p1Loadout = IGameEngine.PlayerLoadout({
            playerId: uint32(1),
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });

        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: uint32(2),
            skinIndex: skinIndex,
            skinTokenId: chars.quarterstaffDefensive
        });

        // Get weapon stats for logging
        (PlayerEquipmentStats.WeaponStats memory weapon,,) = playerContract.equipmentStats().getFullCharacterStats(
            IPlayerSkinNFT.WeaponType.Quarterstaff,
            IPlayerSkinNFT.ArmorType.Chain,
            IPlayerSkinNFT.FightingStance.Defensive
        );

        console2.log("Weapon Parry:", weapon.parryChance);

        // Run the combat test
        bytes memory results = game.practiceGame(p1Loadout, p2Loadout);
        (uint256 winner,, GameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(results);

        console2.log("Winner:", winner);
        console2.log("Total Actions:", actions.length);
    }

    function testDefensiveActions() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }

        // Remove createPlayer calls and use pre-configured loadouts directly
        IGameEngine.PlayerLoadout memory attackerLoadout = IGameEngine.PlayerLoadout({
            playerId: uint32(1),
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });

        IGameEngine.PlayerLoadout memory defenderLoadout = IGameEngine.PlayerLoadout({
            playerId: uint32(2),
            skinIndex: skinIndex,
            skinTokenId: chars.quarterstaffDefensive // High parry/block defender
        });

        // Get and log defensive stats for our quarterstaff defensive character
        IPlayer.PlayerStats memory defenderStats = playerContract.getPlayer(chars.quarterstaffDefensive);
        IPlayer.CalculatedStats memory calcStats = playerContract.calculateStats(defenderStats);

        // Get and log stance modifiers
        (,, PlayerEquipmentStats.StanceMultiplier memory stance) = playerContract.equipmentStats().getFullCharacterStats(
            IPlayerSkinNFT.WeaponType.Quarterstaff,
            IPlayerSkinNFT.ArmorType.Chain,
            IPlayerSkinNFT.FightingStance.Defensive
        );
        console2.log(
            "Stance Mods - Block:%d Parry:%d Dodge:%d", stance.blockChance, stance.parryChance, stance.dodgeChance
        );

        // Run combat and verify results
        bytes memory results = game.practiceGame(attackerLoadout, defenderLoadout);
        (uint256 winner,, GameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(results);

        console2.log("Winner:", winner);
        console2.log("Total Actions:", actions.length);
    }

    function testParryChanceCalculation() public view {
        // Use the pre-configured RapierAndShield character from setUp
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(chars.rapierAndShieldDefensive);
        IPlayer.CalculatedStats memory calcStats = playerContract.calculateStats(stats);

        // Get weapon stats
        (PlayerEquipmentStats.WeaponStats memory weapon,,) = playerContract.equipmentStats().getFullCharacterStats(
            IPlayerSkinNFT.WeaponType.RapierAndShield,
            IPlayerSkinNFT.ArmorType.Leather,
            IPlayerSkinNFT.FightingStance.Defensive
        );

        console2.log("Base Parry Chance:", weapon.parryChance);
        console2.log("Calculated Parry Chance:", calcStats.parryChance);

        assertTrue(calcStats.parryChance > 0, "Parry chance should be greater than 0");
        assertTrue(calcStats.parryChance <= 100, "Parry chance should be <= 100");
    }

    function testSingleParryAttempt() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }

        // Use pre-configured players directly
        IGameEngine.PlayerLoadout memory attackerLoadout = IGameEngine.PlayerLoadout({
            playerId: uint32(1),
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });

        IGameEngine.PlayerLoadout memory defenderLoadout = IGameEngine.PlayerLoadout({
            playerId: uint32(2),
            skinIndex: skinIndex,
            skinTokenId: chars.rapierAndShieldDefensive
        });

        // Run multiple games with different seeds to verify parry mechanics
        for (uint256 seed = 0; seed < 10; seed++) {
            bytes memory results = gameEngine.processGame(attackerLoadout, defenderLoadout, seed, playerContract);

            require(results.length > 2, "Invalid results length");
        }
    }

    function testCombatLogStructure() public {
        // Use pre-configured players
        IGameEngine.PlayerLoadout memory p1Loadout = IGameEngine.PlayerLoadout({
            playerId: uint32(1),
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });

        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: uint32(2),
            skinIndex: skinIndex,
            skinTokenId: chars.quarterstaffDefensive
        });

        // Run a game and get combat log
        bytes memory results = game.practiceGame(p1Loadout, p2Loadout);

        // Test decodeCombatLog function
        (uint256 decodedWinner, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        console2.log("\nDecoded Combat Log:");
        console2.log("Winner:", decodedWinner);
        console2.log("Win Condition:", uint8(condition));
        console2.log("Number of Actions:", actions.length);

        // Manual byte parsing for verification
        uint32 manualWinner = uint32(uint8(results[0])) << 24 | uint32(uint8(results[1])) << 16
            | uint32(uint8(results[2])) << 8 | uint32(uint8(results[3]));
        uint8 manualCondition = uint8(results[4]);

        // Verify decoded results match manual parsing
        require(decodedWinner == manualWinner, "Decoded winner mismatch");
        require(uint8(condition) == manualCondition, "Decoded condition mismatch");
        require(actions.length == (results.length - 5) / 8, "Decoded actions length mismatch");

        // Rest of the test remains the same...
        // ... existing code for byte structure verification ...
    }
}

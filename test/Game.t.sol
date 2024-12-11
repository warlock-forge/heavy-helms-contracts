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
    address operator;

    address constant PLAYER_ONE = address(0x1);
    address constant PLAYER_TWO = address(0x2);
    uint256 constant ROUND_ID = 1;

    event RequestedRandomness(uint256 round, bytes data);

    function setUp() public {
        // Set operator address
        operator = address(1);

        // Deploy contracts in correct order
        skinRegistry = new PlayerSkinRegistry();
        defaultSkin = new DefaultPlayerSkinNFT();
        nameRegistry = new PlayerNameRegistry();
        equipmentStats = new PlayerEquipmentStats();

        // Deploy Player contract with dependencies
        playerContract = new Player(address(skinRegistry), address(nameRegistry), address(equipmentStats), operator);

        // Deploy Game contracts
        gameEngine = new GameEngine();
        game = new Game(address(gameEngine), address(playerContract));

        // Register default skin and set up registry
        skinIndex = skinRegistry.registerSkin(address(defaultSkin));
        skinRegistry.setDefaultSkinRegistryId(skinIndex);
        skinRegistry.setDefaultCollection(skinIndex, true);
    }

    // Create a separate function for minting default characters to improve readability
    function mintDefaultCharacters() private {
        // Mint Greatsword User
        vm.startPrank(PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer(true);
        uint256 randomness = uint256(keccak256(abi.encodePacked("greatsword")));
        bytes memory extraData = "";
        bytes memory dataWithRound = abi.encode(ROUND_ID, abi.encode(requestId, extraData));
        vm.stopPrank();
        vm.prank(operator);
        playerContract.fulfillRandomness(randomness, dataWithRound);
        chars.greatswordOffensive = uint16(1000);

        // Mint Battleaxe User
        vm.prank(PLAYER_ONE);
        requestId = playerContract.requestCreatePlayer(true);
        randomness = uint256(keccak256(abi.encodePacked("battleaxe")));
        dataWithRound = abi.encode(ROUND_ID, abi.encode(requestId, extraData));
        vm.stopPrank();
        vm.prank(operator);
        playerContract.fulfillRandomness(randomness, dataWithRound);
        chars.battleaxeOffensive = uint16(1001);

        // Mint Spear User
        vm.prank(PLAYER_ONE);
        requestId = playerContract.requestCreatePlayer(true);
        randomness = uint256(keccak256(abi.encodePacked("spear")));
        dataWithRound = abi.encode(ROUND_ID, abi.encode(requestId, extraData));
        vm.stopPrank();
        vm.prank(operator);
        playerContract.fulfillRandomness(randomness, dataWithRound);
        chars.spearBalanced = uint16(1002);

        // Mint Sword and Shield User
        vm.prank(PLAYER_TWO);
        requestId = playerContract.requestCreatePlayer(true);
        randomness = uint256(keccak256(abi.encodePacked("sword_shield")));
        dataWithRound = abi.encode(ROUND_ID, abi.encode(requestId, extraData));
        vm.stopPrank();
        vm.prank(operator);
        playerContract.fulfillRandomness(randomness, dataWithRound);
        chars.swordAndShieldDefensive = uint16(1003);

        // Mint Rapier and Shield User
        vm.prank(PLAYER_TWO);
        requestId = playerContract.requestCreatePlayer(true);
        randomness = uint256(keccak256(abi.encodePacked("rapier_shield")));
        dataWithRound = abi.encode(ROUND_ID, abi.encode(requestId, extraData));
        vm.stopPrank();
        vm.prank(operator);
        playerContract.fulfillRandomness(randomness, dataWithRound);
        chars.rapierAndShieldDefensive = uint16(1004);

        // Mint Quarterstaff User
        vm.prank(PLAYER_TWO);
        requestId = playerContract.requestCreatePlayer(true);
        randomness = uint256(keccak256(abi.encodePacked("quarterstaff")));
        dataWithRound = abi.encode(ROUND_ID, abi.encode(requestId, extraData));
        vm.stopPrank();
        vm.prank(operator);
        playerContract.fulfillRandomness(randomness, dataWithRound);
        chars.quarterstaffDefensive = uint16(1005);
    }

    function testBasicCombat() public {
        // Create the test characters first
        mintDefaultCharacters();

        // First verify we can get the player stats directly
        console2.log("\nDebug Player Setup:");

        // Get initial state
        (uint256 health, uint256 stamina) = playerContract.getPlayerState(1000);
        console2.log("Initial State:");
        console2.log("  - Health:", health);
        console2.log("  - Stamina:", stamina);

        // Get the player stats
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(1000);
        console2.log("Player Stats:");
        console2.log("  - Strength:", stats.strength);
        console2.log("  - SkinIndex:", stats.skinIndex);

        // Now set up the game loadouts
        uint32 defaultSkinIndex = skinRegistry.defaultSkinRegistryId();
        IGameEngine.PlayerLoadout memory player1 =
            IGameEngine.PlayerLoadout({playerId: 1000, skinIndex: defaultSkinIndex, skinTokenId: 1});

        IGameEngine.PlayerLoadout memory player2 =
            IGameEngine.PlayerLoadout({playerId: 1003, skinIndex: defaultSkinIndex, skinTokenId: 4});

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

        // Create the test characters first
        mintDefaultCharacters();

        // Use pre-configured players directly
        IGameEngine.PlayerLoadout memory loadout1A = IGameEngine.PlayerLoadout({
            playerId: uint32(1000),
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });
        IGameEngine.PlayerLoadout memory loadout1B = IGameEngine.PlayerLoadout({
            playerId: uint32(1003),
            skinIndex: skinIndex,
            skinTokenId: chars.swordAndShieldDefensive
        });

        vm.warp(block.timestamp + 1);
        bytes memory results = game.practiceGame(loadout1A, loadout1B);
        logScenarioResults(1, results);

        // Scenario 2: Battleaxe vs Spear
        IGameEngine.PlayerLoadout memory loadout2A = IGameEngine.PlayerLoadout({
            playerId: uint32(1001),
            skinIndex: skinIndex,
            skinTokenId: chars.battleaxeOffensive
        });
        IGameEngine.PlayerLoadout memory loadout2B =
            IGameEngine.PlayerLoadout({playerId: uint32(1002), skinIndex: skinIndex, skinTokenId: chars.spearBalanced});

        vm.warp(block.timestamp + 1);
        results = game.practiceGame(loadout2A, loadout2B);
        logScenarioResults(2, results);

        // Scenario 3: Rapier and Shield vs Quarterstaff
        IGameEngine.PlayerLoadout memory loadout3A = IGameEngine.PlayerLoadout({
            playerId: uint32(1004),
            skinIndex: skinIndex,
            skinTokenId: chars.rapierAndShieldDefensive
        });
        IGameEngine.PlayerLoadout memory loadout3B = IGameEngine.PlayerLoadout({
            playerId: uint32(1005),
            skinIndex: skinIndex,
            skinTokenId: chars.quarterstaffDefensive
        });

        vm.warp(block.timestamp + 1);
        results = game.practiceGame(loadout3A, loadout3B);
        logScenarioResults(3, results);

        // Scenario 4: Greatsword vs Spear (Offensive vs Balanced)
        IGameEngine.PlayerLoadout memory loadout4A = IGameEngine.PlayerLoadout({
            playerId: uint32(1000),
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });
        IGameEngine.PlayerLoadout memory loadout4B =
            IGameEngine.PlayerLoadout({playerId: uint32(1002), skinIndex: skinIndex, skinTokenId: chars.spearBalanced});

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

        // Create the test characters first
        mintDefaultCharacters();

        uint256 totalFights = 20;
        uint256 totalScenarios = 3;
        uint256[] memory offensiveWins = new uint256[](totalScenarios);
        uint256[] memory defensiveWins = new uint256[](totalScenarios);
        uint256[] memory totalRounds = new uint256[](totalScenarios);

        // Remove createPlayer calls and use pre-configured loadouts directly
        IGameEngine.PlayerLoadout memory attackerLoadout = IGameEngine.PlayerLoadout({
            playerId: uint32(1000),
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });

        IGameEngine.PlayerLoadout memory defenderLoadout = IGameEngine.PlayerLoadout({
            playerId: uint32(1005),
            skinIndex: skinIndex,
            skinTokenId: chars.quarterstaffDefensive
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
                playerId: uint32(1000),
                skinIndex: skinIndex,
                skinTokenId: offensiveTokenIds[scenario]
            });

            IGameEngine.PlayerLoadout memory defensiveLoadout = IGameEngine.PlayerLoadout({
                playerId: uint32(1003),
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

                if (winner == 1000) offensiveWins[scenario]++;
                else if (winner == 1003) defensiveWins[scenario]++;

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

    function testCombatMechanics() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }

        // Create the test characters first
        mintDefaultCharacters();

        // Use pre-configured players directly
        IGameEngine.PlayerLoadout memory p1Loadout = IGameEngine.PlayerLoadout({
            playerId: uint32(1000),
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });

        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: uint32(1005),
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
            playerId: uint32(1000),
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });

        IGameEngine.PlayerLoadout memory defenderLoadout = IGameEngine.PlayerLoadout({
            playerId: uint32(1005),
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

        // Create the test characters first
        mintDefaultCharacters();

        // Use pre-configured players directly
        IGameEngine.PlayerLoadout memory attackerLoadout = IGameEngine.PlayerLoadout({
            playerId: uint32(1000),
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });

        IGameEngine.PlayerLoadout memory defenderLoadout = IGameEngine.PlayerLoadout({
            playerId: uint32(1004),
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
            playerId: uint32(1000),
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });

        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: uint32(1005),
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

        // Verify turn structure
        require(actions.length > 0, "No actions recorded");

        console2.log("\nAnalyzing Combat Turns:");
        bool player1First = isOffensiveAction(uint8(actions[0].p1Result));
        console2.log(string.concat("First attacker: ", player1First ? "P1" : "P2"));

        // Add detailed action analysis
        console2.log("\nDetailed Action Analysis:");
        uint256 p1OffensiveCount = 0;
        uint256 p2OffensiveCount = 0;

        for (uint256 i = 0; i < actions.length; i++) {
            GameEngine.CombatAction memory action = actions[i];

            // Count offensive actions
            if (isOffensiveAction(uint8(action.p1Result))) p1OffensiveCount++;
            if (isOffensiveAction(uint8(action.p2Result))) p2OffensiveCount++;

            console2.log(
                string.concat(
                    "Round ",
                    vm.toString(i + 1),
                    ":\n  P1: ",
                    getActionType(uint8(action.p1Result)),
                    " (",
                    isOffensiveAction(uint8(action.p1Result)) ? "offensive" : "defensive",
                    ")\n  P2: ",
                    getActionType(uint8(action.p2Result)),
                    " (",
                    isOffensiveAction(uint8(action.p2Result)) ? "offensive" : "defensive",
                    ")"
                )
            );
        }

        console2.log("\nAction Summary:");
        console2.log(string.concat("P1 Offensive Actions: ", vm.toString(p1OffensiveCount)));
        console2.log(string.concat("P2 Offensive Actions: ", vm.toString(p2OffensiveCount)));

        // Add assertions to ensure both players have offensive actions
        assertTrue(
            p1OffensiveCount > 0,
            string.concat("P1 should have offensive actions but had ", vm.toString(p1OffensiveCount))
        );
        assertTrue(
            p2OffensiveCount > 0,
            string.concat("P2 should have offensive actions but had ", vm.toString(p2OffensiveCount))
        );

        // Add assertions to ensure neither player has all the actions
        assertTrue(
            p1OffensiveCount < actions.length,
            string.concat(
                "P1 shouldn't have all offensive actions (",
                vm.toString(p1OffensiveCount),
                "/",
                vm.toString(actions.length),
                ")"
            )
        );
        assertTrue(
            p2OffensiveCount < actions.length,
            string.concat(
                "P2 shouldn't have all offensive actions (",
                vm.toString(p2OffensiveCount),
                "/",
                vm.toString(actions.length),
                ")"
            )
        );
    }

    // Helper function to determine if an action is offensive
    function isOffensiveAction(uint8 action) internal pure returns (bool) {
        return action == uint8(GameEngine.CombatResultType.ATTACK) || action == uint8(GameEngine.CombatResultType.CRIT)
            || action == uint8(GameEngine.CombatResultType.EXHAUSTED);
    }

    // Helper function to determine if an action is defensive
    function isDefensiveAction(uint8 action) internal pure returns (bool) {
        return action == uint8(GameEngine.CombatResultType.MISS) || action == uint8(GameEngine.CombatResultType.DODGE)
            || action == uint8(GameEngine.CombatResultType.BLOCK) || action == uint8(GameEngine.CombatResultType.PARRY)
            || action == uint8(GameEngine.CombatResultType.HIT);
    }

    // Helper function to convert action type to string for logging
    function getActionType(uint8 action) internal pure returns (string memory) {
        if (action == uint8(GameEngine.CombatResultType.ATTACK)) return "ATTACK";
        if (action == uint8(GameEngine.CombatResultType.CRIT)) return "CRIT";
        if (action == uint8(GameEngine.CombatResultType.EXHAUSTED)) return "EXHAUSTED";
        if (action == uint8(GameEngine.CombatResultType.MISS)) return "MISS";
        if (action == uint8(GameEngine.CombatResultType.DODGE)) return "DODGE";
        if (action == uint8(GameEngine.CombatResultType.BLOCK)) return "BLOCK";
        if (action == uint8(GameEngine.CombatResultType.PARRY)) return "PARRY";
        if (action == uint8(GameEngine.CombatResultType.HIT)) return "HIT";
        if (action == uint8(GameEngine.CombatResultType.COUNTER)) return "COUNTER";
        if (action == uint8(GameEngine.CombatResultType.COUNTER_CRIT)) return "COUNTER_CRIT";
        if (action == uint8(GameEngine.CombatResultType.RIPOSTE)) return "RIPOSTE";
        if (action == uint8(GameEngine.CombatResultType.RIPOSTE_CRIT)) return "RIPOSTE_CRIT";
        return "UNKNOWN";
    }

    function testHighDamageEncoding() public {
        // Test several high damage values
        uint16[] memory testDamages = new uint16[](4);
        testDamages[0] = 256; // Just over uint8 max
        testDamages[1] = 300; // Random mid-range value
        testDamages[2] = 1000; // High value
        testDamages[3] = 65535; // uint16 max

        for (uint256 i = 0; i < testDamages.length; i++) {
            uint16 testDamage = testDamages[i];

            // Create a test combat action with high damage
            bytes memory actionData = new bytes(8);

            // Pack the damage
            actionData[0] = bytes1(uint8(GameEngine.CombatResultType.ATTACK));

            // Debug output before encoding
            uint8 highByte = uint8(testDamage >> 8);
            uint8 lowByte = uint8(testDamage);
            console2.log("=== Encoding Process ===");
            console2.log(string.concat("Original damage value: ", vm.toString(testDamage)));
            console2.log(string.concat("High byte: ", vm.toString(highByte)));
            console2.log(string.concat("Low byte: ", vm.toString(lowByte)));

            actionData[1] = bytes1(highByte); // High byte
            actionData[2] = bytes1(lowByte); // Low byte
            actionData[3] = bytes1(uint8(10)); // Stamina cost
            actionData[4] = bytes1(uint8(GameEngine.CombatResultType.HIT));
            actionData[5] = bytes1(0); // No defense damage
            actionData[6] = bytes1(0);
            actionData[7] = bytes1(0);

            // Debug output raw bytes
            console2.log("Raw bytes in actionData:");
            for (uint256 j = 0; j < 8; j++) {
                console2.log(string.concat("Byte ", vm.toString(j), ": ", vm.toString(uint8(actionData[j]))));
            }

            // Create minimal valid combat log - JUST the header
            bytes memory testLog = new bytes(5); // Only 5 bytes for header
            testLog[0] = bytes1(uint8(0));
            testLog[1] = bytes1(uint8(0));
            testLog[2] = bytes1(uint8(0));
            testLog[3] = bytes1(uint8(1)); // Winner ID 1
            testLog[4] = bytes1(uint8(GameEngine.WinCondition.HEALTH));

            // Concatenate the action data to make a 13 byte log
            testLog = bytes.concat(testLog, actionData);

            // Concatenate the test log with action data
            testLog = bytes.concat(testLog, actionData);

            // Debug output before decoding
            console2.log("=== Decoding Process ===");
            (,, GameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(testLog);

            // Debug decoded values
            console2.log(
                string.concat(
                    "Decoded damage: ", vm.toString(actions[0].p1Damage), " (Expected: ", vm.toString(testDamage), ")"
                )
            );

            // Assertion
            assertEq(
                actions[0].p1Damage,
                testDamage,
                string.concat("Damage encoding failed for value: ", vm.toString(testDamage))
            );

            console2.log("-------------------");
        }
    }
}

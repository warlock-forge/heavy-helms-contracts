// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/game/engine/GameEngine.sol";
import "../../src/interfaces/fighters/IPlayer.sol";
import "../../src/interfaces/game/engine/IGameEngine.sol";

contract BalanceTest is Test {
    GameEngine private gameEngine;
    uint16 private lethalityFactor = 150; // Default lethality

    // Standard test attributes
    uint8 private lowStat = 5;
    uint8 private mediumStat = 12;
    uint8 private highStat = 19;

    // Test iterations for statistical significance
    uint256 private matchCount = 100;

    struct MatchStatistics {
        uint256 wins;
        uint256 totalDamageDealt;
        uint256 totalRounds;
        uint256 successfulBlocks;
        uint256 successfulParries;
        uint256 successfulDodges;
        uint256 criticalHits;
        uint256 totalHits;
        uint256 totalAttacks;
        uint256 deathsByExhaustion;
        uint256 deathsByLethalDamage;
    }

    struct TestFighter {
        string name;
        IGameEngine.FighterStats stats;
    }

    uint256 private constant DEFAULT_FORK_BLOCK = 19_000_000;

    function setUp() public {
        // Use the same setupRandomness pattern from TestBase.sol
        try vm.envString("CI") returns (string memory) {
            console.log("Testing in CI mode with mock randomness");
            vm.warp(1_000_000);
            vm.roll(DEFAULT_FORK_BLOCK);
            vm.prevrandao(bytes32(uint256(0x1234567890)));
        } catch {
            // Try to use RPC fork, fallback to mock if not available
            try vm.envString("RPC_URL") returns (string memory rpcUrl) {
                vm.createSelectFork(rpcUrl);
            } catch {
                console.log("No RPC_URL found, using mock randomness");
                vm.warp(1_000_000);
                vm.roll(DEFAULT_FORK_BLOCK);
                vm.prevrandao(bytes32(uint256(0x1234567890)));
            }
        }

        gameEngine = new GameEngine();
    }

    // ==================== FIGHTER CREATION HELPERS ====================

    // Create a shield tank with high CON/STR/SIZ, plate armor, and tower shield
    function createShieldTank() private view returns (TestFighter memory) {
        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: 12,
            constitution: highStat,
            size: highStat,
            agility: lowStat,
            stamina: mediumStat,
            luck: lowStat
        });

        return TestFighter({
            name: "Shield Tank",
            stats: IGameEngine.FighterStats({
                attributes: attrs,
                armor: 3, // ARMOR_PLATE
                weapon: 1, // WEAPON_MACE_TOWER
                stance: 0 // STANCE_DEFENSIVE
            })
        });
    }

    // Create a dodge-focused fighter with high AGI, low SIZ, cloth armor
    function createDodger() private view returns (TestFighter memory) {
        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: lowStat,
            constitution: mediumStat,
            size: lowStat,
            agility: highStat,
            stamina: highStat,
            luck: mediumStat
        });

        return TestFighter({
            name: "Dodger",
            stats: IGameEngine.FighterStats({
                attributes: attrs,
                armor: 0, // ARMOR_CLOTH
                weapon: 5, // WEAPON_QUARTERSTAFF
                stance: 0 // STANCE_DEFENSIVE
            })
        });
    }

    // Create a parry-focused fighter
    function createParryMaster() private view returns (TestFighter memory) {
        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: mediumStat,
            constitution: lowStat,
            size: mediumStat,
            agility: highStat,
            stamina: mediumStat,
            luck: mediumStat
        });

        return TestFighter({
            name: "Parry Master",
            stats: IGameEngine.FighterStats({
                attributes: attrs,
                armor: 1, // ARMOR_LEATHER
                weapon: 2, // WEAPON_RAPIER_BUCKLER
                stance: 0 // STANCE_DEFENSIVE
            })
        });
    }

    // Create a berserker with high STR, SIZ, and offensive stance
    function createBerserker() private view returns (TestFighter memory) {
        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: highStat,
            constitution: mediumStat,
            size: mediumStat,
            agility: mediumStat,
            stamina: mediumStat,
            luck: lowStat
        });

        return TestFighter({
            name: "Berserker",
            stats: IGameEngine.FighterStats({
                attributes: attrs,
                armor: 1, // ARMOR_LEATHER
                weapon: 4, // WEAPON_BATTLEAXE
                stance: 2 // STANCE_OFFENSIVE
            })
        });
    }

    // Create a dual dagger fighter with high agility
    function createDualDaggerist() private view returns (TestFighter memory) {
        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: mediumStat,
            constitution: mediumStat,
            size: lowStat,
            agility: highStat,
            stamina: mediumStat,
            luck: mediumStat
        });

        return TestFighter({
            name: "Dual Daggerist",
            stats: IGameEngine.FighterStats({
                attributes: attrs,
                armor: 0, // ARMOR_CLOTH
                weapon: 9, // WEAPON_DUAL_DAGGERS
                stance: 1 // STANCE_BALANCED
            })
        });
    }

    // Create a greatsword fighter
    function createGreatswordFighter() private view returns (TestFighter memory) {
        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: highStat,
            constitution: mediumStat,
            size: mediumStat,
            agility: lowStat,
            stamina: mediumStat,
            luck: mediumStat
        });

        return TestFighter({
            name: "Greatsword User",
            stats: IGameEngine.FighterStats({
                attributes: attrs,
                armor: 2, // ARMOR_CHAIN
                weapon: 3, // WEAPON_GREATSWORD
                stance: 1 // STANCE_BALANCED
            })
        });
    }

    // Create a balanced fighter
    function createBalancedFighter() private view returns (TestFighter memory) {
        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: mediumStat,
            constitution: mediumStat,
            size: mediumStat,
            agility: mediumStat,
            stamina: mediumStat,
            luck: mediumStat
        });

        return TestFighter({
            name: "Balanced",
            stats: IGameEngine.FighterStats({
                attributes: attrs,
                armor: 2, // ARMOR_CHAIN
                weapon: 0, // WEAPON_ARMING_SWORD_KITE
                stance: 1 // STANCE_BALANCED
            })
        });
    }

    // Create a fighter with specified weapon, armor, stance and attributes
    function createCustomFighter(
        string memory name,
        uint8 weapon,
        uint8 armor,
        uint8 stance,
        uint8 str,
        uint8 con,
        uint8 siz,
        uint8 agi,
        uint8 stam,
        uint8 luck
    ) private pure returns (TestFighter memory) {
        Fighter.Attributes memory attrs =
            Fighter.Attributes({strength: str, constitution: con, size: siz, agility: agi, stamina: stam, luck: luck});

        return TestFighter({
            name: name,
            stats: IGameEngine.FighterStats({attributes: attrs, armor: armor, weapon: weapon, stance: stance})
        });
    }

    // ==================== TEST INFRASTRUCTURE ====================

    function _generateTestSeed() internal view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp, block.prevrandao, blockhash(block.number - 1), msg.sender, block.number
                )
            )
        );
    }

    function runDuel(TestFighter memory fighter1, TestFighter memory fighter2)
        private
        returns (MatchStatistics memory stats1, MatchStatistics memory stats2)
    {
        // Initialize statistics
        stats1 = MatchStatistics(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        stats2 = MatchStatistics(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

        // Generate base seed per test run (different every time)
        uint256 baseSeed = _generateTestSeed();

        for (uint256 i = 0; i < matchCount; i++) {
            // Change blockchain state for new entropy
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 15);

            // Use a new seed for each match
            uint256 matchSeed = uint256(keccak256(abi.encodePacked(baseSeed, i, block.timestamp)));

            // Run the combat
            bytes memory results = gameEngine.processGame(fighter1.stats, fighter2.stats, matchSeed, lethalityFactor);

            // Decode and analyze results
            (bool player1Won,, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) =
                gameEngine.decodeCombatLog(results);

            // Update win counts
            if (player1Won) {
                stats1.wins++;
            } else {
                stats2.wins++;
            }

            // Update condition counts
            if (condition == IGameEngine.WinCondition.EXHAUSTION) {
                if (player1Won) stats2.deathsByExhaustion++;
                else stats1.deathsByExhaustion++;
            } else if (condition == IGameEngine.WinCondition.DEATH) {
                if (player1Won) stats2.deathsByLethalDamage++;
                else stats1.deathsByLethalDamage++;
            }

            // Analyze each action
            for (uint256 j = 0; j < actions.length; j++) {
                IGameEngine.CombatAction memory action = actions[j];

                // Count rounds
                stats1.totalRounds++;
                stats2.totalRounds++;

                // Track player 1's actions
                processActionData(action.p1Result, action.p1Damage, stats1);

                // Track player 2's actions
                processActionData(action.p2Result, action.p2Damage, stats2);
            }
        }

        return (stats1, stats2);
    }

    function processActionData(IGameEngine.CombatResultType resultType, uint16 damage, MatchStatistics memory stats)
        private
        pure
    {
        // Track successful hits
        if (resultType == IGameEngine.CombatResultType.ATTACK || resultType == IGameEngine.CombatResultType.CRIT) {
            stats.totalHits++;
            stats.totalDamageDealt += damage;
        }

        // Track total attacks
        if (resultType == IGameEngine.CombatResultType.ATTACK || resultType == IGameEngine.CombatResultType.MISS) {
            stats.totalAttacks++;
        }

        // Track action results
        if (resultType == IGameEngine.CombatResultType.BLOCK) {
            stats.successfulBlocks++;
        }

        if (resultType == IGameEngine.CombatResultType.PARRY) {
            stats.successfulParries++;
        }

        if (resultType == IGameEngine.CombatResultType.DODGE) {
            stats.successfulDodges++;
        }

        if (resultType == IGameEngine.CombatResultType.CRIT) {
            stats.criticalHits++;
        }
    }

    // ==================== NEW TARGETED TESTS ====================

    // Test 1: Shield Tank vs Fast Weapons
    // Shield tank should dominate low-damage, fast weapons
    function testShieldTankVsLightWeapons() public {
        TestFighter memory shieldTank = createShieldTank();
        TestFighter memory dualDagger = createDualDaggerist();

        MatchStatistics memory tankStats;
        MatchStatistics memory daggerStats;

        (tankStats, daggerStats) = runDuel(shieldTank, dualDagger);

        // Shield tank should win 75-85% against dual daggers
        assertTrue(
            tankStats.wins >= matchCount * 75 / 100, "Shield Tank should counter Dual Daggers (expected 75%+ win rate)"
        );
    }

    // Test 2: Parry Master vs Berserker
    // Parry fighter should counter slow, heavy-hitting weapons
    function testParryMasterVsBerserker() public {
        TestFighter memory parryMaster = createParryMaster();
        TestFighter memory berserker = createBerserker();

        MatchStatistics memory parryStats;
        MatchStatistics memory berserkerStats;

        (parryStats, berserkerStats) = runDuel(parryMaster, berserker);

        // Parry master should win 65-75% against berserker
        assertTrue(
            parryStats.wins >= matchCount * 60 / 100, "Parry Master should counter Berserker (expected 65%+ win rate)"
        );
    }

    // Test 3: Dodger vs Heavy Weapons
    // Dodger should counter slow weapons like greatsword
    function testDodgerVsGreatsword() public {
        TestFighter memory dodger = createDodger();
        TestFighter memory greatswordUser = createGreatswordFighter();

        MatchStatistics memory dodgerStats;
        MatchStatistics memory gsStats;

        (dodgerStats, gsStats) = runDuel(dodger, greatswordUser);

        // Dodger should win 50% of matches against greatsword
        assertTrue(
            dodgerStats.wins >= matchCount * 50 / 100, "Dodger should counter Greatsword (expected 50%+ win rate)"
        );
    }

    // Test 4: Berserker vs Shield Tank (Offensive vs Defensive)
    // Berserker should have an advantage against shield tanks
    function testBerserkerVsShieldTank() public {
        TestFighter memory berserker = createBerserker();
        TestFighter memory shieldTank = createShieldTank();

        // Run just one fight for detailed analysis
        uint256 singleSeed = _generateTestSeed();
        bytes memory results = gameEngine.processGame(berserker.stats, shieldTank.stats, singleSeed, lethalityFactor);

        (bool berserkerWon,, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Now run the full statistical test
        MatchStatistics memory berserkerStats;
        MatchStatistics memory tankStats;
        (berserkerStats, tankStats) = runDuel(berserker, shieldTank);

        assertTrue(
            berserkerStats.wins >= matchCount * 60 / 100,
            "Berserker should counter Shield Tank (expected 50%+ win rate)"
        );
    }

    // Test 6: Weapon matchups with identical fighters
    // Tests raw weapon performance with equal stats
    function testWeaponPerformance() public {
        // Create fighters with identical stats but different weapons
        TestFighter memory greatsword = createCustomFighter(
            "Greatsword Control", 3, 2, 1, mediumStat, mediumStat, mediumStat, mediumStat, mediumStat, mediumStat
        );

        TestFighter memory battleaxe = createCustomFighter(
            "Battleaxe Control", 4, 2, 1, mediumStat, mediumStat, mediumStat, mediumStat, mediumStat, mediumStat
        );

        TestFighter memory dualDaggers = createCustomFighter(
            "Dual Daggers Control", 9, 2, 1, mediumStat, mediumStat, mediumStat, mediumStat, mediumStat, mediumStat
        );

        TestFighter memory swordShield = createCustomFighter(
            "Sword+Shield Control", 0, 2, 1, mediumStat, mediumStat, mediumStat, mediumStat, mediumStat, mediumStat
        );

        MatchStatistics memory gsStats;
        MatchStatistics memory baStats;
        MatchStatistics memory ddStats;
        MatchStatistics memory ssStats;

        // Test Greatsword vs Battleaxe
        (gsStats, baStats) = runDuel(greatsword, battleaxe);

        // Test Greatsword vs Dual Daggers
        (gsStats, ddStats) = runDuel(greatsword, dualDaggers);

        // Test Battleaxe vs Sword+Shield
        (baStats, ssStats) = runDuel(battleaxe, swordShield);

        // No weapon should have more than a 63% advantage when all other factors are equal
        assertTrue(
            gsStats.wins <= matchCount * 70 / 100 && baStats.wins <= matchCount * 80 / 100,
            "Weapons should be reasonably balanc8d when all other factors are equal"
        );
    }

    // Test 8: Stamina Importance
    // High stamina should consistently beat low stamina
    function testStaminaImportance() public {
        // Create fighters with identical stats except stamina
        TestFighter memory highStamFighter = createCustomFighter(
            "High Stamina", 0, 2, 1, mediumStat, mediumStat, mediumStat, mediumStat, highStat, mediumStat
        );

        TestFighter memory lowStamFighter = createCustomFighter(
            "Low Stamina", 0, 2, 1, mediumStat, mediumStat, mediumStat, mediumStat, lowStat, mediumStat
        );

        MatchStatistics memory highStamStats;
        MatchStatistics memory lowStamStats;

        (highStamStats, lowStamStats) = runDuel(highStamFighter, lowStamFighter);

        // High stamina should win and low stamina should die from exhaustion
        assertTrue(highStamStats.wins >= matchCount * 65 / 100, "High stamina should win at least 65% of fights");
        assertTrue(
            lowStamStats.deathsByExhaustion >= lowStamStats.deathsByLethalDamage,
            "Low stamina fighter should die more from exhaustion than damage"
        );
    }

    // Test 9: Low-Stamina Offensive vs Tank
    // A berserker with low stamina should exhaust themselves against a tank
    function testLowStaminaOffensiveVsTank() public {
        // Create a low-stamina berserker
        TestFighter memory lowStamBerserker = createCustomFighter(
            "Low Stam Berserker", 4, 1, 2, highStat, mediumStat, highStat, mediumStat, lowStat, lowStat
        );

        TestFighter memory tank = createShieldTank();

        MatchStatistics memory bStats;
        MatchStatistics memory tStats;

        (bStats, tStats) = runDuel(lowStamBerserker, tank);

        // Tank should win and berserker should die from exhaustion
        assertTrue(tStats.wins >= matchCount * 40 / 100, "Tank should win against low stamina berserker");
        assertTrue(
            bStats.deathsByExhaustion >= bStats.deathsByLethalDamage,
            "Low stamina berserker should die more from exhaustion than damage"
        );
    }

    // Add this test function to your BalanceTest.t.sol file
    function testArmorTypeVsVariousWeapons() public {
        // Create tank variants with different armor
        TestFighter memory plateTank =
            createCustomFighter("Plate Tank", 1, 3, 0, highStat, highStat, highStat, lowStat, mediumStat, lowStat);

        TestFighter memory leatherTank =
            createCustomFighter("Leather Tank", 1, 1, 0, highStat, highStat, highStat, lowStat, mediumStat, lowStat);

        // Create different weapon users
        TestFighter memory spearUser = createCustomFighter(
            "Spear User", 6, 0, 1, mediumStat, mediumStat, mediumStat, highStat, mediumStat, mediumStat
        );

        TestFighter memory greatswordUser = createGreatswordFighter();

        // Run matchups
        MatchStatistics memory plateVsSpearStats;
        MatchStatistics memory leatherVsSpearStats;
        MatchStatistics memory plateVsGreatswordStats;
        MatchStatistics memory leatherVsGreatswordStats;
        MatchStatistics memory spearStats1;
        MatchStatistics memory spearStats2;
        MatchStatistics memory gsStats1;
        MatchStatistics memory gsStats2;

        // Test tanks against spear
        (plateVsSpearStats, spearStats1) = runDuel(plateTank, spearUser);

        (leatherVsSpearStats, spearStats2) = runDuel(leatherTank, spearUser);

        // Test tanks against greatsword
        (plateVsGreatswordStats, gsStats1) = runDuel(plateTank, greatswordUser);

        // Test leather tank against greatsword
        (leatherVsGreatswordStats, gsStats2) = runDuel(leatherTank, greatswordUser);
    }

    // Add this helper function
    function _getResultName(IGameEngine.CombatResultType result) private pure returns (string memory) {
        if (result == IGameEngine.CombatResultType.MISS) return "MISS";
        if (result == IGameEngine.CombatResultType.ATTACK) return "ATTACK";
        if (result == IGameEngine.CombatResultType.CRIT) return "CRIT";
        if (result == IGameEngine.CombatResultType.BLOCK) return "BLOCK";
        if (result == IGameEngine.CombatResultType.COUNTER) return "COUNTER";
        if (result == IGameEngine.CombatResultType.COUNTER_CRIT) return "COUNTER_CRIT";
        if (result == IGameEngine.CombatResultType.DODGE) return "DODGE";
        if (result == IGameEngine.CombatResultType.PARRY) return "PARRY";
        if (result == IGameEngine.CombatResultType.RIPOSTE) return "RIPOSTE";
        if (result == IGameEngine.CombatResultType.RIPOSTE_CRIT) return "RIPOSTE_CRIT";
        if (result == IGameEngine.CombatResultType.EXHAUSTED) return "EXHAUSTED";
        if (result == IGameEngine.CombatResultType.HIT) return "HIT";
        return "UNKNOWN";
    }

    // Helper function to determine if a result type is offensive (attacking)
    function _isOffensiveResult(IGameEngine.CombatResultType result) private pure returns (bool) {
        return result == IGameEngine.CombatResultType.ATTACK || result == IGameEngine.CombatResultType.CRIT
            || result == IGameEngine.CombatResultType.MISS || result == IGameEngine.CombatResultType.EXHAUSTED;
    }

    // Helper function to get win condition name
    function _getWinConditionName(IGameEngine.WinCondition condition) private pure returns (string memory) {
        if (condition == IGameEngine.WinCondition.DEATH) return "DEATH";
        if (condition == IGameEngine.WinCondition.EXHAUSTION) return "EXHAUSTION";
        if (condition == IGameEngine.WinCondition.HEALTH) return "HEALTH";
        if (condition == IGameEngine.WinCondition.MAX_ROUNDS) return "MAX_ROUNDS";
        return "UNKNOWN";
    }
}

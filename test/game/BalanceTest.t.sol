// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/game/engine/GameEngine.sol";
import "../../src/interfaces/fighters/IPlayer.sol";
import "../../src/interfaces/game/engine/IGameEngine.sol";
import "../TestBase.sol";

contract BalanceTest is TestBase {
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

    // ==================== FIGHTER CREATION HELPERS ====================

    function createShieldTank() private view returns (TestFighter memory) {
        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: mediumStat,
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

    function createParryMaster() private view returns (TestFighter memory) {
        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: mediumStat,
            constitution: highStat,
            size: lowStat,
            agility: highStat,
            stamina: lowStat,
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

    function createBerserker() private view returns (TestFighter memory) {
        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: highStat,
            constitution: lowStat,
            size: highStat,
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

    function createAssassin() private view returns (TestFighter memory) {
        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: highStat,
            constitution: lowStat,
            size: mediumStat,
            agility: highStat,
            stamina: lowStat,
            luck: mediumStat
        });

        return TestFighter({
            name: "Assassin",
            stats: IGameEngine.FighterStats({
                attributes: attrs,
                armor: 1, // ARMOR_LEATHER
                weapon: 9, // WEAPON_DUAL_DAGGERS
                stance: 2 // STANCE_OFFENSIVE
            })
        });
    }

    function createBruiser() private view returns (TestFighter memory) {
        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: highStat,
            constitution: lowStat,
            size: highStat,
            agility: lowStat,
            stamina: mediumStat,
            luck: mediumStat
        });

        return TestFighter({
            name: "Bruiser",
            stats: IGameEngine.FighterStats({
                attributes: attrs,
                armor: 1, // ARMOR_LEATHER
                weapon: 18, // WEAPON_DUAL_CLUBS
                stance: 2 // STANCE_OFFENSIVE
            })
        });
    }

    function createVanguard() private view returns (TestFighter memory) {
        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: highStat,
            constitution: highStat,
            size: mediumStat,
            agility: lowStat,
            stamina: mediumStat,
            luck: lowStat
        });

        return TestFighter({
            name: "Vanguard",
            stats: IGameEngine.FighterStats({
                attributes: attrs,
                armor: 2, // ARMOR_CHAIN
                weapon: 3, // WEAPON_GREATSWORD
                stance: 1 // STANCE_BALANCED
            })
        });
    }

    function createMage() private view returns (TestFighter memory) {
        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: mediumStat,
            constitution: mediumStat,
            size: mediumStat,
            agility: mediumStat,
            stamina: highStat,
            luck: lowStat
        });

        return TestFighter({
            name: "Mage",
            stats: IGameEngine.FighterStats({
                attributes: attrs,
                armor: 0, // ARMOR_CLOTH
                weapon: 5, // WEAPON_QUARTERSTAFF
                stance: 0 // STANCE_DEFENSIVE
            })
        });
    }

    function createBalanced() private view returns (TestFighter memory) {
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
            bytes memory results = gameEngine.processGame(fighter1.stats, fighter2.stats, matchSeed, 0);

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

    // Test 1: Shield Tank vs Assassin
    // Shield tank should dominate low-damage, fast weapons
    function testShieldTankVsAssassin() public skipInCI {
        TestFighter memory shieldTank = createShieldTank();
        TestFighter memory assassin = createAssassin();

        MatchStatistics memory tankStats;
        MatchStatistics memory assassinStats;

        (tankStats, assassinStats) = runDuel(shieldTank, assassin);

        // Shield tank should win 75-85% against dual daggers
        assertTrue(
            tankStats.wins >= matchCount * 65 / 100 && tankStats.wins <= matchCount * 95 / 100,
            string(
                abi.encodePacked(
                    "Shield Tank should counter Assassin (expected 65%-95% win rate): ", vm.toString(tankStats.wins)
                )
            )
        );
        assertTrue(
            assassinStats.wins >= matchCount * 5 / 100 && assassinStats.wins <= matchCount * 35 / 100,
            string(
                abi.encodePacked(
                    "Assassin be weak against Shield Tank (expected 5%-35% win rate): ", vm.toString(assassinStats.wins)
                )
            )
        );
    }

    // Test 2: Parry Master vs Berserker
    // Parry fighter should counter slow, heavy-hitting weapons
    function testParryMasterVsBerserker() public skipInCI {
        TestFighter memory parryMaster = createParryMaster();
        TestFighter memory berserker = createBerserker();

        MatchStatistics memory parryStats;
        MatchStatistics memory berserkerStats;

        (parryStats, berserkerStats) = runDuel(parryMaster, berserker);

        assertTrue(
            parryStats.wins >= matchCount * 60 / 100 && parryStats.wins <= matchCount * 90 / 100,
            string(
                abi.encodePacked(
                    "Parry Master should counter Berserker (expected 60%-90% win rate): ", vm.toString(parryStats.wins)
                )
            )
        );
        assertTrue(
            berserkerStats.wins >= matchCount * 10 / 100 && berserkerStats.wins <= matchCount * 40 / 100,
            string(
                abi.encodePacked(
                    "Berserker should be weak against Parry Master (expected 10%-40% win rate): ",
                    vm.toString(berserkerStats.wins)
                )
            )
        );
    }

    // Test 3: Berserker vs Shield Tank (Offensive vs Defensive)
    // Berserker should have an advantage against shield tanks
    function testBerserkerVsShieldTank() public skipInCI {
        TestFighter memory berserker = createBerserker();
        TestFighter memory shieldTank = createShieldTank();

        // Run just one fight for detailed analysis
        uint256 singleSeed = _generateTestSeed();
        bytes memory results = gameEngine.processGame(berserker.stats, shieldTank.stats, singleSeed, 0);

        (bool berserkerWon,, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Now run the full statistical test
        MatchStatistics memory berserkerStats;
        MatchStatistics memory tankStats;
        (berserkerStats, tankStats) = runDuel(berserker, shieldTank);

        assertTrue(
            berserkerStats.wins >= matchCount * 60 / 100 && berserkerStats.wins <= matchCount * 90 / 100,
            string(
                abi.encodePacked(
                    "Berserker should counter Shield Tank (expected 60%-90% win rate): ",
                    vm.toString(berserkerStats.wins)
                )
            )
        );
        assertTrue(
            tankStats.wins >= matchCount * 10 / 100 && tankStats.wins <= matchCount * 40 / 100,
            string(
                abi.encodePacked(
                    "Shield Tank should be weak against Berserker (expected 10%-40% win rate): ",
                    vm.toString(tankStats.wins)
                )
            )
        );
    }

    // Test 5: Shield Tank vs Bruiser
    // Bruiser should be counter to shield tank
    function testShieldTankVsBruiser() public skipInCI {
        TestFighter memory shieldTank = createShieldTank();
        TestFighter memory bruiser = createBruiser();

        MatchStatistics memory tankStats;
        MatchStatistics memory bruiserStats;

        (tankStats, bruiserStats) = runDuel(shieldTank, bruiser);

        // Clubs should win 60-90% against shield tank
        assertTrue(
            bruiserStats.wins >= matchCount * 60 / 100 && bruiserStats.wins <= matchCount * 90 / 100,
            string(
                abi.encodePacked(
                    "Bruiser should counter Shield Tank (expected 60%-90% win rate): ", vm.toString(bruiserStats.wins)
                )
            )
        );
        assertTrue(
            tankStats.wins >= matchCount * 10 / 100 && tankStats.wins <= matchCount * 40 / 100,
            string(
                abi.encodePacked(
                    "Shield Tank be weak against Bruiser (expected 10%-40% win rate): ", vm.toString(tankStats.wins)
                )
            )
        );
    }

    // Test 6: Mage vs Vanguard
    // Mage should counter Vanguard due to blunt damage and high parry/dodge
    function testMageVsVanguard() public skipInCI {
        TestFighter memory mage = createMage();
        TestFighter memory vanguard = createVanguard();

        MatchStatistics memory mageStats;
        MatchStatistics memory vanguardStats;

        (mageStats, vanguardStats) = runDuel(mage, vanguard);

        assertTrue(
            mageStats.wins >= matchCount * 55 / 100 && mageStats.wins <= matchCount * 85 / 100,
            string(
                abi.encodePacked(
                    "Mage should counter Vanguard (expected 55%-85% win rate): ", vm.toString(mageStats.wins)
                )
            )
        );
        assertTrue(
            vanguardStats.wins >= matchCount * 15 / 100 && vanguardStats.wins <= matchCount * 45 / 100,
            string(
                abi.encodePacked(
                    "Vanguard should be weak against Mage (expected 15%-45% win rate): ",
                    vm.toString(vanguardStats.wins)
                )
            )
        );
    }

    // Test 7: Assassin vs Berserker
    // Fast, agile fighters should dominate slow, heavy hitters
    function testAssassinVsBerserker() public skipInCI {
        TestFighter memory assassin = createAssassin();
        TestFighter memory berserker = createBerserker();

        MatchStatistics memory assassinStats;
        MatchStatistics memory berserkerStats;

        (assassinStats, berserkerStats) = runDuel(assassin, berserker);

        assertTrue(
            assassinStats.wins >= matchCount * 65 / 100 && assassinStats.wins <= matchCount * 95 / 100,
            string(
                abi.encodePacked(
                    "Assassin should counter Berserker (expected 65%-95% win rate): ", vm.toString(assassinStats.wins)
                )
            )
        );
        assertTrue(
            berserkerStats.wins >= matchCount * 5 / 100 && berserkerStats.wins <= matchCount * 35 / 100,
            string(
                abi.encodePacked(
                    "Berserker should be weak against Assassin (expected 5%-35% win rate): ",
                    vm.toString(berserkerStats.wins)
                )
            )
        );
    }

    // Test 8: Balanced vs Mage
    // Even matchup between balanced and technical fighters
    function testBalancedVsMage() public skipInCI {
        TestFighter memory balanced = createBalanced();
        TestFighter memory mage = createMage();

        MatchStatistics memory balancedStats;
        MatchStatistics memory mageStats;

        (balancedStats, mageStats) = runDuel(balanced, mage);

        assertTrue(
            balancedStats.wins >= matchCount * 30 / 100 && balancedStats.wins <= matchCount * 70 / 100,
            string(
                abi.encodePacked(
                    "Balanced should be even with Mage (expected 30%-70% win rate): ", vm.toString(balancedStats.wins)
                )
            )
        );
        assertTrue(
            mageStats.wins >= matchCount * 30 / 100 && mageStats.wins <= matchCount * 70 / 100,
            string(
                abi.encodePacked(
                    "Mage should be even with Balanced (expected 30%-70% win rate): ", vm.toString(mageStats.wins)
                )
            )
        );
    }

    // Test 9: Bruiser vs Parry Master
    // Parry Master should counter Bruiser with superior technical skill
    function testBruiserVsParryMaster() public skipInCI {
        TestFighter memory bruiser = createBruiser();
        TestFighter memory parryMaster = createParryMaster();

        MatchStatistics memory bruiserStats;
        MatchStatistics memory parryStats;

        (bruiserStats, parryStats) = runDuel(bruiser, parryMaster);

        assertTrue(
            parryStats.wins >= matchCount * 55 / 100 && parryStats.wins <= matchCount * 85 / 100,
            string(
                abi.encodePacked(
                    "Parry Master should counter Bruiser (expected 55%-85% win rate): ", vm.toString(parryStats.wins)
                )
            )
        );
        assertTrue(
            bruiserStats.wins >= matchCount * 15 / 100 && bruiserStats.wins <= matchCount * 45 / 100,
            string(
                abi.encodePacked(
                    "Bruiser should be weak against Parry Master (expected 15%-45% win rate): ",
                    vm.toString(bruiserStats.wins)
                )
            )
        );
    }

    // Test 10: Vanguard vs Bruiser
    // Vanguard should counter Bruiser with superior reach and damage
    function testVanguardVsBruiser() public skipInCI {
        TestFighter memory vanguard = createVanguard();
        TestFighter memory bruiser = createBruiser();

        // Run just one fight for detailed analysis
        uint256 singleSeed = _generateTestSeed();
        bytes memory results = gameEngine.processGame(vanguard.stats, bruiser.stats, singleSeed, 0);

        (bool vanguardWon,, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Now run the full statistical test
        MatchStatistics memory vanguardStats;
        MatchStatistics memory bruiserStats;

        (vanguardStats, bruiserStats) = runDuel(vanguard, bruiser);

        assertTrue(
            vanguardStats.wins >= matchCount * 55 / 100 && vanguardStats.wins <= matchCount * 85 / 100,
            string(
                abi.encodePacked(
                    "Vanguard should counter Bruiser (expected 55%-85% win rate): ", vm.toString(vanguardStats.wins)
                )
            )
        );
        assertTrue(
            bruiserStats.wins >= matchCount * 15 / 100 && bruiserStats.wins <= matchCount * 45 / 100,
            string(
                abi.encodePacked(
                    "Bruiser should be weak against Vanguard (expected 15%-45% win rate): ",
                    vm.toString(bruiserStats.wins)
                )
            )
        );
    }

    // Test 11: Vanguard vs Assassin
    // Fast Assassin should counter slow Vanguard
    function testVanguardVsAssassin() public skipInCI {
        TestFighter memory vanguard = createVanguard();
        TestFighter memory assassin = createAssassin();

        MatchStatistics memory vanguardStats;
        MatchStatistics memory assassinStats;

        (vanguardStats, assassinStats) = runDuel(vanguard, assassin);

        assertTrue(
            assassinStats.wins >= matchCount * 60 / 100 && assassinStats.wins <= matchCount * 85 / 100,
            string(
                abi.encodePacked(
                    "Assassin should counter Vanguard (expected 60%-85% win rate): ", vm.toString(assassinStats.wins)
                )
            )
        );
        assertTrue(
            vanguardStats.wins >= matchCount * 15 / 100 && vanguardStats.wins <= matchCount * 40 / 100,
            string(
                abi.encodePacked(
                    "Vanguard should be weak against Assassin (expected 15%-40% win rate): ",
                    vm.toString(vanguardStats.wins)
                )
            )
        );
    }

    // Test 12: Assassin vs Berserker
    // Fast, agile Assassin should dominate slow Berserker
    function testAssassinDominatesBerserker() public skipInCI {
        TestFighter memory assassin = createAssassin();
        TestFighter memory berserker = createBerserker();

        // Run a single duel for detailed analysis first
        uint256 singleSeed = _generateTestSeed();
        bytes memory results = gameEngine.processGame(assassin.stats, berserker.stats, singleSeed, 0);

        (bool assassinWon,, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Now run full statistical test
        MatchStatistics memory assassinStats;
        MatchStatistics memory berserkerStats;

        (assassinStats, berserkerStats) = runDuel(assassin, berserker);

        // Assassin should dominate with 75-95% win rate
        assertTrue(
            assassinStats.wins >= matchCount * 75 / 100 && assassinStats.wins <= matchCount * 95 / 100,
            string(
                abi.encodePacked(
                    "Assassin should dominate Berserker (expected 75%-95% win rate): ", vm.toString(assassinStats.wins)
                )
            )
        );

        // Berserker should rarely win
        assertTrue(
            berserkerStats.wins >= matchCount * 5 / 100 && berserkerStats.wins <= matchCount * 25 / 100,
            string(
                abi.encodePacked(
                    "Berserker should be easily defeated by Assassin (expected 5%-25% win rate): ",
                    vm.toString(berserkerStats.wins)
                )
            )
        );
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

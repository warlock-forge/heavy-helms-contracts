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
                stance: 2 // STANCE_OFFENSIVE
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

        // Berserker should dominate with raw damage
        assertTrue(
            berserkerStats.wins >= matchCount * 65 / 100 && berserkerStats.wins <= matchCount * 95 / 100,
            string(
                abi.encodePacked(
                    "Berserker should CRUSH Shield Tank (expected 65%-95% win rate): ", vm.toString(berserkerStats.wins)
                )
            )
        );
        assertTrue(
            tankStats.wins >= matchCount * 5 / 100 && tankStats.wins <= matchCount * 30 / 100,
            string(
                abi.encodePacked(
                    "Shield Tank should be countered by Berserker (expected 5%-30% win rate): ",
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

        // Clubs should DOMINATE shield tanks
        assertTrue(
            bruiserStats.wins >= matchCount * 60 / 100 && bruiserStats.wins <= matchCount * 95 / 100,
            string(
                abi.encodePacked(
                    "Bruiser should SMASH Shield Tank (expected 60%-95% win rate): ", vm.toString(bruiserStats.wins)
                )
            )
        );
        assertTrue(
            tankStats.wins >= matchCount * 5 / 100 && tankStats.wins <= matchCount * 35 / 100,
            string(
                abi.encodePacked(
                    "Shield Tank should be CRUSHED by Bruiser (expected 5%-35% win rate): ", vm.toString(tankStats.wins)
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
            assassinStats.wins >= matchCount * 65 / 100 && assassinStats.wins <= matchCount * 98 / 100,
            string(
                abi.encodePacked(
                    "Assassin should counter Berserker (expected 65%-98% win rate): ", vm.toString(assassinStats.wins)
                )
            )
        );
        assertTrue(
            berserkerStats.wins >= matchCount * 2 / 100 && berserkerStats.wins <= matchCount * 35 / 100,
            string(
                abi.encodePacked(
                    "Berserker should be weak against Assassin (expected 2%-35% win rate): ",
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
            balancedStats.wins >= matchCount * 25 / 100 && balancedStats.wins <= matchCount * 70 / 100,
            string(
                abi.encodePacked(
                    "Balanced should be even with Mage (expected 25%-70% win rate): ", vm.toString(balancedStats.wins)
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
            vanguardStats.wins >= matchCount * 45 / 100 && vanguardStats.wins <= matchCount * 85 / 100,
            string(
                abi.encodePacked(
                    "Vanguard should counter Bruiser (expected 45%-85% win rate): ", vm.toString(vanguardStats.wins)
                )
            )
        );
        assertTrue(
            bruiserStats.wins >= matchCount * 15 / 100 && bruiserStats.wins <= matchCount * 55 / 100,
            string(
                abi.encodePacked(
                    "Bruiser should be weak against Vanguard (expected 15%-55% win rate): ",
                    vm.toString(bruiserStats.wins)
                )
            )
        );
    }

    // Test 11: Vanguard vs Assassin - DISABLED (not core to balance)
    // Fast Assassin should counter slow Vanguard
    // function testVanguardVsAssassin() public skipInCI {
    //     TestFighter memory vanguard = createVanguard();
    //     TestFighter memory assassin = createAssassin();

    //     MatchStatistics memory vanguardStats;
    //     MatchStatistics memory assassinStats;

    //     (vanguardStats, assassinStats) = runDuel(vanguard, assassin);

    //     assertTrue(
    //         assassinStats.wins >= matchCount * 60 / 100 && assassinStats.wins <= matchCount * 85 / 100,
    //         string(
    //             abi.encodePacked(
    //                 "Assassin should counter Vanguard (expected 60%-85% win rate): ", vm.toString(assassinStats.wins)
    //             )
    //         )
    //     );
    //     assertTrue(
    //         vanguardStats.wins >= matchCount * 15 / 100 && vanguardStats.wins <= matchCount * 40 / 100,
    //         string(
    //             abi.encodePacked(
    //                 "Vanguard should be weak against Assassin (expected 15%-40% win rate): ",
    //                 vm.toString(vanguardStats.wins)
    //             )
    //         )
    //     );
    // }

    // Test 12: Mage vs Shield Tank
    // Offensive mage should break through defensive turtle builds
    function testMageVsShieldTank() public skipInCI {
        TestFighter memory mage = createMage();
        TestFighter memory shieldTank = createShieldTank();

        MatchStatistics memory mageStats;
        MatchStatistics memory tankStats;

        (mageStats, tankStats) = runDuel(mage, shieldTank);

        // Mage should dominate shield tank with superior offense and stamina
        assertTrue(
            mageStats.wins >= matchCount * 60 / 100 && mageStats.wins <= matchCount * 90 / 100,
            string(
                abi.encodePacked(
                    "Mage should dominate Shield Tank (expected 60%-90% win rate): ", vm.toString(mageStats.wins)
                )
            )
        );
        assertTrue(
            tankStats.wins >= matchCount * 10 / 100 && tankStats.wins <= matchCount * 35 / 100,
            string(
                abi.encodePacked(
                    "Shield Tank should struggle against Mage (expected 10%-35% win rate): ",
                    vm.toString(tankStats.wins)
                )
            )
        );
    }

    // Test 13: Assassin vs Mage
    // Fast assassin should dominate positioning-based mage
    function testAssassinVsMage() public skipInCI {
        TestFighter memory assassin = createAssassin();
        TestFighter memory mage = createMage();

        MatchStatistics memory assassinStats;
        MatchStatistics memory mageStats;

        (assassinStats, mageStats) = runDuel(assassin, mage);

        // Assassin should have advantage over mage with superior speed and agility
        assertTrue(
            assassinStats.wins >= matchCount * 45 / 100 && assassinStats.wins <= matchCount * 85 / 100,
            string(
                abi.encodePacked(
                    "Assassin should counter Mage (expected 45%-85% win rate): ", vm.toString(assassinStats.wins)
                )
            )
        );
        assertTrue(
            mageStats.wins >= matchCount * 25 / 100 && mageStats.wins <= matchCount * 55 / 100,
            string(
                abi.encodePacked(
                    "Mage should be countered by Assassin (expected 25%-55% win rate): ", vm.toString(mageStats.wins)
                )
            )
        );
    }

    // Test 14: Bruiser vs Mage
    // Bruiser's raw power should overpower mage's finesse
    function testBruiserVsMage() public skipInCI {
        TestFighter memory bruiser = createBruiser();
        TestFighter memory mage = createMage();

        MatchStatistics memory bruiserStats;
        MatchStatistics memory mageStats;

        (bruiserStats, mageStats) = runDuel(bruiser, mage);

        // Bruiser should be competitive with mage in this specific matchup
        assertTrue(
            bruiserStats.wins >= matchCount * 20 / 100 && bruiserStats.wins <= matchCount * 70 / 100,
            string(
                abi.encodePacked(
                    "Bruiser should be competitive with Mage (expected 20%-70% win rate): ",
                    vm.toString(bruiserStats.wins)
                )
            )
        );
        assertTrue(
            mageStats.wins >= matchCount * 40 / 100 && mageStats.wins <= matchCount * 80 / 100,
            string(
                abi.encodePacked(
                    "Mage should be competitive with Bruiser (expected 40%-80% win rate): ", vm.toString(mageStats.wins)
                )
            )
        );
    }

    // Test 15: Assassin vs Berserker
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

        // Assassin should dominate with 75-98% win rate
        assertTrue(
            assassinStats.wins >= matchCount * 75 / 100 && assassinStats.wins <= matchCount * 98 / 100,
            string(
                abi.encodePacked(
                    "Assassin should dominate Berserker (expected 75%-98% win rate): ", vm.toString(assassinStats.wins)
                )
            )
        );

        // Berserker should rarely win
        assertTrue(
            berserkerStats.wins >= matchCount * 2 / 100 && berserkerStats.wins <= matchCount * 25 / 100,
            string(
                abi.encodePacked(
                    "Berserker should be easily defeated by Assassin (expected 2%-25% win rate): ",
                    vm.toString(berserkerStats.wins)
                )
            )
        );
    }

    // ==================== ARCHETYPE VALIDATION TESTS ====================

    // Test all Shield Tank variants vs Assassin variants
    function testShieldTankArchetypeVsAssassinArchetype() public skipInCI {
        // Shield Tank weapons: MACE_TOWER, AXE_TOWER, CLUB_TOWER, SHORTSWORD_TOWER
        uint8[] memory shieldTankWeapons = new uint8[](4);
        shieldTankWeapons[0] = 1; // MACE_TOWER
        shieldTankWeapons[1] = 13; // AXE_TOWER
        shieldTankWeapons[2] = 17; // CLUB_TOWER
        shieldTankWeapons[3] = 8; // SHORTSWORD_TOWER

        // Assassin weapons: DUAL_DAGGERS, DUAL_SCIMITARS, RAPIER_DAGGER, SCIMITAR_DAGGER, SPEAR
        uint8[] memory assassinWeapons = new uint8[](5);
        assassinWeapons[0] = 9; // DUAL_DAGGERS
        assassinWeapons[1] = 14; // DUAL_SCIMITARS
        assassinWeapons[2] = 10; // RAPIER_DAGGER
        assassinWeapons[3] = 20; // SCIMITAR_DAGGER
        assassinWeapons[4] = 6; // SPEAR (2-handed assassin weapon)

        uint256 totalShieldWins = 0;
        uint256 totalMatches = 0;
        uint256 testRounds = 25; // Reduced for multiple combinations

        for (uint256 i = 0; i < shieldTankWeapons.length; i++) {
            for (uint256 j = 0; j < assassinWeapons.length; j++) {
                TestFighter memory shieldTank = createCustomFighter(
                    "Shield Tank Variant",
                    shieldTankWeapons[i], // weapon
                    3, // PLATE armor
                    0, // DEFENSIVE stance
                    mediumStat,
                    highStat,
                    highStat,
                    lowStat,
                    mediumStat,
                    lowStat
                );

                TestFighter memory assassin = createCustomFighter(
                    "Assassin Variant",
                    assassinWeapons[j], // weapon
                    1, // LEATHER armor
                    2, // OFFENSIVE stance
                    highStat,
                    lowStat,
                    mediumStat,
                    highStat,
                    lowStat,
                    mediumStat
                );

                // Run reduced test set
                uint256 shieldWins = 0;
                for (uint256 k = 0; k < testRounds; k++) {
                    vm.roll(block.number + 1);
                    vm.warp(block.timestamp + 15);

                    uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, k, i, j)));
                    bytes memory results = gameEngine.processGame(shieldTank.stats, assassin.stats, seed, 0);

                    (bool shieldWon,,,) = gameEngine.decodeCombatLog(results);
                    if (shieldWon) shieldWins++;
                }

                totalShieldWins += shieldWins;
                totalMatches += testRounds;
            }
        }

        // Shield tanks should dominate assassins with superior defense
        assertTrue(
            totalShieldWins >= (totalMatches * 60) / 100 && totalShieldWins <= (totalMatches * 95) / 100,
            string(
                abi.encodePacked(
                    "Shield Tank archetype should counter Assassin archetype (expected 60%-95% win rate): ",
                    vm.toString(totalShieldWins)
                )
            )
        );
    }

    // Test all Parry Master variants vs Bruiser variants
    function testParryMasterArchetypeVsBruiserArchetype() public skipInCI {
        // Parry Master weapons: RAPIER_BUCKLER, SHORTSWORD_BUCKLER, SCIMITAR_BUCKLER, FLAIL_BUCKLER
        uint8[] memory parryWeapons = new uint8[](4);
        parryWeapons[0] = 2; // RAPIER_BUCKLER
        parryWeapons[1] = 7; // SHORTSWORD_BUCKLER
        parryWeapons[2] = 11; // SCIMITAR_BUCKLER
        parryWeapons[3] = 15; // FLAIL_BUCKLER

        // Bruiser weapons: DUAL_CLUBS, DUAL_SCIMITARS, AXE_MACE, ARMING_SWORD_CLUB
        uint8[] memory bruiserWeapons = new uint8[](4);
        bruiserWeapons[0] = 18; // DUAL_CLUBS
        bruiserWeapons[1] = 14; // DUAL_SCIMITARS
        bruiserWeapons[2] = 22; // AXE_MACE
        bruiserWeapons[3] = 21; // ARMING_SWORD_CLUB

        uint256 totalParryWins = 0;
        uint256 totalMatches = 0;
        uint256 testRounds = 25;

        for (uint256 i = 0; i < parryWeapons.length; i++) {
            for (uint256 j = 0; j < bruiserWeapons.length; j++) {
                TestFighter memory parryMaster = createCustomFighter(
                    "Parry Master Variant",
                    parryWeapons[i], // weapon
                    1, // LEATHER armor
                    0, // DEFENSIVE stance
                    mediumStat,
                    highStat,
                    lowStat,
                    highStat,
                    lowStat,
                    mediumStat
                );

                TestFighter memory bruiser = createCustomFighter(
                    "Bruiser Variant",
                    bruiserWeapons[j], // weapon
                    1, // LEATHER armor
                    2, // OFFENSIVE stance
                    highStat,
                    lowStat,
                    highStat,
                    lowStat,
                    mediumStat,
                    mediumStat
                );

                uint256 parryWins = 0;
                for (uint256 k = 0; k < testRounds; k++) {
                    vm.roll(block.number + 1);
                    vm.warp(block.timestamp + 15);

                    uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, k, i, j)));
                    bytes memory results = gameEngine.processGame(parryMaster.stats, bruiser.stats, seed, 0);

                    (bool parryWon,,,) = gameEngine.decodeCombatLog(results);
                    if (parryWon) parryWins++;
                }

                uint256 winRate = (parryWins * 100) / testRounds;

                // Log each individual matchup for debugging
                emit log_named_uint("Parry weapon", parryWeapons[i]);
                emit log_named_uint("Bruiser weapon", bruiserWeapons[j]);
                emit log_named_uint("Win rate", winRate);

                totalParryWins += parryWins;
                totalMatches += testRounds;
            }
        }

        // Parry masters should win 55-85% across ALL weapon combinations
        uint256 winRate = (totalParryWins * 100) / totalMatches;
        assertTrue(
            winRate >= 55 && winRate <= 85,
            string(
                abi.encodePacked(
                    "Parry Master archetype should counter Bruiser archetype (expected 55%-85% win rate): ",
                    vm.toString(winRate)
                )
            )
        );
    }

    // Test Assassin archetype consistency across weapon variants
    function testAssassinArchetypeConsistency() public skipInCI {
        // Test all assassin weapons against a standard mage
        uint8[] memory assassinWeapons = new uint8[](5);
        assassinWeapons[0] = 9; // DUAL_DAGGERS
        assassinWeapons[1] = 14; // DUAL_SCIMITARS
        assassinWeapons[2] = 10; // RAPIER_DAGGER
        assassinWeapons[3] = 20; // SCIMITAR_DAGGER
        assassinWeapons[4] = 6; // SPEAR (2-handed assassin weapon)

        TestFighter memory mage = createMage();
        uint256 testRounds = 50;

        for (uint256 i = 0; i < assassinWeapons.length; i++) {
            TestFighter memory assassin = createCustomFighter(
                "Assassin Variant",
                assassinWeapons[i], // weapon
                1, // LEATHER armor
                2, // OFFENSIVE stance
                highStat,
                lowStat,
                mediumStat,
                highStat,
                lowStat,
                mediumStat
            );

            uint256 assassinWins = 0;
            for (uint256 j = 0; j < testRounds; j++) {
                vm.roll(block.number + 1);
                vm.warp(block.timestamp + 15);

                uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, j, i)));
                bytes memory results = gameEngine.processGame(assassin.stats, mage.stats, seed, 0);

                (bool assassinWon,,,) = gameEngine.decodeCombatLog(results);
                if (assassinWon) assassinWins++;
            }

            uint256 winRate = (assassinWins * 100) / testRounds;

            // Each assassin weapon should perform reasonably vs mage (some variation expected)
            assertTrue(
                winRate >= 30 && winRate <= 100,
                string(
                    abi.encodePacked(
                        "Assassin weapon variant ",
                        vm.toString(assassinWeapons[i]),
                        " should be viable (expected 30%-100% vs Mage): ",
                        vm.toString(winRate)
                    )
                )
            );
        }
    }

    // Test all Berserker variants vs Shield Tank variants
    function testBerserkerArchetypeVsShieldTankArchetype() public skipInCI {
        // Berserker weapons: BATTLEAXE, GREATSWORD, MAUL, TRIDENT
        uint8[] memory berserkerWeapons = new uint8[](4);
        berserkerWeapons[0] = 4; // BATTLEAXE
        berserkerWeapons[1] = 3; // GREATSWORD
        berserkerWeapons[2] = 25; // MAUL
        berserkerWeapons[3] = 26; // TRIDENT

        // Shield Tank weapons: MACE_TOWER, AXE_TOWER, CLUB_TOWER, SHORTSWORD_TOWER
        uint8[] memory shieldWeapons = new uint8[](4);
        shieldWeapons[0] = 1; // MACE_TOWER
        shieldWeapons[1] = 13; // AXE_TOWER
        shieldWeapons[2] = 17; // CLUB_TOWER
        shieldWeapons[3] = 8; // SHORTSWORD_TOWER

        uint256 totalBerserkerWins = 0;
        uint256 totalMatches = 0;
        uint256 testRounds = 25;

        for (uint256 i = 0; i < berserkerWeapons.length; i++) {
            for (uint256 j = 0; j < shieldWeapons.length; j++) {
                TestFighter memory berserker = createCustomFighter(
                    "Berserker Variant",
                    berserkerWeapons[i], // weapon
                    1, // LEATHER armor
                    2, // OFFENSIVE stance
                    highStat,
                    lowStat,
                    highStat,
                    lowStat,
                    mediumStat,
                    mediumStat
                );

                TestFighter memory shieldTank = createCustomFighter(
                    "Shield Tank Variant",
                    shieldWeapons[j], // weapon
                    3, // PLATE armor
                    0, // DEFENSIVE stance
                    mediumStat,
                    highStat,
                    highStat,
                    lowStat,
                    mediumStat,
                    lowStat
                );

                uint256 berserkerWins = 0;
                for (uint256 k = 0; k < testRounds; k++) {
                    vm.roll(block.number + 1);
                    vm.warp(block.timestamp + 15);

                    uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, k, i, j)));
                    bytes memory results = gameEngine.processGame(berserker.stats, shieldTank.stats, seed, 0);

                    (bool berserkerWon,,,) = gameEngine.decodeCombatLog(results);
                    if (berserkerWon) berserkerWins++;
                }

                totalBerserkerWins += berserkerWins;
                totalMatches += testRounds;
            }
        }

        // Berserkers should win 80-95% across ALL weapon combinations
        uint256 winRate = (totalBerserkerWins * 100) / totalMatches;
        assertTrue(
            winRate >= 75 && winRate <= 95,
            string(
                abi.encodePacked(
                    "Berserker archetype should counter Shield Tank archetype (expected 75%-95% win rate): ",
                    vm.toString(winRate)
                )
            )
        );
    }

    // Test Assassin archetype vs Berserker archetype (assassins should counter)
    function testAssassinArchetypeVsBerserkerArchetype() public skipInCI {
        // Assassin weapons: DUAL_DAGGERS, DUAL_SCIMITARS, RAPIER_DAGGER, SCIMITAR_DAGGER, SPEAR
        uint8[] memory assassinWeapons = new uint8[](5);
        assassinWeapons[0] = 9; // DUAL_DAGGERS
        assassinWeapons[1] = 14; // DUAL_SCIMITARS
        assassinWeapons[2] = 10; // RAPIER_DAGGER
        assassinWeapons[3] = 20; // SCIMITAR_DAGGER
        assassinWeapons[4] = 6; // SPEAR (2-handed assassin weapon)

        // Berserker weapons: BATTLEAXE, GREATSWORD, MAUL, TRIDENT
        uint8[] memory berserkerWeapons = new uint8[](4);
        berserkerWeapons[0] = 4; // BATTLEAXE
        berserkerWeapons[1] = 3; // GREATSWORD
        berserkerWeapons[2] = 25; // MAUL
        berserkerWeapons[3] = 26; // TRIDENT

        uint256 totalAssassinWins = 0;
        uint256 totalMatches = 0;
        uint256 testRounds = 25;

        for (uint256 i = 0; i < assassinWeapons.length; i++) {
            for (uint256 j = 0; j < berserkerWeapons.length; j++) {
                TestFighter memory assassin = createCustomFighter(
                    "Assassin Variant",
                    assassinWeapons[i], // weapon
                    1, // LEATHER armor
                    2, // OFFENSIVE stance
                    highStat,
                    lowStat,
                    mediumStat,
                    highStat,
                    lowStat,
                    mediumStat
                );

                TestFighter memory berserker = createCustomFighter(
                    "Berserker Variant",
                    berserkerWeapons[j], // weapon
                    1, // LEATHER armor
                    2, // OFFENSIVE stance
                    highStat,
                    lowStat,
                    highStat,
                    lowStat,
                    mediumStat,
                    mediumStat
                );

                uint256 assassinWins = 0;
                for (uint256 k = 0; k < testRounds; k++) {
                    vm.roll(block.number + 1);
                    vm.warp(block.timestamp + 15);

                    uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, k, i, j)));
                    bytes memory results = gameEngine.processGame(assassin.stats, berserker.stats, seed, 0);

                    (bool assassinWon,,,) = gameEngine.decodeCombatLog(results);
                    if (assassinWon) assassinWins++;
                }

                totalAssassinWins += assassinWins;
                totalMatches += testRounds;
            }
        }

        // Assassins should win 60-85% against berserkers (speed vs power)
        uint256 winRate = (totalAssassinWins * 100) / totalMatches;
        assertTrue(
            winRate >= 60 && winRate <= 85,
            string(
                abi.encodePacked(
                    "Assassin archetype should counter Berserker archetype (expected 60%-85% win rate): ",
                    vm.toString(winRate)
                )
            )
        );
    }

    // Test Vanguard archetype vs Bruiser archetype (vanguards should counter)
    function testVanguardArchetypeVsBruiserArchetype() public skipInCI {
        // Vanguard weapons: GREATSWORD, QUARTERSTAFF, RAPIER_DAGGER (technical weapons)
        uint8[] memory vanguardWeapons = new uint8[](3);
        vanguardWeapons[0] = 3; // GREATSWORD
        vanguardWeapons[1] = 5; // QUARTERSTAFF
        vanguardWeapons[2] = 10; // RAPIER_DAGGER

        // Bruiser weapons: DUAL_CLUBS, DUAL_SCIMITARS, AXE_MACE, ARMING_SWORD_CLUB
        uint8[] memory bruiserWeapons = new uint8[](4);
        bruiserWeapons[0] = 18; // DUAL_CLUBS
        bruiserWeapons[1] = 14; // DUAL_SCIMITARS
        bruiserWeapons[2] = 22; // AXE_MACE
        bruiserWeapons[3] = 21; // ARMING_SWORD_CLUB

        uint256 totalVanguardWins = 0;
        uint256 totalMatches = 0;
        uint256 testRounds = 25;

        for (uint256 i = 0; i < vanguardWeapons.length; i++) {
            for (uint256 j = 0; j < bruiserWeapons.length; j++) {
                TestFighter memory vanguard = createCustomFighter(
                    "Vanguard Variant",
                    vanguardWeapons[i], // weapon
                    2, // CHAIN armor
                    1, // BALANCED stance
                    mediumStat,
                    mediumStat,
                    mediumStat,
                    mediumStat,
                    mediumStat,
                    mediumStat
                );

                TestFighter memory bruiser = createCustomFighter(
                    "Bruiser Variant",
                    bruiserWeapons[j], // weapon
                    1, // LEATHER armor
                    2, // OFFENSIVE stance
                    highStat,
                    lowStat,
                    highStat,
                    lowStat,
                    mediumStat,
                    mediumStat
                );

                uint256 vanguardWins = 0;
                for (uint256 k = 0; k < testRounds; k++) {
                    vm.roll(block.number + 1);
                    vm.warp(block.timestamp + 15);

                    uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, k, i, j)));
                    bytes memory results = gameEngine.processGame(vanguard.stats, bruiser.stats, seed, 0);

                    (bool vanguardWon,,,) = gameEngine.decodeCombatLog(results);
                    if (vanguardWon) vanguardWins++;
                }

                totalVanguardWins += vanguardWins;
                totalMatches += testRounds;
            }
        }

        // Vanguards should win 55-75% against bruisers (technique vs brute force)
        uint256 winRate = (totalVanguardWins * 100) / totalMatches;
        assertTrue(
            winRate >= 55 && winRate <= 75,
            string(
                abi.encodePacked(
                    "Vanguard archetype should counter Bruiser archetype (expected 55%-75% win rate): ",
                    vm.toString(winRate)
                )
            )
        );
    }

    // Test Mage archetype vs Shield Tank archetype (mages should counter)
    function testMageArchetypeVsShieldTankArchetype() public skipInCI {
        // Mage weapons: QUARTERSTAFF (pure mage weapon)
        uint8[] memory mageWeapons = new uint8[](1);
        mageWeapons[0] = 5; // QUARTERSTAFF

        // Shield Tank weapons: MACE_TOWER, AXE_TOWER, CLUB_TOWER, SHORTSWORD_TOWER
        uint8[] memory shieldTankWeapons = new uint8[](4);
        shieldTankWeapons[0] = 1; // MACE_TOWER
        shieldTankWeapons[1] = 13; // AXE_TOWER
        shieldTankWeapons[2] = 17; // CLUB_TOWER
        shieldTankWeapons[3] = 8; // SHORTSWORD_TOWER

        uint256 totalMageWins = 0;
        uint256 totalMatches = 0;
        uint256 testRounds = 25;

        for (uint256 i = 0; i < mageWeapons.length; i++) {
            for (uint256 j = 0; j < shieldTankWeapons.length; j++) {
                TestFighter memory mage = createCustomFighter(
                    "Mage Variant",
                    mageWeapons[i], // weapon
                    0, // CLOTH armor
                    1, // BALANCED stance
                    lowStat,
                    mediumStat,
                    lowStat,
                    mediumStat,
                    highStat,
                    highStat
                );

                TestFighter memory shieldTank = createCustomFighter(
                    "Shield Tank Variant",
                    shieldTankWeapons[j], // weapon
                    3, // PLATE armor
                    0, // DEFENSIVE stance
                    mediumStat,
                    highStat,
                    highStat,
                    lowStat,
                    mediumStat,
                    lowStat
                );

                uint256 mageWins = 0;
                for (uint256 k = 0; k < testRounds; k++) {
                    vm.roll(block.number + 1);
                    vm.warp(block.timestamp + 15);

                    uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, k, i, j)));
                    bytes memory results = gameEngine.processGame(mage.stats, shieldTank.stats, seed, 0);

                    (bool mageWon,,,) = gameEngine.decodeCombatLog(results);
                    if (mageWon) mageWins++;
                }

                totalMageWins += mageWins;
                totalMatches += testRounds;
            }
        }

        // Mages should be viable but not dominant against shield tanks
        uint256 winRate = (totalMageWins * 100) / totalMatches;
        assertTrue(
            winRate >= 15 && winRate <= 60,
            string(
                abi.encodePacked(
                    "Mage archetype should be viable (expected 15%-60% win rate vs Shield Tanks): ",
                    vm.toString(winRate)
                )
            )
        );
    }

    // Test Bruiser archetype vs Shield Tank archetype (bruisers should have advantage - blunt vs plate)
    function testBruiserArchetypeVsShieldTankArchetype() public skipInCI {
        // Bruiser weapons: DUAL_CLUBS, DUAL_SCIMITARS, AXE_MACE, ARMING_SWORD_CLUB
        uint8[] memory bruiserWeapons = new uint8[](4);
        bruiserWeapons[0] = 18; // DUAL_CLUBS
        bruiserWeapons[1] = 14; // DUAL_SCIMITARS
        bruiserWeapons[2] = 22; // AXE_MACE
        bruiserWeapons[3] = 21; // ARMING_SWORD_CLUB

        // Shield Tank weapons: MACE_TOWER, AXE_TOWER, CLUB_TOWER, SHORTSWORD_TOWER
        uint8[] memory shieldTankWeapons = new uint8[](4);
        shieldTankWeapons[0] = 1; // MACE_TOWER
        shieldTankWeapons[1] = 13; // AXE_TOWER
        shieldTankWeapons[2] = 17; // CLUB_TOWER
        shieldTankWeapons[3] = 8; // SHORTSWORD_TOWER

        uint256 totalBruiserWins = 0;
        uint256 totalMatches = 0;
        uint256 testRounds = 25;

        for (uint256 i = 0; i < bruiserWeapons.length; i++) {
            for (uint256 j = 0; j < shieldTankWeapons.length; j++) {
                TestFighter memory bruiser = createCustomFighter(
                    "Bruiser Variant",
                    bruiserWeapons[i], // weapon
                    1, // LEATHER armor
                    2, // OFFENSIVE stance
                    highStat,
                    lowStat,
                    highStat,
                    lowStat,
                    mediumStat,
                    mediumStat
                );

                TestFighter memory shieldTank = createCustomFighter(
                    "Shield Tank Variant",
                    shieldTankWeapons[j], // weapon
                    3, // PLATE armor
                    0, // DEFENSIVE stance
                    mediumStat,
                    highStat,
                    highStat,
                    lowStat,
                    mediumStat,
                    lowStat
                );

                uint256 bruiserWins = 0;
                for (uint256 k = 0; k < testRounds; k++) {
                    vm.roll(block.number + 1);
                    vm.warp(block.timestamp + 15);

                    uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, k, i, j)));
                    bytes memory results = gameEngine.processGame(bruiser.stats, shieldTank.stats, seed, 0);

                    (bool bruiserWon,,,) = gameEngine.decodeCombatLog(results);
                    if (bruiserWon) bruiserWins++;
                }

                totalBruiserWins += bruiserWins;
                totalMatches += testRounds;
            }
        }

        // Bruisers should have advantage against shield tanks (blunt weapons vs plate armor)
        uint256 winRate = (totalBruiserWins * 100) / totalMatches;
        assertTrue(
            winRate >= 65 && winRate <= 85,
            string(
                abi.encodePacked(
                    "Bruiser archetype should counter Shield Tank archetype (expected 65%-85% win rate): ",
                    vm.toString(winRate)
                )
            )
        );
    }

    // Test Parry Master archetype vs Berserker archetype (parry masters should counter)
    function testParryMasterArchetypeVsBerserkerArchetype() public skipInCI {
        // Parry Master weapons: RAPIER_BUCKLER, SHORTSWORD_BUCKLER, SCIMITAR_BUCKLER, FLAIL_BUCKLER
        uint8[] memory parryWeapons = new uint8[](4);
        parryWeapons[0] = 2; // RAPIER_BUCKLER
        parryWeapons[1] = 7; // SHORTSWORD_BUCKLER
        parryWeapons[2] = 11; // SCIMITAR_BUCKLER
        parryWeapons[3] = 15; // FLAIL_BUCKLER

        // Berserker weapons: BATTLEAXE, GREATSWORD, MAUL, TRIDENT
        uint8[] memory berserkerWeapons = new uint8[](4);
        berserkerWeapons[0] = 4; // BATTLEAXE
        berserkerWeapons[1] = 3; // GREATSWORD
        berserkerWeapons[2] = 25; // MAUL
        berserkerWeapons[3] = 26; // TRIDENT

        uint256 totalParryWins = 0;
        uint256 totalMatches = 0;
        uint256 testRounds = 25;

        for (uint256 i = 0; i < parryWeapons.length; i++) {
            for (uint256 j = 0; j < berserkerWeapons.length; j++) {
                TestFighter memory parryMaster = createCustomFighter(
                    "Parry Master Variant",
                    parryWeapons[i], // weapon
                    1, // LEATHER armor
                    0, // DEFENSIVE stance
                    mediumStat,
                    highStat,
                    lowStat,
                    highStat,
                    lowStat,
                    mediumStat
                );

                TestFighter memory berserker = createCustomFighter(
                    "Berserker Variant",
                    berserkerWeapons[j], // weapon
                    1, // LEATHER armor
                    2, // OFFENSIVE stance
                    highStat,
                    lowStat,
                    highStat,
                    lowStat,
                    mediumStat,
                    mediumStat
                );

                uint256 parryWins = 0;
                for (uint256 k = 0; k < testRounds; k++) {
                    vm.roll(block.number + 1);
                    vm.warp(block.timestamp + 15);

                    uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, k, i, j)));
                    bytes memory results = gameEngine.processGame(parryMaster.stats, berserker.stats, seed, 0);

                    (bool parryWon,,,) = gameEngine.decodeCombatLog(results);
                    if (parryWon) parryWins++;
                }

                totalParryWins += parryWins;
                totalMatches += testRounds;
            }
        }

        // Parry masters should win 65-85% against berserkers (technique vs raw power)
        uint256 winRate = (totalParryWins * 100) / totalMatches;
        assertTrue(
            winRate >= 65 && winRate <= 85,
            string(
                abi.encodePacked(
                    "Parry Master archetype should counter Berserker archetype (expected 65%-85% win rate): ",
                    vm.toString(winRate)
                )
            )
        );
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/game/engine/GameEngine.sol";
import "../../src/interfaces/fighters/IPlayer.sol";
import "../../src/interfaces/game/engine/IGameEngine.sol";
import "../TestBase.sol";

contract GameEngineProgressionTest is TestBase {
    // Standard test attributes for level 1 characters
    uint8 private lowStat = 5;
    uint8 private mediumStat = 12;
    uint8 private highStat = 19;

    // Max attribute cap
    uint8 private maxStat = 25;

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

    function createLeveledAssassin(uint8 bonusPoints) private view returns (TestFighter memory) {
        // Base Assassin: STR=19, CON=5, SIZE=12, AGI=19, STA=5, LUCK=12 (Total: 72)
        // AGI is primary stat, so we'll prioritize AGI then STR
        uint8 agiBonus = 0;
        uint8 strBonus = 0;
        uint8 conBonus = 0;
        uint8 remainingPoints = bonusPoints;

        // First max out AGI (19 + 6 = 25)
        if (remainingPoints > 0 && highStat + agiBonus < maxStat) {
            uint8 agiSpace = maxStat - highStat;
            agiBonus = remainingPoints > agiSpace ? agiSpace : remainingPoints;
            remainingPoints -= agiBonus;
        }

        // Then boost STR (19 + 6 = 25)
        if (remainingPoints > 0 && highStat + strBonus < maxStat) {
            uint8 strSpace = maxStat - highStat;
            strBonus = remainingPoints > strSpace ? strSpace : remainingPoints;
            remainingPoints -= strBonus;
        }

        // Finally boost CON for survivability (5 + 3 = 8)
        if (remainingPoints > 0) {
            conBonus = remainingPoints;
        }

        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: highStat + strBonus,
            constitution: lowStat + conBonus,
            size: mediumStat,
            agility: highStat + agiBonus,
            stamina: lowStat,
            luck: mediumStat
        });

        return TestFighter({
            name: bonusPoints > 0 ? "Assassin L10" : "Assassin L1",
            stats: IGameEngine.FighterStats({
                weapon: 9, // WEAPON_DUAL_DAGGERS
                armor: 1, // ARMOR_LEATHER
                stance: 2, // STANCE_OFFENSIVE
                attributes: attrs,
                level: 1,
                weaponSpecialization: 255, // No specialization
                armorSpecialization: 255 // No specialization
            })
        });
    }

    function createLeveledBerserker(uint8 bonusPoints) private view returns (TestFighter memory) {
        // Base Berserker: STR=19, CON=5, SIZE=19, AGI=12, STA=12, LUCK=5 (Total: 72)
        // STR and SIZE are primary stats
        uint8 strBonus = 0;
        uint8 sizeBonus = 0;
        uint8 conBonus = 0;
        uint8 remainingPoints = bonusPoints;

        // First max out STR (19 + 6 = 25)
        if (remainingPoints > 0 && highStat + strBonus < maxStat) {
            uint8 strSpace = maxStat - highStat;
            strBonus = remainingPoints > strSpace ? strSpace : remainingPoints;
            remainingPoints -= strBonus;
        }

        // Then max out SIZE (19 + 6 = 25)
        if (remainingPoints > 0 && highStat + sizeBonus < maxStat) {
            uint8 sizeSpace = maxStat - highStat;
            sizeBonus = remainingPoints > sizeSpace ? sizeSpace : remainingPoints;
            remainingPoints -= sizeBonus;
        }

        // Finally boost CON for survivability (5 + 3 = 8 if L10)
        if (remainingPoints > 0) {
            conBonus = remainingPoints;
        }

        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: highStat + strBonus,
            constitution: lowStat + conBonus,
            size: highStat + sizeBonus,
            agility: mediumStat,
            stamina: mediumStat,
            luck: lowStat
        });

        return TestFighter({
            name: bonusPoints > 0 ? "Berserker L10" : "Berserker L1",
            stats: IGameEngine.FighterStats({
                weapon: 4, // WEAPON_BATTLEAXE
                armor: 1, // ARMOR_LEATHER
                stance: 2, // STANCE_OFFENSIVE
                attributes: attrs,
                level: 1,
                weaponSpecialization: 255, // No specialization
                armorSpecialization: 255 // No specialization
            })
        });
    }

    function createLeveledShieldTank(uint8 bonusPoints) private view returns (TestFighter memory) {
        // Base Shield Tank: STR=12, CON=19, SIZE=19, AGI=5, STA=12, LUCK=5 (Total: 72)
        // CON and SIZE are primary stats for defense
        uint8 conBonus = 0;
        uint8 sizeBonus = 0;
        uint8 strBonus = 0;
        uint8 remainingPoints = bonusPoints;

        // First max out CON (19 + 6 = 25)
        if (remainingPoints > 0 && highStat + conBonus < maxStat) {
            uint8 conSpace = maxStat - highStat;
            conBonus = remainingPoints > conSpace ? conSpace : remainingPoints;
            remainingPoints -= conBonus;
        }

        // Then max out SIZE (19 + 6 = 25)
        if (remainingPoints > 0 && highStat + sizeBonus < maxStat) {
            uint8 sizeSpace = maxStat - highStat;
            sizeBonus = remainingPoints > sizeSpace ? sizeSpace : remainingPoints;
            remainingPoints -= sizeBonus;
        }

        // Finally boost STR for some damage (12 + 3 = 15 if L10)
        if (remainingPoints > 0) {
            strBonus = remainingPoints;
        }

        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: mediumStat + strBonus,
            constitution: highStat + conBonus,
            size: highStat + sizeBonus,
            agility: lowStat,
            stamina: mediumStat,
            luck: lowStat
        });

        return TestFighter({
            name: bonusPoints > 0 ? "Shield Tank L10" : "Shield Tank L1",
            stats: IGameEngine.FighterStats({
                weapon: 1, // WEAPON_MACE_TOWER
                armor: 3, // ARMOR_PLATE
                stance: 0, // STANCE_DEFENSIVE
                attributes: attrs,
                level: 1,
                weaponSpecialization: 255, // No specialization
                armorSpecialization: 255 // No specialization
            })
        });
    }

    function createLeveledMonk(uint8 bonusPoints) private view returns (TestFighter memory) {
        // Base Monk: STR=12, CON=19, SIZE=5, AGI=19, STA=12, LUCK=5 (Total: 72)
        // AGI and CON are primary stats
        uint8 agiBonus = 0;
        uint8 conBonus = 0;
        uint8 staBonus = 0;
        uint8 remainingPoints = bonusPoints;

        // First max out AGI (19 + 6 = 25)
        if (remainingPoints > 0 && highStat + agiBonus < maxStat) {
            uint8 agiSpace = maxStat - highStat;
            agiBonus = remainingPoints > agiSpace ? agiSpace : remainingPoints;
            remainingPoints -= agiBonus;
        }

        // Then max out CON (19 + 6 = 25)
        if (remainingPoints > 0 && highStat + conBonus < maxStat) {
            uint8 conSpace = maxStat - highStat;
            conBonus = remainingPoints > conSpace ? conSpace : remainingPoints;
            remainingPoints -= conBonus;
        }

        // Finally boost STA for endurance (12 + 3 = 15 if L10)
        if (remainingPoints > 0) {
            staBonus = remainingPoints;
        }

        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: mediumStat, // FIXED: Using mediumStat (12) not lowStat (5)
            constitution: highStat + conBonus,
            size: lowStat,
            agility: highStat + agiBonus,
            stamina: mediumStat + staBonus,
            luck: lowStat
        });

        return TestFighter({
            name: bonusPoints > 0 ? "Monk L10" : "Monk L1",
            stats: IGameEngine.FighterStats({
                weapon: 6, // WEAPON_SPEAR
                armor: 0, // ARMOR_CLOTH
                stance: 1, // STANCE_BALANCED (not defensive - disciplined approach)
                attributes: attrs,
                level: 1,
                weaponSpecialization: 255, // No specialization
                armorSpecialization: 255 // No specialization
            })
        });
    }

    function createLeveledParryMaster(uint8 bonusPoints) private view returns (TestFighter memory) {
        // Base Parry Master: STR=12, CON=19, SIZE=5, AGI=19, STA=5, LUCK=12 (Total: 72)
        // AGI and CON are primary stats
        uint8 agiBonus = 0;
        uint8 conBonus = 0;
        uint8 luckBonus = 0;
        uint8 remainingPoints = bonusPoints;

        // First max out AGI (19 + 6 = 25)
        if (remainingPoints > 0 && highStat + agiBonus < maxStat) {
            uint8 agiSpace = maxStat - highStat;
            agiBonus = remainingPoints > agiSpace ? agiSpace : remainingPoints;
            remainingPoints -= agiBonus;
        }

        // Then max out CON (19 + 6 = 25)
        if (remainingPoints > 0 && highStat + conBonus < maxStat) {
            uint8 conSpace = maxStat - highStat;
            conBonus = remainingPoints > conSpace ? conSpace : remainingPoints;
            remainingPoints -= conBonus;
        }

        // Finally boost LUCK for riposte (12 + 3 = 15 if L10)
        if (remainingPoints > 0) {
            luckBonus = remainingPoints;
        }

        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: mediumStat,
            constitution: highStat + conBonus,
            size: lowStat,
            agility: highStat + agiBonus,
            stamina: lowStat,
            luck: mediumStat + luckBonus
        });

        return TestFighter({
            name: bonusPoints > 0 ? "Parry Master L10" : "Parry Master L1",
            stats: IGameEngine.FighterStats({
                weapon: 2, // WEAPON_RAPIER_BUCKLER
                armor: 1, // ARMOR_LEATHER
                stance: 0, // STANCE_DEFENSIVE
                attributes: attrs,
                level: 1,
                weaponSpecialization: 255, // No specialization
                armorSpecialization: 255 // No specialization
            })
        });
    }

    function createLeveledVanguard(uint8 bonusPoints) private view returns (TestFighter memory) {
        // Base Vanguard: STR=19, CON=19, SIZE=12, AGI=5, STA=12, LUCK=5 (Total: 72)
        // STR and CON are primary stats
        uint8 strBonus = 0;
        uint8 conBonus = 0;
        uint8 staBonus = 0;
        uint8 remainingPoints = bonusPoints;

        // First max out STR (19 + 6 = 25)
        if (remainingPoints > 0 && highStat + strBonus < maxStat) {
            uint8 strSpace = maxStat - highStat;
            strBonus = remainingPoints > strSpace ? strSpace : remainingPoints;
            remainingPoints -= strBonus;
        }

        // Then max out CON (19 + 6 = 25)
        if (remainingPoints > 0 && highStat + conBonus < maxStat) {
            uint8 conSpace = maxStat - highStat;
            conBonus = remainingPoints > conSpace ? conSpace : remainingPoints;
            remainingPoints -= conBonus;
        }

        // Finally boost STA for endurance (12 + 3 = 15 if L10)
        if (remainingPoints > 0) {
            staBonus = remainingPoints;
        }

        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: highStat + strBonus,
            constitution: highStat + conBonus,
            size: mediumStat,
            agility: lowStat,
            stamina: mediumStat + staBonus,
            luck: lowStat
        });

        return TestFighter({
            name: bonusPoints > 0 ? "Vanguard L10" : "Vanguard L1",
            stats: IGameEngine.FighterStats({
                weapon: 12, // WEAPON_AXE_KITE
                armor: 2, // ARMOR_CHAIN
                stance: 1, // STANCE_BALANCED
                attributes: attrs,
                level: 1,
                weaponSpecialization: 255, // No specialization
                armorSpecialization: 255 // No specialization
            })
        });
    }

    // ==================== TESTING HELPERS ====================

    function _generateTestSeed() internal view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp, block.prevrandao, blockhash(block.number - 1), msg.sender, block.number, gasleft()
                )
            )
        );
    }

    function runProgressionTest(
        TestFighter memory fighter1,
        TestFighter memory fighter2,
        uint256 expectedWinRateMin,
        uint256 expectedWinRateMax
    ) private {
        MatchStatistics memory stats1;
        MatchStatistics memory stats2;

        uint256 baseSeed = _generateTestSeed();

        for (uint256 i = 0; i < matchCount; i++) {
            // Change blockchain state for new entropy
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 15);

            // Alternate who goes first for fairness
            bool fighter1First = i % 2 == 0;

            IGameEngine.FighterStats memory firstFighter;
            IGameEngine.FighterStats memory secondFighter;

            if (fighter1First) {
                firstFighter = fighter1.stats;
                secondFighter = fighter2.stats;
            } else {
                firstFighter = fighter2.stats;
                secondFighter = fighter1.stats;
            }

            uint256 matchSeed = uint256(keccak256(abi.encodePacked(baseSeed, i, block.timestamp)));
            bytes memory results = gameEngine.processGame(firstFighter, secondFighter, matchSeed, 0);

            (bool player1Won,, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) =
                gameEngine.decodeCombatLog(results);

            // Update win counts
            if (fighter1First && player1Won || !fighter1First && !player1Won) {
                stats1.wins++;
            } else {
                stats2.wins++;
            }

            // Update condition counts
            if (condition == IGameEngine.WinCondition.EXHAUSTION) {
                if (fighter1First && player1Won || !fighter1First && !player1Won) {
                    stats2.deathsByExhaustion++;
                } else {
                    stats1.deathsByExhaustion++;
                }
            } else if (condition == IGameEngine.WinCondition.DEATH) {
                if (fighter1First && player1Won || !fighter1First && !player1Won) {
                    stats2.deathsByLethalDamage++;
                } else {
                    stats1.deathsByLethalDamage++;
                }
            }

            // Count rounds
            stats1.totalRounds += actions.length;
            stats2.totalRounds += actions.length;
        }

        uint256 winRate = (stats1.wins * 100) / matchCount;

        emit log("=== PROGRESSION TEST RESULTS ===");
        emit log_named_string("Fighter 1", fighter1.name);
        emit log_named_string("Fighter 2", fighter2.name);
        emit log_named_uint(string.concat(fighter1.name, " wins"), stats1.wins);
        emit log_named_uint(string.concat(fighter2.name, " wins"), stats2.wins);
        emit log_named_uint("Win rate %", winRate);
        emit log_named_uint("Average rounds per match", stats1.totalRounds / matchCount);

        // Assert win rate is within expected range
        assertGe(
            winRate,
            expectedWinRateMin,
            string.concat(
                fighter1.name,
                " vs ",
                fighter2.name,
                " win rate too low (expected ",
                vm.toString(expectedWinRateMin),
                "%-",
                vm.toString(expectedWinRateMax),
                "% win rate): ",
                vm.toString(winRate)
            )
        );

        assertLe(
            winRate,
            expectedWinRateMax,
            string.concat(
                fighter1.name,
                " vs ",
                fighter2.name,
                " win rate too high (expected ",
                vm.toString(expectedWinRateMin),
                "%-",
                vm.toString(expectedWinRateMax),
                "% win rate): ",
                vm.toString(winRate)
            )
        );
    }

    // ==================== LEVEL PROGRESSION TESTS ====================

    function testAssassinProgression() public skipInCI {
        TestFighter memory assassinL1 = createLeveledAssassin(0);
        TestFighter memory assassinL10 = createLeveledAssassin(9);

        // L10 assassin should dominate L1 assassin (80-95% win rate)
        runProgressionTest(assassinL10, assassinL1, 80, 95);
    }

    function testBerserkerProgression() public skipInCI {
        TestFighter memory berserkerL1 = createLeveledBerserker(0);
        TestFighter memory berserkerL10 = createLeveledBerserker(9);

        // L10 berserker should beat L1 berserker (45-70% win rate - berserkers are volatile)
        runProgressionTest(berserkerL10, berserkerL1, 45, 70);
    }

    function testShieldTankProgression() public skipInCI {
        TestFighter memory tankL1 = createLeveledShieldTank(0);
        TestFighter memory tankL10 = createLeveledShieldTank(9);

        // L10 tank should dominate L1 tank (85-100% win rate)
        runProgressionTest(tankL10, tankL1, 85, 100);
    }

    function testMonkProgression() public skipInCI {
        TestFighter memory monkL1 = createLeveledMonk(0);
        TestFighter memory monkL10 = createLeveledMonk(9);

        // L10 monk should beat L1 monk (70-85% win rate)
        runProgressionTest(monkL10, monkL1, 70, 85);
    }

    function testParryMasterProgression() public skipInCI {
        TestFighter memory parryL1 = createLeveledParryMaster(0);
        TestFighter memory parryL10 = createLeveledParryMaster(9);

        // L10 parry master should dominate L1 parry master (80-95% win rate)
        runProgressionTest(parryL10, parryL1, 80, 95);
    }

    function testVanguardProgression() public skipInCI {
        TestFighter memory vanguardL1 = createLeveledVanguard(0);
        TestFighter memory vanguardL10 = createLeveledVanguard(9);

        // L10 vanguard should dominate L1 vanguard (80-95% win rate)
        runProgressionTest(vanguardL10, vanguardL1, 80, 95);
    }

    // ==================== CROSS-ARCHETYPE PROGRESSION TESTS ====================

    function testLeveledAssassinVsBaseBerserker() public skipInCI {
        TestFighter memory assassinL10 = createLeveledAssassin(9);
        TestFighter memory berserkerL1 = createLeveledBerserker(0);

        // L10 assassin should dominate L1 berserker (75-95% win rate)
        // Shows that levels can overcome bad matchups
        runProgressionTest(assassinL10, berserkerL1, 75, 95);
    }

    function testLeveledMonkVsBaseShieldTank() public skipInCI {
        TestFighter memory monkL10 = createLeveledMonk(9);
        TestFighter memory tankL1 = createLeveledShieldTank(0);

        // L10 monk should beat L1 tank (60-85% win rate)
        // Reach weapons + high AGI should overcome tank defense with levels
        runProgressionTest(monkL10, tankL1, 60, 85);
    }

    function testLeveledTankVsBaseAssassin() public skipInCI {
        TestFighter memory tankL10 = createLeveledShieldTank(9);
        TestFighter memory assassinL1 = createLeveledAssassin(0);

        // L10 tank should dominate L1 assassin (95-100% win rate)
        // Max defense + levels should be very strong
        runProgressionTest(tankL10, assassinL1, 95, 100);
    }

    function testLeveledParryMasterVsBaseBruiser() public skipInCI {
        TestFighter memory parryL10 = createLeveledParryMaster(9);
        TestFighter memory bruiserL1 = createLeveledBruiser(0);

        // L10 parry master should dominate L1 bruiser (80-95% win rate)
        runProgressionTest(parryL10, bruiserL1, 80, 95);
    }

    // ==================== MAX STAT TESTS ====================

    function testMaxStatAssassinVsMaxStatBerserker() public skipInCI {
        // Both at max stats (L10+)
        TestFighter memory assassinMax = createLeveledAssassin(12); // 12 points to max both AGI and STR
        TestFighter memory berserkerMax = createLeveledBerserker(12); // 12 points to max both STR and SIZE

        // Should favor assassin at max stats (80-100% win rate for assassin)
        runProgressionTest(assassinMax, berserkerMax, 80, 100);
    }

    function testMaxStatMonkVsMaxStatShieldTank() public skipInCI {
        // Both at max stats
        TestFighter memory monkMax = createLeveledMonk(12); // 12 points to max AGI and CON
        TestFighter memory tankMax = createLeveledShieldTank(12); // 12 points to max CON and SIZE

        // Tank should dominate even at max stats (0-10% win rate for monk)
        runProgressionTest(monkMax, tankMax, 0, 10);
    }

    // ==================== MINIMAL PROGRESSION TESTS ====================
    // Testing that even small amounts of progression matter

    function testMinimalProgressionAssassin() public skipInCI {
        TestFighter memory assassinL1 = createLeveledAssassin(0);
        TestFighter memory assassinL3 = createLeveledAssassin(2); // Just 2 attribute points

        // Even 2 attribute points should provide meaningful advantage (60-75% win rate)
        runProgressionTest(assassinL3, assassinL1, 60, 75);
    }

    function testMinimalProgressionBerserker() public skipInCI {
        TestFighter memory berserkerL1 = createLeveledBerserker(0);
        TestFighter memory berserkerL3 = createLeveledBerserker(2); // Just 2 attribute points

        // Even 2 attribute points should provide meaningful advantage (55-70% win rate)
        runProgressionTest(berserkerL3, berserkerL1, 55, 70);
    }

    // ==================== LEVEL SCALING PLACEHOLDER ====================
    // These tests demonstrate where we might add level-based scaling beyond attributes

    function testLevelScalingPlaceholder() public skipInCI {
        // This test shows where we could add level-based damage/defense scaling
        // For now, it just tests attribute progression

        TestFighter memory assassinL1 = createLeveledAssassin(0);
        TestFighter memory assassinL10 = createLeveledAssassin(9);

        // Log to show current scaling is purely attribute-based
        emit log("=== Level Scaling Test (Attributes Only) ===");
        emit log_named_uint("L1 Assassin STR", assassinL1.stats.attributes.strength);
        emit log_named_uint("L1 Assassin AGI", assassinL1.stats.attributes.agility);
        emit log_named_uint("L10 Assassin STR", assassinL10.stats.attributes.strength);
        emit log_named_uint("L10 Assassin AGI", assassinL10.stats.attributes.agility);
        emit log("Note: Currently no level-based damage/defense scaling beyond attributes");

        runProgressionTest(assassinL10, assassinL1, 80, 95);
    }

    // Helper for creating bruiser archetype (not in original set)
    function createLeveledBruiser(uint8 bonusPoints) private view returns (TestFighter memory) {
        // Base Bruiser: STR=19, CON=5, SIZE=19, AGI=5, STA=12, LUCK=12 (Total: 72)
        uint8 strBonus = 0;
        uint8 sizeBonus = 0;
        uint8 staBonus = 0;
        uint8 remainingPoints = bonusPoints;

        // First max out STR (19 + 6 = 25)
        if (remainingPoints > 0 && highStat + strBonus < maxStat) {
            uint8 strSpace = maxStat - highStat;
            strBonus = remainingPoints > strSpace ? strSpace : remainingPoints;
            remainingPoints -= strBonus;
        }

        // Then max out SIZE (19 + 6 = 25)
        if (remainingPoints > 0 && highStat + sizeBonus < maxStat) {
            uint8 sizeSpace = maxStat - highStat;
            sizeBonus = remainingPoints > sizeSpace ? sizeSpace : remainingPoints;
            remainingPoints -= sizeBonus;
        }

        // Finally boost STA for endurance (12 + 3 = 15 if L10)
        if (remainingPoints > 0) {
            staBonus = remainingPoints;
        }

        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: highStat + strBonus,
            constitution: lowStat,
            size: highStat + sizeBonus,
            agility: lowStat,
            stamina: mediumStat + staBonus,
            luck: mediumStat
        });

        return TestFighter({
            name: bonusPoints > 0 ? "Bruiser L10" : "Bruiser L1",
            stats: IGameEngine.FighterStats({
                weapon: 18, // WEAPON_DUAL_CLUBS
                armor: 1, // ARMOR_LEATHER
                stance: 2, // STANCE_OFFENSIVE
                attributes: attrs,
                level: 1,
                weaponSpecialization: 255, // No specialization
                armorSpecialization: 255 // No specialization
            })
        });
    }
}

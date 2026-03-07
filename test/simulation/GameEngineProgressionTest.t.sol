// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {GameEngine} from "../../src/game/engine/GameEngine.sol";
import {IGameEngine} from "../../src/interfaces/game/engine/IGameEngine.sol";
import {TestBase} from "../TestBase.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";

contract GameEngineProgressionTest is TestBase {
    // Standard test attributes for level 1 characters
    uint8 private lowStat = 5;
    uint8 private mediumStat = 12;
    uint8 private highStat = 19;

    // Max attribute cap
    uint8 private maxStat = 25;

    // Test iterations for statistical significance
    uint256 private constant MATCH_COUNT = 100;

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

        uint8 weaponId = 9; // WEAPON_DUAL_DAGGERS
        uint8 armorId = 1; // ARMOR_LEATHER

        return TestFighter({
            name: bonusPoints > 0 ? "Assassin L10" : "Assassin L1",
            stats: IGameEngine.FighterStats({
                weapon: weaponId,
                armor: armorId,
                stance: 2, // STANCE_OFFENSIVE
                attributes: attrs,
                level: bonusPoints == 0 ? 1 : (bonusPoints == 2 ? 3 : 10),
                weaponSpecialization: bonusPoints == 0 ? 255 : (bonusPoints == 2 ? 255 : getWeaponClass(weaponId)), // L10: weapon class spec
                armorSpecialization: bonusPoints == 0 ? 255 : armorId // L5+: armor type spec
            })
        });
    }

    // Helper function to get weapon class for specialization
    function getWeaponClass(uint8 weapon) private pure returns (uint8) {
        if (weapon == 9) return 0; // DUAL_DAGGERS -> LIGHT_FINESSE
        if (weapon == 4) return 4; // BATTLEAXE -> HEAVY_DEMOLITION
        if (weapon == 1) return 3; // MACE_TOWER -> PURE_BLUNT
        if (weapon == 6) return 6; // SPEAR -> REACH_CONTROL
        if (weapon == 2) return 0; // RAPIER_BUCKLER -> LIGHT_FINESSE
        if (weapon == 12) return 4; // AXE_KITE -> HEAVY_DEMOLITION
        if (weapon == 18) return 5; // DUAL_CLUBS -> DUAL_WIELD_BRUTE
        return 255; // Unknown weapon
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

        uint8 weaponId = 4; // WEAPON_BATTLEAXE
        uint8 armorId = 1; // ARMOR_LEATHER

        return TestFighter({
            name: bonusPoints > 0 ? "Berserker L10" : "Berserker L1",
            stats: IGameEngine.FighterStats({
                weapon: weaponId,
                armor: armorId,
                stance: 2, // STANCE_OFFENSIVE
                attributes: attrs,
                level: bonusPoints == 0 ? 1 : (bonusPoints == 2 ? 3 : 10),
                weaponSpecialization: bonusPoints == 0 ? 255 : (bonusPoints == 2 ? 255 : getWeaponClass(weaponId)), // L10: weapon class spec
                armorSpecialization: bonusPoints == 0 ? 255 : armorId // L5+: armor type spec
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

        uint8 weaponId = 1; // WEAPON_MACE_TOWER
        uint8 armorId = 3; // ARMOR_PLATE

        return TestFighter({
            name: bonusPoints > 0 ? "Shield Tank L10" : "Shield Tank L1",
            stats: IGameEngine.FighterStats({
                weapon: weaponId,
                armor: armorId,
                stance: 0, // STANCE_DEFENSIVE
                attributes: attrs,
                level: bonusPoints == 0 ? 1 : (bonusPoints == 2 ? 3 : 10),
                weaponSpecialization: bonusPoints == 0 ? 255 : (bonusPoints == 2 ? 255 : getWeaponClass(weaponId)), // L10: weapon class spec
                armorSpecialization: bonusPoints == 0 ? 255 : armorId // L5+: armor type spec
            })
        });
    }

    function createLeveledMonk(uint8 bonusPoints) private view returns (TestFighter memory) {
        // Base Monk: STR=12, CON=19, SIZE=5, AGI=19, STA=12, LUCK=5 (Total: 72)
        // AGI and STR are primary stats
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

        // Then max out STR (19 + 6 = 25)
        if (remainingPoints > 0 && highStat + strBonus < maxStat) {
            uint8 strSpace = maxStat - highStat;
            strBonus = remainingPoints > strSpace ? strSpace : remainingPoints;
            remainingPoints -= conBonus;
        }

        // Finally boost STA for endurance (12 + 3 = 15 if L10)
        if (remainingPoints > 0) {
            conBonus = remainingPoints;
        }

        Fighter.Attributes memory attrs = Fighter.Attributes({
            strength: highStat + strBonus,
            constitution: mediumStat + conBonus,
            size: lowStat,
            agility: highStat + agiBonus,
            stamina: mediumStat,
            luck: lowStat
        });

        uint8 weaponId = 5; // WEAPON_QUARTERSTAFF
        uint8 armorId = 0; // ARMOR_CLOTH

        return TestFighter({
            name: bonusPoints > 0 ? "Monk L10" : "Monk L1",
            stats: IGameEngine.FighterStats({
                weapon: weaponId,
                armor: armorId,
                stance: 1, // STANCE_BALANCED (not defensive - disciplined approach)
                attributes: attrs,
                level: bonusPoints == 0 ? 1 : (bonusPoints == 2 ? 3 : 10),
                weaponSpecialization: bonusPoints == 0 ? 255 : (bonusPoints == 2 ? 255 : getWeaponClass(weaponId)), // L10: weapon class spec
                armorSpecialization: bonusPoints == 0 ? 255 : armorId // L5+: armor type spec
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

        uint8 weaponId = 2; // WEAPON_RAPIER_BUCKLER
        uint8 armorId = 1; // ARMOR_LEATHER

        return TestFighter({
            name: bonusPoints > 0 ? "Parry Master L10" : "Parry Master L1",
            stats: IGameEngine.FighterStats({
                weapon: weaponId,
                armor: armorId,
                stance: 0, // STANCE_DEFENSIVE
                attributes: attrs,
                level: bonusPoints == 0 ? 1 : (bonusPoints == 2 ? 3 : 10),
                weaponSpecialization: bonusPoints == 0 ? 255 : (bonusPoints == 2 ? 255 : getWeaponClass(weaponId)), // L10: weapon class spec
                armorSpecialization: bonusPoints == 0 ? 255 : armorId // L5+: armor type spec
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

        uint8 weaponId = 12; // WEAPON_AXE_KITE
        uint8 armorId = 2; // ARMOR_CHAIN

        return TestFighter({
            name: bonusPoints > 0 ? "Vanguard L10" : "Vanguard L1",
            stats: IGameEngine.FighterStats({
                weapon: weaponId,
                armor: armorId,
                stance: 1, // STANCE_BALANCED
                attributes: attrs,
                level: bonusPoints == 0 ? 1 : (bonusPoints == 2 ? 3 : 10),
                weaponSpecialization: bonusPoints == 0 ? 255 : (bonusPoints == 2 ? 255 : getWeaponClass(weaponId)), // L10: weapon class spec
                armorSpecialization: bonusPoints == 0 ? 255 : armorId // L5+: armor type spec
            })
        });
    }

    // ==================== TESTING HELPERS ====================

    function runProgressionTest(
        TestFighter memory fighter1,
        TestFighter memory fighter2,
        uint256 baseSeed,
        uint256 expectedWinRateMin,
        uint256 expectedWinRateMax
    ) private view {
        uint256 fighter1Wins;
        uint256 totalRounds;

        for (uint256 i = 0; i < MATCH_COUNT; i++) {
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

            uint256 matchSeed = uint256(keccak256(abi.encodePacked(baseSeed, i)));
            bytes memory results = gameEngine.processGame(firstFighter, secondFighter, matchSeed, 0);

            (bool player1Won,,, IGameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(results);

            if (fighter1First && player1Won || !fighter1First && !player1Won) {
                fighter1Wins++;
            }

            totalRounds += actions.length;
        }

        uint256 winRate = (fighter1Wins * 100) / MATCH_COUNT;

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

    function testFuzz_AssassinProgression(uint256 seed) public view {
        TestFighter memory assassinL1 = createLeveledAssassin(0);
        TestFighter memory assassinL10 = createLeveledAssassin(9);

        // L10 assassin should dominate L1 assassin (75-100% win rate - RNG variance)
        runProgressionTest(assassinL10, assassinL1, seed, 75, 100);
    }

    function testFuzz_BerserkerProgression(uint256 seed) public view {
        TestFighter memory berserkerL1 = createLeveledBerserker(0);
        TestFighter memory berserkerL10 = createLeveledBerserker(9);

        // L10 berserker should beat L1 berserker (75-100% win rate - 5%/5% scaling, berserkers volatile)
        runProgressionTest(berserkerL10, berserkerL1, seed, 75, 100);
    }

    function testFuzz_ShieldTankProgression(uint256 seed) public view {
        TestFighter memory tankL1 = createLeveledShieldTank(0);
        TestFighter memory tankL10 = createLeveledShieldTank(9);

        // L10 tank should dominate L1 tank (90-100% win rate - 5%/5% scaling)
        runProgressionTest(tankL10, tankL1, seed, 90, 100);
    }

    function testFuzz_MonkProgression(uint256 seed) public view {
        TestFighter memory monkL1 = createLeveledMonk(0);
        TestFighter memory monkL10 = createLeveledMonk(9);

        // L10 monk should beat L1 monk (80-100% win rate - 5%/5% scaling)
        runProgressionTest(monkL10, monkL1, seed, 80, 100);
    }

    function testFuzz_ParryMasterProgression(uint256 seed) public view {
        TestFighter memory parryL1 = createLeveledParryMaster(0);
        TestFighter memory parryL10 = createLeveledParryMaster(9);

        // L10 parry master should dominate L1 parry master (80-100% win rate - 5%/5% scaling)
        runProgressionTest(parryL10, parryL1, seed, 80, 100);
    }

    function testFuzz_VanguardProgression(uint256 seed) public view {
        TestFighter memory vanguardL1 = createLeveledVanguard(0);
        TestFighter memory vanguardL10 = createLeveledVanguard(9);

        // L10 vanguard should dominate L1 vanguard (90-100% win rate - 5%/5% scaling)
        runProgressionTest(vanguardL10, vanguardL1, seed, 90, 100);
    }

    // ==================== CROSS-ARCHETYPE PROGRESSION TESTS ====================

    function testFuzz_LeveledAssassinVsBaseBerserker(uint256 seed) public view {
        TestFighter memory assassinL10 = createLeveledAssassin(9);
        TestFighter memory berserkerL1 = createLeveledBerserker(0);

        // L10 assassin should dominate L1 berserker (90-100% win rate - 5%/5% scaling)
        // Shows that levels can overcome bad matchups
        runProgressionTest(assassinL10, berserkerL1, seed, 90, 100);
    }

    function testFuzz_LeveledMonkVsBaseShieldTank(uint256 seed) public view {
        TestFighter memory monkL10 = createLeveledMonk(9);
        TestFighter memory tankL1 = createLeveledShieldTank(0);

        // L10 monk should beat L1 tank (60-100% win rate - v1.0 scaling advantage)
        // Reach weapons + high AGI should overcome tank defense with levels
        runProgressionTest(monkL10, tankL1, seed, 60, 100);
    }

    function testFuzz_LeveledTankVsBaseAssassin(uint256 seed) public view {
        TestFighter memory tankL10 = createLeveledShieldTank(9);
        TestFighter memory assassinL1 = createLeveledAssassin(0);

        // L10 tank should dominate L1 assassin (90-100% win rate - 5%/5% scaling)
        // Max defense + levels should be very strong
        runProgressionTest(tankL10, assassinL1, seed, 90, 100);
    }

    function testFuzz_LeveledParryMasterVsBaseBruiser(uint256 seed) public view {
        TestFighter memory parryL10 = createLeveledParryMaster(9);
        TestFighter memory bruiserL1 = createLeveledBruiser(0);

        // L10 parry master should dominate L1 bruiser (90-100% win rate - 5%/5% scaling)
        runProgressionTest(parryL10, bruiserL1, seed, 90, 100);
    }

    // ==================== MAX STAT TESTS ====================

    function testFuzz_MaxStatAssassinVsMaxStatBerserker(uint256 seed) public view {
        // Both at max stats (L10+)
        TestFighter memory assassinMax = createLeveledAssassin(12); // 12 points to max both AGI and STR
        TestFighter memory berserkerMax = createLeveledBerserker(12); // 12 points to max both STR and SIZE

        // Should favor assassin at max stats (75-100% win rate for assassin)
        runProgressionTest(assassinMax, berserkerMax, seed, 75, 100);
    }

    function testFuzz_MaxStatMonkVsMaxStatShieldTank(uint256 seed) public view {
        // Both at max stats
        TestFighter memory monkMax = createLeveledMonk(12); // 12 points to max AGI and CON
        TestFighter memory tankMax = createLeveledShieldTank(12); // 12 points to max CON and SIZE

        // Tank vs Monk at max stats (35-60% win rate for monk - quarterstaff vs plate is competitive)
        runProgressionTest(monkMax, tankMax, seed, 35, 60);
    }

    // ==================== MINIMAL PROGRESSION TESTS ====================
    // Testing that even small amounts of progression matter

    function testFuzz_MinimalProgressionAssassin(uint256 seed) public view {
        TestFighter memory assassinL1 = createLeveledAssassin(0);
        TestFighter memory assassinL3 = createLeveledAssassin(2); // Just 2 attribute points

        // Even 2 level progression should provide meaningful advantage (70-95% win rate - 5%/5% scaling)
        runProgressionTest(assassinL3, assassinL1, seed, 70, 95);
    }

    function testFuzz_MinimalProgressionBerserker(uint256 seed) public view {
        TestFighter memory berserkerL1 = createLeveledBerserker(0);
        TestFighter memory berserkerL3 = createLeveledBerserker(2); // Just 2 attribute points

        // Even 2 level progression should provide meaningful advantage (40-70% win rate - berserkers volatile, 5%/5% scaling)
        runProgressionTest(berserkerL3, berserkerL1, seed, 40, 70);
    }

    // ==================== LEVEL SCALING PLACEHOLDER ====================
    // These tests demonstrate where we might add level-based scaling beyond attributes

    function testFuzz_LevelScaling(uint256 seed) public view {
        TestFighter memory assassinL1 = createLeveledAssassin(0);
        TestFighter memory assassinL10 = createLeveledAssassin(9);

        runProgressionTest(assassinL10, assassinL1, seed, 80, 100);
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

        uint8 weaponId = 18; // WEAPON_DUAL_CLUBS
        uint8 armorId = 1; // ARMOR_LEATHER

        return TestFighter({
            name: bonusPoints > 0 ? "Bruiser L10" : "Bruiser L1",
            stats: IGameEngine.FighterStats({
                weapon: weaponId,
                armor: armorId,
                stance: 2, // STANCE_OFFENSIVE
                attributes: attrs,
                level: bonusPoints == 0 ? 1 : (bonusPoints == 2 ? 3 : 10),
                weaponSpecialization: bonusPoints == 0 ? 255 : (bonusPoints == 2 ? 255 : getWeaponClass(weaponId)), // L10: weapon class spec
                armorSpecialization: bonusPoints == 0 ? 255 : armorId // L5+: armor type spec
            })
        });
    }
}

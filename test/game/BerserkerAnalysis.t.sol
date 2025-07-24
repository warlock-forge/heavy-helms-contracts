// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/game/engine/GameEngine.sol";
import "../../src/interfaces/game/engine/IGameEngine.sol";
import "../../src/fighters/Fighter.sol";

contract BerserkerAnalysisTest is Test {
    GameEngine public gameEngine;
    uint8 private lowStat = 5;
    uint8 private mediumStat = 12;
    uint8 private highStat = 19;

    function setUp() public {
        gameEngine = new GameEngine();
    }

    function test_AnalyzeBerserkerVsShieldTank() public {
        // Berserker: STR 19, CON 5, SIZE 19, AGI 12, STA 12, LUCK 5
        Fighter.Attributes memory berserkerAttrs = Fighter.Attributes({
            strength: highStat,
            constitution: lowStat,
            size: highStat,
            agility: mediumStat,
            stamina: mediumStat,
            luck: lowStat
        });

        IGameEngine.FighterStats memory berserker = IGameEngine.FighterStats({
            attributes: berserkerAttrs,
            armor: 1, // ARMOR_LEATHER
            weapon: 4, // WEAPON_BATTLEAXE
            stance: 2 // STANCE_OFFENSIVE
        });

        // Shield Tank: STR 12, CON 19, SIZE 19, AGI 5, STA 12, LUCK 5
        Fighter.Attributes memory shieldTankAttrs = Fighter.Attributes({
            strength: mediumStat,
            constitution: highStat,
            size: highStat,
            agility: lowStat,
            stamina: mediumStat,
            luck: lowStat
        });

        IGameEngine.FighterStats memory shieldTank = IGameEngine.FighterStats({
            attributes: shieldTankAttrs,
            armor: 3, // ARMOR_PLATE
            weapon: 1, // WEAPON_MACE_TOWER
            stance: 0 // STANCE_DEFENSIVE
        });

        // Calculate stats for both fighters
        GameEngine.CalculatedStats memory berserkerStats = gameEngine.calculateStats(berserker);
        GameEngine.CalculatedStats memory shieldTankStats = gameEngine.calculateStats(shieldTank);

        // Log Berserker stats
        console.log("\n=== BERSERKER STATS (Battleaxe + Leather + Offensive) ===");
        console.log("Health:", berserkerStats.maxHealth);
        console.log("Endurance:", berserkerStats.maxEndurance);
        console.log("Damage Modifier:", berserkerStats.damageModifier);
        console.log("Hit Chance:", berserkerStats.hitChance);
        console.log("Dodge Chance:", berserkerStats.dodgeChance);
        console.log("Block Chance:", berserkerStats.blockChance);
        console.log("Counter Chance:", berserkerStats.counterChance);
        console.log("Parry Chance:", berserkerStats.parryChance);
        console.log("Riposte Chance:", berserkerStats.riposteChance);
        console.log("Crit Chance:", berserkerStats.critChance);
        console.log("Crit Multiplier:", berserkerStats.critMultiplier);
        console.log("Initiative:", berserkerStats.initiative);

        // Log Shield Tank stats
        console.log("\n=== SHIELD TANK STATS (Mace+Tower + Plate + Defensive) ===");
        console.log("Health:", shieldTankStats.maxHealth);
        console.log("Endurance:", shieldTankStats.maxEndurance);
        console.log("Damage Modifier:", shieldTankStats.damageModifier);
        console.log("Hit Chance:", shieldTankStats.hitChance);
        console.log("Dodge Chance:", shieldTankStats.dodgeChance);
        console.log("Block Chance:", shieldTankStats.blockChance);
        console.log("Counter Chance:", shieldTankStats.counterChance);
        console.log("Parry Chance:", shieldTankStats.parryChance);
        console.log("Riposte Chance:", shieldTankStats.riposteChance);
        console.log("Crit Chance:", shieldTankStats.critChance);
        console.log("Crit Multiplier:", shieldTankStats.critMultiplier);
        console.log("Initiative:", shieldTankStats.initiative);

        // Get weapon stats
        GameEngine.WeaponStats memory battleaxe = gameEngine.getWeaponStats(4);
        GameEngine.WeaponStats memory maceTower = gameEngine.getWeaponStats(1);

        console.log("\n=== WEAPON COMPARISON ===");
        console.log("Battleaxe damage:", battleaxe.minDamage, "-", battleaxe.maxDamage);
        console.log("Battleaxe speed:", battleaxe.attackSpeed);
        console.log("Mace+Tower damage:", maceTower.minDamage, "-", maceTower.maxDamage);
        console.log("Mace+Tower speed:", maceTower.attackSpeed);

        // Calculate actual damage per hit
        uint256 berserkerAvgWeaponDmg = (battleaxe.minDamage + battleaxe.maxDamage) / 2;
        uint256 berserkerDamagePerHit = (berserkerAvgWeaponDmg * berserkerStats.damageModifier) / 100;
        console.log("\nBerserker avg damage per hit:", berserkerDamagePerHit);

        uint256 tankAvgWeaponDmg = (maceTower.minDamage + maceTower.maxDamage) / 2;
        uint256 tankDamagePerHit = (tankAvgWeaponDmg * shieldTankStats.damageModifier) / 100;
        console.log("Shield Tank avg damage per hit:", tankDamagePerHit);

        // Calculate attacks per round
        console.log("\n=== ACTION POINTS ===");
        console.log("Attack cost: 149 action points");
        console.log("Berserker gains per round:", battleaxe.attackSpeed);
        console.log("Shield Tank gains per round:", maceTower.attackSpeed);

        // Run a few combat simulations with detailed logging
        console.log("\n=== RUNNING 5 COMBAT SIMULATIONS ===");
        uint256 berserkerWins = 0;

        for (uint256 i = 0; i < 5; i++) {
            console.log("\n--- Combat", i + 1, "---");
            uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, i)));

            bytes memory results = gameEngine.processGame(berserker, shieldTank, seed, 0);
            (bool berserkerWon,, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) =
                gameEngine.decodeCombatLog(results);

            if (berserkerWon) berserkerWins++;

            console.log("Winner:", berserkerWon ? "Berserker" : "Shield Tank");
            console.log("Win condition:", uint8(condition));
            console.log("Total rounds:", actions.length);

            // Analyze first 10 rounds
            uint256 roundsToAnalyze = actions.length > 10 ? 10 : actions.length;
            for (uint256 j = 0; j < roundsToAnalyze; j++) {
                IGameEngine.CombatAction memory action = actions[j];
                console.log("\nRound", j + 1);
                console.log("Berserker:", _resultToString(action.p1Result), "Damage:", action.p1Damage);
                console.log("Shield Tank:", _resultToString(action.p2Result), "Damage:", action.p2Damage);
            }
        }

        console.log("\n=== SUMMARY ===");
        console.log("Berserker won", berserkerWins, "out of 5 fights");
    }

    function _resultToString(IGameEngine.CombatResultType result) private pure returns (string memory) {
        if (result == IGameEngine.CombatResultType.MISS) return "MISS";
        if (result == IGameEngine.CombatResultType.ATTACK) return "ATTACK";
        if (result == IGameEngine.CombatResultType.CRIT) return "CRIT";
        if (result == IGameEngine.CombatResultType.BLOCK) return "BLOCK";
        if (result == IGameEngine.CombatResultType.COUNTER) return "COUNTER";
        if (result == IGameEngine.CombatResultType.PARRY) return "PARRY";
        if (result == IGameEngine.CombatResultType.RIPOSTE) return "RIPOSTE";
        if (result == IGameEngine.CombatResultType.DODGE) return "DODGE";
        return "UNKNOWN";
    }
}

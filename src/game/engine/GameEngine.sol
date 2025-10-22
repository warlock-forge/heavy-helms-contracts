// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {UniformRandomNumber} from "../../lib/UniformRandomNumber.sol";
import {IGameEngine} from "../../interfaces/game/engine/IGameEngine.sol";

contract GameEngine is IGameEngine {
    using UniformRandomNumber for uint256;

    error InvalidResults();
    error InvalidEquipment();

    uint16 public constant version = 260; // v1.4: Improved initiative formula

    struct CalculatedStats {
        uint16 maxHealth;
        uint16 damageModifier;
        uint16 hitChance;
        uint16 blockChance;
        uint16 parryChance;
        uint16 dodgeChance;
        uint16 maxEndurance;
        uint16 initiative;
        uint16 counterChance;
        uint16 riposteChance;
        uint16 critChance;
        uint16 critMultiplier;
        uint16 baseSurvivalRate;
    }

    enum DamageType {
        Slashing,
        Piercing,
        Blunt,
        Hybrid_Slash_Pierce, // For weapons mixing slashing and piercing
        Hybrid_Slash_Blunt, // For weapons mixing slashing and blunt
        Hybrid_Pierce_Blunt // For weapons mixing piercing and blunt
    }

    enum ShieldType {
        NONE,
        BUCKLER,
        KITE_SHIELD,
        TOWER_SHIELD
    }

    enum WeaponClass {
        LIGHT_FINESSE, // Pure AGI damage
        CURVED_BLADE, // AGI*4 + STR*2 damage
        BALANCED_SWORD, // STR*4 + AGI*2 damage
        PURE_BLUNT, // Pure STR damage
        HEAVY_DEMOLITION, // STR+SIZE damage
        DUAL_WIELD_BRUTE, // STR+SIZE+AGI damage
        REACH_CONTROL // AGI+STR damage + dodge bonus
    }

    struct WeaponStats {
        uint16 minDamage;
        uint16 maxDamage;
        uint16 attackSpeed; // Base 100, higher is faster
        uint16 parryChance; // Base 100, chance to parry
        uint16 riposteChance; // Base 100, chance to riposte
        uint16 critMultiplier; // Base 100, higher means better crits
        uint16 staminaMultiplier; // Base 100, higher means more stamina drain
        uint16 survivalFactor; // Base 100, higher means better survival chance
        DamageType damageType; // Primary damage type
        ShieldType shieldType; // NONE, BUCKLER, KITE_SHIELD, or TOWER_SHIELD
        WeaponClass weaponClass; // Classification for damage scaling
    }

    struct ArmorStats {
        uint16 defense; // Base damage reduction
        uint16 weight; // Affects stamina drain
        uint16 slashResist; // Resistance to slashing (base 100)
        uint16 pierceResist; // Resistance to piercing (base 100)
        uint16 bluntResist; // Resistance to blunt (base 100)
    }

    struct StanceMultiplier {
        uint16 damageModifier; // Reduce the range between offensive/defensive
        uint16 hitChance; // Make hit chance differences smaller
        uint16 critChance; // Keep crit chances relatively close
        uint16 critMultiplier; // Reduce the gap in crit damage
        uint16 blockChance; // Make defensive abilities more consistent
        uint16 parryChance; // Keep parry in check
        uint16 dodgeChance; // Balance dodge with other defensive options
        uint16 counterChance; // Make counter more reliable but less swingy
        uint16 riposteChance; // New field
        uint16 staminaCostModifier; // Add this new field
        uint16 survivalFactor; // Base 100, higher means better survival chance
        uint16 heavyArmorEffectiveness; // Plate armor defense/resistance effectiveness
    }

    struct CalculatedCombatStats {
        CalculatedStats stats;
        WeaponStats weapon;
        ArmorStats armor;
        StanceMultiplier stanceMultipliers;
    }

    struct CombatState {
        bool isPlayer1Turn;
        WinCondition condition;
        uint96 p1Health;
        uint96 p2Health;
        uint32 p1Stamina;
        uint32 p2Stamina;
        uint16 p1ActionPoints;
        uint16 p2ActionPoints;
        bool p1HasInitiative;
        bool player1Won;
    }

    enum CounterType {
        PARRY,
        COUNTER
    }

    enum ActionType {
        ATTACK,
        BLOCK,
        PARRY,
        DODGE,
        COUNTER,
        RIPOSTE
    }

    // Combat-related constants
    uint8 private immutable STAMINA_ATTACK = 16;
    uint8 private immutable STAMINA_BLOCK = 4;
    uint8 private immutable STAMINA_DODGE = 4;
    uint8 private immutable STAMINA_COUNTER = 6;
    uint8 private immutable STAMINA_PARRY = 4;
    uint8 private immutable STAMINA_RIPOSTE = 6;
    uint8 private immutable MAX_ROUNDS = 70;
    uint8 private constant ATTACK_ACTION_COST = 149;
    uint8 private constant REACH_DODGE_BONUS = 5;
    uint8 private constant BASE_SURVIVAL_CHANCE = 70;
    uint8 private constant MINIMUM_SURVIVAL_CHANCE = 35;
    uint8 private constant DAMAGE_THRESHOLD_PERCENT = 20;
    uint8 private constant MAX_DAMAGE_OVERAGE = 75;

    // Weapon Types
    uint8 public constant WEAPON_ARMING_SWORD_KITE = 0;
    uint8 public constant WEAPON_MACE_TOWER = 1;
    uint8 public constant WEAPON_RAPIER_BUCKLER = 2;
    uint8 public constant WEAPON_GREATSWORD = 3;
    uint8 public constant WEAPON_BATTLEAXE = 4;
    uint8 public constant WEAPON_QUARTERSTAFF = 5;
    uint8 public constant WEAPON_SPEAR = 6;
    uint8 public constant WEAPON_SHORTSWORD_BUCKLER = 7;
    uint8 public constant WEAPON_SHORTSWORD_TOWER = 8;
    uint8 public constant WEAPON_DUAL_DAGGERS = 9;
    uint8 public constant WEAPON_RAPIER_DAGGER = 10;
    uint8 public constant WEAPON_SCIMITAR_BUCKLER = 11;
    uint8 public constant WEAPON_AXE_KITE = 12;
    uint8 public constant WEAPON_AXE_TOWER = 13;
    uint8 public constant WEAPON_DUAL_SCIMITARS = 14;
    uint8 public constant WEAPON_MACE_KITE = 16;
    uint8 public constant WEAPON_CLUB_TOWER = 17;
    uint8 public constant WEAPON_DUAL_CLUBS = 18;
    uint8 public constant WEAPON_ARMING_SWORD_SHORTSWORD = 19;
    uint8 public constant WEAPON_SCIMITAR_DAGGER = 20;
    uint8 public constant WEAPON_ARMING_SWORD_CLUB = 21;
    uint8 public constant WEAPON_AXE_MACE = 22;
    uint8 public constant WEAPON_MACE_SHORTSWORD = 24;
    uint8 public constant WEAPON_MAUL = 25;
    uint8 public constant WEAPON_TRIDENT = 26;

    // Armor Types
    uint8 public constant ARMOR_CLOTH = 0;
    uint8 public constant ARMOR_LEATHER = 1;
    uint8 public constant ARMOR_CHAIN = 2;
    uint8 public constant ARMOR_PLATE = 3;

    // Stance Types
    uint8 public constant STANCE_DEFENSIVE = 0;
    uint8 public constant STANCE_BALANCED = 1;
    uint8 public constant STANCE_OFFENSIVE = 2;

    /// @notice Decodes a version number into major and minor components
    /// @param _version The version number to decode
    /// @return major The major version number (0-255)
    /// @return minor The minor version number (0-255)
    function decodeVersion(uint16 _version) public pure returns (uint8 major, uint8 minor) {
        major = uint8(_version >> 8); // Get upper 8 bits
        minor = uint8(_version & 0xFF); // Get lower 8 bits
    }

    /// @notice Decodes a combat log byte array into structured data
    /// @param results The byte array containing the encoded combat log
    /// @return player1Won True if player1 won, false if player2 won
    /// @return gameEngineVersion The version of the game engine that generated this log (16 bits)
    /// @return condition The win condition that ended the combat
    /// @return actions Array of combat actions containing results for both players
    /// @dev Format:
    ///   - Byte 0: Winner (1 for player1, 0 for player2)
    ///   - Bytes 1-2: Game Engine Version (16 bits)
    ///   - Byte 3: Win Condition
    ///   - Bytes 4+: Combat actions (8 bytes each):
    ///     - Byte 0: Player 1 Result
    ///     - Bytes 1-2: Player 1 Damage
    ///     - Byte 3: Player 1 Stamina Lost
    ///     - Byte 4: Player 2 Result
    ///     - Bytes 5-6: Player 2 Damage
    ///     - Byte 7: Player 2 Stamina Lost
    function decodeCombatLog(bytes memory results)
        public
        pure
        returns (bool player1Won, uint16 gameEngineVersion, WinCondition condition, CombatAction[] memory actions)
    {
        if (results.length < 4) {
            revert InvalidResults();
        }

        // Read winner (1 byte) - 0 means player1 won, 1 means player2 won
        player1Won = uint8(results[0]) == 0;

        // Read version (2 bytes)
        gameEngineVersion = uint16(uint8(results[1])) << 8 | uint16(uint8(results[2]));

        // Read condition
        condition = WinCondition(uint8(results[3]));

        // Decode actions
        uint256 numActions = (results.length - 4) / 8;
        actions = new CombatAction[](numActions);

        unchecked {
            for (uint256 i = 0; i < numActions; i++) {
                actions[i] = unpackCombatAction(results, 4 + (i * 8));
            }
        }
    }

    /**
     * @dev Unpacks a single combat action from the byte array
     * @param data The byte array containing all combat data
     * @param offset Starting position of this action in the byte array
     * @return action The unpacked CombatAction struct
     */
    function unpackCombatAction(bytes memory data, uint256 offset) private pure returns (CombatAction memory action) {
        return CombatAction({
            p1Result: CombatResultType(uint8(data[offset])),
            p1Damage: (uint16(uint8(data[offset + 1])) << 8) | uint16(uint8(data[offset + 2])),
            p1StaminaLost: uint8(data[offset + 3]),
            p2Result: CombatResultType(uint8(data[offset + 4])),
            p2Damage: (uint16(uint8(data[offset + 5])) << 8) | uint16(uint8(data[offset + 6])),
            p2StaminaLost: uint8(data[offset + 7])
        });
    }

    function calculateStats(FighterStats memory player) public pure returns (CalculatedStats memory) {
        // Health calculation remains unchanged
        uint32 healthBase = 50;
        uint32 healthFromCon = uint32(player.attributes.constitution) * 17; // Back to 17 as requested
        uint32 healthFromSize = uint32(player.attributes.size) * 6;
        uint32 healthFromStamina = uint32(player.attributes.stamina) * 3;
        uint16 maxHealth = uint16(healthBase + healthFromCon + healthFromSize + healthFromStamina);

        // Balanced endurance: STR users need stamina for heavy weapons, STA users get more
        uint32 enduranceBase = 35;
        uint32 enduranceFromStamina = uint32(player.attributes.stamina) * 20; // Increased from 16 to 20
        uint32 enduranceFromStrength = uint32(player.attributes.strength) * 5; // Increased from 2 to 5
        uint16 maxEndurance = uint16(enduranceBase + enduranceFromStamina + enduranceFromStrength);

        // Safe initiative calculation
        uint32 initiativeBase = 20;
        uint32 initiativeFromAgility = uint32(player.attributes.agility) * 3;
        uint32 initiativeFromLuck = uint32(player.attributes.luck) * 2;
        uint16 initiative = uint16(initiativeBase + initiativeFromAgility + initiativeFromLuck);

        // Safe defensive stats calculation
        uint16 dodgeChance =
            calculateDodgeChance(player.attributes.agility, player.attributes.size, player.attributes.stamina);
        uint16 blockChance =
            calculateBlockChance(player.attributes.constitution, player.attributes.strength, player.attributes.size);
        uint16 parryChance =
            calculateParryChance(player.attributes.strength, player.attributes.agility, player.attributes.stamina);

        // Rebalanced hit chance: AGI*0.5 + LUCK*2.5 (was AGI*1 + LUCK*2)
        uint32 baseChance = 50;
        uint32 agilityBonus = uint32(player.attributes.agility) / 2; // Reduced from *1 to *0.5
        uint32 luckBonus = uint32(player.attributes.luck) * 25 / 10; // Increased from *2 to *2.5
        uint16 hitChance = uint16(baseChance + agilityBonus + luckBonus);

        // Rebalanced crit calculations: AGI*0.2 + LUCK*0.5 (was AGI*0.33 + LUCK*0.33)
        uint16 critChance =
            2 + uint16(uint32(player.attributes.agility) / 5) + uint16(uint32(player.attributes.luck) / 2);
        uint16 critMultiplier =
            uint16(150 + (uint32(player.attributes.strength) * 3) + (uint32(player.attributes.size) * 2));

        // Rebalanced counter chance: Pure STR overpowering (was STR + AGI)
        uint16 counterChance = uint16(3 + uint32(player.attributes.strength) * 2);

        // Safe riposte chance calculation (agility + luck based)
        uint16 riposteChance = uint16(
            3 + uint32(player.attributes.agility) + uint32(player.attributes.luck)
                + (uint32(player.attributes.constitution) * 3 / 10)
        );

        // Weapon-class-based physical power calculation with base damage adjustments
        WeaponStats memory weaponStats = getWeaponStats(player.weapon);
        uint32 tempPowerMod;
        uint32 baseDamage;

        if (weaponStats.weaponClass == WeaponClass.LIGHT_FINESSE) {
            // Pure AGI damage scaling (10x total, single stat)
            baseDamage = 20; // Single stat weapons: Base 25
            tempPowerMod = baseDamage + (uint32(player.attributes.agility) * 10);
        } else if (weaponStats.weaponClass == WeaponClass.CURVED_BLADE) {
            // AGI-heavy scaling: AGI*7 + STR*3 (10x total, dual stat uneven split)
            baseDamage = 35; // Dual stat uneven: Base 35
            tempPowerMod =
                baseDamage + (uint32(player.attributes.agility) * 7) + (uint32(player.attributes.strength) * 3);
        } else if (weaponStats.weaponClass == WeaponClass.BALANCED_SWORD) {
            // STR-heavy scaling: STR*7 + AGI*3 (10x total, dual stat uneven split)
            baseDamage = 35; // Dual stat uneven: Base 35
            tempPowerMod =
                baseDamage + (uint32(player.attributes.strength) * 7) + (uint32(player.attributes.agility) * 3);
        } else if (weaponStats.weaponClass == WeaponClass.PURE_BLUNT) {
            // Pure STR damage scaling (10x total, single stat)
            baseDamage = 20; // Single stat weapons: Base 20
            tempPowerMod = baseDamage + (uint32(player.attributes.strength) * 10);
        } else if (weaponStats.weaponClass == WeaponClass.HEAVY_DEMOLITION) {
            // STR+SIZE scaling: STR*5 + SIZE*5 (10x total, dual stat even split)
            baseDamage = 40; // Dual stat even: Base 40
            tempPowerMod = baseDamage + (uint32(player.attributes.strength) * 5) + (uint32(player.attributes.size) * 5);
        } else if (weaponStats.weaponClass == WeaponClass.DUAL_WIELD_BRUTE) {
            // STR+SIZE+AGI scaling: STR*4 + SIZE*3 + AGI*3 (10x total, triple stat)
            baseDamage = 50; // Triple stat weapons: Base 50
            tempPowerMod = baseDamage + (uint32(player.attributes.strength) * 4) + (uint32(player.attributes.size) * 3)
                + (uint32(player.attributes.agility) * 3);
        } else if (weaponStats.weaponClass == WeaponClass.REACH_CONTROL) {
            // AGI+STR scaling: AGI*5 + STR*5 (10x total, dual stat even split)
            baseDamage = 30; // Dual stat even: Base 30
            tempPowerMod =
                baseDamage + (uint32(player.attributes.agility) * 5) + (uint32(player.attributes.strength) * 5);
        } else {
            // Fallback to original formula if somehow no classification
            baseDamage = 20;
            tempPowerMod = baseDamage + (uint32(player.attributes.strength) * 5) + (uint32(player.attributes.size) * 5);
        }

        // Apply universal attribute damage bonuses to the damage modifier

        // STR Universal Power Modifier: smaller but affects all weapons
        if (player.attributes.strength <= 8) {
            // STR 3-8: -3% damage modifier
            tempPowerMod = (tempPowerMod * 97) / 100;
        } else if (player.attributes.strength >= 17 && player.attributes.strength <= 21) {
            // STR 17-21: +3% damage modifier
            tempPowerMod = (tempPowerMod * 103) / 100;
        } else if (player.attributes.strength >= 22) {
            // STR 22+: +5% damage modifier
            tempPowerMod = (tempPowerMod * 105) / 100;
        }
        // STR 9-16: 0% (baseline) - no modification needed

        // SIZE Mass/Leverage Modifier: larger bonus but more specialized
        if (player.attributes.size <= 8) {
            // SIZE 3-8: -5% damage modifier
            tempPowerMod = (tempPowerMod * 95) / 100;
        } else if (player.attributes.size >= 17 && player.attributes.size <= 21) {
            // SIZE 17-21: +5% damage modifier
            tempPowerMod = (tempPowerMod * 105) / 100;
        } else if (player.attributes.size >= 22) {
            // SIZE 22+: +10% damage modifier
            tempPowerMod = (tempPowerMod * 110) / 100;
        }
        // SIZE 9-16: 0% (baseline) - no modification needed

        uint16 physicalPowerMod = uint16(tempPowerMod < type(uint16).max ? tempPowerMod : type(uint16).max);

        // Calculate base survival rate (v1.3: Enhanced scaling LUCK×4 + CON×2, base 70)
        uint16 baseSurvivalRate =
            BASE_SURVIVAL_CHANCE + (uint16(player.attributes.luck) * 4) + (uint16(player.attributes.constitution) * 2);

        // Apply level scaling (v1.0)
        // +5% health per level above 1 (max +45% at level 10)
        if (player.level > 1) {
            uint32 levelBonus = uint32(player.level - 1) * 5; // 5% per level
            maxHealth = uint16((uint32(maxHealth) * (100 + levelBonus)) / 100);

            // +5% damage per level above 1 (max +45% at level 10)
            uint32 damageLevelBonus = uint32(player.level - 1) * 5; // 5% per level
            physicalPowerMod = uint16((uint32(physicalPowerMod) * (100 + damageLevelBonus)) / 100);

            // +2 initiative per level above 1 (max +18 at level 10)
            uint32 initiativeLevelBonus = uint32(player.level - 1) * 2; // 2 per level
            initiative = uint16(uint32(initiative) + initiativeLevelBonus);
        }

        // Apply weapon specialization bonuses (v1.0)
        // Check if player's weapon specialization matches their equipped weapon's class
        if (player.weaponSpecialization != 255) {
            // 255 = no specialization
            if (uint8(weaponStats.weaponClass) == player.weaponSpecialization) {
                // Apply class-specific bonuses
                if (weaponStats.weaponClass == WeaponClass.LIGHT_FINESSE) {
                    // +10 initiative, +10% endurance (stamina efficiency)
                    initiative += 10;
                    maxEndurance = uint16((uint32(maxEndurance) * 110) / 100);
                } else if (weaponStats.weaponClass == WeaponClass.CURVED_BLADE) {
                    // +5% crit chance, +3% dodge
                    critChance = uint16((uint32(critChance) * 105) / 100);
                    dodgeChance = uint16((uint32(dodgeChance) * 103) / 100);
                } else if (weaponStats.weaponClass == WeaponClass.BALANCED_SWORD) {
                    // +3% hit chance, +5% damage
                    hitChance = uint16((uint32(hitChance) * 103) / 100);
                    physicalPowerMod = uint16((uint32(physicalPowerMod) * 105) / 100);
                } else if (weaponStats.weaponClass == WeaponClass.PURE_BLUNT) {
                    // +5% counter chance, +5% damage
                    counterChance = uint16((uint32(counterChance) * 105) / 100);
                    physicalPowerMod = uint16((uint32(physicalPowerMod) * 105) / 100);
                } else if (weaponStats.weaponClass == WeaponClass.HEAVY_DEMOLITION) {
                    // +10% crit multiplier, +7% damage
                    critMultiplier = uint16((uint32(critMultiplier) * 110) / 100);
                    physicalPowerMod = uint16((uint32(physicalPowerMod) * 107) / 100);
                } else if (weaponStats.weaponClass == WeaponClass.DUAL_WIELD_BRUTE) {
                    // +10% endurance (stamina efficiency), +3% parry
                    maxEndurance = uint16((uint32(maxEndurance) * 110) / 100);
                    parryChance = uint16((uint32(parryChance) * 103) / 100);
                } else if (weaponStats.weaponClass == WeaponClass.REACH_CONTROL) {
                    // +5% dodge, +5% parry
                    dodgeChance = uint16((uint32(dodgeChance) * 105) / 100);
                    parryChance = uint16((uint32(parryChance) * 105) / 100);
                }
            }
        }

        // Apply armor specialization bonuses (v1.0)
        // Check if player's armor specialization matches their equipped armor
        if (player.armorSpecialization != 255) {
            // 255 = no specialization
            if (player.armor == player.armorSpecialization) {
                // Apply armor-specific bonuses
                if (player.armor == ARMOR_CLOTH) {
                    // +10% dodge, +15% endurance (light & efficient)
                    dodgeChance = uint16((uint32(dodgeChance) * 110) / 100);
                    maxEndurance = uint16((uint32(maxEndurance) * 115) / 100);
                } else if (player.armor == ARMOR_LEATHER) {
                    // +5% dodge, +10% endurance (moderate mobility)
                    dodgeChance = uint16((uint32(dodgeChance) * 105) / 100);
                    maxEndurance = uint16((uint32(maxEndurance) * 110) / 100);
                } else if (player.armor == ARMOR_CHAIN) {
                    // +5% health, +3% block (balanced protection)
                    maxHealth = uint16((uint32(maxHealth) * 105) / 100);
                    blockChance = uint16((uint32(blockChance) * 103) / 100);
                } else if (player.armor == ARMOR_PLATE) {
                    // +10% health, +5% block (maximum protection)
                    maxHealth = uint16((uint32(maxHealth) * 110) / 100);
                    blockChance = uint16((uint32(blockChance) * 105) / 100);
                }
            }
        }

        return CalculatedStats({
            maxHealth: maxHealth,
            maxEndurance: maxEndurance,
            initiative: initiative,
            hitChance: hitChance,
            dodgeChance: dodgeChance,
            blockChance: blockChance,
            parryChance: parryChance,
            critChance: critChance,
            critMultiplier: critMultiplier,
            counterChance: counterChance,
            riposteChance: riposteChance,
            damageModifier: physicalPowerMod,
            baseSurvivalRate: baseSurvivalRate
        });
    }

    function calculateBlockChance(uint8 constitution, uint8 strength, uint8 size) internal pure returns (uint16) {
        // Historically accurate blocking: strength primary for shield control, size for coverage/mass, constitution for endurance
        return uint16(2 + (uint32(strength) * 50 / 100) + (uint32(size) * 30 / 100) + (uint32(constitution) * 20 / 100));
    }

    function calculateParryChance(uint8 strength, uint8 agility, uint8 stamina) internal pure returns (uint16) {
        // Reduced AGI influence: STR*0.4 + AGI*0.25 + STA*0.3 (was AGI*0.35)
        return uint16(2 + (uint32(strength) * 40 / 100) + (uint32(agility) * 25 / 100) + (uint32(stamina) * 30 / 100));
    }

    function calculateDodgeChance(uint8 agility, uint8 size, uint8 stamina) internal pure returns (uint16) {
        uint16 baseDodge = 7;
        uint32 agilityBonus = uint32(agility) * 30 / 100;
        uint32 staminaBonus = uint32(stamina) * 20 / 100;
        baseDodge += uint16(agilityBonus + staminaBonus);

        if (size <= 21) {
            uint32 sizeModifier = uint32(21 - size) * 10 / 100;
            return uint16(baseDodge + sizeModifier);
        } else {
            uint32 sizeModifier = uint32(size - 21) * 10 / 100;
            return sizeModifier >= baseDodge ? 0 : uint16(baseDodge - sizeModifier);
        }
    }

    /// @notice Process a game between two players
    /// @param player1 The first player's combat loadout
    /// @param player2 The second player's loadout
    /// @param randomSeed The random seed for the game
    /// @param lethalityFactor The lethality factor for the game
    /// @return A byte array containing the encoded combat log
    function processGame(
        FighterStats calldata player1,
        FighterStats calldata player2,
        uint256 randomSeed,
        uint16 lethalityFactor
    ) external pure returns (bytes memory) {
        // Calculate all combat stats upfront
        CalculatedCombatStats memory p1Calculated = CalculatedCombatStats({
            stats: calculateStats(player1),
            weapon: getWeaponStats(player1.weapon),
            armor: getArmorStats(player1.armor),
            stanceMultipliers: getStanceMultiplier(player1.stance)
        });

        CalculatedCombatStats memory p2Calculated = CalculatedCombatStats({
            stats: calculateStats(player2),
            weapon: getWeaponStats(player2.weapon),
            armor: getArmorStats(player2.armor),
            stanceMultipliers: getStanceMultiplier(player2.stance)
        });

        // Apply stance modifiers to stats
        p1Calculated.stats = applyStanceModifiers(p1Calculated.stats, p1Calculated.stanceMultipliers);
        p2Calculated.stats = applyStanceModifiers(p2Calculated.stats, p2Calculated.stanceMultipliers);

        // Initialize combat with calculated stats
        CombatState memory state = initializeCombatState(randomSeed, p1Calculated, p2Calculated);

        bytes memory results = new bytes(4);
        uint8 roundCount = 0;
        uint256 currentSeed = randomSeed;

        while (state.p1Health > 0 && state.p2Health > 0 && roundCount < MAX_ROUNDS) {
            // Determine if anyone can attack this round, including stamina check
            bool canP1Attack =
                state.p1ActionPoints >= ATTACK_ACTION_COST
                && state.p1Stamina >= calculateStaminaCost(ActionType.ATTACK, p1Calculated);
            bool canP2Attack =
                state.p2ActionPoints >= ATTACK_ACTION_COST
                && state.p2Stamina >= calculateStaminaCost(ActionType.ATTACK, p2Calculated);

            // First check if any player has 0 health - this should take precedence
            if (state.p1Health == 0) {
                state.condition = WinCondition.HEALTH;
                state.player1Won = false; // Player 2 wins regardless of stamina
                break;
            } else if (state.p2Health == 0) {
                state.condition = WinCondition.HEALTH;
                state.player1Won = true; // Player 1 wins regardless of stamina
                break;
            }

            // Only check exhaustion if both players still have health
            if (!canP1Attack && canP2Attack && state.p1ActionPoints >= ATTACK_ACTION_COST) {
                state.condition = WinCondition.EXHAUSTION;
                state.player1Won = false; // Player 2 wins

                // Add this - record the exhaustion in the combat log
                results = appendCombatAction(
                    results,
                    uint8(CombatResultType.EXHAUSTED), // P1 result (exhausted)
                    0, // No damage
                    0, // No stamina cost
                    uint8(CombatResultType.HIT), // P2 result (HIT with 0 damage)
                    0, // No damage
                    0, // No stamina cost
                    true // P1 is "attacking" (for log purposes)
                );

                break;
            } else if (!canP2Attack && canP1Attack && state.p2ActionPoints >= ATTACK_ACTION_COST) {
                state.condition = WinCondition.EXHAUSTION;
                state.player1Won = true; // Player 1 wins
                break;
            }

            // After the other exhaustion checks add:
            if (
                !canP1Attack && !canP2Attack && state.p1ActionPoints >= ATTACK_ACTION_COST
                    && state.p2ActionPoints >= ATTACK_ACTION_COST
            ) {
                // Both players are exhausted - decide winner by health percentage
                uint256 p1HealthWide = uint256(state.p1Health);
                uint256 p2HealthWide = uint256(state.p2Health);
                uint256 p1MaxHealthWide = uint256(p1Calculated.stats.maxHealth);
                uint256 p2MaxHealthWide = uint256(p2Calculated.stats.maxHealth);

                // Calculate percentages using wider type
                uint256 p1HealthPct = (p1HealthWide * 100) / p1MaxHealthWide;
                uint256 p2HealthPct = (p2HealthWide * 100) / p2MaxHealthWide;

                // Then safely convert to uint32 for storage
                uint32 p1HealthPctFinal = p1HealthPct > type(uint32).max ? type(uint32).max : uint32(p1HealthPct);
                uint32 p2HealthPctFinal = p2HealthPct > type(uint32).max ? type(uint32).max : uint32(p2HealthPct);

                state.condition = WinCondition.EXHAUSTION;
                // Player with higher health percentage wins (P1 wins ties)
                state.player1Won = p1HealthPctFinal >= p2HealthPctFinal;
                break;
            }

            // Only process combat if someone can attack
            if (canP1Attack || canP2Attack) {
                bool isPlayer1Attacking;
                if (canP1Attack && canP2Attack) {
                    // Both can attack, strictly compare points
                    isPlayer1Attacking = (state.p1ActionPoints > state.p2ActionPoints)
                        || (state.p1ActionPoints == state.p2ActionPoints && state.p1HasInitiative);
                } else {
                    // Only one can attack
                    isPlayer1Attacking = canP1Attack;
                }

                state.isPlayer1Turn = isPlayer1Attacking;

                // Deduct points BEFORE processing round
                if (isPlayer1Attacking) {
                    state.p1ActionPoints -= ATTACK_ACTION_COST;
                } else {
                    state.p2ActionPoints -= ATTACK_ACTION_COST;
                }

                // Process round and update state - only if an attack happened
                (currentSeed, results) =
                    processRound(state, currentSeed, results, p1Calculated, p2Calculated, lethalityFactor);
            }

            roundCount++;

            // Add action points for both players AFTER everything else with overflow protection
            uint32 newP1Points = uint32(state.p1ActionPoints) + uint32(p1Calculated.weapon.attackSpeed);
            uint32 newP2Points = uint32(state.p2ActionPoints) + uint32(p2Calculated.weapon.attackSpeed);
            state.p1ActionPoints = newP1Points > type(uint16).max ? type(uint16).max : uint16(newP1Points);
            state.p2ActionPoints = newP2Points > type(uint16).max ? type(uint16).max : uint16(newP2Points);
        }

        if (roundCount >= MAX_ROUNDS) {
            state.condition = WinCondition.MAX_ROUNDS;
            state.player1Won = state.p1Health >= state.p2Health;
        }

        return encodeCombatResults(state, results);
    }

    function initializeCombatState(
        uint256 seed,
        CalculatedCombatStats memory p1Calculated,
        CalculatedCombatStats memory p2Calculated
    ) private pure returns (CombatState memory state) {
        state = CombatState({
            p1Health: uint96(p1Calculated.stats.maxHealth),
            p2Health: uint96(p2Calculated.stats.maxHealth),
            p1Stamina: uint32(p1Calculated.stats.maxEndurance),
            p2Stamina: uint32(p2Calculated.stats.maxEndurance),
            p1ActionPoints: 0,
            p2ActionPoints: 0,
            isPlayer1Turn: false,
            player1Won: false,
            condition: WinCondition.HEALTH,
            p1HasInitiative: false
        });

        // Calculate initiative but only store it in state for tiebreakers
        uint32 p1Initiative = calculateTotalInitiative(p1Calculated);
        uint32 p2Initiative = calculateTotalInitiative(p2Calculated);
        seed = uint256(keccak256(abi.encodePacked(seed)));
        state.p1HasInitiative = p1Initiative > p2Initiative || (p1Initiative == p2Initiative && seed.uniform(2) == 0);

        return state;
    }

    function calculateTotalInitiative(CalculatedCombatStats memory stats) private pure returns (uint32) {
        uint32 total = stats.stats.initiative * 4 + stats.weapon.attackSpeed * 2;
        uint32 penalty = stats.armor.weight > 70 ? 60 : stats.armor.weight > 30 ? 35 : stats.armor.weight > 10 ? 10 : 0;
        return total > penalty ? total - penalty : 1;
    }

    function processRound(
        CombatState memory state,
        uint256 currentSeed,
        bytes memory results,
        CalculatedCombatStats memory p1Calculated,
        CalculatedCombatStats memory p2Calculated,
        uint16 lethalityFactor
    ) private pure returns (uint256, bytes memory) {
        uint256 seed = currentSeed;

        // Process combat turn with seed updates
        (
            uint8 attackResult,
            uint16 attackDamage,
            uint8 attackStaminaCost,
            uint8 defenseResult,
            uint16 defenseDamage,
            uint8 defenseStaminaCost,
            uint256 newSeed
        ) = processCombatTurn(
            state.isPlayer1Turn ? p1Calculated : p2Calculated,
            state.isPlayer1Turn ? p2Calculated : p1Calculated,
            state.isPlayer1Turn ? state.p1Stamina : state.p2Stamina,
            state.isPlayer1Turn ? state.p2Stamina : state.p1Stamina,
            seed
        );

        // Update combat state with new seed
        seed = uint256(keccak256(abi.encodePacked(newSeed)));
        updateCombatState(
            state,
            attackDamage,
            attackStaminaCost,
            defenseResult,
            defenseDamage,
            defenseStaminaCost,
            p1Calculated,
            p2Calculated,
            seed,
            lethalityFactor
        );

        // Append results and return new seed
        results = appendCombatAction(
            results,
            attackResult,
            attackDamage,
            attackStaminaCost,
            defenseResult,
            defenseDamage,
            defenseStaminaCost,
            state.isPlayer1Turn
        );

        return (seed, results);
    }

    function calculateHitChance(CalculatedCombatStats memory attacker) private pure returns (uint8) {
        uint32 baseHitChance = uint32(attacker.stats.hitChance);
        uint32 weaponSpeedMod = 85 + ((uint32(attacker.weapon.attackSpeed) * 15) / 100);
        uint32 adjustedHitChance = (baseHitChance * weaponSpeedMod) / 100;
        uint32 withMin = adjustedHitChance < 70 ? 70 : adjustedHitChance;
        uint32 withBothBounds = withMin > 95 ? 95 : withMin;

        return uint8(withBothBounds);
    }

    function calculateDamage(CalculatedCombatStats memory attacker, uint256 seed)
        private
        pure
        returns (uint16 damage, uint256 nextSeed)
    {
        uint64 damageRange = attacker.weapon.maxDamage >= attacker.weapon.minDamage
            ? attacker.weapon.maxDamage - attacker.weapon.minDamage
            : 0;
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint64 baseDamage = uint64(attacker.weapon.minDamage) + uint64(seed.uniform(damageRange + 1));

        // Apply damage modifier as a percentage
        uint64 modifiedDamage = (baseDamage * uint64(attacker.stats.damageModifier)) / 100;

        nextSeed = uint256(keccak256(abi.encodePacked(seed)));
        return (modifiedDamage > type(uint16).max ? type(uint16).max : uint16(modifiedDamage), nextSeed);
    }

    /// @notice Apply PREDATOR MODE bonuses when attacking tired opponents
    function applyStaminaModifiers(
        CalculatedCombatStats memory attacker,
        uint32 defenderCurrentStamina,
        uint16 defenderMaxStamina
    ) private pure returns (CalculatedCombatStats memory) {
        uint256 defenderStaminaPercent = (uint256(defenderCurrentStamina) * 100) / defenderMaxStamina;

        if (defenderStaminaPercent >= 50) {
            return attacker; // No bonuses vs fresh opponents
        }

        if (defenderStaminaPercent >= 20) {
            // Tired opponent (50%-20%): Hit bonus with overflow protection
            uint32 newHitChance = uint32(attacker.stats.hitChance) + 10;
            attacker.stats.hitChance = newHitChance > type(uint16).max ? type(uint16).max : uint16(newHitChance);
        } else {
            // BLOOD IN THE WATER (<20%): PREDATOR MODE ACTIVATED!
            uint32 newHitChance = uint32(attacker.stats.hitChance) + 30;
            attacker.stats.hitChance = newHitChance > type(uint16).max ? type(uint16).max : uint16(newHitChance);

            uint32 newCritChance = uint32(attacker.stats.critChance) + 50;
            attacker.stats.critChance = newCritChance > type(uint16).max ? type(uint16).max : uint16(newCritChance);
            // DOUBLE DAMAGE with reasonable cap to prevent overflow in damage calculations
            uint32 doubleCritMult = uint32(attacker.stats.critMultiplier) * 2;
            attacker.stats.critMultiplier = doubleCritMult > 1000 ? 1000 : uint16(doubleCritMult);
        }

        return attacker;
    }

    /// @notice Apply defensive penalties to tired fighters
    function applyDefensivePenalties(CalculatedCombatStats memory defender, uint32 defenderCurrentStamina)
        private
        pure
        returns (CalculatedCombatStats memory)
    {
        // Shield Tanks (Tower Shield + Defensive Stance) are immune to stamina penalties
        if (
            defender.weapon.shieldType == ShieldType.TOWER_SHIELD
                && defender.stanceMultipliers.heavyArmorEffectiveness == 100
        ) {
            return defender; // No penalties for dedicated tank builds (Defensive Stance)
        }

        uint256 defenderStaminaPercent = (uint256(defenderCurrentStamina) * 100) / defender.stats.maxEndurance;

        if (defenderStaminaPercent >= 50) {
            return defender; // No penalties for fresh fighters
        }

        uint256 penalty;
        if (defenderStaminaPercent >= 20) {
            // Tired (50%-20%): -30% defensive stats
            penalty = 30;
        } else {
            // Exhausted (<20%): -40% defensive stats (reduced from 60% to help tanks)
            penalty = 40;
        }

        uint256 multiplier = 100 - penalty;
        defender.stats.blockChance = uint16((defender.stats.blockChance * multiplier) / 100);
        defender.stats.parryChance = uint16((defender.stats.parryChance * multiplier) / 100);
        defender.stats.dodgeChance = uint16((defender.stats.dodgeChance * multiplier) / 100);

        return defender;
    }

    function processCombatTurn(
        CalculatedCombatStats memory attacker,
        CalculatedCombatStats memory defender,
        uint256 attackerStamina,
        uint256 defenderStamina,
        uint256 seed
    )
        private
        pure
        returns (
            uint8 attackResult,
            uint16 attackDamage,
            uint8 attackStaminaCost,
            uint8 defenseResult,
            uint16 defenseDamage,
            uint8 defenseStaminaCost,
            uint256 newSeed
        )
    {
        uint256 attackCost = calculateStaminaCost(ActionType.ATTACK, attacker);
        if (attackerStamina < attackCost) {
            return (uint8(CombatResultType.EXHAUSTED), 0, uint8(attackCost), 0, 0, 0, seed);
        }

        // BLOOD IN THE WATER: Apply stamina-based combat modifiers
        CalculatedCombatStats memory modifiedAttacker =
            applyStaminaModifiers(attacker, uint32(defenderStamina), defender.stats.maxEndurance);
        CalculatedCombatStats memory modifiedDefender = applyDefensivePenalties(defender, uint32(defenderStamina));

        // Hit check with predator bonuses
        uint8 finalHitChance = calculateHitChance(modifiedAttacker);
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 hitRoll = uint8(seed.uniform(100));

        if (hitRoll >= finalHitChance) {
            uint8 safeAttackCost = attackCost > 255 ? 255 : uint8(attackCost);
            return (uint8(CombatResultType.ATTACK), 0, safeAttackCost, uint8(CombatResultType.MISS), 0, 0, seed);
        }

        // Process defense first with stamina penalties
        seed = uint256(keccak256(abi.encodePacked(seed)));
        (defenseResult, defenseDamage, defenseStaminaCost, seed) =
            processDefense(modifiedDefender, modifiedAttacker, defenderStamina, attackerStamina, seed);

        // Only calculate damage if defense failed
        if (defenseResult == uint8(CombatResultType.HIT)) {
            // Calculate base damage with predator bonuses
            uint16 baseDamage;
            (baseDamage, seed) = calculateDamage(modifiedAttacker, seed);

            // Check for crit with PREDATOR MODE bonuses
            seed = uint256(keccak256(abi.encodePacked(seed)));
            uint8 critRoll = uint8(seed.uniform(100));
            bool isCritical = critRoll < modifiedAttacker.stats.critChance;

            // Apply armor reduction FIRST (before crit multiplier)
            uint16 armorReducedDamage = applyDefensiveStats(
                baseDamage,
                modifiedDefender.armor,
                modifiedAttacker.weapon.damageType,
                modifiedAttacker.weapon.weaponClass,
                modifiedDefender.stanceMultipliers
            );

            if (isCritical) {
                // Apply both character and weapon crit multipliers AFTER armor reduction
                uint64 totalMultiplier =
                    (uint64(modifiedAttacker.stats.critMultiplier) * uint64(modifiedAttacker.weapon.critMultiplier))
                    / 100;
                uint64 critDamage = (uint64(armorReducedDamage) * totalMultiplier) / 100;
                attackDamage = critDamage > type(uint16).max ? type(uint16).max : uint16(critDamage);
                attackResult = uint8(CombatResultType.CRIT);
            } else {
                attackDamage = armorReducedDamage;
                attackResult = uint8(CombatResultType.ATTACK);
            }
        } else {
            attackResult = uint8(CombatResultType.ATTACK);
            attackDamage = 0;
        }

        attackStaminaCost = attackCost > 255 ? 255 : uint8(attackCost);
        return (attackResult, attackDamage, attackStaminaCost, defenseResult, defenseDamage, defenseStaminaCost, seed);
    }

    function processDefense(
        CalculatedCombatStats memory defender,
        CalculatedCombatStats memory attacker,
        uint256 defenderStamina,
        uint256 attackerStamina,
        uint256 seed
    ) private pure returns (uint8 result, uint16 damage, uint8 staminaCost, uint256 nextSeed) {
        // Check if defender has a shield
        if (defender.weapon.shieldType != ShieldType.NONE) {
            // Block check
            uint16 finalBlockChance = calculateFinalBlockChance(defender, attacker);
            seed = uint256(keccak256(abi.encodePacked(seed)));
            uint8 blockRoll = uint8(seed.uniform(100));

            if (blockRoll < finalBlockChance) {
                uint256 blockStaminaCost = calculateStaminaCost(ActionType.BLOCK, defender);
                if (defenderStamina >= blockStaminaCost) {
                    // Add block breakthrough chance for HEAVY_DEMOLITION weapons
                    if (attacker.weapon.weaponClass == WeaponClass.HEAVY_DEMOLITION) {
                        seed = uint256(keccak256(abi.encodePacked(seed)));
                        uint8 breakthroughRoll = uint8(seed.uniform(100));

                        // Heavy weapons get breakthrough based on their crushing power
                        // Slowest weapons (Battleaxe/Maul 40 speed) = 20%, others = 8%
                        uint16 breakthroughChance;
                        if (attacker.weapon.attackSpeed <= 40) {
                            breakthroughChance = 20; // Battleaxe, Maul - reduced for balance
                        } else {
                            breakthroughChance = 8; // Greatsword, Axe+Kite, Axe+Tower - reduced for balance
                        }

                        if (breakthroughRoll < breakthroughChance) {
                            // Breakthrough! Attack smashes through the shield
                            return (uint8(CombatResultType.HIT), 0, 0, seed);
                        }
                    }

                    // Regular block success logic continues...
                    // Check for counter
                    seed = uint256(keccak256(abi.encodePacked(seed)));
                    uint8 counterRoll = uint8(seed.uniform(100));

                    (, uint16 shieldCounterBonus,,) = getShieldStats(defender.weapon.shieldType);
                    uint32 effectiveCounterChance = uint32(defender.stats.counterChance);
                    effectiveCounterChance = uint32((effectiveCounterChance * uint32(shieldCounterBonus)) / 100);

                    if (counterRoll < effectiveCounterChance) {
                        seed = uint256(keccak256(abi.encodePacked(seed)));
                        return processCounterAttack(
                            defender, attacker, defenderStamina, attackerStamina, seed, CounterType.COUNTER
                        );
                    }
                    uint8 safeBlockCost = blockStaminaCost > 255 ? 255 : uint8(blockStaminaCost);
                    return (uint8(CombatResultType.BLOCK), 0, safeBlockCost, seed);
                }
            }
        }

        // Parry check
        uint16 finalParryChance = calculateFinalParryChance(defender, attacker);
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 parryRoll = uint8(seed.uniform(100));

        if (parryRoll < finalParryChance) {
            uint256 parryStaminaCost = calculateStaminaCost(ActionType.PARRY, defender);
            if (defenderStamina >= parryStaminaCost) {
                seed = uint256(keccak256(abi.encodePacked(seed)));
                uint8 riposteRoll = uint8(seed.uniform(100));

                uint32 effectiveRiposteChance32 =
                    (uint32(defender.stats.riposteChance) * uint32(defender.weapon.riposteChance)) / 100;

                // Add riposte bonus vs HEAVY_DEMOLITION weapons - technical weapons counter brute force
                if (attacker.weapon.weaponClass == WeaponClass.HEAVY_DEMOLITION) {
                    // Technical weapons get bonus ripostes vs heavy weapons
                    uint16 riposteBonus = 15; // Fixed 15% bonus vs HEAVY_DEMOLITION
                    // No capping needed - fixed value
                    effectiveRiposteChance32 += riposteBonus;
                }

                uint16 effectiveRiposteChance =
                    effectiveRiposteChance32 > type(uint16).max ? type(uint16).max : uint16(effectiveRiposteChance32);

                if (riposteRoll < effectiveRiposteChance) {
                    seed = uint256(keccak256(abi.encodePacked(seed)));
                    return
                        processCounterAttack(
                            defender, attacker, defenderStamina, attackerStamina, seed, CounterType.PARRY
                        );
                }
                uint8 safeParryCost = parryStaminaCost > 255 ? 255 : uint8(parryStaminaCost);
                return (uint8(CombatResultType.PARRY), 0, safeParryCost, seed);
            }
        }

        // Dodge check
        uint16 finalDodgeChance = calculateFinalDodgeChance(defender, attacker);
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 dodgeRoll = uint8(seed.uniform(100));

        if (dodgeRoll < finalDodgeChance) {
            uint256 dodgeStaminaCost = calculateStaminaCost(ActionType.DODGE, defender);
            if (defenderStamina >= dodgeStaminaCost) {
                uint8 safeDodgeCost = dodgeStaminaCost > 255 ? 255 : uint8(dodgeStaminaCost);
                return (uint8(CombatResultType.DODGE), 0, safeDodgeCost, seed);
            }
        }

        // If all defensive actions fail, return HIT result
        return (uint8(CombatResultType.HIT), 0, 0, seed);
    }

    function calculateFinalBlockChance(CalculatedCombatStats memory defender, CalculatedCombatStats memory attacker)
        internal
        pure
        returns (uint16)
    {
        uint32 baseBlockChance = uint32(defender.stats.blockChance);

        // Apply shield bonus first
        (uint16 shieldBlockBonus,,,) = getShieldStats(defender.weapon.shieldType);
        baseBlockChance = uint32(baseBlockChance * uint32(shieldBlockBonus)) / 100;

        // Apply weapon class modifiers - only bonus for LIGHT_FINESSE
        if (attacker.weapon.weaponClass == WeaponClass.LIGHT_FINESSE) {
            // LIGHT_FINESSE weapons are easier to block (bonus)
            uint32 blockBonus = 15; // Fixed 15% bonus
            baseBlockChance = baseBlockChance + blockBonus;
        }
        // HEAVY_DEMOLITION no longer gets a penalty - handled by breakthrough mechanic instead
        uint16 adjustedBlockChance = baseBlockChance > 80 ? 80 : uint16(baseBlockChance);
        return adjustedBlockChance;
    }

    function calculateFinalParryChance(
        CalculatedCombatStats memory defender,
        CalculatedCombatStats memory /* attacker */
    )
        internal
        pure
        returns (uint16)
    {
        // Calculate base parry chance
        uint32 baseParryChance = (uint32(defender.stats.parryChance) * uint32(defender.weapon.parryChance)) / 100;

        uint16 adjustedParryChance = baseParryChance > 80 ? 80 : uint16(baseParryChance);
        return adjustedParryChance;
    }

    function calculateFinalDodgeChance(CalculatedCombatStats memory defender, CalculatedCombatStats memory attacker)
        internal
        pure
        returns (uint16)
    {
        // HEAVY_DEMOLITION weapons cannot dodge at all
        if (defender.weapon.weaponClass == WeaponClass.HEAVY_DEMOLITION) {
            return 0;
        }

        uint32 baseDodgeChance = uint32(defender.stats.dodgeChance);
        // Add reach weapon dodge bonus
        if (defender.weapon.weaponClass == WeaponClass.REACH_CONTROL) {
            baseDodgeChance += uint32(REACH_DODGE_BONUS);
        }

        // Calculate dodge bonus vs different weapon classes
        uint32 classDodgeBonus = 0;
        if (attacker.weapon.weaponClass == WeaponClass.HEAVY_DEMOLITION) {
            // HEAVY_DEMOLITION weapons are significantly easier to dodge (telegraphed swings)
            classDodgeBonus = 15; // Major bonus vs heavy weapons
        } else if (
            attacker.weapon.weaponClass == WeaponClass.DUAL_WIELD_BRUTE
                || attacker.weapon.weaponClass == WeaponClass.PURE_BLUNT
        ) {
            // DUAL_WIELD_BRUTE and PURE_BLUNT are moderately easier to dodge
            classDodgeBonus = 5; // Moderate bonus vs these weapon types
        }
        // Other weapon classes get no dodge bonus

        // Add class bonus to base dodge
        uint32 totalDodgeBeforeArmor = baseDodgeChance + classDodgeBonus;

        // Apply armor penalties to the total dodge (base + speed bonus)
        uint32 adjustedDodgeChance;
        if (defender.armor.weight <= 10) {
            // Cloth
            adjustedDodgeChance = totalDodgeBeforeArmor; // No penalty
        } else if (defender.armor.weight <= 30) {
            // Leather
            adjustedDodgeChance = (totalDodgeBeforeArmor * 80) / 100;
        } else if (defender.armor.weight <= 70) {
            // Chain
            adjustedDodgeChance = (totalDodgeBeforeArmor * 60) / 100;
        } else {
            // Plate
            adjustedDodgeChance = (totalDodgeBeforeArmor * 20) / 100; // Minimal dodge
        }

        // Apply shield effect
        if (defender.weapon.shieldType != ShieldType.NONE) {
            (,, uint16 dodgeModifier,) = getShieldStats(defender.weapon.shieldType);
            adjustedDodgeChance = (adjustedDodgeChance * uint32(dodgeModifier)) / 100;
        }

        // Cap the dodge chance
        uint32 cappedDodge = adjustedDodgeChance > 70 ? 70 : adjustedDodgeChance;
        return uint16(cappedDodge);
    }

    function processCounterAttack(
        CalculatedCombatStats memory defender,
        CalculatedCombatStats memory target,
        uint256, /* defenderStamina */
        uint256 targetStamina,
        uint256 seed,
        CounterType counterType
    ) private pure returns (uint8 result, uint16 damage, uint8 staminaCost, uint256 nextSeed) {
        // BLOOD IN THE WATER: Apply stamina modifiers for counter attacks
        CalculatedCombatStats memory modifiedDefender =
            applyStaminaModifiers(defender, uint32(targetStamina), target.stats.maxEndurance);
        CalculatedCombatStats memory modifiedTarget = applyDefensivePenalties(target, uint32(targetStamina));
        uint16 counterDamage;
        (counterDamage, seed) = calculateDamage(modifiedDefender, seed);

        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 critRoll = uint8(seed.uniform(100));
        bool isCritical = critRoll < modifiedDefender.stats.critChance;

        ActionType actionType = counterType == CounterType.PARRY ? ActionType.RIPOSTE : ActionType.COUNTER;

        // Apply armor reduction FIRST (before crit multiplier)
        uint16 armorReducedDamage = applyDefensiveStats(
            counterDamage,
            modifiedTarget.armor,
            modifiedDefender.weapon.damageType,
            modifiedDefender.weapon.weaponClass,
            modifiedTarget.stanceMultipliers
        );

        if (isCritical) {
            // Use uint64 for intermediate calculations to prevent overflow
            uint64 totalMultiplier =
                (uint64(modifiedDefender.stats.critMultiplier) * uint64(modifiedDefender.weapon.critMultiplier)) / 100;

            // Calculate damage with overflow protection AFTER armor reduction
            uint64 critDamage = (uint64(armorReducedDamage) * totalMultiplier) / 100;
            counterDamage = critDamage > type(uint16).max ? type(uint16).max : uint16(critDamage);

            uint256 critModifiedStaminaCost = calculateStaminaCost(actionType, modifiedDefender);
            uint8 safeCost = critModifiedStaminaCost > 255 ? 255 : uint8(critModifiedStaminaCost);

            seed = uint256(keccak256(abi.encodePacked(seed)));
            return (
                uint8(counterType == CounterType.PARRY ? CombatResultType.RIPOSTE_CRIT : CombatResultType.COUNTER_CRIT),
                counterDamage,
                safeCost,
                seed
            );
        } else {
            // Use armor-reduced damage for non-critical hits
            counterDamage = armorReducedDamage;
        }

        uint256 normalModifiedStaminaCost = calculateStaminaCost(actionType, modifiedDefender);
        uint8 safeNormalCost = normalModifiedStaminaCost > 255 ? 255 : uint8(normalModifiedStaminaCost);

        seed = uint256(keccak256(abi.encodePacked(seed)));
        return (
            uint8(counterType == CounterType.PARRY ? CombatResultType.RIPOSTE : CombatResultType.COUNTER),
            counterDamage,
            safeNormalCost,
            seed
        );
    }

    function applyDefensiveStats(
        uint16 incomingDamage,
        ArmorStats memory armor,
        DamageType damageType,
        WeaponClass weaponClass,
        StanceMultiplier memory stance
    ) private pure returns (uint16) {
        // Apply stance armor effectiveness only to plate armor (weight >= 100)
        uint16 armorEff = armor.weight >= 100 ? stance.heavyArmorEffectiveness : 100;
        uint32 effectiveDefense = (uint32(armor.defense) * armorEff) / 100;
        uint16 baseResistance = getResistanceForDamageType(armor, damageType);
        uint32 effectiveResistance = (uint32(baseResistance) * armorEff) / 100;

        // First apply flat reduction with stance modifier
        uint32 afterFlat = incomingDamage > effectiveDefense ? uint32(incomingDamage) - effectiveDefense : 0;

        // Calculate armor penetration for HEAVY_DEMOLITION weapons vs heavy armor
        uint32 armorPen = 0;
        if (weaponClass == WeaponClass.HEAVY_DEMOLITION && armor.weight >= 50) {
            // HEAVY_DEMOLITION weapons vs heavy armors get fixed penetration
            armorPen = 30; // Fixed 30% armor penetration for heavy weapons
        }

        // Then apply percentage reduction with armor penetration
        uint32 reductionPercent = effectiveResistance > 90 ? 90 : effectiveResistance;
        reductionPercent = armorPen >= reductionPercent ? 0 : reductionPercent - armorPen;
        uint32 finalDamage = (afterFlat * (100 - reductionPercent)) / 100;

        return finalDamage > type(uint16).max ? type(uint16).max : uint16(finalDamage == 0 ? 1 : finalDamage);
    }

    function getResistanceForDamageType(ArmorStats memory armor, DamageType damageType) private pure returns (uint16) {
        return damageType == DamageType.Slashing ? armor.slashResist :
               damageType == DamageType.Piercing ? armor.pierceResist :
               damageType == DamageType.Blunt ? armor.bluntResist :
               damageType == DamageType.Hybrid_Slash_Pierce ? (armor.slashResist < armor.pierceResist ? armor.slashResist : armor.pierceResist) :
               damageType == DamageType.Hybrid_Slash_Blunt ? (armor.slashResist < armor.bluntResist ? armor.slashResist : armor.bluntResist) :
               damageType == DamageType.Hybrid_Pierce_Blunt ? (armor.pierceResist < armor.bluntResist ? armor.pierceResist : armor.bluntResist) : 0;
    }

    // Improved to prevent overflow when applying high multipliers (180%)
    function applyStanceModifiers(CalculatedStats memory stats, StanceMultiplier memory stance)
        private
        pure
        returns (CalculatedStats memory)
    {
        // Use uint32 for all intermediate calculations to prevent overflow
        uint32 hitChance = (uint32(stats.hitChance) * uint32(stance.hitChance)) / 100;
        uint32 dodgeChance = (uint32(stats.dodgeChance) * uint32(stance.dodgeChance)) / 100;
        uint32 blockChance = (uint32(stats.blockChance) * uint32(stance.blockChance)) / 100;
        uint32 parryChance = (uint32(stats.parryChance) * uint32(stance.parryChance)) / 100;
        uint32 critChance = (uint32(stats.critChance) * uint32(stance.critChance)) / 100;
        uint32 critMultiplier = (uint32(stats.critMultiplier) * uint32(stance.critMultiplier)) / 100;
        uint32 counterChance = (uint32(stats.counterChance) * uint32(stance.counterChance)) / 100;
        uint32 riposteChance = (uint32(stats.riposteChance) * uint32(stance.riposteChance)) / 100;
        uint32 damageModifier = (uint32(stats.damageModifier) * uint32(stance.damageModifier)) / 100;

        // Safely cap all values to uint16 max before returning
        return CalculatedStats({
            maxHealth: stats.maxHealth,
            maxEndurance: stats.maxEndurance,
            initiative: stats.initiative,
            hitChance: hitChance > type(uint16).max ? type(uint16).max : uint16(hitChance),
            dodgeChance: dodgeChance > type(uint16).max ? type(uint16).max : uint16(dodgeChance),
            blockChance: blockChance > type(uint16).max ? type(uint16).max : uint16(blockChance),
            parryChance: parryChance > type(uint16).max ? type(uint16).max : uint16(parryChance),
            critChance: critChance > type(uint16).max ? type(uint16).max : uint16(critChance),
            critMultiplier: critMultiplier > type(uint16).max ? type(uint16).max : uint16(critMultiplier),
            counterChance: counterChance > type(uint16).max ? type(uint16).max : uint16(counterChance),
            riposteChance: riposteChance > type(uint16).max ? type(uint16).max : uint16(riposteChance),
            damageModifier: damageModifier > type(uint16).max ? type(uint16).max : uint16(damageModifier),
            baseSurvivalRate: stats.baseSurvivalRate
        });
    }

    function applyDamageAndCheckLethality(
        CombatState memory state,
        uint16 damage,
        CalculatedCombatStats memory attackerStats,
        CalculatedCombatStats memory defenderStats,
        bool isPlayer1Attacker,
        uint256 seed,
        uint16 lethalityFactor
    ) private pure {
        uint96 currentHealth = isPlayer1Attacker ? state.p2Health : state.p1Health;

        // Check if this hit would reduce health to zero
        bool wouldKill = damage >= currentHealth;

        // Apply damage normally
        currentHealth = currentHealth > damage ? currentHealth - damage : 0;

        if (isPlayer1Attacker) {
            state.p2Health = currentHealth;
        } else {
            state.p1Health = currentHealth;
        }

        // Only check for lethal damage if health is 0 and lethalityFactor is enabled
        if (currentHealth == 0 && wouldKill && lethalityFactor > 0) {
            bool survived = !isLethalDamage(
                damage,
                defenderStats.stats.maxHealth,
                defenderStats.stats,
                attackerStats.weapon,
                defenderStats.stanceMultipliers,
                seed,
                lethalityFactor
            );

            // If they survived the lethal blow, it's a KO (not death)
            if (survived) {
                // Survived the death save - results in KO, not death
                state.player1Won = isPlayer1Attacker;
                state.condition = WinCondition.HEALTH;
            } else {
                // Failed the death save - they died
                state.player1Won = isPlayer1Attacker;
                state.condition = WinCondition.DEATH;
            }
        } else if (currentHealth == 0) {
            // Normal KO by reducing health to 0
            state.player1Won = isPlayer1Attacker;
            state.condition = WinCondition.HEALTH;
        }
    }

    function updateCombatState(
        CombatState memory state,
        uint16 attackDamage,
        uint8 attackStaminaCost,
        uint8 defenseResult,
        uint16 defenseDamage,
        uint8 defenseStaminaCost,
        CalculatedCombatStats memory p1Calculated,
        CalculatedCombatStats memory p2Calculated,
        uint256 seed,
        uint16 lethalityFactor
    ) private pure {
        // Apply stamina costs based on turn
        uint32 attackerStamina = state.isPlayer1Turn ? state.p1Stamina : state.p2Stamina;
        uint32 defenderStamina = state.isPlayer1Turn ? state.p2Stamina : state.p1Stamina;

        attackerStamina = attackerStamina > attackStaminaCost ? attackerStamina - attackStaminaCost : 0;
        defenderStamina = defenderStamina > defenseStaminaCost ? defenderStamina - defenseStaminaCost : 0;

        if (state.isPlayer1Turn) {
            state.p1Stamina = attackerStamina;
            state.p2Stamina = defenderStamina;
        } else {
            state.p2Stamina = attackerStamina;
            state.p1Stamina = defenderStamina;
        }

        // Apply attack damage if defense wasn't successful
        if (
            defenseResult != uint8(CombatResultType.PARRY) && defenseResult != uint8(CombatResultType.BLOCK)
                && defenseResult != uint8(CombatResultType.DODGE) && defenseResult != uint8(CombatResultType.COUNTER)
                && defenseResult != uint8(CombatResultType.COUNTER_CRIT)
                && defenseResult != uint8(CombatResultType.RIPOSTE)
                && defenseResult != uint8(CombatResultType.RIPOSTE_CRIT)
        ) {
            applyDamageAndCheckLethality(
                state,
                attackDamage,
                state.isPlayer1Turn ? p1Calculated : p2Calculated,
                state.isPlayer1Turn ? p2Calculated : p1Calculated,
                state.isPlayer1Turn,
                seed,
                lethalityFactor
            );
        }

        // Apply counter damage if any AND defender is still alive
        if (
            defenseDamage > 0
                && ((state.isPlayer1Turn && state.p2Health > 0) || (!state.isPlayer1Turn && state.p1Health > 0))
        ) {
            applyDamageAndCheckLethality(
                state,
                defenseDamage,
                state.isPlayer1Turn ? p2Calculated : p1Calculated,
                state.isPlayer1Turn ? p1Calculated : p2Calculated,
                !state.isPlayer1Turn,
                uint256(keccak256(abi.encodePacked(seed))),
                lethalityFactor
            );
        }
    }

    /**
     * @dev Combat action byte layout (8 bytes total):
     * Player 1's data is always in bytes 0-3, Player 2's data in bytes 4-7
     * For each player's 4-byte section:
     * - Byte 0: Result type (attack/defense)
     * - Bytes 1-2: Damage value (high byte, low byte)
     * - Byte 3: Stamina cost
     * @param results The existing combat log to append to
     * @param attackResult The result type of the attack action
     * @param attackDamage The damage dealt by the attack
     * @param attackStaminaCost The stamina cost of the attack
     * @param defenseResult The result type of the defense action
     * @param defenseDamage The damage dealt by any counter-attack
     * @param defenseStaminaCost The stamina cost of the defense
     * @param isPlayer1Attacking Whether Player 1 is the attacker in this action
     * @return The updated combat log with the new action appended
     */
    function appendCombatAction(
        bytes memory results,
        uint8 attackResult,
        uint16 attackDamage,
        uint8 attackStaminaCost,
        uint8 defenseResult,
        uint16 defenseDamage,
        uint8 defenseStaminaCost,
        bool isPlayer1Attacking
    ) private pure returns (bytes memory) {
        bytes memory actionData = new bytes(8);

        // Pack attacker and defender data into the correct player positions
        if (isPlayer1Attacking) {
            packPlayerData(actionData, 0, attackResult, attackDamage, attackStaminaCost); // P1 attack
            packPlayerData(actionData, 4, defenseResult, defenseDamage, defenseStaminaCost); // P2 defense
        } else {
            packPlayerData(actionData, 0, defenseResult, defenseDamage, defenseStaminaCost); // P1 defense
            packPlayerData(actionData, 4, attackResult, attackDamage, attackStaminaCost); // P2 attack
        }

        return bytes.concat(results, actionData);
    }

    /**
     * @dev Packs a player's combat data into 4 bytes starting at the specified offset
     * @param data The byte array to pack into
     * @param offset Starting position in the byte array (0 or 4)
     * @param result Action result type
     * @param damage Damage value (packed into 2 bytes)
     * @param staminaCost Stamina cost
     */
    function packPlayerData(bytes memory data, uint256 offset, uint8 result, uint16 damage, uint8 staminaCost)
        private
        pure
    {
        data[offset] = bytes1(result);
        data[offset + 1] = bytes1(uint8(damage >> 8));
        data[offset + 2] = bytes1(uint8(damage));
        data[offset + 3] = bytes1(staminaCost);
    }

    /// @dev TODO: Potential optimization - Instead of allocating prefix bytes (winner, version, condition) upfront
    /// and carrying them through combat, consider only storing combat actions during the fight and concatenating
    /// the prefix at the end. This would reduce memory copying in appendCombatAction and be more gas efficient.
    function encodeCombatResults(CombatState memory state, bytes memory results) private pure returns (bytes memory) {
        if (results.length < 4) revert InvalidResults();

        // Write single byte for winner (0 for player1, 1 for player2)
        results[0] = bytes1(state.player1Won ? uint8(0) : uint8(1));

        // Write version (2 bytes)
        results[1] = bytes1(uint8(version >> 8));
        results[2] = bytes1(uint8(version));

        // Write condition
        results[3] = bytes1(uint8(state.condition));

        return results;
    }

    function calculateStaminaCost(ActionType actionType, CalculatedCombatStats memory stats)
        internal
        pure
        returns (uint256)
    {
        // Get base cost by action type
        uint256 baseCost;
        if (actionType == ActionType.ATTACK) {
            baseCost = STAMINA_ATTACK;
        } else if (actionType == ActionType.BLOCK) {
            baseCost = STAMINA_BLOCK;
        } else if (actionType == ActionType.DODGE) {
            baseCost = STAMINA_DODGE;
        } else if (actionType == ActionType.PARRY) {
            baseCost = STAMINA_PARRY;
        } else if (actionType == ActionType.COUNTER) {
            baseCost = STAMINA_COUNTER;
        } else if (actionType == ActionType.RIPOSTE) {
            baseCost = STAMINA_RIPOSTE;
        }

        // Use uint256 for all intermediate calculations
        uint256 staminaCost = baseCost;

        // Apply stance modifier
        staminaCost = (staminaCost * uint256(stats.stanceMultipliers.staminaCostModifier)) / 100;

        // Apply weapon modifier only to weapon-related actions
        if (
            actionType == ActionType.ATTACK || actionType == ActionType.PARRY || actionType == ActionType.COUNTER
                || actionType == ActionType.RIPOSTE
        ) {
            staminaCost = (staminaCost * uint256(stats.weapon.staminaMultiplier)) / 100;
        }

        // Apply shield modifier only for block action
        if (actionType == ActionType.BLOCK && stats.weapon.shieldType != ShieldType.NONE) {
            (,,, uint16 shieldStaminaModifier) = getShieldStats(stats.weapon.shieldType);
            staminaCost = (staminaCost * uint256(shieldStaminaModifier)) / 100;
        }

        // Calculate armor impact using uint256
        uint256 armorImpact = 100 + (actionType == ActionType.DODGE ? 
            (uint256(stats.armor.weight) * 3 / 2) : (uint256(stats.armor.weight) / 10));

        // Apply armor impact
        staminaCost = (staminaCost * armorImpact) / 100;

        return staminaCost;
    }

    // =============================================
    // WEAPON STATS
    // =============================================

    function ARMING_SWORD_KITE() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 35,
            maxDamage: 43,
            attackSpeed: 75,
            parryChance: 140,
            riposteChance: 100,
            critMultiplier: 175,
            staminaMultiplier: 100,
            survivalFactor: 100,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.KITE_SHIELD,
            weaponClass: WeaponClass.BALANCED_SWORD
        });
    }

    function MACE_TOWER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 33,
            maxDamage: 42,
            attackSpeed: 70,
            parryChance: 140,
            riposteChance: 85,
            critMultiplier: 190,
            staminaMultiplier: 85,
            survivalFactor: 130,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.TOWER_SHIELD,
            weaponClass: WeaponClass.PURE_BLUNT
        });
    }

    function RAPIER_BUCKLER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 40,
            maxDamage: 52,
            attackSpeed: 90,
            parryChance: 155,
            riposteChance: 140,
            critMultiplier: 190,
            staminaMultiplier: 105,
            survivalFactor: 120,
            damageType: DamageType.Piercing,
            shieldType: ShieldType.BUCKLER,
            weaponClass: WeaponClass.LIGHT_FINESSE
        });
    }

    function GREATSWORD() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 76,
            maxDamage: 85,
            attackSpeed: 60,
            parryChance: 120,
            riposteChance: 70,
            critMultiplier: 190,
            staminaMultiplier: 260,
            survivalFactor: 90,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.NONE,
            weaponClass: WeaponClass.HEAVY_DEMOLITION
        });
    }

    function BATTLEAXE() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 130,
            maxDamage: 140,
            attackSpeed: 40,
            parryChance: 70,
            riposteChance: 40,
            critMultiplier: 230,
            staminaMultiplier: 280,
            survivalFactor: 80,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.NONE,
            weaponClass: WeaponClass.HEAVY_DEMOLITION
        });
    }

    function QUARTERSTAFF() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 42,
            maxDamage: 54,
            attackSpeed: 80,
            parryChance: 140,
            riposteChance: 120,
            critMultiplier: 160,
            staminaMultiplier: 110,
            survivalFactor: 110,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.NONE,
            weaponClass: WeaponClass.REACH_CONTROL
        });
    }

    function SPEAR() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 46,
            maxDamage: 58,
            attackSpeed: 80,
            parryChance: 130,
            riposteChance: 140,
            critMultiplier: 145,
            staminaMultiplier: 120,
            survivalFactor: 90,
            damageType: DamageType.Piercing,
            shieldType: ShieldType.NONE,
            weaponClass: WeaponClass.REACH_CONTROL
        });
    }

    function SHORTSWORD_BUCKLER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 40, // Buffed to 38-40 DPR range
            maxDamage: 52, // Buffed to 38-40 DPR range
            attackSpeed: 90,
            parryChance: 160, // v28: Moderate buff +45 - not overwhelming vs assassins
            riposteChance: 145, // v28: Moderate buff +45 - not overwhelming vs assassins
            critMultiplier: 160,
            staminaMultiplier: 100, // Light finesse efficient
            survivalFactor: 120,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.BUCKLER,
            weaponClass: WeaponClass.LIGHT_FINESSE
        });
    }

    function SHORTSWORD_TOWER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 32, // Nerfed to target ~31 DPR range (tower shields should be lowest)
            maxDamage: 40, // Nerfed to target ~31 DPR range (tower shields should be lowest)
            attackSpeed: 85,
            parryChance: 120,
            riposteChance: 80,
            critMultiplier: 120,
            staminaMultiplier: 100,
            survivalFactor: 125,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.TOWER_SHIELD,
            weaponClass: WeaponClass.LIGHT_FINESSE
        });
    }

    function SCIMITAR_BUCKLER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 38, // Buckler weapons get slight damage advantage over tower shields
            maxDamage: 50, // Buckler weapons get slight damage advantage over tower shields
            attackSpeed: 85,
            parryChance: 145, // v28: Moderate buff +45 - not overwhelming vs assassins
            riposteChance: 135, // v28: Moderate buff +45 - not overwhelming vs assassins
            critMultiplier: 180,
            staminaMultiplier: 110, // Curved blade balanced
            survivalFactor: 120,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.BUCKLER,
            weaponClass: WeaponClass.CURVED_BLADE
        });
    }

    function AXE_KITE() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 36, // Shield principle: kite shields prioritize defense over damage (~30 DPR)
            maxDamage: 44, // Shield principle: kite shields prioritize defense over damage (~30 DPR)
            attackSpeed: 70,
            parryChance: 120,
            riposteChance: 85,
            critMultiplier: 200,
            staminaMultiplier: 220, // High cost for shield + heavy demolition combo
            survivalFactor: 105,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.KITE_SHIELD,
            weaponClass: WeaponClass.HEAVY_DEMOLITION
        });
    }

    function AXE_TOWER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 34, // Shield principle: tower shields prioritize maximum defense (~25 DPR)
            maxDamage: 43, // Shield principle: tower shields prioritize maximum defense (~25 DPR)
            attackSpeed: 65,
            parryChance: 50, // Made really weak at parry
            riposteChance: 65,
            critMultiplier: 230, // v28: Reduced from 270 - dial back 2k+ crits
            staminaMultiplier: 180, // High cost for shield + heavy demolition combo
            survivalFactor: 120,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.TOWER_SHIELD,
            weaponClass: WeaponClass.HEAVY_DEMOLITION
        });
    }

    function MACE_KITE() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 43, // Shield principle: kite shields prioritize defense over damage (~30 DPR)
            maxDamage: 53, // Shield principle: kite shields prioritize defense over damage (~30 DPR)
            attackSpeed: 65,
            parryChance: 160,
            riposteChance: 100,
            critMultiplier: 200,
            staminaMultiplier: 105,
            survivalFactor: 110,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.KITE_SHIELD,
            weaponClass: WeaponClass.PURE_BLUNT
        });
    }

    function CLUB_TOWER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 33, // Shield principle: tower shields prioritize maximum defense (~25 DPR)
            maxDamage: 42, // Shield principle: tower shields prioritize maximum defense (~25 DPR)
            attackSpeed: 70,
            parryChance: 75,
            riposteChance: 65,
            critMultiplier: 230,
            staminaMultiplier: 75, // Tower shields should be very sustainable
            survivalFactor: 125,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.TOWER_SHIELD,
            weaponClass: WeaponClass.PURE_BLUNT
        });
    }

    // Dual-wield weapons
    function DUAL_DAGGERS() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 39, // v28: Buffed +22% total for better balance vs cloth
            maxDamage: 61, // v28: Buffed +22% total for better balance vs cloth
            attackSpeed: 115,
            parryChance: 70,
            riposteChance: 70,
            critMultiplier: 165, // v28: Boosted assassin crits further
            staminaMultiplier: 105, // v28: Moderate nerf - burn out vs tanks but sustain vs cloth
            survivalFactor: 95,
            damageType: DamageType.Piercing,
            shieldType: ShieldType.NONE,
            weaponClass: WeaponClass.LIGHT_FINESSE
        });
    }

    function RAPIER_DAGGER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 48, // v28: Buffed +20% total for better balance vs cloth
            maxDamage: 62, // v28: Buffed +22% total for better balance vs cloth
            attackSpeed: 100,
            parryChance: 185, // v28: Moderate buff +45 - not overwhelming vs assassins
            riposteChance: 155, // v28: Moderate buff +45 - not overwhelming vs assassins
            critMultiplier: 155, // v28: Boosted assassin crits further
            staminaMultiplier: 115, // v28: Moderate nerf - burn out vs tanks but sustain vs cloth
            survivalFactor: 110,
            damageType: DamageType.Piercing,
            shieldType: ShieldType.NONE,
            weaponClass: WeaponClass.LIGHT_FINESSE
        });
    }

    function DUAL_SCIMITARS() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 48, // v28: Buffed +20% total for better balance vs cloth
            maxDamage: 62, // v28: Buffed +22% total for better balance vs cloth
            attackSpeed: 100,
            parryChance: 80,
            riposteChance: 80,
            critMultiplier: 170, // v28: Boosted assassin crits further
            staminaMultiplier: 125, // v28: Moderate nerf - burn out vs tanks but sustain vs cloth
            survivalFactor: 90,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.NONE,
            weaponClass: WeaponClass.CURVED_BLADE
        });
    }

    function DUAL_CLUBS() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 54, // v28: Buffed +6% to counter Shield Tanks
            maxDamage: 66, // v28: Buffed +6% to counter Shield Tanks
            attackSpeed: 85,
            parryChance: 50,
            riposteChance: 50,
            critMultiplier: 180,
            staminaMultiplier: 145, // v28: Better efficiency vs Shield Tanks
            survivalFactor: 95,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.NONE,
            weaponClass: WeaponClass.DUAL_WIELD_BRUTE
        });
    }

    // Mixed damage type weapons
    function ARMING_SWORD_SHORTSWORD() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 45,
            maxDamage: 60,
            attackSpeed: 85,
            parryChance: 130,
            riposteChance: 150,
            critMultiplier: 180,
            staminaMultiplier: 130,
            survivalFactor: 90,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.NONE,
            weaponClass: WeaponClass.BALANCED_SWORD
        });
    }

    function SCIMITAR_DAGGER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 46, // v28: Buffed +21% total for better balance vs cloth
            maxDamage: 60, // v28: Buffed +22% total for better balance vs cloth
            attackSpeed: 105,
            parryChance: 185, // v28: Moderate buff +45 - not overwhelming vs assassins
            riposteChance: 155, // v28: Moderate buff +45 - not overwhelming vs assassins
            critMultiplier: 185, // v28: Boosted assassin crits further
            staminaMultiplier: 120, // v28: Moderate nerf - burn out vs tanks but sustain vs cloth
            survivalFactor: 100,
            damageType: DamageType.Hybrid_Slash_Pierce,
            shieldType: ShieldType.NONE,
            weaponClass: WeaponClass.CURVED_BLADE
        });
    }

    function ARMING_SWORD_CLUB() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 50, // Buffed to target ~45 DPR range
            maxDamage: 65, // Buffed to target ~45 DPR range
            attackSpeed: 75,
            parryChance: 90,
            riposteChance: 65,
            critMultiplier: 240,
            staminaMultiplier: 115,
            survivalFactor: 100,
            damageType: DamageType.Hybrid_Slash_Blunt,
            shieldType: ShieldType.NONE,
            weaponClass: WeaponClass.BALANCED_SWORD
        });
    }

    function AXE_MACE() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 66, // v28: Buffed +6% to counter Shield Tanks
            maxDamage: 90, // v28: Buffed +6% to counter Shield Tanks
            attackSpeed: 65,
            parryChance: 75,
            riposteChance: 70,
            critMultiplier: 280,
            staminaMultiplier: 135, // v28: Better efficiency vs Shield Tanks
            survivalFactor: 90,
            damageType: DamageType.Hybrid_Slash_Blunt,
            shieldType: ShieldType.NONE,
            weaponClass: WeaponClass.DUAL_WIELD_BRUTE
        });
    }

    function MACE_SHORTSWORD() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 60, // v28: Buffed +5% to counter Shield Tanks
            maxDamage: 84, // v28: Buffed +5% to counter Shield Tanks
            attackSpeed: 70,
            parryChance: 160,
            riposteChance: 85,
            critMultiplier: 225,
            staminaMultiplier: 145, // v28: Better efficiency vs Shield Tanks
            survivalFactor: 105,
            damageType: DamageType.Hybrid_Slash_Blunt,
            shieldType: ShieldType.NONE,
            weaponClass: WeaponClass.DUAL_WIELD_BRUTE
        });
    }

    // Additional two-handed weapons
    function MAUL() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 130, // Adjusted to achieve ~58 DPR - powerful but not overpowering
            maxDamage: 140, // Adjusted to achieve ~58 DPR - powerful but not overpowering
            attackSpeed: 40,
            parryChance: 70,
            riposteChance: 40,
            critMultiplier: 280, // v28: Reduced from 320 - dial back 2k+ crits
            staminaMultiplier: 310, // Reduced from 350 - berserkers need to counter shield tanks
            survivalFactor: 85,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.NONE,
            weaponClass: WeaponClass.HEAVY_DEMOLITION
        });
    }

    function TRIDENT() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 62,
            maxDamage: 79,
            attackSpeed: 55,
            parryChance: 100,
            riposteChance: 100,
            critMultiplier: 190, // v28: Reduced from 220 - dial back 2k+ crits
            staminaMultiplier: 140, // Higher than spear but reasonable for reach weapon
            survivalFactor: 90,
            damageType: DamageType.Piercing,
            shieldType: ShieldType.NONE,
            weaponClass: WeaponClass.REACH_CONTROL
        });
    }

    function getWeaponStats(uint8 weapon) public pure returns (WeaponStats memory) {
        if (weapon == WEAPON_ARMING_SWORD_KITE) return ARMING_SWORD_KITE();
        if (weapon == WEAPON_MACE_TOWER) return MACE_TOWER();
        if (weapon == WEAPON_RAPIER_BUCKLER) return RAPIER_BUCKLER();
        if (weapon == WEAPON_GREATSWORD) return GREATSWORD();
        if (weapon == WEAPON_BATTLEAXE) return BATTLEAXE();
        if (weapon == WEAPON_QUARTERSTAFF) return QUARTERSTAFF();
        if (weapon == WEAPON_SPEAR) return SPEAR();
        if (weapon == WEAPON_SHORTSWORD_BUCKLER) return SHORTSWORD_BUCKLER();
        if (weapon == WEAPON_SHORTSWORD_TOWER) return SHORTSWORD_TOWER();
        if (weapon == WEAPON_DUAL_DAGGERS) return DUAL_DAGGERS();
        if (weapon == WEAPON_RAPIER_DAGGER) return RAPIER_DAGGER();
        if (weapon == WEAPON_SCIMITAR_BUCKLER) return SCIMITAR_BUCKLER();
        if (weapon == WEAPON_AXE_KITE) return AXE_KITE();
        if (weapon == WEAPON_AXE_TOWER) return AXE_TOWER();
        if (weapon == WEAPON_DUAL_SCIMITARS) return DUAL_SCIMITARS();
        if (weapon == WEAPON_MACE_KITE) return MACE_KITE();
        if (weapon == WEAPON_CLUB_TOWER) return CLUB_TOWER();
        if (weapon == WEAPON_DUAL_CLUBS) return DUAL_CLUBS();
        if (weapon == WEAPON_ARMING_SWORD_SHORTSWORD) return ARMING_SWORD_SHORTSWORD();
        if (weapon == WEAPON_SCIMITAR_DAGGER) return SCIMITAR_DAGGER();
        if (weapon == WEAPON_ARMING_SWORD_CLUB) return ARMING_SWORD_CLUB();
        if (weapon == WEAPON_AXE_MACE) return AXE_MACE();
        if (weapon == WEAPON_MACE_SHORTSWORD) return MACE_SHORTSWORD();
        if (weapon == WEAPON_MAUL) return MAUL();
        if (weapon == WEAPON_TRIDENT) return TRIDENT();
        revert InvalidEquipment();
    }

    // =============================================
    // ARMOR STATS
    // =============================================

    function CLOTH() public pure returns (ArmorStats memory) {
        return ArmorStats({defense: 1, weight: 5, slashResist: 1, pierceResist: 1, bluntResist: 5});
    }

    function LEATHER() public pure returns (ArmorStats memory) {
        return ArmorStats({defense: 6, weight: 15, slashResist: 8, pierceResist: 8, bluntResist: 20});
    }

    function CHAIN() public pure returns (ArmorStats memory) {
        return ArmorStats({defense: 13, weight: 50, slashResist: 25, pierceResist: 15, bluntResist: 40});
    }

    function PLATE() public pure returns (ArmorStats memory) {
        return ArmorStats({defense: 28, weight: 100, slashResist: 50, pierceResist: 45, bluntResist: 20});
    }

    function getArmorStats(uint8 armor) public pure returns (ArmorStats memory) {
        if (armor == ARMOR_CLOTH) return CLOTH();
        if (armor == ARMOR_LEATHER) return LEATHER();
        if (armor == ARMOR_CHAIN) return CHAIN();
        if (armor == ARMOR_PLATE) return PLATE();
        revert InvalidEquipment();
    }

    // =============================================
    // STANCES
    // =============================================

    function DEFENSIVE_STANCE() public pure returns (StanceMultiplier memory) {
        return StanceMultiplier({
            damageModifier: 75,
            hitChance: 75,
            critChance: 75,
            critMultiplier: 85,
            blockChance: 150,
            parryChance: 150,
            dodgeChance: 140,
            counterChance: 150,
            riposteChance: 150,
            staminaCostModifier: 55,
            survivalFactor: 125,
            heavyArmorEffectiveness: 100
        });
    }

    function BALANCED_STANCE() public pure returns (StanceMultiplier memory) {
        return StanceMultiplier({
            damageModifier: 100,
            hitChance: 100,
            critChance: 100,
            critMultiplier: 100,
            blockChance: 100,
            parryChance: 100,
            dodgeChance: 100,
            counterChance: 100,
            riposteChance: 100,
            staminaCostModifier: 100,
            survivalFactor: 100,
            heavyArmorEffectiveness: 75
        });
    }

    function OFFENSIVE_STANCE() public pure returns (StanceMultiplier memory) {
        return StanceMultiplier({
            damageModifier: 115,
            hitChance: 130,
            critChance: 115,
            critMultiplier: 150,
            blockChance: 60,
            parryChance: 60,
            dodgeChance: 60,
            counterChance: 70,
            riposteChance: 70,
            staminaCostModifier: 145,
            survivalFactor: 75,
            heavyArmorEffectiveness: 50
        });
    }

    function getStanceMultiplier(uint8 stance) public pure returns (StanceMultiplier memory) {
        if (stance == STANCE_DEFENSIVE) return DEFENSIVE_STANCE();
        if (stance == STANCE_OFFENSIVE) return OFFENSIVE_STANCE();
        return BALANCED_STANCE();
    }

    // Fix 6: Fix isLethalDamage function to avoid division by zero and handle overflow
    function isLethalDamage(
        uint16 attackerDamage,
        uint16 defenderMaxHealth,
        CalculatedStats memory defenderStats,
        WeaponStats memory weapon,
        StanceMultiplier memory, /* defenderStance */
        uint256 seed,
        uint16 lethalityFactor
    ) private pure returns (bool died) {
        // Early return if lethality is disabled
        if (lethalityFactor == 0) return false;

        // Use uint256 for all calculations to prevent any overflow
        uint256 damagePercent = (uint256(attackerDamage) * 100) / uint256(defenderMaxHealth);

        if (damagePercent <= DAMAGE_THRESHOLD_PERCENT) {
            return false;
        }

        uint256 survivalChance = uint256(defenderStats.baseSurvivalRate);

        uint256 excessDamage = damagePercent > DAMAGE_THRESHOLD_PERCENT ? damagePercent - DAMAGE_THRESHOLD_PERCENT : 0;
        excessDamage = excessDamage > MAX_DAMAGE_OVERAGE ? MAX_DAMAGE_OVERAGE : excessDamage;
        survivalChance = survivalChance > excessDamage ? survivalChance - excessDamage : 0;

        // Safe division - prevent division by zero
        if (lethalityFactor > 0) {
            survivalChance = (survivalChance * 100) / lethalityFactor;
        }

        // Apply weapon survival factor safely
        survivalChance = (survivalChance * uint256(weapon.survivalFactor)) / 100;

        // Cap between min and max
        if (survivalChance < MINIMUM_SURVIVAL_CHANCE) {
            survivalChance = MINIMUM_SURVIVAL_CHANCE;
        } else if (survivalChance > BASE_SURVIVAL_CHANCE) {
            survivalChance = BASE_SURVIVAL_CHANCE;
        }

        // Generate random number and compare
        seed = uint256(keccak256(abi.encodePacked(seed)));
        return uint8(seed.uniform(100)) >= survivalChance;
    }

    function getShieldStats(ShieldType shieldType)
        internal
        pure
        returns (uint16 blockChance, uint16 counterChance, uint16 dodgeModifier, uint16 staminaModifier)
    {
        if (shieldType == ShieldType.BUCKLER) {
            return (70, 110, 110, 100);
        } else if (shieldType == ShieldType.KITE_SHIELD) {
            return (110, 90, 55, 120);
        } else if (shieldType == ShieldType.TOWER_SHIELD) {
            return (140, 50, 20, 150);
        }
        return (0, 0, 100, 100);
    }
}

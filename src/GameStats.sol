// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IPlayerSkinNFT.sol";
import "./interfaces/IPlayer.sol";

contract GameStats {
    enum DamageType {
        Slashing,
        Piercing,
        Blunt
    }

    struct WeaponStats {
        uint16 minDamage;
        uint16 maxDamage;
        uint16 attackSpeed; // Base 100, higher is faster
        uint16 parryChance; // Base 100, chance to parry
        uint16 riposteChance; // Add this new stat
        DamageType damageType; // Primary damage type
        bool isTwoHanded;
        bool hasShield;
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
        uint16 staminaCostModifier; // Add this new field
    }

    struct StatRequirements {
        uint8 strength;
        uint8 constitution;
        uint8 size;
        uint8 agility;
        uint8 stamina;
        uint8 luck;
    }

    mapping(IPlayerSkinNFT.WeaponType => WeaponStats) public weaponStats;
    mapping(IPlayerSkinNFT.ArmorType => ArmorStats) public armorStats;
    mapping(IPlayerSkinNFT.FightingStance => StanceMultiplier) public stanceStats;
    mapping(IPlayerSkinNFT.WeaponType => StatRequirements) public weaponRequirements;
    mapping(IPlayerSkinNFT.ArmorType => StatRequirements) public armorRequirements;

    constructor() {
        // =============================================
        // WEAPON STATS AND REQUIREMENTS
        // =============================================

        // === One-Handed Weapons (with Shield) ===
        weaponStats[IPlayerSkinNFT.WeaponType.SwordAndShield] = WeaponStats({
            minDamage: 18,
            maxDamage: 26,
            attackSpeed: 100,
            parryChance: 110,
            riposteChance: 120,
            damageType: DamageType.Slashing,
            isTwoHanded: false,
            hasShield: true
        });
        weaponRequirements[IPlayerSkinNFT.WeaponType.SwordAndShield] =
            StatRequirements({strength: 10, constitution: 0, size: 0, agility: 6, stamina: 0, luck: 0});

        weaponStats[IPlayerSkinNFT.WeaponType.MaceAndShield] = WeaponStats({
            minDamage: 22,
            maxDamage: 34,
            attackSpeed: 80,
            parryChance: 80,
            riposteChance: 70,
            damageType: DamageType.Blunt,
            isTwoHanded: false,
            hasShield: true
        });
        weaponRequirements[IPlayerSkinNFT.WeaponType.MaceAndShield] = StatRequirements({
            strength: 12, // Needs decent strength to wield effectively
            constitution: 0,
            size: 0,
            agility: 0,
            stamina: 8,
            luck: 0
        });

        weaponStats[IPlayerSkinNFT.WeaponType.RapierAndShield] = WeaponStats({
            minDamage: 16,
            maxDamage: 24,
            attackSpeed: 110,
            parryChance: 120,
            riposteChance: 130,
            damageType: DamageType.Piercing,
            isTwoHanded: false,
            hasShield: true
        });
        weaponRequirements[IPlayerSkinNFT.WeaponType.RapierAndShield] = StatRequirements({
            strength: 6, // Emphasizes agility over strength
            constitution: 0,
            size: 0,
            agility: 12,
            stamina: 0,
            luck: 0
        });

        // === Two-Handed Weapons ===
        weaponStats[IPlayerSkinNFT.WeaponType.Greatsword] = WeaponStats({
            minDamage: 26,
            maxDamage: 38,
            attackSpeed: 80,
            parryChance: 100,
            riposteChance: 110,
            damageType: DamageType.Slashing,
            isTwoHanded: true,
            hasShield: false
        });
        weaponRequirements[IPlayerSkinNFT.WeaponType.Greatsword] = StatRequirements({
            strength: 12, // Requires good strength and size
            constitution: 0,
            size: 10,
            agility: 8,
            stamina: 0,
            luck: 0
        });

        weaponStats[IPlayerSkinNFT.WeaponType.Battleaxe] = WeaponStats({
            minDamage: 35,
            maxDamage: 46,
            attackSpeed: 60,
            parryChance: 60,
            riposteChance: 70,
            damageType: DamageType.Slashing,
            isTwoHanded: true,
            hasShield: false
        });
        weaponRequirements[IPlayerSkinNFT.WeaponType.Battleaxe] = StatRequirements({
            strength: 15, // Highest strength requirement
            constitution: 0,
            size: 12, // Needs good size to handle
            agility: 0,
            stamina: 0,
            luck: 0
        });

        weaponStats[IPlayerSkinNFT.WeaponType.Quarterstaff] = WeaponStats({
            minDamage: 15,
            maxDamage: 23,
            attackSpeed: 120,
            parryChance: 120,
            riposteChance: 130,
            damageType: DamageType.Blunt,
            isTwoHanded: true,
            hasShield: false
        });
        weaponRequirements[IPlayerSkinNFT.WeaponType.Quarterstaff] =
            StatRequirements({strength: 0, constitution: 0, size: 0, agility: 0, stamina: 0, luck: 0});

        weaponStats[IPlayerSkinNFT.WeaponType.Spear] = WeaponStats({
            minDamage: 20,
            maxDamage: 32,
            attackSpeed: 90,
            parryChance: 80,
            riposteChance: 90,
            damageType: DamageType.Piercing,
            isTwoHanded: true,
            hasShield: false
        });
        weaponRequirements[IPlayerSkinNFT.WeaponType.Spear] = StatRequirements({
            strength: 8, // Balanced requirements
            constitution: 0,
            size: 8, // Length requires some size
            agility: 10, // Precise strikes need agility
            stamina: 0,
            luck: 0
        });

        // =============================================
        // ARMOR STATS AND REQUIREMENTS
        // =============================================

        // === Light Armor ===
        armorStats[IPlayerSkinNFT.ArmorType.Cloth] =
            ArmorStats({defense: 2, weight: 25, slashResist: 70, pierceResist: 70, bluntResist: 80});
        armorRequirements[IPlayerSkinNFT.ArmorType.Cloth] = StatRequirements({
            strength: 0, // No requirements - default armor
            constitution: 0,
            size: 0,
            agility: 0,
            stamina: 0,
            luck: 0
        });

        armorStats[IPlayerSkinNFT.ArmorType.Leather] =
            ArmorStats({defense: 4, weight: 50, slashResist: 90, pierceResist: 85, bluntResist: 90});
        armorRequirements[IPlayerSkinNFT.ArmorType.Leather] = StatRequirements({
            strength: 6, // Light requirements
            constitution: 6,
            size: 0,
            agility: 0,
            stamina: 0,
            luck: 0
        });

        // === Medium Armor ===
        armorStats[IPlayerSkinNFT.ArmorType.Chain] =
            ArmorStats({defense: 6, weight: 75, slashResist: 110, pierceResist: 70, bluntResist: 100});
        armorRequirements[IPlayerSkinNFT.ArmorType.Chain] = StatRequirements({
            strength: 8, // Moderate requirements
            constitution: 8,
            size: 0,
            agility: 0,
            stamina: 0,
            luck: 0
        });

        // === Heavy Armor ===
        armorStats[IPlayerSkinNFT.ArmorType.Plate] =
            ArmorStats({defense: 12, weight: 100, slashResist: 120, pierceResist: 90, bluntResist: 80});
        armorRequirements[IPlayerSkinNFT.ArmorType.Plate] = StatRequirements({
            strength: 10, // Highest requirements
            constitution: 10,
            size: 0,
            agility: 0,
            stamina: 0,
            luck: 0
        });

        // Initialize Stance Stats
        initializeStanceStats();
    }

    function initializeStanceStats() internal {
        stanceStats[IPlayerSkinNFT.FightingStance.Defensive] = StanceMultiplier({
            damageModifier: 85,
            hitChance: 95,
            critChance: 90,
            critMultiplier: 90,
            blockChance: 150,
            parryChance: 150,
            dodgeChance: 140,
            counterChance: 140,
            staminaCostModifier: 75
        });

        stanceStats[IPlayerSkinNFT.FightingStance.Balanced] = StanceMultiplier({
            damageModifier: 100,
            hitChance: 100,
            critChance: 100,
            critMultiplier: 100,
            blockChance: 100,
            parryChance: 100,
            dodgeChance: 100,
            counterChance: 100,
            staminaCostModifier: 100
        });

        stanceStats[IPlayerSkinNFT.FightingStance.Offensive] = StanceMultiplier({
            damageModifier: 115,
            hitChance: 105,
            critChance: 110,
            critMultiplier: 110,
            blockChance: 85,
            parryChance: 85,
            dodgeChance: 85,
            counterChance: 85,
            staminaCostModifier: 125
        });
    }

    // View functions only - no state changes possible
    function getFullCharacterStats(
        IPlayerSkinNFT.WeaponType weapon,
        IPlayerSkinNFT.ArmorType armor,
        IPlayerSkinNFT.FightingStance stance
    ) external view returns (WeaponStats memory weapon_, ArmorStats memory armor_, StanceMultiplier memory stance_) {
        return (weaponStats[weapon], armorStats[armor], stanceStats[stance]);
    }

    function getStanceMultiplier(IPlayerSkinNFT.FightingStance stance) public view returns (StanceMultiplier memory) {
        return stanceStats[stance];
    }

    function checkStatRequirements(
        IPlayerSkinNFT.WeaponType weapon,
        IPlayerSkinNFT.ArmorType armor,
        IPlayer.PlayerStats memory stats
    ) external view returns (bool meetsWeaponReqs, bool meetsArmorReqs) {
        StatRequirements memory weaponReqs = weaponRequirements[weapon];
        StatRequirements memory armorReqs = armorRequirements[armor];

        meetsWeaponReqs = stats.strength >= weaponReqs.strength && stats.constitution >= weaponReqs.constitution
            && stats.size >= weaponReqs.size && stats.agility >= weaponReqs.agility && stats.stamina >= weaponReqs.stamina
            && stats.luck >= weaponReqs.luck;

        meetsArmorReqs = stats.strength >= armorReqs.strength && stats.constitution >= armorReqs.constitution
            && stats.size >= armorReqs.size && stats.agility >= armorReqs.agility && stats.stamina >= armorReqs.stamina
            && stats.luck >= armorReqs.luck;
    }
}

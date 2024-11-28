// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IPlayerSkinNFT.sol";

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

    mapping(IPlayerSkinNFT.WeaponType => WeaponStats) public weaponStats;
    mapping(IPlayerSkinNFT.ArmorType => ArmorStats) public armorStats;
    mapping(IPlayerSkinNFT.FightingStance => StanceMultiplier) public stanceStats;

    constructor() {
        // Initialize Weapon Stats
        weaponStats[IPlayerSkinNFT.WeaponType.SwordAndShield] = WeaponStats({
            minDamage: 18,
            maxDamage: 26,
            attackSpeed: 100,
            parryChance: 110, // Good at parrying
            riposteChance: 120,
            damageType: DamageType.Slashing,
            isTwoHanded: false,
            hasShield: true
        });

        weaponStats[IPlayerSkinNFT.WeaponType.MaceAndShield] = WeaponStats({
            minDamage: 22,
            maxDamage: 34,
            attackSpeed: 80,
            parryChance: 80,
            riposteChance: 70, // Only this new field should be added
            damageType: DamageType.Blunt,
            isTwoHanded: false,
            hasShield: true
        });

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

        weaponStats[IPlayerSkinNFT.WeaponType.Battleaxe] = WeaponStats({
            minDamage: 35,
            maxDamage: 46,
            attackSpeed: 60,
            parryChance: 60, // Hard to parry with
            riposteChance: 70,
            damageType: DamageType.Slashing,
            isTwoHanded: true,
            hasShield: false
        });

        weaponStats[IPlayerSkinNFT.WeaponType.Quarterstaff] = WeaponStats({
            minDamage: 15,
            maxDamage: 23,
            attackSpeed: 120,
            parryChance: 120, // Best at parrying
            riposteChance: 130,
            damageType: DamageType.Blunt,
            isTwoHanded: true,
            hasShield: false
        });

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

        // Initialize Armor Stats with resistances
        armorStats[IPlayerSkinNFT.ArmorType.Plate] =
            ArmorStats({defense: 12, weight: 100, slashResist: 120, pierceResist: 90, bluntResist: 80});

        armorStats[IPlayerSkinNFT.ArmorType.Chain] = ArmorStats({
            defense: 6,
            weight: 75,
            slashResist: 110, // Good vs slashing
            pierceResist: 70, // Very weak to piercing
            bluntResist: 100 // Decent vs blunt
        });

        armorStats[IPlayerSkinNFT.ArmorType.Leather] = ArmorStats({
            defense: 4,
            weight: 50,
            slashResist: 90, // Some protection
            pierceResist: 85, // Some protection
            bluntResist: 90 // Some protection
        });

        armorStats[IPlayerSkinNFT.ArmorType.Cloth] = ArmorStats({
            defense: 2,
            weight: 25, // Lowest stamina drain
            slashResist: 70, // Poor protection
            pierceResist: 70, // Poor protection
            bluntResist: 80 // Slightly better vs blunt
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
}

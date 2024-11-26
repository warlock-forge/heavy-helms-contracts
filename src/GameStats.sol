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
        uint16 damageMultiplier; // Base 100
        uint16 defenseMultiplier; // Base 100
        uint16 speedMultiplier; // Base 100
        uint16 parryMultiplier; // Base 100
        uint16 blockMultiplier; // Base 100, only applies if hasShield is true
    }

    mapping(IPlayerSkinNFT.WeaponType => WeaponStats) public weaponStats;
    mapping(IPlayerSkinNFT.ArmorType => ArmorStats) public armorStats;
    mapping(IPlayerSkinNFT.FightingStance => StanceMultiplier) public stanceStats;

    constructor() {
        // Initialize Weapon Stats
        weaponStats[IPlayerSkinNFT.WeaponType.SwordAndShield] = WeaponStats({
            minDamage: 12,
            maxDamage: 18,
            attackSpeed: 100,
            parryChance: 110, // Good at parrying
            damageType: DamageType.Slashing,
            isTwoHanded: false,
            hasShield: true
        });

        weaponStats[IPlayerSkinNFT.WeaponType.MaceAndShield] = WeaponStats({
            minDamage: 14,
            maxDamage: 20,
            attackSpeed: 85,
            parryChance: 90, // Harder to parry with
            damageType: DamageType.Blunt,
            isTwoHanded: false,
            hasShield: true
        });

        weaponStats[IPlayerSkinNFT.WeaponType.Greatsword] = WeaponStats({
            minDamage: 18,
            maxDamage: 26,
            attackSpeed: 80,
            parryChance: 100,
            damageType: DamageType.Slashing,
            isTwoHanded: true,
            hasShield: false
        });

        weaponStats[IPlayerSkinNFT.WeaponType.Battleaxe] = WeaponStats({
            minDamage: 24,
            maxDamage: 32,
            attackSpeed: 60,
            parryChance: 60, // Hard to parry with
            damageType: DamageType.Slashing,
            isTwoHanded: true,
            hasShield: false
        });

        weaponStats[IPlayerSkinNFT.WeaponType.Quarterstaff] = WeaponStats({
            minDamage: 10,
            maxDamage: 16,
            attackSpeed: 120,
            parryChance: 120, // Best at parrying
            damageType: DamageType.Blunt,
            isTwoHanded: true,
            hasShield: false
        });

        weaponStats[IPlayerSkinNFT.WeaponType.Spear] = WeaponStats({
            minDamage: 14,
            maxDamage: 22,
            attackSpeed: 90,
            parryChance: 80,
            damageType: DamageType.Piercing,
            isTwoHanded: true,
            hasShield: false
        });

        // Initialize Armor Stats with resistances
        armorStats[IPlayerSkinNFT.ArmorType.Plate] = ArmorStats({
            defense: 8,
            weight: 100, // Highest stamina drain
            slashResist: 120, // Very good vs slashing
            pierceResist: 90, // Weak to gaps in armor
            bluntResist: 80 // Weak to blunt force
        });

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
        stanceStats[IPlayerSkinNFT.FightingStance.Defensive] = StanceMultiplier({
            damageMultiplier: 80, // -20% damage
            defenseMultiplier: 120, // +20% defense
            speedMultiplier: 90, // -10% speed
            parryMultiplier: 120, // +20% parry chance
            blockMultiplier: 130 // +30% block chance
        });

        stanceStats[IPlayerSkinNFT.FightingStance.Balanced] = StanceMultiplier({
            damageMultiplier: 100, // Normal damage
            defenseMultiplier: 100, // Normal defense
            speedMultiplier: 100, // Normal speed
            parryMultiplier: 100, // Normal parry chance
            blockMultiplier: 100 // Normal block chance
        });

        stanceStats[IPlayerSkinNFT.FightingStance.Offensive] = StanceMultiplier({
            damageMultiplier: 120, // +20% damage
            defenseMultiplier: 80, // -20% defense
            speedMultiplier: 110, // +10% speed
            parryMultiplier: 80, // -20% parry chance
            blockMultiplier: 70 // -30% block chance
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
}

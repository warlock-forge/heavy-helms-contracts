// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import "../../interfaces/game/engine/IEquipmentRequirements.sol";
import "../../fighters/Fighter.sol";

/// @title Equipment Requirements Contract
/// @notice Manages stat requirements for weapons and armor in Heavy Helms
/// @dev Pure functions that return minimum stat requirements for equipment
contract EquipmentRequirements is IEquipmentRequirements {
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
    uint8 public constant WEAPON_FLAIL_BUCKLER = 15;
    uint8 public constant WEAPON_MACE_KITE = 16;
    uint8 public constant WEAPON_CLUB_TOWER = 17;
    uint8 public constant WEAPON_DUAL_CLUBS = 18;
    uint8 public constant WEAPON_ARMING_SWORD_SHORTSWORD = 19;
    uint8 public constant WEAPON_SCIMITAR_DAGGER = 20;
    uint8 public constant WEAPON_ARMING_SWORD_CLUB = 21;
    uint8 public constant WEAPON_AXE_MACE = 22;
    uint8 public constant WEAPON_FLAIL_DAGGER = 23;
    uint8 public constant WEAPON_MACE_SHORTSWORD = 24;
    uint8 public constant WEAPON_MAUL = 25;
    uint8 public constant WEAPON_TRIDENT = 26;

    // Armor Types
    uint8 public constant ARMOR_CLOTH = 0;
    uint8 public constant ARMOR_LEATHER = 1;
    uint8 public constant ARMOR_CHAIN = 2;
    uint8 public constant ARMOR_PLATE = 3;

    function armingSwordKiteReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 12, constitution: 0, size: 5, agility: 0, stamina: 5, luck: 0});
    }

    function maceTowerReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 12, constitution: 0, size: 12, agility: 0, stamina: 8, luck: 0});
    }

    function rapierBucklerReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 14, stamina: 0, luck: 0});
    }

    function greatswordReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 14, constitution: 0, size: 10, agility: 0, stamina: 0, luck: 0});
    }

    function battleaxeReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 16, constitution: 0, size: 12, agility: 0, stamina: 0, luck: 0});
    }

    function quarterstaffReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 0, stamina: 0, luck: 0});
    }

    function spearReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 6, constitution: 0, size: 12, agility: 10, stamina: 0, luck: 0});
    }

    function shortswordBucklerReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 0, stamina: 0, luck: 0});
    }

    function shortswordTowerReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 6, constitution: 0, size: 12, agility: 0, stamina: 8, luck: 0});
    }

    function dualDaggersReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 8, stamina: 0, luck: 0});
    }

    function rapierDaggerReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 16, stamina: 0, luck: 0});
    }

    function scimitarBucklerReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 8, constitution: 0, size: 0, agility: 8, stamina: 0, luck: 0});
    }

    function axeKiteReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 10, constitution: 0, size: 5, agility: 0, stamina: 5, luck: 0});
    }

    function axeTowerReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 12, constitution: 0, size: 12, agility: 0, stamina: 8, luck: 0});
    }

    function dualScimitarsReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 8, constitution: 0, size: 0, agility: 14, stamina: 0, luck: 0});
    }

    function flailBucklerReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 10, constitution: 0, size: 0, agility: 10, stamina: 0, luck: 0});
    }

    function maceKiteReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 10, constitution: 0, size: 5, agility: 0, stamina: 5, luck: 0});
    }

    function clubTowerReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 8, constitution: 0, size: 12, agility: 0, stamina: 8, luck: 0});
    }

    function dualClubsReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 0, stamina: 0, luck: 0});
    }

    function armingSwordShortswordReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 14, constitution: 0, size: 0, agility: 12, stamina: 0, luck: 0});
    }

    function scimitarDaggerReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 8, constitution: 0, size: 0, agility: 16, stamina: 0, luck: 0});
    }

    function armingSwordClubReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 14, constitution: 0, size: 0, agility: 8, stamina: 0, luck: 0});
    }

    function axeMaceReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 16, constitution: 0, size: 0, agility: 8, stamina: 0, luck: 0});
    }

    function flailDaggerReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 12, constitution: 0, size: 0, agility: 14, stamina: 0, luck: 0});
    }

    function maceShortswordReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 14, constitution: 0, size: 0, agility: 10, stamina: 0, luck: 0});
    }

    function maulReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 18, constitution: 0, size: 12, agility: 0, stamina: 0, luck: 0});
    }

    function tridentReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 12, constitution: 0, size: 12, agility: 10, stamina: 0, luck: 0});
    }

    /// @notice Get the minimum stat requirements for a weapon type
    /// @param weapon The weapon type ID
    /// @return Minimum attributes required to use the weapon
    function getWeaponRequirements(uint8 weapon) external pure returns (Fighter.Attributes memory) {
        if (weapon == WEAPON_ARMING_SWORD_KITE) return armingSwordKiteReqs();
        if (weapon == WEAPON_MACE_TOWER) return maceTowerReqs();
        if (weapon == WEAPON_RAPIER_BUCKLER) return rapierBucklerReqs();
        if (weapon == WEAPON_GREATSWORD) return greatswordReqs();
        if (weapon == WEAPON_BATTLEAXE) return battleaxeReqs();
        if (weapon == WEAPON_QUARTERSTAFF) return quarterstaffReqs();
        if (weapon == WEAPON_SPEAR) return spearReqs();
        if (weapon == WEAPON_SHORTSWORD_BUCKLER) return shortswordBucklerReqs();
        if (weapon == WEAPON_SHORTSWORD_TOWER) return shortswordTowerReqs();
        if (weapon == WEAPON_DUAL_DAGGERS) return dualDaggersReqs();
        if (weapon == WEAPON_RAPIER_DAGGER) return rapierDaggerReqs();
        if (weapon == WEAPON_SCIMITAR_BUCKLER) return scimitarBucklerReqs();
        if (weapon == WEAPON_AXE_KITE) return axeKiteReqs();
        if (weapon == WEAPON_AXE_TOWER) return axeTowerReqs();
        if (weapon == WEAPON_DUAL_SCIMITARS) return dualScimitarsReqs();
        if (weapon == WEAPON_FLAIL_BUCKLER) return flailBucklerReqs();
        if (weapon == WEAPON_MACE_KITE) return maceKiteReqs();
        if (weapon == WEAPON_CLUB_TOWER) return clubTowerReqs();
        if (weapon == WEAPON_DUAL_CLUBS) return dualClubsReqs();
        if (weapon == WEAPON_ARMING_SWORD_SHORTSWORD) return armingSwordShortswordReqs();
        if (weapon == WEAPON_SCIMITAR_DAGGER) return scimitarDaggerReqs();
        if (weapon == WEAPON_ARMING_SWORD_CLUB) return armingSwordClubReqs();
        if (weapon == WEAPON_AXE_MACE) return axeMaceReqs();
        if (weapon == WEAPON_FLAIL_DAGGER) return flailDaggerReqs();
        if (weapon == WEAPON_MACE_SHORTSWORD) return maceShortswordReqs();
        if (weapon == WEAPON_MAUL) return maulReqs();
        if (weapon == WEAPON_TRIDENT) return tridentReqs();
        revert("Invalid weapon type");
    }

    function clothReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 0, stamina: 0, luck: 0});
    }

    function leatherReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 5, constitution: 0, size: 0, agility: 0, stamina: 0, luck: 0});
    }

    function chainReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 8, constitution: 6, size: 0, agility: 0, stamina: 6, luck: 0});
    }

    function plateReqs() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 10, constitution: 8, size: 0, agility: 0, stamina: 8, luck: 0});
    }

    /// @notice Get the minimum stat requirements for an armor type
    /// @param armor The armor type ID
    /// @return Minimum attributes required to use the armor
    function getArmorRequirements(uint8 armor) external pure returns (Fighter.Attributes memory) {
        if (armor == ARMOR_CLOTH) return clothReqs();
        if (armor == ARMOR_LEATHER) return leatherReqs();
        if (armor == ARMOR_CHAIN) return chainReqs();
        if (armor == ARMOR_PLATE) return plateReqs();
        revert("Invalid armor type");
    }
}

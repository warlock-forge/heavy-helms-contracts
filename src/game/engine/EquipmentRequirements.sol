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

    function ARMING_SWORD_KITE_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 12, constitution: 0, size: 5, agility: 0, stamina: 5, luck: 0});
    }

    function MACE_TOWER_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 12, constitution: 0, size: 12, agility: 0, stamina: 8, luck: 0});
    }

    function RAPIER_BUCKLER_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 14, stamina: 0, luck: 0});
    }

    function GREATSWORD_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 14, constitution: 0, size: 10, agility: 0, stamina: 0, luck: 0});
    }

    function BATTLEAXE_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 16, constitution: 0, size: 12, agility: 0, stamina: 0, luck: 0});
    }

    function QUARTERSTAFF_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 0, stamina: 0, luck: 0});
    }

    function SPEAR_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 6, constitution: 0, size: 12, agility: 10, stamina: 0, luck: 0});
    }

    function SHORTSWORD_BUCKLER_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 0, stamina: 0, luck: 0});
    }

    function SHORTSWORD_TOWER_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 6, constitution: 0, size: 12, agility: 0, stamina: 8, luck: 0});
    }

    function DUAL_DAGGERS_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 8, stamina: 0, luck: 0});
    }

    function RAPIER_DAGGER_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 16, stamina: 0, luck: 0});
    }

    function SCIMITAR_BUCKLER_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 8, constitution: 0, size: 0, agility: 8, stamina: 0, luck: 0});
    }

    function AXE_KITE_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 10, constitution: 0, size: 5, agility: 0, stamina: 5, luck: 0});
    }

    function AXE_TOWER_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 12, constitution: 0, size: 12, agility: 0, stamina: 8, luck: 0});
    }

    function DUAL_SCIMITARS_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 8, constitution: 0, size: 0, agility: 14, stamina: 0, luck: 0});
    }

    function FLAIL_BUCKLER_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 10, constitution: 0, size: 0, agility: 10, stamina: 0, luck: 0});
    }

    function MACE_KITE_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 10, constitution: 0, size: 5, agility: 0, stamina: 5, luck: 0});
    }

    function CLUB_TOWER_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 8, constitution: 0, size: 12, agility: 0, stamina: 8, luck: 0});
    }

    function DUAL_CLUBS_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 0, stamina: 0, luck: 0});
    }

    function ARMING_SWORD_SHORTSWORD_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 14, constitution: 0, size: 0, agility: 12, stamina: 0, luck: 0});
    }

    function SCIMITAR_DAGGER_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 8, constitution: 0, size: 0, agility: 16, stamina: 0, luck: 0});
    }

    function ARMING_SWORD_CLUB_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 14, constitution: 0, size: 0, agility: 8, stamina: 0, luck: 0});
    }

    function AXE_MACE_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 16, constitution: 0, size: 0, agility: 8, stamina: 0, luck: 0});
    }

    function FLAIL_DAGGER_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 12, constitution: 0, size: 0, agility: 14, stamina: 0, luck: 0});
    }

    function MACE_SHORTSWORD_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 14, constitution: 0, size: 0, agility: 10, stamina: 0, luck: 0});
    }

    function MAUL_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 18, constitution: 0, size: 12, agility: 0, stamina: 0, luck: 0});
    }

    function TRIDENT_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 12, constitution: 0, size: 12, agility: 10, stamina: 0, luck: 0});
    }

    /// @notice Get the minimum stat requirements for a weapon type
    /// @param weapon The weapon type ID
    /// @return Minimum attributes required to use the weapon
    function getWeaponRequirements(uint8 weapon) external pure returns (Fighter.Attributes memory) {
        if (weapon == WEAPON_ARMING_SWORD_KITE) return ARMING_SWORD_KITE_REQS();
        if (weapon == WEAPON_MACE_TOWER) return MACE_TOWER_REQS();
        if (weapon == WEAPON_RAPIER_BUCKLER) return RAPIER_BUCKLER_REQS();
        if (weapon == WEAPON_GREATSWORD) return GREATSWORD_REQS();
        if (weapon == WEAPON_BATTLEAXE) return BATTLEAXE_REQS();
        if (weapon == WEAPON_QUARTERSTAFF) return QUARTERSTAFF_REQS();
        if (weapon == WEAPON_SPEAR) return SPEAR_REQS();
        if (weapon == WEAPON_SHORTSWORD_BUCKLER) return SHORTSWORD_BUCKLER_REQS();
        if (weapon == WEAPON_SHORTSWORD_TOWER) return SHORTSWORD_TOWER_REQS();
        if (weapon == WEAPON_DUAL_DAGGERS) return DUAL_DAGGERS_REQS();
        if (weapon == WEAPON_RAPIER_DAGGER) return RAPIER_DAGGER_REQS();
        if (weapon == WEAPON_SCIMITAR_BUCKLER) return SCIMITAR_BUCKLER_REQS();
        if (weapon == WEAPON_AXE_KITE) return AXE_KITE_REQS();
        if (weapon == WEAPON_AXE_TOWER) return AXE_TOWER_REQS();
        if (weapon == WEAPON_DUAL_SCIMITARS) return DUAL_SCIMITARS_REQS();
        if (weapon == WEAPON_FLAIL_BUCKLER) return FLAIL_BUCKLER_REQS();
        if (weapon == WEAPON_MACE_KITE) return MACE_KITE_REQS();
        if (weapon == WEAPON_CLUB_TOWER) return CLUB_TOWER_REQS();
        if (weapon == WEAPON_DUAL_CLUBS) return DUAL_CLUBS_REQS();
        if (weapon == WEAPON_ARMING_SWORD_SHORTSWORD) return ARMING_SWORD_SHORTSWORD_REQS();
        if (weapon == WEAPON_SCIMITAR_DAGGER) return SCIMITAR_DAGGER_REQS();
        if (weapon == WEAPON_ARMING_SWORD_CLUB) return ARMING_SWORD_CLUB_REQS();
        if (weapon == WEAPON_AXE_MACE) return AXE_MACE_REQS();
        if (weapon == WEAPON_FLAIL_DAGGER) return FLAIL_DAGGER_REQS();
        if (weapon == WEAPON_MACE_SHORTSWORD) return MACE_SHORTSWORD_REQS();
        if (weapon == WEAPON_MAUL) return MAUL_REQS();
        if (weapon == WEAPON_TRIDENT) return TRIDENT_REQS();
        revert("Invalid weapon type");
    }

    function CLOTH_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 0, stamina: 0, luck: 0});
    }

    function LEATHER_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 5, constitution: 0, size: 0, agility: 0, stamina: 0, luck: 0});
    }

    function CHAIN_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 8, constitution: 6, size: 0, agility: 0, stamina: 6, luck: 0});
    }

    function PLATE_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 10, constitution: 8, size: 0, agility: 0, stamina: 8, luck: 0});
    }

    /// @notice Get the minimum stat requirements for an armor type
    /// @param armor The armor type ID
    /// @return Minimum attributes required to use the armor
    function getArmorRequirements(uint8 armor) external pure returns (Fighter.Attributes memory) {
        if (armor == ARMOR_CLOTH) return CLOTH_REQS();
        if (armor == ARMOR_LEATHER) return LEATHER_REQS();
        if (armor == ARMOR_CHAIN) return CHAIN_REQS();
        if (armor == ARMOR_PLATE) return PLATE_REQS();
        revert("Invalid armor type");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IEquipmentRequirements.sol";
import "./Fighter.sol";

/// @title Equipment Requirements Contract
/// @notice Manages stat requirements for weapons and armor in Heavy Helms
/// @dev Pure functions that return minimum stat requirements for equipment
contract EquipmentRequirements is IEquipmentRequirements {
    // TODO: These should match GameEngine constants
    // Weapon Types
    uint8 public constant WEAPON_SWORD_AND_SHIELD = 0;
    uint8 public constant WEAPON_MACE_AND_SHIELD = 1;
    uint8 public constant WEAPON_RAPIER_AND_SHIELD = 2;
    uint8 public constant WEAPON_GREATSWORD = 3;
    uint8 public constant WEAPON_BATTLEAXE = 4;
    uint8 public constant WEAPON_QUARTERSTAFF = 5;
    uint8 public constant WEAPON_SPEAR = 6;

    // Armor Types
    uint8 public constant ARMOR_CLOTH = 0;
    uint8 public constant ARMOR_LEATHER = 1;
    uint8 public constant ARMOR_CHAIN = 2;
    uint8 public constant ARMOR_PLATE = 3;

    function SWORD_AND_SHIELD_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 10, constitution: 0, size: 0, agility: 6, stamina: 0, luck: 0});
    }

    function MACE_AND_SHIELD_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 12, constitution: 0, size: 0, agility: 0, stamina: 8, luck: 0});
    }

    function RAPIER_AND_SHIELD_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 6, constitution: 0, size: 0, agility: 12, stamina: 0, luck: 0});
    }

    function GREATSWORD_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 12, constitution: 0, size: 10, agility: 8, stamina: 0, luck: 0});
    }

    function BATTLEAXE_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 15, constitution: 0, size: 12, agility: 0, stamina: 0, luck: 0});
    }

    function QUARTERSTAFF_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 0, stamina: 0, luck: 0});
    }

    function SPEAR_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 8, constitution: 0, size: 8, agility: 10, stamina: 0, luck: 0});
    }

    /// @notice Get the minimum stat requirements for a weapon type
    /// @param weapon The weapon type ID
    /// @return Minimum attributes required to use the weapon
    function getWeaponRequirements(uint8 weapon) external pure returns (Fighter.Attributes memory) {
        if (weapon == WEAPON_SWORD_AND_SHIELD) return SWORD_AND_SHIELD_REQS();
        if (weapon == WEAPON_MACE_AND_SHIELD) return MACE_AND_SHIELD_REQS();
        if (weapon == WEAPON_RAPIER_AND_SHIELD) return RAPIER_AND_SHIELD_REQS();
        if (weapon == WEAPON_GREATSWORD) return GREATSWORD_REQS();
        if (weapon == WEAPON_BATTLEAXE) return BATTLEAXE_REQS();
        if (weapon == WEAPON_QUARTERSTAFF) return QUARTERSTAFF_REQS();
        if (weapon == WEAPON_SPEAR) return SPEAR_REQS();
        revert("Invalid weapon type");
    }

    function CLOTH_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 0, constitution: 0, size: 0, agility: 0, stamina: 0, luck: 0});
    }

    function LEATHER_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 5, constitution: 0, size: 0, agility: 0, stamina: 0, luck: 0});
    }

    function CHAIN_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 8, constitution: 8, size: 0, agility: 0, stamina: 0, luck: 0});
    }

    function PLATE_REQS() public pure returns (Fighter.Attributes memory) {
        return Fighter.Attributes({strength: 10, constitution: 10, size: 0, agility: 0, stamina: 0, luck: 0});
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

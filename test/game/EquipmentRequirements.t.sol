// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {EquipmentRequirements} from "../../src/game/engine/EquipmentRequirements.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";

contract EquipmentRequirementsTest is Test {
    EquipmentRequirements public reqs;

    // All valid weapon type IDs (gaps at 15, 23)
    uint8[] public validWeapons;

    function setUp() public {
        reqs = new EquipmentRequirements();
        validWeapons = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 18, 19, 20, 21, 22, 24, 25, 26];
    }

    // --- Weapon Requirements ---

    function testGetWeaponRequirementsAllValid() public view {
        for (uint256 i = 0; i < validWeapons.length; i++) {
            Fighter.Attributes memory attr = reqs.getWeaponRequirements(validWeapons[i]);
            // Every return should be a valid struct (no revert)
            assertTrue(
                attr.strength <= 21 && attr.constitution <= 21 && attr.size <= 21 && attr.agility <= 21
                    && attr.stamina <= 21 && attr.luck <= 21
            );
        }
    }

    function testRevertWhen_InvalidWeaponType() public {
        vm.expectRevert("Invalid weapon type");
        reqs.getWeaponRequirements(15);

        vm.expectRevert("Invalid weapon type");
        reqs.getWeaponRequirements(23);

        vm.expectRevert("Invalid weapon type");
        reqs.getWeaponRequirements(27);

        vm.expectRevert("Invalid weapon type");
        reqs.getWeaponRequirements(255);
    }

    // Spot-check specific weapon requirements
    function testBattleaxeRequirements() public view {
        Fighter.Attributes memory attr = reqs.getWeaponRequirements(reqs.WEAPON_BATTLEAXE());
        assertEq(attr.strength, 16);
        assertEq(attr.size, 12);
        assertEq(attr.agility, 0);
    }

    function testQuarterstaffRequirementsZero() public view {
        Fighter.Attributes memory attr = reqs.getWeaponRequirements(reqs.WEAPON_QUARTERSTAFF());
        assertEq(attr.strength, 0);
        assertEq(attr.constitution, 0);
        assertEq(attr.size, 0);
        assertEq(attr.agility, 0);
        assertEq(attr.stamina, 0);
        assertEq(attr.luck, 0);
    }

    function testMaulRequirements() public view {
        Fighter.Attributes memory attr = reqs.getWeaponRequirements(reqs.WEAPON_MAUL());
        assertEq(attr.strength, 18);
        assertEq(attr.size, 12);
    }

    // --- Armor Requirements ---

    function testGetArmorRequirementsAllValid() public view {
        for (uint8 i = 0; i < 4; i++) {
            Fighter.Attributes memory attr = reqs.getArmorRequirements(i);
            assertTrue(attr.strength <= 21 && attr.constitution <= 21);
        }
    }

    function testRevertWhen_InvalidArmorType() public {
        vm.expectRevert("Invalid armor type");
        reqs.getArmorRequirements(4);

        vm.expectRevert("Invalid armor type");
        reqs.getArmorRequirements(255);
    }

    function testPlateArmorRequirements() public view {
        Fighter.Attributes memory attr = reqs.getArmorRequirements(reqs.ARMOR_PLATE());
        assertEq(attr.strength, 10);
        assertEq(attr.constitution, 8);
        assertEq(attr.stamina, 8);
    }

    function testClothArmorRequirementsZero() public view {
        Fighter.Attributes memory attr = reqs.getArmorRequirements(reqs.ARMOR_CLOTH());
        assertEq(attr.strength, 0);
        assertEq(attr.constitution, 0);
        assertEq(attr.size, 0);
        assertEq(attr.agility, 0);
        assertEq(attr.stamina, 0);
        assertEq(attr.luck, 0);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {Monster, InvalidMonsterRange, MonsterDoesNotExist} from "../../src/fighters/Monster.sol";
import {IMonster} from "../../src/interfaces/fighters/IMonster.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";

contract MonsterTest is TestBase {
    function setUp() public override {
        super.setUp();
    }

    // --- View Functions ---

    function testGetMonsterLevel1() public view {
        // Monster 2001 was created in TestBase._mintMonsters()
        IMonster.MonsterStats memory stats = monsterContract.getMonster(2001, 1);
        assertTrue(stats.attributes.strength > 0, "Should have non-zero strength");
    }

    function testGetMonsterLevel10() public view {
        IMonster.MonsterStats memory stats = monsterContract.getMonster(2001, 10);
        assertTrue(stats.attributes.strength > 0);
    }

    function testIsValidId() public view {
        assertTrue(monsterContract.isValidId(2001));
        assertTrue(monsterContract.isValidId(10000));
        assertFalse(monsterContract.isValidId(2000));
        assertFalse(monsterContract.isValidId(10001));
    }

    function testNameRegistry() public view {
        assertEq(address(monsterContract.nameRegistry()), address(monsterNameRegistry));
    }

    function testSkinRegistry() public view {
        assertEq(address(monsterContract.skinRegistry()), address(skinRegistry));
    }

    // --- Revert Paths ---

    function testRevertWhen_GetMonsterInvalidRange() public {
        vm.expectRevert(InvalidMonsterRange.selector);
        monsterContract.getMonster(1, 1);
    }

    function testRevertWhen_GetMonsterDoesNotExist() public {
        vm.expectRevert(MonsterDoesNotExist.selector);
        monsterContract.getMonster(9999, 1);
    }

    function testRevertWhen_GetMonsterInvalidLevel() public {
        vm.expectRevert("Invalid level");
        monsterContract.getMonster(2001, 0);

        vm.expectRevert("Invalid level");
        monsterContract.getMonster(2001, 11);
    }

    // --- updateMonsterStats ---

    function testUpdateMonsterStats() public {
        IMonster.MonsterStats memory existing = monsterContract.getMonster(2001, 1);
        uint8 originalStr = existing.attributes.strength;

        IMonster.MonsterStats[10] memory newStats;
        for (uint8 i = 0; i < 10; i++) {
            newStats[i].attributes = Fighter.Attributes({
                strength: originalStr + 1,
                constitution: existing.attributes.constitution,
                size: existing.attributes.size,
                agility: existing.attributes.agility,
                stamina: existing.attributes.stamina,
                luck: existing.attributes.luck
            });
            newStats[i].name = existing.name;
            newStats[i].skin = existing.skin;
            newStats[i].stance = existing.stance;
            newStats[i].level = i + 1;
        }

        monsterContract.updateMonsterStats(2001, newStats);

        IMonster.MonsterStats memory updated = monsterContract.getMonster(2001, 1);
        assertEq(updated.attributes.strength, originalStr + 1);
    }

    function testRevertWhen_UpdateMonsterStatsNotOwner() public {
        IMonster.MonsterStats[10] memory stats;

        vm.expectRevert("Only callable by owner");
        vm.prank(address(0x1234));
        monsterContract.updateMonsterStats(2001, stats);
    }

    function testRevertWhen_UpdateMonsterStatsDoesNotExist() public {
        IMonster.MonsterStats[10] memory stats;

        vm.expectRevert(MonsterDoesNotExist.selector);
        monsterContract.updateMonsterStats(9999, stats);
    }
}

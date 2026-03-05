// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {
    MonsterNameRegistry,
    EmptyBatch,
    BatchTooLarge,
    InvalidNameLength,
    InvalidNameIndex
} from "../../src/fighters/registries/names/MonsterNameRegistry.sol";

contract MonsterNameRegistryTest is Test {
    MonsterNameRegistry public registry;

    function setUp() public {
        registry = new MonsterNameRegistry();
    }

    function testConstructorState() public view {
        // Index 0 is reserved empty name
        assertEq(registry.getMonsterNamesLength(), 1);
    }

    function testAddMonsterNames() public {
        string[] memory names = new string[](2);
        names[0] = "Goblin King";
        names[1] = "Shadow Fiend";
        registry.addMonsterNames(names);

        assertEq(registry.getMonsterNamesLength(), 3); // 1 empty + 2 added
        assertEq(registry.getMonsterName(1), "Goblin King");
        assertEq(registry.getMonsterName(2), "Shadow Fiend");
    }

    function testRevertWhen_GetNameIndexZero() public {
        vm.expectRevert(InvalidNameIndex.selector);
        registry.getMonsterName(0);
    }

    function testRevertWhen_GetNameIndexOutOfBounds() public {
        vm.expectRevert(InvalidNameIndex.selector);
        registry.getMonsterName(5);
    }

    function testRevertWhen_AddEmptyBatch() public {
        string[] memory names = new string[](0);
        vm.expectRevert(EmptyBatch.selector);
        registry.addMonsterNames(names);
    }

    function testRevertWhen_AddBatchTooLarge() public {
        string[] memory names = new string[](501);
        for (uint256 i = 0; i < 501; i++) {
            names[i] = "Name";
        }
        vm.expectRevert(BatchTooLarge.selector);
        registry.addMonsterNames(names);
    }

    function testRevertWhen_AddInvalidNameLengthEmpty() public {
        string[] memory names = new string[](1);
        names[0] = "";
        vm.expectRevert(InvalidNameLength.selector);
        registry.addMonsterNames(names);
    }

    function testRevertWhen_AddInvalidNameLengthTooLong() public {
        string[] memory names = new string[](1);
        names[0] = "ThisNameIsWayTooLongForTheLimit!!"; // 32 chars, max is 31
        vm.expectRevert(InvalidNameLength.selector);
        registry.addMonsterNames(names);
    }

    function testRevertWhen_AddNamesNotOwner() public {
        string[] memory names = new string[](1);
        names[0] = "Test";
        vm.expectRevert("Only callable by owner");
        vm.prank(address(0x1234));
        registry.addMonsterNames(names);
    }
}

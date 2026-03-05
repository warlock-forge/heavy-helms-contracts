// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {
    DefaultPlayer,
    InvalidDefaultPlayerRange,
    PlayerDoesNotExist,
    DefaultPlayerExists,
    BadZeroAddress,
    InvalidDefaultPlayerSkinType,
    InvalidNameIndex
} from "../../src/fighters/DefaultPlayer.sol";
import {IPlayerSkinRegistry} from "../../src/interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";

contract DefaultPlayerTest is TestBase {
    function setUp() public override {
        super.setUp();
    }

    // --- View Functions ---

    function testGetDefaultPlayerLevel1() public view {
        // Default player 1 was created in TestBase._mintDefaultCharacters()
        IPlayer.PlayerStats memory stats = defaultPlayerContract.getDefaultPlayer(1, 1);
        assertTrue(stats.attributes.strength > 0, "Should have non-zero strength");
        assertEq(stats.level, 1);
    }

    function testGetDefaultPlayerLevel10() public view {
        IPlayer.PlayerStats memory stats = defaultPlayerContract.getDefaultPlayer(1, 10);
        assertEq(stats.level, 10);
        // Level 10 stats should be >= level 1 stats
        IPlayer.PlayerStats memory lvl1 = defaultPlayerContract.getDefaultPlayer(1, 1);
        assertTrue(stats.attributes.strength >= lvl1.attributes.strength, "Level 10 strength should be >= level 1");
    }

    function testIsValidId() public view {
        assertTrue(defaultPlayerContract.isValidId(1));
        assertTrue(defaultPlayerContract.isValidId(2000));
        assertFalse(defaultPlayerContract.isValidId(0));
        assertFalse(defaultPlayerContract.isValidId(2001));
    }

    function testValidDefaultPlayerCount() public view {
        // TestBase creates default characters via DefaultPlayerLibrary
        assertTrue(defaultPlayerContract.validDefaultPlayerCount() > 0);
    }

    function testGetValidDefaultPlayerId() public view {
        uint32 id = defaultPlayerContract.getValidDefaultPlayerId(0);
        assertTrue(defaultPlayerContract.isValidId(id));
    }

    // --- Revert Paths ---

    function testRevertWhen_GetDefaultPlayerInvalidRange() public {
        vm.expectRevert(InvalidDefaultPlayerRange.selector);
        defaultPlayerContract.getDefaultPlayer(2001, 1);
    }

    function testRevertWhen_GetDefaultPlayerDoesNotExist() public {
        // ID 1999 is in range but was never created
        vm.expectRevert(abi.encodeWithSelector(PlayerDoesNotExist.selector, 1999));
        defaultPlayerContract.getDefaultPlayer(1999, 1);
    }

    function testRevertWhen_GetDefaultPlayerInvalidLevel() public {
        vm.expectRevert("Invalid level");
        defaultPlayerContract.getDefaultPlayer(1, 0);

        vm.expectRevert("Invalid level");
        defaultPlayerContract.getDefaultPlayer(1, 11);
    }

    function testRevertWhen_CreateDefaultPlayerAlreadyExists() public {
        // Player 1 was already created in setUp via _mintDefaultCharacters
        IPlayer.PlayerStats[10] memory stats;
        // Fill with dummy data (won't actually get used due to revert)
        for (uint8 i = 0; i < 10; i++) {
            stats[i].attributes =
                Fighter.Attributes({strength: 10, constitution: 10, size: 10, agility: 10, stamina: 10, luck: 10});
            stats[i].level = i + 1;
            stats[i].skin = Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: 1});
            stats[i].name = IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 0});
        }

        vm.expectRevert(abi.encodeWithSelector(DefaultPlayerExists.selector, 1));
        defaultPlayerContract.createDefaultPlayer(1, stats);
    }

    function testRevertWhen_CreateDefaultPlayerInvalidRange() public {
        IPlayer.PlayerStats[10] memory stats;

        vm.expectRevert(InvalidDefaultPlayerRange.selector);
        defaultPlayerContract.createDefaultPlayer(2001, stats);
    }

    function testRevertWhen_CreateDefaultPlayerNotOwner() public {
        IPlayer.PlayerStats[10] memory stats;

        vm.expectRevert("Only callable by owner");
        vm.prank(address(0x1234));
        defaultPlayerContract.createDefaultPlayer(1999, stats);
    }

    // --- SkinRegistry ---

    function testSkinRegistry() public view {
        assertEq(address(defaultPlayerContract.skinRegistry()), address(skinRegistry));
    }

    // --- NameRegistry ---

    function testNameRegistry() public view {
        assertEq(address(defaultPlayerContract.nameRegistry()), address(nameRegistry));
    }

    // --- updateDefaultPlayerStats ---

    function testUpdateDefaultPlayerStats() public {
        // Player 1 already exists from setUp. Update its stats.
        IPlayer.PlayerStats memory existing = defaultPlayerContract.getDefaultPlayer(1, 1);
        uint8 originalStr = existing.attributes.strength;

        IPlayer.PlayerStats[10] memory newStats;
        for (uint8 i = 0; i < 10; i++) {
            newStats[i].attributes = Fighter.Attributes({
                strength: originalStr + 1,
                constitution: existing.attributes.constitution,
                size: existing.attributes.size,
                agility: existing.attributes.agility,
                stamina: existing.attributes.stamina,
                luck: existing.attributes.luck
            });
            newStats[i].level = i + 1;
            newStats[i].skin = existing.skin;
            newStats[i].name = existing.name;
        }

        defaultPlayerContract.updateDefaultPlayerStats(1, newStats);

        IPlayer.PlayerStats memory updated = defaultPlayerContract.getDefaultPlayer(1, 1);
        assertEq(updated.attributes.strength, originalStr + 1);
    }

    function testRevertWhen_UpdateDefaultPlayerStatsNotOwner() public {
        IPlayer.PlayerStats[10] memory stats;

        vm.expectRevert("Only callable by owner");
        vm.prank(address(0x1234));
        defaultPlayerContract.updateDefaultPlayerStats(1, stats);
    }

    function testRevertWhen_UpdateDefaultPlayerStatsDoesNotExist() public {
        IPlayer.PlayerStats[10] memory stats;
        for (uint8 i = 0; i < 10; i++) {
            stats[i].attributes =
                Fighter.Attributes({strength: 10, constitution: 10, size: 10, agility: 10, stamina: 10, luck: 10});
            stats[i].level = i + 1;
            stats[i].skin = Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: 1});
            stats[i].name = IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 0});
        }

        vm.expectRevert(abi.encodeWithSelector(PlayerDoesNotExist.selector, 1999));
        defaultPlayerContract.updateDefaultPlayerStats(1999, stats);
    }

    // --- Constructor Reverts ---

    function testRevertWhen_ConstructorZeroNameRegistry() public {
        vm.expectRevert(BadZeroAddress.selector);
        new DefaultPlayer(address(skinRegistry), address(0));
    }

    // --- CreateDefaultPlayer Validation ---

    function testRevertWhen_CreateDefaultPlayerInvalidSkinType() public {
        // Register a non-DefaultPlayer skin (Monster type)
        uint32 mSkinIdx = monsterSkinIndex;

        IPlayer.PlayerStats[10] memory stats;
        for (uint8 i = 0; i < 10; i++) {
            stats[i].attributes =
                Fighter.Attributes({strength: 10, constitution: 10, size: 10, agility: 10, stamina: 10, luck: 10});
            stats[i].level = i + 1;
            stats[i].skin = Fighter.SkinInfo({skinIndex: mSkinIdx, skinTokenId: 1});
            stats[i].name = IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 0});
        }

        vm.expectRevert(abi.encodeWithSelector(InvalidDefaultPlayerSkinType.selector, mSkinIdx));
        defaultPlayerContract.createDefaultPlayer(1999, stats);
    }

    function testRevertWhen_CreateDefaultPlayerInvalidNameIndex() public {
        IPlayer.PlayerStats[10] memory stats;
        for (uint8 i = 0; i < 10; i++) {
            stats[i].attributes =
                Fighter.Attributes({strength: 10, constitution: 10, size: 10, agility: 10, stamina: 10, luck: 10});
            stats[i].level = i + 1;
            stats[i].skin = Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: 1});
            stats[i].name = IPlayer.PlayerName({firstNameIndex: 9999, surnameIndex: 9999});
        }

        vm.expectRevert(InvalidNameIndex.selector);
        defaultPlayerContract.createDefaultPlayer(1999, stats);
    }

    function testRevertWhen_UpdateDefaultPlayerStatsInvalidSkinType() public {
        IPlayer.PlayerStats memory existing = defaultPlayerContract.getDefaultPlayer(1, 1);

        IPlayer.PlayerStats[10] memory newStats;
        for (uint8 i = 0; i < 10; i++) {
            newStats[i].attributes = existing.attributes;
            newStats[i].level = i + 1;
            newStats[i].skin = Fighter.SkinInfo({skinIndex: monsterSkinIndex, skinTokenId: 1});
            newStats[i].name = existing.name;
        }

        vm.expectRevert(abi.encodeWithSelector(InvalidDefaultPlayerSkinType.selector, monsterSkinIndex));
        defaultPlayerContract.updateDefaultPlayerStats(1, newStats);
    }

    function testRevertWhen_UpdateDefaultPlayerStatsInvalidNameIndex() public {
        IPlayer.PlayerStats memory existing = defaultPlayerContract.getDefaultPlayer(1, 1);

        IPlayer.PlayerStats[10] memory newStats;
        for (uint8 i = 0; i < 10; i++) {
            newStats[i].attributes = existing.attributes;
            newStats[i].level = i + 1;
            newStats[i].skin = existing.skin;
            newStats[i].name = IPlayer.PlayerName({firstNameIndex: 9999, surnameIndex: 9999});
        }

        vm.expectRevert(InvalidNameIndex.selector);
        defaultPlayerContract.updateDefaultPlayerStats(1, newStats);
    }
}

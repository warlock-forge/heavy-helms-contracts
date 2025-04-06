// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {
    Player,
    TooManyPlayers,
    NotPlayerOwner,
    InvalidPlayerStats,
    NoPermission,
    PlayerDoesNotExist,
    InsufficientCharges,
    InvalidAttributeSwap,
    InvalidNameIndex,
    BadZeroAddress,
    InsufficientFeeAmount,
    PendingRequestExists
} from "../../src/fighters/Player.sol";
import "../TestBase.sol";

event NameChangeAwarded(address indexed to, uint256 totalCharges);

event AttributeSwapAwarded(address indexed to, uint256 totalCharges);

contract PlayerChargesTest is TestBase {
    address public PLAYER_ONE;
    address public PLAYER_TWO;

    function setUp() public override {
        super.setUp();

        PLAYER_ONE = address(0x1111);
        PLAYER_TWO = address(0x2222);
    }

    function testNameChangeCharges() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant name permission to test contract
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, name: true, attributes: false, immortal: false});
        playerContract.setGameContractPermission(address(this), permissions);

        // Award charge and verify event
        vm.expectEmit(true, false, false, true);
        emit NameChangeAwarded(PLAYER_ONE, 1);
        playerContract.awardNameChange(PLAYER_ONE);

        assertEq(playerContract.nameChangeCharges(PLAYER_ONE), 1, "Should have 1 name change charge");

        // Change name
        uint16 newFirstName = 5;
        uint16 newSurname = 10;

        vm.startPrank(PLAYER_ONE);
        playerContract.changeName(playerId, newFirstName, newSurname);
        vm.stopPrank();

        // Verify name changed and charge consumed
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertEq(stats.name.firstNameIndex, newFirstName, "First name should be updated");
        assertEq(stats.name.surnameIndex, newSurname, "Surname should be updated");
        assertEq(playerContract.nameChangeCharges(PLAYER_ONE), 0, "Should have 0 charges remaining");
    }

    function testCannotChangeNameWithoutCharge() public {
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(InsufficientCharges.selector);
        playerContract.changeName(playerId, 5, 10);
        vm.stopPrank();
    }

    function testCannotChangeNameForNonOwnedPlayer() public {
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant permission and award charge to PLAYER_TWO
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, name: true, attributes: false, immortal: false});
        playerContract.setGameContractPermission(address(this), permissions);
        playerContract.awardNameChange(PLAYER_TWO);

        vm.startPrank(PLAYER_TWO);
        vm.expectRevert(NotPlayerOwner.selector);
        playerContract.changeName(playerId, 5, 10);
        vm.stopPrank();
    }

    function testAttributeSwapCharges() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant attribute permission to test contract
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, name: false, attributes: true, immortal: false});
        playerContract.setGameContractPermission(address(this), permissions);

        // Award charge and verify event
        vm.expectEmit(true, false, false, true);
        emit AttributeSwapAwarded(PLAYER_ONE, 1);
        playerContract.awardAttributeSwap(PLAYER_ONE);

        // Store initial stats and find valid attributes to swap
        IPlayer.PlayerStats memory initialStats = playerContract.getPlayer(playerId);

        // Find a stat > MIN_STAT to decrease and a stat < MAX_STAT to increase
        IPlayer.Attribute decreaseAttr = IPlayer.Attribute.STRENGTH;
        IPlayer.Attribute increaseAttr = IPlayer.Attribute.AGILITY;
        uint8 decreaseVal = initialStats.attributes.strength;
        uint8 increaseVal = initialStats.attributes.agility;

        require(decreaseVal > 3 && increaseVal < 21, "Could not find valid stats to swap");

        // Perform swap
        vm.startPrank(PLAYER_ONE);
        playerContract.swapAttributes(playerId, decreaseAttr, increaseAttr);
        vm.stopPrank();

        // Verify stats were modified correctly (-1/+1)
        IPlayer.PlayerStats memory newStats = playerContract.getPlayer(playerId);
        assertEq(newStats.attributes.strength, decreaseVal - 1, "Strength should decrease by 1");
        assertEq(newStats.attributes.agility, increaseVal + 1, "Agility should increase by 1");
        assertEq(playerContract.attributeSwapCharges(PLAYER_ONE), 0, "Should have 0 charges remaining");
    }

    function testMultipleCharges() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant both permissions
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, name: true, attributes: true, immortal: false});
        playerContract.setGameContractPermission(address(this), permissions);

        // Award multiple charges
        playerContract.awardNameChange(PLAYER_ONE);
        playerContract.awardNameChange(PLAYER_ONE);
        playerContract.awardAttributeSwap(PLAYER_ONE);
        playerContract.awardAttributeSwap(PLAYER_ONE);

        assertEq(playerContract.nameChangeCharges(PLAYER_ONE), 2, "Should have 2 name charges");
        assertEq(playerContract.attributeSwapCharges(PLAYER_ONE), 2, "Should have 2 attribute charges");

        // Use charges
        vm.startPrank(PLAYER_ONE);
        playerContract.changeName(playerId, 5, 10);
        assertEq(playerContract.nameChangeCharges(PLAYER_ONE), 1, "Should have 1 name charge remaining");

        // Get initial stats to find valid attributes to swap
        IPlayer.PlayerStats memory initialStats = playerContract.getPlayer(playerId);
        require(
            initialStats.attributes.strength > 3 && initialStats.attributes.agility < 21,
            "Could not find valid stats to swap"
        );

        playerContract.swapAttributes(playerId, IPlayer.Attribute.STRENGTH, IPlayer.Attribute.AGILITY);
        assertEq(playerContract.attributeSwapCharges(PLAYER_ONE), 1, "Should have 1 attribute charge remaining");
        vm.stopPrank();
    }

    function testInvalidAttributeSwap() public {
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant permission and award charge
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, name: false, attributes: true, immortal: false});
        playerContract.setGameContractPermission(address(this), permissions);
        playerContract.awardAttributeSwap(PLAYER_ONE);

        // Try to swap same attribute
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(InvalidAttributeSwap.selector);
        playerContract.swapAttributes(playerId, IPlayer.Attribute.STRENGTH, IPlayer.Attribute.STRENGTH);
        vm.stopPrank();
    }

    function testChargesNotTransferable() public {
        // Award charges to PLAYER_ONE
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, name: true, attributes: true, immortal: false});
        playerContract.setGameContractPermission(address(this), permissions);

        playerContract.awardNameChange(PLAYER_ONE);
        playerContract.awardAttributeSwap(PLAYER_ONE);

        // Create player owned by PLAYER_TWO
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

        // Try to use PLAYER_ONE's charges on PLAYER_TWO's character
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(NotPlayerOwner.selector);
        playerContract.changeName(playerId, 5, 10);

        vm.expectRevert(NotPlayerOwner.selector);
        playerContract.swapAttributes(playerId, IPlayer.Attribute.STRENGTH, IPlayer.Attribute.AGILITY);
        vm.stopPrank();
    }

    function testAttributeSwapMinMaxLimits() public skipInCI {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant attribute permission to test contract
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, name: false, attributes: true, immortal: false});
        playerContract.setGameContractPermission(address(this), permissions);

        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);

        // Find a stat > MIN_STAT to decrease and a stat < MAX_STAT to increase
        IPlayer.Attribute decreaseAttr = IPlayer.Attribute.STRENGTH;
        IPlayer.Attribute increaseAttr = IPlayer.Attribute.AGILITY;
        uint8 decreaseVal = stats.attributes.strength;
        uint8 increaseVal = stats.attributes.agility;

        // Try each combination until we find one where:
        // 1. decreaseVal > 3 (so we can decrease it)
        // 2. increaseVal < 21 (so we can increase it)
        // 3. decreaseVal - 3 <= 21 - increaseVal (so we won't hit MAX before MIN)
        bool foundValidPair = false;

        if (
            stats.attributes.strength > 3 && stats.attributes.agility < 21
                && (stats.attributes.strength - 3 <= 21 - stats.attributes.agility)
        ) {
            decreaseAttr = IPlayer.Attribute.STRENGTH;
            increaseAttr = IPlayer.Attribute.AGILITY;
            decreaseVal = stats.attributes.strength;
            increaseVal = stats.attributes.agility;
            foundValidPair = true;
        } else if (
            stats.attributes.constitution > 3 && stats.attributes.size < 21
                && (stats.attributes.constitution - 3 <= 21 - stats.attributes.size)
        ) {
            decreaseAttr = IPlayer.Attribute.CONSTITUTION;
            increaseAttr = IPlayer.Attribute.SIZE;
            decreaseVal = stats.attributes.constitution;
            increaseVal = stats.attributes.size;
            foundValidPair = true;
        } else if (
            stats.attributes.size > 3 && stats.attributes.stamina < 21
                && (stats.attributes.size - 3 <= 21 - stats.attributes.stamina)
        ) {
            decreaseAttr = IPlayer.Attribute.SIZE;
            increaseAttr = IPlayer.Attribute.STAMINA;
            decreaseVal = stats.attributes.size;
            increaseVal = stats.attributes.stamina;
            foundValidPair = true;
        } else if (
            stats.attributes.agility > 3 && stats.attributes.luck < 21
                && (stats.attributes.agility - 3 <= 21 - stats.attributes.luck)
        ) {
            decreaseAttr = IPlayer.Attribute.AGILITY;
            increaseAttr = IPlayer.Attribute.LUCK;
            decreaseVal = stats.attributes.agility;
            increaseVal = stats.attributes.luck;
            foundValidPair = true;
        }

        require(foundValidPair, "Could not find valid stats to swap");

        // Keep swapping until we hit MIN_STAT
        while (decreaseVal > 3) {
            playerContract.awardAttributeSwap(PLAYER_ONE);
            vm.prank(PLAYER_ONE);
            playerContract.swapAttributes(playerId, decreaseAttr, increaseAttr);
            stats = playerContract.getPlayer(playerId);
            decreaseVal = _getAttributeValue(stats, decreaseAttr);
        }

        // Now try to decrease MIN_STAT (should fail)
        playerContract.awardAttributeSwap(PLAYER_ONE);
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(InvalidAttributeSwap.selector);
        playerContract.swapAttributes(playerId, decreaseAttr, increaseAttr);
        vm.stopPrank();
    }

    function testInvalidNameIndices() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant name permission and award charge
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, name: true, attributes: false, immortal: false});
        playerContract.setGameContractPermission(address(this), permissions);
        playerContract.awardNameChange(PLAYER_ONE);

        vm.startPrank(PLAYER_ONE);

        // Test invalid name indices
        uint16 invalidSetBIndex = 999; // Last index in Set B range (which we know doesn't exist)
        uint16 invalidSetAIndex = 2000; // High index in Set A range (which we know doesn't exist)
        uint16 invalidSurnameIndex = uint16(nameRegistry.getSurnamesLength());

        // Test invalid indices
        vm.expectRevert(InvalidNameIndex.selector);
        playerContract.changeName(playerId, invalidSetBIndex, 0);

        vm.expectRevert(InvalidNameIndex.selector);
        playerContract.changeName(playerId, invalidSetAIndex, 0);

        vm.expectRevert(InvalidNameIndex.selector);
        playerContract.changeName(playerId, 0, invalidSurnameIndex);

        // Verify charge wasn't consumed
        assertEq(playerContract.nameChangeCharges(PLAYER_ONE), 1, "Charge should not be consumed on failed attempts");

        vm.stopPrank();
    }

    function testCannotAwardChargesToZeroAddress() public {
        // Grant both permissions
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, name: true, attributes: true, immortal: false});
        playerContract.setGameContractPermission(address(this), permissions);

        // Try to award name change to zero address
        vm.expectRevert(BadZeroAddress.selector);
        playerContract.awardNameChange(address(0));

        // Try to award attribute swap to zero address
        vm.expectRevert(BadZeroAddress.selector);
        playerContract.awardAttributeSwap(address(0));
    }

    // Helper function to get attribute value
    function _getAttributeValue(IPlayer.PlayerStats memory stats, IPlayer.Attribute attr)
        internal
        pure
        returns (uint8)
    {
        if (attr == IPlayer.Attribute.STRENGTH) return stats.attributes.strength;
        if (attr == IPlayer.Attribute.CONSTITUTION) return stats.attributes.constitution;
        if (attr == IPlayer.Attribute.SIZE) return stats.attributes.size;
        if (attr == IPlayer.Attribute.AGILITY) return stats.attributes.agility;
        if (attr == IPlayer.Attribute.STAMINA) return stats.attributes.stamina;
        return stats.attributes.luck;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {
    Player,
    NotPlayerOwner,
    NoPermission,
    InsufficientCharges,
    InvalidAttributeSwap,
    BadZeroAddress
} from "../../src/fighters/Player.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import "../TestBase.sol";

event AttributeSwapAwarded(address indexed to, uint256 totalCharges);

contract PlayerChargesTest is TestBase {
    address public PLAYER_ONE;
    address public PLAYER_TWO;

    function setUp() public override {
        super.setUp();

        PLAYER_ONE = address(0x1111);
        PLAYER_TWO = address(0x2222);
    }

    function testAttributeSwapCharges() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant attribute permission to test contract
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, attributes: true, immortal: false, experience: false});
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
    }

    function testCannotSwapWithoutCharge() public {
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(InsufficientCharges.selector);
        playerContract.swapAttributes(playerId, IPlayer.Attribute.STRENGTH, IPlayer.Attribute.AGILITY);
        vm.stopPrank();
    }

    function testCannotSwapForNonOwnedPlayer() public {
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant permission and award charge to PLAYER_TWO
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, attributes: true, immortal: false, experience: false});
        playerContract.setGameContractPermission(address(this), permissions);
        playerContract.awardAttributeSwap(PLAYER_TWO);

        vm.startPrank(PLAYER_TWO);
        vm.expectRevert(NotPlayerOwner.selector);
        playerContract.swapAttributes(playerId, IPlayer.Attribute.STRENGTH, IPlayer.Attribute.AGILITY);
        vm.stopPrank();
    }

    function testInvalidAttributeSwap() public {
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant permission and award charge
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, attributes: true, immortal: false, experience: false});
        playerContract.setGameContractPermission(address(this), permissions);
        playerContract.awardAttributeSwap(PLAYER_ONE);

        // Try to swap same attribute
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(InvalidAttributeSwap.selector);
        playerContract.swapAttributes(playerId, IPlayer.Attribute.STRENGTH, IPlayer.Attribute.STRENGTH);
        vm.stopPrank();
    }

    function testCannotAwardChargesToZeroAddress() public {
        // Grant permission
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, attributes: true, immortal: false, experience: false});
        playerContract.setGameContractPermission(address(this), permissions);

        // Try to award attribute swap to zero address
        vm.expectRevert(BadZeroAddress.selector);
        playerContract.awardAttributeSwap(address(0));
    }

    function testMultipleAttributeSwaps() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant permission
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, attributes: true, immortal: false, experience: false});
        playerContract.setGameContractPermission(address(this), permissions);

        // Award multiple charges
        playerContract.awardAttributeSwap(PLAYER_ONE);
        playerContract.awardAttributeSwap(PLAYER_ONE);

        // Get initial stats to find valid attributes to swap
        IPlayer.PlayerStats memory initialStats = playerContract.getPlayer(playerId);
        require(
            initialStats.attributes.strength > 3 && initialStats.attributes.agility < 21,
            "Could not find valid stats to swap"
        );

        // Use first charge
        vm.startPrank(PLAYER_ONE);
        playerContract.swapAttributes(playerId, IPlayer.Attribute.STRENGTH, IPlayer.Attribute.AGILITY);
        
        // Use second charge
        playerContract.swapAttributes(playerId, IPlayer.Attribute.STRENGTH, IPlayer.Attribute.AGILITY);
        vm.stopPrank();

        // Verify stats were modified correctly (-2/+2)
        IPlayer.PlayerStats memory newStats = playerContract.getPlayer(playerId);
        assertEq(newStats.attributes.strength, initialStats.attributes.strength - 2, "Strength should decrease by 2");
        assertEq(newStats.attributes.agility, initialStats.attributes.agility + 2, "Agility should increase by 2");
    }
}
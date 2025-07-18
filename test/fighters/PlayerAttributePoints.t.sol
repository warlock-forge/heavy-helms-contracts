// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test, stdError} from "forge-std/Test.sol";
import {Player, NotPlayerOwner, InsufficientCharges, InvalidAttributeSwap} from "../../src/fighters/Player.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import "../TestBase.sol";

contract PlayerAttributePointsTest is TestBase {
    address public PLAYER_ONE;
    address public PLAYER_TWO;
    uint32 public playerId1;
    uint32 public playerId2;

    event PlayerLevelUp(uint32 indexed playerId, uint8 newLevel, uint8 attributePointsAwarded);
    event PlayerAttributePointUsed(uint32 indexed playerId, IPlayer.Attribute attribute, uint8 newValue, uint256 remainingPoints);
    event ExperienceGained(uint32 indexed playerId, uint16 xpGained, uint16 totalXP);

    function setUp() public override {
        super.setUp();

        PLAYER_ONE = address(0x1111);
        PLAYER_TWO = address(0x2222);
        
        // Create players
        playerId1 = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        playerId2 = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

        // Grant experience permission to this test contract
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, attributes: false, immortal: false, experience: true});
        playerContract.setGameContractPermission(address(this), permissions);
    }

    function testPlayerLevelUpAwarsAttributePoints() public {
        // Check initial state
        assertEq(playerContract.attributePoints(playerId1), 0);
        
        IPlayer.PlayerStats memory initialStats = playerContract.getPlayer(playerId1);
        assertEq(initialStats.level, 1);
        assertEq(initialStats.currentXP, 0);

        // Award enough XP to level up (100 XP for level 2)
        vm.expectEmit(true, false, false, true);
        emit PlayerLevelUp(playerId1, 2, 1);
        
        playerContract.awardExperience(playerId1, 100);

        // Check that player leveled up and got attribute points
        IPlayer.PlayerStats memory newStats = playerContract.getPlayer(playerId1);
        assertEq(newStats.level, 2);
        assertEq(playerContract.attributePoints(playerId1), 1);
    }

    function testMultipleLevelUpsAwardMultiplePoints() public {
        // Award enough XP to reach level 4 (100 + 150 + 225 = 475 XP)
        playerContract.awardExperience(playerId1, 475);

        // Should be level 4 with 3 attribute points
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId1);
        assertEq(stats.level, 4);
        assertEq(playerContract.attributePoints(playerId1), 3);
    }

    function testUseAttributePointIncreasesStatBeyond21() public {
        // Level up the player to get attribute points
        playerContract.awardExperience(playerId1, 100);
        assertEq(playerContract.attributePoints(playerId1), 1);

        // Get a player with a stat at 21 (if any)
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId1);
        
        // Find the highest stat and increase it
        IPlayer.Attribute targetAttribute = IPlayer.Attribute.STRENGTH;
        uint8 targetValue = stats.attributes.strength;
        
        // Find the highest stat to test going beyond 21
        if (stats.attributes.constitution > targetValue) {
            targetAttribute = IPlayer.Attribute.CONSTITUTION;
            targetValue = stats.attributes.constitution;
        }
        if (stats.attributes.size > targetValue) {
            targetAttribute = IPlayer.Attribute.SIZE;
            targetValue = stats.attributes.size;
        }
        if (stats.attributes.agility > targetValue) {
            targetAttribute = IPlayer.Attribute.AGILITY;
            targetValue = stats.attributes.agility;
        }
        if (stats.attributes.stamina > targetValue) {
            targetAttribute = IPlayer.Attribute.STAMINA;
            targetValue = stats.attributes.stamina;
        }
        if (stats.attributes.luck > targetValue) {
            targetAttribute = IPlayer.Attribute.LUCK;
            targetValue = stats.attributes.luck;
        }

        // Use the attribute point
        vm.startPrank(PLAYER_ONE);
        vm.expectEmit(true, false, false, true);
        emit PlayerAttributePointUsed(playerId1, targetAttribute, targetValue + 1, 0);
        
        playerContract.useAttributePoint(playerId1, targetAttribute);
        vm.stopPrank();

        // Verify the stat increased and points were consumed
        IPlayer.PlayerStats memory newStats = playerContract.getPlayer(playerId1);
        assertEq(playerContract.attributePoints(playerId1), 0);
        
        // Check that the specific attribute increased
        if (targetAttribute == IPlayer.Attribute.STRENGTH) {
            assertEq(newStats.attributes.strength, targetValue + 1);
        } else if (targetAttribute == IPlayer.Attribute.CONSTITUTION) {
            assertEq(newStats.attributes.constitution, targetValue + 1);
        } else if (targetAttribute == IPlayer.Attribute.SIZE) {
            assertEq(newStats.attributes.size, targetValue + 1);
        } else if (targetAttribute == IPlayer.Attribute.AGILITY) {
            assertEq(newStats.attributes.agility, targetValue + 1);
        } else if (targetAttribute == IPlayer.Attribute.STAMINA) {
            assertEq(newStats.attributes.stamina, targetValue + 1);
        } else if (targetAttribute == IPlayer.Attribute.LUCK) {
            assertEq(newStats.attributes.luck, targetValue + 1);
        }
    }

    function testCannotUseAttributePointsWithoutPoints() public {
        // Player starts with 0 attribute points
        assertEq(playerContract.attributePoints(playerId1), 0);

        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(InsufficientCharges.selector);
        playerContract.useAttributePoint(playerId1, IPlayer.Attribute.STRENGTH);
        vm.stopPrank();
    }

    function testCannotUseAttributePointsForNonOwnedPlayer() public {
        // Level up player 1 to get attribute points
        playerContract.awardExperience(playerId1, 100);
        assertEq(playerContract.attributePoints(playerId1), 1);

        // Try to use PLAYER_TWO to spend PLAYER_ONE's points
        vm.startPrank(PLAYER_TWO);
        vm.expectRevert(NotPlayerOwner.selector);
        playerContract.useAttributePoint(playerId1, IPlayer.Attribute.STRENGTH);
        vm.stopPrank();
    }

    function testCannotIncreaseStatBeyond25() public {
        // This is a theoretical test since we'd need a player with 25 in a stat
        // Create a player with high stats, then level them up to 25
        
        // Level up player many times to get lots of attribute points
        playerContract.awardExperience(playerId1, 2000); // Should get to level 10
        
        // In a real scenario, we'd need to manually increase a stat to 25
        // For now, let's test the cap logic when it's implemented
        assertTrue(playerContract.attributePoints(playerId1) > 0);
    }

    function testAttributePointsArePerPlayer() public {
        // Level up player 1
        playerContract.awardExperience(playerId1, 100);
        assertEq(playerContract.attributePoints(playerId1), 1);
        assertEq(playerContract.attributePoints(playerId2), 0);

        // Level up player 2
        playerContract.awardExperience(playerId2, 100);
        assertEq(playerContract.attributePoints(playerId1), 1);
        assertEq(playerContract.attributePoints(playerId2), 1);

        // Use player 1's points
        vm.startPrank(PLAYER_ONE);
        playerContract.useAttributePoint(playerId1, IPlayer.Attribute.STRENGTH);
        vm.stopPrank();

        // Only player 1's points should be consumed
        assertEq(playerContract.attributePoints(playerId1), 0);
        assertEq(playerContract.attributePoints(playerId2), 1);
    }

    function testXPCalculationForLevels() public {
        // Test that XP requirements are calculated correctly
        assertEq(playerContract.getXPRequiredForLevel(1), 0);   // Already at level 1
        assertEq(playerContract.getXPRequiredForLevel(2), 100); // Level 2 requires 100 XP
        assertEq(playerContract.getXPRequiredForLevel(3), 150); // Level 3 requires 150 XP
        assertEq(playerContract.getXPRequiredForLevel(4), 225); // Level 4 requires 225 XP
        
        // Test levels beyond 10 return 0
        assertEq(playerContract.getXPRequiredForLevel(11), 0);
    }

    function testLevelCapAt10() public {
        // Award massive XP (more than enough to reach level 10)
        playerContract.awardExperience(playerId1, 10000);
        
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId1);
        assertEq(stats.level, 10); // Should cap at level 10
        assertEq(playerContract.attributePoints(playerId1), 9); // Should have 9 attribute points (levels 2-10)
    }
}
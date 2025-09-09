// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {
    NotPlayerOwner,
    WeaponSpecializationLevelTooLow,
    ArmorSpecializationLevelTooLow
} from "../../src/fighters/Player.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {TestBase} from "../TestBase.sol";

contract PlayerSpecializationTest is TestBase {
    address public PLAYER_ONE;
    uint32 public playerId;

    event PlayerWeaponSpecializationChanged(uint32 indexed playerId, uint8 weaponType);
    event PlayerArmorSpecializationChanged(uint32 indexed playerId, uint8 armorType);

    function setUp() public override {
        super.setUp();

        PLAYER_ONE = address(0x1111);
        playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Set up permissions for this test contract to award experience
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: false, retire: false, immortal: false, experience: true});
        playerContract.setGameContractPermission(address(this), perms);
    }

    // Helper function to level up a player to specific level
    function levelUpPlayerTo(uint32 targetPlayerId, uint8 targetLevel) internal {
        // Get current player level
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(targetPlayerId);
        uint8 currentLevel = stats.level;

        // Award precise XP to reach exactly the target level
        // Level 2: 100 XP, Level 3: 250 XP, Level 4: 450 XP, Level 5: 700 XP, etc.
        while (currentLevel < targetLevel) {
            // Award small amounts and check level
            playerContract.awardExperience(targetPlayerId, 100);
            stats = playerContract.getPlayer(targetPlayerId);
            if (stats.level > currentLevel) {
                currentLevel = stats.level;
                if (currentLevel >= targetLevel) {
                    break;
                }
            }
        }
    }

    function testWeaponSpecializationFreeAtLevel10() public {
        // Level up player to level 10
        levelUpPlayerTo(playerId, 10);

        vm.startPrank(PLAYER_ONE);

        // Should be able to set weapon specialization for free (no tickets needed)
        vm.expectEmit(true, false, false, true);
        emit PlayerWeaponSpecializationChanged(playerId, 3);

        playerContract.setWeaponSpecialization(playerId, 3);

        // Verify specialization was set
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertEq(stats.weaponSpecialization, 3);

        vm.stopPrank();
    }

    function testWeaponSpecializationRequiresLevel10() public {
        // Player starts at level 1, should fail
        vm.expectRevert(WeaponSpecializationLevelTooLow.selector);
        vm.prank(PLAYER_ONE);
        playerContract.setWeaponSpecialization(playerId, 1);

        // Level up to 9, should still fail
        levelUpPlayerTo(playerId, 9);
        vm.expectRevert(WeaponSpecializationLevelTooLow.selector);
        vm.prank(PLAYER_ONE);
        playerContract.setWeaponSpecialization(playerId, 1);

        // Level up to 10, should succeed
        levelUpPlayerTo(playerId, 10);
        vm.prank(PLAYER_ONE);
        playerContract.setWeaponSpecialization(playerId, 1); // Should not revert
    }

    function testWeaponRespecRequiresTicket() public {
        PlayerTickets tickets = playerContract.playerTickets();

        // Level up to 10 and set initial specialization
        levelUpPlayerTo(playerId, 10);
        vm.prank(PLAYER_ONE);
        playerContract.setWeaponSpecialization(playerId, 1);

        // Try to change without ticket - should fail
        vm.expectRevert("Not authorized to burn");
        vm.prank(PLAYER_ONE);
        playerContract.setWeaponSpecialization(playerId, 2);

        // Mint a respec ticket and try again
        tickets.mintFungibleTicket(PLAYER_ONE, tickets.WEAPON_SPECIALIZATION_TICKET(), 1);

        vm.startPrank(PLAYER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        // Should succeed with ticket
        vm.expectEmit(true, false, false, true);
        emit PlayerWeaponSpecializationChanged(playerId, 2);

        playerContract.setWeaponSpecialization(playerId, 2);

        // Verify specialization changed
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertEq(stats.weaponSpecialization, 2);

        // Verify ticket was burned
        assertEq(tickets.balanceOf(PLAYER_ONE, tickets.WEAPON_SPECIALIZATION_TICKET()), 0);

        vm.stopPrank();
    }

    function testArmorSpecializationFreeAtLevel5() public {
        // Level up player to level 5
        levelUpPlayerTo(playerId, 5);

        vm.startPrank(PLAYER_ONE);

        // Should be able to set armor specialization for free (no tickets needed)
        vm.expectEmit(true, false, false, true);
        emit PlayerArmorSpecializationChanged(playerId, 1);

        playerContract.setArmorSpecialization(playerId, 1);

        // Verify specialization was set
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertEq(stats.armorSpecialization, 1);

        vm.stopPrank();
    }

    function testArmorSpecializationRequiresLevel5() public {
        // Player starts at level 1, should fail
        vm.expectRevert(ArmorSpecializationLevelTooLow.selector);
        vm.prank(PLAYER_ONE);
        playerContract.setArmorSpecialization(playerId, 1);

        // Level up to 4, should still fail
        levelUpPlayerTo(playerId, 4);
        vm.expectRevert(ArmorSpecializationLevelTooLow.selector);
        vm.prank(PLAYER_ONE);
        playerContract.setArmorSpecialization(playerId, 1);

        // Level up to 5, should succeed
        levelUpPlayerTo(playerId, 5);
        vm.prank(PLAYER_ONE);
        playerContract.setArmorSpecialization(playerId, 1); // Should not revert
    }

    function testArmorRespecRequiresTicket() public {
        PlayerTickets tickets = playerContract.playerTickets();

        // Level up to 5 and set initial specialization
        levelUpPlayerTo(playerId, 5);
        vm.prank(PLAYER_ONE);
        playerContract.setArmorSpecialization(playerId, 1);

        // Try to change without ticket - should fail
        vm.expectRevert("Not authorized to burn");
        vm.prank(PLAYER_ONE);
        playerContract.setArmorSpecialization(playerId, 2);

        // Mint a respec ticket and try again
        tickets.mintFungibleTicket(PLAYER_ONE, tickets.ARMOR_SPECIALIZATION_TICKET(), 1);

        vm.startPrank(PLAYER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        // Should succeed with ticket
        vm.expectEmit(true, false, false, true);
        emit PlayerArmorSpecializationChanged(playerId, 2);

        playerContract.setArmorSpecialization(playerId, 2);

        // Verify specialization changed
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertEq(stats.armorSpecialization, 2);

        // Verify ticket was burned
        assertEq(tickets.balanceOf(PLAYER_ONE, tickets.ARMOR_SPECIALIZATION_TICKET()), 0);

        vm.stopPrank();
    }

    function testCanSetAnyWeaponValue() public {
        PlayerTickets tickets = playerContract.playerTickets();

        levelUpPlayerTo(playerId, 10);

        // First change from 255 should be free - can use any uint8 value
        vm.prank(PLAYER_ONE);
        playerContract.setWeaponSpecialization(playerId, 7); // Should not revert

        // Subsequent changes need tickets
        tickets.mintFungibleTicket(PLAYER_ONE, tickets.WEAPON_SPECIALIZATION_TICKET(), 2);

        vm.startPrank(PLAYER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        // Should accept any uint8 value (even invalid ones like 100, etc.)
        playerContract.setWeaponSpecialization(playerId, 100); // Should not revert

        // 255 should be valid (no specialization)
        playerContract.setWeaponSpecialization(playerId, 255); // Should not revert

        vm.stopPrank();
    }

    function testCanSetAnyArmorValue() public {
        PlayerTickets tickets = playerContract.playerTickets();

        levelUpPlayerTo(playerId, 5);

        // First change from 255 should be free - can use any uint8 value
        vm.prank(PLAYER_ONE);
        playerContract.setArmorSpecialization(playerId, 50); // Should not revert

        // Subsequent changes need tickets
        tickets.mintFungibleTicket(PLAYER_ONE, tickets.ARMOR_SPECIALIZATION_TICKET(), 2);

        vm.startPrank(PLAYER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        // Should accept any uint8 value (armor has no validation in Player contract)
        playerContract.setArmorSpecialization(playerId, 200); // Should not revert

        // 255 should be valid (no specialization)
        playerContract.setArmorSpecialization(playerId, 255); // Should not revert

        vm.stopPrank();
    }

    function testCannotChangeSpecializationForNonOwnedPlayer() public {
        address PLAYER_TWO = address(0x2222);
        uint32 playerId2 = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

        // Level up both players
        levelUpPlayerTo(playerId, 10);
        levelUpPlayerTo(playerId2, 10);

        // Try to change PLAYER_TWO's specialization as PLAYER_ONE
        vm.expectRevert(NotPlayerOwner.selector);
        vm.prank(PLAYER_ONE);
        playerContract.setWeaponSpecialization(playerId2, 5);

        vm.expectRevert(NotPlayerOwner.selector);
        vm.prank(PLAYER_ONE);
        playerContract.setArmorSpecialization(playerId2, 3);
    }

    function testMultipleRespecs() public {
        PlayerTickets tickets = playerContract.playerTickets();

        // Test multiple weapon respecs
        levelUpPlayerTo(playerId, 10);

        // Initial free specialization
        vm.prank(PLAYER_ONE);
        playerContract.setWeaponSpecialization(playerId, 1);

        // Mint multiple tickets for multiple respecs
        tickets.mintFungibleTicket(PLAYER_ONE, tickets.WEAPON_SPECIALIZATION_TICKET(), 3);

        vm.startPrank(PLAYER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        // First respec
        playerContract.setWeaponSpecialization(playerId, 2);

        // Second respec
        playerContract.setWeaponSpecialization(playerId, 3);

        // Third respec back to none
        playerContract.setWeaponSpecialization(playerId, 255);

        // Verify final state
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertEq(stats.weaponSpecialization, 255);

        // Verify all tickets were consumed
        assertEq(tickets.balanceOf(PLAYER_ONE, tickets.WEAPON_SPECIALIZATION_TICKET()), 0);

        vm.stopPrank();
    }
}

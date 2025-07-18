// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test, stdError} from "forge-std/Test.sol";
import {Player, NotPlayerOwner} from "../../src/fighters/Player.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import "../TestBase.sol";

contract PlayerSpecializationTest is TestBase {
    address public PLAYER_ONE;
    uint32 public playerId;

    event PlayerWeaponSpecializationChanged(uint32 indexed playerId, uint8 weaponType);
    event PlayerArmorSpecializationChanged(uint32 indexed playerId, uint8 armorType);

    function setUp() public override {
        super.setUp();

        PLAYER_ONE = address(0x1111);
        playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
    }

    function testWeaponSpecializationChange() public {
        // Mint a weapon specialization ticket
        PlayerTickets tickets = playerContract.playerTickets();
        tickets.mintFungibleTicket(PLAYER_ONE, tickets.WEAPON_SPECIALIZATION_TICKET(), 1);

        // Verify ticket balance
        assertEq(tickets.balanceOf(PLAYER_ONE, tickets.WEAPON_SPECIALIZATION_TICKET()), 1);

        // Change weapon specialization
        vm.startPrank(PLAYER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);
        
        vm.expectEmit(true, false, false, true);
        emit PlayerWeaponSpecializationChanged(playerId, 5); // Some weapon type
        
        playerContract.setWeaponSpecialization(playerId, 5);
        vm.stopPrank();

        // Verify ticket was burned
        assertEq(tickets.balanceOf(PLAYER_ONE, tickets.WEAPON_SPECIALIZATION_TICKET()), 0);

        // Verify specialization was set
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertEq(stats.weaponSpecialization, 5);
    }

    function testArmorSpecializationChange() public {
        // Mint an armor specialization ticket
        PlayerTickets tickets = playerContract.playerTickets();
        tickets.mintFungibleTicket(PLAYER_ONE, tickets.ARMOR_SPECIALIZATION_TICKET(), 1);

        // Verify ticket balance
        assertEq(tickets.balanceOf(PLAYER_ONE, tickets.ARMOR_SPECIALIZATION_TICKET()), 1);

        // Change armor specialization
        vm.startPrank(PLAYER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);
        
        vm.expectEmit(true, false, false, true);
        emit PlayerArmorSpecializationChanged(playerId, 3); // Some armor type
        
        playerContract.setArmorSpecialization(playerId, 3);
        vm.stopPrank();

        // Verify ticket was burned
        assertEq(tickets.balanceOf(PLAYER_ONE, tickets.ARMOR_SPECIALIZATION_TICKET()), 0);

        // Verify specialization was set
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertEq(stats.armorSpecialization, 3);
    }

    function testCannotChangeSpecializationWithoutTicket() public {
        PlayerTickets tickets = playerContract.playerTickets();
        
        vm.startPrank(PLAYER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);
        
        // Should revert when no ticket available (ERC1155 burns will underflow)
        vm.expectRevert(stdError.arithmeticError);
        playerContract.setWeaponSpecialization(playerId, 5);
        
        vm.expectRevert(stdError.arithmeticError);
        playerContract.setArmorSpecialization(playerId, 3);
        
        vm.stopPrank();
    }

    function testCannotChangeSpecializationForNonOwnedPlayer() public {
        address PLAYER_TWO = address(0x2222);
        uint32 playerId2 = _createPlayerAndFulfillVRF(PLAYER_TWO, false);
        
        PlayerTickets tickets = playerContract.playerTickets();
        
        // Mint tickets to PLAYER_ONE
        tickets.mintFungibleTicket(PLAYER_ONE, tickets.WEAPON_SPECIALIZATION_TICKET(), 1);
        tickets.mintFungibleTicket(PLAYER_ONE, tickets.ARMOR_SPECIALIZATION_TICKET(), 1);

        // Try to change PLAYER_TWO's specialization using PLAYER_ONE's tickets
        vm.startPrank(PLAYER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);
        
        vm.expectRevert(NotPlayerOwner.selector);
        playerContract.setWeaponSpecialization(playerId2, 5);
        
        vm.expectRevert(NotPlayerOwner.selector);
        playerContract.setArmorSpecialization(playerId2, 3);
        
        vm.stopPrank();
    }
}
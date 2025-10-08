// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {InsufficientFeeAmount} from "../../src/fighters/Player.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {TestBase} from "../TestBase.sol";

contract PlayerDualCreationTest is TestBase {
    address public USER;

    event PlayerCreationRequested(uint256 indexed requestId, address indexed requester, bool paidWithTicket);

    function setUp() public override {
        super.setUp();
        USER = address(0x1337);
        vm.deal(USER, 100 ether);
    }

    function testCreatePlayerWithETH() public {
        uint256 fee = playerContract.createPlayerFeeAmount();

        vm.startPrank(USER);

        // Create player with ETH
        vm.expectEmit(true, true, false, true);
        emit PlayerCreationRequested(1, USER, false);

        uint256 requestId = playerContract.requestCreatePlayer{value: fee}(false);
        assertEq(requestId, 1);

        // Verify pending request exists
        assertEq(playerContract.getPendingRequest(USER), requestId);

        vm.stopPrank();
    }

    function testCreatePlayerWithTicket() public {
        PlayerTickets tickets = playerContract.playerTickets();

        // Grant permission to mint tickets
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: true,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: false
        });
        tickets.setGameContractPermission(address(this), perms);

        // Mint ticket to user
        tickets.mintFungibleTicket(USER, tickets.CREATE_PLAYER_TICKET(), 1);

        vm.startPrank(USER);

        // Approve Player contract to burn tickets
        tickets.setApprovalForAll(address(playerContract), true);

        // Create player with ticket
        vm.expectEmit(true, true, false, true);
        emit PlayerCreationRequested(1, USER, true);

        uint256 requestId = playerContract.requestCreatePlayerWithTicket(false);
        assertEq(requestId, 1);

        // Verify pending request exists
        assertEq(playerContract.getPendingRequest(USER), requestId);

        // Verify ticket was burned
        assertEq(tickets.balanceOf(USER, tickets.CREATE_PLAYER_TICKET()), 0);

        vm.stopPrank();
    }

    function testCannotCreatePlayerWithTicketWithoutTickets() public {
        vm.startPrank(USER);

        // Try to create player with ticket without having any tickets
        vm.expectRevert(); // Should revert with ERC1155 insufficient balance
        playerContract.requestCreatePlayerWithTicket(false);

        vm.stopPrank();
    }

    function testCannotCreatePlayerWithETHWithoutPayment() public {
        vm.startPrank(USER);

        // Try to create player with ETH without payment
        vm.expectRevert(InsufficientFeeAmount.selector);
        playerContract.requestCreatePlayer{value: 0}(false);

        vm.stopPrank();
    }

    function testCreatePlayerWithTicketFullWorkflow() public {
        PlayerTickets tickets = playerContract.playerTickets();

        // Grant permission to mint tickets
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: true,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: false
        });
        tickets.setGameContractPermission(address(this), perms);

        // Mint ticket to user
        tickets.mintFungibleTicket(USER, tickets.CREATE_PLAYER_TICKET(), 1);

        vm.startPrank(USER);
        tickets.setApprovalForAll(address(playerContract), true);
        vm.stopPrank();

        // Create player with ticket and fulfill VRF
        uint32 playerId = _createPlayerWithTicketAndFulfillVRF(USER, false);

        // Verify player was created
        assertGt(playerId, 0);
        assertEq(playerContract.getPlayerOwner(playerId), USER);

        // Verify ticket was burned
        assertEq(tickets.balanceOf(USER, tickets.CREATE_PLAYER_TICKET()), 0);

        // Verify player stats
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertTrue(stats.attributes.strength >= 3 && stats.attributes.strength <= 21);
        assertTrue(stats.attributes.constitution >= 3 && stats.attributes.constitution <= 21);
        assertTrue(stats.attributes.size >= 3 && stats.attributes.size <= 21);
        assertTrue(stats.attributes.agility >= 3 && stats.attributes.agility <= 21);
        assertTrue(stats.attributes.stamina >= 3 && stats.attributes.stamina <= 21);
        assertTrue(stats.attributes.luck >= 3 && stats.attributes.luck <= 21);

        // Verify total is 72
        uint256 total =
            uint256(stats.attributes.strength) + uint256(stats.attributes.constitution) + uint256(stats.attributes.size)
            + uint256(stats.attributes.agility) + uint256(stats.attributes.stamina) + uint256(stats.attributes.luck);
        assertEq(total, 72);
    }

    function testMixedCreationMethods() public {
        PlayerTickets tickets = playerContract.playerTickets();

        // Grant permission to mint tickets
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: true,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: false
        });
        tickets.setGameContractPermission(address(this), perms);

        // Mint ticket to user
        tickets.mintFungibleTicket(USER, tickets.CREATE_PLAYER_TICKET(), 1);

        vm.startPrank(USER);
        tickets.setApprovalForAll(address(playerContract), true);
        vm.stopPrank();

        // Create first player with ETH
        uint32 playerId1 = _createPlayerAndFulfillVRF(USER, false);

        // Create second player with ticket
        uint32 playerId2 = _createPlayerWithTicketAndFulfillVRF(USER, true);

        // Verify both players were created
        assertGt(playerId1, 0);
        assertGt(playerId2, 0);
        assertNotEq(playerId1, playerId2);

        // Verify both players belong to same user
        assertEq(playerContract.getPlayerOwner(playerId1), USER);
        assertEq(playerContract.getPlayerOwner(playerId2), USER);

        // Verify active player count
        assertEq(playerContract.getActivePlayerCount(USER), 2);

        // Verify ticket was burned for second player
        assertEq(tickets.balanceOf(USER, tickets.CREATE_PLAYER_TICKET()), 0);
    }

    // Helper function to create player with ticket and fulfill VRF
    function _createPlayerWithTicketAndFulfillVRF(address owner, bool useSetB) internal returns (uint32) {
        // Start recording logs BEFORE creating the request to capture VRF events
        vm.recordLogs();

        // Create the player request with ticket
        vm.prank(owner);
        uint256 requestId = playerContract.requestCreatePlayerWithTicket(useSetB);

        // Fulfill the VRF request using the standard helper pattern
        _fulfillVRFRequest(address(playerContract));

        // Extract player ID from logs
        return _getPlayerIdFromLogs(owner, requestId);
    }
}

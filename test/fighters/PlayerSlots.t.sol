// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Player, ValueMustBePositive, TooManyPlayers, InsufficientFeeAmount} from "../../src/fighters/Player.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";
import "../TestBase.sol";

contract PlayerSlotsTest is TestBase {
    address public USER_ONE;
    address public USER_TWO;

    event PlayerSlotsPurchased(address indexed user, uint8 totalSlots, bool paidWithTicket);

    function setUp() public override {
        super.setUp();

        USER_ONE = address(0x1111);
        USER_TWO = address(0x2222);

        vm.deal(USER_ONE, 100 ether);
        vm.deal(USER_TWO, 100 ether);
    }

    function testDefaultSlotCount() public view {
        assertEq(playerContract.getPlayerSlots(USER_ONE), 3);
        assertEq(playerContract.getPlayerSlots(USER_TWO), 3);
    }

    function testPurchaseSlotsWithETH() public {
        uint256 cost = playerContract.slotBatchCost();
        assertEq(cost, 0.001 ether);

        vm.startPrank(USER_ONE);
        vm.expectEmit(true, false, false, true);
        emit PlayerSlotsPurchased(USER_ONE, 4, false);

        playerContract.purchasePlayerSlots{value: cost}();
        vm.stopPrank();

        // Always adds exactly 1 slot
        assertEq(playerContract.getPlayerSlots(USER_ONE), 4);

        // Second purchase should cost the same (fixed cost)
        uint256 secondCost = playerContract.slotBatchCost();
        assertEq(secondCost, 0.001 ether); // Same fixed cost
    }

    function testPurchaseSlotsWithTickets() public {
        // Give user 1 ticket (exactly 1 transaction worth)
        PlayerTickets tickets = playerContract.playerTickets();

        // Grant permission to mint tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: true,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: false
        });
        tickets.setGameContractPermission(address(this), ticketPerms);

        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 1);

        // Purchase slots with tickets
        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        vm.expectEmit(true, false, false, true);
        emit PlayerSlotsPurchased(USER_ONE, 4, true); // paid with ticket

        playerContract.purchasePlayerSlotsWithTickets();
        vm.stopPrank();

        // Verify slots were added and ticket burned
        assertEq(playerContract.getPlayerSlots(USER_ONE), 4);
        assertEq(tickets.balanceOf(USER_ONE, tickets.PLAYER_SLOT_TICKET()), 0);
    }

    function testMultipleTicketPurchases() public {
        // Give user 3 tickets, but they must use them one at a time
        PlayerTickets tickets = playerContract.playerTickets();

        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: true,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: false
        });
        tickets.setGameContractPermission(address(this), ticketPerms);

        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 3);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        // First purchase
        playerContract.purchasePlayerSlotsWithTickets();
        assertEq(playerContract.getPlayerSlots(USER_ONE), 4);
        assertEq(tickets.balanceOf(USER_ONE, tickets.PLAYER_SLOT_TICKET()), 2);

        // Second purchase
        playerContract.purchasePlayerSlotsWithTickets();
        assertEq(playerContract.getPlayerSlots(USER_ONE), 5);
        assertEq(tickets.balanceOf(USER_ONE, tickets.PLAYER_SLOT_TICKET()), 1);

        // Third purchase
        playerContract.purchasePlayerSlotsWithTickets();
        assertEq(playerContract.getPlayerSlots(USER_ONE), 6);
        assertEq(tickets.balanceOf(USER_ONE, tickets.PLAYER_SLOT_TICKET()), 0);

        vm.stopPrank();
    }

    function testCannotPurchaseSlotsWithoutTickets() public {
        vm.startPrank(USER_ONE);

        // Try to purchase without tickets - should revert
        vm.expectRevert(); // ERC1155 insufficient balance
        playerContract.purchasePlayerSlotsWithTickets();

        vm.stopPrank();
    }

    function testInsufficientETHForSlots() public {
        vm.startPrank(USER_ONE);

        vm.expectRevert(InsufficientFeeAmount.selector);
        playerContract.purchasePlayerSlots{value: 0.0009 ether}(); // Too little (need 0.001 ether)

        vm.stopPrank();
    }

    function testIndependentSlotCounts() public {
        uint256 cost = playerContract.slotBatchCost();

        // USER_ONE buys slots
        vm.prank(USER_ONE);
        playerContract.purchasePlayerSlots{value: cost}();

        // USER_TWO still has default slots
        assertEq(playerContract.getPlayerSlots(USER_ONE), 4);
        assertEq(playerContract.getPlayerSlots(USER_TWO), 3);

        // USER_TWO can also buy slots
        vm.prank(USER_TWO);
        playerContract.purchasePlayerSlots{value: cost}();

        assertEq(playerContract.getPlayerSlots(USER_ONE), 4);
        assertEq(playerContract.getPlayerSlots(USER_TWO), 4);
    }

    function testMixedPurchasingMethods() public {
        PlayerTickets tickets = playerContract.playerTickets();
        uint256 cost = playerContract.slotBatchCost();

        // Setup tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: true,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: false
        });
        tickets.setGameContractPermission(address(this), ticketPerms);
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 2);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        // Mix ETH and ticket purchases
        playerContract.purchasePlayerSlots{value: cost}(); // ETH: 3->4
        playerContract.purchasePlayerSlotsWithTickets(); // Ticket: 4->5
        playerContract.purchasePlayerSlots{value: cost}(); // ETH: 5->6
        playerContract.purchasePlayerSlotsWithTickets(); // Ticket: 6->7

        vm.stopPrank();

        assertEq(playerContract.getPlayerSlots(USER_ONE), 7);
        assertEq(tickets.balanceOf(USER_ONE, tickets.PLAYER_SLOT_TICKET()), 0);
    }

    function testSlotCappingNearMax() public {
        // Get user close to max slots
        uint256 maxSlots = 100; // MAX_TOTAL_SLOTS
        uint256 currentSlots = playerContract.getPlayerSlots(USER_ONE); // 3
        uint256 slotsNeeded = maxSlots - currentSlots - 1; // Leave room for exactly 1 more

        // Give them enough tickets to get close to max
        PlayerTickets tickets = playerContract.playerTickets();
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: true,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: false
        });
        tickets.setGameContractPermission(address(this), ticketPerms);

        // Calculate how many tickets needed (each ticket = 1 slot)
        uint256 ticketsNeeded = slotsNeeded;
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), ticketsNeeded);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        // Buy slots to get close to max
        for (uint256 i = 0; i < ticketsNeeded; i++) {
            playerContract.purchasePlayerSlotsWithTickets();
        }

        // Should now have exactly 99 slots (1 slot away from max)
        assertEq(playerContract.getPlayerSlots(USER_ONE), 99);

        // One more purchase should work (brings to exactly 100)
        vm.stopPrank(); // Stop prank to mint more tickets
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 1);
        vm.startPrank(USER_ONE);
        playerContract.purchasePlayerSlotsWithTickets();
        assertEq(playerContract.getPlayerSlots(USER_ONE), 100);

        // Now at max - next purchase should fail
        vm.stopPrank(); // Stop prank to mint more tickets
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 1);
        vm.startPrank(USER_ONE);
        vm.expectRevert(TooManyPlayers.selector);
        playerContract.purchasePlayerSlotsWithTickets();

        vm.stopPrank();
    }

    function testStateConsistencyUnderRapidCalls() public {
        uint256 cost = playerContract.slotBatchCost();

        vm.startPrank(USER_ONE);

        // Multiple rapid purchases - each should add exactly 1 slot
        playerContract.purchasePlayerSlots{value: cost}();
        assertEq(playerContract.getPlayerSlots(USER_ONE), 4);

        playerContract.purchasePlayerSlots{value: cost}();
        assertEq(playerContract.getPlayerSlots(USER_ONE), 5);

        playerContract.purchasePlayerSlots{value: cost}();
        assertEq(playerContract.getPlayerSlots(USER_ONE), 6);

        vm.stopPrank();
    }
}

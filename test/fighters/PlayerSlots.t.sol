// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test, stdError} from "forge-std/Test.sol";
import {Player, TooManyPlayers, ValueMustBePositive, InsufficientFeeAmount} from "../../src/fighters/Player.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import "../TestBase.sol";

contract PlayerSlotsTest is TestBase {
    address public USER_ONE;
    address public USER_TWO;

    event PlayerSlotsPurchased(address indexed user, uint8 slotsAdded, uint8 totalSlots, uint256 amountPaid);

    function setUp() public override {
        super.setUp();

        USER_ONE = address(0x1111);
        USER_TWO = address(0x2222);
    }

    function testInitialSlotCount() public {
        // All users start with 5 base slots
        assertEq(playerContract.getPlayerSlots(USER_ONE), 5);
        assertEq(playerContract.getPlayerSlots(USER_TWO), 5);
    }

    function testPurchaseSlotsWithETH() public {
        // Check initial state
        assertEq(playerContract.getPlayerSlots(USER_ONE), 5);

        // Calculate cost for first slot batch
        uint256 cost = playerContract.getNextSlotBatchCost(USER_ONE);

        // Purchase slots with ETH
        vm.deal(USER_ONE, cost);
        vm.startPrank(USER_ONE);

        vm.expectEmit(true, false, false, true);
        emit PlayerSlotsPurchased(USER_ONE, 5, 5, cost);

        uint8 slotsAdded = playerContract.purchasePlayerSlots{value: cost}();
        vm.stopPrank();

        // Verify slots were added
        assertEq(slotsAdded, 5);
        assertEq(playerContract.getPlayerSlots(USER_ONE), 10);
    }

    function testPurchaseSlotsWithTickets() public {
        // Check initial state
        assertEq(playerContract.getPlayerSlots(USER_ONE), 5);

        // Mint player slot tickets
        PlayerTickets tickets = playerContract.playerTickets();
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 5);

        // Verify ticket balance
        assertEq(tickets.balanceOf(USER_ONE, tickets.PLAYER_SLOT_TICKET()), 5);

        // Purchase slots with tickets
        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        vm.expectEmit(true, false, false, true);
        emit PlayerSlotsPurchased(USER_ONE, 5, 10, 0); // 0 ETH paid

        uint8 slotsAdded = playerContract.purchasePlayerSlotsWithTickets(5);
        vm.stopPrank();

        // Verify slots were added and tickets burned
        assertEq(slotsAdded, 5);
        assertEq(playerContract.getPlayerSlots(USER_ONE), 10);
        assertEq(tickets.balanceOf(USER_ONE, tickets.PLAYER_SLOT_TICKET()), 0);
    }

    function testPurchasePartialSlotsWithTickets() public {
        // Mint 10 tickets but only use 3
        PlayerTickets tickets = playerContract.playerTickets();
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 10);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        uint8 slotsAdded = playerContract.purchasePlayerSlotsWithTickets(3);
        vm.stopPrank();

        // Verify only 3 slots added and 3 tickets burned
        assertEq(slotsAdded, 3);
        assertEq(playerContract.getPlayerSlots(USER_ONE), 8);
        assertEq(tickets.balanceOf(USER_ONE, tickets.PLAYER_SLOT_TICKET()), 7);
    }

    function testCannotPurchaseZeroSlotsWithTickets() public {
        PlayerTickets tickets = playerContract.playerTickets();
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 5);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        vm.expectRevert(ValueMustBePositive.selector);
        playerContract.purchasePlayerSlotsWithTickets(0);
        vm.stopPrank();
    }

    function testCannotPurchaseSlotsWithoutTickets() public {
        vm.startPrank(USER_ONE);
        playerContract.playerTickets().setApprovalForAll(address(playerContract), true);

        vm.expectRevert(stdError.arithmeticError);
        playerContract.purchasePlayerSlotsWithTickets(1);
        vm.stopPrank();
    }

    function testSlotPurchaseRespectsCap() public {
        // Get close to the max (200 slots)
        uint256 currentSlots = playerContract.getPlayerSlots(USER_ONE);
        uint8 slotsToMax = uint8(200 - currentSlots);

        // Mint enough tickets to exceed the cap
        PlayerTickets tickets = playerContract.playerTickets();
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), slotsToMax + 10);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        // Try to purchase more than the cap allows
        uint8 slotsAdded = playerContract.purchasePlayerSlotsWithTickets(slotsToMax + 10);
        vm.stopPrank();

        // Should only add slots up to the cap
        assertEq(slotsAdded, slotsToMax);
        assertEq(playerContract.getPlayerSlots(USER_ONE), 200);

        // Should have burned only the slots that were actually added
        assertEq(tickets.balanceOf(USER_ONE, tickets.PLAYER_SLOT_TICKET()), 10);
    }

    function testCannotPurchaseWhenAtMaxSlots() public {
        // First get to max slots by purchasing many batches with ETH
        while (playerContract.getPlayerSlots(USER_ONE) < 200) {
            uint256 cost = playerContract.getNextSlotBatchCost(USER_ONE);
            vm.deal(USER_ONE, cost);
            vm.startPrank(USER_ONE);
            playerContract.purchasePlayerSlots{value: cost}();
            vm.stopPrank();
        }

        // Now try to purchase more with tickets
        PlayerTickets tickets = playerContract.playerTickets();
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 5);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        vm.expectRevert(TooManyPlayers.selector);
        playerContract.purchasePlayerSlotsWithTickets(1);
        vm.stopPrank();
    }

    function testMixedPurchasingMethods() public {
        // Start with 5 slots
        assertEq(playerContract.getPlayerSlots(USER_ONE), 5);

        // Buy 5 slots with ETH
        uint256 cost = playerContract.getNextSlotBatchCost(USER_ONE);
        vm.deal(USER_ONE, cost);
        vm.startPrank(USER_ONE);
        playerContract.purchasePlayerSlots{value: cost}();
        vm.stopPrank();
        assertEq(playerContract.getPlayerSlots(USER_ONE), 10);

        // Buy 3 slots with tickets
        PlayerTickets tickets = playerContract.playerTickets();
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 3);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);
        playerContract.purchasePlayerSlotsWithTickets(3);
        vm.stopPrank();
        assertEq(playerContract.getPlayerSlots(USER_ONE), 13);

        // Buy more with ETH
        cost = playerContract.getNextSlotBatchCost(USER_ONE);
        vm.deal(USER_ONE, cost);
        vm.startPrank(USER_ONE);
        playerContract.purchasePlayerSlots{value: cost}();
        vm.stopPrank();
        assertEq(playerContract.getPlayerSlots(USER_ONE), 18);
    }

    function testSlotPurchaseEventEmission() public {
        PlayerTickets tickets = playerContract.playerTickets();
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 5);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        // Check event is emitted with correct parameters
        vm.expectEmit(true, false, false, true);
        emit PlayerSlotsPurchased(USER_ONE, 5, 10, 0); // 0 ETH paid when using tickets

        playerContract.purchasePlayerSlotsWithTickets(5);
        vm.stopPrank();
    }

    function testIndependentSlotCounts() public {
        // Each user has independent slot counts
        assertEq(playerContract.getPlayerSlots(USER_ONE), 5);
        assertEq(playerContract.getPlayerSlots(USER_TWO), 5);

        // Purchase slots for USER_ONE
        PlayerTickets tickets = playerContract.playerTickets();
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 3);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);
        playerContract.purchasePlayerSlotsWithTickets(3);
        vm.stopPrank();

        // Only USER_ONE's slots should have increased
        assertEq(playerContract.getPlayerSlots(USER_ONE), 8);
        assertEq(playerContract.getPlayerSlots(USER_TWO), 5);
    }
}

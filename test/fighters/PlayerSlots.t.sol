// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test, stdError} from "forge-std/Test.sol";
import {Player, ValueMustBePositive, TooManyPlayers, InsufficientFeeAmount} from "../../src/fighters/Player.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import "../TestBase.sol";

event PlayerSlotsPurchased(address indexed buyer, uint8 slotsAdded, uint8 newTotalSlots, uint256 ethPaid);

contract PlayerSlotsTest is TestBase {
    address public USER_ONE;
    address public USER_TWO;

    function setUp() public override {
        super.setUp();

        USER_ONE = address(0x1111);
        USER_TWO = address(0x2222);

        // Give users some ETH
        vm.deal(USER_ONE, 100 ether);
        vm.deal(USER_TWO, 100 ether);
    }

    function testDefaultSlotCount() public {
        // Default should be 5 slots
        assertEq(playerContract.getPlayerSlots(USER_ONE), 5);
        assertEq(playerContract.getPlayerSlots(address(this)), 5);
    }

    function testPurchaseSlotsWithETH() public {
        uint256 cost = playerContract.getNextSlotBatchCost(USER_ONE);
        assertEq(cost, 0.005 ether); // First batch cost (slotBatchCost * 1)

        vm.startPrank(USER_ONE);
        vm.expectEmit(true, false, false, true);
        emit PlayerSlotsPurchased(USER_ONE, 5, 10, 0.005 ether);

        uint8 slotsAdded = playerContract.purchasePlayerSlots{value: cost}();
        vm.stopPrank();

        assertEq(slotsAdded, 5);
        assertEq(playerContract.getPlayerSlots(USER_ONE), 10);

        // Second purchase should cost more
        uint256 secondCost = playerContract.getNextSlotBatchCost(USER_ONE);
        assertEq(secondCost, 0.010 ether); // Double the first cost (slotBatchCost * 2)
    }

    function testPurchaseSlotsWithTickets() public {
        // Give user 1 player slot ticket (each ticket = 5 slots)
        PlayerTickets tickets = playerContract.playerTickets();
        
        // Grant permission to mint tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: true,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false
        });
        tickets.setGameContractPermission(address(this), ticketPerms);
        
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 1);

        // Verify ticket balance
        assertEq(tickets.balanceOf(USER_ONE, tickets.PLAYER_SLOT_TICKET()), 1);

        // Purchase slots with tickets
        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        vm.expectEmit(true, false, false, true);
        emit PlayerSlotsPurchased(USER_ONE, 5, 10, 0); // 0 ETH paid

        uint8 slotsAdded = playerContract.purchasePlayerSlotsWithTickets(1);
        vm.stopPrank();

        // Verify slots were added and ticket burned
        assertEq(slotsAdded, 5);
        assertEq(playerContract.getPlayerSlots(USER_ONE), 10);
        assertEq(tickets.balanceOf(USER_ONE, tickets.PLAYER_SLOT_TICKET()), 0);
    }

    function testPurchaseMultipleTickets() public {
        // Give user 3 tickets (each ticket = 5 slots, so 15 slots total)
        PlayerTickets tickets = playerContract.playerTickets();
        
        // Grant permission to mint tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: true,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false
        });
        tickets.setGameContractPermission(address(this), ticketPerms);
        
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 3);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        uint8 slotsAdded = playerContract.purchasePlayerSlotsWithTickets(3);
        vm.stopPrank();

        // Verify 15 slots added and 3 tickets burned
        assertEq(slotsAdded, 15);
        assertEq(playerContract.getPlayerSlots(USER_ONE), 20);
        assertEq(tickets.balanceOf(USER_ONE, tickets.PLAYER_SLOT_TICKET()), 0);
    }

    function testCannotPurchaseZeroTickets() public {
        PlayerTickets tickets = playerContract.playerTickets();

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
        PlayerTickets tickets = playerContract.playerTickets();
        
        // Grant permission to mint tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: true,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false
        });
        tickets.setGameContractPermission(address(this), ticketPerms);
        
        // Need 39 tickets to get from 5 to 200 slots (39 * 5 = 195 slots)
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 39);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        // Purchase all 39 tickets worth
        uint8 slotsAdded = playerContract.purchasePlayerSlotsWithTickets(39);
        vm.stopPrank();

        // Should add 195 slots (39 * 5)
        assertEq(slotsAdded, 195);
        assertEq(playerContract.getPlayerSlots(USER_ONE), 200);
    }

    function testInsufficientETHForSlots() public {
        uint256 cost = playerContract.getNextSlotBatchCost(USER_ONE);

        vm.startPrank(USER_ONE);
        vm.expectRevert(InsufficientFeeAmount.selector);
        playerContract.purchasePlayerSlots{value: cost - 1 wei}();
        vm.stopPrank();
    }

    function testCannotExceedMaxSlots() public {
        // Max USER_ONE out at 200 slots
        PlayerTickets tickets = playerContract.playerTickets();
        
        // Grant permission to mint tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: true,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false
        });
        tickets.setGameContractPermission(address(this), ticketPerms);
        
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 39);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);
        playerContract.purchasePlayerSlotsWithTickets(39);

        // Try to purchase more
        vm.expectRevert(TooManyPlayers.selector);
        playerContract.purchasePlayerSlots{value: 1 ether}();
        vm.stopPrank();
    }

    function testMixedPurchasingMethods() public {
        // Start with 5 slots
        assertEq(playerContract.getPlayerSlots(USER_ONE), 5);

        // Buy with ETH first
        uint256 cost = playerContract.getNextSlotBatchCost(USER_ONE);
        vm.startPrank(USER_ONE);
        playerContract.purchasePlayerSlots{value: cost}();
        vm.stopPrank();
        assertEq(playerContract.getPlayerSlots(USER_ONE), 10);

        // Buy with tickets (1 ticket = 5 slots)
        PlayerTickets tickets = playerContract.playerTickets();
        
        // Grant permission to mint tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: true,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false
        });
        tickets.setGameContractPermission(address(this), ticketPerms);
        
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 1);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);
        playerContract.purchasePlayerSlotsWithTickets(1);
        vm.stopPrank();
        assertEq(playerContract.getPlayerSlots(USER_ONE), 15);

        // Buy more with ETH
        cost = playerContract.getNextSlotBatchCost(USER_ONE);
        vm.startPrank(USER_ONE);
        playerContract.purchasePlayerSlots{value: cost}();
        vm.stopPrank();
        assertEq(playerContract.getPlayerSlots(USER_ONE), 20);
    }

    function testTicketEventParameters() public {
        // Give user 1 player slot ticket
        PlayerTickets tickets = playerContract.playerTickets();
        
        // Grant permission to mint tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: true,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false
        });
        tickets.setGameContractPermission(address(this), ticketPerms);
        
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 1);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);

        // Check event is emitted with correct parameters
        vm.expectEmit(true, false, false, true);
        emit PlayerSlotsPurchased(USER_ONE, 5, 10, 0); // 0 ETH paid when using tickets

        playerContract.purchasePlayerSlotsWithTickets(1);
        vm.stopPrank();
    }

    function testIndependentSlotCounts() public {
        // Each user has independent slot counts
        assertEq(playerContract.getPlayerSlots(USER_ONE), 5);
        assertEq(playerContract.getPlayerSlots(USER_TWO), 5);

        // Purchase slots for USER_ONE (1 ticket = 5 slots)
        PlayerTickets tickets = playerContract.playerTickets();
        
        // Grant permission to mint tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: true,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false
        });
        tickets.setGameContractPermission(address(this), ticketPerms);
        
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 1);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);
        playerContract.purchasePlayerSlotsWithTickets(1);
        vm.stopPrank();

        // Only USER_ONE's slots should have increased by 5
        assertEq(playerContract.getPlayerSlots(USER_ONE), 10);
        assertEq(playerContract.getPlayerSlots(USER_TWO), 5);
    }

    function testSlotCappingWithTickets() public {
        // Get user to 195 slots (39 tickets * 5 slots each)
        PlayerTickets tickets = playerContract.playerTickets();
        
        // Grant permission to mint tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: true,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false
        });
        tickets.setGameContractPermission(address(this), ticketPerms);
        
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 39);

        vm.startPrank(USER_ONE);
        tickets.setApprovalForAll(address(playerContract), true);
        playerContract.purchasePlayerSlotsWithTickets(39);
        
        // Now at 200 slots, try to add 2 more tickets (would be 10 slots)
        vm.stopPrank();
        tickets.mintFungibleTicket(USER_ONE, tickets.PLAYER_SLOT_TICKET(), 2);
        vm.startPrank(USER_ONE);
        
        // Should fail as we're already at max
        vm.expectRevert(TooManyPlayers.selector);
        playerContract.purchasePlayerSlotsWithTickets(1);
        vm.stopPrank();
    }
}
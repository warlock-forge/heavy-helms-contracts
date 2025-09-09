// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {NotPlayerOwner, InvalidAttributeSwap} from "../../src/fighters/Player.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {PlayerTickets, TokenNotTransferable} from "../../src/nft/PlayerTickets.sol";
import {TestBase} from "../TestBase.sol";

contract PlayerAttributeSwapsTest is TestBase {
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

        // Grant PlayerTickets permission to mint attribute swap tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: true
        });
        playerTickets.setGameContractPermission(address(this), ticketPerms);

        // Award attribute swap ticket by minting NFT
        playerTickets.mintFungibleTicket(PLAYER_ONE, playerTickets.ATTRIBUTE_SWAP_TICKET(), 1);

        // Verify PLAYER_ONE has the ticket
        assertEq(
            playerTickets.balanceOf(PLAYER_ONE, playerTickets.ATTRIBUTE_SWAP_TICKET()),
            1,
            "Should have 1 attribute swap ticket"
        );

        // PLAYER_ONE needs to approve Player contract to burn their tickets
        vm.startPrank(PLAYER_ONE);
        playerTickets.setApprovalForAll(address(playerContract), true);
        vm.stopPrank();

        // Store initial stats and find valid attributes to swap
        IPlayer.PlayerStats memory initialStats = playerContract.getPlayer(playerId);

        // Find a stat > MIN_STAT to decrease and a stat < MAX_STAT to increase
        IPlayer.Attribute decreaseAttr = IPlayer.Attribute.STRENGTH;
        IPlayer.Attribute increaseAttr = IPlayer.Attribute.AGILITY;
        uint8 decreaseVal = initialStats.attributes.strength;
        uint8 increaseVal = initialStats.attributes.agility;

        require(decreaseVal > 3 && increaseVal < 21, "Could not find valid stats to swap");

        // Perform swap (this should use the charge)
        vm.startPrank(PLAYER_ONE);
        playerContract.swapAttributes(playerId, decreaseAttr, increaseAttr);
        vm.stopPrank();

        // Verify stats were modified correctly (-1/+1)
        IPlayer.PlayerStats memory newStats = playerContract.getPlayer(playerId);
        assertEq(newStats.attributes.strength, decreaseVal - 1, "Strength should decrease by 1");
        assertEq(newStats.attributes.agility, increaseVal + 1, "Agility should increase by 1");

        // Verify ticket was burned
        assertEq(
            playerTickets.balanceOf(PLAYER_ONE, playerTickets.ATTRIBUTE_SWAP_TICKET()), 0, "Ticket should be burned"
        );
    }

    function testCannotSwapWithoutCharge() public {
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Try to swap without having any tickets - should revert when trying to burn
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert("Not authorized to burn");
        playerContract.swapAttributes(playerId, IPlayer.Attribute.STRENGTH, IPlayer.Attribute.AGILITY);
        vm.stopPrank();
    }

    function testCannotSwapForNonOwnedPlayer() public {
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant permission and award ticket to PLAYER_TWO
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: true
        });
        playerTickets.setGameContractPermission(address(this), ticketPerms);
        playerTickets.mintFungibleTicket(PLAYER_TWO, playerTickets.ATTRIBUTE_SWAP_TICKET(), 1);

        // PLAYER_TWO needs to approve Player contract to burn their tickets
        vm.startPrank(PLAYER_TWO);
        playerTickets.setApprovalForAll(address(playerContract), true);
        vm.stopPrank();

        // PLAYER_TWO has ticket but doesn't own the player
        vm.startPrank(PLAYER_TWO);
        vm.expectRevert(NotPlayerOwner.selector);
        playerContract.swapAttributes(playerId, IPlayer.Attribute.STRENGTH, IPlayer.Attribute.AGILITY);
        vm.stopPrank();
    }

    function testInvalidAttributeSwap() public {
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant permission and award ticket
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: true
        });
        playerTickets.setGameContractPermission(address(this), ticketPerms);
        playerTickets.mintFungibleTicket(PLAYER_ONE, playerTickets.ATTRIBUTE_SWAP_TICKET(), 1);

        // PLAYER_ONE needs to approve Player contract to burn their tickets
        vm.startPrank(PLAYER_ONE);
        playerTickets.setApprovalForAll(address(playerContract), true);
        vm.stopPrank();

        // Try to swap same attribute
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(InvalidAttributeSwap.selector);
        playerContract.swapAttributes(playerId, IPlayer.Attribute.STRENGTH, IPlayer.Attribute.STRENGTH);
        vm.stopPrank();
    }

    function testCannotMintTicketsToZeroAddress() public {
        // Grant permission
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: true
        });
        playerTickets.setGameContractPermission(address(this), ticketPerms);

        // Try to mint attribute swap ticket to zero address - should revert with specific error
        uint256 ticketId = playerTickets.ATTRIBUTE_SWAP_TICKET();
        vm.expectRevert(); // Solady ERC1155 throws TransferToZeroAddress()
        playerTickets.mintFungibleTicket(address(0), ticketId, 1);
    }

    function testMultipleAttributeSwaps() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant permission
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: true
        });
        playerTickets.setGameContractPermission(address(this), ticketPerms);

        // Award multiple tickets
        playerTickets.mintFungibleTicket(PLAYER_ONE, playerTickets.ATTRIBUTE_SWAP_TICKET(), 2);

        // PLAYER_ONE needs to approve Player contract to burn their tickets
        vm.startPrank(PLAYER_ONE);
        playerTickets.setApprovalForAll(address(playerContract), true);
        vm.stopPrank();

        // Get initial stats to find valid attributes to swap
        IPlayer.PlayerStats memory initialStats = playerContract.getPlayer(playerId);
        require(
            initialStats.attributes.strength > 4 && initialStats.attributes.agility < 20,
            "Could not find valid stats to swap twice"
        );

        // Use first ticket
        vm.startPrank(PLAYER_ONE);
        playerContract.swapAttributes(playerId, IPlayer.Attribute.STRENGTH, IPlayer.Attribute.AGILITY);

        // Use second ticket
        playerContract.swapAttributes(playerId, IPlayer.Attribute.STRENGTH, IPlayer.Attribute.AGILITY);
        vm.stopPrank();

        // Verify stats were modified correctly (-2/+2)
        IPlayer.PlayerStats memory newStats = playerContract.getPlayer(playerId);
        assertEq(newStats.attributes.strength, initialStats.attributes.strength - 2, "Strength should decrease by 2");
        assertEq(newStats.attributes.agility, initialStats.attributes.agility + 2, "Agility should increase by 2");

        // Verify all tickets were used
        assertEq(
            playerTickets.balanceOf(PLAYER_ONE, playerTickets.ATTRIBUTE_SWAP_TICKET()), 0, "All tickets should be used"
        );
    }

    function testAttributeSwapTokensAreSoulbound() public {
        // Grant permission to mint attribute swap tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: true
        });
        playerTickets.setGameContractPermission(address(this), ticketPerms);

        // Mint attribute swap ticket to PLAYER_ONE
        uint256 ticketId = playerTickets.ATTRIBUTE_SWAP_TICKET();
        playerTickets.mintFungibleTicket(PLAYER_ONE, ticketId, 2);

        // Verify PLAYER_ONE has the tickets
        assertEq(playerTickets.balanceOf(PLAYER_ONE, ticketId), 2, "Should have 2 attribute swap tickets");
        assertEq(playerTickets.balanceOf(PLAYER_TWO, ticketId), 0, "PLAYER_TWO should have 0 tickets");

        // Try to transfer single ticket - should revert with TokenNotTransferable
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(TokenNotTransferable.selector);
        playerTickets.safeTransferFrom(PLAYER_ONE, PLAYER_TWO, ticketId, 1, "");
        vm.stopPrank();

        // Verify no transfer occurred
        assertEq(playerTickets.balanceOf(PLAYER_ONE, ticketId), 2, "PLAYER_ONE should still have 2 tickets");
        assertEq(playerTickets.balanceOf(PLAYER_TWO, ticketId), 0, "PLAYER_TWO should still have 0 tickets");
    }

    function testAttributeSwapTokensBatchTransferBlocked() public {
        // Grant permission to mint attribute swap tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: true
        });
        playerTickets.setGameContractPermission(address(this), ticketPerms);

        // Mint attribute swap tickets to PLAYER_ONE
        playerTickets.mintFungibleTicket(PLAYER_ONE, playerTickets.ATTRIBUTE_SWAP_TICKET(), 2);

        // Try to batch transfer tickets - should revert with TokenNotTransferable
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = playerTickets.ATTRIBUTE_SWAP_TICKET();
        amounts[0] = 2;

        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(TokenNotTransferable.selector);
        playerTickets.safeBatchTransferFrom(PLAYER_ONE, PLAYER_TWO, ids, amounts, "");
        vm.stopPrank();

        // Verify no transfer occurred
        assertEq(
            playerTickets.balanceOf(PLAYER_ONE, playerTickets.ATTRIBUTE_SWAP_TICKET()),
            2,
            "PLAYER_ONE should still have 2 tickets"
        );
        assertEq(
            playerTickets.balanceOf(PLAYER_TWO, playerTickets.ATTRIBUTE_SWAP_TICKET()),
            0,
            "PLAYER_TWO should still have 0 tickets"
        );
    }

    function testNonSoulboundTokensCanStillTransfer() public {
        // Grant permissions for both attribute swaps and weapon specialization
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: true,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: true
        });
        playerTickets.setGameContractPermission(address(this), ticketPerms);

        // Cache ticket IDs to avoid calling functions in expectRevert block
        uint256 soulboundTicketId = playerTickets.ATTRIBUTE_SWAP_TICKET();
        uint256 transferableTicketId = playerTickets.WEAPON_SPECIALIZATION_TICKET();

        // Mint both soulbound and transferable tickets to PLAYER_ONE
        playerTickets.mintFungibleTicket(PLAYER_ONE, soulboundTicketId, 1); // Soulbound
        playerTickets.mintFungibleTicket(PLAYER_ONE, transferableTicketId, 1); // Transferable

        // Verify initial balances
        assertEq(playerTickets.balanceOf(PLAYER_ONE, soulboundTicketId), 1, "Should have 1 attribute swap ticket");
        assertEq(playerTickets.balanceOf(PLAYER_ONE, transferableTicketId), 1, "Should have 1 weapon spec ticket");
        assertEq(
            playerTickets.balanceOf(PLAYER_TWO, transferableTicketId), 0, "PLAYER_TWO should have 0 weapon spec tickets"
        );

        // Try to transfer soulbound token - should fail
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(TokenNotTransferable.selector);
        playerTickets.safeTransferFrom(PLAYER_ONE, PLAYER_TWO, soulboundTicketId, 1, "");
        vm.stopPrank();

        // Transfer non-soulbound token - should succeed
        vm.startPrank(PLAYER_ONE);
        playerTickets.safeTransferFrom(PLAYER_ONE, PLAYER_TWO, transferableTicketId, 1, "");
        vm.stopPrank();

        // Verify final balances
        assertEq(
            playerTickets.balanceOf(PLAYER_ONE, soulboundTicketId),
            1,
            "PLAYER_ONE should still have attribute swap ticket"
        );
        assertEq(
            playerTickets.balanceOf(PLAYER_ONE, transferableTicketId),
            0,
            "PLAYER_ONE should have no weapon spec tickets"
        );
        assertEq(
            playerTickets.balanceOf(PLAYER_TWO, transferableTicketId), 1, "PLAYER_TWO should have 1 weapon spec ticket"
        );
    }

    function testMixedBatchTransferWithSoulboundTokens() public {
        // Grant permissions for multiple ticket types
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: true,
            armorSpecialization: true,
            duels: false,
            dailyResets: false,
            attributeSwaps: true
        });
        playerTickets.setGameContractPermission(address(this), ticketPerms);

        // Mint mixed tickets to PLAYER_ONE
        playerTickets.mintFungibleTicket(PLAYER_ONE, playerTickets.WEAPON_SPECIALIZATION_TICKET(), 1); // Transferable
        playerTickets.mintFungibleTicket(PLAYER_ONE, playerTickets.ATTRIBUTE_SWAP_TICKET(), 1); // Soulbound
        playerTickets.mintFungibleTicket(PLAYER_ONE, playerTickets.ARMOR_SPECIALIZATION_TICKET(), 1); // Transferable

        // Try to batch transfer including soulbound token - should fail
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = playerTickets.WEAPON_SPECIALIZATION_TICKET();
        ids[1] = playerTickets.ATTRIBUTE_SWAP_TICKET(); // This will cause revert
        ids[2] = playerTickets.ARMOR_SPECIALIZATION_TICKET();
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;

        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(TokenNotTransferable.selector);
        playerTickets.safeBatchTransferFrom(PLAYER_ONE, PLAYER_TWO, ids, amounts, "");
        vm.stopPrank();

        // Verify no transfers occurred (batch should be atomic)
        assertEq(
            playerTickets.balanceOf(PLAYER_ONE, playerTickets.WEAPON_SPECIALIZATION_TICKET()),
            1,
            "No weapon spec transfer"
        );
        assertEq(
            playerTickets.balanceOf(PLAYER_ONE, playerTickets.ARMOR_SPECIALIZATION_TICKET()),
            1,
            "No armor spec transfer"
        );
        assertEq(
            playerTickets.balanceOf(PLAYER_TWO, playerTickets.WEAPON_SPECIALIZATION_TICKET()),
            0,
            "PLAYER_TWO has no tokens"
        );
        assertEq(
            playerTickets.balanceOf(PLAYER_TWO, playerTickets.ARMOR_SPECIALIZATION_TICKET()),
            0,
            "PLAYER_TWO has no tokens"
        );
    }
}

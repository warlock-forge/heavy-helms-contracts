// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {PlayerTickets, NotAuthorizedToMint, ZeroAddress, TokenNotTransferable} from "../../src/nft/PlayerTickets.sol";
import {PlayerNameRegistry} from "../../src/fighters/registries/names/PlayerNameRegistry.sol";
import {IPlayerNameRegistry} from "../../src/interfaces/fighters/registries/names/IPlayerNameRegistry.sol";
import {NameLibrary} from "../../src/fighters/registries/names/lib/NameLibrary.sol";
import {Base64} from "solady/utils/Base64.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts@4.9.6/token/ERC1155/IERC1155Receiver.sol";

contract PlayerTicketsTest is Test, IERC1155Receiver {
    PlayerTickets public tickets;
    PlayerNameRegistry public nameRegistry;

    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public gameContract = address(0x100);

    event NameChangeNFTMinted(uint256 indexed tokenId, address indexed to, uint16 firstNameIndex, uint16 surnameIndex);

    function setUp() public {
        // Deploy name registry and populate with real names
        nameRegistry = new PlayerNameRegistry();
        nameRegistry.addNamesToSetA(NameLibrary.getInitialNameSetA());
        nameRegistry.addNamesToSetB(NameLibrary.getInitialNameSetB());
        nameRegistry.addSurnames(NameLibrary.getInitialSurnames());

        // Deploy PlayerTickets with name registry
        tickets = new PlayerTickets(
            address(nameRegistry),
            "bafybeib2pydnkibnj5o3udxg2grmh4dt2tztcecccka4rxia5xumqpemjm", // Fungible metadata CID
            "bafybeibgu5ach7brer6jcjqcgtacxn2ltmgxwencxmcmlf3jt5mmwhxrje" // Name change image CID
        );

        // Set up game contract permissions for name changes
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: true,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: false
        });
        tickets.setGameContractPermission(gameContract, perms);
    }

    function testMintNameChangeNFT() public {
        vm.startPrank(gameContract);

        uint256 seed = 12345;
        uint256 tokenId = tickets.mintNameChangeNFT(user1, seed);

        assertEq(tokenId, 100);
        assertEq(tickets.balanceOf(user1, tokenId), 1);
        assertEq(tickets.nextNameChangeTokenId(), 101);

        // Verify the minted name data exists and is valid
        (uint16 firstNameIndex, uint16 surnameIndex) = tickets.getNameChangeData(tokenId);
        assertTrue(nameRegistry.isValidFirstNameIndex(firstNameIndex));
        assertTrue(surnameIndex < nameRegistry.getSurnamesLength());

        vm.stopPrank();
    }

    function testGetNameChangeData() public {
        vm.prank(gameContract);
        uint256 tokenId = tickets.mintNameChangeNFT(user1, 99999); // Some seed

        (uint16 firstNameIndex, uint16 surnameIndex) = tickets.getNameChangeData(tokenId);
        assertTrue(nameRegistry.isValidFirstNameIndex(firstNameIndex));
        assertTrue(surnameIndex < nameRegistry.getSurnamesLength());
    }

    function testNameChangeNFTsHaveUniqueTokenIds() public {
        vm.startPrank(gameContract);

        uint256 tokenId1 = tickets.mintNameChangeNFT(user1, 111);
        uint256 tokenId2 = tickets.mintNameChangeNFT(user2, 222);
        uint256 tokenId3 = tickets.mintNameChangeNFT(user1, 333);

        assertEq(tokenId1, 100);
        assertEq(tokenId2, 101);
        assertEq(tokenId3, 102);

        assertEq(tickets.balanceOf(user1, tokenId1), 1);
        assertEq(tickets.balanceOf(user2, tokenId2), 1);
        assertEq(tickets.balanceOf(user1, tokenId3), 1);

        vm.stopPrank();
    }

    function testDynamicURIGeneration() public {
        vm.prank(gameContract);
        uint256 tokenId = tickets.mintNameChangeNFT(user1, 7777);

        string memory uri = tickets.uri(tokenId);

        // Should start with data:application/json;base64,
        assertTrue(bytes(uri).length > 0);
        assertEq(bytes(uri)[0], "d"); // "data" prefix

        // Verify name data was stored
        (uint16 firstNameIndex, uint16 surnameIndex) = tickets.getNameChangeData(tokenId);
        assertTrue(firstNameIndex > 0 || surnameIndex > 0, "Name data should be set");
    }

    function testInitialSupplyMinted() public view {
        // Verify initial supply was minted to deployer
        assertEq(tickets.balanceOf(owner, tickets.CREATE_PLAYER_TICKET()), 1000);
        assertEq(tickets.balanceOf(owner, tickets.PLAYER_SLOT_TICKET()), 1000);
        assertEq(tickets.balanceOf(owner, tickets.DAILY_RESET_TICKET()), 1000);

        // Verify other tickets were NOT minted initially
        assertEq(tickets.balanceOf(owner, tickets.WEAPON_SPECIALIZATION_TICKET()), 0);
        assertEq(tickets.balanceOf(owner, tickets.ARMOR_SPECIALIZATION_TICKET()), 0);
        assertEq(tickets.balanceOf(owner, tickets.DUEL_TICKET()), 0);
        assertEq(tickets.balanceOf(owner, tickets.ATTRIBUTE_SWAP_TICKET()), 0);
    }

    function testFungibleTicketURIs() public view {
        // Test all 5 fungible ticket URIs are IPFS links
        string memory uri1 = tickets.uri(tickets.CREATE_PLAYER_TICKET());
        string memory uri2 = tickets.uri(tickets.PLAYER_SLOT_TICKET());
        string memory uri3 = tickets.uri(tickets.WEAPON_SPECIALIZATION_TICKET());
        string memory uri4 = tickets.uri(tickets.ARMOR_SPECIALIZATION_TICKET());
        string memory uri5 = tickets.uri(tickets.DUEL_TICKET());

        // All should be non-empty
        assertTrue(bytes(uri1).length > 0);
        assertTrue(bytes(uri2).length > 0);
        assertTrue(bytes(uri3).length > 0);
        assertTrue(bytes(uri4).length > 0);
        assertTrue(bytes(uri5).length > 0);

        // Verify they're IPFS URIs
        assertTrue(_startsWith(uri1, "ipfs://"));
        assertTrue(_startsWith(uri2, "ipfs://"));
        assertTrue(_startsWith(uri3, "ipfs://"));
        assertTrue(_startsWith(uri4, "ipfs://"));
        assertTrue(_startsWith(uri5, "ipfs://"));
    }

    function _startsWith(string memory str, string memory prefix) private pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);

        if (strBytes.length < prefixBytes.length) return false;

        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) return false;
        }
        return true;
    }

    function testBurnNameChangeNFT() public {
        vm.prank(gameContract);
        uint256 tokenId = tickets.mintNameChangeNFT(user1, 8888);

        assertEq(tickets.balanceOf(user1, tokenId), 1);

        vm.prank(user1);
        tickets.burnFrom(user1, tokenId, 1);

        assertEq(tickets.balanceOf(user1, tokenId), 0);
    }

    function testRevertWhen_InvalidNameData() public {
        vm.expectRevert("TokenDoesNotExist()");
        tickets.getNameChangeData(999); // Non-existent token
    }

    function testRevertWhen_InvalidTokenIdURI() public {
        vm.expectRevert("TokenDoesNotExist()");
        tickets.uri(999); // Non-existent name change NFT
    }

    function testRevertWhen_UnauthorizedMint() public {
        vm.expectRevert("NotAuthorizedToMint()");
        vm.prank(user1);
        tickets.mintNameChangeNFT(user1, 1234);
    }

    function testMultipleNamesInURI() public {
        vm.startPrank(gameContract);

        // Test with different seeds
        uint256 tokenId1 = tickets.mintNameChangeNFT(user1, 1001);
        uint256 tokenId2 = tickets.mintNameChangeNFT(user1, 2002);
        uint256 tokenId3 = tickets.mintNameChangeNFT(user1, 3003);
        uint256 tokenId4 = tickets.mintNameChangeNFT(user1, 4004);

        string memory uri1 = tickets.uri(tokenId1);
        string memory uri2 = tickets.uri(tokenId2);
        string memory uri3 = tickets.uri(tokenId3);
        string memory uri4 = tickets.uri(tokenId4);

        // Each URI should be different (with high probability)
        // There's a tiny chance of collision but extremely unlikely
        uint256 uniqueCount = 1;
        if (keccak256(bytes(uri1)) != keccak256(bytes(uri2))) uniqueCount++;
        if (keccak256(bytes(uri1)) != keccak256(bytes(uri3)) && keccak256(bytes(uri2)) != keccak256(bytes(uri3))) {
            uniqueCount++;
        }
        if (
            keccak256(bytes(uri1)) != keccak256(bytes(uri4)) && keccak256(bytes(uri2)) != keccak256(bytes(uri4))
                && keccak256(bytes(uri3)) != keccak256(bytes(uri4))
        ) uniqueCount++;

        // At least 3 out of 4 should be unique
        assertTrue(uniqueCount >= 3, "Random generation should produce mostly unique names");

        vm.stopPrank();
    }

    function testGamePermissions() public view {
        PlayerTickets.GamePermissions memory perms = tickets.gameContractPermissions(gameContract);
        assertTrue(perms.nameChanges);
        assertFalse(perms.playerCreation);
        assertFalse(perms.playerSlots);
    }

    function testOwnerCannotMintWithoutPermissions() public {
        // Owner should NOT be able to mint without explicit permissions
        // This ensures a more secure permission model
        vm.expectRevert(NotAuthorizedToMint.selector);
        tickets.mintNameChangeNFT(user1, 5555);
    }

    function testSameSeedDifferentBlockchainState() public {
        vm.startPrank(gameContract);

        // Test that same seed with different blockchain conditions produces different results
        uint256 seed = 12345;

        // First mint
        uint256 tokenId1 = tickets.mintNameChangeNFT(user1, seed);
        (uint16 firstName1, uint16 surname1) = tickets.getNameChangeData(tokenId1);

        // Advance block to change blockchain conditions
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        // Second mint with same seed
        uint256 tokenId2 = tickets.mintNameChangeNFT(user1, seed);
        (uint16 firstName2, uint16 surname2) = tickets.getNameChangeData(tokenId2);

        // Should produce different names despite same seed
        assertTrue(
            firstName1 != firstName2 || surname1 != surname2,
            "Same seed should produce different names with different blockchain state"
        );

        // Verify names are valid
        assertTrue(nameRegistry.isValidFirstNameIndex(firstName1));
        assertTrue(nameRegistry.isValidFirstNameIndex(firstName2));
        assertTrue(surname1 < nameRegistry.getSurnamesLength());
        assertTrue(surname2 < nameRegistry.getSurnamesLength());

        vm.stopPrank();
    }

    function testFuzz_RandomNameDistribution(uint256 seed) public {
        vm.prank(gameContract);
        uint256 tokenId = tickets.mintNameChangeNFT(user1, seed);

        (uint16 firstNameIndex, uint16 surnameIndex) = tickets.getNameChangeData(tokenId);

        // Verify the name indices are valid
        assertTrue(nameRegistry.isValidFirstNameIndex(firstNameIndex));
        assertTrue(surnameIndex < nameRegistry.getSurnamesLength());

        // Verify name index is from a valid set (Set B: 0-setBLength, Set A: 1000+)
        assertTrue(
            firstNameIndex < nameRegistry.getNameSetBLength() || firstNameIndex >= nameRegistry.getSetAStart(),
            "Name index should be from Set A or Set B"
        );
    }

    // --- Fungible Ticket Minting ---

    function testMintFungibleTicket() public {
        // Grant all permissions to gameContract
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: true,
            playerSlots: true,
            nameChanges: true,
            weaponSpecialization: true,
            armorSpecialization: true,
            duels: true,
            dailyResets: true,
            attributeSwaps: true
        });
        tickets.setGameContractPermission(gameContract, perms);

        // Mint each ticket type
        vm.startPrank(gameContract);
        tickets.mintFungibleTicket(user1, tickets.CREATE_PLAYER_TICKET(), 5);
        tickets.mintFungibleTicket(user1, tickets.PLAYER_SLOT_TICKET(), 3);
        tickets.mintFungibleTicket(user1, tickets.WEAPON_SPECIALIZATION_TICKET(), 2);
        tickets.mintFungibleTicket(user1, tickets.ARMOR_SPECIALIZATION_TICKET(), 1);
        tickets.mintFungibleTicket(user1, tickets.DUEL_TICKET(), 10);
        tickets.mintFungibleTicket(user1, tickets.DAILY_RESET_TICKET(), 4);
        tickets.mintFungibleTicket(user1, tickets.ATTRIBUTE_SWAP_TICKET(), 7);
        vm.stopPrank();

        assertEq(tickets.balanceOf(user1, tickets.CREATE_PLAYER_TICKET()), 5);
        assertEq(tickets.balanceOf(user1, tickets.PLAYER_SLOT_TICKET()), 3);
        assertEq(tickets.balanceOf(user1, tickets.WEAPON_SPECIALIZATION_TICKET()), 2);
        assertEq(tickets.balanceOf(user1, tickets.ARMOR_SPECIALIZATION_TICKET()), 1);
        assertEq(tickets.balanceOf(user1, tickets.DUEL_TICKET()), 10);
        assertEq(tickets.balanceOf(user1, tickets.DAILY_RESET_TICKET()), 4);
        assertEq(tickets.balanceOf(user1, tickets.ATTRIBUTE_SWAP_TICKET()), 7);
    }

    function testRevertWhen_MintFungibleTicketUnauthorized() public {
        uint256 ticketType = tickets.CREATE_PLAYER_TICKET();
        vm.expectRevert(NotAuthorizedToMint.selector);
        vm.prank(user1);
        tickets.mintFungibleTicket(user1, ticketType, 1);
    }

    // --- BurnFrom ---

    function testBurnFromSelf() public {
        // Owner has initial supply of CREATE_PLAYER_TICKET — self-burn should work
        uint256 ticketType = tickets.CREATE_PLAYER_TICKET();
        uint256 before = tickets.balanceOf(owner, ticketType);
        tickets.burnFrom(owner, ticketType, 1);
        assertEq(tickets.balanceOf(owner, ticketType), before - 1);
    }

    function testRevertWhen_BurnFromUnauthorized() public {
        uint256 ticketType = tickets.CREATE_PLAYER_TICKET();
        // user1 tries to burn owner's tokens without approval
        vm.expectRevert("Not authorized to burn");
        vm.prank(user1);
        tickets.burnFrom(owner, ticketType, 1);
    }

    function testBurnFromWithApproval() public {
        uint256 ticketType = tickets.CREATE_PLAYER_TICKET();
        // Transfer some tokens to user1
        tickets.safeTransferFrom(owner, user1, ticketType, 5, "");

        // user1 approves user2
        vm.prank(user1);
        tickets.setApprovalForAll(user2, true);

        // user2 burns user1's tokens
        vm.prank(user2);
        tickets.burnFrom(user1, ticketType, 2);
        assertEq(tickets.balanceOf(user1, ticketType), 3);
    }

    // --- Soulbound Token Transfers ---

    function testRevertWhen_TransferSoulboundToken() public {
        // Grant attributeSwaps permission
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: true,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: true
        });
        tickets.setGameContractPermission(gameContract, perms);

        uint256 ticketType = tickets.ATTRIBUTE_SWAP_TICKET();
        vm.prank(gameContract);
        tickets.mintFungibleTicket(user1, ticketType, 1);

        vm.expectRevert(TokenNotTransferable.selector);
        vm.prank(user1);
        tickets.safeTransferFrom(user1, user2, ticketType, 1, "");
    }

    function testTransferNonSoulboundTicket() public {
        // Transfer CREATE_PLAYER_TICKET (not soulbound) should work
        tickets.safeTransferFrom(owner, user1, tickets.CREATE_PLAYER_TICKET(), 10, "");
        assertEq(tickets.balanceOf(user1, tickets.CREATE_PLAYER_TICKET()), 10);
    }

    // --- SetGameContractPermission ---

    function testSetGameContractPermissionFull() public {
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: true,
            playerSlots: true,
            nameChanges: true,
            weaponSpecialization: true,
            armorSpecialization: true,
            duels: true,
            dailyResets: true,
            attributeSwaps: true
        });
        tickets.setGameContractPermission(user2, perms);

        PlayerTickets.GamePermissions memory stored = tickets.gameContractPermissions(user2);
        assertTrue(stored.playerCreation);
        assertTrue(stored.playerSlots);
        assertTrue(stored.weaponSpecialization);
        assertTrue(stored.attributeSwaps);
    }

    function testRevertWhen_SetGameContractPermissionNotOwner() public {
        PlayerTickets.GamePermissions memory perms;
        vm.expectRevert("Only callable by owner");
        vm.prank(user1);
        tickets.setGameContractPermission(user2, perms);
    }

    // --- URI for Different Token Types ---

    function testURIForDailyResetTicket() public view {
        string memory uri = tickets.uri(tickets.DAILY_RESET_TICKET());
        assertTrue(bytes(uri).length > 0);
        assertTrue(_startsWith(uri, "ipfs://"));
    }

    function testURIForAttributeSwapTicket() public view {
        string memory uri = tickets.uri(tickets.ATTRIBUTE_SWAP_TICKET());
        assertTrue(bytes(uri).length > 0);
        assertTrue(_startsWith(uri, "ipfs://"));
    }

    // --- Safe Mint Variants ---

    function testMintFungibleTicketSafe() public {
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
        tickets.setGameContractPermission(gameContract, perms);

        uint256 ticketType = tickets.CREATE_PLAYER_TICKET();
        vm.prank(gameContract);
        tickets.mintFungibleTicketSafe(user1, ticketType, 3);
        assertEq(tickets.balanceOf(user1, ticketType), 3);
    }

    function testMintNameChangeNFTSafe() public {
        vm.prank(gameContract);
        uint256 tokenId = tickets.mintNameChangeNFTSafe(user1, 54321);

        assertEq(tokenId, 100);
        assertEq(tickets.balanceOf(user1, tokenId), 1);

        (uint16 firstNameIndex, uint16 surnameIndex) = tickets.getNameChangeData(tokenId);
        assertTrue(nameRegistry.isValidFirstNameIndex(firstNameIndex));
        assertTrue(surnameIndex < nameRegistry.getSurnamesLength());
    }

    // --- Admin CID Updates ---

    function testSetFungibleMetadataCID() public {
        tickets.setFungibleMetadataCID("newFungibleCID");
        assertEq(tickets.fungibleMetadataCID(), "newFungibleCID");

        // Verify URI changed
        string memory uri = tickets.uri(tickets.CREATE_PLAYER_TICKET());
        assertTrue(bytes(uri).length > 0);
    }

    function testSetNameChangeImageCID() public {
        tickets.setNameChangeImageCID("newImageCID");
        assertEq(tickets.nameChangeImageCID(), "newImageCID");
    }

    // --- Constructor Revert ---

    function testRevertWhen_ConstructorZeroAddress() public {
        vm.expectRevert(ZeroAddress.selector);
        new PlayerTickets(address(0), "cid1", "cid2");
    }

    // --- Batch Transfer Soulbound ---

    function testRevertWhen_BatchTransferSoulbound() public {
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: true
        });
        tickets.setGameContractPermission(gameContract, perms);

        uint256 ticketType = tickets.ATTRIBUTE_SWAP_TICKET();
        vm.prank(gameContract);
        tickets.mintFungibleTicket(user1, ticketType, 2);

        uint256[] memory ids = new uint256[](1);
        ids[0] = ticketType;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.expectRevert(TokenNotTransferable.selector);
        vm.prank(user1);
        tickets.safeBatchTransferFrom(user1, user2, ids, amounts, "");
    }

    // --- URI edge case ---

    function testURIForInvalidRange() public view {
        // Token IDs 8-99 return empty string
        string memory uri = tickets.uri(50);
        assertEq(bytes(uri).length, 0);
    }

    // --- SetGameContractPermission zero address ---

    function testRevertWhen_SetGameContractPermissionZeroAddress() public {
        PlayerTickets.GamePermissions memory perms;
        vm.expectRevert(ZeroAddress.selector);
        tickets.setGameContractPermission(address(0), perms);
    }

    // --- Invalid ticket type ---

    function testRevertWhen_MintInvalidTicketType() public {
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: true,
            playerSlots: true,
            nameChanges: true,
            weaponSpecialization: true,
            armorSpecialization: true,
            duels: true,
            dailyResets: true,
            attributeSwaps: true
        });
        tickets.setGameContractPermission(gameContract, perms);

        vm.prank(gameContract);
        vm.expectRevert();
        tickets.mintFungibleTicket(user1, 99, 1); // Invalid ticket type
    }

    // --- Per-permission denial coverage ---

    function testRevertWhen_MintWithoutPlayerCreationPerm() public {
        uint256 ticketType = tickets.CREATE_PLAYER_TICKET();
        vm.expectRevert(NotAuthorizedToMint.selector);
        vm.prank(gameContract);
        tickets.mintFungibleTicket(user1, ticketType, 1);
    }

    function testRevertWhen_MintWithoutPlayerSlotsPerm() public {
        uint256 ticketType = tickets.PLAYER_SLOT_TICKET();
        vm.expectRevert(NotAuthorizedToMint.selector);
        vm.prank(gameContract);
        tickets.mintFungibleTicket(user1, ticketType, 1);
    }

    function testRevertWhen_MintWithoutWeaponSpecPerm() public {
        uint256 ticketType = tickets.WEAPON_SPECIALIZATION_TICKET();
        vm.expectRevert(NotAuthorizedToMint.selector);
        vm.prank(gameContract);
        tickets.mintFungibleTicket(user1, ticketType, 1);
    }

    function testRevertWhen_MintWithoutArmorSpecPerm() public {
        uint256 ticketType = tickets.ARMOR_SPECIALIZATION_TICKET();
        vm.expectRevert(NotAuthorizedToMint.selector);
        vm.prank(gameContract);
        tickets.mintFungibleTicket(user1, ticketType, 1);
    }

    function testRevertWhen_MintWithoutDuelPerm() public {
        uint256 ticketType = tickets.DUEL_TICKET();
        vm.expectRevert(NotAuthorizedToMint.selector);
        vm.prank(gameContract);
        tickets.mintFungibleTicket(user1, ticketType, 1);
    }

    function testRevertWhen_MintWithoutDailyResetPerm() public {
        uint256 ticketType = tickets.DAILY_RESET_TICKET();
        vm.expectRevert(NotAuthorizedToMint.selector);
        vm.prank(gameContract);
        tickets.mintFungibleTicket(user1, ticketType, 1);
    }

    function testRevertWhen_MintWithoutAttributeSwapPerm() public {
        uint256 ticketType = tickets.ATTRIBUTE_SWAP_TICKET();
        vm.expectRevert(NotAuthorizedToMint.selector);
        vm.prank(gameContract);
        tickets.mintFungibleTicket(user1, ticketType, 1);
    }

    // --- Mint to non-receiver contract ---

    function testRevertWhen_MintToNonReceiverContract() public {
        // nameRegistry is a contract that doesn't implement IERC1155Receiver
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
        tickets.setGameContractPermission(gameContract, perms);

        uint256 ticketType = tickets.CREATE_PLAYER_TICKET();
        vm.prank(gameContract);
        vm.expectRevert();
        tickets.mintFungibleTicket(address(nameRegistry), ticketType, 1);
    }

    // --- Batch transfer non-soulbound success ---

    function testBatchTransferNonSoulbound() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = tickets.CREATE_PLAYER_TICKET();
        ids[1] = tickets.DAILY_RESET_TICKET();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 5;
        amounts[1] = 3;

        tickets.safeBatchTransferFrom(owner, user1, ids, amounts, "");
        assertEq(tickets.balanceOf(user1, tickets.CREATE_PLAYER_TICKET()), 5);
        assertEq(tickets.balanceOf(user1, tickets.DAILY_RESET_TICKET()), 3);
    }

    // --- Batch transfer with soulbound mixed in ---

    function testRevertWhen_BatchTransferMixedSoulbound() public {
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: true
        });
        tickets.setGameContractPermission(gameContract, perms);

        uint256 swapTicket = tickets.ATTRIBUTE_SWAP_TICKET();
        uint256 createTicket = tickets.CREATE_PLAYER_TICKET();

        vm.prank(gameContract);
        tickets.mintFungibleTicket(user1, swapTicket, 2);

        // Transfer some CREATE_PLAYER tickets to user1 so they have both types
        tickets.safeTransferFrom(owner, user1, createTicket, 5, "");

        uint256[] memory ids = new uint256[](2);
        ids[0] = createTicket; // not soulbound
        ids[1] = swapTicket; // soulbound
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        vm.expectRevert(TokenNotTransferable.selector);
        vm.prank(user1);
        tickets.safeBatchTransferFrom(user1, user2, ids, amounts, "");
    }

    // --- Admin CID non-owner reverts ---

    function testRevertWhen_SetFungibleMetadataCIDNotOwner() public {
        vm.expectRevert("Only callable by owner");
        vm.prank(user1);
        tickets.setFungibleMetadataCID("hacked");
    }

    function testRevertWhen_SetNameChangeImageCIDNotOwner() public {
        vm.expectRevert("Only callable by owner");
        vm.prank(user1);
        tickets.setNameChangeImageCID("hacked");
    }

    // --- getNameChangeData boundary cases ---

    function testRevertWhen_GetNameChangeDataTooLow() public {
        // tokenId 99 is below the name NFT range
        vm.expectRevert();
        tickets.getNameChangeData(99);
    }

    function testRevertWhen_GetNameChangeDataUnminted() public {
        // nextNameChangeTokenId is 100, so 100 is not yet minted
        vm.expectRevert();
        tickets.getNameChangeData(100);
    }

    // --- URI for unminted name NFT in valid range ---

    function testRevertWhen_URIForUnmintedNameNFT() public {
        // Token 100 hasn't been minted yet
        vm.expectRevert();
        tickets.uri(100);
    }

    // --- mintFungibleTicketSafe non-owner revert ---

    function testRevertWhen_MintFungibleTicketSafeUnauthorized() public {
        uint256 ticketType = tickets.CREATE_PLAYER_TICKET();
        vm.expectRevert(NotAuthorizedToMint.selector);
        vm.prank(user1);
        tickets.mintFungibleTicketSafe(user1, ticketType, 1);
    }

    // --- mintNameChangeNFTSafe non-owner revert ---

    function testRevertWhen_MintNameChangeNFTSafeUnauthorized() public {
        vm.expectRevert(NotAuthorizedToMint.selector);
        vm.prank(user1);
        tickets.mintNameChangeNFTSafe(user1, 123);
    }

    // ERC1155 Receiver implementation
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == 0x01ffc9a7; // ERC165 interface
    }
}

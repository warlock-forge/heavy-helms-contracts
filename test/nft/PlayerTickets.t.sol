// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";
import {PlayerNameRegistry} from "../../src/fighters/registries/names/PlayerNameRegistry.sol";
import {IPlayerNameRegistry} from "../../src/interfaces/fighters/registries/names/IPlayerNameRegistry.sol";
import {NameLibrary} from "../../src/fighters/registries/names/lib/NameLibrary.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";

contract PlayerTicketsTest is Test {
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
        tickets = new PlayerTickets(address(nameRegistry));

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

        // Get the name data for logging
        (uint16 firstNameIndex, uint16 surnameIndex) = tickets.getNameChangeData(tokenId);
        (string memory firstName, string memory surname) = nameRegistry.getFullName(firstNameIndex, surnameIndex);

        console.log("Generated URI for", firstName, surname);
        console.log(uri);
    }

    function testFungibleTicketURIs() public view {
        // Test all 5 fungible ticket URIs are base64 encoded JSON
        string memory uri1 = tickets.uri(tickets.CREATE_PLAYER_TICKET());
        string memory uri2 = tickets.uri(tickets.PLAYER_SLOT_TICKET());
        string memory uri3 = tickets.uri(tickets.WEAPON_SPECIALIZATION_TICKET());
        string memory uri4 = tickets.uri(tickets.ARMOR_SPECIALIZATION_TICKET());
        string memory uri5 = tickets.uri(tickets.DUEL_TICKET());

        // All should start with data:application/json;base64,
        assertTrue(bytes(uri1).length > 0);
        assertTrue(bytes(uri2).length > 0);
        assertTrue(bytes(uri3).length > 0);
        assertTrue(bytes(uri4).length > 0);
        assertTrue(bytes(uri5).length > 0);

        // Verify they're data URIs (not IPFS)
        assertTrue(_startsWith(uri1, "data:application/json;base64,"));
        assertTrue(_startsWith(uri2, "data:application/json;base64,"));
        assertTrue(_startsWith(uri3, "data:application/json;base64,"));
        assertTrue(_startsWith(uri4, "data:application/json;base64,"));
        assertTrue(_startsWith(uri5, "data:application/json;base64,"));

        // Log one example to verify it looks good
        console.log("Create Player Ticket URI:");
        console.log(uri1);
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

    function testRevertOnInvalidNameData() public {
        vm.expectRevert("TokenDoesNotExist()");
        tickets.getNameChangeData(999); // Non-existent token
    }

    function testRevertOnInvalidTokenIdURI() public {
        vm.expectRevert("TokenDoesNotExist()");
        tickets.uri(999); // Non-existent name change NFT
    }

    function testRevertOnUnauthorizedMint() public {
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

    function testOwnerCanAlwaysMint() public {
        // Owner should be able to mint without explicit permissions
        uint256 tokenId = tickets.mintNameChangeNFT(user1, 5555);
        assertEq(tokenId, 100);
        assertEq(tickets.balanceOf(user1, tokenId), 1);
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

        // Log to see distribution (Set B is 0-99, Set A is 1000+)
        if (firstNameIndex < 1000) {
            console.log("Selected from Set B:", firstNameIndex);
        } else {
            console.log("Selected from Set A:", firstNameIndex);
        }
    }
}

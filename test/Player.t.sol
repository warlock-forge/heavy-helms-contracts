// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Player, InvalidContractAddress, PlayerDoesNotExist} from "../src/Player.sol";
import {PlayerSkinRegistry} from "../src/PlayerSkinRegistry.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";
import {PlayerEquipmentStats} from "../src/PlayerEquipmentStats.sol";
import "../src/interfaces/IPlayer.sol";
import {DefaultPlayerSkinNFT} from "../src/DefaultPlayerSkinNFT.sol";
import "../src/interfaces/IPlayerSkinNFT.sol";
import "./utils/TestBase.sol";
import "./mocks/UnlockNFT.sol";
import {PlayerSkinNFT} from "../src/examples/PlayerSkinNFT.sol";
import {RequiredNFTNotOwned} from "../src/Player.sol";

// Helper contract that doesn't implement the required interface
contract MockInvalidEquipmentStats {
// Empty contract that will fail the interface check
}

contract PlayerTest is TestBase {
    Player public playerContract;
    PlayerSkinRegistry public skinRegistry;
    PlayerNameRegistry public nameRegistry;
    PlayerEquipmentStats public equipmentStats;
    DefaultPlayerSkinNFT public defaultSkin;
    address operator;
    uint32 public skinIndex;
    uint256 public ROUND_ID;
    uint256 private constant _PERIOD = 3;

    address public constant PLAYER_ONE = address(0xDF);
    uint256 public constant PLAYER_ONE_EXPECTED_ID = 1000; // Updated to match nextPlayerId in Player contract

    event PlayerSkinEquipped(uint256 indexed playerId, uint32 indexed skinIndex, uint16 indexed skinTokenId);
    event PlayerCreationRequested(uint256 indexed requestId, address indexed requester);
    event PlayerCreationFulfilled(uint256 indexed requestId, uint256 indexed playerId, address indexed owner);
    event RequestedRandomness(uint256 round, bytes data);
    event EquipmentStatsUpdated(address indexed oldStats, address indexed newStats);

    modifier skipInCI() {
        if (!vm.envOr("CI", false)) {
            _;
        }
    }

    function setUp() public {
        // Set operator address
        operator = address(1);

        // Set up the test environment with a proper timestamp
        vm.warp(1692803367 + 1000); // Set timestamp to after genesis

        // Deploy contracts in correct order
        skinRegistry = new PlayerSkinRegistry();
        defaultSkin = new DefaultPlayerSkinNFT();
        nameRegistry = new PlayerNameRegistry();
        equipmentStats = new PlayerEquipmentStats();

        // Deploy Player contract with dependencies
        playerContract = new Player(address(skinRegistry), address(nameRegistry), address(equipmentStats), operator);

        // Register default skin
        skinIndex = _registerSkin(address(defaultSkin));
        skinRegistry.setDefaultSkinRegistryId(skinIndex);
        skinRegistry.setDefaultCollection(skinIndex, true);
        skinRegistry.setSkinVerification(skinIndex, true); // Verify the skin

        // Reset VRF state
        ROUND_ID = 0;
    }

    function testCreatePlayerWithVRF() public skipInCI {
        // Create player and verify ownership
        uint256 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, true);
        IPlayer.PlayerStats memory newPlayer = playerContract.getPlayer(playerId);
        assertTrue(playerContract.getPlayerOwner(playerId) == PLAYER_ONE, "Player should own the NFT");
        _assertStatRanges(newPlayer, playerContract.calculateStats(newPlayer));
    }

    function testMaxPlayers() public {
        // Create max number of players
        for (uint256 i = 0; i < playerContract.maxPlayersPerAddress(); i++) {
            _createPlayerAndFulfillVRF(PLAYER_ONE, i % 2 == 0);
        }

        // Try to create one more player (should fail)
        vm.expectRevert("Too many players");
        vm.prank(PLAYER_ONE);
        playerContract.requestCreatePlayer(true);
    }

    function testMultiplePlayersWithVRF() public {
        address playerTwo = address(0x2);

        // Create players
        uint256 playerId1 = _createPlayerAndFulfillVRF(PLAYER_ONE, true);
        uint256 playerId2 = _createPlayerAndFulfillVRF(playerTwo, false);

        // Verify both players were created with correct owners
        assertEq(playerContract.getPlayerOwner(playerId1), PLAYER_ONE, "First player should be owned by PLAYER_ONE");
        assertEq(playerContract.getPlayerOwner(playerId2), playerTwo, "Second player should be owned by playerTwo");

        // Verify players have different IDs
        assertTrue(playerId1 != playerId2, "Players should have different IDs");

        // Verify each player's stats
        IPlayer.PlayerStats memory stats1 = playerContract.getPlayer(playerId1);
        IPlayer.PlayerStats memory stats2 = playerContract.getPlayer(playerId2);
        _assertStatRanges(stats1, playerContract.calculateStats(stats1));
        _assertStatRanges(stats2, playerContract.calculateStats(stats2));
    }

    function testFailCreatePlayerBeforeVRFFulfillment() public {
        // First player creation request
        vm.startPrank(PLAYER_ONE);
        playerContract.requestCreatePlayer(true);

        // Try to create another player before VRF fulfillment (should fail)
        vm.expectRevert("Pending request exists");
        playerContract.requestCreatePlayer(true);
        vm.stopPrank();

        // Now fulfill the VRF and verify we can create another player
        uint256 randomness = uint256(keccak256(abi.encodePacked("test randomness")));
        vm.prank(operator);
        bytes memory data = abi.encode(0, abi.encode(0, ""));
        playerContract.fulfillRandomness(randomness, data);

        // Should now be able to create another player
        vm.prank(PLAYER_ONE);
        playerContract.requestCreatePlayer(true);
    }

    function testFulfillRandomnessNonOperator() public {
        // Create a player request
        vm.prank(PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer(true);

        // Try to fulfill as non-operator
        vm.prank(address(0xBEEF));
        vm.expectRevert("only operator");
        bytes memory data = abi.encode(0, abi.encode(requestId, ""));
        playerContract.fulfillRandomness(uint256(keccak256(abi.encodePacked("test randomness"))), data);
    }

    function testFulfillRandomnessNotValidRoundId() public {
        // Create a player request first
        vm.prank(PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer(true);

        // Store the original request hash
        bytes32 originalHash = playerContract.requestedHash(requestId);
        assertTrue(originalHash != bytes32(0), "Request hash should be set");

        // Try to fulfill with invalid round ID
        vm.prank(operator);
        bytes memory extraData = "";
        bytes memory innerData = abi.encode(requestId, extraData);
        bytes memory dataWithRound = abi.encode(ROUND_ID + 1, innerData); // Use wrong round ID

        // This won't revert, but it should not fulfill the request
        playerContract.fulfillRandomness(uint256(keccak256(abi.encodePacked("test randomness"))), dataWithRound);

        // The request should still be pending but hash should be deleted
        assertTrue(playerContract.requestPending(requestId), "Request should still be pending");
        assertEq(playerContract.requestedHash(requestId), bytes32(0), "Request hash should be deleted");

        // Verify that the request was not actually fulfilled by trying to create a new player
        vm.expectRevert("Pending request exists");
        vm.prank(PLAYER_ONE);
        playerContract.requestCreatePlayer(true);
    }

    function testEquipSkin() public {
        // Create player and equip skin
        uint256 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, true);
        _equipSkinToPlayer(playerId, skinIndex, 0, true);

        // Verify the skin was equipped
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertEq(stats.skinIndex, skinIndex);
    }

    function testCannotEquipToUnownedPlayer() public {
        // Create a player owned by PLAYER_ONE
        uint256 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, true);

        // Try to equip skin as a different address
        vm.prank(address(0xBEEF)); // Use a different address
        vm.expectRevert(abi.encodeWithSelector(PlayerDoesNotExist.selector, playerId));
        playerContract.equipSkin(playerId, skinIndex, 0);
    }

    function testCannotEquipInvalidSkinIndex() public {
        // Create a player and try to equip invalid skin
        uint256 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, true);

        // Try to equip invalid skin index (should fail)
        _equipSkinToPlayer(playerId, 999, 0, false);
    }

    function testDefaultNameCombination() public {
        // Test Set B default name (index 0)
        (string memory firstName, string memory surname) = nameRegistry.getFullName(0, 0);
        assertEq(firstName, "Alex", "First default feminine name should be Alex");
        assertEq(surname, "the Novice", "First surname should be 'the Novice'");

        // Test Set A default name (index 1000)
        (firstName, surname) = nameRegistry.getFullName(1000, 0);
        assertEq(firstName, "Alex", "First default masculine name should be Alex");
        assertEq(surname, "the Novice", "First surname should be 'the Novice'");

        // Both should result in "Alex the Novice"
    }

    function testNameRandomness() public skipInCI {
        // Create multiple players and track name frequencies
        uint256 numPlayers = 20; // Reduced from 50 to avoid gas limits
        uint256[] memory firstNameCounts = new uint256[](nameRegistry.SET_A_START() + nameRegistry.getNameSetALength());
        uint256[] memory surnameCounts = new uint256[](nameRegistry.getSurnamesLength());

        for (uint256 i = 0; i < numPlayers; i++) {
            // Create player alternating between Set A and Set B
            address player = address(uint160(i + 1));

            vm.startPrank(player);
            uint256 requestId = playerContract.requestCreatePlayer(i % 2 == 0);
            vm.stopPrank();

            bytes32 requestHash = playerContract.requestedHash(requestId);

            vm.prank(operator);
            playerContract.fulfillRandomness(
                uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, i))),
                abi.encode(335, abi.encode(requestId, ""))
            );

            uint256 playerId = playerContract.getPlayerIds(player)[0];
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
            firstNameCounts[stats.firstNameIndex]++;
            surnameCounts[stats.surnameIndex]++;
        }

        // Verify we got some variety in names
        uint256 uniqueFirstNames = 0;
        uint256 uniqueSurnames = 0;

        // Count unique first names
        for (uint16 i = 0; i < nameRegistry.getNameSetBLength(); i++) {
            if (firstNameCounts[i] > 0) uniqueFirstNames++;
        }
        for (
            uint16 i = nameRegistry.SET_A_START();
            i < nameRegistry.SET_A_START() + nameRegistry.getNameSetALength();
            i++
        ) {
            if (firstNameCounts[i] > 0) uniqueFirstNames++;
        }

        // Count unique surnames
        for (uint16 i = 0; i < nameRegistry.getSurnamesLength(); i++) {
            if (surnameCounts[i] > 0) uniqueSurnames++;
        }

        // We should have a good distribution of names
        assertTrue(uniqueFirstNames > 3, "Should have multiple different first names");
        assertTrue(uniqueSurnames > 3, "Should have multiple different surnames");

        // Make sure we're not always getting the default names
        assertTrue(firstNameCounts[0] < numPlayers, "Too many default Set B names");
        assertTrue(firstNameCounts[nameRegistry.SET_A_START()] < numPlayers, "Too many default Set A names");
        assertTrue(surnameCounts[0] < numPlayers, "Too many default surnames");
    }

    function testFuzz_PlayerCreation(address player) public {
        // Skip zero address and contracts
        vm.assume(player != address(0));
        vm.assume(uint160(player) > 0x10000); // Skip precompiles

        vm.startPrank(player);
        uint256 requestId = playerContract.requestCreatePlayer(false);
        vm.stopPrank();

        bytes32 requestHash = playerContract.requestedHash(requestId);

        vm.prank(operator);
        playerContract.fulfillRandomness(
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, player))),
            abi.encode(335, abi.encode(requestId, ""))
        );

        uint256 playerId = playerContract.getPlayerIds(player)[0];

        // Get and validate player stats
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);

        assertTrue(stats.strength >= 3 && stats.strength <= 21, "Invalid strength");
        assertTrue(stats.constitution >= 3 && stats.constitution <= 21, "Invalid constitution");
        assertTrue(stats.size >= 3 && stats.size <= 21, "Invalid size");
        assertTrue(stats.agility >= 3 && stats.agility <= 21, "Invalid agility");
        assertTrue(stats.stamina >= 3 && stats.stamina <= 21, "Invalid stamina");
        assertTrue(stats.luck >= 3 && stats.luck <= 21, "Invalid luck");

        // Verify total points are within expected range
        uint256 totalPoints = uint256(stats.strength) + uint256(stats.constitution) + uint256(stats.size)
            + uint256(stats.agility) + uint256(stats.stamina) + uint256(stats.luck);
        assertTrue(totalPoints >= 18 && totalPoints <= 126, "Total points out of range");
    }

    function testEquipmentStatsOwnership() public {
        // Store original equipment stats address
        address originalEquipmentStats = address(equipmentStats);

        // Create new stats contract first
        PlayerEquipmentStats newStats = new PlayerEquipmentStats();

        // Test 1: Non-owner cannot swap stats
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        playerContract.setEquipmentStats(address(newStats));

        // Test 2: Owner can swap stats and event is emitted
        vm.expectEmit(true, true, false, false);
        emit EquipmentStatsUpdated(originalEquipmentStats, address(newStats));
        playerContract.setEquipmentStats(address(newStats));
        assertEq(address(playerContract.equipmentStats()), address(newStats), "Equipment stats not updated");

        // Test 3: Cannot swap to zero address
        vm.expectRevert(InvalidContractAddress.selector);
        playerContract.setEquipmentStats(address(0));

        // Test 4: Cannot swap to invalid contract
        MockInvalidEquipmentStats invalidStats = new MockInvalidEquipmentStats();
        vm.expectRevert();
        playerContract.setEquipmentStats(address(invalidStats));
    }

    function testEquipUnlockableCollection() public {
        // Deploy unlock NFT contract
        UnlockNFT unlockNFT = new UnlockNFT();

        // Deploy and register a new skin NFT that requires unlock NFT
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("Unlockable", "UNLOCK", 0.01 ether);
        uint32 newSkinIndex = _registerSkin(address(skinNFT));
        skinRegistry.setSkinVerification(newSkinIndex, true);
        skinRegistry.setRequiredNFT(newSkinIndex, address(unlockNFT));

        // Create player
        uint256 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, true);

        // Try to equip without owning unlock NFT (should fail)
        vm.prank(PLAYER_ONE);
        vm.expectRevert(abi.encodeWithSelector(RequiredNFTNotOwned.selector, address(unlockNFT)));
        playerContract.equipSkin(playerId, newSkinIndex, 0);

        // Mint unlock NFT to player
        unlockNFT.mint(PLAYER_ONE);

        // Enable minting on the skin NFT
        vm.prank(address(this));
        skinNFT.setMintingEnabled(true);

        // Now equip should succeed
        vm.deal(PLAYER_ONE, 0.01 ether);
        vm.startPrank(PLAYER_ONE);
        uint16 tokenId = uint16(skinNFT.CURRENT_TOKEN_ID());
        skinNFT.mintSkin{value: 0.01 ether}(
            PLAYER_ONE,
            IPlayerSkinNFT.WeaponType.SwordAndShield,
            IPlayerSkinNFT.ArmorType.Plate,
            IPlayerSkinNFT.FightingStance.Defensive
        );
        vm.stopPrank();

        _equipSkinToPlayer(playerId, newSkinIndex, tokenId, true);

        // Verify the skin was equipped
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertEq(stats.skinIndex, newSkinIndex);
        assertEq(stats.skinTokenId, tokenId);
    }

    function testEquipOwnedSkin() public {
        // Create player and equip skin
        uint256 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, true);

        // Deploy and register a new skin NFT
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("TestSkin", "TEST", 0.01 ether);
        uint32 newSkinIndex = _registerSkin(address(skinNFT));
        skinRegistry.setSkinVerification(newSkinIndex, true);

        // Enable minting
        vm.prank(address(this));
        skinNFT.setMintingEnabled(true);

        // Mint skin to player
        vm.deal(PLAYER_ONE, 0.01 ether);
        vm.startPrank(PLAYER_ONE);
        uint16 tokenId = uint16(skinNFT.CURRENT_TOKEN_ID());
        skinNFT.mintSkin{value: 0.01 ether}(
            PLAYER_ONE,
            IPlayerSkinNFT.WeaponType.SwordAndShield,
            IPlayerSkinNFT.ArmorType.Plate,
            IPlayerSkinNFT.FightingStance.Defensive
        );
        vm.stopPrank();

        // Equip the skin
        _equipSkinToPlayer(playerId, newSkinIndex, tokenId, true);

        // Verify the skin was equipped
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertEq(stats.skinIndex, newSkinIndex);
        assertEq(stats.skinTokenId, tokenId);
    }

    function testGetPlayerIds() public {
        // Request player creation
        uint256 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false); // Use name set A

        // Should be able to get player IDs now
        uint256[] memory playerIds = playerContract.getPlayerIds(PLAYER_ONE);
        assertEq(playerIds.length, 1, "Should have one player after VRF fulfillment");

        // Verify player stats exist
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertTrue(stats.strength > 0, "Player should exist after VRF fulfillment");
    }

    function testPlayerCreationEvents() public {
        vm.startPrank(PLAYER_ONE);
        vm.expectEmit(true, true, false, false);
        emit PlayerCreationRequested(0, PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer(true);
        vm.stopPrank();

        vm.expectEmit(true, true, true, false);
        emit PlayerCreationFulfilled(requestId, 1000, PLAYER_ONE);
        _fulfillVRF(requestId, uint256(keccak256(abi.encodePacked("test randomness"))));
    }

    // Helper functions
    function _assertStatRanges(IPlayer.PlayerStats memory stats, IPlayer.CalculatedStats memory calc) internal pure {
        // Basic stat bounds
        assertTrue(stats.strength >= 3 && stats.strength <= 21);
        assertTrue(stats.constitution >= 3 && stats.constitution <= 21);
        assertTrue(stats.size >= 3 && stats.size <= 21);
        assertTrue(stats.agility >= 3 && stats.agility <= 21);
        assertTrue(stats.stamina >= 3 && stats.stamina <= 21);
        assertTrue(stats.luck >= 3 && stats.luck <= 21);

        // Health calculation: base(75) + constitution(3-21 * 12) + size(3-21 * 6)
        uint256 minHealth = 75 + (3 * 12) + (3 * 6); // min stats (3) = 75 + 36 + 18 = 129
        uint256 maxHealth = 75 + (21 * 12) + (21 * 6); // max stats (21) = 75 + 252 + 126 = 453
        assertTrue(calc.maxHealth >= minHealth && calc.maxHealth <= maxHealth, "Health out of range");

        assertTrue(calc.damageModifier >= 50 && calc.damageModifier <= 200, "Damage mod out of range");
        assertTrue(calc.hitChance >= 30 && calc.hitChance <= 100, "Hit chance out of range");
        assertTrue(calc.critChance <= 50, "Crit chance too high");
        assertTrue(calc.critMultiplier >= 150 && calc.critMultiplier <= 300, "Crit multiplier out of range");
    }

    // Player Creation Helper
    function _createPlayerAndFulfillVRF(address owner, bool useSetB) internal returns (uint256 playerId) {
        vm.startPrank(owner);
        uint256 requestId = playerContract.requestCreatePlayer(useSetB);
        vm.stopPrank();

        // Get the request hash and fulfill it
        bytes32 requestHash = playerContract.requestedHash(requestId);
        bytes memory extraData = "";
        bytes memory data = abi.encode(requestId, extraData);
        uint256 round = 0;

        // Find the matching round number
        while (true) {
            bytes memory dataWithRound = abi.encode(round, data);
            if (keccak256(dataWithRound) == requestHash) {
                // Call fulfillRandomness as operator
                vm.prank(operator);
                playerContract.fulfillRandomness(
                    uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, round))),
                    dataWithRound
                );
                break;
            }
            round++;
        }

        // Get the player ID from the owner's list
        uint256[] memory playerIds = playerContract.getPlayerIds(owner);
        require(playerIds.length > 0, "Player not created");
        return playerIds[playerIds.length - 1];
    }

    // Skin Equipment Helper
    function _equipSkinToPlayer(uint256 playerId, uint32 skinIndexToEquip, uint16 tokenId, bool shouldSucceed)
        internal
    {
        vm.startPrank(PLAYER_ONE);
        if (shouldSucceed) {
            playerContract.equipSkin(playerId, skinIndexToEquip, tokenId);
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
            assertEq(stats.skinIndex, skinIndexToEquip);
            assertEq(stats.skinTokenId, tokenId);
        } else {
            vm.expectRevert();
            playerContract.equipSkin(playerId, skinIndexToEquip, tokenId);
        }
        vm.stopPrank();
    }

    // Helper function for VRF fulfillment
    function _fulfillVRF(uint256 requestId, uint256 randomSeed) internal {
        bytes32 requestHash = playerContract.requestedHash(requestId);
        bytes memory extraData = "";
        bytes memory data = abi.encode(requestId, extraData);
        uint256 round = 0;

        // Find the matching round number
        while (true) {
            bytes memory dataWithRound = abi.encode(round, data);
            if (keccak256(dataWithRound) == requestHash) {
                // Call fulfillRandomness as operator
                vm.prank(operator);
                playerContract.fulfillRandomness(randomSeed, dataWithRound);
                break;
            }
            round++;
        }
    }

    function _createPlayerAndExpectVRFFail(address owner, bool useSetB, string memory expectedError) internal {
        vm.startPrank(owner);
        uint256 requestId = playerContract.requestCreatePlayer(useSetB);
        vm.stopPrank();

        vm.expectRevert(bytes(expectedError));
        _fulfillVRF(requestId, uint256(keccak256(abi.encodePacked("test randomness"))));
    }

    function _createPlayerAndExpectVRFFail(
        address owner,
        bool useSetB,
        string memory expectedError,
        uint256 customRoundId
    ) internal {
        vm.startPrank(owner);
        uint256 requestId = playerContract.requestCreatePlayer(useSetB);
        vm.stopPrank();

        bytes memory extraData = "";
        bytes memory data = abi.encode(requestId, extraData);
        bytes memory dataWithRound = abi.encode(customRoundId, data);

        vm.expectRevert(bytes(expectedError));
        vm.prank(operator);
        playerContract.fulfillRandomness(uint256(keccak256(abi.encodePacked("test randomness"))), dataWithRound);
    }

    function _registerSkin(address skinContract) internal returns (uint32) {
        uint32 newSkinIndex = skinRegistry.registerSkin(skinContract);
        return newSkinIndex;
    }
}

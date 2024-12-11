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

contract PlayerTest is TestBase {
    Player public playerContract;
    PlayerSkinRegistry public skinRegistry;
    PlayerNameRegistry public nameRegistry;
    PlayerEquipmentStats public equipmentStats;
    DefaultPlayerSkinNFT public defaultSkin;
    address operator;
    uint32 public skinIndex;
    uint256 public ROUND_ID;

    address public constant PLAYER_ONE = address(0x1);
    uint256 public constant PLAYER_ONE_EXPECTED_ID = 1000;  // Updated to match nextPlayerId in Player contract

    event PlayerSkinEquipped(uint256 indexed playerId, uint32 indexed skinIndex, uint16 indexed skinTokenId);
    event PlayerCreationRequested(uint256 indexed requestId, address indexed requester);
    event PlayerCreationFulfilled(uint256 indexed requestId, uint256 indexed playerId, address indexed owner);
    event RequestedRandomness(uint256 round, bytes data);
    event EquipmentStatsUpdated(address indexed oldStats, address indexed newStats);

    function setUp() public {
        // Set operator address
        operator = address(1);

        // Deploy contracts in correct order
        skinRegistry = new PlayerSkinRegistry();
        defaultSkin = new DefaultPlayerSkinNFT();
        nameRegistry = new PlayerNameRegistry();
        equipmentStats = new PlayerEquipmentStats();
        
        // Deploy Player contract with dependencies
        playerContract = new Player(
            address(skinRegistry),
            address(nameRegistry),
            address(equipmentStats),
            operator
        );

        // Register default skin and set up registry
        skinIndex = skinRegistry.registerSkin(address(defaultSkin));
        skinRegistry.setDefaultSkinRegistryId(skinIndex);
        skinRegistry.setDefaultCollection(skinIndex, true);

        // Set up test variables
        ROUND_ID = 1;
    }

    function _validatePlayerAttributes(IPlayer.PlayerStats memory stats, string memory context) private pure {
        assertTrue(stats.strength >= 3 && stats.strength <= 21);
        assertTrue(stats.constitution >= 3 && stats.constitution <= 21);
        assertTrue(stats.size >= 3 && stats.size <= 21);
        assertTrue(stats.agility >= 3 && stats.agility <= 21);
        assertTrue(stats.stamina >= 3 && stats.stamina <= 21);
        assertTrue(stats.luck >= 3 && stats.luck <= 21);

        uint16 total = uint16(stats.strength) + uint16(stats.constitution) + uint16(stats.size) + uint16(stats.agility)
            + uint16(stats.stamina) + uint16(stats.luck);
        assertEq(total, 72, string.concat(context, ": Total attributes should be 72"));
    }

    // Helper function for VRF fulfillment
    function _fulfillVRF(uint256 requestId, uint256 randomSeed) internal {
        bytes memory dataWithRound = abi.encode(ROUND_ID, requestId);
        vm.prank(operator);
        playerContract.fulfillRandomness(randomSeed, dataWithRound);
    }

    function testCreatePlayer() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }
        address player = address(0x1);
        vm.startPrank(player);

        // Request player creation
        uint256 requestId = playerContract.requestCreatePlayer(true);

        // Verify request status
        (bool exists, bool fulfilled,) = playerContract.getRequestStatus(requestId);
        assertTrue(exists && !fulfilled, "Request should be pending");

        // Simulate VRF response with fixed randomness
        uint256 randomness = uint256(keccak256(abi.encodePacked("test randomness")));
        vm.stopPrank();
        _fulfillVRF(requestId, randomness);

        // Get the created player's stats
        IPlayer.PlayerStats memory newPlayer = playerContract.getPlayer(1000);

        assertTrue(playerContract.getPlayerOwner(1000) == player, "Player should own the NFT");
        _validatePlayerAttributes(newPlayer, "Single player test");
    }

    function testMultiplePlayers() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }
        for (uint256 i = 0; i < 10; i++) {
            address player = address(uint160(i + 1));
            vm.startPrank(player);

            // Request player creation
            uint256 requestId = playerContract.requestCreatePlayer(i % 2 == 0);

            // Verify request status
            (bool exists, bool fulfilled,) = playerContract.getRequestStatus(requestId);
            assertTrue(exists && !fulfilled, "Request should be pending");

            // Simulate VRF response with different random values for each player
            uint256 randomness = uint256(keccak256(abi.encode(i)));
            bytes memory extraData = "";
            bytes memory dataWithRound = abi.encode(ROUND_ID, abi.encode(requestId, extraData));

            // Call fulfillRandomness as operator
            vm.stopPrank();
            vm.prank(operator);
            playerContract.fulfillRandomness(randomness, dataWithRound);

            // Get the created player's stats
            IPlayer.PlayerStats memory newPlayer = playerContract.getPlayer(1000 + i);

            vm.startPrank(player);
            assertTrue(playerContract.getPlayerOwner(1000 + i) == player, "Player should own the NFT");
            vm.stopPrank();
            _validatePlayerAttributes(newPlayer, string.concat("Player ", vm.toString(i + 1)));
        }
    }

    function testStatRanges() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }
        vm.startPrank(PLAYER_ONE);

        // Request player creation
        uint256 requestId = playerContract.requestCreatePlayer(true);

        // Simulate VRF response
        uint256 randomness = uint256(keccak256(abi.encodePacked("test randomness")));
        bytes memory data = abi.encode(PLAYER_ONE);
        bytes memory dataWithRound = abi.encode(ROUND_ID, abi.encode(requestId, data));

        // Call fulfillRandomness as operator
        vm.stopPrank();
        vm.prank(operator);
        playerContract.fulfillRandomness(randomness, dataWithRound);

        // Get the created player's stats
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(1000);
        IPlayer.CalculatedStats memory calculated = playerContract.calculateStats(stats);

        vm.stopPrank();

        // Update expected ranges for new health calculation
        assertTrue(calculated.maxHealth >= 75 + 36 + 18, "Health below min"); // Min stats (3) = 75 + (3*12) + (3*6)
        assertTrue(calculated.maxHealth <= 75 + 252 + 126, "Health above max"); // Max stats (21) = 75 + (21*12) + (21*6)

        // ... rest of test assertions ...
    }

    function testMaxPlayers() public {
        // Create max number of players
        for (uint256 i = 0; i < playerContract.maxPlayersPerAddress(); i++) {
            vm.startPrank(PLAYER_ONE);
            uint256 requestId = playerContract.requestCreatePlayer(i % 2 == 0);
            uint256 randomness = uint256(keccak256(abi.encode(i)));
            bytes memory data = abi.encode(PLAYER_ONE);
            bytes memory dataWithRound = abi.encode(ROUND_ID, abi.encode(requestId, data));
            vm.stopPrank();
            vm.prank(operator);
            playerContract.fulfillRandomness(randomness, dataWithRound);
        }

        // Try to create one more player (should fail)
        vm.expectRevert("Too many players");
        vm.prank(PLAYER_ONE);
        playerContract.requestCreatePlayer(true);
    }

    function testFailCreatePlayerBeforeVRFFulfillment() public {
        // First player creation
        vm.startPrank(PLAYER_ONE);
        playerContract.requestCreatePlayer(true);

        // Try to create another player before VRF fulfillment (should fail)
        vm.expectRevert("Pending request exists");
        playerContract.requestCreatePlayer(true);
        vm.stopPrank();
    }

    function testFulfillRandomnessNonOperator() public {
        uint256 randomness = uint256(keccak256(abi.encodePacked("test randomness")));
        bytes memory dataWithRound = abi.encode(1);

        // Call fulfillRandomness from non operator
        vm.prank(address(2));
        vm.expectRevert("only operator");
        playerContract.fulfillRandomness(randomness, dataWithRound);
    }

    function testFulfillRandomnessNotValidRoundId() public {
        // Request player creation
        vm.prank(PLAYER_ONE);
        playerContract.requestCreatePlayer(true);

        uint256 randomness = uint256(keccak256(abi.encodePacked("test randomness")));
        uint256 requestId = 0;
        uint256 invalidRoundId = 42;
        bytes memory data = abi.encode(PLAYER_ONE);
        bytes memory dataWithRound = abi.encode(invalidRoundId, abi.encode(requestId, data));

        // Call fulfillRandomness as operator with invalid round ID
        vm.prank(operator);
        playerContract.fulfillRandomness(randomness, dataWithRound);

        // Player should not be created
        vm.expectRevert();
        playerContract.getPlayer(1000);
    }

    function testEquipSkin() public {
        console2.log("\n=== Test Setup ===");
        // Create player first
        vm.prank(PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer(true);

        // Verify request status
        (bool exists, bool fulfilled,) = playerContract.getRequestStatus(requestId);
        assertTrue(exists && !fulfilled, "Request should be pending");

        // Simulate VRF response with fixed randomness
        uint256 randomness = uint256(keccak256(abi.encodePacked("test randomness")));
        vm.stopPrank();
        _fulfillVRF(requestId, randomness);

        // Now try to equip the default skin
        vm.prank(PLAYER_ONE);
        playerContract.equipSkin(1000, skinIndex, 0);

        // Verify the skin was equipped
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(1000);
        assertEq(stats.skinIndex, skinIndex);
    }

    function testCannotEquipToUnownedPlayer() public {
        // Create a player owned by PLAYER_ONE
        vm.prank(PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer(true);
        uint256 randomness = uint256(keccak256(abi.encodePacked("test randomness")));
        vm.stopPrank();
        _fulfillVRF(requestId, randomness);

        // Try to equip skin as PLAYER_TWO (should fail)
        vm.prank(address(0x2));
        vm.expectRevert("Not player owner");
        playerContract.equipSkin(1000, skinIndex, 0);
    }

    function testCannotEquipInvalidSkinIndex() public {
        // Create a player first
        vm.prank(PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer(true);
        uint256 randomness = uint256(keccak256(abi.encodePacked("test randomness")));
        bytes memory extraData = "";
        bytes memory dataWithRound = abi.encode(ROUND_ID, abi.encode(requestId, extraData));
        vm.stopPrank();
        vm.prank(operator);
        playerContract.fulfillRandomness(randomness, dataWithRound);

        // Try to equip an invalid skin index
        vm.prank(PLAYER_ONE);
        vm.expectRevert("Invalid skin index");
        playerContract.equipSkin(1000, 999, 0);  // Using an unregistered skin index
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

    function testNameRandomness() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }

        // Create multiple players and track name frequencies
        uint256 numPlayers = 50;
        uint256[] memory firstNameCounts = new uint256[](nameRegistry.SET_A_START() + nameRegistry.getNameSetALength());
        uint256[] memory surnameCounts = new uint256[](nameRegistry.getSurnamesLength());

        for (uint256 i = 0; i < numPlayers; i++) {
            // Create player alternating between Set A and Set B
            vm.prank(address(uint160(i + 1)));
            uint256 requestId = playerContract.requestCreatePlayer(i % 2 == 0);
            uint256 randomness = uint256(keccak256(abi.encode(i)));
            bytes memory data = abi.encode(address(uint160(i + 1)));
            bytes memory dataWithRound = abi.encode(ROUND_ID, abi.encode(requestId, data));
            vm.stopPrank();
            vm.prank(operator);
            playerContract.fulfillRandomness(randomness, dataWithRound);
            uint256[] memory playerIds = playerContract.getPlayerIds(address(uint160(i + 1)));
            require(playerIds.length > 0, "No players found");
            uint256 playerId = playerIds[0];
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
        assertTrue(uniqueFirstNames > 5, "Should have multiple different first names");
        assertTrue(uniqueSurnames > 5, "Should have multiple different surnames");

        // Make sure we're not always getting the default names
        assertTrue(firstNameCounts[0] < numPlayers / 2, "Too many default Set B names");
        assertTrue(firstNameCounts[nameRegistry.SET_A_START()] < numPlayers / 2, "Too many default Set A names");
        assertTrue(surnameCounts[0] < numPlayers / 2, "Too many default surnames");
    }

    function testSwapEquipmentStats() public {
        // Deploy new equipment stats contract
        PlayerEquipmentStats newEquipmentStats = new PlayerEquipmentStats();

        // Store old address for comparison
        address oldEquipmentStats = address(equipmentStats);

        // Test equipment stats swap
        vm.expectEmit(true, true, false, false);
        emit EquipmentStatsUpdated(oldEquipmentStats, address(newEquipmentStats));
        playerContract.setEquipmentStats(address(newEquipmentStats));
        assertEq(address(playerContract.equipmentStats()), address(newEquipmentStats));
    }

    function testCannotSwapToZeroAddress() public {
        vm.expectRevert(InvalidContractAddress.selector);
        playerContract.setEquipmentStats(address(0));
    }

    function testOwnerCanSwapEquipmentStats() public {
        // We are the owner (test contract) so this should work
        PlayerEquipmentStats newEquipmentStats = new PlayerEquipmentStats();

        // This should succeed
        playerContract.setEquipmentStats(address(newEquipmentStats));

        // Verify the change took effect
        assertEq(address(playerContract.equipmentStats()), address(newEquipmentStats));
    }

    function testOnlyOwnerCanSwapEquipmentStats() public {
        // Create a non-owner address
        address nonOwner = makeAddr("nonOwner");

        // Store original equipment stats address
        address originalEquipmentStats = address(playerContract.equipmentStats());

        // Transfer ownership away from test contract
        playerContract.transferOwnership(nonOwner);

        // Try to set new equipment stats (should fail)
        PlayerEquipmentStats newEquipmentStats = new PlayerEquipmentStats();

        // Just expect any revert - we don't care about the specific error
        vm.expectRevert();
        playerContract.setEquipmentStats(address(newEquipmentStats));

        // Verify equipment stats didn't change
        assertEq(
            address(playerContract.equipmentStats()), originalEquipmentStats, "Equipment stats should not have changed"
        );
    }

    function testEquipUnlockableCollection() public {
        console2.log("\n=== Setup ===");
        // Deploy unlock NFT
        UnlockNFT unlockNFT = new UnlockNFT();
        console2.log("Unlock NFT deployed at:", address(unlockNFT));

        // Create a player
        vm.prank(PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer(true);
        uint256 randomness = uint256(keccak256(abi.encodePacked("test randomness")));
        bytes memory extraData = "";
        bytes memory dataWithRound = abi.encode(ROUND_ID, abi.encode(requestId, extraData));
        vm.stopPrank();
        vm.prank(operator);
        playerContract.fulfillRandomness(randomness, dataWithRound);

        // Register unlock NFT skin collection
        PlayerSkinNFT unlockableSkin = new PlayerSkinNFT("Unlockable Skin", "UNLOCK", 0.01 ether);
        uint32 unlockableSkinIndex = skinRegistry.registerSkin(address(unlockableSkin));
        skinRegistry.setRequiredNFT(unlockableSkinIndex, address(unlockNFT));

        // Try to equip without owning unlock NFT
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(abi.encodeWithSelector(PlayerSkinRegistry.RequiredNFTNotOwned.selector, address(unlockNFT)));
        playerContract.equipSkin(1000, unlockableSkinIndex, 0);
        vm.stopPrank();

        // Mint unlock NFT to player
        unlockNFT.mint(PLAYER_ONE);

        // Now equip should succeed
        vm.prank(PLAYER_ONE);
        playerContract.equipSkin(1000, unlockableSkinIndex, 0);
    }

    function testEquipOwnedSkin() public {
        // Deploy regular NFT skin contract
        PlayerSkinNFT ownedSkinNFT = new PlayerSkinNFT("Test Skin", "TEST", 0.01 ether);

        // Create player
        vm.prank(PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer(true);
        uint256 randomness = uint256(keccak256(abi.encodePacked("test randomness")));
        bytes memory extraData = "";
        bytes memory dataWithRound = abi.encode(ROUND_ID, abi.encode(requestId, extraData));
        vm.stopPrank();
        vm.prank(operator);
        playerContract.fulfillRandomness(randomness, dataWithRound);

        // Register NFT skin collection
        uint32 ownedSkinIndex = skinRegistry.registerSkin(address(ownedSkinNFT));

        // Try to equip without owning NFT
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert("Not skin owner");
        playerContract.equipSkin(1000, ownedSkinIndex, 0);
        vm.stopPrank();

        // Mint NFT to player
        vm.startPrank(PLAYER_ONE);
        ownedSkinNFT.mintSkin{value: 0.01 ether}(PLAYER_ONE, IPlayerSkinNFT.WeaponType.SwordAndShield, IPlayerSkinNFT.ArmorType.Plate, IPlayerSkinNFT.FightingStance.Defensive);
        vm.stopPrank();

        // Now equip should succeed
        vm.prank(PLAYER_ONE);
        playerContract.equipSkin(1000, ownedSkinIndex, 0);
    }

    // VRF-specific tests
    function testCreatePlayerWithVRF() public {
        // Start listening for the event
        vm.expectEmit(true, true, true, true);
        emit PlayerCreationRequested(1, PLAYER_ONE); // requestId will be 1 for first request

        // Request player creation as PLAYER_ONE
        vm.startPrank(PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer(false);  // Use name set A
        
        // Try to get player IDs before VRF fulfillment (should be empty)
        uint256[] memory playerIds = playerContract.getPlayerIds(PLAYER_ONE);
        assertEq(playerIds.length, 0, "Should have no players before VRF fulfillment");

        // Now fulfill the VRF request
        uint256 randomness = uint256(keccak256(abi.encodePacked("test randomness")));
        bytes memory data = abi.encode(PLAYER_ONE);
        bytes memory dataWithRound = abi.encode(ROUND_ID, abi.encode(requestId, data));
        vm.stopPrank();
        vm.prank(operator);
        playerContract.fulfillRandomness(randomness, dataWithRound);

        // Should be able to get player IDs now
        playerIds = playerContract.getPlayerIds(PLAYER_ONE);
        assertEq(playerIds.length, 1, "Should have one player after VRF fulfillment");
        
        // Verify player stats exist
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerIds[0]);
        assertTrue(stats.strength > 0, "Player should exist after VRF fulfillment");
        
        vm.stopPrank();
    }

    function testMultiplePlayersWithVRF() public {
        address playerTwo = address(0x2);

        // Create first player
        vm.prank(PLAYER_ONE);
        uint256 requestId1 = playerContract.requestCreatePlayer(false);  // Use name set A
        uint256 randomness1 = uint256(keccak256(abi.encodePacked("test randomness")));
        bytes memory data1 = abi.encode(PLAYER_ONE);
        bytes memory dataWithRound1 = abi.encode(ROUND_ID, abi.encode(requestId1, data1));
        vm.stopPrank();
        vm.prank(operator);
        playerContract.fulfillRandomness(randomness1, dataWithRound1);

        // Create second player
        vm.prank(playerTwo);
        uint256 requestId2 = playerContract.requestCreatePlayer(false);  // Use name set A
        uint256 randomness2 = uint256(keccak256(abi.encodePacked("test randomness 2")));
        bytes memory data2 = abi.encode(playerTwo);
        bytes memory dataWithRound2 = abi.encode(ROUND_ID, abi.encode(requestId2, data2));
        vm.stopPrank();
        vm.prank(operator);
        playerContract.fulfillRandomness(randomness2, dataWithRound2);

        // Verify different stats for different random values
        IPlayer.PlayerStats memory stats1 = playerContract.getPlayer(1000);
        IPlayer.PlayerStats memory stats2 = playerContract.getPlayer(1001);

        assertTrue(
            stats1.strength != stats2.strength || stats1.constitution != stats2.constitution
                || stats1.size != stats2.size,
            "Players should have different stats with different random values"
        );
    }

    function assertStatRanges(IPlayer.PlayerStats memory stats, IPlayer.CalculatedStats memory calc) internal pure {
        // Basic stat bounds
        assertTrue(stats.strength >= 3 && stats.strength <= 21);
        assertTrue(stats.constitution >= 3 && stats.constitution <= 21);
        assertTrue(stats.size >= 3 && stats.size <= 21);
        assertTrue(stats.agility >= 3 && stats.agility <= 21);
        assertTrue(stats.stamina >= 3 && stats.stamina <= 21);
        assertTrue(stats.luck >= 3 && stats.luck <= 21);

        // Updated calculated stat bounds based on new formulas
        uint256 minHealth = 45 + (3 * 8) + (3 * 4); // min constitution and size
        uint256 maxHealth = 45 + (21 * 8) + (21 * 4); // max constitution and size
        assertTrue(calc.maxHealth >= minHealth && calc.maxHealth <= maxHealth, "Health out of range");

        assertTrue(calc.damageModifier >= 50 && calc.damageModifier <= 200, "Damage mod out of range");
        assertTrue(calc.hitChance >= 30 && calc.hitChance <= 100, "Hit chance out of range");
        assertTrue(calc.critChance <= 50, "Crit chance too high");
        assertTrue(calc.critMultiplier >= 150 && calc.critMultiplier <= 300, "Crit multiplier out of range");
    }

    function testGetPlayerIds() public {
        // Request player creation
        vm.startPrank(PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer(false);  // Use name set A
        
        // Try to get player IDs before VRF fulfillment (should be empty)
        uint256[] memory playerIds = playerContract.getPlayerIds(PLAYER_ONE);
        assertEq(playerIds.length, 0, "Should have no players before VRF fulfillment");

        // Now fulfill the VRF request
        uint256 randomness = uint256(keccak256(abi.encodePacked("test randomness")));
        bytes memory data = abi.encode(PLAYER_ONE);
        bytes memory dataWithRound = abi.encode(ROUND_ID, abi.encode(requestId, data));
        vm.stopPrank();
        vm.prank(operator);
        playerContract.fulfillRandomness(randomness, dataWithRound);

        // Should be able to get player IDs now
        playerIds = playerContract.getPlayerIds(PLAYER_ONE);
        assertEq(playerIds.length, 1, "Should have one player after VRF fulfillment");
        
        // Verify player stats exist
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerIds[0]);
        assertTrue(stats.strength > 0, "Player should exist after VRF fulfillment");
        
        vm.stopPrank();
    }
}

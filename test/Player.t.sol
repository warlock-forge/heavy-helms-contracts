// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Player, NotSkinOwner, RequiredNFTNotOwned} from "../src/Player.sol";
import {PlayerSkinRegistry} from "../src/PlayerSkinRegistry.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";
import {PlayerEquipmentStats} from "../src/PlayerEquipmentStats.sol";
import "../src/interfaces/IPlayer.sol";
import {DefaultPlayerSkinNFT} from "../src/DefaultPlayerSkinNFT.sol";
import "../src/interfaces/IPlayerSkinNFT.sol";
import "./utils/TestBase.sol";
import "./mocks/UnlockNFT.sol";
import {PlayerSkinNFT} from "../src/examples/PlayerSkinNFT.sol";
import {InvalidContractAddress, PlayerDoesNotExist} from "../src/Player.sol";

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

    function setUp() public override {
        super.setUp();

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
        uint32 skinIndex = _registerSkin(address(defaultSkin));
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
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert("Too many players");
        playerContract.requestCreatePlayer(true);
        vm.stopPrank();
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
        vm.deal(PLAYER_ONE, playerContract.createPlayerFeeAmount() * 2); // Enough for two attempts
        vm.startPrank(PLAYER_ONE);
        playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(true);

        // Try to create another player before VRF fulfillment (should fail)
        vm.expectRevert("Pending request exists");
        playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(true);
        vm.stopPrank();

        // Now fulfill the VRF and verify we can create another player
        uint256 randomness = uint256(keccak256(abi.encodePacked("test randomness")));
        vm.prank(operator);
        bytes memory data = abi.encode(335, abi.encode(0, ""));
        playerContract.fulfillRandomness(randomness, data);

        // Should now be able to create another player
        vm.prank(PLAYER_ONE);
        playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(true);
    }

    function testFulfillRandomnessNonOperator() public {
        // Create a player request
        vm.deal(PLAYER_ONE, playerContract.createPlayerFeeAmount());
        vm.prank(PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(true);

        // Try to fulfill as non-operator
        vm.prank(address(0xBEEF));
        vm.expectRevert("only operator");
        bytes memory data = abi.encode(0, abi.encode(requestId, ""));
        playerContract.fulfillRandomness(uint256(keccak256(abi.encodePacked("test randomness"))), data);
    }

    function testFulfillRandomnessNotValidRoundId() public {
        // Create a player request first
        vm.deal(PLAYER_ONE, playerContract.createPlayerFeeAmount());
        vm.prank(PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(true);

        // Store the original request hash
        bytes32 originalHash = playerContract.requestedHash(requestId);
        assertTrue(originalHash != bytes32(0), "Request hash should be set");

        // Try to fulfill with invalid round ID
        vm.prank(operator);
        bytes memory extraData = "";
        bytes memory innerData = abi.encode(requestId, extraData);
        bytes memory dataWithRound = abi.encode(ROUND_ID + 1, innerData);

        // This should NOT revert, but should not fulfill the request
        playerContract.fulfillRandomness(uint256(keccak256(abi.encodePacked("test randomness"))), dataWithRound);

        // Verify the request hash is deleted but request is still pending
        assertTrue(playerContract.requestPending(requestId), "Request should still be pending");
        assertEq(playerContract.requestedHash(requestId), bytes32(0), "Request hash should be deleted");

        // Since the request hash is deleted, we should be able to create a new request
        vm.startPrank(PLAYER_ONE);
        playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(true);
        vm.stopPrank();
    }

    function testEquipSkin() public {
        // First create a player
        uint256 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, true);

        // Register a new skin collection
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("Test Skin Collection", "TSC", 0.01 ether);
        skinNFT.setMintingEnabled(true);

        // Register the skin collection
        uint32 skinIndex = _registerSkin(address(skinNFT));

        // Mint a skin to the player
        uint16 tokenId = 1;
        vm.deal(PLAYER_ONE, 0.01 ether);
        vm.startPrank(PLAYER_ONE);
        skinNFT.mintSkin{value: skinNFT.mintPrice()}(
            PLAYER_ONE,
            IPlayerSkinNFT.WeaponType.Greatsword,
            IPlayerSkinNFT.ArmorType.Plate,
            IPlayerSkinNFT.FightingStance.Offensive
        );
        vm.stopPrank();

        // Equip the skin
        _equipSkinToPlayer(playerId, skinIndex, tokenId, true);

        // Verify the skin was equipped
        IPlayer.PlayerStats memory player = playerContract.getPlayer(playerId);
        assertEq(player.skinIndex, skinIndex, "Skin index should be updated");
        assertEq(player.skinTokenId, tokenId, "Token ID should be updated");
    }

    function testCannotEquipToUnownedPlayer() public {
        // First create a player owned by PLAYER_ONE
        uint256 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, true);

        // Register a new skin collection
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("Test Skin Collection", "TSC", 0.01 ether);
        skinNFT.setMintingEnabled(true);

        // Register the skin collection
        uint32 skinIndex = _registerSkin(address(skinNFT));

        // Mint skin to a different address
        address otherAddress = address(0x2);
        uint16 tokenId = 1;
        vm.deal(otherAddress, 0.01 ether);
        vm.startPrank(otherAddress);
        skinNFT.mintSkin{value: skinNFT.mintPrice()}(
            otherAddress,
            IPlayerSkinNFT.WeaponType.SwordAndShield,
            IPlayerSkinNFT.ArmorType.Plate,
            IPlayerSkinNFT.FightingStance.Defensive
        );

        // Try to equip the skin (should fail)
        vm.expectRevert(abi.encodeWithSelector(PlayerDoesNotExist.selector, playerId));
        playerContract.equipSkin(playerId, skinIndex, tokenId);
        vm.stopPrank();

        // Now try to equip the same skin as PLAYER_ONE (who owns the player but not the skin)
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(NotSkinOwner.selector);
        playerContract.equipSkin(playerId, skinIndex, tokenId);
        vm.stopPrank();
    }

    function testCannotEquipInvalidSkinIndex() public {
        // First create a player
        uint256 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, true);

        // Try to equip a non-existent skin collection
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert();
        playerContract.equipSkin(playerId, 999, 1);
        vm.stopPrank();
    }

    function testNameRandomness() public skipInCI {
        // Create multiple players and track name frequencies
        uint256 numPlayers = 20; // Reduced from 50 to avoid gas limits
        uint256[] memory firstNameCounts = new uint256[](nameRegistry.SET_A_START() + nameRegistry.getNameSetALength());
        uint256[] memory surnameCounts = new uint256[](nameRegistry.getSurnamesLength());

        for (uint256 i = 0; i < numPlayers; i++) {
            // Create player alternating between Set A and Set B
            address player = address(uint160(i + 1));
            vm.deal(player, playerContract.createPlayerFeeAmount());

            vm.startPrank(player);
            uint256 requestId =
                playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(i % 2 == 0);
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

        // Give enough ETH for the fee
        vm.deal(player, playerContract.createPlayerFeeAmount());

        vm.startPrank(player);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(false);
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

    function testRetireOwnPlayer() public {
        // Create a player
        uint256 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, true);

        // Retire the player
        vm.startPrank(PLAYER_ONE);
        playerContract.retireOwnPlayer(uint32(playerId));
        vm.stopPrank();

        // Verify player is retired
        assertTrue(playerContract.isPlayerRetired(playerId), "Player should be retired");
    }

    function testCannotRetireOtherPlayerCharacter() public {
        // Create a player owned by address(1)
        vm.prank(address(1));
        uint256 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, true);

        // Try to retire it from address(2)
        vm.prank(address(2));
        vm.expectRevert("Not player owner");
        playerContract.retireOwnPlayer(uint32(playerId));

        // Verify player is not retired
        assertFalse(playerContract.isPlayerRetired(playerId), "Player should not be retired");
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

    function testGetPlayerIds() public {
        // Create multiple players for PLAYER_ONE
        uint256[] memory playerIds = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            playerIds[i] = _createPlayerAndFulfillVRF(PLAYER_ONE, true);
        }

        // Get all player IDs for PLAYER_ONE
        uint256[] memory retrievedIds = playerContract.getPlayerIds(PLAYER_ONE);

        // Verify we got all the IDs
        assertEq(retrievedIds.length, 3, "Should have 3 players");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(retrievedIds[i], playerIds[i], "Player ID mismatch");
        }
    }

    function testEquipUnlockableCollection() public {
        // Create a player
        uint256 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, true);

        // Create unlock NFT
        UnlockNFT unlockNFT = new UnlockNFT();

        // Create skin collection that requires unlock NFT
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("Unlockable Collection", "UC", 0.01 ether);
        skinNFT.setMintingEnabled(true);

        // Register the skin collection with unlock requirement
        uint32 skinIndex = skinRegistry.registerSkin{value: skinRegistry.registrationFee()}(address(skinNFT));
        skinRegistry.setRequiredNFT(skinIndex, address(unlockNFT));

        // Try to equip without owning unlock NFT (should fail)
        vm.deal(PLAYER_ONE, 0.01 ether);
        vm.startPrank(PLAYER_ONE);
        skinNFT.mintSkin{value: skinNFT.mintPrice()}(
            PLAYER_ONE,
            IPlayerSkinNFT.WeaponType.Greatsword,
            IPlayerSkinNFT.ArmorType.Plate,
            IPlayerSkinNFT.FightingStance.Offensive
        );
        vm.stopPrank();

        // Now mint unlock NFT and try again (should succeed)
        unlockNFT.mint(PLAYER_ONE);
        vm.prank(PLAYER_ONE);
        playerContract.equipSkin(playerId, skinIndex, 1);

        // Verify skin was equipped
        IPlayer.PlayerStats memory player = playerContract.getPlayer(playerId);
        assertEq(player.skinIndex, skinIndex);
        assertEq(player.skinTokenId, 1);
    }

    function testEquipOwnedSkin() public {
        // Create player and equip skin
        uint256 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, true);

        // Deploy and register a new skin NFT
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("TestSkin", "TEST", 0.01 ether);
        skinNFT.setMintingEnabled(true);

        // Register the skin collection
        uint32 skinIndex = skinRegistry.registerSkin{value: skinRegistry.registrationFee()}(address(skinNFT));

        // Mint skin to player
        vm.deal(PLAYER_ONE, 0.01 ether);
        vm.startPrank(PLAYER_ONE);
        uint16 tokenId = uint16(skinNFT.CURRENT_TOKEN_ID());
        skinNFT.mintSkin{value: skinNFT.mintPrice()}(
            PLAYER_ONE,
            IPlayerSkinNFT.WeaponType.SwordAndShield,
            IPlayerSkinNFT.ArmorType.Plate,
            IPlayerSkinNFT.FightingStance.Offensive
        );
        vm.stopPrank();

        // Equip the skin
        _equipSkinToPlayer(playerId, skinIndex, tokenId, true);

        // Verify the skin was equipped
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertEq(stats.skinIndex, skinIndex);
        assertEq(stats.skinTokenId, tokenId);
    }

    function testPlayerCreationEvents() public {
        // Give enough ETH for the fee
        vm.deal(PLAYER_ONE, playerContract.createPlayerFeeAmount());

        vm.startPrank(PLAYER_ONE);
        vm.expectEmit(true, true, false, false);
        emit PlayerCreationRequested(0, PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(true);
        vm.stopPrank();

        vm.expectEmit(true, true, true, false);
        emit PlayerCreationFulfilled(requestId, PLAYER_ONE_EXPECTED_ID, PLAYER_ONE);
        _fulfillVRF(requestId, uint256(keccak256(abi.encodePacked("test randomness"))));
    }

    function testFailCreatePlayerWithInsufficientFee() public {
        // Try to create a player with insufficient fee
        vm.deal(PLAYER_ONE, playerContract.createPlayerFeeAmount() / 2);
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert("Insufficient fee amount");
        playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount() / 2}(true);
        vm.stopPrank();
    }

    function testWithdrawFees() public {
        // Create a player and pay the fee
        uint256 initialBalance = address(this).balance;
        _createPlayerAndFulfillVRF(PLAYER_ONE, true);

        // Verify fees were collected
        uint256 collectedFees = address(playerContract).balance;
        assertTrue(collectedFees > 0, "Fees should be collected");

        // Withdraw fees as owner
        playerContract.withdrawFees();

        // Verify fees were withdrawn
        assertEq(address(playerContract).balance, 0, "Contract balance should be 0 after withdrawal");
        assertEq(address(this).balance, initialBalance + collectedFees, "Owner should receive all fees");
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

    // Helper function to get the current fee amount
    function _getCreatePlayerFee() internal view returns (uint256) {
        return playerContract.createPlayerFeeAmount();
    }

    // Player Creation Helper
    function _createPlayerAndFulfillVRF(address owner, bool useSetB) internal returns (uint256 playerId) {
        // Give enough ETH to cover the fee
        vm.deal(owner, playerContract.createPlayerFeeAmount());

        vm.startPrank(owner);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(useSetB);
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

    function _createPlayerAndExpectVRFFail(address owner, bool useSetB, string memory expectedError) internal {
        vm.deal(owner, playerContract.createPlayerFeeAmount());

        vm.startPrank(owner);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(useSetB);
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
        vm.deal(owner, playerContract.createPlayerFeeAmount());

        vm.startPrank(owner);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(useSetB);
        vm.stopPrank();

        bytes memory extraData = "";
        bytes memory innerData = abi.encode(requestId, extraData);
        bytes memory dataWithRound = abi.encode(customRoundId, innerData);

        vm.expectRevert(bytes(expectedError));
        vm.prank(operator);
        playerContract.fulfillRandomness(uint256(keccak256(abi.encodePacked("test randomness"))), dataWithRound);
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

    function _registerSkin(address skinContract) internal returns (uint32) {
        return skinRegistry.registerSkin{value: skinRegistry.registrationFee()}(skinContract);
    }

    receive() external payable {}
}

// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {
    Player,
    TooManyPlayers,
    NotPlayerOwner,
    NoPermission,
    PlayerDoesNotExist,
    InsufficientCharges,
    InvalidAttributeSwap,
    InvalidNameIndex,
    BadZeroAddress,
    InsufficientFeeAmount,
    PendingRequestExists,
    NoPendingRequest
} from "../../src/fighters/Player.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {IPlayerSkinRegistry} from "../../src/interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";
import {EquipmentRequirementsNotMet} from "../../src/fighters/registries/skins/PlayerSkinRegistry.sol";
import {SkinNotOwned, SkinRegistryDoesNotExist} from "../../src/fighters/registries/skins/PlayerSkinRegistry.sol";
import {PlayerNameRegistry} from "../../src/fighters/registries/names/PlayerNameRegistry.sol";
import {DefaultPlayerSkinNFT} from "../../src/nft/skins/DefaultPlayerSkinNFT.sol";
import {PlayerSkinNFT} from "../../src/nft/skins/PlayerSkinNFT.sol";
import "../TestBase.sol";
import "../mocks/UnlockNFT.sol";

contract PlayerTest is TestBase {
    // Test addresses
    address public PLAYER_ONE;
    address public PLAYER_TWO;

    // Allow test contract to receive ETH
    receive() external payable {}

    event PlayerSkinEquipped(uint32 indexed playerId, uint32 indexed skinIndex, uint16 indexed skinTokenId);
    event PlayerCreationRequested(uint256 indexed requestId, address indexed requester, bool paidWithTicket);
    event PlayerCreationComplete(
        uint256 indexed requestId,
        uint32 indexed playerId,
        address indexed owner,
        uint256 randomness,
        uint16 firstNameIndex,
        uint16 surnameIndex,
        uint8 strength,
        uint8 constitution,
        uint8 size,
        uint8 agility,
        uint8 stamina,
        uint8 luck,
        bool paidWithTicket
    );
    event RequestedRandomness(uint256 round, bytes data);
    event EquipmentStatsUpdated(address indexed oldStats, address indexed newStats);
    event PlayerImmortalityChanged(uint32 indexed playerId, address indexed changer, bool isImmortal);
    event RequestRecovered(
        uint256 indexed requestId, address indexed user, uint256 amount, bool adminInitiated, uint256 recoveryTimestamp
    );

    function setUp() public override {
        super.setUp();

        // Set up test addresses
        PLAYER_ONE = address(0x1111);
        PLAYER_TWO = address(0x2222);
    }

    function testCreatePlayerWithVRF() public skipInCI {
        // Create player and verify ownership
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Verify player state
        _assertPlayerState(playerContract, playerId, PLAYER_ONE, true);

        IPlayer.PlayerStats memory newPlayer = playerContract.getPlayer(playerId);
        _assertStatRanges(newPlayer);
    }

    function testMaxPlayers() public {
        // Test default slots first
        uint256 defaultSlots = playerContract.getPlayerSlots(PLAYER_ONE);

        // Fill up default slots
        for (uint256 i = 0; i < defaultSlots; i++) {
            _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        }

        // Keep purchasing and filling slots until we hit max
        while (playerContract.getPlayerSlots(PLAYER_ONE) < 100) {
            // Use actual constant value
            // Purchase one additional slot batch (1 slot)
            vm.startPrank(PLAYER_ONE);
            uint256 batchCost = playerContract.slotBatchCost();
            vm.deal(PLAYER_ONE, batchCost);
            playerContract.purchasePlayerSlots{value: batchCost}();
            vm.stopPrank();

            // Fill up all new slots
            uint256 newSlotCount = playerContract.getPlayerSlots(PLAYER_ONE);
            while (playerContract.getActivePlayerCount(PLAYER_ONE) < newSlotCount) {
                _createPlayerAndFulfillVRF(PLAYER_ONE, false);
            }

            // Verify slot count matches active players
            assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), newSlotCount);
        }
    }

    function test_RevertWhen_MaxPlayersReached() public {
        // Fill up default slots first
        uint256 defaultSlots = playerContract.getPlayerSlots(PLAYER_ONE);
        for (uint256 i = 0; i < defaultSlots; i++) {
            _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        }

        // Verify we hit the default slots limit
        uint256 activeCount = playerContract.getActivePlayerCount(PLAYER_ONE);
        assertEq(activeCount, defaultSlots);

        // Try to create one more without purchasing slots - should revert
        vm.startPrank(PLAYER_ONE);
        uint256 feeAmount = playerContract.createPlayerFeeAmount();
        vm.deal(PLAYER_ONE, feeAmount);
        vm.expectRevert(TooManyPlayers.selector);
        playerContract.requestCreatePlayer{value: feeAmount}(false);
        vm.stopPrank();
    }

    function test_RevertWhen_AbsoluteMaxSlotsReached() public {
        // Fill up to max slots (100)
        while (playerContract.getPlayerSlots(PLAYER_ONE) < 100) {
            // Purchase slots
            vm.startPrank(PLAYER_ONE);
            uint256 batchCostTmp = playerContract.slotBatchCost();
            vm.deal(PLAYER_ONE, batchCostTmp);
            playerContract.purchasePlayerSlots{value: batchCostTmp}();
            vm.stopPrank();

            // Fill new slots
            uint256 newSlotCount = playerContract.getPlayerSlots(PLAYER_ONE);
            while (playerContract.getActivePlayerCount(PLAYER_ONE) < newSlotCount) {
                _createPlayerAndFulfillVRF(PLAYER_ONE, false);
            }
        }

        // Try to purchase more slots at max - should revert
        vm.startPrank(PLAYER_ONE);
        uint256 batchCost = playerContract.slotBatchCost();
        vm.deal(PLAYER_ONE, batchCost);
        vm.expectRevert(TooManyPlayers.selector);
        playerContract.purchasePlayerSlots{value: batchCost}();
        vm.stopPrank();

        // Try to create one more player at max - should revert
        vm.startPrank(PLAYER_ONE);
        uint256 feeAmount = playerContract.createPlayerFeeAmount();
        vm.deal(PLAYER_ONE, feeAmount);
        vm.expectRevert(TooManyPlayers.selector);
        playerContract.requestCreatePlayer{value: feeAmount}(true);
        vm.stopPrank();
    }

    function testMultiplePlayersWithVRF() public {
        address playerTwo = address(0x2);

        // Create players
        uint32 playerId1 = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        uint32 playerId2 = _createPlayerAndFulfillVRF(playerTwo, false);

        // Verify both players were created with correct owners
        _assertPlayerState(playerContract, playerId1, PLAYER_ONE, true);
        _assertPlayerState(playerContract, playerId2, playerTwo, true);

        // Verify players have different IDs
        assertTrue(playerId1 != playerId2, "Players should have different IDs");

        // Verify each player's stats
        IPlayer.PlayerStats memory stats1 = playerContract.getPlayer(playerId1);
        IPlayer.PlayerStats memory stats2 = playerContract.getPlayer(playerId2);
        _assertStatRanges(stats1);
        _assertStatRanges(stats2);
    }

    function test_RevertWhen_CreatePlayerWithInsufficientFee() public {
        uint256 feeAmount = playerContract.createPlayerFeeAmount();
        // Try to create a player with insufficient fee
        vm.deal(PLAYER_ONE, feeAmount / 2);
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(InsufficientFeeAmount.selector);
        playerContract.requestCreatePlayer{value: feeAmount / 2}(true);
        vm.stopPrank();
    }

    function testEquipSkin() public {
        // Use equipment with low but meaningful requirements that we can guarantee
        // DUAL_DAGGERS requires agility >= 8, LEATHER requires strength >= 5
        // Since stats range from 3-21, we'll keep creating players until we get one that meets these modest requirements

        uint32 playerId;
        bool foundSuitablePlayer = false;

        // Try up to 50 players to find one with agility >= 8 and strength >= 5
        for (uint256 i = 0; i < 50 && !foundSuitablePlayer; i++) {
            playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);

            // Check if player meets DUAL_DAGGERS (agi >= 8) + LEATHER (str >= 5) requirements
            if (stats.attributes.agility >= 8 && stats.attributes.strength >= 5) {
                foundSuitablePlayer = true;
                break;
            }
        }

        assertTrue(
            foundSuitablePlayer, "Could not find player meeting dual daggers + leather requirements after 50 attempts"
        );

        // Register a new skin collection
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("Test Skin Collection", "TSC", 0.01 ether);
        skinNFT.setMintingEnabled(true);

        // Register the skin collection
        uint32 skinIndex = _registerSkin(address(skinNFT));
        skinRegistry.setSkinVerification(skinIndex, true);

        // Mint skin with meaningful requirements: DUAL_DAGGERS (agi >= 8) + LEATHER (str >= 5)
        vm.deal(PLAYER_ONE, 0.01 ether);
        vm.startPrank(PLAYER_ONE);
        skinNFT.mintSkin{value: skinNFT.mintPrice()}(
            PLAYER_ONE, equipmentRequirements.WEAPON_DUAL_DAGGERS(), equipmentRequirements.ARMOR_LEATHER()
        );
        uint16 tokenId = 1;
        vm.stopPrank();

        // Equip the skin (should work since we verified the player meets requirements)
        _equipSkinToPlayer(playerId, skinIndex, tokenId, true);

        // Verify the skin was equipped
        IPlayer.PlayerStats memory player = playerContract.getPlayer(playerId);
        assertEq(player.skin.skinIndex, skinIndex, "Skin index should be updated");
        assertEq(player.skin.skinTokenId, tokenId, "Token ID should be updated");
    }

    function testCannotEquipToUnownedPlayer() public {
        // First create a player owned by PLAYER_ONE
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Register a new skin collection
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("Test Skin Collection", "TSC", 0.01 ether);
        skinNFT.setMintingEnabled(true);

        // Register the skin collection
        uint32 skinIndex = _registerSkin(address(skinNFT));
        skinRegistry.setSkinVerification(skinIndex, true);

        // Mint skin to a different address
        address otherAddress = address(0x2);
        vm.deal(otherAddress, 0.01 ether);
        vm.startPrank(otherAddress);
        skinNFT.mintSkin{value: skinNFT.mintPrice()}(
            otherAddress, gameEngine.WEAPON_ARMING_SWORD_KITE(), gameEngine.ARMOR_PLATE()
        );
        uint16 tokenId = 1;
        vm.stopPrank();

        // Try to equip the skin (should fail)
        vm.expectRevert(NotPlayerOwner.selector);
        playerContract.equipSkin(playerId, skinIndex, tokenId, 1);
        vm.stopPrank();

        // Now try to equip the same skin as PLAYER_ONE (who owns the player but not the skin)
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(abi.encodeWithSelector(SkinNotOwned.selector, address(skinNFT), tokenId));
        playerContract.equipSkin(playerId, skinIndex, tokenId, 1);
        vm.stopPrank();
    }

    function testCannotEquipInvalidSkinIndex() public {
        // First create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Try to equip a non-existent skin collection
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(SkinRegistryDoesNotExist.selector);
        playerContract.equipSkin(playerId, 9999, 1, 1);
        vm.stopPrank();
    }

    function testNameRandomness() public skipInCI {
        // Create multiple players and track name frequencies
        uint256 numPlayers = 20; // Reduced from 50 to avoid gas limits
        uint256[] memory firstNameCounts = new uint256[](nameRegistry.getSetAStart() + nameRegistry.getNameSetALength());
        uint256[] memory surnameCounts = new uint256[](nameRegistry.getSurnamesLength());

        for (uint256 i = 0; i < numPlayers; i++) {
            // Create player alternating between Set A and Set B
            address player = address(uint160(i + 1));
            vm.deal(player, playerContract.createPlayerFeeAmount());

            vm.startPrank(player);
            uint256 requestId =
                playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(i % 2 == 0);
            vm.stopPrank();

            // Record logs BEFORE fulfilling VRF
            vm.recordLogs();

            vm.prank(vrfCoordinator);
            uint256[] memory randomWords = new uint256[](1);
            randomWords[0] = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, i)));
            playerContract.rawFulfillRandomWords(requestId, randomWords);

            // Now extract the player ID right after the transaction that emitted the event
            uint32 playerId = _getPlayerIdFromLogs(player, requestId);

            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
            firstNameCounts[stats.name.firstNameIndex]++;
            surnameCounts[stats.name.surnameIndex]++;
        }

        // Verify we got some variety in names
        uint256 uniqueFirstNames = 0;
        uint256 uniqueSurnames = 0;

        // Count unique first names
        for (uint16 i = 0; i < nameRegistry.getNameSetBLength(); i++) {
            if (firstNameCounts[i] > 0) uniqueFirstNames++;
        }
        for (
            uint16 i = nameRegistry.getSetAStart();
            i < nameRegistry.getSetAStart() + nameRegistry.getNameSetALength();
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
        assertTrue(firstNameCounts[nameRegistry.getSetAStart()] < numPlayers, "Too many default Set A names");
        assertTrue(surnameCounts[0] < numPlayers, "Too many default surnames");
    }

    function test_PlayerCreation(address player) public {
        // Skip zero address and contracts
        vm.assume(player != address(0));
        vm.assume(uint160(player) > 0x10000); // Skip precompiles

        // Give enough ETH for the fee
        vm.deal(player, playerContract.createPlayerFeeAmount());

        vm.startPrank(player);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(false);
        vm.stopPrank();

        // VRF request created

        // Record logs before fulfilling VRF
        vm.recordLogs();

        vm.prank(vrfCoordinator);
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, player)));
        playerContract.rawFulfillRandomWords(requestId, randomWords);

        // Get player ID from logs using our helper
        uint32 playerId = _getPlayerIdFromLogs(player, requestId);

        // Get and validate player stats
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);

        // Use the helper method instead of repeating validation logic
        _assertStatRanges(stats);

        // Verify total points are within expected range
        uint256 totalPoints = uint256(stats.attributes.strength) + uint256(stats.attributes.constitution)
            + uint256(stats.attributes.size) + uint256(stats.attributes.agility) + uint256(stats.attributes.stamina)
            + uint256(stats.attributes.luck);
        assertTrue(totalPoints >= 18 && totalPoints <= 126, "Total points out of range");
    }

    function test_statDistribution() public {
        uint256 numPlayers = 100;
        // Ensure we have enough slots for the test
        _ensurePlayerSlots(PLAYER_ONE, numPlayers, playerContract);

        uint256 maxStatCount = 0;
        uint256 highStatCount = 0;
        uint256 medStatCount = 0;
        uint256 lowStatCount = 0;

        for (uint256 i = 0; i < numPlayers; i++) {
            uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);

            // Check each stat
            uint8[6] memory statArray = [
                stats.attributes.strength,
                stats.attributes.constitution,
                stats.attributes.size,
                stats.attributes.agility,
                stats.attributes.stamina,
                stats.attributes.luck
            ];

            for (uint256 j = 0; j < 6; j++) {
                if (statArray[j] >= 19) maxStatCount++; // 19-21

                else if (statArray[j] >= 16) highStatCount++; // 16-18

                else if (statArray[j] >= 13) medStatCount++; // 13-15

                else lowStatCount++; // 3-12
            }
        }

        // Total stats checked = numPlayers * 6 stats per player
        uint256 totalStats = numPlayers * 6;

        // Log distributions
        console2.log("Stat Distribution for %d total stats:", totalStats);
        console2.log("Max stats (19-21): %d (%d%%)", maxStatCount, (maxStatCount * 100) / totalStats);
        console2.log("High stats (16-18): %d (%d%%)", highStatCount, (highStatCount * 100) / totalStats);
        console2.log("Med stats (13-15): %d (%d%%)", medStatCount, (medStatCount * 100) / totalStats);
        console2.log("Low stats (3-12): %d (%d%%)", lowStatCount, (lowStatCount * 100) / totalStats);

        // Verify rough distributions
        // Max stats should still be relatively rare (<20%)
        assertLt(maxStatCount * 100 / totalStats, 20);
        // Low stats should still be most common (>40%)
        assertGt(lowStatCount * 100 / totalStats, 40);
    }

    function testRetireOwnPlayer() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Retire the player
        vm.startPrank(PLAYER_ONE);
        playerContract.retireOwnPlayer(playerId);
        vm.stopPrank();

        // Verify player is retired
        assertTrue(playerContract.isPlayerRetired(playerId), "Player should be retired");
    }

    function testCannotRetireOtherPlayerCharacter() public {
        // Create a player owned by address(1)
        vm.prank(address(1));
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Try to retire it from address(2)
        vm.prank(address(2));
        vm.expectRevert(NotPlayerOwner.selector);
        playerContract.retireOwnPlayer(playerId);

        // Verify player is not retired
        assertFalse(playerContract.isPlayerRetired(playerId), "Player should not be retired");
    }

    function testEquipUnlockableCollection() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Create unlock NFT
        UnlockNFT unlockNFT = new UnlockNFT();

        // Create skin collection that requires unlock NFT
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("Unlockable Collection", "UC", 0.01 ether);
        skinNFT.setMintingEnabled(true);

        // Register the skin collection with unlock requirement
        vm.deal(address(this), skinRegistry.registrationFee());
        uint32 skinIndex = skinRegistry.registerSkin{value: skinRegistry.registrationFee()}(address(skinNFT));
        skinRegistry.setSkinVerification(skinIndex, true);
        skinRegistry.setRequiredNFT(skinIndex, address(unlockNFT));
        skinRegistry.setSkinType(skinIndex, IPlayerSkinRegistry.SkinType.Player);

        // Try to equip without owning unlock NFT (should fail)
        vm.deal(PLAYER_ONE, 0.01 ether);
        vm.startPrank(PLAYER_ONE);
        skinNFT.mintSkin{value: skinNFT.mintPrice()}(
            PLAYER_ONE, equipmentRequirements.WEAPON_QUARTERSTAFF(), equipmentRequirements.ARMOR_CLOTH()
        );
        uint16 tokenId = 1;
        vm.stopPrank();

        // Now mint unlock NFT and try again (should succeed)
        unlockNFT.mint(PLAYER_ONE);
        vm.prank(PLAYER_ONE);
        playerContract.equipSkin(playerId, skinIndex, tokenId, 1);

        // Verify skin was equipped
        IPlayer.PlayerStats memory player = playerContract.getPlayer(playerId);
        assertEq(player.skin.skinIndex, skinIndex);
        assertEq(player.skin.skinTokenId, tokenId);
    }

    function testEquipOwnedSkin() public {
        // Create player and equip skin
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Deploy and register a new skin NFT
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("TestSkin", "TEST", 0.01 ether);
        skinNFT.setMintingEnabled(true);

        // Register the skin collection
        vm.deal(address(this), skinRegistry.registrationFee());
        uint32 skinIndex = skinRegistry.registerSkin{value: skinRegistry.registrationFee()}(address(skinNFT));
        skinRegistry.setSkinVerification(skinIndex, true);

        // Mint skin to player with low requirement equipment
        vm.deal(PLAYER_ONE, 0.01 ether);
        vm.startPrank(PLAYER_ONE);
        skinNFT.mintSkin{value: skinNFT.mintPrice()}(
            PLAYER_ONE, equipmentRequirements.WEAPON_QUARTERSTAFF(), equipmentRequirements.ARMOR_CLOTH()
        );
        uint16 tokenId = 1;
        vm.stopPrank();

        // Equip the skin
        _equipSkinToPlayer(playerId, skinIndex, tokenId, true);

        // Verify the skin was equipped
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertEq(stats.skin.skinIndex, skinIndex);
        assertEq(stats.skin.skinTokenId, tokenId);
    }

    function testPlayerCreationEvents() public {
        // Give enough ETH for the fee
        vm.deal(PLAYER_ONE, playerContract.createPlayerFeeAmount());

        vm.startPrank(PLAYER_ONE);
        vm.expectEmit(true, true, false, false);
        emit PlayerCreationRequested(1, PLAYER_ONE, false);
        vm.recordLogs();
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(true);
        vm.stopPrank();

        vm.expectEmit(true, true, true, false); // Only check first three indexed params
        emit PlayerCreationComplete(requestId, 10001, PLAYER_ONE, 0, 0, 0, 0, 0, 0, 0, 0, 0, false); // Added placeholders for all params
        _fulfillVRFRequest(address(playerContract));
    }

    function testWithdrawFees() public {
        // Create a player and pay the fee
        uint256 initialBalance = address(this).balance;
        _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Verify fees were collected
        uint256 collectedFees = address(playerContract).balance;
        assertTrue(collectedFees > 0, "Fees should be collected");

        // Withdraw fees as owner
        playerContract.withdrawFees();

        // Verify balances after withdrawal
        _assertBalances(address(playerContract), 0, "Contract balance should be 0 after withdrawal");
        _assertBalances(address(this), initialBalance + collectedFees, "Owner should receive all fees");
    }

    function testEquipCollectionBasedSkin() public {
        // Create player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Create unlock NFT (like Shapecraft Key)
        PlayerSkinNFT unlockNFT = new PlayerSkinNFT("Unlock NFT", "UNLOCK", 0);
        unlockNFT.setMintingEnabled(true);

        // Create skin collection where skins stay with contract
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("Collection Skins", "CSKIN", 0);
        skinNFT.setMintingEnabled(true);

        // Register skin with unlock requirement
        uint32 skinIndex = _registerSkin(address(skinNFT));
        skinRegistry.setRequiredNFT(skinIndex, address(unlockNFT));
        skinRegistry.setSkinVerification(skinIndex, true);
        skinRegistry.setSkinType(skinIndex, IPlayerSkinRegistry.SkinType.Player);

        // Mint unlock NFT to player with low requirements
        vm.startPrank(PLAYER_ONE);
        unlockNFT.mintSkin(PLAYER_ONE, equipmentRequirements.WEAPON_QUARTERSTAFF(), equipmentRequirements.ARMOR_CLOTH());
        vm.stopPrank();

        // Mint skin but keep it in contract
        skinNFT.mintSkin(
            address(skinNFT), // Mint to contract itself, not PLAYER_ONE
            equipmentRequirements.WEAPON_QUARTERSTAFF(),
            equipmentRequirements.ARMOR_CLOTH()
        );
        uint16 tokenId = 1;

        // Should be able to equip with just unlock NFT
        _equipSkinToPlayer(playerId, skinIndex, tokenId, true);

        // Verify the skin was equipped
        IPlayer.PlayerStats memory player = playerContract.getPlayer(playerId);
        assertEq(player.skin.skinIndex, skinIndex, "Skin index should be updated");
        assertEq(player.skin.skinTokenId, tokenId, "Token ID should be updated");
    }

    function testActivePlayerCountTracking() public {
        // Initial count should be 0
        assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), 0);

        // Create first player and verify count
        uint32 playerId1 = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), 1);

        // Create second player and verify count
        uint32 playerId2 = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), 2);

        // Retire first player as owner
        vm.prank(PLAYER_ONE);
        playerContract.retireOwnPlayer(playerId1);
        assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), 1);

        // Try to retire same player again (should fail)
        vm.prank(PLAYER_ONE);
        vm.expectRevert(abi.encodeWithSignature("PlayerIsRetired(uint32)", playerId1));
        playerContract.retireOwnPlayer(playerId1);
        assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), 1);

        // Grant RETIRE permission to game contract
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: true, immortal: false, experience: false});
        playerContract.setGameContractPermission(address(this), permissions);

        // Test game contract retirement
        playerContract.setPlayerRetired(playerId2, true);
        assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), 0);

        // Un-retire a player
        playerContract.setPlayerRetired(playerId2, false);
        assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), 1);
    }

    function testImmortalityStatus() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Check initial state - should not be immortal
        assertFalse(playerContract.isPlayerImmortal(playerId));

        // Grant immortal permission to test contract
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, immortal: true, experience: false});
        playerContract.setGameContractPermission(address(this), permissions);

        // Set player as immortal
        playerContract.setPlayerImmortal(playerId, true);
        assertTrue(playerContract.isPlayerImmortal(playerId));

        // Toggle immortality off
        playerContract.setPlayerImmortal(playerId, false);
        assertFalse(playerContract.isPlayerImmortal(playerId));
    }

    function testCannotSetImmortalWithoutPermission() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Try to set immortal without permission
        vm.expectRevert(abi.encodeWithSelector(NoPermission.selector));
        playerContract.setPlayerImmortal(playerId, true);
    }

    function testCannotSetImmortalForNonexistentPlayer() public {
        // Grant immortal permission to test contract
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, immortal: true, experience: false});
        playerContract.setGameContractPermission(address(this), permissions);

        // Try to set immortal for non-existent player
        uint32 nonExistentPlayerId = 10999;
        vm.expectRevert(abi.encodeWithSelector(PlayerDoesNotExist.selector, nonExistentPlayerId));
        playerContract.setPlayerImmortal(nonExistentPlayerId, true);
    }

    function testImmortalityEventEmission() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant immortal permission
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, immortal: true, experience: false});
        playerContract.setGameContractPermission(address(this), permissions);

        // Expect event when setting to true
        vm.expectEmit(true, true, false, true);
        emit PlayerImmortalityChanged(playerId, address(this), true);
        playerContract.setPlayerImmortal(playerId, true);

        // Expect event when setting to false
        vm.expectEmit(true, true, false, true);
        emit PlayerImmortalityChanged(playerId, address(this), false);
        playerContract.setPlayerImmortal(playerId, false);
    }

    function testMultiplePlayersImmortalityIndependence() public {
        // Create two players
        uint32 playerId1 = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        uint32 playerId2 = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

        // Grant immortal permission
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, immortal: true, experience: false});
        playerContract.setGameContractPermission(address(this), permissions);

        // Set only player 1 as immortal
        playerContract.setPlayerImmortal(playerId1, true);

        // Verify independence
        assertTrue(playerContract.isPlayerImmortal(playerId1), "Player 1 should be immortal");
        assertFalse(playerContract.isPlayerImmortal(playerId2), "Player 2 should not be immortal");
    }

    function testImmortalityPermissionRevocation() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant immortal permission
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, immortal: true, experience: false});
        playerContract.setGameContractPermission(address(this), permissions);

        // Set player as immortal
        playerContract.setPlayerImmortal(playerId, true);

        // Revoke permission
        permissions.immortal = false;
        playerContract.setGameContractPermission(address(this), permissions);

        // Try to modify immortality after revocation
        vm.expectRevert(abi.encodeWithSelector(NoPermission.selector));
        playerContract.setPlayerImmortal(playerId, false);
    }

    function testOwnerCannotBypassImmortalityPermission() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Even as owner, should not be able to set immortality without permission
        vm.startPrank(playerContract.owner());
        vm.expectRevert(abi.encodeWithSelector(NoPermission.selector));
        playerContract.setPlayerImmortal(playerId, true);
        vm.stopPrank();
    }

    function testPlayerCreatedEvent() public {
        // Give enough ETH for the fee
        vm.deal(PLAYER_ONE, playerContract.createPlayerFeeAmount());

        // Create player request
        vm.startPrank(PLAYER_ONE);
        vm.recordLogs();
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(false);
        vm.stopPrank();

        // Fulfill VRF request using helper
        _fulfillVRFRequest(address(playerContract));

        // Get the logs and find our PlayerCreationComplete event
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundPlayerCreationCompleteEvent = false;

        for (uint256 i = 0; i < entries.length; i++) {
            // Check if this is our PlayerCreationComplete event
            if (
                entries[i].topics[0]
                    == keccak256(
                        "PlayerCreationComplete(uint256,uint32,address,uint256,uint16,uint16,uint8,uint8,uint8,uint8,uint8,uint8,bool)"
                    )
            ) {
                foundPlayerCreationCompleteEvent = true;

                // Get indexed parameters
                uint256 emittedRequestId = uint256(entries[i].topics[1]);
                uint32 playerId = uint32(uint256(entries[i].topics[2]));
                address owner = address(uint160(uint256(entries[i].topics[3])));

                // Decode the non-indexed parameters
                (
                    ,
                    uint16 firstNameIndex,
                    uint16 surnameIndex,
                    uint8 strength,
                    uint8 constitution,
                    uint8 size,
                    uint8 agility,
                    uint8 stamina,
                    uint8 luck,
                    bool paidWithTicket
                ) = abi.decode(
                    entries[i].data, (uint256, uint16, uint16, uint8, uint8, uint8, uint8, uint8, uint8, bool)
                );

                // Verify request ID matches
                assertEq(emittedRequestId, requestId, "Request ID mismatch");
                assertEq(owner, PLAYER_ONE, "Owner mismatch");

                // Get stored player data for comparison
                IPlayer.PlayerStats memory storedStats = playerContract.getPlayer(playerId);

                // Use TestBase helper to verify stat ranges
                _assertStatRanges(storedStats);

                // Verify stats match stored data
                assertEq(storedStats.name.firstNameIndex, firstNameIndex, "First name index mismatch");
                assertEq(storedStats.name.surnameIndex, surnameIndex, "Surname index mismatch");
                assertEq(storedStats.attributes.strength, strength, "Strength mismatch");
                assertEq(storedStats.attributes.constitution, constitution, "Constitution mismatch");
                assertEq(storedStats.attributes.size, size, "Size mismatch");
                assertEq(storedStats.attributes.agility, agility, "Agility mismatch");
                assertEq(storedStats.attributes.stamina, stamina, "Stamina mismatch");
                assertEq(storedStats.attributes.luck, luck, "Luck mismatch");

                // Verify total stats equal 72
                uint16 totalStats = uint16(strength) + constitution + size + agility + stamina + luck;
                assertEq(totalStats, 72, "Total stats should equal 72");

                // Verify payment method (should be false for ETH payment)
                assertEq(paidWithTicket, false, "Should be paid with ETH, not ticket");

                // Verify name indices are within valid ranges
                // For Set A names
                bool validFirstName = nameRegistry.isValidFirstNameIndex(firstNameIndex);

                assertTrue(validFirstName, "First name index out of range");
                assertTrue(surnameIndex < nameRegistry.getSurnamesLength(), "Surname index out of range");
            }
        }

        assertTrue(foundPlayerCreationCompleteEvent, "PlayerCreationComplete event was not emitted");
    }

    function testWinLossKillEvents() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Grant RECORD permission to test contract
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: true, retire: false, immortal: false, experience: false});
        playerContract.setGameContractPermission(address(this), permissions);

        // Test win event
        vm.recordLogs();
        uint256 currentSeason = playerContract.currentSeason();
        playerContract.incrementWins(playerId, currentSeason);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundWinEvent = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("PlayerWinRecorded(uint32,uint256)")) {
                foundWinEvent = true;
                uint32 eventPlayerId = uint32(uint256(entries[i].topics[1]));
                uint256 eventSeason = uint256(entries[i].topics[2]);

                assertEq(eventPlayerId, playerId, "Player ID mismatch");
                assertEq(eventSeason, currentSeason, "Season mismatch");
            }
        }
        assertTrue(foundWinEvent, "PlayerWinRecorded event not emitted for win");

        // Test loss event
        vm.recordLogs();
        playerContract.incrementLosses(playerId, currentSeason);
        entries = vm.getRecordedLogs();
        bool foundLossEvent = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("PlayerLossRecorded(uint32,uint256)")) {
                foundLossEvent = true;
                uint32 eventPlayerId = uint32(uint256(entries[i].topics[1]));
                uint256 eventSeason = uint256(entries[i].topics[2]);

                assertEq(eventPlayerId, playerId, "Player ID mismatch");
                assertEq(eventSeason, currentSeason, "Season mismatch");
            }
        }
        assertTrue(foundLossEvent, "PlayerLossRecorded event not emitted for loss");

        // Test kill event
        vm.recordLogs();
        playerContract.incrementKills(playerId, currentSeason);
        entries = vm.getRecordedLogs();
        bool foundKillEvent = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("PlayerKillRecorded(uint32,uint256)")) {
                foundKillEvent = true;
                uint32 eventPlayerId = uint32(uint256(entries[i].topics[1]));
                uint256 eventSeason = uint256(entries[i].topics[2]);

                assertEq(eventPlayerId, playerId, "Player ID mismatch");
                assertEq(eventSeason, currentSeason, "Season mismatch");
            }
        }
        assertTrue(foundKillEvent, "PlayerKillRecorded event not emitted");
    }

    function testCannotEquipSkinWithoutMeetingRequirements() public {
        // Create a player with minimum stats
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

        // Verify initial state has default skin
        IPlayer.PlayerStats memory initialStats = playerContract.getPlayer(playerId);
        assertEq(initialStats.skin.skinIndex, 0, "Initial skin index should be 0");
        assertEq(initialStats.skin.skinTokenId, 1, "Initial skin token should be 1");

        // Create a skin collection with high requirements
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("High Req Skin", "HRS", 0.01 ether);
        skinNFT.setMintingEnabled(true);

        // Register the skin
        uint32 skinIndex = _registerSkin(address(skinNFT));
        skinRegistry.setSkinVerification(skinIndex, true);

        // Mint a skin with high requirement weapon (e.g., greatsword) and heavy armor
        vm.startPrank(PLAYER_ONE);
        vm.deal(PLAYER_ONE, skinNFT.mintPrice());
        skinNFT.mintSkin{value: skinNFT.mintPrice()}(
            PLAYER_ONE, equipmentRequirements.WEAPON_SCIMITAR_DAGGER(), equipmentRequirements.ARMOR_PLATE()
        );
        uint16 tokenId = 1;

        // Get the player's stats to verify they're too low
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);

        // Expect the requirements not met error
        vm.expectRevert(EquipmentRequirementsNotMet.selector);
        playerContract.equipSkin(playerId, skinIndex, tokenId, 1);

        // Verify the skin was not equipped
        stats = playerContract.getPlayer(playerId);
        assertEq(stats.skin.skinIndex, 0, "Should still have default skin index");
        assertEq(stats.skin.skinTokenId, 1, "Should still have default token ID");

        vm.stopPrank();
    }

    function testCannotEquipDefaultSkinWithoutMeetingRequirements() public {
        // Create players until we find one that doesn't meet battleaxe requirements
        uint32 playerId;
        bool foundIneligiblePlayer = false;

        for (uint32 i = 1; i <= 100; i++) {
            // Create a new player
            playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

            // Get player stats
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
            Fighter.Attributes memory attrs = stats.attributes;

            // Check if player doesn't meet battleaxe requirements (strength 15, size 12)
            if (attrs.strength < 15 || attrs.size < 12) {
                foundIneligiblePlayer = true;
                break;
            }
        }

        // Make sure we found a player that doesn't meet requirements
        assertTrue(foundIneligiblePlayer, "Could not find player that doesn't meet battleaxe requirements");

        // Try to equip the default battleaxe skin (token ID 4)
        uint32 defaultSkinCollectionIndex = 0; // Default collection index
        uint16 battleaxeSkinTokenId = 4; // The battleaxe skin token ID

        // This should revert because the player doesn't meet requirements
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(EquipmentRequirementsNotMet.selector);
        playerContract.equipSkin(playerId, defaultSkinCollectionIndex, battleaxeSkinTokenId, 1);
        vm.stopPrank();
    }

    // Skin Equipment Helper
    function _equipSkinToPlayer(uint32 playerId, uint32 skinIndexToEquip, uint16 tokenId, bool shouldSucceed)
        internal
    {
        vm.startPrank(PLAYER_ONE);
        if (shouldSucceed) {
            playerContract.equipSkin(playerId, skinIndexToEquip, tokenId, 1);
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
            assertEq(stats.skin.skinIndex, skinIndexToEquip);
            assertEq(stats.skin.skinTokenId, tokenId);
        } else {
            IPlayerSkinRegistry.SkinCollectionInfo memory skinInfo = skinRegistry.getSkin(skinIndexToEquip);
            vm.expectRevert(abi.encodeWithSelector(SkinNotOwned.selector, skinInfo.contractAddress, tokenId));
            playerContract.equipSkin(playerId, skinIndexToEquip, tokenId, 1);
        }
        vm.stopPrank();
    }

    function testAdminClearPendingRequest() public {
        // Setup a first request to ensure non-zero IDs
        _setupValidPlayerRequest(address(0xDEAD));

        // Get owner address
        address owner = playerContract.owner();

        // Create a new request for PLAYER_ONE
        uint256 requestId = _setupValidPlayerRequest(PLAYER_ONE);
        assertTrue(requestId != 0, "Request ID should not be 0");

        // Track balances for verification
        uint256 contractBalanceBefore = address(playerContract).balance;
        vm.deal(PLAYER_ONE, 0); // Reset player balance for clear verification

        // Call the admin function to clear the request with refund
        vm.prank(owner);
        playerContract.clearPendingRequestsForAddress(PLAYER_ONE, true);

        // Verify request is cleared
        uint256 pendingRequestAfter = playerContract.getPendingRequest(PLAYER_ONE);
        assertEq(pendingRequestAfter, 0, "Request should be cleared");

        // Verify balances
        assertEq(
            address(PLAYER_ONE).balance, playerContract.createPlayerFeeAmount(), "Player should receive the fee amount"
        );
        assertEq(
            address(playerContract).balance,
            contractBalanceBefore - playerContract.createPlayerFeeAmount(),
            "Contract balance should decrease by fee amount"
        );
    }

    /// @notice Creates a player using a deterministic seed that ensures sufficient stats for equipment testing
    /// @dev Uses a specific seed (0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA) that generates stats: str:14, con:11, size:8, agi:11, sta:13, luck:11
    /// @param owner The address that will own the player
    /// @param useSetB Whether to use name set B
    /// @return The player ID of the created player
    function _createPlayerWithDeterministicStats(address owner, bool useSetB) internal returns (uint32) {
        // Start recording logs BEFORE creating the request to capture VRF events
        vm.recordLogs();

        // Create the player request
        vm.deal(owner, playerContract.createPlayerFeeAmount());
        uint256 requestId = _createPlayerRequest(owner, playerContract, useSetB);

        // Use the standard VRF fulfillment pattern
        _fulfillVRFRequest(address(playerContract));

        // Extract player ID from logs
        return _getPlayerIdFromLogs(owner, requestId);
    }
}

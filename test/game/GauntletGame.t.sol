// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {GauntletGame} from "../../src/game/modes/GauntletGame.sol";
import {Player} from "../../src/fighters/Player.sol";
import {GameEngine} from "../../src/game/engine/GameEngine.sol";
import {IPlayerSkinRegistry} from "../../src/interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";
import "../TestBase.sol";
import {IGameEngine} from "../../src/interfaces/game/engine/IGameEngine.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";
import {DefaultPlayer} from "../../src/fighters/DefaultPlayer.sol";
import {IDefaultPlayer} from "../../src/interfaces/fighters/IDefaultPlayer.sol";
// Import custom errors directly
import {
    AlreadyInQueue,
    CallerNotPlayerOwner,
    PlayerIsRetired,
    GameDisabled,
    PlayerNotInQueue,
    // Add missing errors from GauntletGame
    NotOffChainRunner,
    InsufficientQueueLength,
    InvalidQueueIndex,
    InvalidPlayerSelection,
    InvalidGauntletSize,
    QueueNotEmpty,
    GauntletDoesNotExist
} from "../../src/game/modes/GauntletGame.sol";
import {ZeroAddress} from "../../src/game/modes/BaseGame.sol"; // Import ZeroAddress from BaseGame

contract GauntletGameTest is TestBase {
    GauntletGame public game;

    // Test addresses
    address public PLAYER_ONE;
    address public PLAYER_TWO;
    address public PLAYER_THREE;
    address public OFF_CHAIN_RUNNER;

    // Player IDs
    uint32[] public playerIds;
    uint32 public PLAYER_ONE_ID;
    uint32 public PLAYER_TWO_ID;
    uint32 public PLAYER_THREE_ID;

    // Events to test
    event PlayerQueued(uint32 indexed playerId, uint256 queueSize, uint256 entryFee);
    event PlayerWithdrew(uint32 indexed playerId, uint256 queueSize);
    event GauntletStarted(
        uint256 indexed gauntletId, uint8 size, uint256 entryFee, uint32[] participantIds, uint256 vrfRequestId
    );
    event GauntletCompleted(
        uint256 indexed gauntletId,
        uint8 size,
        uint256 entryFee,
        uint32 indexed championId,
        uint256 prizeAwarded,
        uint256 feeCollected
    );
    event GauntletRecovered(uint256 indexed gauntletId);
    event OffChainRunnerSet(address indexed newRunner);
    event EntryFeeSet(uint256 oldFee, uint256 newFee);
    event GauntletSizeSet(uint8 oldSize, uint8 newSize);
    event QueueClearedDueToSettingsChange(uint256 playersRefunded, uint256 totalRefunded);

    function setUp() public override {
        super.setUp();

        // Initialize off-chain runner address
        OFF_CHAIN_RUNNER = address(0x42424242);

        // Deploy DefaultPlayer contract
        defaultPlayerContract = new DefaultPlayer(address(skinRegistry), address(nameRegistry));

        // Initialize game contract with off-chain runner AND DefaultPlayer address
        game = new GauntletGame(
            address(gameEngine), address(playerContract), address(defaultPlayerContract), operator, OFF_CHAIN_RUNNER
        );

        // Create a default player entry for testing substitutions
        _createDefaultPlayerEntry(1, defaultPlayerContract);

        // Set permissions for game contract
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, name: false, attributes: false, immortal: false});
        playerContract.setGameContractPermission(address(game), perms);

        // Setup test addresses
        PLAYER_ONE = address(0xdF1);
        PLAYER_TWO = address(0xdF2);
        PLAYER_THREE = address(0xdF3);

        // Create actual players using VRF
        PLAYER_ONE_ID = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        PLAYER_TWO_ID = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);
        PLAYER_THREE_ID = _createPlayerAndFulfillVRF(PLAYER_THREE, playerContract, false);

        // Store player IDs in array for convenience
        playerIds = new uint32[](3);
        playerIds[0] = PLAYER_ONE_ID;
        playerIds[1] = PLAYER_TWO_ID;
        playerIds[2] = PLAYER_THREE_ID;

        // Give them ETH
        vm.deal(PLAYER_ONE, 100 ether);
        vm.deal(PLAYER_TWO, 100 ether);
        vm.deal(PLAYER_THREE, 100 ether);
    }

    // Helper to create a basic default player entry
    function _createDefaultPlayerEntry(uint32 playerId, DefaultPlayer dpContract) internal {
        IPlayer.PlayerStats memory stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 10, constitution: 10, size: 10, agility: 10, stamina: 10, luck: 10}),
            name: IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 0}),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            stance: 1,
            record: Fighter.Record({wins: 0, losses: 0, kills: 0})
        });
        vm.prank(dpContract.owner());
        dpContract.createDefaultPlayer(playerId, stats);
    }

    //==============================================================//
    //              QUEUE MANAGEMENT FUNCTION TESTS                 //
    //==============================================================//

    function testInitialState() public {
        assertEq(address(game.gameEngine()), address(gameEngine));
        assertEq(address(game.playerContract()), address(playerContract));
        assertEq(game.nextGauntletId(), 0);
        assertEq(game.queuedFeesPool(), 0);
        assertEq(game.contractFeesCollected(), 0);
        assertEq(game.getQueueSize(), 0);
        assertEq(game.offChainRunner(), OFF_CHAIN_RUNNER);
    }

    function testQueueForGauntlet() public {
        vm.startPrank(PLAYER_ONE);

        // Get fee amount from state variable
        uint256 entryFee = game.currentEntryFee();

        // Create loadout for player
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // Test event emission
        vm.expectEmit(true, true, false, true);
        emit PlayerQueued(PLAYER_ONE_ID, 1, entryFee);

        // Queue for gauntlet
        game.queueForGauntlet{value: entryFee}(loadout);

        // Verify queue state
        assertEq(game.getQueueSize(), 1, "Queue size should be 1");
        assertEq(game.queueIndex(0), PLAYER_ONE_ID, "Player should be at index 0");
        assertEq(
            uint8(game.playerStatus(PLAYER_ONE_ID)), uint8(GauntletGame.PlayerStatus.QUEUED), "Player should be QUEUED"
        );
        assertEq(game.playerIndexInQueue(PLAYER_ONE_ID), 1, "Player index + 1 should be 1");
        assertEq(game.queuedFeesPool(), entryFee, "Entry fee should be in fee pool");

        // Verify loadout is stored correctly
        Fighter.PlayerLoadout memory storedLoadout =
            GauntletGame.PlayerQueueData(game.registrationQueue(PLAYER_ONE_ID)).loadout;
        assertEq(storedLoadout.playerId, loadout.playerId, "Stored playerId should match");
        assertEq(storedLoadout.skin.skinIndex, loadout.skin.skinIndex, "Stored skin index should match");
        assertEq(storedLoadout.skin.skinTokenId, loadout.skin.skinTokenId, "Stored skin token ID should match");
        assertEq(storedLoadout.stance, loadout.stance, "Stored stance should match");

        vm.stopPrank();
    }

    function testQueueMultiplePlayers() public {
        uint256 entryFee = game.currentEntryFee();

        // Queue all three test players
        for (uint256 i = 0; i < 3; i++) {
            address player = i == 0 ? PLAYER_ONE : (i == 1 ? PLAYER_TWO : PLAYER_THREE);
            uint32 playerId = playerIds[i];

            vm.startPrank(player);
            Fighter.PlayerLoadout memory loadout = _createLoadout(playerId);
            game.queueForGauntlet{value: entryFee}(loadout);
            vm.stopPrank();
        }

        // Verify queue state
        assertEq(game.getQueueSize(), 3, "Queue size should be 3");
        assertEq(game.queueIndex(0), PLAYER_ONE_ID, "Player one should be at index 0");
        assertEq(game.queueIndex(1), PLAYER_TWO_ID, "Player two should be at index 1");
        assertEq(game.queueIndex(2), PLAYER_THREE_ID, "Player three should be at index 2");

        // Check player indices are correct
        assertEq(game.playerIndexInQueue(PLAYER_ONE_ID), 1, "Player one index + 1 should be 1");
        assertEq(game.playerIndexInQueue(PLAYER_TWO_ID), 2, "Player two index + 1 should be 2");
        assertEq(game.playerIndexInQueue(PLAYER_THREE_ID), 3, "Player three index + 1 should be 3");

        // Check player statuses
        assertEq(
            uint8(game.playerStatus(PLAYER_ONE_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED),
            "Player one should be QUEUED"
        );
        assertEq(
            uint8(game.playerStatus(PLAYER_TWO_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED),
            "Player two should be QUEUED"
        );
        assertEq(
            uint8(game.playerStatus(PLAYER_THREE_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED),
            "Player three should be QUEUED"
        );

        // Verify fee pool
        assertEq(game.queuedFeesPool(), entryFee * 3, "Fee pool should have three entry fees");
    }

    function testWithdrawFromQueue() public {
        uint256 entryFee = game.currentEntryFee();

        // First queue a player
        vm.startPrank(PLAYER_ONE);
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);
        game.queueForGauntlet{value: entryFee}(loadout);

        // Record balance before withdraw
        uint256 balanceBefore = address(PLAYER_ONE).balance;

        // Expect event
        vm.expectEmit(true, true, false, true);
        emit PlayerWithdrew(PLAYER_ONE_ID, 0);

        // Withdraw from queue - pass the correct ID
        game.withdrawFromQueue(PLAYER_ONE_ID);
        vm.stopPrank();

        // Verify queue state
        assertEq(game.getQueueSize(), 0, "Queue should be empty");
        assertEq(
            uint8(game.playerStatus(PLAYER_ONE_ID)),
            uint8(GauntletGame.PlayerStatus.NONE),
            "Player status should be NONE"
        );
        assertEq(game.playerIndexInQueue(PLAYER_ONE_ID), 0, "Player index should be cleared (0)");

        // Verify player was refunded
        assertEq(address(PLAYER_ONE).balance, balanceBefore + entryFee, "Player should be refunded entry fee");

        // Verify fee pool
        assertEq(game.queuedFeesPool(), 0, "Fee pool should be empty");
    }

    function testRevertWhen_AlreadyInQueue() public {
        // Queue player one
        vm.startPrank(PLAYER_ONE);
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);
        uint256 entryFee = game.currentEntryFee();
        game.queueForGauntlet{value: entryFee}(loadout);

        // Try to queue again - should revert
        vm.expectRevert(AlreadyInQueue.selector);
        game.queueForGauntlet{value: entryFee}(loadout);
        vm.stopPrank();
    }

    function testRevertWhen_IncorrectEntryFee() public {
        vm.startPrank(PLAYER_ONE);
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // Send wrong fee amount
        uint256 entryFee = game.currentEntryFee();
        vm.expectRevert("Incorrect entry fee");
        game.queueForGauntlet{value: entryFee == 0 ? 1 : entryFee - 1}(loadout);

        vm.expectRevert("Incorrect entry fee");
        game.queueForGauntlet{value: entryFee + 1}(loadout);

        vm.stopPrank();
    }

    function testRevertWhen_NotPlayerOwner() public {
        // Try to queue a player you don't own
        vm.startPrank(PLAYER_TWO);
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID); // Using player one's ID

        uint256 entryFee = game.currentEntryFee();
        vm.expectRevert(CallerNotPlayerOwner.selector);
        game.queueForGauntlet{value: entryFee}(loadout);
        vm.stopPrank();
    }

    function testRevertWhen_PlayerRetired() public {
        // First retire player one
        vm.startPrank(PLAYER_ONE);
        playerContract.retireOwnPlayer(PLAYER_ONE_ID);

        // Now try to queue retired player
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        uint256 entryFee = game.currentEntryFee();
        vm.expectRevert(PlayerIsRetired.selector);
        game.queueForGauntlet{value: entryFee}(loadout);
        vm.stopPrank();
    }

    function testRevertWhen_GameDisabled() public {
        // Disable game as owner
        vm.prank(game.owner());
        game.setGameEnabled(false);

        // Try to queue when game is disabled
        vm.startPrank(PLAYER_ONE);
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        uint256 entryFee = game.currentEntryFee();
        vm.expectRevert(GameDisabled.selector);
        game.queueForGauntlet{value: entryFee}(loadout);
        vm.stopPrank();
    }

    function testRevertWhen_WithdrawNotInQueue() public {
        // Try to withdraw when not in queue
        vm.startPrank(PLAYER_ONE);
        // Use direct selector after import
        vm.expectRevert(PlayerNotInQueue.selector);
        game.withdrawFromQueue(PLAYER_ONE_ID);
        vm.stopPrank();
    }

    //==============================================================//
    //         START GAUNTLET & SWAP-AND-POP TESTS                //
    //==============================================================//

    /// @notice Helper to queue multiple players for testing startGauntlet
    function _queuePlayers(uint256 count) internal returns (uint32[] memory queuedIds, address[] memory queuedAddrs) {
        if (count == 0) return (new uint32[](0), new address[](0));

        queuedIds = new uint32[](count);
        queuedAddrs = new address[](count);
        uint256 entryFee = game.currentEntryFee();

        for (uint256 i = 0; i < count; i++) {
            // Create new address and player for each slot
            address playerAddr = address(uint160(uint256(keccak256(abi.encodePacked("player", i)))));
            // Set larger initial balance
            vm.deal(playerAddr, 10 ether);

            // Create player first (this will consume some ETH)
            uint32 playerId = _createPlayerAndFulfillVRF(playerAddr, playerContract, false);

            // Ensure player still has enough ETH for entry fee after player creation
            if (playerAddr.balance < entryFee) {
                vm.deal(playerAddr, playerAddr.balance + entryFee + 0.01 ether);
            }

            queuedIds[i] = playerId;
            queuedAddrs[i] = playerAddr;

            vm.startPrank(playerAddr);
            Fighter.PlayerLoadout memory loadout = _createLoadout(playerId);
            game.queueForGauntlet{value: entryFee}(loadout);
            vm.stopPrank();
        }
    }

    function testStartGauntlet_Success_16Players() public {
        uint8 gauntletSize = game.currentGauntletSize();
        uint256 entryFee = game.currentEntryFee();

        (uint32[] memory queuedIds,) = _queuePlayers(gauntletSize);
        assertEq(game.getQueueSize(), gauntletSize, "Queue should have correct number of players");

        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 playerId = game.queueIndex(i);
            selectedIds[i] = playerId;
            selectedIndices[i] = game.playerIndexInQueue(playerId) - 1;
        }

        vm.recordLogs(); // Start recording BEFORE the call
        vm.prank(OFF_CHAIN_RUNNER);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
        Vm.Log[] memory entries = vm.getRecordedLogs(); // Get logs AFTER the call

        assertEq(game.getQueueSize(), 0, "Queue should be empty after start");
        assertEq(game.nextGauntletId(), 1, "Next gauntlet ID should be 1");

        bytes32 gauntletStartedSig = keccak256("GauntletStarted(uint256,uint8,uint256,uint32[],uint256)");
        uint256 actualVrfRequestId = 0;
        bool foundGauntletStartedEvent = false;

        // Simple loop to find and decode the event
        for (uint256 i = 0; i < entries.length; i++) {
            if (
                entries[i].topics.length > 1 && entries[i].topics[0] == gauntletStartedSig
                    && uint256(entries[i].topics[1]) == 0 // Check gauntletId = 0
            ) {
                // Direct decoding - assumes this is the correct log
                (uint8 size, uint256 fee, uint32[] memory pIds, uint256 reqId) =
                    abi.decode(entries[i].data, (uint8, uint256, uint32[], uint256));

                actualVrfRequestId = reqId;
                foundGauntletStartedEvent = true;
                assertEq(size, gauntletSize, "Event size mismatch");
                assertEq(fee, entryFee, "Event fee mismatch");
                assertEq(pIds.length, gauntletSize, "Event participant count mismatch");
                // Basic check on participant IDs
                if (pIds.length == selectedIds.length) {
                    for (uint256 j = 0; j < pIds.length; j++) {
                        assertEq(pIds[j], selectedIds[j], "Mismatch participant ID in event");
                    }
                }
                break; // Found the event, exit loop
            }
        }
        assertTrue(foundGauntletStartedEvent, "GauntletStarted event not found for gauntletId 0");

        // Check the mapping regardless of the ID value
        assertEq(game.requestToGauntletId(actualVrfRequestId), 0, "Request ID should map to Gauntlet ID 0");
        // Check player statuses
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = selectedIds[i];
            assertEq(
                uint8(game.playerStatus(pId)),
                uint8(GauntletGame.PlayerStatus.IN_GAUNTLET),
                "Player status should be IN_GAUNTLET"
            );
            assertEq(game.playerCurrentGauntlet(pId), 0, "Player current gauntlet should be 0");
        }
    }

    function testStartGauntlet_Success_MoreThan16Players() public {
        uint8 gauntletSize = game.currentGauntletSize();
        uint256 entryFee = game.currentEntryFee();
        uint256 queueStartSize = gauntletSize + 4;

        (uint32[] memory queuedIds,) = _queuePlayers(queueStartSize);
        assertEq(game.getQueueSize(), queueStartSize, "Queue should have correct initial number of players");

        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 playerId = game.queueIndex(i);
            selectedIds[i] = playerId;
            selectedIndices[i] = game.playerIndexInQueue(playerId) - 1;
        }

        vm.recordLogs(); // Start recording BEFORE the call
        vm.prank(OFF_CHAIN_RUNNER);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
        Vm.Log[] memory entries = vm.getRecordedLogs(); // Get logs AFTER the call

        assertEq(game.getQueueSize(), queueStartSize - gauntletSize, "Queue size should be reduced correctly");
        assertEq(game.nextGauntletId(), 1, "Next gauntlet ID should be 1");

        bytes32 gauntletStartedSig = keccak256("GauntletStarted(uint256,uint8,uint256,uint32[],uint256)");
        uint256 actualVrfRequestId = 0;
        bool foundGauntletStartedEvent = false;

        // Simple loop to find and decode the event
        for (uint256 i = 0; i < entries.length; i++) {
            if (
                entries[i].topics.length > 1 && entries[i].topics[0] == gauntletStartedSig
                    && uint256(entries[i].topics[1]) == 0 // Check gauntletId = 0
            ) {
                // Direct decoding
                (uint8 size, uint256 fee, uint32[] memory pIds, uint256 reqId) =
                    abi.decode(entries[i].data, (uint8, uint256, uint32[], uint256));

                actualVrfRequestId = reqId;
                foundGauntletStartedEvent = true;
                assertEq(size, gauntletSize, "Event size mismatch");
                assertEq(fee, entryFee, "Event fee mismatch");
                assertEq(pIds.length, gauntletSize, "Event participant count mismatch");
                if (pIds.length == selectedIds.length) {
                    for (uint256 j = 0; j < pIds.length; j++) {
                        assertEq(pIds[j], selectedIds[j], "Mismatch participant ID in event");
                    }
                }
                break; // Found the event, exit loop
            }
        }
        assertTrue(foundGauntletStartedEvent, "GauntletStarted event not found for gauntletId 0");

        // Check the mapping regardless of the ID value
        assertEq(game.requestToGauntletId(actualVrfRequestId), 0, "Request ID should map to Gauntlet ID 0");
        // Verify remaining players are still queued correctly (swap-and-pop check)
        for (uint256 i = 0; i < game.getQueueSize(); i++) {
            uint32 queuedId = game.queueIndex(i);
            assertEq(
                uint8(game.playerStatus(queuedId)),
                uint8(GauntletGame.PlayerStatus.QUEUED),
                "Remaining player status incorrect"
            );
        }

        // Check player statuses
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = selectedIds[i];
            assertEq(
                uint8(game.playerStatus(pId)),
                uint8(GauntletGame.PlayerStatus.IN_GAUNTLET),
                "Player status should be IN_GAUNTLET"
            );
            assertEq(game.playerCurrentGauntlet(pId), 0, "Player current gauntlet should be 0");
        }
    }

    function testRevertWhen_StartGauntlet_NotRunner() public {
        uint8 gauntletSize = game.currentGauntletSize();
        _queuePlayers(gauntletSize);

        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            selectedIds[i] = game.queueIndex(i); // Get IDs from queue
            selectedIndices[i] = i;
        }

        // Prank as PLAYER_ONE (not the runner)
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(NotOffChainRunner.selector);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
        vm.stopPrank();
    }

    function testRevertWhen_StartGauntlet_InsufficientPlayers() public {
        uint8 gauntletSize = game.currentGauntletSize();
        _queuePlayers(gauntletSize - 1); // Queue one less than needed

        // Prepare dummy arrays - size doesn't strictly matter as length check fails first
        // But initialize correctly to avoid unrelated reverts
        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        // No need to populate as the check should fail before using them

        vm.prank(OFF_CHAIN_RUNNER);
        vm.expectRevert(InsufficientQueueLength.selector);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
    }

    function testRevertWhen_StartGauntlet_InvalidIndex() public {
        uint8 gauntletSize = game.currentGauntletSize();
        _queuePlayers(gauntletSize);

        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            selectedIds[i] = game.queueIndex(i);
            selectedIndices[i] = i;
        }

        // Make one index invalid (out of bounds)
        selectedIndices[gauntletSize > 0 ? gauntletSize / 2 : 0] = 100; // Use index relative to size

        vm.prank(OFF_CHAIN_RUNNER);
        vm.expectRevert(InvalidQueueIndex.selector);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
    }

    function testRevertWhen_StartGauntlet_MismatchedSelection() public {
        uint8 gauntletSize = game.currentGauntletSize();
        _queuePlayers(gauntletSize);

        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            selectedIds[i] = game.queueIndex(i);
            selectedIndices[i] = i;
        }

        // Make one ID not match the ID at its supposed index
        selectedIds[gauntletSize > 0 ? gauntletSize / 2 : 0] = 99999; // An ID not in the queue

        vm.prank(OFF_CHAIN_RUNNER);
        vm.expectRevert(InvalidPlayerSelection.selector);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
    }

    function testRevertWhen_StartGauntlet_PlayerNotInQueueStatus() public {
        uint8 gauntletSize = game.currentGauntletSize();
        (uint32[] memory queuedIds, address[] memory queuedAddrs) = _queuePlayers(gauntletSize);

        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            selectedIds[i] = queuedIds[i];
            selectedIndices[i] = game.playerIndexInQueue(queuedIds[i]) - 1;
        }

        // Manually withdraw one player *after* queuing
        uint256 indexToWithdraw = gauntletSize > 0 ? gauntletSize / 2 : 0;
        vm.startPrank(queuedAddrs[indexToWithdraw]);
        game.withdrawFromQueue(queuedIds[indexToWithdraw]); // Player status is now NONE, queue size reduced
        vm.stopPrank();

        // Now try to start the gauntlet with the original list (including withdrawn player)
        // AND the original indices (which are now potentially wrong due to swap-and-pop)
        vm.prank(OFF_CHAIN_RUNNER);
        vm.expectRevert(InsufficientQueueLength.selector);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
    }

    function testAdmin_SetOffChainRunner() public {
        address newRunner = address(0x9876);
        vm.prank(game.owner());
        vm.expectEmit(true, true, false, true);
        emit OffChainRunnerSet(newRunner);
        game.setOffChainRunner(newRunner);
        assertEq(game.offChainRunner(), newRunner);
    }

    function testRevertWhen_SetOffChainRunner_NotOwner() public {
        address newRunner = address(0x9876);
        vm.startPrank(PLAYER_ONE); // Not owner
        vm.expectRevert("UNAUTHORIZED"); // Owned uses UNAUTHORIZED
        game.setOffChainRunner(newRunner);
        vm.stopPrank();
    }

    function testRevertWhen_SetOffChainRunner_ZeroAddress() public {
        vm.prank(game.owner());
        vm.expectRevert(ZeroAddress.selector);
        game.setOffChainRunner(address(0));
    }

    //==============================================================//
    //                    VRF FULFILLMENT TESTS                   //
    //==============================================================//

    function testFulfillRandomness_CompletesGauntlet() public {
        uint8 gauntletSize = game.currentGauntletSize();
        uint256 entryFee = game.currentEntryFee();
        uint256 totalFeesCollected = entryFee * gauntletSize;
        uint256 expectedContractFee = (totalFeesCollected * game.feePercentage()) / 10000;
        uint256 expectedPrize = totalFeesCollected - expectedContractFee;

        _queuePlayers(gauntletSize);

        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = game.queueIndex(i);
            selectedIds[i] = pId;
            selectedIndices[i] = game.playerIndexInQueue(pId) - 1;
        }

        vm.recordLogs(); // Record logs covering start + VRF request
        vm.prank(OFF_CHAIN_RUNNER);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Extract Request IDs - Simple loop, direct decode
        uint256 vrfRequestId = 0;
        uint256 vrfRoundId = 0;
        uint256 gauntletId = 0;

        bytes32 gauntletStartedSig = keccak256("GauntletStarted(uint256,uint8,uint256,uint32[],uint256)");
        bytes32 requestedRandomnessSig = keccak256("RequestedRandomness(uint256,bytes)");

        for (uint256 i = 0; i < entries.length; i++) {
            if (
                vrfRequestId == 0 && entries[i].topics.length > 1 && entries[i].topics[0] == gauntletStartedSig
                    && uint256(entries[i].topics[1]) == gauntletId
            ) {
                // Direct decode for GauntletStarted
                (,,, uint256 reqId) = abi.decode(entries[i].data, (uint8, uint256, uint32[], uint256));
                vrfRequestId = reqId;
            }
            if (vrfRoundId == 0 && entries[i].topics.length > 0 && entries[i].topics[0] == requestedRandomnessSig) {
                // Direct decode for RequestedRandomness
                (uint256 roundId,) = abi.decode(entries[i].data, (uint256, bytes));
                vrfRoundId = roundId;
            }
            if (vrfRequestId != 0 && vrfRoundId != 0) break;
        }
        require(vrfRoundId != 0, "TEST FAIL: RequestedRandomness Round ID not found in logs");

        // Simulate VRF fulfillment
        uint256 randomnessFromBlock =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, vrfRoundId)));
        bytes memory dataWithRound = _simulateVRFFulfillment(vrfRequestId, vrfRoundId); // Assuming helper needs vrfRoundId

        // Record logs around the fulfill call to check GauntletCompleted manually
        vm.recordLogs();
        vm.prank(operator);
        game.fulfillRandomness(randomnessFromBlock, dataWithRound);
        vm.stopPrank();
        Vm.Log[] memory finalEntries = vm.getRecordedLogs(); // Get logs emitted *during* fulfill

        // Verify GauntletCompleted Event manually
        bytes32 gauntletCompletedSig = keccak256("GauntletCompleted(uint256,uint8,uint256,uint32,uint256,uint256)");
        uint256 actualPrizeAwarded = 0;
        uint256 actualFeeCollected = 0;
        uint32 actualChampionId = 0; // Initialize to 0
        bool foundCompletedEvent = false;

        for (uint256 i = 0; i < finalEntries.length; i++) {
            // Check correct event signature AND gauntletId topic
            if (
                finalEntries[i].topics.length > 2 // Need gauntletId and championId topics
                    && finalEntries[i].topics[0] == gauntletCompletedSig && uint256(finalEntries[i].topics[1]) == gauntletId // Check gauntletId
            ) {
                // Direct decode
                (uint8 size, uint256 fee, uint256 prize, uint256 collected) =
                    abi.decode(finalEntries[i].data, (uint8, uint256, uint256, uint256));
                // Extract championId from indexed topic 2
                actualChampionId = uint32(uint256(finalEntries[i].topics[2]));
                actualPrizeAwarded = prize;
                actualFeeCollected = collected;
                foundCompletedEvent = true;
                assertEq(size, gauntletSize, "Completed event size mismatch");
                assertEq(fee, entryFee, "Completed event fee mismatch");
                break; // Found the event
            }
        }
        assertTrue(foundCompletedEvent, "GauntletCompleted event not found or data mismatch for gauntletId 0");
        // Now we can assert the extracted champion ID is non-zero
        assertTrue(actualChampionId != 0, "Actual champion ID extracted from event was zero");
        assertEq(actualPrizeAwarded, expectedPrize, "Prize awarded in event mismatch");
        assertEq(actualFeeCollected, expectedContractFee, "Fee collected in event mismatch");
        assertEq(game.contractFeesCollected(), expectedContractFee, "Contract fee balance mismatch");

        // Assertions for Gauntlet 0 State
        GauntletGame.Gauntlet memory completedGauntlet = game.getGauntletData(gauntletId);
        assertEq(completedGauntlet.championId, actualChampionId, "Stored champion ID mismatch event champion ID"); // Compare stored vs event
        assertEq(uint8(completedGauntlet.state), uint8(GauntletGame.GauntletState.COMPLETED), "Gauntlet 0 state");
        assertTrue(completedGauntlet.completionTimestamp > 0, "Completion timestamp should be set");
        assertEq(game.requestToGauntletId(vrfRequestId), 0, "Request ID mapping should be cleared");

        // Check player statuses are reset
        for (uint8 i = 0; i < gauntletSize; i++) {
            assertEq(
                uint8(game.playerStatus(selectedIds[i])),
                uint8(GauntletGame.PlayerStatus.NONE),
                "Player status should be NONE after completion"
            );
            assertEq(game.playerCurrentGauntlet(selectedIds[i]), 0, "Player current gauntlet should be cleared");
        }
    }
}

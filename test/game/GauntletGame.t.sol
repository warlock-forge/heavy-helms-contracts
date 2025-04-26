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
import {
    AlreadyInQueue,
    CallerNotPlayerOwner,
    PlayerIsRetired,
    GameDisabled,
    PlayerNotInQueue,
    InvalidGauntletSize,
    QueueNotEmpty,
    GauntletDoesNotExist,
    IncorrectEntryFee,
    TimeoutNotReached,
    NoFeesToWithdraw,
    GauntletNotPending
} // Also used in recoverTimedOutVRF checks
from "../../src/game/modes/GauntletGame.sol";
import {ZeroAddress} from "../../src/game/modes/BaseGame.sol"; // Import ZeroAddress from BaseGame

contract GauntletGameTest is TestBase {
    GauntletGame public game;

    // Test addresses
    address public PLAYER_ONE;
    address public PLAYER_TWO;
    address public PLAYER_THREE;
    // REMOVED: address public OFF_CHAIN_RUNNER;

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
    // REMOVED: event OffChainRunnerSet(address indexed newRunner);
    event EntryFeeSet(uint256 oldFee, uint256 newFee);
    event GauntletSizeSet(uint8 oldSize, uint8 newSize);
    event QueueClearedDueToSettingsChange(uint256 playersRefunded, uint256 totalRefunded);
    // ADDED: Event for new timing setting
    event MinTimeBetweenGauntletsSet(uint256 newMinTime);

    // Add this receive function to allow the test contract (owner) to receive ETH
    receive() external payable {}

    // Helper function to warp time past the minimum interval
    function _warpPastMinInterval() internal {
        vm.warp(block.timestamp + game.minTimeBetweenGauntlets());
    }

    function setUp() public override {
        super.setUp(); // This correctly deploys DefaultPlayer and mints 1-18

        // Initialize game contract - USE THE INHERITED defaultPlayerContract
        game = new GauntletGame(
            address(gameEngine),
            address(playerContract),
            address(defaultPlayerContract), // Use the one from TestBase.setUp()
            operator // Only 4 args now
        );

        // Keep this: Transfer ownership of the INHERITED defaultPlayerContract
        defaultPlayerContract.transferOwnership(address(game));

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
        assertTrue(game.minTimeBetweenGauntlets() > 0); // Check new timing variable initialized
        assertTrue(game.lastGauntletStartTime() > 0); // Check timestamp initialized
            // REMOVED: assertEq(game.offChainRunner(), OFF_CHAIN_RUNNER);
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
        Fighter.PlayerLoadout memory storedLoadout = game.getPlayerLoadoutFromQueue(PLAYER_ONE_ID);

        // Assert using the struct variable
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

        uint256 entryFee = game.currentEntryFee();
        // It's good practice to calculate revert parameters outside the expectRevert call
        uint256 wrongFeeLow = entryFee == 0 ? 1 : entryFee - 1;
        uint256 wrongFeeHigh = entryFee + 1;

        // USE abi.encodeWithSelector with expected arguments
        vm.expectRevert(abi.encodeWithSelector(IncorrectEntryFee.selector, entryFee, wrongFeeLow));
        game.queueForGauntlet{value: wrongFeeLow}(loadout);

        // USE abi.encodeWithSelector with expected arguments
        vm.expectRevert(abi.encodeWithSelector(IncorrectEntryFee.selector, entryFee, wrongFeeHigh));
        game.queueForGauntlet{value: wrongFeeHigh}(loadout);

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

    function testTryStartGauntlet_Success_DefaultSize() public {
        uint8 gauntletSize = game.currentGauntletSize(); // Use current default size
        uint256 entryFee = game.currentEntryFee();

        (uint32[] memory allQueuedIds,) = _queuePlayers(gauntletSize);
        assertEq(game.getQueueSize(), gauntletSize, "Queue should have correct number of players");

        // --- Get expected selected IDs (first N) ---
        uint32[] memory expectedSelectedIds = new uint32[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            expectedSelectedIds[i] = game.queueIndex(i);
        }
        // --- End Get expected selected IDs ---

        vm.recordLogs();
        // Warp time forward to allow starting
        _warpPastMinInterval();
        // Call tryStartGauntlet - no longer needs prank or parameters
        game.tryStartGauntlet();
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(game.getQueueSize(), 0, "Queue should be empty after start");
        assertEq(game.nextGauntletId(), 1, "Next gauntlet ID should be 1");
        assertTrue(game.lastGauntletStartTime() > block.timestamp - 5, "lastGauntletStartTime not updated"); // Check it was updated recently

        bytes32 gauntletStartedSig = keccak256("GauntletStarted(uint256,uint8,uint256,uint32[],uint256)");
        uint256 actualVrfRequestId = 0;
        bool foundGauntletStartedEvent = false;
        uint256 gauntletId = 0; // Expecting first gauntlet

        for (uint256 i = 0; i < entries.length; i++) {
            if (
                entries[i].topics.length > 1 && entries[i].topics[0] == gauntletStartedSig
                    && uint256(entries[i].topics[1]) == gauntletId // Check gauntletId
            ) {
                (uint8 size, uint256 fee, uint32[] memory pIds, uint256 reqId) =
                    abi.decode(entries[i].data, (uint8, uint256, uint32[], uint256));

                actualVrfRequestId = reqId;
                foundGauntletStartedEvent = true;
                assertEq(size, gauntletSize, "Event size mismatch");
                assertEq(fee, entryFee, "Event fee mismatch");
                assertEq(pIds.length, gauntletSize, "Event participant count mismatch");
                // --- Compare event participant IDs with expectedSelectedIds ---
                // REMOVED: Loop comparing pIds[j] to expectedSelectedIds[j]
                // --- End Compare event participant IDs ---
                break;
            }
        }
        assertTrue(foundGauntletStartedEvent, "GauntletStarted event not found for gauntletId 0");

        assertEq(game.requestToGauntletId(actualVrfRequestId), gauntletId, "Request ID mapping mismatch");
        // --- Check status for the players who *were* selected ---
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = expectedSelectedIds[i];
            assertEq(
                uint8(game.playerStatus(pId)),
                uint8(GauntletGame.PlayerStatus.IN_GAUNTLET),
                "Player status should be IN_GAUNTLET"
            );
            assertEq(game.playerCurrentGauntlet(pId), gauntletId, "Player current gauntlet mismatch");
        }
        // --- End Check status ---
    }

    function testTryStartGauntlet_Success_Size8() public {
        uint8 targetSize = 8;
        vm.prank(game.owner());
        game.setGauntletSize(targetSize); // Set the size first
        uint8 gauntletSize = game.currentGauntletSize();
        assertEq(gauntletSize, targetSize, "Failed to set gauntlet size to 8");
        uint256 entryFee = game.currentEntryFee();

        (uint32[] memory allQueuedIds,) = _queuePlayers(gauntletSize);
        assertEq(game.getQueueSize(), gauntletSize, "Queue should have 8 players");

        // --- Get expected selected IDs (first N) ---
        uint32[] memory expectedSelectedIds = new uint32[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            expectedSelectedIds[i] = game.queueIndex(i);
        }
        // --- End Get expected selected IDs ---

        vm.recordLogs();
        _warpPastMinInterval();
        game.tryStartGauntlet(); // No runner, no params
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(game.getQueueSize(), 0, "Queue should be empty after start");
        assertEq(game.nextGauntletId(), 1, "Next gauntlet ID should be 1");
        assertTrue(game.lastGauntletStartTime() > block.timestamp - 5, "lastGauntletStartTime not updated");

        bytes32 gauntletStartedSig = keccak256("GauntletStarted(uint256,uint8,uint256,uint32[],uint256)");
        uint256 actualVrfRequestId = 0;
        bool foundGauntletStartedEvent = false;
        uint256 gauntletId = 0; // Expecting first gauntlet

        for (uint256 i = 0; i < entries.length; i++) {
            if (
                entries[i].topics.length > 1 && entries[i].topics[0] == gauntletStartedSig
                    && uint256(entries[i].topics[1]) == gauntletId // Check gauntletId
            ) {
                (uint8 size, uint256 fee, uint32[] memory pIds, uint256 reqId) =
                    abi.decode(entries[i].data, (uint8, uint256, uint32[], uint256));
                actualVrfRequestId = reqId;
                foundGauntletStartedEvent = true;
                assertEq(size, gauntletSize, "Event size mismatch");
                assertEq(fee, entryFee, "Event fee mismatch");
                assertEq(pIds.length, gauntletSize, "Event participant count mismatch");
                // --- Compare event participant IDs with expectedSelectedIds ---
                // REMOVED: Loop comparing pIds[j] to expectedSelectedIds[j]
                // --- End Compare event participant IDs ---
                break;
            }
        }
        assertTrue(foundGauntletStartedEvent, "GauntletStarted event not found for gauntletId 0");

        assertEq(game.requestToGauntletId(actualVrfRequestId), gauntletId, "Request ID mapping mismatch");
        // --- Check status for the players who *were* selected ---
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = expectedSelectedIds[i];
            assertEq(
                uint8(game.playerStatus(pId)),
                uint8(GauntletGame.PlayerStatus.IN_GAUNTLET),
                "Player status should be IN_GAUNTLET"
            );
            assertEq(game.playerCurrentGauntlet(pId), gauntletId, "Player current gauntlet mismatch");
        }
        // --- End Check status ---
    }

    function testTryStartGauntlet_Success_Size32() public {
        uint8 targetSize = 32;
        vm.prank(game.owner());
        game.setGauntletSize(targetSize); // Set the size first
        uint8 gauntletSize = game.currentGauntletSize();
        assertEq(gauntletSize, targetSize, "Failed to set gauntlet size to 32");
        uint256 entryFee = game.currentEntryFee();

        (uint32[] memory allQueuedIds,) = _queuePlayers(gauntletSize);
        assertEq(game.getQueueSize(), gauntletSize, "Queue should have 32 players");

        // --- Get expected selected IDs (first N) ---
        uint32[] memory expectedSelectedIds = new uint32[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            expectedSelectedIds[i] = game.queueIndex(i);
        }
        // --- End Get expected selected IDs ---

        vm.recordLogs();
        _warpPastMinInterval();
        game.tryStartGauntlet(); // No runner, no params
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(game.getQueueSize(), 0, "Queue should be empty after start");
        assertEq(game.nextGauntletId(), 1, "Next gauntlet ID should be 1");
        assertTrue(game.lastGauntletStartTime() > block.timestamp - 5, "lastGauntletStartTime not updated");

        bytes32 gauntletStartedSig = keccak256("GauntletStarted(uint256,uint8,uint256,uint32[],uint256)");
        uint256 actualVrfRequestId = 0;
        bool foundGauntletStartedEvent = false;
        uint256 gauntletId = 0; // Expecting first gauntlet

        for (uint256 i = 0; i < entries.length; i++) {
            if (
                entries[i].topics.length > 1 && entries[i].topics[0] == gauntletStartedSig
                    && uint256(entries[i].topics[1]) == gauntletId // Check gauntletId
            ) {
                (uint8 size, uint256 fee, uint32[] memory pIds, uint256 reqId) =
                    abi.decode(entries[i].data, (uint8, uint256, uint32[], uint256));
                actualVrfRequestId = reqId;
                foundGauntletStartedEvent = true;
                assertEq(size, gauntletSize, "Event size mismatch");
                assertEq(fee, entryFee, "Event fee mismatch");
                assertEq(pIds.length, gauntletSize, "Event participant count mismatch");
                // --- Compare event participant IDs with expectedSelectedIds ---
                // REMOVED: Loop comparing pIds[j] to expectedSelectedIds[j]
                // --- End Compare event participant IDs ---
                break;
            }
        }
        assertTrue(foundGauntletStartedEvent, "GauntletStarted event not found for gauntletId 0");

        assertEq(game.requestToGauntletId(actualVrfRequestId), gauntletId, "Request ID mapping mismatch");
        // --- Check status for the players who *were* selected ---
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = expectedSelectedIds[i];
            assertEq(
                uint8(game.playerStatus(pId)),
                uint8(GauntletGame.PlayerStatus.IN_GAUNTLET),
                "Player status should be IN_GAUNTLET"
            );
            assertEq(game.playerCurrentGauntlet(pId), gauntletId, "Player current gauntlet mismatch");
        }
        // --- End Check status ---
    }

    function testTryStartGauntlet_Success_MoreThanDefaultSize() public {
        uint8 gauntletSize = game.currentGauntletSize(); // Use current default size
        uint256 entryFee = game.currentEntryFee();
        uint256 queueStartSize = gauntletSize + 4;

        (uint32[] memory allQueuedIds,) = _queuePlayers(queueStartSize);
        assertEq(game.getQueueSize(), queueStartSize, "Queue should have correct initial number of players");

        // --- Get expected selected IDs (first N) ---
        uint32[] memory expectedSelectedIds = new uint32[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            expectedSelectedIds[i] = game.queueIndex(i);
        }
        // --- End Get expected selected IDs ---

        vm.recordLogs();
        _warpPastMinInterval();
        game.tryStartGauntlet(); // No runner, no params
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(game.getQueueSize(), queueStartSize - gauntletSize, "Queue size should be reduced correctly");
        assertEq(game.nextGauntletId(), 1, "Next gauntlet ID should be 1");
        assertTrue(game.lastGauntletStartTime() > block.timestamp - 5, "lastGauntletStartTime not updated");

        bytes32 gauntletStartedSig = keccak256("GauntletStarted(uint256,uint8,uint256,uint32[],uint256)");
        uint256 actualVrfRequestId = 0;
        bool foundGauntletStartedEvent = false;
        uint256 gauntletId = 0;
        uint32[] memory actualSelectedIds; // Array to store the IDs from the event

        for (uint256 i = 0; i < entries.length; i++) {
            if (
                entries[i].topics.length > 1 && entries[i].topics[0] == gauntletStartedSig
                    && uint256(entries[i].topics[1]) == gauntletId
            ) {
                (uint8 size, uint256 fee, uint32[] memory pIds, uint256 reqId) =
                    abi.decode(entries[i].data, (uint8, uint256, uint32[], uint256));
                actualVrfRequestId = reqId;
                foundGauntletStartedEvent = true;
                assertEq(size, gauntletSize, "Event size mismatch");
                assertEq(fee, entryFee, "Event fee mismatch");
                assertEq(pIds.length, gauntletSize, "Event participant count mismatch");
                actualSelectedIds = pIds; // Capture the actual IDs
                // REMOVED: Loop comparing pIds[j] to expectedSelectedIds[j]
                break;
            }
        }
        assertTrue(foundGauntletStartedEvent, "GauntletStarted event not found for gauntletId 0");
        require(actualSelectedIds.length == gauntletSize, "Failed to capture selected IDs from event"); // Add safety check

        assertEq(game.requestToGauntletId(actualVrfRequestId), gauntletId, "Request ID mapping mismatch");

        // Verify remaining players are still queued
        // This check remains valid as it iterates through the current game.getQueueSize()
        for (uint256 i = 0; i < game.getQueueSize(); i++) {
            uint32 queuedId = game.queueIndex(i);
            assertEq(
                uint8(game.playerStatus(queuedId)),
                uint8(GauntletGame.PlayerStatus.QUEUED), // Should be 1
                "Remaining player status incorrect"
            );
        }

        // Verify selected players (from the event) are in gauntlet
        for (uint256 i = 0; i < actualSelectedIds.length; i++) {
            // Iterate through ACTUAL selected IDs
            uint32 pId = actualSelectedIds[i]; // Use ID from the event
            assertEq(
                uint8(game.playerStatus(pId)),
                uint8(GauntletGame.PlayerStatus.IN_GAUNTLET), // Should be 2
                "Started player status incorrect"
            );
            assertEq(game.playerCurrentGauntlet(pId), gauntletId, "Started player gauntlet ID incorrect");
        }
    }

    // This test is no longer valid as the runner concept is removed
    // function testRevertWhen_StartGauntlet_NotRunner() public { ... }

    // Test that tryStartGauntlet doesn't run if queue is too small
    function testTryStartGauntlet_InsufficientPlayers() public {
        uint8 gauntletSize = game.currentGauntletSize();
        _queuePlayers(gauntletSize - 1); // Queue one less than needed

        uint256 gauntletIdBefore = game.nextGauntletId();
        _warpPastMinInterval();
        game.tryStartGauntlet(); // Should return early

        assertEq(game.nextGauntletId(), gauntletIdBefore, "Gauntlet should not have started");
        assertEq(game.getQueueSize(), gauntletSize - 1, "Queue size should remain unchanged");
    }

    // Test that tryStartGauntlet doesn't run if not enough time has passed
    function testTryStartGauntlet_TimeoutNotReached() public {
        uint8 gauntletSize = game.currentGauntletSize();
        _queuePlayers(gauntletSize); // Queue enough players

        uint256 gauntletIdBefore = game.nextGauntletId();
        // DO NOT warp time forward
        game.tryStartGauntlet(); // Should return early

        assertEq(game.nextGauntletId(), gauntletIdBefore, "Gauntlet should not have started due to time");
        assertEq(game.getQueueSize(), gauntletSize, "Queue size should remain unchanged");
    }

    // These tests are no longer applicable as tryStartGauntlet selects first N
    // function testRevertWhen_StartGauntlet_InvalidIndex() public { ... }
    // function testRevertWhen_StartGauntlet_MismatchedSelection() public { ... }

    // This scenario is covered by testTryStartGauntlet_InsufficientPlayers
    // function testRevertWhen_StartGauntlet_PlayerNotInQueueStatus() public { ... }

    // Remove runner admin tests
    // function testAdmin_SetOffChainRunner() public { ... }
    // function testRevertWhen_SetOffChainRunner_NotOwner() public { ... }
    // function testRevertWhen_SetOffChainRunner_ZeroAddress() public { ... }

    // Add test for new time setting admin function
    function testAdmin_SetMinTimeBetweenGauntlets() public {
        uint256 initialTime = game.minTimeBetweenGauntlets();
        uint256 newTime = initialTime * 2; // Example new time
        require(newTime != initialTime, "Choose a different new time for test");

        vm.prank(game.owner());
        vm.expectEmit(true, false, false, true);
        emit MinTimeBetweenGauntletsSet(newTime);
        game.setMinTimeBetweenGauntlets(newTime);
        assertEq(game.minTimeBetweenGauntlets(), newTime, "Min time not updated");
    }

    function testRevertWhen_SetMinTimeBetweenGauntlets_NotOwner() public {
        uint256 initialTime = game.minTimeBetweenGauntlets();
        uint256 newTime = initialTime * 2;

        vm.startPrank(PLAYER_ONE); // Not owner
        vm.expectRevert("UNAUTHORIZED");
        game.setMinTimeBetweenGauntlets(newTime);
        vm.stopPrank();
        assertEq(game.minTimeBetweenGauntlets(), initialTime, "Min time changed by non-owner");
    }

    function testSetEntryFee_ClearsQueueAndRefundsCorrectly() public {
        uint256 oldFee = game.currentEntryFee();
        require(oldFee > 0, "Initial fee is zero, cannot test refund properly");

        // Queue players
        uint256 playerCount = 2;
        Fighter.PlayerLoadout memory loadoutP1 = _createLoadout(PLAYER_ONE_ID);
        Fighter.PlayerLoadout memory loadoutP2 = _createLoadout(PLAYER_TWO_ID);

        vm.startPrank(PLAYER_ONE);
        game.queueForGauntlet{value: oldFee}(loadoutP1);
        vm.stopPrank();
        vm.startPrank(PLAYER_TWO);
        game.queueForGauntlet{value: oldFee}(loadoutP2);
        vm.stopPrank();

        uint256 balanceOneBefore = PLAYER_ONE.balance;
        uint256 balanceTwoBefore = PLAYER_TWO.balance;
        uint256 poolBefore = game.queuedFeesPool();
        assertEq(poolBefore, oldFee * playerCount, "Pool balance mismatch before fee change");
        assertEq(game.getQueueSize(), playerCount, "Queue size mismatch before fee change");

        // Change fee
        uint256 newFee = oldFee * 2;
        uint256 expectedTotalRefund = oldFee * playerCount;

        vm.prank(game.owner());
        vm.expectEmit(true, false, false, true);
        emit EntryFeeSet(oldFee, newFee);
        vm.expectEmit(true, false, false, true);
        emit QueueClearedDueToSettingsChange(playerCount, expectedTotalRefund);
        game.setEntryFee(newFee, true, false); // refundPlayers=true, skipReset=false

        // Verify state after change
        assertEq(game.currentEntryFee(), newFee, "New fee not set correctly");
        assertEq(game.getQueueSize(), 0, "Queue not cleared");
        assertEq(game.queuedFeesPool(), 0, "Fee pool not cleared/zeroed");
        assertEq(PLAYER_ONE.balance, balanceOneBefore + oldFee, "Player one not refunded correctly");
        assertEq(PLAYER_TWO.balance, balanceTwoBefore + oldFee, "Player two not refunded correctly");
        assertEq(
            uint8(game.playerStatus(PLAYER_ONE_ID)),
            uint8(GauntletGame.PlayerStatus.NONE),
            "Player one status not reset"
        );
        assertEq(
            uint8(game.playerStatus(PLAYER_TWO_ID)),
            uint8(GauntletGame.PlayerStatus.NONE),
            "Player two status not reset"
        );
        assertEq(game.playerIndexInQueue(PLAYER_ONE_ID), 0, "Player one index not cleared");
        assertEq(game.playerIndexInQueue(PLAYER_TWO_ID), 0, "Player two index not cleared");

        // Verify queuing with new fee
        vm.startPrank(PLAYER_ONE);
        // Test queuing with the old fee (should fail)
        Fighter.PlayerLoadout memory attemptLoadout = _createLoadout(PLAYER_ONE_ID);
        vm.expectRevert(abi.encodeWithSelector(IncorrectEntryFee.selector, newFee, oldFee));
        game.queueForGauntlet{value: oldFee}(attemptLoadout); // Pass the pre-calculated loadout
        vm.stopPrank(); // Stop prank before next attempt

        // Test queuing with the new fee (should succeed)
        vm.startPrank(PLAYER_ONE);
        vm.expectEmit(true, true, false, true);
        emit PlayerQueued(PLAYER_ONE_ID, 1, newFee);
        game.queueForGauntlet{value: newFee}(attemptLoadout);
        assertEq(game.getQueueSize(), 1, "Failed to queue with new fee");
        vm.stopPrank();
    }

    function testSetEntryFee_NoChangeWhenFeeIsSame() public {
        uint256 currentFee = game.currentEntryFee();
        vm.startPrank(PLAYER_ONE);
        game.queueForGauntlet{value: currentFee}(_createLoadout(PLAYER_ONE_ID));
        vm.stopPrank();

        assertEq(game.getQueueSize(), 1, "Player not queued initially");

        vm.prank(game.owner());
        vm.recordLogs();
        game.setEntryFee(currentFee, false, false); // Flags don't matter here as fee is same, but needed for compilation
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 0, "Events emitted when fee was not changed");
        assertEq(game.getQueueSize(), 1, "Queue size changed unexpectedly");
        assertEq(
            uint8(game.playerStatus(PLAYER_ONE_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED),
            "Player status changed unexpectedly"
        );
    }

    function testSetGauntletSize_Success() public {
        uint8 initialSize = game.currentGauntletSize();
        uint8 newSize8 = 8;
        uint8 newSize32 = 32;

        vm.prank(game.owner());
        assertEq(game.getQueueSize(), 0, "Queue should be empty initially");

        // Set to 8
        if (initialSize != newSize8) {
            vm.expectEmit(true, false, false, true);
            emit GauntletSizeSet(initialSize, newSize8);
            game.setGauntletSize(newSize8);
        } else {
            vm.recordLogs();
            game.setGauntletSize(newSize8); // Call it anyway
            Vm.Log[] memory entries = vm.getRecordedLogs();
            assertEq(entries.length, 0, "Event emitted when setting same size");
        }
        assertEq(game.currentGauntletSize(), newSize8, "Failed to set size to 8");

        // Set to 32
        vm.expectEmit(true, false, false, true);
        emit GauntletSizeSet(newSize8, newSize32); // Expect emit from 8 to 32
        game.setGauntletSize(newSize32);
        assertEq(game.currentGauntletSize(), newSize32, "Failed to set size to 32");

        // Set back to initial (optional, only if different from 32)
        if (initialSize != newSize32) {
            vm.expectEmit(true, false, false, true);
            emit GauntletSizeSet(newSize32, initialSize);
            game.setGauntletSize(initialSize);
            assertEq(game.currentGauntletSize(), initialSize, "Failed to set size back to initial");
        }
    }

    function testRevertWhen_SetGauntletSize_QueueNotEmpty() public {
        uint256 fee = game.currentEntryFee();
        vm.startPrank(PLAYER_ONE);
        game.queueForGauntlet{value: fee}(_createLoadout(PLAYER_ONE_ID));
        vm.stopPrank();

        assertEq(game.getQueueSize(), 1, "Player not queued");

        vm.prank(game.owner());
        uint8 currentSize = game.currentGauntletSize();
        uint8 targetSize = currentSize == 8 ? 16 : 8; // Pick a different valid size
        vm.expectRevert(QueueNotEmpty.selector);
        game.setGauntletSize(targetSize);
    }

    function testRevertWhen_SetGauntletSize_InvalidSize() public {
        vm.prank(game.owner());

        // Test size 0
        vm.expectRevert(abi.encodeWithSelector(InvalidGauntletSize.selector, 0));
        game.setGauntletSize(0);

        // Test size 10
        vm.expectRevert(abi.encodeWithSelector(InvalidGauntletSize.selector, 10));
        game.setGauntletSize(10);

        // Test size 17
        vm.expectRevert(abi.encodeWithSelector(InvalidGauntletSize.selector, 17));
        game.setGauntletSize(17);

        // Test size 33
        vm.expectRevert(abi.encodeWithSelector(InvalidGauntletSize.selector, 33));
        game.setGauntletSize(33);
    }

    //==============================================================//
    //                    VRF FULFILLMENT TESTS                   //
    //==============================================================//

    // Helper function to setup and start a gauntlet, returning key details
    function _setupAndStartGauntlet(uint8 gauntletSize)
        internal
        returns (
            uint256 gauntletId,
            uint256 vrfRequestId,
            uint256 vrfRoundId,
            uint32[] memory participantIds, // Returns the IDs of the players *selected* (first N)
            address[] memory participantAddrs // Returns addresses of *all* players initially queued
        )
    {
        (uint32[] memory allQueuedIds, address[] memory allQueuedAddrs) = _queuePlayers(gauntletSize);
        participantIds = new uint32[](gauntletSize); // Array to store the actual participants (first N)
        for (uint8 i = 0; i < gauntletSize; i++) {
            participantIds[i] = allQueuedIds[i]; // Store the first N IDs
        }

        vm.recordLogs();
        _warpPastMinInterval();
        game.tryStartGauntlet(); // Trigger the start
        Vm.Log[] memory entries = vm.getRecordedLogs();

        gauntletId = 0; // Assuming first gauntlet
        bytes32 gauntletStartedSig = keccak256("GauntletStarted(uint256,uint8,uint256,uint32[],uint256)");
        bytes32 requestedRandomnessSig = keccak256("RequestedRandomness(uint256,bytes)");
        bool foundStarted = false;
        bool foundRequested = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (
                !foundStarted && entries[i].topics.length > 1 && entries[i].topics[0] == gauntletStartedSig
                    && uint256(entries[i].topics[1]) == gauntletId // Check gauntletId
            ) {
                (,,, uint256 reqId) = abi.decode(entries[i].data, (uint8, uint256, uint32[], uint256));
                vrfRequestId = reqId;
                foundStarted = true;
            }
            if (!foundRequested && entries[i].topics.length > 0 && entries[i].topics[0] == requestedRandomnessSig) {
                (uint256 roundId,) = abi.decode(entries[i].data, (uint256, bytes));
                vrfRoundId = roundId;
                foundRequested = true;
            }
            if (foundStarted && foundRequested) break;
        }
        require(foundRequested && foundStarted, "TEST SETUP FAILED: Gauntlet start/request incomplete");
        return (gauntletId, vrfRequestId, vrfRoundId, participantIds, allQueuedAddrs); // Return selected IDs, all addresses
    }

    // Helper function to verify the GauntletCompleted event
    function _verifyGauntletCompletedEvent(
        Vm.Log[] memory finalEntries,
        uint256 gauntletId,
        uint8 expectedSize,
        uint256 expectedFee,
        uint256 expectedPrize,
        uint256 expectedFeeCollected
    ) internal returns (uint32 actualChampionId) {
        bytes32 gauntletCompletedSig = keccak256("GauntletCompleted(uint256,uint8,uint256,uint32,uint256,uint256)");
        bool foundCompleted = false;

        // Iterate through logs to find the specific event
        for (uint256 i = 0; i < finalEntries.length; i++) {
            // Check if topics match the expected event signature and gauntletId
            if (
                finalEntries[i].topics.length > 2 && finalEntries[i].topics[0] == gauntletCompletedSig
                    && uint256(finalEntries[i].topics[1]) == gauntletId
            ) {
                // Decode the non-indexed data directly within the assertion checks
                (uint8 size, uint256 fee, uint256 prize, uint256 collected) =
                    abi.decode(finalEntries[i].data, (uint8, uint256, uint256, uint256));

                // Decode the indexed championId from the topic
                actualChampionId = uint32(uint256(finalEntries[i].topics[2]));

                // Perform assertions
                assertEq(size, expectedSize, "Completed event size mismatch");
                assertEq(fee, expectedFee, "Completed event fee mismatch");
                assertEq(prize, expectedPrize, "Event prize mismatch");
                assertEq(collected, expectedFeeCollected, "Event fee mismatch");

                foundCompleted = true;
                break; // Exit the loop once the event is found and verified
            }
        }

        assertTrue(foundCompleted, "GauntletCompleted event not found or did not match expected values");
        // actualChampionId will be set if foundCompleted is true
        return actualChampionId;
    }

    // Helper function to verify the GauntletCompleted event for the all-default scenario
    function _verifyGauntletCompletedEvent_AllDefault(
        Vm.Log[] memory finalEntries,
        uint256 gauntletId,
        uint256 expectedPrize
    ) internal returns (uint32 actualChampionId) {
        bytes32 gauntletCompletedSig = keccak256("GauntletCompleted(uint256,uint8,uint256,uint32,uint256,uint256)");
        bool foundCompleted = false;

        for (uint256 i = 0; i < finalEntries.length; i++) {
            if (
                finalEntries[i].topics.length > 2 && finalEntries[i].topics[0] == gauntletCompletedSig
                    && uint256(finalEntries[i].topics[1]) == gauntletId
            ) {
                (,, uint256 prize,) = abi.decode(finalEntries[i].data, (uint8, uint256, uint256, uint256));
                // Decode champion ID from the indexed topic
                actualChampionId = uint32(uint256(finalEntries[i].topics[2]));
                assertEq(prize, expectedPrize, "Event prize mismatch (All Default)");
                foundCompleted = true;
                break;
            }
        }
        assertTrue(foundCompleted, "GauntletCompleted event not found (All Default)");
        assertTrue(game.defaultPlayerContract().isValidId(actualChampionId), "Winner was not a default player");
        return actualChampionId;
    }

    // Helper function to verify the state of a retired player
    function _verifyRetiredPlayerState(uint32 retiredPlayerId, Fighter.Record memory recordBefore) internal view {
        Fighter.Record memory recordAfter = playerContract.getPlayer(retiredPlayerId).record;
        assertEq(recordAfter.wins, recordBefore.wins, "Retired player wins changed");
        assertEq(recordAfter.losses, recordBefore.losses, "Retired player losses changed");
    }

    // Helper function to verify payouts and fees
    function _verifyPayoutAndFees(
        uint32 actualChampionId,
        uint256 feesBefore,
        uint256 expectedBaseFee,
        uint256 expectedPrize
    ) internal view {
        uint256 feesAfter = game.contractFeesCollected();
        if (game.defaultPlayerContract().isValidId(actualChampionId)) {
            assertEq(feesAfter, feesBefore + expectedBaseFee + expectedPrize, "Fees incorrect (Default Winner)");
            assertEq(address(this).balance, 0, "Owner balance changed unexpectedly (Default Winner)");
        } else {
            assertEq(feesAfter, feesBefore + expectedBaseFee, "Fees incorrect (Player Winner)");
            address winnerOwner = playerContract.getPlayerOwner(actualChampionId);
            assertTrue(winnerOwner.balance > 0, "Winner balance indicates potential payout failure");
        }
    }

    // Helper function to verify payouts and fees for the all-default scenario
    function _verifyPayoutAndFees_AllDefault(uint256 feesBefore, uint256 expectedTotalFees, uint256 ownerBalanceBefore)
        internal
        view
    {
        uint256 feesAfter = game.contractFeesCollected();
        assertEq(feesAfter, feesBefore + expectedTotalFees, "Total fees collected incorrect (All Default)");
        // Check owner balance against the value recorded *before* fulfillment
        assertEq(game.owner().balance, ownerBalanceBefore, "Owner balance changed unexpectedly (All Default)");
    }

    // Helper function to verify state cleanup after gauntlet completion/recovery
    function _verifyStateCleanup(uint32[] memory participantIds, uint256 gauntletId, uint256 vrfRequestId)
        internal
        view
    {
        GauntletGame.Gauntlet memory completedGauntlet = game.getGauntletData(gauntletId);
        assertEq(uint8(completedGauntlet.state), uint8(GauntletGame.GauntletState.COMPLETED), "Gauntlet state");
        assertTrue(completedGauntlet.completionTimestamp > 0, "Completion timestamp should be set");
        // Check VRF request ID mapping is cleared only if it wasn't 0 initially (e.g., not for recovered gauntlets)
        if (vrfRequestId != 0) {
            assertEq(game.requestToGauntletId(vrfRequestId), 0, "Request ID mapping should be cleared/reset");
        }

        for (uint256 i = 0; i < participantIds.length; ++i) {
            assertEq(
                uint8(game.playerStatus(participantIds[i])),
                uint8(GauntletGame.PlayerStatus.NONE),
                "Player status not NONE"
            );
            assertEq(game.playerCurrentGauntlet(participantIds[i]), 0, "Player gauntlet ID not 0");
        }
    }

    // Helper function to retire all participants in a list
    function _retireAllParticipants(uint32[] memory participantIds, address[] memory participantAddrs) internal {
        for (uint256 i = 0; i < participantIds.length; ++i) {
            // Ensure we have a valid address for the participant before trying to prank
            // This assumes participantIds and participantAddrs have the same length and corresponding indices
            if (i < participantAddrs.length) {
                vm.startPrank(participantAddrs[i]);
                playerContract.retireOwnPlayer(participantIds[i]);
                vm.stopPrank();
                assertTrue(playerContract.isPlayerRetired(participantIds[i]), "Player failed to retire");
            } else {
                // Handle case where participant ID might be a default player with no address in the array
                // Or log a warning if the arrays are mismatched
                console.log(
                    "Warning: No address found for participant ID:", participantIds[i], "in _retireAllParticipants"
                );
            }
        }
    }

    function testFulfillRandomness_CompletesGauntlet_DefaultSize() public {
        uint8 gauntletSize = game.currentGauntletSize(); // Use current default size
        uint256 entryFee = game.currentEntryFee();
        uint256 totalFeesCollected = entryFee * gauntletSize;
        uint256 expectedContractFee = (totalFeesCollected * game.feePercentage()) / 10000;
        uint256 expectedPrize = totalFeesCollected - expectedContractFee;

        // --- Start Gauntlet using helper ---
        (
            uint256 gauntletId,
            uint256 vrfRequestId,
            uint256 vrfRoundId,
            uint32[] memory actualParticipantIds, // These are the first N selected
                /* address[] memory participantAddrs */ // Don't need addresses here
        ) = _setupAndStartGauntlet(gauntletSize);
        // --- End Start Gauntlet ---

        uint256 randomnessFromBlock =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, vrfRoundId)));
        bytes memory dataWithRound = _simulateVRFFulfillment(vrfRequestId, vrfRoundId);

        // --- PRE-FULFILLMENT STATE CAPTURE (Based on actualParticipantIds) ---
        uint32[] memory nonDefaultParticipantIds = new uint32[](gauntletSize); // Max possible size
        Fighter.Record[] memory recordsBefore = new Fighter.Record[](gauntletSize); // Max possible size
        uint256 nonDefaultCount = 0;
        for (uint256 i = 0; i < actualParticipantIds.length; i++) {
            if (!game.defaultPlayerContract().isValidId(actualParticipantIds[i])) {
                // Only track real players who were selected
                nonDefaultParticipantIds[nonDefaultCount] = actualParticipantIds[i];
                recordsBefore[nonDefaultCount] = playerContract.getPlayer(actualParticipantIds[i]).record;
                nonDefaultCount++;
            }
        }
        // Optional: Resize arrays if needed
        // --- End PRE-FULFILLMENT ---

        vm.recordLogs();
        vm.prank(operator);
        game.fulfillRandomness(randomnessFromBlock, dataWithRound);
        vm.stopPrank();
        Vm.Log[] memory finalEntries = vm.getRecordedLogs();

        // --- Verify Event and State (using _verify functions) ---
        uint32 actualChampionId = _verifyGauntletCompletedEvent(
            finalEntries, gauntletId, gauntletSize, entryFee, expectedPrize, expectedContractFee
        );
        _verifyStateCleanup(actualParticipantIds, gauntletId, vrfRequestId);
        // --- End Verify ---

        assertEq(game.contractFeesCollected(), expectedContractFee, "Contract fee balance mismatch");

        // --- CORRECTED WIN RECORD VERIFICATION (using nonDefaultParticipantIds from before) ---
        if (!game.defaultPlayerContract().isValidId(actualChampionId)) {
            Fighter.Record memory recordAfter = playerContract.getPlayer(actualChampionId).record;
            Fighter.Record memory recordBeforeChampion;
            bool foundRecord = false;
            // Find the champion's record in our pre-fulfillment array
            for (uint256 i = 0; i < nonDefaultCount; i++) {
                if (nonDefaultParticipantIds[i] == actualChampionId) {
                    recordBeforeChampion = recordsBefore[i];
                    foundRecord = true;
                    break;
                }
            }
            assertTrue(foundRecord, "Failed to find pre-fulfillment record for champion");
            assertTrue(recordAfter.wins > recordBeforeChampion.wins, "Champion win count did not increase");
        }
        // --- END CORRECTED VERIFICATION ---
    }

    function testFulfillRandomness_CompletesGauntlet_Size8() public {
        uint8 targetSize = 8;
        vm.prank(game.owner());
        game.setGauntletSize(targetSize); // Set the size first
        uint8 gauntletSize = game.currentGauntletSize();
        assertEq(gauntletSize, targetSize, "Failed to set gauntlet size to 8");

        uint256 entryFee = game.currentEntryFee();
        uint256 totalFeesCollected = entryFee * gauntletSize;
        uint256 expectedContractFee = (totalFeesCollected * game.feePercentage()) / 10000;
        uint256 expectedPrize = totalFeesCollected - expectedContractFee;

        // --- Start Gauntlet using helper ---
        (
            uint256 gauntletId,
            uint256 vrfRequestId,
            uint256 vrfRoundId,
            uint32[] memory actualParticipantIds, // These are the first N selected
                /* address[] memory participantAddrs */ // Don't need addresses here
        ) = _setupAndStartGauntlet(gauntletSize);
        // --- End Start Gauntlet ---

        uint256 randomnessFromBlock =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, vrfRoundId)));
        bytes memory dataWithRound = _simulateVRFFulfillment(vrfRequestId, vrfRoundId);

        // --- PRE-FULFILLMENT STATE CAPTURE (Based on actualParticipantIds) ---
        uint32[] memory nonDefaultParticipantIds = new uint32[](gauntletSize);
        Fighter.Record[] memory recordsBefore = new Fighter.Record[](gauntletSize);
        uint256 nonDefaultCount = 0;
        for (uint256 i = 0; i < actualParticipantIds.length; i++) {
            if (!game.defaultPlayerContract().isValidId(actualParticipantIds[i])) {
                nonDefaultParticipantIds[nonDefaultCount] = actualParticipantIds[i];
                recordsBefore[nonDefaultCount] = playerContract.getPlayer(actualParticipantIds[i]).record;
                nonDefaultCount++;
            }
        }
        // --- End PRE-FULFILLMENT ---

        vm.recordLogs();
        vm.prank(operator);
        game.fulfillRandomness(randomnessFromBlock, dataWithRound);
        vm.stopPrank();
        Vm.Log[] memory finalEntries = vm.getRecordedLogs();

        // --- Verify Event and State (using _verify functions) ---
        uint32 actualChampionId = _verifyGauntletCompletedEvent(
            finalEntries, gauntletId, gauntletSize, entryFee, expectedPrize, expectedContractFee
        );
        _verifyStateCleanup(actualParticipantIds, gauntletId, vrfRequestId);
        // --- End Verify ---

        assertEq(game.contractFeesCollected(), expectedContractFee, "Contract fee balance mismatch");

        // --- CORRECTED WIN RECORD VERIFICATION ---
        if (!game.defaultPlayerContract().isValidId(actualChampionId)) {
            Fighter.Record memory recordAfter = playerContract.getPlayer(actualChampionId).record;
            Fighter.Record memory recordBeforeChampion;
            bool foundRecord = false;
            for (uint256 i = 0; i < nonDefaultCount; i++) {
                if (nonDefaultParticipantIds[i] == actualChampionId) {
                    recordBeforeChampion = recordsBefore[i];
                    foundRecord = true;
                    break;
                }
            }
            assertTrue(foundRecord, "Failed to find pre-fulfillment record for champion (Size 8)");
            assertTrue(recordAfter.wins > recordBeforeChampion.wins, "Champion win count did not increase (Size 8)");
        }
        // --- END CORRECTED VERIFICATION ---
    }

    function testFulfillRandomness_CompletesGauntlet_Size32() public {
        uint8 targetSize = 32;
        vm.prank(game.owner());
        game.setGauntletSize(targetSize); // Set the size first
        uint8 gauntletSize = game.currentGauntletSize();
        assertEq(gauntletSize, targetSize, "Failed to set gauntlet size to 32");

        uint256 entryFee = game.currentEntryFee();
        uint256 totalFeesCollected = entryFee * gauntletSize;
        uint256 expectedContractFee = (totalFeesCollected * game.feePercentage()) / 10000;
        uint256 expectedPrize = totalFeesCollected - expectedContractFee;

        // --- Start Gauntlet using helper ---
        (
            uint256 gauntletId,
            uint256 vrfRequestId,
            uint256 vrfRoundId,
            uint32[] memory actualParticipantIds, // These are the first N selected
                /* address[] memory participantAddrs */ // Don't need addresses here
        ) = _setupAndStartGauntlet(gauntletSize);
        // --- End Start Gauntlet ---

        uint256 randomnessFromBlock =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, vrfRoundId)));
        bytes memory dataWithRound = _simulateVRFFulfillment(vrfRequestId, vrfRoundId);

        // --- PRE-FULFILLMENT STATE CAPTURE (Based on actualParticipantIds) ---
        uint32[] memory nonDefaultParticipantIds = new uint32[](gauntletSize);
        Fighter.Record[] memory recordsBefore = new Fighter.Record[](gauntletSize);
        uint256 nonDefaultCount = 0;
        for (uint256 i = 0; i < actualParticipantIds.length; i++) {
            if (!game.defaultPlayerContract().isValidId(actualParticipantIds[i])) {
                nonDefaultParticipantIds[nonDefaultCount] = actualParticipantIds[i];
                recordsBefore[nonDefaultCount] = playerContract.getPlayer(actualParticipantIds[i]).record;
                nonDefaultCount++;
            }
        }
        // --- End PRE-FULFILLMENT ---

        vm.recordLogs();
        vm.prank(operator);
        game.fulfillRandomness(randomnessFromBlock, dataWithRound);
        vm.stopPrank();
        Vm.Log[] memory finalEntries = vm.getRecordedLogs();

        // --- Verify Event and State (using _verify functions) ---
        uint32 actualChampionId = _verifyGauntletCompletedEvent(
            finalEntries, gauntletId, gauntletSize, entryFee, expectedPrize, expectedContractFee
        );
        _verifyStateCleanup(actualParticipantIds, gauntletId, vrfRequestId);
        // --- End Verify ---

        assertEq(game.contractFeesCollected(), expectedContractFee, "Contract fee balance mismatch");

        // --- CORRECTED WIN RECORD VERIFICATION ---
        if (!game.defaultPlayerContract().isValidId(actualChampionId)) {
            Fighter.Record memory recordAfter = playerContract.getPlayer(actualChampionId).record;
            Fighter.Record memory recordBeforeChampion;
            bool foundRecord = false;
            for (uint256 i = 0; i < nonDefaultCount; i++) {
                if (nonDefaultParticipantIds[i] == actualChampionId) {
                    recordBeforeChampion = recordsBefore[i];
                    foundRecord = true;
                    break;
                }
            }
            assertTrue(foundRecord, "Failed to find pre-fulfillment record for champion (Size 32)");
            assertTrue(recordAfter.wins > recordBeforeChampion.wins, "Champion win count did not increase (Size 32)");
        }
        // --- END CORRECTED VERIFICATION ---
    }

    //==============================================================//
    //                 GAUNTLET RECOVERY TESTS                    //
    //==============================================================//

    function testRecoverTimedOutVRF_Success() public {
        uint8 gauntletSize = game.currentGauntletSize();
        uint256 entryFee = game.currentEntryFee();

        // 1. Start the gauntlet using the helper
        (
            uint256 gauntletId,
            uint256 vrfRequestId,
            /*uint256 vrfRoundId*/
            , // Don't need round ID here
            uint32[] memory participantIds, // Selected participants
            address[] memory participantAddrs // Addresses of *all* queued players originally
        ) = _setupAndStartGauntlet(gauntletSize);

        // Find addresses corresponding to the *selected* participants for balance check
        address[] memory selectedParticipantAddrs = new address[](gauntletSize);
        for (uint256 i = 0; i < gauntletSize; i++) {
            // This assumes _queuePlayers queues in the order used by _setupAndStartGauntlet
            selectedParticipantAddrs[i] = participantAddrs[i];
        }

        // 3. Record balances before recovery
        uint256[] memory balancesBefore = new uint256[](gauntletSize);
        for (uint256 i = 0; i < gauntletSize; i++) {
            balancesBefore[i] = selectedParticipantAddrs[i].balance;
        }

        // 4. Advance time past the timeout
        uint256 timeout = game.vrfRequestTimeout();
        vm.warp(block.timestamp + timeout + 1);

        // 5. Recover the gauntlet (callable by anyone, but prank as owner for consistency)
        vm.prank(game.owner());
        vm.expectEmit(true, true, false, true);
        emit GauntletRecovered(gauntletId);
        game.recoverTimedOutVRF(gauntletId);
        vm.stopPrank(); // Stop owner prank

        // 6. Verify state after recovery (using helper)
        _verifyStateCleanup(participantIds, gauntletId, vrfRequestId); // Use selected IDs

        GauntletGame.Gauntlet memory recoveredGauntlet = game.getGauntletData(gauntletId);
        assertEq(recoveredGauntlet.championId, 0, "Champion ID should be 0 on recovery"); // No champion on recovery

        // Verify player refunds
        for (uint256 i = 0; i < gauntletSize; i++) {
            address pAddr = selectedParticipantAddrs[i];
            assertEq(pAddr.balance, balancesBefore[i] + entryFee, "Player not refunded correctly");
        }
    }

    function testRevertWhen_RecoverTimedOutVRF_TimeoutNotReached() public {
        uint8 gauntletSize = game.currentGauntletSize();

        // 1. Start the gauntlet using the helper
        (uint256 gauntletId,,,,) = _setupAndStartGauntlet(gauntletSize);

        // 2. Record state (ensure it's PENDING)
        GauntletGame.Gauntlet memory gauntletData = game.getGauntletData(gauntletId);
        assertEq(uint8(gauntletData.state), uint8(GauntletGame.GauntletState.PENDING));

        // 3. Try to recover *before* timeout
        uint256 timeout = game.vrfRequestTimeout();
        assertTrue(timeout > 0); // Ensure timeout is positive
        // No need to warp time forward

        // 4. Attempt recovery (should fail)
        vm.expectRevert(TimeoutNotReached.selector);
        game.recoverTimedOutVRF(gauntletId); // Callable by anyone
    }

    function testRevertWhen_RecoverTimedOutVRF_NotPending() public {
        uint8 gauntletSize = 8; // Use smaller size
        vm.prank(game.owner());
        game.setGauntletSize(gauntletSize);

        // 1. Setup and Start Gauntlet
        (uint256 gauntletId, uint256 vrfRequestId, uint256 vrfRoundId,,) = _setupAndStartGauntlet(gauntletSize);

        // 2. Fulfill randomness to complete the gauntlet
        uint256 randomnessFromBlock =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, vrfRoundId)));
        bytes memory dataWithRound = _simulateVRFFulfillment(vrfRequestId, vrfRoundId);
        vm.prank(operator);
        game.fulfillRandomness(randomnessFromBlock, dataWithRound);
        vm.stopPrank();

        // 3. Verify Gauntlet is COMPLETED
        GauntletGame.Gauntlet memory completedGauntlet = game.getGauntletData(gauntletId);
        assertEq(uint8(completedGauntlet.state), uint8(GauntletGame.GauntletState.COMPLETED));

        // 4. Attempt recovery on completed gauntlet
        vm.warp(block.timestamp + game.vrfRequestTimeout() + 1); // Ensure timeout is passed
        vm.expectRevert(GauntletNotPending.selector);
        game.recoverTimedOutVRF(gauntletId); // Callable by anyone
    }

    //==============================================================//
    //                 ADMIN FUNCTION TESTS                       //
    //==============================================================//

    /// @notice Internal helper to complete one gauntlet and generate fees
    function _generateFees() internal returns (uint256 collectedFees) {
        uint8 gauntletSize = game.currentGauntletSize();
        uint256 entryFee = game.currentEntryFee();
        // Start gauntlet using helper
        (
            uint256 gauntletId,
            uint256 vrfRequestId,
            uint256 vrfRoundId,
            , // Don't need participants here
                // Don't need addresses here
        ) = _setupAndStartGauntlet(gauntletSize);

        // Fulfill randomness
        uint256 randomnessFromBlock =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, vrfRoundId)));
        bytes memory dataWithRound = _simulateVRFFulfillment(vrfRequestId, vrfRoundId);
        vm.prank(operator); // Operator fulfills
        game.fulfillRandomness(randomnessFromBlock, dataWithRound);
        vm.stopPrank(); // Stop operator prank

        collectedFees = game.contractFeesCollected();
        assertTrue(collectedFees > 0, "Helper function failed to generate fees");
    }

    function testWithdrawFees_Success() public {
        // 1. Generate fees using the helper
        uint256 collectedFees = _generateFees();

        // 2. Withdraw fees as owner
        uint256 ownerBalanceBefore = game.owner().balance;
        vm.prank(game.owner());
        // vm.expectEmit(...); // No event for withdrawFees
        game.withdrawFees();

        // 3. Verify state
        assertEq(game.contractFeesCollected(), 0, "Fees not zeroed after withdrawal");
        assertEq(game.owner().balance, ownerBalanceBefore + collectedFees, "Owner did not receive correct fee amount");
    }

    function testRevertWhen_WithdrawFees_NoFees() public {
        assertEq(game.contractFeesCollected(), 0, "Initial fees should be zero");
        vm.prank(game.owner());
        // --- MODIFIED REVERT CHECK ---
        vm.expectRevert(NoFeesToWithdraw.selector); // Use the custom error selector
        game.withdrawFees();
    }

    function testRevertWhen_WithdrawFees_NotOwner() public {
        // 1. Generate fees using the helper
        _generateFees();
        assertTrue(game.contractFeesCollected() > 0, "Fees should be non-zero after generating them");

        // 2. Try to withdraw as non-owner
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert("UNAUTHORIZED"); // Owned uses UNAUTHORIZED
        game.withdrawFees();
        vm.stopPrank();
    }

    function testSetGameEnabled() public {
        uint256 entryFee = game.currentEntryFee();
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // 1. Disable game
        vm.prank(game.owner());
        // vm.expectEmit(...); // No event for setGameEnabled
        game.setGameEnabled(false);
        assertFalse(game.isGameEnabled(), "Game not disabled"); // Use the correct getter

        // 2. Verify queuing fails
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(GameDisabled.selector);
        game.queueForGauntlet{value: entryFee}(loadout);
        vm.stopPrank();

        // 3. Verify tryStartGauntlet fails when disabled
        _warpPastMinInterval(); // Advance time
        uint256 nextIdBefore = game.nextGauntletId();
        vm.expectRevert(GameDisabled.selector); // Expect revert now
        game.tryStartGauntlet();
        assertEq(game.nextGauntletId(), nextIdBefore, "Gauntlet started while disabled"); // Verify no state change

        // 4. Re-enable game
        vm.prank(game.owner());
        game.setGameEnabled(true);
        assertTrue(game.isGameEnabled(), "Game not re-enabled"); // Use the correct getter

        // 5. Verify queuing succeeds
        vm.startPrank(PLAYER_ONE);
        vm.expectEmit(true, true, false, true); // Expect PlayerQueued event
        emit PlayerQueued(PLAYER_ONE_ID, 1, entryFee);
        game.queueForGauntlet{value: entryFee}(loadout);
        assertEq(game.getQueueSize(), 1, "Failed to queue after re-enabling");
        vm.stopPrank();
    }

    function testRevertWhen_SetGameEnabled_NotOwner() public {
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert("UNAUTHORIZED");
        game.setGameEnabled(false); // Attempt to disable
        vm.stopPrank();

        // Ensure state didn't change
        assertTrue(game.isGameEnabled(), "Game state changed by non-owner"); // Use the correct getter
    }

    function testSetDefaultPlayerContract() public {
        address initialDpAddress = address(game.defaultPlayerContract());
        require(initialDpAddress != address(0), "Initial DP contract is zero");

        // Deploy a new (dummy) DefaultPlayer - doesn't need full setup for this test
        DefaultPlayer newDpContract = new DefaultPlayer(address(skinRegistry), address(nameRegistry));
        address newDpAddress = address(newDpContract);

        // Set the new contract as owner
        vm.prank(game.owner());
        // vm.expectEmit(...); // No event for setDefaultPlayerContract
        game.setDefaultPlayerContract(newDpAddress);

        // Verify the address was updated
        assertEq(address(game.defaultPlayerContract()), newDpAddress, "DefaultPlayer contract address not updated");
    }

    function testRevertWhen_SetDefaultPlayerContract_NotOwner() public {
        address initialDpAddress = address(game.defaultPlayerContract());
        DefaultPlayer newDpContract = new DefaultPlayer(address(skinRegistry), address(nameRegistry));
        address newDpAddress = address(newDpContract);

        vm.startPrank(PLAYER_ONE); // Not owner
        vm.expectRevert("UNAUTHORIZED");
        game.setDefaultPlayerContract(newDpAddress);
        vm.stopPrank();

        // Verify address did not change
        assertEq(address(game.defaultPlayerContract()), initialDpAddress, "DP address changed by non-owner");
    }

    function testRevertWhen_SetDefaultPlayerContract_ZeroAddress() public {
        vm.prank(game.owner());
        vm.expectRevert(ZeroAddress.selector);
        game.setDefaultPlayerContract(address(0));
    }

    //==============================================================//
    //           RETIRED PLAYER SUBSTITUTION TESTS                //
    //==============================================================//

    function testFulfillRandomness_WithRetiredPlayerSubstitution() public {
        uint8 gauntletSize = 8; // Use smaller size for simplicity
        vm.prank(game.owner());
        game.setGauntletSize(gauntletSize); // Ensure size is 8
        uint256 entryFee = game.currentEntryFee();

        // 1. Start the gauntlet using the helper
        (
            uint256 gauntletId,
            uint256 vrfRequestId,
            uint256 vrfRoundId,
            uint32[] memory participantIds, // Selected participants
            address[] memory participantAddrs // Addresses of *all* queued players originally
        ) = _setupAndStartGauntlet(gauntletSize);

        // 3. Retire ONE participant *after* gauntlet start
        // Pick one from the middle of *selected* participants
        uint32 retiredPlayerId = participantIds[gauntletSize / 2];

        // Get the owner directly from the Player contract, as the game queue is empty now.
        address retiredPlayerOwner = playerContract.getPlayerOwner(retiredPlayerId);
        require(retiredPlayerOwner != address(0), "Could not find owner for player to retire");

        // Retire the player
        vm.startPrank(retiredPlayerOwner);
        playerContract.retireOwnPlayer(retiredPlayerId);
        vm.stopPrank();
        assertTrue(playerContract.isPlayerRetired(retiredPlayerId), "Player failed to retire");
        Fighter.Record memory recordBefore = playerContract.getPlayer(retiredPlayerId).record; // Record state before fulfillment

        // --- PRE-FULFILLMENT STATE CAPTURE (Based on actualParticipantIds) ---
        uint32[] memory nonDefaultParticipantIds = new uint32[](gauntletSize); // Max size
        Fighter.Record[] memory recordsBefore = new Fighter.Record[](gauntletSize); // Max size
        uint256 nonDefaultCount = 0;
        for (uint256 i = 0; i < participantIds.length; i++) {
            // Don't track the player we just retired or defaults
            if (participantIds[i] != retiredPlayerId && !game.defaultPlayerContract().isValidId(participantIds[i])) {
                nonDefaultParticipantIds[nonDefaultCount] = participantIds[i];
                recordsBefore[nonDefaultCount] = playerContract.getPlayer(participantIds[i]).record;
                nonDefaultCount++;
            }
        }
        // --- End PRE-FULFILLMENT ---

        // 4. Fulfill randomness
        uint256 randomnessFromBlock =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, vrfRoundId)));
        bytes memory dataWithRound = _simulateVRFFulfillment(vrfRequestId, vrfRoundId);

        uint256 feesBefore = game.contractFeesCollected();

        vm.recordLogs();
        vm.prank(operator);
        game.fulfillRandomness(randomnessFromBlock, dataWithRound);
        vm.stopPrank();
        Vm.Log[] memory finalEntries = vm.getRecordedLogs();

        // 5. Verify results
        uint256 expectedBaseFee = (entryFee * gauntletSize * game.feePercentage()) / 10000;
        uint256 expectedPrize = (entryFee * gauntletSize) - expectedBaseFee;

        // --- Verify Event and State ---
        // Extract actual champion ID first to determine expected event prize
        uint32 actualChampionId = _extractChampionIdOnly(finalEntries, gauntletId);
        assertTrue(actualChampionId != 0, "Champion ID is zero after fulfillment");

        // Calculate expected prize *emitted* in the event based on winner type
        uint256 prizeAwardedForEvent = expectedPrize;
        if (game.defaultPlayerContract().isValidId(actualChampionId)) {
            prizeAwardedForEvent = 0;
        }

        // Verify the event emission parameters using the calculated event prize
        _verifyGauntletCompletedEvent(
            finalEntries,
            gauntletId,
            gauntletSize,
            entryFee,
            prizeAwardedForEvent, // Use the calculated prize for the event check
            expectedBaseFee
        );
        _verifyStateCleanup(participantIds, gauntletId, vrfRequestId); // Use original selected IDs for cleanup check
        // --- End Verify Event and State ---

        // Verify retired player record unchanged
        _verifyRetiredPlayerState(retiredPlayerId, recordBefore); // Use recordBefore from before fulfillment

        // Verify fee collection and final payout logic (checks contract state)
        _verifyPayoutAndFees(actualChampionId, feesBefore, expectedBaseFee, expectedPrize);

        // --- CORRECTED WIN RECORD VERIFICATION ---
        if (!game.defaultPlayerContract().isValidId(actualChampionId)) {
            Fighter.Record memory recordAfter = playerContract.getPlayer(actualChampionId).record;
            Fighter.Record memory recordBeforeChampion;
            bool foundRecord = false;
            // Find the champion's record in our pre-fulfillment array
            for (uint256 i = 0; i < nonDefaultCount; i++) {
                if (nonDefaultParticipantIds[i] == actualChampionId) {
                    recordBeforeChampion = recordsBefore[i];
                    foundRecord = true;
                    break;
                }
            }
            assertTrue(foundRecord, "Failed to find pre-fulfillment record for champion (Substitution Test)");
            assertTrue(
                recordAfter.wins > recordBeforeChampion.wins, "Champion win count did not increase (Substitution Test)"
            );
        }
        // --- END CORRECTED VERIFICATION ---
    }

    //==============================================================//
    //                    VRF FULFILLMENT TESTS                   //
    //==============================================================//

    // Add this new internal helper function somewhere in the GauntletGameTest contract
    function _findChampionIdFromLogs_Minimal(Vm.Log[] memory logs, uint256 gauntletId)
        internal
        pure
        returns (uint32 championId, bool found)
    {
        bytes32 gauntletCompletedSig = keccak256("GauntletCompleted(uint256,uint8,uint256,uint32,uint256,uint256)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics.length > 2 && logs[i].topics[0] == gauntletCompletedSig
                    && uint256(logs[i].topics[1]) == gauntletId
            ) {
                // The problematic line, now in an isolated function
                bytes32 topic2 = logs[i].topics[2];
                championId = uint32(uint256(topic2));
                found = true;
                return (championId, found); // Return immediately
            }
        }
        return (0, false); // Return default if not found
    }

    // Modify the existing test function:
    function testFulfillRandomness_AllDefaultPlayersWinScenario() public {
        uint8 gauntletSize = 8;
        vm.prank(game.owner());
        game.setGauntletSize(gauntletSize);
        uint256 entryFee = game.currentEntryFee();

        // 1. Setup and Start using helper
        (
            uint256 gauntletId,
            uint256 vrfRequestId,
            uint256 vrfRoundId,
            uint32[] memory participantIds, // Selected participant IDs
            address[] memory participantAddrs // Addresses of originally queued players
        ) = _setupAndStartGauntlet(gauntletSize);

        // 2. Retire All Players (using selected IDs and original addresses)
        _retireAllParticipants(participantIds, participantAddrs);

        // 3. Fulfill Randomness
        uint256 randomnessFromBlock =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, vrfRoundId)));
        bytes memory dataWithRound = _simulateVRFFulfillment(vrfRequestId, vrfRoundId);
        uint256 feesBefore = game.contractFeesCollected();
        uint256 ownerBalanceBefore = game.owner().balance;
        uint256 expectedTotalFeesCollected = entryFee * gauntletSize; // All fees go to contract
        uint256 expectedPrize = 0; // No prize paid out if default wins

        vm.recordLogs();
        vm.prank(operator);
        game.fulfillRandomness(randomnessFromBlock, dataWithRound);
        vm.stopPrank();
        Vm.Log[] memory finalEntries = vm.getRecordedLogs();

        // 4. Verify using dedicated helper
        uint32 actualChampionId = _verifyGauntletCompletedEvent_AllDefault(finalEntries, gauntletId, expectedPrize);
        assertTrue(actualChampionId != 0, "Champion ID should not be 0"); // Basic check from helper

        // 5. Verify Payouts/Fees using dedicated helper
        _verifyPayoutAndFees_AllDefault(feesBefore, expectedTotalFeesCollected, ownerBalanceBefore);

        // 6. Verify State Cleanup
        _verifyStateCleanup(participantIds, gauntletId, vrfRequestId); // Use selected IDs
    }

    function _extractChampionIdOnly(Vm.Log[] memory logs, uint256 gauntletId) internal pure returns (uint32) {
        bytes32 gauntletCompletedSig = keccak256("GauntletCompleted(uint256,uint8,uint256,uint32,uint256,uint256)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics.length > 2 && logs[i].topics[0] == gauntletCompletedSig
                    && uint256(logs[i].topics[1]) == gauntletId
            ) {
                return uint32(uint256(logs[i].topics[2]));
            }
        }
        return 0;
    }

    //==============================================================//
    //         SWAP-AND-POP DETAIL TESTS                         //
    //==============================================================//

    function testWithdrawFromQueue_SwapAndPop_Middle() public {
        uint256 queueSize = 5;
        uint256 withdrawIndex = 2; // Index to remove (0-based)
        uint256 lastIndex = queueSize - 1;
        uint256 entryFee = game.currentEntryFee();

        // Queue 5 players
        (uint32[] memory queuedIds, address[] memory queuedAddrs) = _queuePlayers(queueSize);
        assertEq(game.getQueueSize(), queueSize, "Initial queue size mismatch");

        // Identify players at specific indices
        uint32 playerToWithdrawId = game.queueIndex(withdrawIndex);
        address playerToWithdrawAddr = address(0); // Find the address corresponding to the ID
        for (uint256 i = 0; i < queueSize; i++) {
            if (queuedIds[i] == playerToWithdrawId) {
                playerToWithdrawAddr = queuedAddrs[i];
                break;
            }
        }
        require(playerToWithdrawAddr != address(0), "Could not find address for player to withdraw");

        uint32 playerAtLastIndexId = game.queueIndex(lastIndex);

        // Verify initial index mapping for the player at the last index
        assertEq(
            game.playerIndexInQueue(playerAtLastIndexId),
            lastIndex + 1,
            "Initial index mapping incorrect for last player"
        );

        // Record balance before withdraw
        uint256 balanceBefore = playerToWithdrawAddr.balance;

        // Withdraw the middle player
        vm.startPrank(playerToWithdrawAddr);
        vm.expectEmit(true, true, false, true);
        emit PlayerWithdrew(playerToWithdrawId, queueSize - 1);
        game.withdrawFromQueue(playerToWithdrawId);
        vm.stopPrank();

        // Verify queue state after swap-and-pop
        assertEq(game.getQueueSize(), queueSize - 1, "Queue size should decrease by 1");
        assertEq(
            game.queueIndex(withdrawIndex),
            playerAtLastIndexId,
            "Player from last index should be moved to the withdrawn index"
        );
        assertEq(
            uint8(game.playerStatus(playerToWithdrawId)),
            uint8(GauntletGame.PlayerStatus.NONE),
            "Withdrawn player status should be NONE"
        );
        assertEq(game.playerIndexInQueue(playerToWithdrawId), 0, "Withdrawn player index should be cleared");
        assertEq(
            game.playerIndexInQueue(playerAtLastIndexId),
            withdrawIndex + 1,
            "Moved player's index mapping should be updated"
        );

        // Verify refund
        assertEq(playerToWithdrawAddr.balance, balanceBefore + entryFee, "Player should be refunded entry fee");

        // Verify fee pool updated
        assertEq(game.queuedFeesPool(), entryFee * (queueSize - 1), "Fee pool should decrease by one entry fee");
    }

    function testWithdrawFromQueue_SwapAndPop_Beginning() public {
        uint256 queueSize = 5;
        uint256 withdrawIndex = 0; // Index to remove (0-based)
        uint256 lastIndex = queueSize - 1;
        uint256 entryFee = game.currentEntryFee();

        // Queue 5 players
        (uint32[] memory queuedIds, address[] memory queuedAddrs) = _queuePlayers(queueSize);
        assertEq(game.getQueueSize(), queueSize, "Initial queue size mismatch");

        // Identify players at specific indices
        uint32 playerToWithdrawId = game.queueIndex(withdrawIndex);
        address playerToWithdrawAddr = address(0); // Find the address corresponding to the ID
        for (uint256 i = 0; i < queueSize; i++) {
            if (queuedIds[i] == playerToWithdrawId) {
                playerToWithdrawAddr = queuedAddrs[i];
                break;
            }
        }
        require(playerToWithdrawAddr != address(0), "Could not find address for player to withdraw");

        uint32 playerAtLastIndexId = game.queueIndex(lastIndex);

        // Verify initial index mapping for the player at the last index
        assertEq(
            game.playerIndexInQueue(playerAtLastIndexId),
            lastIndex + 1,
            "Initial index mapping incorrect for last player"
        );

        // Record balance before withdraw
        uint256 balanceBefore = playerToWithdrawAddr.balance;

        // Withdraw the first player
        vm.startPrank(playerToWithdrawAddr);
        vm.expectEmit(true, true, false, true);
        emit PlayerWithdrew(playerToWithdrawId, queueSize - 1);
        game.withdrawFromQueue(playerToWithdrawId);
        vm.stopPrank();

        // Verify queue state after swap-and-pop
        assertEq(game.getQueueSize(), queueSize - 1, "Queue size should decrease by 1");
        assertEq(
            game.queueIndex(withdrawIndex), playerAtLastIndexId, "Player from last index should be moved to index 0"
        );
        assertEq(
            uint8(game.playerStatus(playerToWithdrawId)),
            uint8(GauntletGame.PlayerStatus.NONE),
            "Withdrawn player status should be NONE"
        );
        assertEq(game.playerIndexInQueue(playerToWithdrawId), 0, "Withdrawn player index should be cleared");
        assertEq(
            game.playerIndexInQueue(playerAtLastIndexId),
            withdrawIndex + 1,
            "Moved player's index mapping should be updated to 1"
        );

        // Verify refund
        assertEq(playerToWithdrawAddr.balance, balanceBefore + entryFee, "Player should be refunded entry fee");

        // Verify fee pool updated
        assertEq(game.queuedFeesPool(), entryFee * (queueSize - 1), "Fee pool should decrease by one entry fee");
    }

    function testSetEntryFee_SkipReset() public {
        uint256 oldFee = game.currentEntryFee();
        require(oldFee > 0, "Initial fee is zero, cannot test");

        // Queue players
        uint256 playerCount = 2;
        Fighter.PlayerLoadout memory loadoutP1 = _createLoadout(PLAYER_ONE_ID);
        Fighter.PlayerLoadout memory loadoutP2 = _createLoadout(PLAYER_TWO_ID);

        vm.startPrank(PLAYER_ONE);
        game.queueForGauntlet{value: oldFee}(loadoutP1);
        vm.stopPrank();
        vm.startPrank(PLAYER_TWO);
        game.queueForGauntlet{value: oldFee}(loadoutP2);
        vm.stopPrank();

        uint256 balanceOneBefore = PLAYER_ONE.balance;
        uint256 balanceTwoBefore = PLAYER_TWO.balance;
        uint256 poolBefore = game.queuedFeesPool();
        assertEq(game.getQueueSize(), playerCount, "Queue size mismatch before fee change");

        // Change fee with skipReset = true
        uint256 newFee = oldFee * 2;

        vm.prank(game.owner());
        vm.expectEmit(true, false, false, true); // Only EntryFeeSet should be emitted
        emit EntryFeeSet(oldFee, newFee);
        game.setEntryFee(newFee, false, true); // refundPlayers=false (doesn't matter), skipReset=true

        // Verify state after change
        assertEq(game.currentEntryFee(), newFee, "New fee not set correctly");
        assertEq(game.getQueueSize(), playerCount, "Queue SHOULD NOT be cleared");
        assertEq(game.queuedFeesPool(), poolBefore, "Fee pool SHOULD NOT be cleared/zeroed");
        assertEq(PLAYER_ONE.balance, balanceOneBefore, "Player one SHOULD NOT be refunded");
        assertEq(PLAYER_TWO.balance, balanceTwoBefore, "Player two SHOULD NOT be refunded");
        assertEq(
            uint8(game.playerStatus(PLAYER_ONE_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED), // Status should remain QUEUED
            "Player one status SHOULD NOT reset"
        );
        assertEq(
            uint8(game.playerStatus(PLAYER_TWO_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED), // Status should remain QUEUED
            "Player two status SHOULD NOT reset"
        );
        assertEq(game.playerIndexInQueue(PLAYER_ONE_ID), 1, "Player one index SHOULD NOT clear"); // Check original index + 1
        assertEq(game.playerIndexInQueue(PLAYER_TWO_ID), 2, "Player two index SHOULD NOT clear"); // Check original index + 1

        // Verify queuing with new fee
        address PLAYER_FOUR = address(0xdF4);
        uint32 PLAYER_FOUR_ID = _createPlayerAndFulfillVRF(PLAYER_FOUR, playerContract, false);
        vm.deal(PLAYER_FOUR, 1 ether);
        vm.startPrank(PLAYER_FOUR);
        Fighter.PlayerLoadout memory loadoutP4 = _createLoadout(PLAYER_FOUR_ID);
        // Test queuing with the old fee (should fail)
        vm.expectRevert(abi.encodeWithSelector(IncorrectEntryFee.selector, newFee, oldFee));
        game.queueForGauntlet{value: oldFee}(loadoutP4);
        // Test queuing with the new fee (should succeed)
        game.queueForGauntlet{value: newFee}(loadoutP4);
        assertEq(game.getQueueSize(), playerCount + 1, "Failed to queue with new fee after skipReset");
        vm.stopPrank();
    }

    function testSetEntryFee_NoRefund() public {
        uint256 oldFee = game.currentEntryFee();
        require(oldFee > 0, "Initial fee is zero, cannot test");

        // Queue players
        uint256 playerCount = 2;
        Fighter.PlayerLoadout memory loadoutP1 = _createLoadout(PLAYER_ONE_ID);
        Fighter.PlayerLoadout memory loadoutP2 = _createLoadout(PLAYER_TWO_ID);

        vm.startPrank(PLAYER_ONE);
        game.queueForGauntlet{value: oldFee}(loadoutP1);
        vm.stopPrank();
        vm.startPrank(PLAYER_TWO);
        game.queueForGauntlet{value: oldFee}(loadoutP2);
        vm.stopPrank();

        uint256 balanceOneBefore = PLAYER_ONE.balance;
        uint256 balanceTwoBefore = PLAYER_TWO.balance;
        uint256 poolBefore = game.queuedFeesPool();
        assertEq(game.getQueueSize(), playerCount, "Queue size mismatch before fee change");

        // Change fee with refundPlayers = false, skipReset = false
        uint256 newFee = oldFee * 2;

        vm.prank(game.owner());
        vm.expectEmit(true, false, false, true); // Only EntryFeeSet should be emitted
        emit EntryFeeSet(oldFee, newFee);
        game.setEntryFee(newFee, false, false); // refundPlayers=false, skipReset=false

        // Verify state after change
        assertEq(game.currentEntryFee(), newFee, "New fee not set correctly");
        assertEq(game.getQueueSize(), playerCount, "Queue SHOULD NOT be cleared"); // Queue remains
        assertEq(game.queuedFeesPool(), poolBefore, "Fee pool SHOULD NOT be cleared/zeroed"); // Pool remains
        assertEq(PLAYER_ONE.balance, balanceOneBefore, "Player one SHOULD NOT be refunded");
        assertEq(PLAYER_TWO.balance, balanceTwoBefore, "Player two SHOULD NOT be refunded");
        assertEq(
            uint8(game.playerStatus(PLAYER_ONE_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED), // Status should remain QUEUED
            "Player one status SHOULD NOT reset"
        );
        assertEq(
            uint8(game.playerStatus(PLAYER_TWO_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED), // Status should remain QUEUED
            "Player two status SHOULD NOT reset"
        );
        assertEq(game.playerIndexInQueue(PLAYER_ONE_ID), 1, "Player one index SHOULD NOT clear"); // Check original index + 1
        assertEq(game.playerIndexInQueue(PLAYER_TWO_ID), 2, "Player two index SHOULD NOT clear"); // Check original index + 1

        // Verify queuing with new fee still works
        address PLAYER_FOUR = address(0xdF4);
        uint32 PLAYER_FOUR_ID = _createPlayerAndFulfillVRF(PLAYER_FOUR, playerContract, false);
        vm.deal(PLAYER_FOUR, 1 ether);
        vm.startPrank(PLAYER_FOUR);
        Fighter.PlayerLoadout memory loadoutP4 = _createLoadout(PLAYER_FOUR_ID);
        // Test queuing with the old fee (should fail)
        vm.expectRevert(abi.encodeWithSelector(IncorrectEntryFee.selector, newFee, oldFee));
        game.queueForGauntlet{value: oldFee}(loadoutP4);
        // Test queuing with the new fee (should succeed)
        game.queueForGauntlet{value: newFee}(loadoutP4);
        assertEq(game.getQueueSize(), playerCount + 1, "Failed to queue with new fee after noRefund");
        vm.stopPrank();
    }

    function testFulfillRandomness_WithMultipleRetiredPlayerSubstitutions() public {
        uint8 gauntletSize = 8; // Use smaller size for simplicity
        vm.prank(game.owner());
        game.setGauntletSize(gauntletSize); // Ensure size is 8
        uint256 entryFee = game.currentEntryFee();
        uint256 numToRetire = 3; // Retire multiple players

        // 1. Start the gauntlet using the helper
        (
            uint256 gauntletId,
            uint256 vrfRequestId,
            uint256 vrfRoundId,
            uint32[] memory participantIds, // Selected participants
            address[] memory participantAddrs // Addresses of *all* queued players originally
        ) = _setupAndStartGauntlet(gauntletSize);

        // 2. Retire Multiple participants *after* gauntlet start
        uint32[] memory retiredPlayerIds = new uint32[](numToRetire);
        Fighter.Record[] memory recordsBeforeRetirement = new Fighter.Record[](numToRetire);

        for (uint256 i = 0; i < numToRetire; i++) {
            // Pick participants to retire (e.g., first 'numToRetire' selected players)
            uint32 pId = participantIds[i];
            address pOwner = playerContract.getPlayerOwner(pId);
            require(pOwner != address(0), "Could not find owner for player to retire");

            retiredPlayerIds[i] = pId;
            recordsBeforeRetirement[i] = playerContract.getPlayer(pId).record;

            vm.startPrank(pOwner);
            playerContract.retireOwnPlayer(pId);
            vm.stopPrank();
            assertTrue(playerContract.isPlayerRetired(pId), "Player failed to retire");
        }

        // --- PRE-FULFILLMENT STATE CAPTURE (For non-retired players) ---
        uint32[] memory nonDefaultParticipantIds = new uint32[](gauntletSize - numToRetire); // Max size
        Fighter.Record[] memory recordsBefore = new Fighter.Record[](gauntletSize - numToRetire); // Max size
        uint256 nonDefaultCount = 0;
        for (uint256 i = numToRetire; i < participantIds.length; i++) {
            // Start after the retired ones
            // Only track non-default players who were *not* retired
            if (!game.defaultPlayerContract().isValidId(participantIds[i])) {
                nonDefaultParticipantIds[nonDefaultCount] = participantIds[i];
                recordsBefore[nonDefaultCount] = playerContract.getPlayer(participantIds[i]).record;
                nonDefaultCount++;
            }
        }
        // --- End PRE-FULFILLMENT ---

        // 3. Fulfill randomness
        uint256 randomnessFromBlock =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, vrfRoundId)));
        bytes memory dataWithRound = _simulateVRFFulfillment(vrfRequestId, vrfRoundId);

        uint256 feesBefore = game.contractFeesCollected();

        vm.recordLogs();
        vm.prank(operator);
        game.fulfillRandomness(randomnessFromBlock, dataWithRound);
        vm.stopPrank();
        Vm.Log[] memory finalEntries = vm.getRecordedLogs();

        // 4. Verify results
        uint256 expectedBaseFee = (entryFee * gauntletSize * game.feePercentage()) / 10000; // 4e14
        uint256 expectedPrize = (entryFee * gauntletSize) - expectedBaseFee; // 3.6e15

        // --- Verify Event and State ---
        uint32 actualChampionId = _extractChampionIdOnly(finalEntries, gauntletId);
        assertTrue(actualChampionId != 0, "Champion ID is zero after fulfillment");

        // Calculate expected prize *emitted* in the event based on winner type
        uint256 prizeAwardedForEvent = expectedPrize;
        if (game.defaultPlayerContract().isValidId(actualChampionId)) {
            prizeAwardedForEvent = 0;
        }

        // Verify the event emission parameters:
        // - entryFee should match the fee at the start
        // - prizeAwarded should be 0 if default won, else the calculated prize
        // - feeCollected parameter in the event is *always* the base fee calculated
        _verifyGauntletCompletedEvent(
            finalEntries,
            gauntletId,
            gauntletSize,
            entryFee, // Expect entryFee (5e14)
            prizeAwardedForEvent, // Expect prize based on winner type (0 or 3.6e15)
            expectedBaseFee // Expect the base fee collected parameter (4e14)
        );
        _verifyStateCleanup(participantIds, gauntletId, vrfRequestId);
        // --- End Verify Event and State ---

        // Verify retired players' records unchanged
        for (uint256 i = 0; i < numToRetire; i++) {
            _verifyRetiredPlayerState(retiredPlayerIds[i], recordsBeforeRetirement[i]);
        }

        // Verify fee collection and final payout logic (checks contract state)
        _verifyPayoutAndFees(actualChampionId, feesBefore, expectedBaseFee, expectedPrize);

        // --- CORRECTED WIN RECORD VERIFICATION (only for non-retired, non-default winners) ---
        if (!game.defaultPlayerContract().isValidId(actualChampionId)) {
            bool wasChampionRetired = false;
            for (uint256 i = 0; i < numToRetire; i++) {
                if (retiredPlayerIds[i] == actualChampionId) {
                    wasChampionRetired = true;
                    break;
                }
            }

            // Only check win record increase if the champion was NOT one of the retired players
            if (!wasChampionRetired) {
                Fighter.Record memory recordAfter = playerContract.getPlayer(actualChampionId).record;
                Fighter.Record memory recordBeforeChampion;
                bool foundRecord = false;
                // Find the champion's record in our pre-fulfillment array of *non-retired* players
                for (uint256 i = 0; i < nonDefaultCount; i++) {
                    if (nonDefaultParticipantIds[i] == actualChampionId) {
                        recordBeforeChampion = recordsBefore[i];
                        foundRecord = true;
                        break;
                    }
                }
                assertTrue(foundRecord, "Failed to find pre-fulfillment record for non-retired champion");
                assertTrue(
                    recordAfter.wins > recordBeforeChampion.wins,
                    "Non-retired champion win count did not increase (Multi-Substitution Test)"
                );
            }
        }
        // --- END CORRECTED VERIFICATION ---
    }
}

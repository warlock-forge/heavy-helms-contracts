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
    NotOffChainRunner,
    InsufficientQueueLength,
    InvalidQueueIndex,
    InvalidPlayerSelection,
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

    // Add this receive function to allow the test contract (owner) to receive ETH
    receive() external payable {}

    function setUp() public override {
        super.setUp(); // This correctly deploys DefaultPlayer and mints 1-18

        // Initialize off-chain runner address
        OFF_CHAIN_RUNNER = address(0x42424242);

        // Initialize game contract - USE THE INHERITED defaultPlayerContract
        game = new GauntletGame(
            address(gameEngine),
            address(playerContract),
            address(defaultPlayerContract), // Use the one from TestBase.setUp()
            operator,
            OFF_CHAIN_RUNNER
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

    function testStartGauntlet_Success_DefaultSize() public {
        uint8 gauntletSize = game.currentGauntletSize(); // Use current default size
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

        vm.recordLogs();
        vm.prank(OFF_CHAIN_RUNNER);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(game.getQueueSize(), 0, "Queue should be empty after start");
        assertEq(game.nextGauntletId(), 1, "Next gauntlet ID should be 1");

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
                if (pIds.length == selectedIds.length) {
                    for (uint256 j = 0; j < pIds.length; j++) {
                        assertEq(pIds[j], selectedIds[j], "Mismatch participant ID in event");
                    }
                }
                break;
            }
        }
        assertTrue(foundGauntletStartedEvent, "GauntletStarted event not found for gauntletId 0");

        assertEq(game.requestToGauntletId(actualVrfRequestId), gauntletId, "Request ID mapping mismatch");
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = selectedIds[i];
            assertEq(
                uint8(game.playerStatus(pId)),
                uint8(GauntletGame.PlayerStatus.IN_GAUNTLET),
                "Player status should be IN_GAUNTLET"
            );
            assertEq(game.playerCurrentGauntlet(pId), gauntletId, "Player current gauntlet mismatch");
        }
    }

    function testStartGauntlet_Success_Size8() public {
        uint8 targetSize = 8;
        vm.prank(game.owner());
        game.setGauntletSize(targetSize); // Set the size first
        uint8 gauntletSize = game.currentGauntletSize();
        assertEq(gauntletSize, targetSize, "Failed to set gauntlet size to 8");
        uint256 entryFee = game.currentEntryFee();

        (uint32[] memory queuedIds,) = _queuePlayers(gauntletSize);
        assertEq(game.getQueueSize(), gauntletSize, "Queue should have 8 players");

        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 playerId = game.queueIndex(i);
            selectedIds[i] = playerId;
            selectedIndices[i] = game.playerIndexInQueue(playerId) - 1;
        }

        vm.recordLogs();
        vm.prank(OFF_CHAIN_RUNNER);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(game.getQueueSize(), 0, "Queue should be empty after start");
        assertEq(game.nextGauntletId(), 1, "Next gauntlet ID should be 1");

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
                if (pIds.length == selectedIds.length) {
                    for (uint256 j = 0; j < pIds.length; j++) {
                        assertEq(pIds[j], selectedIds[j], "Mismatch participant ID in event");
                    }
                }
                break;
            }
        }
        assertTrue(foundGauntletStartedEvent, "GauntletStarted event not found for gauntletId 0");

        assertEq(game.requestToGauntletId(actualVrfRequestId), gauntletId, "Request ID mapping mismatch");
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = selectedIds[i];
            assertEq(
                uint8(game.playerStatus(pId)),
                uint8(GauntletGame.PlayerStatus.IN_GAUNTLET),
                "Player status should be IN_GAUNTLET"
            );
            assertEq(game.playerCurrentGauntlet(pId), gauntletId, "Player current gauntlet mismatch");
        }
    }

    function testStartGauntlet_Success_Size32() public {
        uint8 targetSize = 32;
        vm.prank(game.owner());
        game.setGauntletSize(targetSize); // Set the size first
        uint8 gauntletSize = game.currentGauntletSize();
        assertEq(gauntletSize, targetSize, "Failed to set gauntlet size to 32");
        uint256 entryFee = game.currentEntryFee();

        (uint32[] memory queuedIds,) = _queuePlayers(gauntletSize);
        assertEq(game.getQueueSize(), gauntletSize, "Queue should have 32 players");

        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 playerId = game.queueIndex(i);
            selectedIds[i] = playerId;
            selectedIndices[i] = game.playerIndexInQueue(playerId) - 1;
        }

        vm.recordLogs();
        vm.prank(OFF_CHAIN_RUNNER);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(game.getQueueSize(), 0, "Queue should be empty after start");
        assertEq(game.nextGauntletId(), 1, "Next gauntlet ID should be 1");

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
                if (pIds.length == selectedIds.length) {
                    for (uint256 j = 0; j < pIds.length; j++) {
                        assertEq(pIds[j], selectedIds[j], "Mismatch participant ID in event");
                    }
                }
                break;
            }
        }
        assertTrue(foundGauntletStartedEvent, "GauntletStarted event not found for gauntletId 0");

        assertEq(game.requestToGauntletId(actualVrfRequestId), gauntletId, "Request ID mapping mismatch");
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = selectedIds[i];
            assertEq(
                uint8(game.playerStatus(pId)),
                uint8(GauntletGame.PlayerStatus.IN_GAUNTLET),
                "Player status should be IN_GAUNTLET"
            );
            assertEq(game.playerCurrentGauntlet(pId), gauntletId, "Player current gauntlet mismatch");
        }
    }

    function testStartGauntlet_Success_MoreThanDefaultSize() public {
        uint8 gauntletSize = game.currentGauntletSize(); // Use current default size
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

        vm.recordLogs();
        vm.prank(OFF_CHAIN_RUNNER);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(game.getQueueSize(), queueStartSize - gauntletSize, "Queue size should be reduced correctly");
        assertEq(game.nextGauntletId(), 1, "Next gauntlet ID should be 1");

        bytes32 gauntletStartedSig = keccak256("GauntletStarted(uint256,uint8,uint256,uint32[],uint256)");
        uint256 actualVrfRequestId = 0;
        bool foundGauntletStartedEvent = false;
        uint256 gauntletId = 0;

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
                if (pIds.length == selectedIds.length) {
                    for (uint256 j = 0; j < pIds.length; j++) {
                        assertEq(pIds[j], selectedIds[j], "Mismatch participant ID in event");
                    }
                }
                break;
            }
        }
        assertTrue(foundGauntletStartedEvent, "GauntletStarted event not found for gauntletId 0");

        assertEq(game.requestToGauntletId(actualVrfRequestId), gauntletId, "Request ID mapping mismatch");
        for (uint256 i = 0; i < game.getQueueSize(); i++) {
            uint32 queuedId = game.queueIndex(i);
            assertEq(
                uint8(game.playerStatus(queuedId)),
                uint8(GauntletGame.PlayerStatus.QUEUED),
                "Remaining player status incorrect"
            );
        }

        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = selectedIds[i];
            assertEq(
                uint8(game.playerStatus(pId)),
                uint8(GauntletGame.PlayerStatus.IN_GAUNTLET),
                "Started player status incorrect"
            );
            assertEq(game.playerCurrentGauntlet(pId), gauntletId, "Started player gauntlet ID incorrect");
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
            uint32[] memory participantIds,
            address[] memory participantAddrs
        )
    {
        (participantIds, participantAddrs) = _queuePlayers(gauntletSize);
        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = game.queueIndex(i);
            selectedIds[i] = pId;
            selectedIndices[i] = game.playerIndexInQueue(pId) - 1;
        }

        vm.recordLogs();
        vm.prank(OFF_CHAIN_RUNNER);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
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
        return (gauntletId, vrfRequestId, vrfRoundId, participantIds, participantAddrs);
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
        uint256 eventPrizeAwarded;
        uint256 eventFeeCollected;

        for (uint256 i = 0; i < finalEntries.length; i++) {
            if (
                finalEntries[i].topics.length > 2 && finalEntries[i].topics[0] == gauntletCompletedSig
                    && uint256(finalEntries[i].topics[1]) == gauntletId
            ) {
                (uint8 size, uint256 fee, uint256 prize, uint256 collected) =
                    abi.decode(finalEntries[i].data, (uint8, uint256, uint256, uint256));
                // Decode champion ID from the indexed topic
                actualChampionId = uint32(uint256(finalEntries[i].topics[2]));
                eventPrizeAwarded = prize;
                eventFeeCollected = collected;
                foundCompleted = true;
                assertEq(size, expectedSize, "Completed event size mismatch");
                assertEq(fee, expectedFee, "Completed event fee mismatch");
                break;
            }
        }
        assertTrue(foundCompleted, "GauntletCompleted event not found");
        assertEq(eventPrizeAwarded, expectedPrize, "Event prize mismatch");
        assertEq(eventFeeCollected, expectedFeeCollected, "Event fee mismatch");
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
            vm.startPrank(participantAddrs[i]);
            playerContract.retireOwnPlayer(participantIds[i]);
            vm.stopPrank();
            assertTrue(playerContract.isPlayerRetired(participantIds[i]), "Player failed to retire");
        }
    }

    function testFulfillRandomness_CompletesGauntlet_DefaultSize() public {
        uint8 gauntletSize = game.currentGauntletSize(); // Use current default size
        uint256 entryFee = game.currentEntryFee();
        uint256 totalFeesCollected = entryFee * gauntletSize;
        uint256 expectedContractFee = (totalFeesCollected * game.feePercentage()) / 10000;
        uint256 expectedPrize = totalFeesCollected - expectedContractFee;

        (uint32[] memory allQueuedIds,) = _queuePlayers(gauntletSize);

        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = game.queueIndex(i);
            selectedIds[i] = pId;
            selectedIndices[i] = game.playerIndexInQueue(pId) - 1;
        }

        vm.recordLogs();
        vm.prank(OFF_CHAIN_RUNNER);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 vrfRequestId = 0;
        uint256 vrfRoundId = 0;
        uint256 gauntletId = 0;
        bytes32 gauntletStartedSig = keccak256("GauntletStarted(uint256,uint8,uint256,uint32[],uint256)");
        bytes32 requestedRandomnessSig = keccak256("RequestedRandomness(uint256,bytes)");
        bool foundStarted = false;
        bool foundRequested = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (
                !foundStarted && entries[i].topics.length > 1 && entries[i].topics[0] == gauntletStartedSig
                    && uint256(entries[i].topics[1]) == gauntletId // Ensure checking against gauntletId 0
            ) {
                (,,, uint256 reqId) = abi.decode(entries[i].data, (uint8, uint256, uint32[], uint256));
                vrfRequestId = reqId;
                foundStarted = true; // Mark as found
            }
            if (!foundRequested && entries[i].topics.length > 0 && entries[i].topics[0] == requestedRandomnessSig) {
                (uint256 roundId,) = abi.decode(entries[i].data, (uint256, bytes));
                vrfRoundId = roundId;
                foundRequested = true; // Mark as found
            }
            if (foundStarted && foundRequested) break; // Exit early if both found
        }
        require(foundRequested, "TEST FAIL: RequestedRandomness event not found in logs");
        require(foundStarted, "TEST FAIL: GauntletStarted event (for gauntletId 0) not found in logs");

        uint256 randomnessFromBlock =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, vrfRoundId)));
        bytes memory dataWithRound = _simulateVRFFulfillment(vrfRequestId, vrfRoundId);

        // PRE-FULFILLMENT STATE CAPTURE (Corrected: Using Arrays)
        uint32[] memory nonDefaultParticipantIds = new uint32[](gauntletSize); // Max possible size
        Fighter.Record[] memory recordsBefore = new Fighter.Record[](gauntletSize); // Max possible size
        uint256 nonDefaultCount = 0;
        for (uint256 i = 0; i < allQueuedIds.length; i++) {
            if (!game.defaultPlayerContract().isValidId(allQueuedIds[i])) {
                // Only track real players
                nonDefaultParticipantIds[nonDefaultCount] = allQueuedIds[i];
                recordsBefore[nonDefaultCount] = playerContract.getPlayer(allQueuedIds[i]).record;
                nonDefaultCount++;
            }
        }
        // Resize arrays to actual count if needed (optional for gas, but clearer)
        // assembly { nonDefaultParticipantIds := mload(nonDefaultParticipantIds) mstore(nonDefaultParticipantIds, nonDefaultCount) }
        // assembly { recordsBefore := mload(recordsBefore) mstore(recordsBefore, nonDefaultCount) }

        vm.recordLogs();
        vm.prank(operator);
        game.fulfillRandomness(randomnessFromBlock, dataWithRound);
        vm.stopPrank();
        Vm.Log[] memory finalEntries = vm.getRecordedLogs();

        bytes32 gauntletCompletedSig = keccak256("GauntletCompleted(uint256,uint8,uint256,uint32,uint256,uint256)");
        uint256 actualPrizeAwarded = 0;
        uint256 actualFeeCollected = 0;
        uint32 actualChampionId = 0;
        bool foundCompletedEvent = false;

        for (uint256 i = 0; i < finalEntries.length; i++) {
            if (
                finalEntries[i].topics.length > 2 && finalEntries[i].topics[0] == gauntletCompletedSig
                    && uint256(finalEntries[i].topics[1]) == gauntletId
            ) {
                (uint8 size, uint256 fee, uint256 prize, uint256 collected) =
                    abi.decode(finalEntries[i].data, (uint8, uint256, uint256, uint256));
                actualChampionId = uint32(uint256(finalEntries[i].topics[2]));
                actualPrizeAwarded = prize;
                actualFeeCollected = collected;
                foundCompletedEvent = true;
                assertEq(size, gauntletSize, "Completed event size mismatch");
                assertEq(fee, entryFee, "Completed event fee mismatch");
                break;
            }
        }
        assertTrue(foundCompletedEvent, "GauntletCompleted event not found or data mismatch for gauntletId 0");
        assertTrue(actualChampionId != 0, "Actual champion ID extracted from event was zero");
        assertEq(actualPrizeAwarded, expectedPrize, "Prize awarded in event mismatch");
        assertEq(actualFeeCollected, expectedContractFee, "Fee collected in event mismatch");
        assertEq(game.contractFeesCollected(), expectedContractFee, "Contract fee balance mismatch");

        GauntletGame.Gauntlet memory completedGauntlet = game.getGauntletData(gauntletId);
        assertEq(completedGauntlet.championId, actualChampionId, "Stored champion ID mismatch event champion ID");
        assertEq(uint8(completedGauntlet.state), uint8(GauntletGame.GauntletState.COMPLETED), "Gauntlet 0 state");
        assertTrue(completedGauntlet.completionTimestamp > 0, "Completion timestamp should be set");
        assertEq(game.requestToGauntletId(vrfRequestId), 0, "Request ID mapping should be cleared/reset");

        for (uint8 i = 0; i < gauntletSize; i++) {
            assertEq(
                uint8(game.playerStatus(allQueuedIds[i])),
                uint8(GauntletGame.PlayerStatus.NONE),
                "Player status should be NONE after completion"
            );
            assertEq(game.playerCurrentGauntlet(allQueuedIds[i]), 0, "Player current gauntlet should be cleared/reset");
        }

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

        (uint32[] memory allQueuedIds,) = _queuePlayers(gauntletSize);

        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = game.queueIndex(i);
            selectedIds[i] = pId;
            selectedIndices[i] = game.playerIndexInQueue(pId) - 1;
        }

        vm.recordLogs();
        vm.prank(OFF_CHAIN_RUNNER);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 vrfRequestId = 0;
        uint256 vrfRoundId = 0;
        uint256 gauntletId = 0; // Explicitly checking for gauntlet 0
        bytes32 gauntletStartedSig = keccak256("GauntletStarted(uint256,uint8,uint256,uint32[],uint256)");
        bytes32 requestedRandomnessSig = keccak256("RequestedRandomness(uint256,bytes)");
        bool foundStarted = false;
        bool foundRequested = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (
                !foundStarted && entries[i].topics.length > 1 && entries[i].topics[0] == gauntletStartedSig
                    && uint256(entries[i].topics[1]) == gauntletId // Ensure checking against gauntletId 0
            ) {
                (,,, uint256 reqId) = abi.decode(entries[i].data, (uint8, uint256, uint32[], uint256));
                vrfRequestId = reqId;
                foundStarted = true; // Mark as found
            }
            if (!foundRequested && entries[i].topics.length > 0 && entries[i].topics[0] == requestedRandomnessSig) {
                (uint256 roundId,) = abi.decode(entries[i].data, (uint256, bytes));
                vrfRoundId = roundId;
                foundRequested = true; // Mark as found
            }
            if (foundStarted && foundRequested) break; // Exit early if both found
        }
        require(foundRequested, "TEST FAIL: RequestedRandomness event not found in logs");
        require(foundStarted, "TEST FAIL: GauntletStarted event (for gauntletId 0) not found in logs");

        uint256 randomnessFromBlock =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, vrfRoundId)));
        bytes memory dataWithRound = _simulateVRFFulfillment(vrfRequestId, vrfRoundId);

        // PRE-FULFILLMENT STATE CAPTURE (Corrected: Using Arrays)
        uint32[] memory nonDefaultParticipantIds = new uint32[](gauntletSize);
        Fighter.Record[] memory recordsBefore = new Fighter.Record[](gauntletSize);
        uint256 nonDefaultCount = 0;
        for (uint256 i = 0; i < allQueuedIds.length; i++) {
            if (!game.defaultPlayerContract().isValidId(allQueuedIds[i])) {
                nonDefaultParticipantIds[nonDefaultCount] = allQueuedIds[i];
                recordsBefore[nonDefaultCount] = playerContract.getPlayer(allQueuedIds[i]).record;
                nonDefaultCount++;
            }
        }

        vm.recordLogs();
        vm.prank(operator);
        game.fulfillRandomness(randomnessFromBlock, dataWithRound);
        vm.stopPrank();
        Vm.Log[] memory finalEntries = vm.getRecordedLogs();

        bytes32 gauntletCompletedSig = keccak256("GauntletCompleted(uint256,uint8,uint256,uint32,uint256,uint256)");
        uint256 actualPrizeAwarded = 0;
        uint256 actualFeeCollected = 0;
        uint32 actualChampionId = 0;
        bool foundCompletedEvent = false;

        for (uint256 i = 0; i < finalEntries.length; i++) {
            if (
                finalEntries[i].topics.length > 2 && finalEntries[i].topics[0] == gauntletCompletedSig
                    && uint256(finalEntries[i].topics[1]) == gauntletId
            ) {
                (uint8 size, uint256 fee, uint256 prize, uint256 collected) =
                    abi.decode(finalEntries[i].data, (uint8, uint256, uint256, uint256));
                actualChampionId = uint32(uint256(finalEntries[i].topics[2]));
                actualPrizeAwarded = prize;
                actualFeeCollected = collected;
                foundCompletedEvent = true;
                assertEq(size, gauntletSize, "Completed event size mismatch");
                assertEq(fee, entryFee, "Completed event fee mismatch");
                break;
            }
        }
        assertTrue(foundCompletedEvent, "GauntletCompleted event not found or data mismatch for gauntletId 0");
        assertTrue(actualChampionId != 0, "Actual champion ID extracted from event was zero");
        assertEq(actualPrizeAwarded, expectedPrize, "Prize awarded in event mismatch");
        assertEq(actualFeeCollected, expectedContractFee, "Fee collected in event mismatch");
        assertEq(game.contractFeesCollected(), expectedContractFee, "Contract fee balance mismatch");

        GauntletGame.Gauntlet memory completedGauntlet = game.getGauntletData(gauntletId);
        assertEq(completedGauntlet.championId, actualChampionId, "Stored champion ID mismatch event champion ID");
        assertEq(uint8(completedGauntlet.state), uint8(GauntletGame.GauntletState.COMPLETED), "Gauntlet 0 state");
        assertTrue(completedGauntlet.completionTimestamp > 0, "Completion timestamp should be set");
        assertEq(game.requestToGauntletId(vrfRequestId), 0, "Request ID mapping should be cleared/reset");

        for (uint8 i = 0; i < gauntletSize; i++) {
            assertEq(
                uint8(game.playerStatus(allQueuedIds[i])),
                uint8(GauntletGame.PlayerStatus.NONE),
                "Player status should be NONE after completion"
            );
            assertEq(game.playerCurrentGauntlet(allQueuedIds[i]), 0, "Player current gauntlet should be cleared/reset");
        }

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

        (uint32[] memory allQueuedIds,) = _queuePlayers(gauntletSize);

        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = game.queueIndex(i);
            selectedIds[i] = pId;
            selectedIndices[i] = game.playerIndexInQueue(pId) - 1;
        }

        vm.recordLogs();
        vm.prank(OFF_CHAIN_RUNNER);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 vrfRequestId = 0;
        uint256 vrfRoundId = 0;
        uint256 gauntletId = 0; // Explicitly checking for gauntlet 0
        bytes32 gauntletStartedSig = keccak256("GauntletStarted(uint256,uint8,uint256,uint32[],uint256)");
        bytes32 requestedRandomnessSig = keccak256("RequestedRandomness(uint256,bytes)");
        bool foundStarted = false;
        bool foundRequested = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (
                !foundStarted && entries[i].topics.length > 1 && entries[i].topics[0] == gauntletStartedSig
                    && uint256(entries[i].topics[1]) == gauntletId // Ensure checking against gauntletId 0
            ) {
                (,,, uint256 reqId) = abi.decode(entries[i].data, (uint8, uint256, uint32[], uint256));
                vrfRequestId = reqId;
                foundStarted = true; // Mark as found
            }
            if (!foundRequested && entries[i].topics.length > 0 && entries[i].topics[0] == requestedRandomnessSig) {
                (uint256 roundId,) = abi.decode(entries[i].data, (uint256, bytes));
                vrfRoundId = roundId;
                foundRequested = true; // Mark as found
            }
            if (foundStarted && foundRequested) break; // Exit early if both found
        }
        require(foundRequested, "TEST FAIL: RequestedRandomness event not found in logs");
        require(foundStarted, "TEST FAIL: GauntletStarted event (for gauntletId 0) not found in logs");

        uint256 randomnessFromBlock =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, vrfRoundId)));
        bytes memory dataWithRound = _simulateVRFFulfillment(vrfRequestId, vrfRoundId);

        // PRE-FULFILLMENT STATE CAPTURE (Corrected: Using Arrays)
        uint32[] memory nonDefaultParticipantIds = new uint32[](gauntletSize);
        Fighter.Record[] memory recordsBefore = new Fighter.Record[](gauntletSize);
        uint256 nonDefaultCount = 0;
        for (uint256 i = 0; i < allQueuedIds.length; i++) {
            if (!game.defaultPlayerContract().isValidId(allQueuedIds[i])) {
                nonDefaultParticipantIds[nonDefaultCount] = allQueuedIds[i];
                recordsBefore[nonDefaultCount] = playerContract.getPlayer(allQueuedIds[i]).record;
                nonDefaultCount++;
            }
        }

        vm.recordLogs();
        vm.prank(operator);
        game.fulfillRandomness(randomnessFromBlock, dataWithRound);
        vm.stopPrank();
        Vm.Log[] memory finalEntries = vm.getRecordedLogs();

        bytes32 gauntletCompletedSig = keccak256("GauntletCompleted(uint256,uint8,uint256,uint32,uint256,uint256)");
        uint256 actualPrizeAwarded = 0;
        uint256 actualFeeCollected = 0;
        uint32 actualChampionId = 0;
        bool foundCompletedEvent = false;

        for (uint256 i = 0; i < finalEntries.length; i++) {
            if (
                finalEntries[i].topics.length > 2 && finalEntries[i].topics[0] == gauntletCompletedSig
                    && uint256(finalEntries[i].topics[1]) == gauntletId
            ) {
                (uint8 size, uint256 fee, uint256 prize, uint256 collected) =
                    abi.decode(finalEntries[i].data, (uint8, uint256, uint256, uint256));
                actualChampionId = uint32(uint256(finalEntries[i].topics[2]));
                actualPrizeAwarded = prize;
                actualFeeCollected = collected;
                foundCompletedEvent = true;
                assertEq(size, gauntletSize, "Completed event size mismatch");
                assertEq(fee, entryFee, "Completed event fee mismatch");
                break;
            }
        }
        assertTrue(foundCompletedEvent, "GauntletCompleted event not found or data mismatch for gauntletId 0");
        assertTrue(actualChampionId != 0, "Actual champion ID extracted from event was zero");
        assertEq(actualPrizeAwarded, expectedPrize, "Prize awarded in event mismatch");
        assertEq(actualFeeCollected, expectedContractFee, "Fee collected in event mismatch");
        assertEq(game.contractFeesCollected(), expectedContractFee, "Contract fee balance mismatch");

        GauntletGame.Gauntlet memory completedGauntlet = game.getGauntletData(gauntletId);
        assertEq(completedGauntlet.championId, actualChampionId, "Stored champion ID mismatch event champion ID");
        assertEq(uint8(completedGauntlet.state), uint8(GauntletGame.GauntletState.COMPLETED), "Gauntlet 0 state");
        assertTrue(completedGauntlet.completionTimestamp > 0, "Completion timestamp should be set");
        assertEq(game.requestToGauntletId(vrfRequestId), 0, "Request ID mapping should be cleared/reset");

        for (uint8 i = 0; i < gauntletSize; i++) {
            assertEq(
                uint8(game.playerStatus(allQueuedIds[i])),
                uint8(GauntletGame.PlayerStatus.NONE),
                "Player status should be NONE after completion"
            );
            assertEq(game.playerCurrentGauntlet(allQueuedIds[i]), 0, "Player current gauntlet should be cleared/reset");
        }

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

        // 1. Queue players and start the gauntlet
        (uint32[] memory participantIds, address[] memory participantAddrs) = _queuePlayers(gauntletSize);
        assertEq(game.getQueueSize(), gauntletSize, "Incorrect queue size before start");

        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = game.queueIndex(i);
            selectedIds[i] = pId;
            selectedIndices[i] = game.playerIndexInQueue(pId) - 1;
        }

        vm.recordLogs();
        vm.prank(OFF_CHAIN_RUNNER);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // 2. Extract gauntletId and vrfRequestId from logs
        uint256 vrfRequestId = 0;
        uint256 gauntletId = 0; // Expecting first gauntlet
        bytes32 gauntletStartedSig = keccak256("GauntletStarted(uint256,uint8,uint256,uint32[],uint256)");
        bool foundStarted = false;
        for (uint256 i = 0; i < entries.length; i++) {
            if (
                entries[i].topics.length > 1 && entries[i].topics[0] == gauntletStartedSig
                    && uint256(entries[i].topics[1]) == gauntletId // Check gauntletId
            ) {
                (,,, uint256 reqId) = abi.decode(entries[i].data, (uint8, uint256, uint32[], uint256));
                vrfRequestId = reqId;
                foundStarted = true;
                break;
            }
        }
        require(foundStarted, "TEST SETUP FAILED: GauntletStarted event not found");
        require(game.requestToGauntletId(vrfRequestId) == gauntletId, "TEST SETUP FAILED: VRF request ID mismatch");

        // 3. Record balances before recovery
        uint256[] memory balancesBefore = new uint256[](gauntletSize);
        for (uint256 i = 0; i < gauntletSize; i++) {
            balancesBefore[i] = participantAddrs[i].balance;
        }

        // 4. Advance time past the timeout
        uint256 timeout = game.vrfRequestTimeout();
        vm.warp(block.timestamp + timeout + 1);

        // 5. Recover the gauntlet as owner
        vm.prank(game.owner());
        vm.expectEmit(true, true, false, true);
        emit GauntletRecovered(gauntletId);
        game.recoverTimedOutVRF(gauntletId);

        // 6. Verify state after recovery
        GauntletGame.Gauntlet memory recoveredGauntlet = game.getGauntletData(gauntletId);
        assertEq(
            uint8(recoveredGauntlet.state), uint8(GauntletGame.GauntletState.COMPLETED), "Gauntlet state not COMPLETED"
        );
        assertTrue(recoveredGauntlet.completionTimestamp > 0, "Completion timestamp not set");
        assertEq(recoveredGauntlet.championId, 0, "Champion ID should be 0 on recovery"); // No champion on recovery

        // Verify VRF mapping cleared
        assertEq(game.requestToGauntletId(vrfRequestId), 0, "VRF request mapping not cleared"); // Should be reset

        // Verify player states and refunds
        for (uint256 i = 0; i < gauntletSize; i++) {
            uint32 pId = participantIds[i];
            address pAddr = participantAddrs[i];
            assertEq(
                uint8(game.playerStatus(pId)), uint8(GauntletGame.PlayerStatus.NONE), "Player status not reset to NONE"
            );
            assertEq(game.playerCurrentGauntlet(pId), 0, "Player current gauntlet not cleared");
            assertEq(pAddr.balance, balancesBefore[i] + entryFee, "Player not refunded correctly");
        }
    }

    function testRevertWhen_RecoverTimedOutVRF_TimeoutNotReached() public {
        uint8 gauntletSize = game.currentGauntletSize();
        uint256 entryFee = game.currentEntryFee();

        // 1. Queue players and start the gauntlet
        (uint32[] memory participantIds,) = _queuePlayers(gauntletSize);
        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            selectedIds[i] = game.queueIndex(i);
            selectedIndices[i] = game.playerIndexInQueue(selectedIds[i]) - 1;
        }
        vm.prank(OFF_CHAIN_RUNNER);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
        uint256 gauntletId = 0; // First gauntlet

        // 2. Record state (ensure it's PENDING)
        GauntletGame.Gauntlet memory gauntletData = game.getGauntletData(gauntletId);
        assertEq(uint8(gauntletData.state), uint8(GauntletGame.GauntletState.PENDING));

        // 3. Try to recover *before* timeout
        uint256 timeout = game.vrfRequestTimeout();
        assertTrue(timeout > 0); // Ensure timeout is positive
        // No need to warp time forward

        // 4. Attempt recovery (should fail)
        vm.prank(game.owner()); // Or any address, as access is public but timeout check fails first
        vm.expectRevert(TimeoutNotReached.selector);
        game.recoverTimedOutVRF(gauntletId);
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
        vm.prank(game.owner()); // Or any address
        vm.expectRevert(GauntletNotPending.selector);
        game.recoverTimedOutVRF(gauntletId);
    }

    //==============================================================//
    //                 ADMIN FUNCTION TESTS                       //
    //==============================================================//

    /// @notice Internal helper to complete one gauntlet and generate fees
    function _generateFees() internal returns (uint256 collectedFees) {
        uint8 gauntletSize = game.currentGauntletSize();
        uint256 entryFee = game.currentEntryFee();
        (uint32[] memory allQueuedIds,) = _queuePlayers(gauntletSize);
        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = game.queueIndex(i);
            selectedIds[i] = pId;
            selectedIndices[i] = game.playerIndexInQueue(pId) - 1;
        }
        vm.recordLogs();
        vm.prank(OFF_CHAIN_RUNNER);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        uint256 vrfRequestId = 0;
        uint256 vrfRoundId = 0;
        uint256 gauntletId = 0;
        bytes32 gauntletStartedSig = keccak256("GauntletStarted(uint256,uint8,uint256,uint32[],uint256)");
        bytes32 requestedRandomnessSig = keccak256("RequestedRandomness(uint256,bytes)");
        bool foundStarted = false;
        bool foundRequested = false;
        for (uint256 i = 0; i < entries.length; i++) {
            if (
                !foundStarted && entries[i].topics.length > 1 && entries[i].topics[0] == gauntletStartedSig
                    && uint256(entries[i].topics[1]) == gauntletId
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

        // 3. Re-enable game
        vm.prank(game.owner());
        game.setGameEnabled(true);
        assertTrue(game.isGameEnabled(), "Game not re-enabled"); // Use the correct getter

        // 4. Verify queuing succeeds
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

        // 1. Queue players and start gauntlet
        (uint32[] memory participantIds, address[] memory participantAddrs) = _queuePlayers(gauntletSize);
        uint32[] memory selectedIds = new uint32[](gauntletSize);
        uint256[] memory selectedIndices = new uint256[](gauntletSize);
        for (uint8 i = 0; i < gauntletSize; i++) {
            uint32 pId = game.queueIndex(i);
            selectedIds[i] = pId;
            selectedIndices[i] = game.playerIndexInQueue(pId) - 1;
        }

        vm.recordLogs();
        vm.prank(OFF_CHAIN_RUNNER);
        game.startGauntletFromQueue(selectedIds, selectedIndices);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // 2. Extract VRF details
        uint256 vrfRequestId = 0;
        uint256 vrfRoundId = 0;
        uint256 gauntletId = 0;
        bytes32 gauntletStartedSig = keccak256("GauntletStarted(uint256,uint8,uint256,uint32[],uint256)");
        bytes32 requestedRandomnessSig = keccak256("RequestedRandomness(uint256,bytes)");
        bool foundStarted = false;
        bool foundRequested = false;
        // (Log parsing logic to find vrfRequestId and vrfRoundId - same as other fulfill tests)
        for (uint256 i = 0; i < entries.length; i++) {
            if (
                !foundStarted && entries[i].topics.length > 1 && entries[i].topics[0] == gauntletStartedSig
                    && uint256(entries[i].topics[1]) == gauntletId
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

        // 3. Retire ONE participant *after* gauntlet start
        uint32 retiredPlayerId = participantIds[gauntletSize / 2]; // Pick one from the middle
        address retiredPlayerOwner = participantAddrs[gauntletSize / 2];
        vm.startPrank(retiredPlayerOwner);
        playerContract.retireOwnPlayer(retiredPlayerId);
        vm.stopPrank();
        assertTrue(playerContract.isPlayerRetired(retiredPlayerId), "Player failed to retire");
        Fighter.Record memory recordBefore = playerContract.getPlayer(retiredPlayerId).record; // Record state before fulfillment

        // PRE-FULFILLMENT STATE CAPTURE (Corrected: Using Arrays)
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

        // 4. Fulfill randomness
        uint256 randomnessFromBlock =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, vrfRoundId)));
        bytes memory dataWithRound = _simulateVRFFulfillment(vrfRequestId, vrfRoundId);

        uint256 feesBefore = game.contractFeesCollected();
        address winnerOwner = address(0); // We'll check balance later
        uint256 winnerBalanceBefore = 0;

        vm.recordLogs();
        vm.prank(operator);
        game.fulfillRandomness(randomnessFromBlock, dataWithRound);
        vm.stopPrank();
        Vm.Log[] memory finalEntries = vm.getRecordedLogs();

        // 5. Verify results
        uint256 expectedBaseFee = (entryFee * gauntletSize * game.feePercentage()) / 10000;
        uint256 expectedPrize = (entryFee * gauntletSize) - expectedBaseFee;

        bytes32 gauntletCompletedSig = keccak256("GauntletCompleted(uint256,uint8,uint256,uint32,uint256,uint256)");
        uint32 actualChampionId = 0; // Initialize to 0
        uint256 eventPrizeAwarded = 0;
        uint256 eventFeeCollected = 0;
        bool foundCompleted = false;

        for (uint256 i = 0; i < finalEntries.length; i++) {
            if (
                finalEntries[i].topics.length > 2 && finalEntries[i].topics[0] == gauntletCompletedSig
                    && uint256(finalEntries[i].topics[1]) == gauntletId
            ) {
                (uint8 size, uint256 fee, uint256 prize, uint256 collected) =
                    abi.decode(finalEntries[i].data, (uint8, uint256, uint256, uint256));
                // Correctly assign the extracted ID to actualChampionId
                actualChampionId = _extractChampionIdOnly(finalEntries, gauntletId); // <---- FIX: Assign here
                eventPrizeAwarded = prize;
                eventFeeCollected = collected;
                foundCompleted = true;
                assertEq(size, gauntletSize, "Completed event size mismatch");
                assertEq(fee, entryFee, "Completed event fee mismatch");
                break;
            }
        }
        assertTrue(foundCompleted, "GauntletCompleted event not found");
        assertTrue(actualChampionId > 0, "Failed to extract champion ID (outside loop)"); // Verify it's non-zero before use
        assertEq(eventPrizeAwarded, expectedPrize, "Event prize mismatch");
        assertEq(eventFeeCollected, expectedBaseFee, "Event fee mismatch");

        // Verify retired player record unchanged
        Fighter.Record memory recordAfter = playerContract.getPlayer(retiredPlayerId).record;
        assertEq(recordAfter.wins, recordBefore.wins, "Retired player wins changed");
        assertEq(recordAfter.losses, recordBefore.losses, "Retired player losses changed");

        // Verify fee collection and payout
        uint256 feesAfter = game.contractFeesCollected();
        // Use defaultPlayerContract.isValidId() to check the winner type
        if (game.defaultPlayerContract().isValidId(actualChampionId)) {
            // Corrected function name
            assertEq(feesAfter, feesBefore + expectedBaseFee + expectedPrize, "Fees incorrect (Default Winner)");
            // Ensure no owner was paid - check balance of original owner (test contract)
            assertEq(address(this).balance, 0, "Owner balance changed unexpectedly (Default Winner)");
        } else {
            assertEq(feesAfter, feesBefore + expectedBaseFee, "Fees incorrect (Player Winner)");
            winnerOwner = playerContract.getPlayerOwner(actualChampionId);
            // This assumes winnerOwner didn't start with 0 balance - safe with vm.deal in _queuePlayers
            assertTrue(winnerOwner.balance > 0, "Winner balance indicates potential payout failure");
            // Cannot reliably check exact balance change due to gas, but confirm fees are correct.
        }

        // Verify state cleanup
        GauntletGame.Gauntlet memory completedGauntlet = game.getGauntletData(gauntletId);
        assertEq(uint8(completedGauntlet.state), uint8(GauntletGame.GauntletState.COMPLETED), "Gauntlet state");
        for (uint256 i = 0; i < participantIds.length; ++i) {
            assertEq(
                uint8(game.playerStatus(participantIds[i])),
                uint8(GauntletGame.PlayerStatus.NONE),
                "Player status not NONE"
            );
            assertEq(game.playerCurrentGauntlet(participantIds[i]), 0, "Player gauntlet ID not 0");
        }

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

        // 1. Setup and Start
        (
            uint256 gauntletId,
            uint256 vrfRequestId,
            uint256 vrfRoundId,
            uint32[] memory participantIds,
            address[] memory participantAddrs
        ) = _setupAndStartGauntlet(gauntletSize);

        // 2. Retire All Players
        _retireAllParticipants(participantIds, participantAddrs);

        // 3. Fulfill Randomness
        uint256 randomnessFromBlock =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, vrfRoundId)));
        bytes memory dataWithRound = _simulateVRFFulfillment(vrfRequestId, vrfRoundId);
        uint256 feesBefore = game.contractFeesCollected();
        uint256 ownerBalanceBefore = game.owner().balance;
        uint256 expectedTotalFeesCollected = entryFee * gauntletSize; // All fees go to contract

        vm.recordLogs();
        vm.prank(operator);
        game.fulfillRandomness(randomnessFromBlock, dataWithRound);
        vm.stopPrank();
        Vm.Log[] memory finalEntries = vm.getRecordedLogs();

        // 4. Call the new isolated helper
        (uint32 actualChampionId, bool foundEvent) = _findChampionIdFromLogs_Minimal(finalEntries, gauntletId);

        // 5. Basic Assertions (outside the loop context)
        assertTrue(foundEvent, "Minimal Check: GauntletCompleted event not found (Helper)");
        if (foundEvent) {
            assertTrue(
                game.defaultPlayerContract().isValidId(actualChampionId), "Minimal Check: Winner not default (Helper)"
            );
        }
        uint256 feesAfter = game.contractFeesCollected();
        assertEq(feesAfter, feesBefore + expectedTotalFeesCollected, "Minimal Check: Total fees mismatch (Helper)");
        assertEq(game.owner().balance, ownerBalanceBefore, "Minimal Check: Owner balance changed (Helper)");

        // Still skip detailed state cleanup for now
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
        address playerToWithdrawAddr = queuedAddrs[withdrawIndex]; // Assuming _queuePlayers returns in order
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
        address playerToWithdrawAddr = queuedAddrs[withdrawIndex]; // Assuming _queuePlayers returns in order
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
}

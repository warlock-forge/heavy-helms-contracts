// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {GauntletGame} from "../../src/game/modes/GauntletGame.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";
import {GauntletHandler} from "./handlers/GauntletHandler.sol";

contract GauntletGameInvariantTest is TestBase {
    GauntletGame public game;
    GauntletHandler public handler;

    uint32[] public playerIds;
    address[] public playerOwners;

    uint256 constant NUM_PLAYERS = 8;

    function setUp() public override {
        super.setUp();

        // Deploy gauntlet game (levels 1-4 bracket)
        game = new GauntletGame(
            address(gameEngine),
            payable(address(playerContract)),
            address(defaultPlayerContract),
            GauntletGame.LevelBracket.LEVELS_1_TO_4,
            address(playerTickets)
        );

        // Transfer defaultPlayerContract ownership so game can use NPCs
        defaultPlayerContract.transferOwnership(address(game));

        // Grant game permissions on player contract
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, immortal: false, experience: true});
        playerContract.setGameContractPermission(address(game), perms);

        // Set gauntlet size to 4 and remove time gate for testing
        game.setGameEnabled(false);
        game.setGauntletSize(4);
        game.setGameEnabled(true);
        game.setMinTimeBetweenGauntlets(0);

        // Create a pool of players
        for (uint256 i = 0; i < NUM_PLAYERS; i++) {
            address owner = address(uint160(0x2001 + i));
            vm.deal(owner, 100 ether);
            uint32 playerId = _createPlayerAndFulfillVRF(owner, false);
            playerIds.push(playerId);
            playerOwners.push(owner);
        }

        // Deploy handler
        handler = new GauntletHandler(game, playerContract, playerIds, playerOwners);

        // Target only the handler
        targetContract(address(handler));
    }

    //==============================================================//
    //                         INVARIANTS                           //
    //==============================================================//

    /// @notice queueIndex.length must equal the number of players with QUEUED status
    function invariant_QueueSizeMatchesPlayerStatuses() public view {
        uint256 queueSize = game.getQueueSize();
        uint256 queuedCount = 0;

        for (uint256 i = 0; i < handler.getPlayerIdsLength(); i++) {
            uint32 pid = handler.getPlayerId(i);
            if (game.playerStatus(pid) == GauntletGame.PlayerStatus.QUEUED) {
                queuedCount++;
            }
        }

        // Queued count from player statuses must match queue array length
        // (queue may also contain default players from incomplete gauntlets,
        //  so queueSize >= queuedCount)
        assertGe(queueSize, queuedCount, "Queue size < queued player count");
    }

    /// @notice Every player in queueIndex must have QUEUED status
    function invariant_QueuePlayersAreQueued() public view {
        uint256 queueSize = game.getQueueSize();
        for (uint256 i = 0; i < queueSize; i++) {
            uint32 pid = game.queueIndex(i);
            // Default players (ID <= 2000) don't track status
            if (pid > 2000) {
                assertEq(
                    uint8(game.playerStatus(pid)),
                    uint8(GauntletGame.PlayerStatus.QUEUED),
                    "Player in queue without QUEUED status"
                );
            }
        }
    }

    /// @notice playerIndexInQueue must be consistent with queueIndex
    function invariant_QueueIndexMappingConsistent() public view {
        uint256 queueSize = game.getQueueSize();
        for (uint256 i = 0; i < queueSize; i++) {
            uint32 pid = game.queueIndex(i);
            uint256 mappedIndex = game.playerIndexInQueue(pid);
            assertEq(mappedIndex, i + 1, "playerIndexInQueue inconsistent with queueIndex position");
        }
    }

    /// @notice Contract ETH balance must be >= ghost-tracked reset fees
    function invariant_BalanceCoversResetFees() public view {
        assertGe(
            address(game).balance, handler.ghost_resetFeesCollected(), "Contract balance less than collected reset fees"
        );
    }

    /// @notice Players with IN_TOURNAMENT status must have a valid gauntlet assignment
    function invariant_InTournamentPlayersHaveGauntlet() public view {
        for (uint256 i = 0; i < handler.getPlayerIdsLength(); i++) {
            uint32 pid = handler.getPlayerId(i);
            if (game.playerStatus(pid) == GauntletGame.PlayerStatus.IN_TOURNAMENT) {
                uint256 gauntletId = game.playerCurrentGauntlet(pid);
                // The gauntlet should be a valid pending one (id < nextGauntletId or pending)
                (bool pendingExists,,,, uint256 pendingId,) = game.getPendingGauntletInfo();
                assertTrue(pendingExists && gauntletId == pendingId, "IN_TOURNAMENT player not in pending gauntlet");
            }
        }
    }

    /// @notice Ghost accounting: queued - withdrawn - (completed * gauntletSize) should roughly track queue
    function invariant_GhostAccountingSound() public view {
        // Total queued minus withdrawn should be >= current queue size
        // (some players get consumed by gauntlets)
        uint256 consumed = handler.ghost_totalQueued() - handler.ghost_totalWithdrawn();
        assertGe(consumed, game.getQueueSize(), "More in queue than ever queued minus withdrawn");
    }

    /// @notice After a run, no player should be stuck in IN_TOURNAMENT with no pending gauntlet
    function invariant_NoStuckTournamentPlayers() public view {
        (bool pendingExists,,,,,) = game.getPendingGauntletInfo();
        if (!pendingExists) {
            for (uint256 i = 0; i < handler.getPlayerIdsLength(); i++) {
                uint32 pid = handler.getPlayerId(i);
                assertTrue(
                    game.playerStatus(pid) != GauntletGame.PlayerStatus.IN_TOURNAMENT,
                    "Player stuck IN_TOURNAMENT with no pending gauntlet"
                );
            }
        }
    }

    /// @notice Call summary for debugging failed runs
    function invariant_callSummary() public view {
        // This invariant always passes -- it just logs call counts for debugging
        handler.calls_queue();
        handler.calls_withdraw();
        handler.calls_tryStart();
        handler.calls_resetDaily();
    }
}

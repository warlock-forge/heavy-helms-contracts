// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {TournamentGame} from "../../../src/game/modes/TournamentGame.sol";
import {Player} from "../../../src/fighters/Player.sol";
import {Fighter} from "../../../src/fighters/Fighter.sol";

/// @notice Handler for TournamentGame invariant testing.
/// @dev Exercises queue management and tournament lifecycle via 3-phase blockhash commit-reveal.
contract TournamentHandler is Test {
    TournamentGame public game;
    Player public playerContract;

    // Pool of valid level-10 player IDs and their owners
    uint32[] public playerIds;
    mapping(uint32 => address) public playerOwners;

    // Ghost variables
    uint256 public ghost_totalQueued;
    uint256 public ghost_totalWithdrawn;
    uint256 public ghost_tournamentsCompleted;

    // Call counters
    uint256 public calls_queue;
    uint256 public calls_withdraw;
    uint256 public calls_tryStart;

    constructor(TournamentGame _game, Player _playerContract, uint32[] memory _playerIds, address[] memory _owners) {
        game = _game;
        playerContract = _playerContract;

        for (uint256 i = 0; i < _playerIds.length; i++) {
            playerIds.push(_playerIds[i]);
            playerOwners[_playerIds[i]] = _owners[i];
        }
    }

    // --- Handler Actions ---

    /// @notice Queue a random player for tournament
    function queueForTournament(uint256 playerSeed) external {
        if (playerIds.length == 0) return;
        uint32 playerId = playerIds[playerSeed % playerIds.length];
        address owner = playerOwners[playerId];

        // Skip if already queued or in tournament
        if (game.playerStatus(playerId) != TournamentGame.PlayerStatus.NONE) return;
        // Skip if retired
        if (playerContract.isPlayerRetired(playerId)) return;

        Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
            playerId: playerId, skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}), stance: 1
        });

        vm.prank(owner);
        try game.queueForTournament(loadout) {
            ghost_totalQueued++;
            calls_queue++;
        } catch {}
    }

    /// @notice Withdraw a random player from queue
    function withdrawFromQueue(uint256 playerSeed) external {
        if (playerIds.length == 0) return;
        uint32 playerId = playerIds[playerSeed % playerIds.length];
        address owner = playerOwners[playerId];

        // Only withdraw if actually queued
        if (game.playerStatus(playerId) != TournamentGame.PlayerStatus.QUEUED) return;

        vm.prank(owner);
        try game.withdrawFromQueue(playerId) {
            ghost_totalWithdrawn++;
            calls_withdraw++;
        } catch {}
    }

    /// @notice Advance the tournament state machine
    function tryStartTournament(uint256 blockSkip) external {
        // Check if we're mid-tournament (pending exists) or need to start fresh
        (bool pendingExists,, uint256 tournamentBlock, uint8 phase,,) = game.getPendingTournamentInfo();

        if (pendingExists && phase > 0) {
            // Mid-tournament: roll past the target block for phase transition
            (, uint256 selectionBlock,,,,) = game.getPendingTournamentInfo();
            uint256 targetBlock = phase == 1 ? selectionBlock : tournamentBlock;
            if (block.number <= targetBlock) {
                vm.roll(targetBlock + 1);
                vm.warp(block.timestamp + (targetBlock + 1 - block.number) * 12);
            }
        } else {
            // No pending tournament: warp to next valid 20:00 UTC window
            uint256 nextDay = block.timestamp + 1 days;
            nextDay = nextDay - (nextDay % 1 days) + 20 hours;
            vm.warp(nextDay);
            // Roll forward some blocks too
            blockSkip = bound(blockSkip, 1, 10);
            vm.roll(block.number + blockSkip);
        }

        // Set prevrandao for blockhash-based randomness
        vm.prevrandao(bytes32(uint256(12345)));

        uint256 tournamentIdBefore = game.nextTournamentId();

        try game.tryStartTournament() {
            calls_tryStart++;
            if (game.nextTournamentId() > tournamentIdBefore) {
                ghost_tournamentsCompleted++;
            }
        } catch {}
    }

    // --- View helpers ---

    function getPlayerIdsLength() external view returns (uint256) {
        return playerIds.length;
    }

    function getPlayerId(uint256 index) external view returns (uint32) {
        return playerIds[index];
    }
}

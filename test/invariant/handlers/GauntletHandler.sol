// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {GauntletGame} from "../../../src/game/modes/GauntletGame.sol";
import {Fighter} from "../../../src/fighters/Fighter.sol";
import {Player} from "../../../src/fighters/Player.sol";

/// @notice Handler for GauntletGame invariant testing.
/// @dev Exposes curated actions that Foundry calls in random sequences.
///      Tracks ghost variables for invariant assertions.
contract GauntletHandler is Test {
    GauntletGame public game;
    Player public playerContract;

    // Pool of valid player IDs and their owners
    uint32[] public playerIds;
    mapping(uint32 => address) public playerOwners;

    // Ghost variables for invariant checking
    uint256 public ghost_totalQueued;
    uint256 public ghost_totalWithdrawn;
    uint256 public ghost_totalGauntletsCompleted;
    uint256 public ghost_resetFeesCollected;

    // Track calls for debugging
    uint256 public calls_queue;
    uint256 public calls_withdraw;
    uint256 public calls_tryStart;
    uint256 public calls_resetDaily;

    constructor(GauntletGame _game, Player _playerContract, uint32[] memory _playerIds, address[] memory _owners) {
        game = _game;
        playerContract = _playerContract;

        for (uint256 i = 0; i < _playerIds.length; i++) {
            playerIds.push(_playerIds[i]);
            playerOwners[_playerIds[i]] = _owners[i];
        }
    }

    // --- Handler Actions ---

    /// @notice Queue a random player for gauntlet
    function queueForGauntlet(uint256 playerSeed) external {
        if (playerIds.length == 0) return;
        uint32 playerId = playerIds[playerSeed % playerIds.length];
        address owner = playerOwners[playerId];

        // Skip if already queued or in tournament
        if (game.playerStatus(playerId) != GauntletGame.PlayerStatus.NONE) return;
        // Skip if retired
        if (playerContract.isPlayerRetired(playerId)) return;

        Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
            playerId: playerId, skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}), stance: 2
        });

        vm.prank(owner);
        try game.queueForGauntlet(loadout) {
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
        if (game.playerStatus(playerId) != GauntletGame.PlayerStatus.QUEUED) return;

        vm.prank(owner);
        try game.withdrawFromQueue(playerId) {
            ghost_totalWithdrawn++;
            calls_withdraw++;
        } catch {}
    }

    /// @notice Advance the gauntlet state machine (any phase)
    function tryStartGauntlet(uint256 blockSkip) external {
        // Roll forward 1-50 blocks to allow phase transitions
        blockSkip = bound(blockSkip, 1, 50);
        vm.roll(block.number + blockSkip);
        vm.warp(block.timestamp + blockSkip * 12);

        uint256 gauntletIdBefore = game.nextGauntletId();

        try game.tryStartGauntlet() {
            calls_tryStart++;
            if (game.nextGauntletId() > gauntletIdBefore) {
                ghost_totalGauntletsCompleted++;
            }
        } catch {}
    }

    /// @notice Reset a player's daily limit with ETH
    function resetDailyLimit(uint256 playerSeed) external {
        if (playerIds.length == 0) return;
        uint32 playerId = playerIds[playerSeed % playerIds.length];
        address owner = playerOwners[playerId];

        uint256 cost = game.dailyResetCost();
        vm.deal(owner, cost);

        vm.prank(owner);
        try game.resetDailyLimit{value: cost}(playerId) {
            ghost_resetFeesCollected += cost;
            calls_resetDaily++;
        } catch {}
    }

    // --- View helpers for invariant test ---

    function getPlayerIdsLength() external view returns (uint256) {
        return playerIds.length;
    }

    function getPlayerId(uint256 index) external view returns (uint32) {
        return playerIds[index];
    }
}

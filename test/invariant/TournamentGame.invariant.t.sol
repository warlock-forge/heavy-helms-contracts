// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {TournamentGame} from "../../src/game/modes/TournamentGame.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";
import {TournamentHandler} from "./handlers/TournamentHandler.sol";

contract TournamentGameInvariantTest is TestBase {
    TournamentGame public game;
    TournamentHandler public handler;

    uint32[] public pIds;
    address[] public pOwners;

    uint256 constant NUM_PLAYERS = 20;

    function setUp() public override {
        super.setUp();

        // Deploy tournament game
        game = new TournamentGame(
            address(gameEngine),
            payable(address(playerContract)),
            address(defaultPlayerContract),
            address(playerTickets)
        );

        // Transfer defaultPlayerContract ownership so game can use NPCs
        defaultPlayerContract.transferOwnership(address(game));

        // Grant game permissions (record + retire for death + experience for XP)
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: true, immortal: false, experience: true});
        playerContract.setGameContractPermission(address(game), perms);

        // Grant this test contract experience permissions for leveling
        IPlayer.GamePermissions memory testPerms =
            IPlayer.GamePermissions({record: false, retire: false, immortal: false, experience: true});
        playerContract.setGameContractPermission(address(this), testPerms);

        // Grant tournament game ticket minting permissions
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: true,
            playerSlots: true,
            nameChanges: true,
            weaponSpecialization: true,
            armorSpecialization: true,
            duels: true,
            dailyResets: true,
            attributeSwaps: true
        });
        playerTickets.setGameContractPermission(address(game), ticketPerms);

        // Set smallest tournament size for faster invariant runs
        game.setTournamentSize(16);

        // Create pool of level-10 players
        for (uint256 i = 0; i < NUM_PLAYERS; i++) {
            address owner = address(uint160(0x6001 + i));
            vm.deal(owner, 100 ether);
            uint32 playerId = _createPlayerAndFulfillVRF(owner, false);
            _levelUpPlayer(playerId, 9);
            pIds.push(playerId);
            pOwners.push(owner);
        }

        // Warp to valid tournament time (20:00 UTC, 48+ hours after deployment)
        uint256 futureTime = block.timestamp + 48 hours;
        futureTime = futureTime - (futureTime % 1 days) + 20 hours;
        vm.warp(futureTime);

        // Deploy handler
        handler = new TournamentHandler(game, playerContract, pIds, pOwners);

        targetContract(address(handler));
    }

    //==============================================================//
    //                         INVARIANTS                           //
    //==============================================================//

    /// @notice queueIndex.length must match QUEUED player count
    function invariant_QueueSizeMatchesPlayerStatuses() public view {
        uint256 queueSize = game.getQueueSize();
        uint256 queuedCount = 0;

        for (uint256 i = 0; i < handler.getPlayerIdsLength(); i++) {
            uint32 pid = handler.getPlayerId(i);
            if (game.playerStatus(pid) == TournamentGame.PlayerStatus.QUEUED) {
                queuedCount++;
            }
        }

        // Queue may also contain default players from incomplete tournaments
        assertGe(queueSize, queuedCount, "Queue size < queued player count");
    }

    /// @notice Every real player in queueIndex must have QUEUED status
    function invariant_QueuePlayersAreQueued() public view {
        uint256 queueSize = game.getQueueSize();
        for (uint256 i = 0; i < queueSize; i++) {
            uint32 pid = game.queueIndex(i);
            // Default players (ID <= 2000) don't track status
            if (pid > 2000) {
                assertEq(
                    uint8(game.playerStatus(pid)),
                    uint8(TournamentGame.PlayerStatus.QUEUED),
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

    /// @notice No player stuck IN_TOURNAMENT when no pending tournament exists
    function invariant_NoStuckTournamentPlayers() public view {
        (bool pendingExists,,,,,) = game.getPendingTournamentInfo();
        if (!pendingExists) {
            for (uint256 i = 0; i < handler.getPlayerIdsLength(); i++) {
                uint32 pid = handler.getPlayerId(i);
                assertTrue(
                    game.playerStatus(pid) != TournamentGame.PlayerStatus.IN_TOURNAMENT,
                    "Player stuck IN_TOURNAMENT with no pending tournament"
                );
            }
        }
    }

    /// @notice Ghost accounting: queued - withdrawn >= current queue size
    function invariant_GhostAccountingSound() public view {
        uint256 consumed = handler.ghost_totalQueued() - handler.ghost_totalWithdrawn();
        assertGe(consumed, game.getQueueSize(), "More in queue than ever queued minus withdrawn");
    }

    /// @notice Call summary for debugging
    function invariant_callSummary() public view {
        handler.calls_queue();
        handler.calls_withdraw();
        handler.calls_tryStart();
    }

    //==============================================================//
    //                          HELPERS                             //
    //==============================================================//

    function _levelUpPlayer(uint32 playerId, uint256 levels) internal {
        for (uint256 i = 0; i < levels; i++) {
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
            uint16 xpNeeded = playerContract.getXPRequiredForLevel(stats.level + 1) - stats.currentXP;
            playerContract.awardExperience(playerId, xpNeeded);
        }
    }
}

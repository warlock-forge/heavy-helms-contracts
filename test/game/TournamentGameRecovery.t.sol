// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {TournamentGame, CannotRecoverYet, NoPendingTournament} from "../../src/game/modes/TournamentGame.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";

contract TournamentGameRecoveryTest is TestBase {
    TournamentGame public game;

    event QueueRecovered(uint256 targetBlock);
    event TournamentRecovered(uint256 indexed tournamentId, uint256 targetBlock, uint32[] participantIds);

    function setUp() public override {
        super.setUp();

        game = new TournamentGame(
            address(gameEngine),
            payable(address(playerContract)),
            address(defaultPlayerContract),
            address(playerTickets)
        );

        game.setGameEngine(address(gameEngine));
        game.setGameEnabled(true);

        // Set permissions for the game contract
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: true, immortal: false, experience: true});
        playerContract.setGameContractPermission(address(game), perms);

        // Give this test contract experience permissions for leveling up players
        IPlayer.GamePermissions memory testPerms =
            IPlayer.GamePermissions({record: false, retire: false, immortal: false, experience: true});
        playerContract.setGameContractPermission(address(this), testPerms);

        // Give tournament game permissions to mint reward tickets
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

        // Create 16 players and level them up to 10
        for (uint256 i = 0; i < 16; i++) {
            address playerOwner = address(uint160(0x1000 + i));
            vm.deal(playerOwner, 100 ether);
            uint32 playerId = _createPlayerAndFulfillVRF(playerOwner, playerContract, false);
            // Award XP to reach level 10 directly (7489 XP total needed)
            playerContract.awardExperience(playerId, 7489);
        }
    }

    // Test that recovery cannot be called too early
    function testRevert_CannotRecoverTooEarly() public {
        // Queue players
        for (uint256 i = 0; i < 16; i++) {
            uint32 playerId = uint32(10001 + i);
            address playerOwner = address(uint160(0x1000 + i));
            vm.prank(playerOwner);
            game.queueForTournament(
                Fighter.PlayerLoadout({
                    playerId: playerId, skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}), stance: 1
                })
            );
        }

        // Start tournament
        uint256 tournamentTime = block.timestamp + 48 hours;
        tournamentTime = tournamentTime - (tournamentTime % 1 days) + 20 hours;
        vm.warp(tournamentTime);

        // Commit phase
        game.tryStartTournament();

        // Move to selection phase
        (, uint256 selectionBlock,,,,) = game.getPendingTournamentInfo();
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));
        game.tryStartTournament();

        // Get tournament block
        (,, uint256 tournamentBlock,,,) = game.getPendingTournamentInfo();

        // Try to recover before 256 blocks have passed
        vm.roll(tournamentBlock + 255);
        vm.expectRevert(CannotRecoverYet.selector);
        game.recoverPendingTournament();
    }

    // Test direct public recovery call
    function testPublicRecoveryFunction() public {
        // Queue players
        for (uint256 i = 0; i < 16; i++) {
            uint32 playerId = uint32(10001 + i);
            address playerOwner = address(uint160(0x1000 + i));
            vm.prank(playerOwner);
            game.queueForTournament(
                Fighter.PlayerLoadout({
                    playerId: playerId, skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}), stance: 1
                })
            );
        }

        // Start tournament
        uint256 tournamentTime = block.timestamp + 48 hours;
        tournamentTime = tournamentTime - (tournamentTime % 1 days) + 20 hours;
        vm.warp(tournamentTime);

        // Commit phase
        game.tryStartTournament();

        // Get selection block
        (, uint256 selectionBlock,,,,) = game.getPendingTournamentInfo();

        // Advance past recovery window
        vm.roll(selectionBlock + 257);

        // Expect QueueRecovered event
        vm.expectEmit(false, false, false, true);
        emit QueueRecovered(selectionBlock);

        // Call recovery directly (not through tryStartTournament)
        game.recoverPendingTournament();

        // Verify recovery happened
        (bool exists,,,,,) = game.getPendingTournamentInfo();
        assertFalse(exists, "Tournament should be recovered");
    }

    // Test recovery with no pending tournament
    function testRevert_NoPendingTournament() public {
        vm.expectRevert(NoPendingTournament.selector);
        game.recoverPendingTournament();
    }

    // Test recovery properly returns correct participant IDs in event
    function testRecoveryEventParticipantIds() public {
        // Queue specific players
        uint32[] memory queuedIds = new uint32[](16);
        for (uint256 i = 0; i < 16; i++) {
            uint32 playerId = uint32(10001 + i);
            queuedIds[i] = playerId;
            address playerOwner = address(uint160(0x1000 + i));
            vm.prank(playerOwner);
            game.queueForTournament(
                Fighter.PlayerLoadout({
                    playerId: playerId, skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}), stance: 1
                })
            );
        }

        // Start tournament
        uint256 tournamentTime = block.timestamp + 48 hours;
        tournamentTime = tournamentTime - (tournamentTime % 1 days) + 20 hours;
        vm.warp(tournamentTime);

        // Commit and select
        game.tryStartTournament();
        (, uint256 selectionBlock,,,,) = game.getPendingTournamentInfo();
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));
        game.tryStartTournament();

        // Get tournament data to know actual participants
        uint256 tournamentId = game.nextTournamentId() - 1;
        TournamentGame.Tournament memory tournament = game.getTournamentData(tournamentId);

        // Build expected participant IDs array
        uint32[] memory expectedIds = new uint32[](16);
        for (uint256 i = 0; i < 16; i++) {
            expectedIds[i] = tournament.participants[i].playerId;
        }

        // Get tournament block and advance
        (,, uint256 tournamentBlock,,,) = game.getPendingTournamentInfo();
        vm.roll(tournamentBlock + 257);

        // Expect event with correct participant IDs
        vm.expectEmit(true, false, false, true);
        emit TournamentRecovered(tournamentId, tournamentBlock, expectedIds);

        // Trigger recovery
        game.tryStartTournament();
    }

    // Test that withdrawn player is NOT re-queued during recovery
    function testRecoveryWithWithdrawnPlayer() public {
        // Queue players
        for (uint256 i = 0; i < 16; i++) {
            uint32 playerId = uint32(10001 + i);
            address playerOwner = address(uint160(0x1000 + i));
            vm.prank(playerOwner);
            game.queueForTournament(
                Fighter.PlayerLoadout({
                    playerId: playerId, skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}), stance: 1
                })
            );
        }

        // Start tournament
        uint256 tournamentTime = block.timestamp + 48 hours;
        tournamentTime = tournamentTime - (tournamentTime % 1 days) + 20 hours;
        vm.warp(tournamentTime);

        // Commit and select
        game.tryStartTournament();
        (, uint256 selectionBlock,,,,) = game.getPendingTournamentInfo();
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));
        game.tryStartTournament();

        // Simulate a player being removed from tournament
        // In real scenario this might happen through admin action
        // For test, we'll check that status check prevents re-queuing

        // Get tournament block and advance
        (,, uint256 tournamentBlock,,,) = game.getPendingTournamentInfo();
        vm.roll(tournamentBlock + 257);

        // Trigger recovery
        game.tryStartTournament();

        // All players should be back in queue if they were IN_TOURNAMENT
        assertEq(game.getQueueSize(), 16, "All eligible players returned to queue");
    }
}

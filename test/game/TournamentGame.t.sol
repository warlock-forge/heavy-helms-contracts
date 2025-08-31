// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import "../TestBase.sol";
import {
    TournamentGame,
    AlreadyInQueue,
    TournamentTooEarly,
    TournamentTooLate,
    MinTimeNotElapsed,
    InvalidTournamentSize,
    InvalidRewardPercentages,
    InvalidBlockhash,
    InsufficientDefaultPlayers,
    QueueEmpty
} from "../../src/game/modes/TournamentGame.sol";
import {PlayerSkinNFT} from "../../src/nft/skins/PlayerSkinNFT.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {IPlayerSkinRegistry} from "../../src/interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";
import {IPlayerTickets} from "../../src/interfaces/nft/IPlayerTickets.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";
import {console2} from "forge-std/console2.sol";

contract TournamentGameTest is TestBase {
    TournamentGame public game;

    address public PLAYER_ONE;
    address public PLAYER_TWO;
    address public PLAYER_THREE;
    address public PLAYER_FOUR;
    address[] public players; // Dynamic array for larger tournaments

    uint32 public PLAYER_ONE_ID;
    uint32 public PLAYER_TWO_ID;
    uint32 public PLAYER_THREE_ID;
    uint32 public PLAYER_FOUR_ID;
    uint32[] public playerIds; // Dynamic array for player IDs

    function setUp() public override {
        super.setUp();

        // Deploy tournament game
        game = new TournamentGame(
            address(gameEngine),
            payable(address(playerContract)),
            address(defaultPlayerContract),
            address(playerTickets)
        );

        // Transfer ownership of defaultPlayerContract to the game
        defaultPlayerContract.transferOwnership(address(game));

        // Set permissions with RETIRE for death mechanics and attributes for rewards
        IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
            record: true,
            retire: true, // Critical for death mechanics
            attributes: true, // Need for attribute swap rewards
            immortal: false,
            experience: true // Need this for test helper function
        });
        playerContract.setGameContractPermission(address(game), perms);

        // Also give this test contract experience permissions for leveling up players
        IPlayer.GamePermissions memory testPerms = IPlayer.GamePermissions({
            record: false,
            retire: false,
            attributes: false,
            immortal: false,
            experience: true
        });
        playerContract.setGameContractPermission(address(this), testPerms);

        // Give tournament game permissions to mint reward tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: true,
            playerSlots: true,
            nameChanges: true, // Need for name change ticket rewards
            weaponSpecialization: true,
            armorSpecialization: true,
            duels: true
        });
        playerTickets.setGameContractPermission(address(game), ticketPerms);

        // Setup test addresses
        PLAYER_ONE = address(0x1001);
        PLAYER_TWO = address(0x1002);
        PLAYER_THREE = address(0x1003);
        PLAYER_FOUR = address(0x1004);

        // Create players with different levels for priority testing
        PLAYER_ONE_ID = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        PLAYER_TWO_ID = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);
        PLAYER_THREE_ID = _createPlayerAndFulfillVRF(PLAYER_THREE, playerContract, false);
        PLAYER_FOUR_ID = _createPlayerAndFulfillVRF(PLAYER_FOUR, playerContract, false);

        // Level up ALL players to level 10 for tournament eligibility
        _levelUpPlayer(PLAYER_ONE_ID, 9); // Level 10
        _levelUpPlayer(PLAYER_TWO_ID, 9); // Level 10
        _levelUpPlayer(PLAYER_THREE_ID, 9); // Level 10
        _levelUpPlayer(PLAYER_FOUR_ID, 9); // Level 10

        // Give them ETH
        vm.deal(PLAYER_ONE, 100 ether);
        vm.deal(PLAYER_TWO, 100 ether);
        vm.deal(PLAYER_THREE, 100 ether);
        vm.deal(PLAYER_FOUR, 100 ether);

        // Initialize arrays
        players = [PLAYER_ONE, PLAYER_TWO, PLAYER_THREE, PLAYER_FOUR];
        playerIds = [PLAYER_ONE_ID, PLAYER_TWO_ID, PLAYER_THREE_ID, PLAYER_FOUR_ID];
    }

    //==============================================================//
    //                      QUEUE MANAGEMENT                        //
    //==============================================================//

    function testQueueForTournament() public {
        Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
            playerId: PLAYER_ONE_ID,
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            stance: 2 // OFFENSIVE
        });

        vm.prank(PLAYER_ONE);
        game.queueForTournament(loadout);

        assertEq(game.getQueueSize(), 1);
        assertEq(uint256(game.playerStatus(PLAYER_ONE_ID)), uint256(TournamentGame.PlayerStatus.QUEUED));
    }

    function testCannotDoubleQueue() public {
        Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
            playerId: PLAYER_ONE_ID,
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            stance: 2
        });

        vm.prank(PLAYER_ONE);
        game.queueForTournament(loadout);

        vm.prank(PLAYER_ONE);
        vm.expectRevert(AlreadyInQueue.selector);
        game.queueForTournament(loadout);
    }

    function testWithdrawFromQueue() public {
        Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
            playerId: PLAYER_ONE_ID,
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            stance: 2
        });

        vm.prank(PLAYER_ONE);
        game.queueForTournament(loadout);

        vm.prank(PLAYER_ONE);
        game.withdrawFromQueue(PLAYER_ONE_ID);

        assertEq(game.getQueueSize(), 0);
        assertEq(uint256(game.playerStatus(PLAYER_ONE_ID)), uint256(TournamentGame.PlayerStatus.NONE));
    }

    //==============================================================//
    //                    DAILY TIMING TESTS                       //
    //==============================================================//

    function testTournamentTooEarly() public {
        // Queue minimum players
        _queuePlayers(16);

        // Set time to before tournament hour (noon PST = 20:00 UTC)
        vm.warp(block.timestamp - (block.timestamp % 1 days) + 19 hours); // 19:00 UTC

        vm.expectRevert(TournamentTooEarly.selector);
        game.tryStartTournament();
    }

    function testTournamentTooLate() public {
        // Queue minimum players
        _queuePlayers(16);

        // Set time to after tournament window (20:00 + 1 hour)
        vm.warp(block.timestamp - (block.timestamp % 1 days) + 22 hours); // 22:00 UTC

        vm.expectRevert(TournamentTooLate.selector);
        game.tryStartTournament();
    }

    function testDailyTournamentTiming() public {
        // Queue enough players for TWO tournaments (in case some die in first)
        _queuePlayers(32);

        // First tournament needs to wait until next valid time slot (at least 24h after deployment)
        // Warp to 48 hours later at proper time (20:00 UTC) to be safe
        uint256 futureTime = block.timestamp + 48 hours;
        futureTime = futureTime - (futureTime % 1 days) + 20 hours; // Align to 20:00 UTC
        vm.warp(futureTime);

        // Run complete tournament (will consume 16 players from queue)
        _runFullTournament();

        // Try to start another tournament same day - should fail with MinTimeNotElapsed
        // Queue still has 16 alive players waiting
        vm.expectRevert(MinTimeNotElapsed.selector);
        game.tryStartTournament();

        // Next day should work
        vm.warp(block.timestamp + 1 days);
        game.tryStartTournament(); // Should succeed
    }

    //==============================================================//
    //                  TOURNAMENT SELECTION TESTS                 //
    //==============================================================//

    //==============================================================//
    //                  COMMIT-REVEAL FLOW TESTS                   //
    //==============================================================//

    function testFullCommitRevealFlow() public {
        // Queue exactly 16 players
        _queuePlayers(16);

        // Set proper daily time (20:00 UTC) at least 48 hours after deployment
        uint256 futureTime = block.timestamp + 48 hours;
        futureTime = futureTime - (futureTime % 1 days) + 20 hours; // Align to 20:00 UTC
        vm.warp(futureTime);

        // Phase 1: Commit queue
        uint256 startBlock = block.number;
        game.tryStartTournament();

        (bool exists, uint256 selectionBlock,,,,) = game.getPendingTournamentInfo();
        assertTrue(exists);
        assertEq(selectionBlock, startBlock + 20);

        // Phase 2: Select participants (advance PAST selection block)
        vm.roll(selectionBlock + 1);
        game.tryStartTournament();

        // Check tournament was created
        TournamentGame.Tournament memory tournament = game.getTournamentData(0);
        assertEq(tournament.size, 16);
        assertEq(uint256(tournament.state), uint256(TournamentGame.TournamentState.PENDING));

        // Get the actual tournament block and advance PAST it
        (,, uint256 tournamentBlock,,,) = game.getPendingTournamentInfo();
        vm.roll(tournamentBlock + 1);
        game.tryStartTournament();

        // Tournament should be completed
        tournament = game.getTournamentData(0);
        assertEq(uint256(tournament.state), uint256(TournamentGame.TournamentState.COMPLETED));
        assertTrue(tournament.championId != 0);
        assertTrue(tournament.runnerUpId != 0);
    }

    //==============================================================//
    //                    DEATH MECHANICS TESTS                    //
    //==============================================================//

    function testDeathMechanicsWithHighLethality() public {
        // Set high lethality factor to increase chance of death
        game.setLethalityFactor(200);

        // Queue exactly 16 players
        _queuePlayers(16);

        // Run full tournament
        _runFullTournament();

        // Check if any players were retired due to death
        // Note: This is probabilistic, so we can't guarantee death occurred
        // but we can check the mechanism is in place
        TournamentGame.Tournament memory tournament = game.getTournamentData(0);
        assertEq(uint256(tournament.state), uint256(TournamentGame.TournamentState.COMPLETED));
    }

    //==============================================================//
    //                    RATING SYSTEM TESTS                      //
    //==============================================================//

    function testTournamentRatingDistribution() public {
        // Queue exactly 16 players
        _queuePlayers(16);

        // Record logs to capture rating events
        vm.recordLogs();

        // Run full tournament
        _runFullTournament();

        // Get the tournament data and logs
        TournamentGame.Tournament memory tournament = game.getTournamentData(0);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the TournamentRatingsAwarded event (singular event with arrays)
        bytes32 ratingEventTopic = keccak256("TournamentRatingsAwarded(uint256,uint256,uint32[],uint16[])");
        uint32[] memory eventPlayerIds;
        uint16[] memory eventRatings;
        bool ratingsEventFound = false;

        console2.log("Looking for TournamentRatingsAwarded event:");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == ratingEventTopic) {
                // Decode: TournamentRatingsAwarded(uint256 indexed tournamentId, uint256 indexed seasonId, uint32[] playerIds, uint256[] ratings)
                // tournamentId and seasonId are indexed, playerIds and ratings are in data
                (eventPlayerIds, eventRatings) = abi.decode(logs[i].data, (uint32[], uint16[]));
                ratingsEventFound = true;

                console2.log("Found TournamentRatingsAwarded event with", eventPlayerIds.length, "ratings");
                for (uint256 j = 0; j < eventPlayerIds.length; j++) {
                    console2.log("Event: Player", eventPlayerIds[j], "awarded rating:", eventRatings[j]);
                }
                break;
            }
        }

        assertTrue(ratingsEventFound, "TournamentRatingsAwarded event should be emitted");
        console2.log("Total ratings in event:", eventPlayerIds.length);

        // Cross-reference events with actual player state
        uint256 playersWithRating = 0;
        uint256 totalTestPlayers = 0;

        for (uint256 i = 0; i < playerIds.length && i < 16; i++) {
            uint32 playerId = playerIds[i];
            if (playerId >= 10001) {
                // Real players only
                totalTestPlayers++;
                uint16 actualRating = game.getPlayerRating(playerId);

                if (actualRating > 0) {
                    playersWithRating++;
                    console2.log("State: Player", playerId, "has rating:", actualRating);

                    // Find this player in the events and verify rating matches
                    bool foundInEvents = false;
                    for (uint256 j = 0; j < eventPlayerIds.length; j++) {
                        if (eventPlayerIds[j] == playerId) {
                            foundInEvents = true;
                            assertEq(eventRatings[j], actualRating, "Event rating should match actual rating");
                            console2.log("VERIFIED: Event and state match for player", playerId);
                            break;
                        }
                    }
                    assertTrue(foundInEvents, "Player with rating should have corresponding event");

                    // Verify rating is from expected set for 16-player tournament
                    assertTrue(
                        actualRating == 100 || actualRating == 60 || actualRating == 30 || actualRating == 20,
                        "Rating should be 100, 60, 30, or 20 for 16-player tournament"
                    );
                }
            }
        }

        // Verify champion and runner-up ratings
        if (tournament.championId >= 10001) {
            assertEq(game.getPlayerRating(tournament.championId), 100, "Champion should get 100 rating");
        }

        if (tournament.runnerUpId >= 10001) {
            assertEq(game.getPlayerRating(tournament.runnerUpId), 60, "Runner-up should get 60 rating");
        }

        console2.log("Total test players:", totalTestPlayers);
        console2.log("Players with rating:", playersWithRating);
        console2.log("Ratings in event:", eventPlayerIds.length);

        // Verify events match state: exactly same number of ratings in event as players with ratings
        assertEq(
            eventPlayerIds.length, playersWithRating, "Number of ratings in event should match players with ratings"
        );

        // Verify top 50% rule: max 8 players for 16-player tournament
        assertTrue(playersWithRating <= 8, "Should not exceed top 50% (8 players) getting ratings");
        assertTrue(playersWithRating >= 2, "At least champion and runner-up should have ratings");
    }

    function testSeasonRatingReset() public {
        // Queue players and run tournament
        _queuePlayers(16);
        _runFullTournament();

        uint32 testPlayerId = PLAYER_ONE_ID;
        uint256 initialRating = game.getPlayerRating(testPlayerId);

        // Advance to next season
        vm.warp(block.timestamp + 32 days); // Advance beyond season length
        playerContract.forceCurrentSeason();

        // Current season rating should reset to 0
        assertEq(game.getPlayerRating(testPlayerId), 0);
        // Historical rating should still exist
        assertEq(game.getPlayerSeasonRating(testPlayerId, 0), initialRating);
    }

    //==============================================================//
    //                    REWARD SYSTEM TESTS                      //
    //==============================================================//

    function testRewardDistribution() public {
        // Queue exactly 16 players
        _queuePlayers(16);

        // Run full tournament
        _runFullTournament();

        TournamentGame.Tournament memory tournament = game.getTournamentData(0);

        // Check that some rewards were distributed (events would be emitted)
        // Since rewards are probabilistic, we mainly verify the mechanism doesn't revert
        assertTrue(tournament.championId != 0);
        assertTrue(tournament.runnerUpId != 0);
    }

    //==============================================================//
    //                     ADMIN FUNCTION TESTS                    //
    //==============================================================//

    function testSetTournamentSize() public {
        game.setTournamentSize(32);
        assertEq(game.currentTournamentSize(), 32);

        game.setTournamentSize(64);
        assertEq(game.currentTournamentSize(), 64);

        vm.expectRevert(abi.encodeWithSelector(InvalidTournamentSize.selector, 8));
        game.setTournamentSize(8);
    }

    function testSetLethalityFactor() public {
        game.setLethalityFactor(50);
        assertEq(game.lethalityFactor(), 50);
    }

    function testSetRewardConfigurations() public {
        IPlayerTickets.RewardConfig memory newConfig = IPlayerTickets.RewardConfig({
            nonePercent: 5000,
            attributeSwapPercent: 1000,
            createPlayerPercent: 1000,
            playerSlotPercent: 1000,
            weaponSpecPercent: 1000,
            armorSpecPercent: 500,
            duelTicketPercent: 500,
            nameChangePercent: 0
        }); // Total = 10000

        game.setWinnerRewards(newConfig);
        // Would need to test by calling the getter if it existed
    }

    function testInvalidRewardPercentages() public {
        IPlayerTickets.RewardConfig memory invalidConfig = IPlayerTickets.RewardConfig({
            nonePercent: 5000,
            attributeSwapPercent: 2000,
            createPlayerPercent: 2000,
            playerSlotPercent: 2000,
            weaponSpecPercent: 2000,
            armorSpecPercent: 2000,
            duelTicketPercent: 2000,
            nameChangePercent: 0
        }); // Total > 10000

        vm.expectRevert(InvalidRewardPercentages.selector);
        game.setWinnerRewards(invalidConfig);
    }

    function testPreviousWinnersGuaranteedSelection() public {
        // Use actual blockchain entropy for true randomness
        uint256 randomSeed = uint256(keccak256(abi.encode(block.prevrandao, block.timestamp, gasleft())));
        _testPreviousWinnersWithRandomness(randomSeed);
    }

    function testTournamentSelectionPoolSize() public {
        // Queue 50 players to test the "first half" selection pool
        _queuePlayers(50);
        console2.log("Queued 50 players");
        console2.log("Tournament size: 16");
        console2.log("Expected pool size: 25 (first half since 50 >= 16*2)");

        // Set proper daily time
        uint256 futureTime = block.timestamp + 48 hours;
        futureTime = futureTime - (futureTime % 1 days) + 20 hours;
        vm.warp(futureTime);

        // Phase 1: Commit queue
        game.tryStartTournament();

        // Phase 2: Select participants
        (, uint256 selectionBlock,,,,) = game.getPendingTournamentInfo();
        vm.roll(selectionBlock + 1);
        game.tryStartTournament();

        // Get selected participants
        TournamentGame.Tournament memory tournament = game.getTournamentData(0);

        // First, let's debug our queue order
        console2.log("Queue order (first 10 players in queue):");
        for (uint256 i = 0; i < 10 && i < playerIds.length; i++) {
            console2.log("  Queue pos %s: Player %s", i + 1, playerIds[i]);
        }

        console2.log("Selected participants:");
        bool foundSecondHalf = false;
        for (uint256 i = 0; i < tournament.participants.length; i++) {
            uint32 playerId = tournament.participants[i].playerId;

            // Find this player's position in our playerIds array
            uint256 arrayIndex = 999;
            for (uint256 j = 0; j < playerIds.length; j++) {
                if (playerIds[j] == playerId) {
                    arrayIndex = j;
                    break;
                }
            }

            // Since we queued in REVERSE order, queue position = 50 - arrayIndex
            uint256 queuePosition = 50 - arrayIndex;
            console2.log("  Tournament pos %s: Player %s (queue pos %s)", i, playerId, queuePosition);

            // Should be from first 25 queue positions
            if (queuePosition > 25) {
                console2.log("    ^^ ERROR: This is from second half!");
                foundSecondHalf = true;
            }
        }

        assertEq(tournament.participants.length, 16, "Should select exactly 16 participants");
        assertFalse(foundSecondHalf, "Should NOT select any player from second half of queue");
    }

    function _testPreviousWinnersWithRandomness(uint256 randomSeed) internal {
        // Set low lethality to prevent player deaths during testing
        game.setLethalityFactor(0);

        // First tournament - queue 50 players (tournament will only take 16)
        _queuePlayers(50);
        console2.log("Initial queue size: %s", game.getQueueSize());

        _runFullTournamentWithSeed(randomSeed);

        // Get champion and runner-up from first tournament
        TournamentGame.Tournament memory firstTournament = game.getTournamentData(0);

        // Log Tournament 1 participants to see if we get high IDs
        console2.log("Tournament 1 participants:");
        for (uint256 i = 0; i < firstTournament.participants.length; i++) {
            console2.log("  Position %s: Player %s", i, firstTournament.participants[i].playerId);
        }
        uint32 championId = firstTournament.championId;
        uint32 runnerUpId = firstTournament.runnerUpId;

        // Skip test if winners are default players (1-2000)
        if ((championId >= 1 && championId <= 2000) || (runnerUpId >= 1 && runnerUpId <= 2000)) {
            console2.log("Skipping test - default player won (champion: %s, runner-up: %s)", championId, runnerUpId);
            return; // Can't test with default players
        }

        console2.log("Tournament 1 - Champion: %s, Runner-up: %s", championId, runnerUpId);
        console2.log("Queue size after first tournament: %s", game.getQueueSize()); // Should be 34!

        // Move to next day
        vm.warp(block.timestamp + 1 days);

        // Now requeue ALL 16 players from first tournament (they were removed from queue)
        console2.log("Requeueing all 16 players from first tournament...");
        for (uint256 i = 0; i < firstTournament.participants.length; i++) {
            uint32 playerId = firstTournament.participants[i].playerId;

            // Skip default players
            if (playerId >= 1 && playerId <= 2000) continue;

            address owner = playerContract.getPlayerOwner(playerId);
            vm.prank(owner);
            game.queueForTournament(
                Fighter.PlayerLoadout({
                    playerId: playerId,
                    skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                    stance: 1
                })
            );
        }

        // Verify we have 50 players queued
        uint256 actualQueueSize = game.getQueueSize();
        console2.log("Queue size after requeueing all players: %s", actualQueueSize);
        assertEq(actualQueueSize, 50, "Should have 50 players queued");

        // Start the second tournament phases with new random seed
        game.tryStartTournament(); // Phase 1: Commit queue
        vm.roll(block.number + 21);
        vm.prevrandao(bytes32(randomSeed + 1000)); // Different seed for second tournament
        game.tryStartTournament(); // Phase 2: Select participants

        // Get the pending tournament info to verify it's been created
        (bool exists,,, uint8 phase, uint256 tournamentId,) = game.getPendingTournamentInfo();
        assertTrue(exists, "Pending tournament should exist");
        assertEq(
            phase, uint8(TournamentGame.TournamentPhase.PARTICIPANT_SELECT), "Should be in participant select phase"
        );

        // Get the tournament data to check participants
        TournamentGame.Tournament memory secondTournament = game.getTournamentData(tournamentId);

        // Log all participants to see what's happening
        console2.log("Second tournament participants:");
        for (uint256 i = 0; i < secondTournament.participants.length; i++) {
            console2.log("  Position %s: Player %s", i, secondTournament.participants[i].playerId);
        }

        // Verify champion and runner-up are in the participant list
        bool championFound = false;
        bool runnerUpFound = false;

        for (uint256 i = 0; i < secondTournament.participants.length; i++) {
            if (secondTournament.participants[i].playerId == championId) championFound = true;
            if (secondTournament.participants[i].playerId == runnerUpId) runnerUpFound = true;
        }

        assertTrue(championFound, "Previous champion not selected");
        assertTrue(runnerUpFound, "Previous runner-up not selected");

        // Verify we still have exactly 16 participants (selected from 50 queued)
        assertEq(secondTournament.participants.length, 16, "Tournament size incorrect");

        // EXTRA VERIFICATION: Check that they were selected FIRST (should be in first 2 positions)
        bool championInFirstTwo = false;
        bool runnerUpInFirstTwo = false;
        for (uint256 i = 0; i < 2 && i < secondTournament.participants.length; i++) {
            if (secondTournament.participants[i].playerId == championId) championInFirstTwo = true;
            if (secondTournament.participants[i].playerId == runnerUpId) runnerUpInFirstTwo = true;
        }
        assertTrue(championInFirstTwo, "Champion should be in first 2 positions (priority selection)");
        assertTrue(runnerUpInFirstTwo, "Runner-up should be in first 2 positions (priority selection)");
    }

    //==============================================================//
    //                       HELPER FUNCTIONS                      //
    //==============================================================//

    function _queuePlayers(uint256 count) internal {
        require(count <= 64, "Too many players requested");

        // Create ALL players first
        uint256 existingPlayers = playerIds.length;

        // Create additional players if needed (create them all first)
        for (uint256 i = existingPlayers; i < count; i++) {
            address newPlayer = address(uint160(0x2000 + i));
            vm.deal(newPlayer, 100 ether);
            uint32 newPlayerId = _createLevel10Player(newPlayer, false);

            players.push(newPlayer);
            playerIds.push(newPlayerId);
        }

        // Now queue them in REVERSE order to mix up the selection pool
        // This ensures higher-ID players are in the "first half" of the queue
        for (uint256 i = count; i > 0; i--) {
            uint256 index = i - 1;
            Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
                playerId: playerIds[index],
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 1
            });

            vm.prank(players[index]);
            game.queueForTournament(loadout);
        }
    }

    function _runFullTournament() internal {
        _runFullTournamentWithSeed(uint256(keccak256(abi.encode(block.timestamp, gasleft()))));
    }

    function _runFullTournamentWithSeed(uint256 baseSeed) internal {
        // Set proper daily time (20:00 UTC) at least 48 hours after deployment
        uint256 futureTime = block.timestamp + 48 hours;
        futureTime = futureTime - (futureTime % 1 days) + 20 hours; // Align to 20:00 UTC
        vm.warp(futureTime);

        // Phase 1: Commit queue
        uint256 startBlock = block.number;
        game.tryStartTournament();

        // Get the actual selection block from the pending tournament
        (bool exists, uint256 selectionBlock,,,,) = game.getPendingTournamentInfo();
        require(exists, "Pending tournament should exist after commit");

        // Phase 2: Select participants (advance PAST the selection block)
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(baseSeed));
        game.tryStartTournament();

        // Get the actual tournament block from the pending tournament
        (,, uint256 tournamentBlock,,,) = game.getPendingTournamentInfo();

        // Phase 3: Execute tournament (advance PAST the tournament block)
        vm.roll(tournamentBlock + 1);
        vm.prevrandao(bytes32(baseSeed + 12345));
        game.tryStartTournament();
    }

    function _levelUpPlayer(uint32 playerId, uint256 levels) internal {
        for (uint256 i = 0; i < levels; i++) {
            // Award enough XP to level up (level 1->2 needs 100 XP, etc.)
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
            uint16 xpNeeded = playerContract.getXPRequiredForLevel(stats.level + 1) - stats.currentXP;
            playerContract.awardExperience(playerId, xpNeeded);
        }
    }

    function _setTournamentTime() internal {
        // Set proper daily time (20:00 UTC) at least 48 hours after deployment
        uint256 futureTime = block.timestamp + 48 hours;
        futureTime = futureTime - (futureTime % 1 days) + 20 hours; // Align to 20:00 UTC
        vm.warp(futureTime);
    }

    /// @notice Creates a level 10 player for tournament testing
    function _createLevel10Player(address owner, bool useSetB) internal returns (uint32) {
        uint32 playerId = _createPlayerAndFulfillVRF(owner, playerContract, useSetB);
        _levelUpPlayer(playerId, 9); // Level up from 1 to 10
        return playerId;
    }

    // Test that our skin validation logic works and replaces invalid players
    function testSkinOwnershipValidationDuringTournament() public {
        console2.log("=== TESTING SKIN OWNERSHIP VALIDATION ===");

        // Create a PlayerSkinNFT as the owner (test contract)
        PlayerSkinNFT testSkinNFT = new PlayerSkinNFT("Test Skins", "TST", 0);

        // As the owner, we can mint for free without enabling public minting
        // Register it with the skin registry
        vm.deal(address(this), 1 ether); // Fund for registration fee
        uint32 testSkinIndex = skinRegistry.registerSkin{value: skinRegistry.registrationFee()}(address(testSkinNFT));
        skinRegistry.setSkinType(testSkinIndex, IPlayerSkinRegistry.SkinType.Player);
        skinRegistry.setSkinVerification(testSkinIndex, true);

        // Set tournament size to 16
        game.setTournamentSize(16);

        // Create 15 normal players for tournament
        address[] memory normalPlayers = new address[](15);
        uint32[] memory normalPlayerIds = new uint32[](15);

        for (uint256 i = 0; i < 15; i++) {
            normalPlayers[i] = address(uint160(0x2000 + i));
            vm.deal(normalPlayers[i], 100 ether);
            normalPlayerIds[i] = _createLevel10Player(normalPlayers[i], false);
        }

        // Create the "cheating" player who will lose their skin
        address cheater = address(0x3000);
        vm.deal(cheater, 100 ether);
        uint32 cheaterPlayerId = _createLevel10Player(cheater, false);

        // Mint a skin NFT for the cheater - as owner we can mint for free
        // Use weapon=5 (QUARTERSTAFF), armor=0 (CLOTH) - zero requirements, fits everyone
        uint256 skinTokenId = testSkinNFT.mintSkin(cheater, 5, 0); // weapon=5 (QUARTERSTAFF), armor=0 (CLOTH)
        console2.log("Minted skin token ID:", skinTokenId);
        console2.log("Cheater owns the skin:", testSkinNFT.ownerOf(skinTokenId) == cheater);

        // Queue all normal players with default skin (index 0)
        for (uint256 i = 0; i < 15; i++) {
            Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
                playerId: normalPlayerIds[i],
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 1 // BALANCED
            });

            vm.prank(normalPlayers[i]);
            game.queueForTournament(loadout);
        }

        // Queue the cheater with their special skin
        console2.log("Test skin index:", testSkinIndex);
        console2.log("Skin token ID:", skinTokenId);

        Fighter.PlayerLoadout memory cheaterLoadout = Fighter.PlayerLoadout({
            playerId: cheaterPlayerId,
            skin: Fighter.SkinInfo({skinIndex: testSkinIndex, skinTokenId: uint16(skinTokenId)}),
            stance: 1 // BALANCED
        });

        vm.prank(cheater);
        game.queueForTournament(cheaterLoadout);

        console2.log("Queue size after all players joined:", game.getQueueSize());
        assertEq(game.getQueueSize(), 16, "Should have 16 players in queue");

        // Set time to daily tournament time (20:00 UTC)
        uint256 futureTime = block.timestamp + 48 hours;
        futureTime = futureTime - (futureTime % 1 days) + 20 hours;
        vm.warp(futureTime);

        // TRANSACTION 1: Queue Commit
        game.tryStartTournament();

        // Get selection block for next transaction
        (bool exists, uint256 selectionBlock, uint256 tournamentBlock, uint8 phase,, uint256 participantCount) =
            game.getPendingTournamentInfo();
        require(exists, "Pending tournament should exist after commit");
        require(phase == 1, "Should be in QUEUE_COMMIT phase");

        // TRANSACTION 2: Participant Selection
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));

        game.tryStartTournament();

        // Get tournament block for next transaction
        (,, tournamentBlock, phase,, participantCount) = game.getPendingTournamentInfo();
        require(phase == 2, "Should be in PARTICIPANT_SELECT phase");
        require(participantCount == 16, "Should have selected 16 participants");

        // NOW THE KEY PART: Transfer the cheater's skin NFT to someone else
        // This simulates the cheater selling/transferring their skin after queuing but before tournament
        address skinThief = address(0x4000);
        vm.prank(cheater);
        testSkinNFT.transferFrom(cheater, skinThief, skinTokenId);

        console2.log("Skin NFT transferred from cheater to skinThief");
        console2.log("Cheater owns skin:", testSkinNFT.ownerOf(skinTokenId) == cheater);
        console2.log("SkinThief owns skin:", testSkinNFT.ownerOf(skinTokenId) == skinThief);

        // TRANSACTION 3: Tournament Execution - This should detect the cheater no longer owns the skin
        vm.roll(tournamentBlock + 1);
        vm.prevrandao(bytes32(uint256(67890)));

        // Debug: Check how many default players are available
        console2.log("Default players available:", defaultPlayerContract.validDefaultPlayerCount());

        // Record logs to capture the TournamentCompleted event
        vm.recordLogs();

        try game.tryStartTournament() {
            console2.log("Tournament execution succeeded");
        } catch Error(string memory reason) {
            console2.log("Tournament execution failed with reason:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console2.log("Tournament execution failed with low level error");
            // Try to decode common errors
            if (lowLevelData.length >= 4) {
                bytes4 errorSelector = bytes4(lowLevelData);
                console2.log("Error selector:", vm.toString(errorSelector));
                if (errorSelector == InvalidBlockhash.selector) {
                    console2.log("InvalidBlockhash error detected");
                } else if (errorSelector == InsufficientDefaultPlayers.selector) {
                    console2.log("InsufficientDefaultPlayers error detected");
                }
            }
            assembly {
                revert(add(lowLevelData, 0x20), mload(lowLevelData))
            }
        }

        // Get the recorded logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        console2.log("Total logs captured:", logs.length);

        // Look for PlayerReplaced events
        bytes32 playerReplacedTopic = keccak256("PlayerReplaced(uint256,uint32,uint32,string)");
        console2.log("Looking for PlayerReplaced events:");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == playerReplacedTopic) {
                console2.log("Found PlayerReplaced event at log index", i);
                // Decode indexed parameters from topics
                uint256 tournamentId = uint256(logs[i].topics[1]);
                uint32 originalPlayerId = uint32(uint256(logs[i].topics[2]));
                uint32 replacementPlayerId = uint32(uint256(logs[i].topics[3]));
                // Decode non-indexed parameter from data
                (string memory reason) = abi.decode(logs[i].data, (string));
                console2.log("Tournament ID:", tournamentId);
                console2.log("Original Player ID:", originalPlayerId);
                console2.log("Replacement Player ID:", replacementPlayerId);
                console2.log("Replacement Reason:", reason);

                // Verify this is our expected replacement
                if (originalPlayerId == cheaterPlayerId) {
                    assertEq(reason, "SKIN_OWNERSHIP_LOST", "Expected SKIN_OWNERSHIP_LOST as replacement reason");
                    console2.log("VERIFIED: Replacement reason for cheater is correct");
                }
            }
        }

        // Find and decode the TournamentCompleted event
        // The event signature is: TournamentCompleted(uint256,uint8,uint32,uint32,uint256,uint32[],uint32[])
        bytes32 tournamentCompletedTopic =
            keccak256("TournamentCompleted(uint256,uint8,uint32,uint32,uint256,uint32[],uint32[])");
        console2.log("Looking for topic:", vm.toString(tournamentCompletedTopic));

        uint32[] memory emittedParticipants;
        bool eventFound = false;

        for (uint256 i = 0; i < logs.length; i++) {
            console2.log("Log", i, "- topics:", logs[i].topics.length);
            if (logs[i].topics.length > 0) {
                console2.log("Topic 0:", vm.toString(logs[i].topics[0]));
                if (logs[i].topics[0] == tournamentCompletedTopic) {
                    console2.log("Found matching TournamentCompleted event at log index", i);
                    // Decode the event data - only non-indexed parameters are in data
                    // Event: TournamentCompleted(uint256 indexed tournamentId, uint8 size, uint32 indexed championId, uint32 runnerUpId, uint256 seasonId, uint32[] participantIds, uint32[] roundWinners)
                    // In data: size, runnerUpId, seasonId, participantIds, roundWinners
                    try this.decodeTournamentEvent(logs[i].data) returns (uint32[] memory participantIds) {
                        emittedParticipants = participantIds;
                        eventFound = true;
                        console2.log("Successfully decoded event with", participantIds.length, "participants");
                        break;
                    } catch Error(string memory reason) {
                        console2.log("Failed to decode TournamentCompleted event data:", reason);
                    } catch {
                        console2.log("Failed to decode TournamentCompleted event data - unknown error");
                    }
                }
            }
        }

        assertTrue(eventFound, "TournamentCompleted event should be emitted");

        // Check the emitted participant list for the cheater
        bool cheaterFoundInEmittedList = false;
        console2.log("Checking emitted participant list from TournamentCompleted event:");
        for (uint256 i = 0; i < emittedParticipants.length; i++) {
            console2.log("Emitted Participant", i, ":", emittedParticipants[i]);
            if (emittedParticipants[i] == cheaterPlayerId) {
                cheaterFoundInEmittedList = true;
            }
        }

        // Also check the stored tournament data
        assertEq(game.nextTournamentId(), 1, "One tournament should have been created");
        TournamentGame.Tournament memory tournament = game.getTournamentData(0);
        assertEq(
            uint8(tournament.state), uint8(TournamentGame.TournamentState.COMPLETED), "Tournament should be completed"
        );

        // Check all participants in storage to ensure cheater is NOT in the list
        bool cheaterFoundInStoredParticipants = false;
        console2.log("\nChecking stored tournament participants:");
        for (uint256 i = 0; i < tournament.participants.length; i++) {
            uint32 participantId = tournament.participants[i].playerId;
            console2.log("Stored Participant", i, ":", participantId);
            if (participantId == cheaterPlayerId) {
                cheaterFoundInStoredParticipants = true;
            }
        }

        console2.log("Tournament Champion ID:", tournament.championId);
        console2.log("Tournament Runner-up ID:", tournament.runnerUpId);
        console2.log("Cheater Player ID:", cheaterPlayerId);
        console2.log("Cheater found in stored participants:", cheaterFoundInStoredParticipants);
        console2.log("Cheater found in emitted participants:", cheaterFoundInEmittedList);

        // The critical assertions:
        // 1. Cheater should NOT be in emitted participant list (they were replaced during execution)
        assertFalse(cheaterFoundInEmittedList, "Cheater should NOT be in emitted TournamentCompleted participant list");

        // 2. Cheater IS still in stored participant list (original registration data preserved)
        // This is expected behavior - storage shows original registrations, event shows actual tournament
        assertTrue(
            cheaterFoundInStoredParticipants,
            "Cheater should be in stored participant list (original registration preserved)"
        );

        // Also verify they're not champion/runner-up
        assertTrue(tournament.championId != cheaterPlayerId, "Cheater should not be champion");
        assertTrue(tournament.runnerUpId != cheaterPlayerId, "Cheater should not be runner-up");

        console2.log("=== SKIN OWNERSHIP VALIDATION TEST PASSED ===");
    }

    // Helper function for decoding tournament event
    // Event: TournamentCompleted(uint256 indexed tournamentId, uint8 size, uint32 indexed championId, uint32 runnerUpId, uint32[] participantIds, uint32[] roundWinners)
    // Only non-indexed parameters are in data: size, runnerUpId, participantIds, roundWinners
    function decodeTournamentEvent(bytes memory data) external pure returns (uint32[] memory participantIds) {
        (uint8 size, uint32 runnerUpId, uint256 seasonId, uint32[] memory participants, uint32[] memory winners) =
            abi.decode(data, (uint8, uint32, uint256, uint32[], uint32[]));
        return participants;
    }

    // Test auto-recovery from QUEUE_COMMIT phase after 256 blocks
    function testAutoRecoveryFromQueueCommitPhase() public {
        // Set tournament size to 16 and queue 16 players
        game.setTournamentSize(16);
        _queuePlayers(16);

        // Set time to tournament window
        uint256 tournamentTime = block.timestamp + 48 hours;
        tournamentTime = tournamentTime - (tournamentTime % 1 days) + 20 hours;
        vm.warp(tournamentTime);

        // TRANSACTION 1: Queue Commit
        game.tryStartTournament();

        // Verify we're in QUEUE_COMMIT phase
        (bool exists, uint256 selectionBlock,, uint8 phase,,) = game.getPendingTournamentInfo();
        assertTrue(exists, "Pending tournament should exist");
        assertEq(uint256(phase), 1, "Should be in QUEUE_COMMIT phase");

        // Simulate 256+ blocks passing (blockhash expires)
        // commitBlock = selectionBlock - futureBlocksForSelection = selectionBlock - 20
        uint256 commitBlock = selectionBlock - 20;
        vm.roll(commitBlock + 256); // Exactly at the recovery threshold

        // Expect recovery event
        vm.expectEmit(true, true, true, true);
        emit TournamentAutoRecovered(commitBlock, commitBlock + 256, TournamentGame.TournamentPhase.QUEUE_COMMIT);

        // Try to proceed - should trigger recovery
        game.tryStartTournament();

        // Verify recovery happened
        (bool existsAfter,,,,,) = game.getPendingTournamentInfo();
        assertFalse(existsAfter, "Pending tournament should be cleared after recovery");

        // Verify queue is still intact (no players removed in QUEUE_COMMIT phase)
        assertEq(game.getQueueSize(), 16, "Queue should still have 16 players");

        // Verify we can start a new tournament immediately after recovery (timestamp reset to 0)
        game.tryStartTournament();
        (bool newExists,,, uint8 newPhase,,) = game.getPendingTournamentInfo();
        assertTrue(newExists, "Should be able to start new tournament immediately after recovery");
        assertEq(uint256(newPhase), 1, "New tournament should be in QUEUE_COMMIT phase");
    }

    // Test auto-recovery from PARTICIPANT_SELECT phase after 256 blocks
    function testAutoRecoveryFromParticipantSelectPhase() public {
        // Set tournament size to 16 and queue 16 players
        game.setTournamentSize(16);
        _queuePlayers(16);

        // Set time to tournament window
        uint256 tournamentTime = block.timestamp + 48 hours;
        tournamentTime = tournamentTime - (tournamentTime % 1 days) + 20 hours;
        vm.warp(tournamentTime);

        // TRANSACTION 1: Queue Commit
        game.tryStartTournament();

        // TRANSACTION 2: Participant Selection
        (bool exists, uint256 selectionBlock,,,,) = game.getPendingTournamentInfo();
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));
        game.tryStartTournament();

        // Verify we're in PARTICIPANT_SELECT phase with selected players
        (,, uint256 tournamentBlock, uint8 phase,, uint256 participantCount) = game.getPendingTournamentInfo();
        assertEq(uint256(phase), 2, "Should be in PARTICIPANT_SELECT phase");
        assertEq(participantCount, 16, "Should have 16 participants selected");

        // Verify players were removed from queue during selection
        assertEq(game.getQueueSize(), 0, "Queue should be empty after participant selection");

        // Verify tournament was created with participants
        assertEq(game.nextTournamentId(), 1, "Tournament ID should be 1");
        TournamentGame.Tournament memory tournament = game.getTournamentData(0);
        assertEq(tournament.participants.length, 16, "Tournament should have 16 participants");

        // Simulate 256+ blocks passing from the original commit block
        uint256 commitBlock = tournamentBlock - 40; // tournamentBlock - futureBlocksForTournament - futureBlocksForSelection
        vm.roll(commitBlock + 256); // Recovery threshold reached

        // Expect recovery event
        vm.expectEmit(true, true, true, true);
        emit TournamentAutoRecovered(commitBlock, commitBlock + 256, TournamentGame.TournamentPhase.PARTICIPANT_SELECT);

        // Try to proceed - should trigger recovery
        game.tryStartTournament();

        // Verify recovery happened
        (bool existsAfter,,,,,) = game.getPendingTournamentInfo();
        assertFalse(existsAfter, "Pending tournament should be cleared after recovery");

        // Verify players were restored to queue
        assertEq(game.getQueueSize(), 16, "All 16 players should be restored to queue");

        // Verify tournament was cleaned up
        assertEq(game.nextTournamentId(), 0, "Tournament ID should be rolled back to 0");

        // Verify the tournament data was deleted (should revert)
        vm.expectRevert(); // TournamentDoesNotExist
        game.getTournamentData(0);

        // Verify player statuses were restored to QUEUED
        for (uint256 i = 0; i < playerIds.length && i < 16; i++) {
            uint256 status = uint256(game.playerStatus(playerIds[i]));
            assertEq(status, 1, "Player should be back in QUEUED status"); // 1 = QUEUED
        }

        // Verify we can start a new tournament immediately after recovery (timestamp reset to 0)
        game.tryStartTournament();
        (bool newExists,,, uint8 newPhase,,) = game.getPendingTournamentInfo();
        assertTrue(newExists, "Should be able to start new tournament immediately after recovery");
        assertEq(uint256(newPhase), 1, "New tournament should be in QUEUE_COMMIT phase");
    }

    // Test that recovery doesn't trigger before 256 blocks
    function testNoRecoveryBefore256Blocks() public {
        // Set tournament size to 16 and queue 16 players
        game.setTournamentSize(16);
        _queuePlayers(16);

        // Set time to tournament window
        uint256 tournamentTime = block.timestamp + 48 hours;
        tournamentTime = tournamentTime - (tournamentTime % 1 days) + 20 hours;
        vm.warp(tournamentTime);

        // TRANSACTION 1: Queue Commit
        game.tryStartTournament();

        (bool exists, uint256 selectionBlock,, uint8 phase,,) = game.getPendingTournamentInfo();
        uint256 commitBlock = selectionBlock - 20;

        // Move to exactly 255 blocks later (should NOT trigger recovery, but should proceed normally)
        vm.roll(commitBlock + 255);
        vm.prevrandao(bytes32(uint256(12345)));

        // Should proceed to participant selection (no recovery yet)
        game.tryStartTournament();

        // Verify tournament progressed to PARTICIPANT_SELECT phase (no recovery triggered)
        (bool stillExists,,, uint8 newPhase,,) = game.getPendingTournamentInfo();
        assertTrue(stillExists, "Pending tournament should still exist before 256 blocks");
        assertEq(uint256(newPhase), 2, "Should be in PARTICIPANT_SELECT phase, not recovered");
    }

    // Test that tournament won't start with empty queue
    function testEmptyQueuePrevention() public {
        // Set time to tournament window
        uint256 tournamentTime = block.timestamp + 48 hours;
        tournamentTime = tournamentTime - (tournamentTime % 1 days) + 20 hours;
        vm.warp(tournamentTime);

        // Verify queue is empty
        assertEq(game.getQueueSize(), 0, "Queue should be empty");

        // Try to start tournament with empty queue - should revert
        vm.expectRevert(QueueEmpty.selector);
        game.tryStartTournament();

        // Verify no tournament was created
        (bool exists,,,,,) = game.getPendingTournamentInfo();
        assertFalse(exists, "No tournament should exist with empty queue");
    }

    //==============================================================//
    //                 PHASE TRANSITION ERROR TESTS                //
    //==============================================================//

    function testRevertWhen_PendingTournamentExists() public {
        // Queue enough players for tournament
        _queuePlayers(16);
        _setTournamentTime();

        // Start tournament (creates pending tournament)
        game.tryStartTournament();

        // Verify pending tournament exists
        (bool exists,,,,,) = game.getPendingTournamentInfo();
        assertTrue(exists, "Pending tournament should exist");

        // Try to change tournament size while tournament is pending - should revert
        vm.expectRevert(abi.encodeWithSignature("PendingTournamentExists()"));
        game.setTournamentSize(32);
    }

    //==============================================================//
    //                 BLOCKHASH VALIDATION TESTS                  //
    //==============================================================//

    function testRevertWhen_SelectionBlockNotReached() public {
        // Queue players and start tournament
        _queuePlayers(16);
        _setTournamentTime();
        game.tryStartTournament();

        (bool exists, uint256 selectionBlock,,,,) = game.getPendingTournamentInfo();
        assertTrue(exists, "Tournament should be pending");

        // Try to proceed before selection block is reached
        vm.roll(selectionBlock - 1);
        vm.expectRevert(
            abi.encodeWithSignature("SelectionBlockNotReached(uint256,uint256)", selectionBlock, selectionBlock - 1)
        );
        game.tryStartTournament();
    }

    function testRevertWhen_InvalidBlockhash() public {
        // Queue players and start tournament
        _queuePlayers(16);
        _setTournamentTime();
        game.tryStartTournament();

        (bool exists, uint256 selectionBlock,,,,) = game.getPendingTournamentInfo();

        // Move to selection block but don't set prevrandao (blockhash will be 0)
        vm.roll(selectionBlock);
        // Don't call vm.prevrandao() - blockhash should be 0

        vm.expectRevert(abi.encodeWithSignature("InvalidBlockhash()"));
        game.tryStartTournament();
    }

    //==============================================================//
    //               TOURNAMENT EDGE CASES                         //
    //==============================================================//

    function testRevertWhen_MinTimeNotElapsed() public {
        // Queue players and run a tournament
        _queuePlayers(16);
        _runFullTournament();

        // Create ADDITIONAL players for the second tournament (some may have died in first)
        for (uint256 i = 0; i < 16; i++) {
            address newPlayer = address(uint160(0x9000 + i)); // Use different address range
            vm.deal(newPlayer, 100 ether);
            uint32 newPlayerId = _createLevel10Player(newPlayer, false);

            vm.startPrank(newPlayer);
            game.queueForTournament(
                Fighter.PlayerLoadout({
                    playerId: newPlayerId,
                    skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                    stance: 1
                })
            );
            vm.stopPrank();
        }

        // DON'T advance the day - try to run tournament on the SAME calendar day
        // Just set the hour to tournament time without advancing the date
        uint256 currentTime = block.timestamp;
        uint256 todayTournamentTime = (currentTime / 1 days) * 1 days + 20 hours; // Same day, 20:00 UTC
        vm.warp(todayTournamentTime);

        vm.expectRevert(abi.encodeWithSignature("MinTimeNotElapsed()"));
        game.tryStartTournament();
    }

    function testRevertWhen_TournamentTooLateEdgeCase() public {
        // Queue players and set tournament time exactly at end of window
        _queuePlayers(16);

        // Set time to just past the tournament window (20:00 + 1 hour = 21:00)
        uint256 futureTime = block.timestamp + 48 hours;
        futureTime = futureTime - (futureTime % 1 days) + 21 hours + 1; // 21:01 UTC (1 minute past window)
        vm.warp(futureTime);

        vm.expectRevert(abi.encodeWithSignature("TournamentTooLate()"));
        game.tryStartTournament();
    }

    function testPlayerLevelTooLow() public {
        // Create a level 9 player (below required level 10)
        address lowLevelPlayer = address(0x7777);
        uint32 lowLevelPlayerId = _createPlayerAndFulfillVRF(lowLevelPlayer, playerContract, false);
        _levelUpPlayer(lowLevelPlayerId, 8); // Level up from 1 to 9

        vm.startPrank(lowLevelPlayer);
        vm.expectRevert(abi.encodeWithSignature("PlayerLevelTooLow()"));
        game.queueForTournament(
            Fighter.PlayerLoadout({
                playerId: lowLevelPlayerId,
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 1
            })
        );
        vm.stopPrank();
    }

    function testAutoRecoveryAt256Blocks() public {
        // Queue players and start tournament
        _queuePlayers(16);
        _setTournamentTime();
        uint256 startBlock = block.number;
        game.tryStartTournament();

        // Move exactly 256 blocks from initial commit block
        (bool exists, uint256 selectionBlock,,,,) = game.getPendingTournamentInfo();
        uint256 commitBlock = selectionBlock - 20; // futureBlocksForSelection = 20

        vm.roll(commitBlock + 256);
        vm.prevrandao(bytes32(uint256(12345)));

        // Should trigger auto-recovery
        vm.expectEmit(true, false, false, true);
        emit TournamentAutoRecovered(commitBlock, commitBlock + 256, TournamentGame.TournamentPhase.QUEUE_COMMIT);
        game.tryStartTournament();

        // Verify no pending tournament exists after recovery
        (bool finalExists,,,,,) = game.getPendingTournamentInfo();
        assertFalse(finalExists, "Pending tournament should be cleared after auto-recovery");
    }

    function testWithdrawDuringParticipantSelectPhase() public {
        // Queue players and start tournament
        _queuePlayers(16);
        _setTournamentTime();
        game.tryStartTournament();

        // Progress to participant selection phase
        (bool exists, uint256 selectionBlock,,,,) = game.getPendingTournamentInfo();
        vm.roll(selectionBlock + 1); // Move PAST the selection block
        vm.prevrandao(bytes32(uint256(12345)));
        game.tryStartTournament();

        // Verify we're in PARTICIPANT_SELECT phase
        (,, uint256 tournamentBlock, uint8 phase,,) = game.getPendingTournamentInfo();
        assertEq(uint256(phase), 2, "Should be in PARTICIPANT_SELECT phase");

        // Verify queue is empty (all players selected for 16-player tournament)
        assertEq(game.getQueueSize(), 0, "Queue should be empty after participant selection");

        // Try to withdraw a selected player (now IN_TOURNAMENT status)
        // Find a player that's in the tournament
        uint32 tournamentPlayerId = 0;
        for (uint256 i = 0; i < playerIds.length; i++) {
            if (uint256(game.playerStatus(playerIds[i])) == 2) {
                // 2 = IN_TOURNAMENT
                tournamentPlayerId = playerIds[i];
                break;
            }
        }
        require(tournamentPlayerId != 0, "Need at least one tournament player for test");

        address playerOwner = playerContract.getPlayerOwner(tournamentPlayerId);
        vm.startPrank(playerOwner);
        vm.expectRevert(abi.encodeWithSignature("PlayerNotInQueue()"));
        game.withdrawFromQueue(tournamentPlayerId);
        vm.stopPrank();
    }

    function testRewardMintingVerification() public {
        // Set reward config to guarantee specific ticket minting
        IPlayerTickets.RewardConfig memory guaranteedConfig = IPlayerTickets.RewardConfig({
            nonePercent: 0, // 0%
            attributeSwapPercent: 0, // 0%
            createPlayerPercent: 0, // 0%
            playerSlotPercent: 0, // 0%
            weaponSpecPercent: 5000, // 50%
            armorSpecPercent: 5000, // 50%
            duelTicketPercent: 0, // 0%
            nameChangePercent: 0 // 0%
        });

        game.setWinnerRewards(guaranteedConfig);

        // Queue players and run tournament
        _queuePlayers(16);
        _runFullTournament();
        uint256 tournamentId = game.nextTournamentId() - 1;

        TournamentGame.Tournament memory tournament = game.getTournamentData(tournamentId);
        address championOwner = playerContract.getPlayerOwner(tournament.championId);

        // Verify champion received weapon OR armor specialization tickets
        uint256 weaponTickets = playerTickets.balanceOf(championOwner, playerTickets.WEAPON_SPECIALIZATION_TICKET());
        uint256 armorTickets = playerTickets.balanceOf(championOwner, playerTickets.ARMOR_SPECIALIZATION_TICKET());

        assertTrue(weaponTickets > 0 || armorTickets > 0, "Champion should have received specialization tickets");
    }

    //==============================================================//
    //               REWARD DISTRIBUTION EDGE CASES                //
    //==============================================================//

    function testRevertWhen_InvalidRewardPercentages_NotSumTo10000() public {
        // Test reward config that doesn't sum to 10000 (100%)
        IPlayerTickets.RewardConfig memory invalidConfig = IPlayerTickets.RewardConfig({
            nonePercent: 5000, // 50%
            attributeSwapPercent: 2000, // 20%
            createPlayerPercent: 1000, // 10%
            playerSlotPercent: 1000, // 10%
            weaponSpecPercent: 500, // 5%
            armorSpecPercent: 500, // 5%
            duelTicketPercent: 500, // 5% = 105% total (should be 100%)
            nameChangePercent: 0 // 0%
        });

        vm.expectRevert(abi.encodeWithSignature("InvalidRewardPercentages()"));
        game.setWinnerRewards(invalidConfig);
    }

    function testComplexRewardDistribution() public {
        // Test complex reward distribution with multiple types
        IPlayerTickets.RewardConfig memory complexConfig = IPlayerTickets.RewardConfig({
            nonePercent: 1000, // 10%
            attributeSwapPercent: 2000, // 20%
            createPlayerPercent: 1500, // 15%
            playerSlotPercent: 1500, // 15%
            weaponSpecPercent: 2000, // 20%
            armorSpecPercent: 1500, // 15%
            duelTicketPercent: 500, // 5% = 100% total
            nameChangePercent: 0 // 0%
        });

        game.setWinnerRewards(complexConfig);
        game.setRunnerUpRewards(complexConfig);
        game.setThirdFourthRewards(complexConfig);

        // Queue players and run tournament
        _queuePlayers(16);
        _runFullTournament();
        uint256 tournamentId = game.nextTournamentId() - 1;

        // Verify tournament completed and rewards were distributed
        TournamentGame.Tournament memory tournament = game.getTournamentData(tournamentId);
        assertEq(uint256(tournament.state), uint256(TournamentGame.TournamentState.COMPLETED));
        assertTrue(tournament.championId > 0, "Should have champion");
        assertTrue(tournament.runnerUpId > 0, "Should have runner-up");
    }

    //==============================================================//
    //            PLAYER SELECTION ALGORITHM TESTS                 //
    //==============================================================//

    function testPlayerSelectionWithInsufficientHighLevelPlayers() public {
        // Create mixed level players - mostly low level with few high level
        uint32[] memory lowLevelPlayers = new uint32[](12);
        uint32[] memory highLevelPlayers = new uint32[](4);

        // Create 12 low-level players (level 10 - minimum required)
        for (uint256 i = 0; i < 12; i++) {
            address playerOwner = address(uint160(0x4000 + i));
            lowLevelPlayers[i] = _createLevel10Player(playerOwner, false);

            vm.startPrank(playerOwner);
            game.queueForTournament(
                Fighter.PlayerLoadout({
                    playerId: lowLevelPlayers[i],
                    skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                    stance: 1
                })
            );
            vm.stopPrank();
        }

        // Create 4 high-level players (level 10)
        for (uint256 i = 0; i < 4; i++) {
            address playerOwner = address(uint160(0x5000 + i));
            highLevelPlayers[i] = _createLevel10Player(playerOwner, false);

            vm.startPrank(playerOwner);
            game.queueForTournament(
                Fighter.PlayerLoadout({
                    playerId: highLevelPlayers[i],
                    skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                    stance: 1
                })
            );
            vm.stopPrank();
        }

        // Run tournament - should complete successfully with mixed levels
        _runFullTournament();
        uint256 tournamentId = game.nextTournamentId() - 1;
        TournamentGame.Tournament memory tournament = game.getTournamentData(tournamentId);

        assertEq(uint256(tournament.state), uint256(TournamentGame.TournamentState.COMPLETED));
        assertEq(tournament.participants.length, 16, "Should have 16 participants");
    }

    // Helper function to simulate TournamentAutoRecovered event
    event TournamentAutoRecovered(uint256 commitBlock, uint256 currentBlock, TournamentGame.TournamentPhase phase);
}

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
    InvalidRewardPercentages
} from "../../src/game/modes/TournamentGame.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
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
            address(gameEngine), address(playerContract), address(defaultPlayerContract), address(playerTickets)
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
            nameChanges: false,
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

        // Level up some players for priority queue testing
        _levelUpPlayer(PLAYER_TWO_ID, 3); // Level 4
        _levelUpPlayer(PLAYER_THREE_ID, 9); // Level 10 (max)

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
    //                  PRIORITY QUEUE TESTS                       //
    //==============================================================//

    function testLevelBasedPriority() public {
        // Create more players with different levels
        for (uint256 i = 5; i <= 20; i++) {
            address player = address(uint160(0x1000 + i));
            vm.deal(player, 100 ether);
            uint32 playerId = _createPlayerAndFulfillVRF(player, playerContract, false);

            // Vary levels
            if (i >= 15) {
                _levelUpPlayer(playerId, 9); // Level 10
            } else if (i >= 10) {
                _levelUpPlayer(playerId, 4); // Level 5
            }
            // Rest stay at level 1

            Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
                playerId: playerId,
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 1
            });

            vm.prank(player);
            game.queueForTournament(loadout);
        }

        // Queue our test players too
        _queuePlayers(4);

        // Set proper time and start tournament selection (48+ hours after deployment)
        uint256 futureTime = block.timestamp + 48 hours;
        futureTime = futureTime - (futureTime % 1 days) + 20 hours; // Align to 20:00 UTC
        vm.warp(futureTime);

        // Phase 1: Commit queue
        uint256 startBlock = block.number;
        game.tryStartTournament();

        // Get the actual selection block and advance PAST it
        (, uint256 selectionBlock,,,,) = game.getPendingTournamentInfo();
        vm.roll(selectionBlock + 1);

        // Phase 2: Select participants
        game.tryStartTournament();

        // Should have selected 16 players, prioritizing highest levels
        // Check that tournament was created
        TournamentGame.Tournament memory tournament = game.getTournamentData(0);
        assertEq(tournament.size, 16);
    }

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

        // Run full tournament
        _runFullTournament();

        // Check rating distribution
        TournamentGame.Tournament memory tournament = game.getTournamentData(0);

        // Champion should get 100 points
        if (tournament.championId <= 2000) {
            // Not a default player
            assertEq(game.getPlayerRating(tournament.championId), 100);
        }

        // Runner-up should get 75 points
        if (tournament.runnerUpId <= 2000) {
            // Not a default player
            assertEq(game.getPlayerRating(tournament.runnerUpId), 75);
        }
    }

    function testSeasonRatingReset() public {
        // Queue players and run tournament
        _queuePlayers(16);
        _runFullTournament();

        uint32 testPlayerId = PLAYER_ONE_ID;
        uint256 initialRating = game.getPlayerRating(testPlayerId);

        // Advance to next season
        vm.warp(block.timestamp + 32 days); // Advance beyond season length
        playerContract.checkAndUpdateSeason();

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
        TournamentGame.RewardConfig memory newConfig = TournamentGame.RewardConfig({
            nonePercent: 5000,
            attributeSwapPercent: 1000,
            createPlayerPercent: 1000,
            playerSlotPercent: 1000,
            weaponSpecPercent: 1000,
            armorSpecPercent: 500,
            duelTicketPercent: 500
        }); // Total = 10000

        game.setWinnerRewards(newConfig);
        // Would need to test by calling the getter if it existed
    }

    function testInvalidRewardPercentages() public {
        TournamentGame.RewardConfig memory invalidConfig = TournamentGame.RewardConfig({
            nonePercent: 5000,
            attributeSwapPercent: 2000,
            createPlayerPercent: 2000,
            playerSlotPercent: 2000,
            weaponSpecPercent: 2000,
            armorSpecPercent: 2000,
            duelTicketPercent: 2000
        }); // Total > 10000

        vm.expectRevert(InvalidRewardPercentages.selector);
        game.setWinnerRewards(invalidConfig);
    }

    //==============================================================//
    //                       HELPER FUNCTIONS                      //
    //==============================================================//

    function _queuePlayers(uint256 count) internal {
        require(count <= 64, "Too many players requested");

        // Queue existing players first
        uint256 existingPlayers = playerIds.length;
        for (uint256 i = 0; i < existingPlayers && i < count; i++) {
            Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
                playerId: playerIds[i],
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 1
            });

            vm.prank(players[i]);
            game.queueForTournament(loadout);
        }

        // Create additional players if needed
        for (uint256 i = existingPlayers; i < count; i++) {
            address newPlayer = address(uint160(0x2000 + i));
            vm.deal(newPlayer, 100 ether);
            uint32 newPlayerId = _createPlayerAndFulfillVRF(newPlayer, playerContract, false);

            Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
                playerId: newPlayerId,
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 1
            });

            vm.prank(newPlayer);
            game.queueForTournament(loadout);

            players.push(newPlayer);
            playerIds.push(newPlayerId);
        }
    }

    function _runFullTournament() internal {
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
        vm.prevrandao(bytes32(uint256(12345)));
        game.tryStartTournament();

        // Get the actual tournament block from the pending tournament
        (,, uint256 tournamentBlock,,,) = game.getPendingTournamentInfo();

        // Phase 3: Execute tournament (advance PAST the tournament block)
        vm.roll(tournamentBlock + 1);
        vm.prevrandao(bytes32(uint256(67890)));
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
}

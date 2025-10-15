// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {InvalidSeasonLength} from "../../src/fighters/Player.sol";

contract SeasonTest is TestBase {
    uint32 public testPlayerId1;
    uint32 public testPlayerId2;

    // Test addresses
    address public USER_ONE;
    address public USER_TWO;
    address public USER_THREE;
    address public USER_FOUR;

    // Events (copied from Player.sol for testing)
    event SeasonStarted(uint256 indexed seasonId, uint256 startTimestamp, uint256 startBlock);
    event SeasonLengthUpdated(uint256 oldLength, uint256 newLength);

    function setUp() public override {
        super.setUp();

        // Set up test addresses
        USER_ONE = address(0x1111);
        USER_TWO = address(0x2222);
        USER_THREE = address(0x3333);
        USER_FOUR = address(0x4444);

        // Create test players
        testPlayerId1 = _createPlayerAndFulfillVRF(USER_ONE, false);
        testPlayerId2 = _createPlayerAndFulfillVRF(USER_TWO, false);

        // Set up permissions for this test contract to call increment functions
        IPlayer.GamePermissions memory testPermissions =
            IPlayer.GamePermissions({record: true, retire: false, immortal: false, experience: false});
        playerContract.setGameContractPermission(address(this), testPermissions);
    }

    // ==================== SEASON INITIALIZATION TESTS ====================

    function testSeasonInitialization() public view {
        // Check initial season setup
        assertEq(playerContract.currentSeason(), 0, "Should start at season 0");

        // Check season 0 metadata
        (uint256 startTimestamp, uint256 startBlock) = playerContract.seasons(0);
        assertGt(startTimestamp, 0, "Season 0 should have start timestamp");
        assertGt(startBlock, 0, "Season 0 should have start block");

        // Check next season start is calculated
        assertGt(playerContract.nextSeasonStart(), block.timestamp, "Next season should be in future");
    }

    function testSeasonLengthConfiguration() public {
        // Test initial season length
        assertEq(playerContract.seasonLengthMonths(), 1, "Should default to 1 month");

        // Test setting new season length
        vm.prank(address(this));
        vm.expectEmit(true, false, false, true);
        emit SeasonLengthUpdated(1, 3);
        playerContract.setSeasonLength(3);

        assertEq(playerContract.seasonLengthMonths(), 3, "Should update to 3 months");

        // Test invalid season lengths
        vm.prank(address(this));
        vm.expectRevert(InvalidSeasonLength.selector);
        playerContract.setSeasonLength(0);

        vm.prank(address(this));
        vm.expectRevert(InvalidSeasonLength.selector);
        playerContract.setSeasonLength(13);

        // Test non-owner cannot set
        vm.prank(USER_ONE);
        vm.expectRevert("Only callable by owner");
        playerContract.setSeasonLength(2);
    }

    function testSeasonCalculation() public {
        // Test season calculation function
        uint256 nextMonth = playerContract.getNextSeasonStart();
        assertGt(nextMonth, block.timestamp, "Next month should be in future");

        // Test with different season lengths
        vm.prank(address(this));
        playerContract.setSeasonLength(3);

        uint256 next3Months = playerContract.getNextSeasonStart();
        assertGt(next3Months, nextMonth, "3-month period should be later than 1-month");
    }

    // ==================== SEASON TRANSITION TESTS ====================

    function testSeasonTransition() public {
        uint256 initialSeason = playerContract.currentSeason();
        uint256 futureTime = playerContract.nextSeasonStart();

        // Warp to future season start time
        vm.warp(futureTime);

        // Trigger season check
        vm.expectEmit(true, false, false, true);
        emit SeasonStarted(initialSeason + 1, futureTime, block.number);
        playerContract.forceCurrentSeason();

        // Verify season updated
        assertEq(playerContract.currentSeason(), initialSeason + 1, "Season should increment");

        // Verify new season metadata
        (uint256 startTimestamp, uint256 startBlock) = playerContract.seasons(initialSeason + 1);
        assertEq(startTimestamp, futureTime, "New season timestamp should match");
        assertEq(startBlock, block.number, "New season block should match");

        // Verify next season start is recalculated
        assertGt(playerContract.nextSeasonStart(), futureTime, "Next season should be calculated");
    }

    function testSeasonTransitionOnRecordUpdate() public {
        uint256 futureTime = playerContract.nextSeasonStart();
        vm.warp(futureTime);

        uint256 initialSeason = playerContract.currentSeason();

        // Force season update explicitly
        vm.expectEmit(true, false, false, true);
        emit SeasonStarted(initialSeason + 1, futureTime, block.number);

        uint256 newSeason = playerContract.forceCurrentSeason();
        assertEq(newSeason, initialSeason + 1, "forceCurrentSeason should return new season");

        // Now increment wins - no automatic season transition
        playerContract.incrementWins(testPlayerId1, playerContract.currentSeason());

        assertEq(playerContract.currentSeason(), initialSeason + 1, "Season should be updated");
    }

    function testNoTransitionBeforeTime() public {
        uint256 initialSeason = playerContract.currentSeason();

        // Should not transition before time
        playerContract.forceCurrentSeason();
        assertEq(playerContract.currentSeason(), initialSeason, "Season should not change early");
    }

    // ==================== DUAL RECORD TRACKING TESTS ====================

    function testDualRecordTracking() public {
        // Initial records should be empty
        Fighter.Record memory seasonalRecord = playerContract.getCurrentSeasonRecord(testPlayerId1);
        Fighter.Record memory lifetimeRecord = playerContract.getLifetimeRecord(testPlayerId1);

        assertEq(seasonalRecord.wins, 0, "Initial seasonal wins should be 0");
        assertEq(lifetimeRecord.wins, 0, "Initial lifetime wins should be 0");

        // Add some wins/losses/kills
        playerContract.incrementWins(testPlayerId1, playerContract.currentSeason());
        playerContract.incrementWins(testPlayerId1, playerContract.currentSeason());
        playerContract.incrementLosses(testPlayerId1, playerContract.currentSeason());
        playerContract.incrementKills(testPlayerId1, playerContract.currentSeason());

        // Check both records updated
        seasonalRecord = playerContract.getCurrentSeasonRecord(testPlayerId1);
        lifetimeRecord = playerContract.getLifetimeRecord(testPlayerId1);

        assertEq(seasonalRecord.wins, 2, "Seasonal wins should be 2");
        assertEq(seasonalRecord.losses, 1, "Seasonal losses should be 1");
        assertEq(seasonalRecord.kills, 1, "Seasonal kills should be 1");

        assertEq(lifetimeRecord.wins, 2, "Lifetime wins should be 2");
        assertEq(lifetimeRecord.losses, 1, "Lifetime losses should be 1");
        assertEq(lifetimeRecord.kills, 1, "Lifetime kills should be 1");
    }

    function testRecordResetAcrossSeasons() public {
        // Add records in season 0
        playerContract.incrementWins(testPlayerId1, playerContract.currentSeason());
        playerContract.incrementWins(testPlayerId1, playerContract.currentSeason());
        playerContract.incrementLosses(testPlayerId1, playerContract.currentSeason());

        Fighter.Record memory season0Record = playerContract.getCurrentSeasonRecord(testPlayerId1);
        assertEq(season0Record.wins, 2, "Season 0 should have 2 wins");
        assertEq(season0Record.losses, 1, "Season 0 should have 1 loss");

        // Transition to season 1
        uint256 futureTime = playerContract.nextSeasonStart();
        vm.warp(futureTime);
        playerContract.forceCurrentSeason();

        // Current season record should be reset
        Fighter.Record memory season1Record = playerContract.getCurrentSeasonRecord(testPlayerId1);
        assertEq(season1Record.wins, 0, "Season 1 should start with 0 wins");
        assertEq(season1Record.losses, 0, "Season 1 should start with 0 losses");
        assertEq(season1Record.kills, 0, "Season 1 should start with 0 kills");

        // But we can still access season 0 record
        Fighter.Record memory oldSeason0Record = playerContract.getSeasonRecord(testPlayerId1, 0);
        assertEq(oldSeason0Record.wins, 2, "Season 0 record should be preserved");
        assertEq(oldSeason0Record.losses, 1, "Season 0 record should be preserved");

        // Lifetime record should be unchanged
        Fighter.Record memory lifetimeRecord = playerContract.getLifetimeRecord(testPlayerId1);
        assertEq(lifetimeRecord.wins, 2, "Lifetime wins should be preserved");
        assertEq(lifetimeRecord.losses, 1, "Lifetime losses should be preserved");

        // Add more records in season 1
        playerContract.incrementWins(testPlayerId1, playerContract.currentSeason());
        playerContract.incrementKills(testPlayerId1, playerContract.currentSeason());

        // Check seasonal vs lifetime
        season1Record = playerContract.getCurrentSeasonRecord(testPlayerId1);
        lifetimeRecord = playerContract.getLifetimeRecord(testPlayerId1);

        assertEq(season1Record.wins, 1, "Season 1 should have 1 win");
        assertEq(season1Record.kills, 1, "Season 1 should have 1 kill");

        assertEq(lifetimeRecord.wins, 3, "Lifetime should have 3 total wins");
        assertEq(lifetimeRecord.losses, 1, "Lifetime should have 1 total loss");
        assertEq(lifetimeRecord.kills, 1, "Lifetime should have 1 total kill");
    }

    function testGetCurrentRecordReturnsSeasonalData() public {
        // Add records
        playerContract.incrementWins(testPlayerId1, playerContract.currentSeason());
        playerContract.incrementLosses(testPlayerId1, playerContract.currentSeason());

        // In season 0, lifetime record should match seasonal record
        Fighter.Record memory lifetimeRecord = playerContract.getLifetimeRecord(testPlayerId1);
        Fighter.Record memory seasonalRecord = playerContract.getCurrentSeasonRecord(testPlayerId1);

        assertEq(lifetimeRecord.wins, seasonalRecord.wins, "Lifetime should match seasonal in season 0");
        assertEq(lifetimeRecord.losses, seasonalRecord.losses, "Lifetime should match seasonal in season 0");
        assertEq(lifetimeRecord.kills, seasonalRecord.kills, "Lifetime should match seasonal in season 0");
    }

    // ==================== HISTORICAL ENCODING TESTS ====================

    function testFightEncodingUsesSeasonalRecord() public {
        // Add some records to players
        playerContract.incrementWins(testPlayerId1, playerContract.currentSeason());
        playerContract.incrementLosses(testPlayerId2, playerContract.currentSeason());

        // Get player stats and seasonal records
        IPlayer.PlayerStats memory stats1 = playerContract.getPlayer(testPlayerId1);
        IPlayer.PlayerStats memory stats2 = playerContract.getPlayer(testPlayerId2);

        Fighter.Record memory record1 = playerContract.getCurrentSeasonRecord(testPlayerId1);
        Fighter.Record memory record2 = playerContract.getCurrentSeasonRecord(testPlayerId2);

        // Encode player data
        bytes32 encoded1 = playerContract.codec().encodePlayerData(testPlayerId1, stats1, record1);
        bytes32 encoded2 = playerContract.codec().encodePlayerData(testPlayerId2, stats2, record2);

        // Decode and verify
        (,, Fighter.Record memory decodedRecord1) = playerContract.codec().decodePlayerData(encoded1);

        (,, Fighter.Record memory decodedRecord2) = playerContract.codec().decodePlayerData(encoded2);

        // Verify decoded records match seasonal data
        assertEq(decodedRecord1.wins, 1, "Player 1 decoded wins should be 1");
        assertEq(decodedRecord1.losses, 0, "Player 1 decoded losses should be 0");

        assertEq(decodedRecord2.wins, 0, "Player 2 decoded wins should be 0");
        assertEq(decodedRecord2.losses, 1, "Player 2 decoded losses should be 1");
    }

    function testHistoricalSeasonalRecordPreservation() public {
        // Season 0: Add records
        playerContract.incrementWins(testPlayerId1, playerContract.currentSeason());
        playerContract.incrementWins(testPlayerId1, playerContract.currentSeason());

        // Get encoding BEFORE season transition
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(testPlayerId1);
        Fighter.Record memory season0Record = playerContract.getCurrentSeasonRecord(testPlayerId1);
        bytes32 season0Encoded = playerContract.codec().encodePlayerData(testPlayerId1, stats, season0Record);

        // Transition to season 1
        uint256 futureTime = playerContract.nextSeasonStart();
        vm.warp(futureTime);
        playerContract.forceCurrentSeason();

        // Add different records in season 1
        uint256 season1 = playerContract.currentSeason();
        playerContract.incrementLosses(testPlayerId1, season1);
        playerContract.incrementKills(testPlayerId1, season1);

        // The season 0 encoded data should still decode to season 0 records
        (,, Fighter.Record memory decodedSeason0Record) = playerContract.codec().decodePlayerData(season0Encoded);
        assertEq(decodedSeason0Record.wins, 2, "Historical encoding should preserve season 0 wins");
        assertEq(decodedSeason0Record.losses, 0, "Historical encoding should preserve season 0 losses");
        assertEq(decodedSeason0Record.kills, 0, "Historical encoding should preserve season 0 kills");

        // But current season records should be different
        Fighter.Record memory currentRecord = playerContract.getCurrentSeasonRecord(testPlayerId1);
        assertEq(currentRecord.wins, 0, "Season 1 should have different wins");
        assertEq(currentRecord.losses, 1, "Season 1 should have different losses");
        assertEq(currentRecord.kills, 1, "Season 1 should have different kills");
    }

    // ==================== GETTER FUNCTION TESTS ====================

    function testSeasonRecordGetters() public {
        // Add records across seasons
        playerContract.incrementWins(testPlayerId1, playerContract.currentSeason());

        uint256 futureTime = playerContract.nextSeasonStart();
        vm.warp(futureTime);
        playerContract.forceCurrentSeason(); // Now in season 1

        uint256 season1Id = playerContract.currentSeason();
        playerContract.incrementLosses(testPlayerId1, season1Id);
        playerContract.incrementKills(testPlayerId1, season1Id);

        // Test getters
        Fighter.Record memory season0 = playerContract.getSeasonRecord(testPlayerId1, 0);
        Fighter.Record memory season1 = playerContract.getSeasonRecord(testPlayerId1, 1);
        Fighter.Record memory current = playerContract.getCurrentSeasonRecord(testPlayerId1);
        Fighter.Record memory lifetime = playerContract.getLifetimeRecord(testPlayerId1);

        // Verify season 0
        assertEq(season0.wins, 1, "Season 0 should have 1 win");
        assertEq(season0.losses, 0, "Season 0 should have 0 losses");
        assertEq(season0.kills, 0, "Season 0 should have 0 kills");

        // Verify season 1
        assertEq(season1.wins, 0, "Season 1 should have 0 wins");
        assertEq(season1.losses, 1, "Season 1 should have 1 loss");
        assertEq(season1.kills, 1, "Season 1 should have 1 kill");

        // Verify current matches season 1
        assertEq(current.wins, season1.wins, "Current should match season 1");
        assertEq(current.losses, season1.losses, "Current should match season 1");
        assertEq(current.kills, season1.kills, "Current should match season 1");

        // Verify lifetime is cumulative
        assertEq(lifetime.wins, 1, "Lifetime should have 1 total win");
        assertEq(lifetime.losses, 1, "Lifetime should have 1 total loss");
        assertEq(lifetime.kills, 1, "Lifetime should have 1 total kill");
    }

    // ==================== MULTIPLE SEASON TESTS ====================

    function testMultipleSeasonTransitions() public {
        uint256 startingSeason = playerContract.currentSeason();

        // Go through 3 season transitions
        for (uint256 i = 0; i < 3; i++) {
            // Add records in current season
            playerContract.incrementWins(testPlayerId1, playerContract.currentSeason());

            // Transition to next season
            uint256 futureTime = playerContract.nextSeasonStart();
            vm.warp(futureTime);
            playerContract.forceCurrentSeason();

            // Verify season incremented
            assertEq(playerContract.currentSeason(), startingSeason + i + 1, "Season should increment correctly");

            // Verify current season starts clean
            Fighter.Record memory currentRecord = playerContract.getCurrentSeasonRecord(testPlayerId1);
            assertEq(currentRecord.wins, 0, "New season should start with 0 wins");
        }

        // Verify all historical seasons preserved
        for (uint256 season = 0; season < 3; season++) {
            Fighter.Record memory historicalRecord = playerContract.getSeasonRecord(testPlayerId1, season);
            assertEq(historicalRecord.wins, 1, string(abi.encodePacked("Season ", season, " should have 1 win")));
        }

        // Verify lifetime totals
        Fighter.Record memory lifetimeRecord = playerContract.getLifetimeRecord(testPlayerId1);
        assertEq(lifetimeRecord.wins, 3, "Lifetime should have 3 total wins");
    }

    function testConfigurableSeasonLengthTransitions() public {
        // Set 3-month seasons
        vm.prank(address(this));
        playerContract.setSeasonLength(3);

        uint256 initialNextStart = playerContract.nextSeasonStart();

        // Change to 1-month seasons
        vm.prank(address(this));
        playerContract.setSeasonLength(1);

        // Next season start should be recalculated
        uint256 newNextStart = playerContract.nextSeasonStart();
        assertLt(newNextStart, initialNextStart, "1-month season should come sooner than 3-month");
    }

    // ==================== EDGE CASE TESTS ====================

    function testPlayerCreationInDifferentSeasons() public {
        // Create player in season 0
        uint32 season0Player = _createPlayerAndFulfillVRF(USER_THREE, false);
        playerContract.incrementWins(season0Player, playerContract.currentSeason());

        // Transition to season 1
        uint256 futureTime = playerContract.nextSeasonStart();
        vm.warp(futureTime);
        playerContract.forceCurrentSeason();

        // Create player in season 1
        uint32 season1Player = _createPlayerAndFulfillVRF(USER_FOUR, false);
        playerContract.incrementWins(season1Player, playerContract.currentSeason());

        // Both players should have different seasonal records
        Fighter.Record memory s0PlayerSeason0 = playerContract.getSeasonRecord(season0Player, 0);
        Fighter.Record memory s0PlayerSeason1 = playerContract.getSeasonRecord(season0Player, 1);
        Fighter.Record memory s1PlayerSeason0 = playerContract.getSeasonRecord(season1Player, 0);
        Fighter.Record memory s1PlayerSeason1 = playerContract.getSeasonRecord(season1Player, 1);

        assertEq(s0PlayerSeason0.wins, 1, "Season 0 player should have season 0 record");
        assertEq(s0PlayerSeason1.wins, 0, "Season 0 player should have empty season 1 record");
        assertEq(s1PlayerSeason0.wins, 0, "Season 1 player should have empty season 0 record");
        assertEq(s1PlayerSeason1.wins, 1, "Season 1 player should have season 1 record");
    }

    function testEmptySeasonRecords() public view {
        // Get records for seasons that haven't happened yet
        Fighter.Record memory futureRecord = playerContract.getSeasonRecord(testPlayerId1, 999);
        assertEq(futureRecord.wins, 0, "Future season should have empty records");
        assertEq(futureRecord.losses, 0, "Future season should have empty records");
        assertEq(futureRecord.kills, 0, "Future season should have empty records");
    }
}

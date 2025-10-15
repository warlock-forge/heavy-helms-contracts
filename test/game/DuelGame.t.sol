// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {console2} from "forge-std/console2.sol";
import {DuelGame} from "../../src/game/modes/DuelGame.sol";
import {TestBase} from "../TestBase.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";
import {DefaultPlayerLibrary} from "../../src/fighters/lib/DefaultPlayerLibrary.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";

contract DuelGameTest is TestBase {
    DuelGame public game;

    // Test addresses
    address public PLAYER_ONE;
    address public PLAYER_TWO;
    uint32 public PLAYER_ONE_ID;
    uint32 public PLAYER_TWO_ID;

    // Events to test
    event ChallengeCreated(
        uint256 indexed challengeId,
        uint32 indexed challengerId,
        uint32 indexed defenderId,
        uint32 challengerSkinIndex,
        uint16 challengerSkinTokenId,
        uint8 challengerStance,
        bool paidWithTicket
    );
    event ChallengeAccepted(
        uint256 indexed challengeId,
        uint32 indexed defenderId,
        uint32 defenderSkinIndex,
        uint16 defenderSkinTokenId,
        uint8 defenderStance
    );
    event ChallengeCancelled(uint256 indexed challengeId);
    event DuelComplete( // This is the key addition
        uint256 indexed challengeId,
        uint32 indexed winnerId,
        uint256 randomness
    );
    event ChallengeRecovered(uint256 indexed challengeId);

    function setUp() public override {
        super.setUp();

        // Use the same test keyHash from TestBase
        bytes32 testKeyHash = 0x0000000000000000000000000000000000000000000000000000000000000001;

        game = new DuelGame(
            address(gameEngine),
            payable(address(playerContract)),
            vrfCoordinator,
            subscriptionId,
            testKeyHash,
            address(playerTickets)
        );

        // Add DuelGame as a consumer to the VRF subscription
        vrfMock.addConsumer(subscriptionId, address(game));

        // Set permissions for game contract
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, immortal: false, experience: false});
        playerContract.setGameContractPermission(address(game), perms);

        // Setup test addresses
        PLAYER_ONE = address(0xdF);
        PLAYER_TWO = address(0xeF);

        // Create actual players using VRF
        PLAYER_ONE_ID = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        PLAYER_TWO_ID = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);

        // Give them ETH
        vm.deal(PLAYER_ONE, 100 ether);
        vm.deal(PLAYER_TWO, 100 ether);

        // Give them duel tickets for testing
        _mintDuelTickets(PLAYER_ONE, 10);
        _mintDuelTickets(PLAYER_TWO, 10);

        // Give players approval to DuelGame to burn their tickets
        vm.prank(PLAYER_ONE);
        playerTickets.setApprovalForAll(address(game), true);
        vm.prank(PLAYER_TWO);
        playerTickets.setApprovalForAll(address(game), true);
    }

    function testInitialState() public view {
        assertEq(address(game.gameEngine()), address(gameEngine));
        assertEq(address(game.playerContract()), address(playerContract));
        assertEq(address(game.playerTickets()), address(playerTickets));
        assertEq(game.nextChallengeId(), 0);
    }

    function testAcceptChallenge() public {
        // First create a challenge
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // Verify challenge state before acceptance
        (,,,, uint256 initialVrfTimestamp,,, DuelGame.ChallengeState initialState) = game.challenges(challengeId);
        assertTrue(initialState == DuelGame.ChallengeState.OPEN, "Challenge should be OPEN");
        assertEq(initialVrfTimestamp, 0, "VRF timestamp should be 0 initially");

        // Accept challenge as player two and verify VRF workflow
        vm.startPrank(PLAYER_TWO);
        vm.recordLogs();
        game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        // Verify challenge state changed to PENDING after VRF request
        (,,,, uint256 vrfTimestamp,,, DuelGame.ChallengeState pendingState) = game.challenges(challengeId);
        assertTrue(pendingState == DuelGame.ChallengeState.PENDING, "Challenge should be PENDING");
        assertTrue(vrfTimestamp > 0, "VRF timestamp should be set after acceptance");

        // Verify challenge state changed to PENDING (indicates VRF request was made)
        assertTrue(game.isChallengePending(challengeId), "Challenge should be pending after acceptance");

        // Verify loadouts were stored correctly during acceptance
        (,,,,, Fighter.PlayerLoadout memory challengerLoadout, Fighter.PlayerLoadout memory defenderLoadout,) =
            game.challenges(challengeId);
        assertEq(challengerLoadout.playerId, PLAYER_ONE_ID, "Challenger loadout incorrect");
        assertEq(defenderLoadout.playerId, PLAYER_TWO_ID, "Defender loadout incorrect");
    }

    function testCancelExpiredChallenge() public {
        vm.startPrank(PLAYER_ONE);

        // Get challenger's address
        address challenger = playerContract.getPlayerOwner(PLAYER_ONE_ID);
        require(challenger == PLAYER_ONE, "Player one should own their player");

        // Create a challenge
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);

        // Warp to after expiry - using timestamps now instead of blocks
        vm.warp(block.timestamp + game.timeUntilExpire() + 1);

        // Cancel the challenge
        game.cancelChallenge(challengeId);

        // Verify challenge state
        (,,,,,,, DuelGame.ChallengeState state) = game.challenges(challengeId);
        assertTrue(state == DuelGame.ChallengeState.COMPLETED);
        vm.stopPrank();
    }

    function testCompleteDuelWorkflow() public {
        // Complete end-to-end duel workflow
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // Accept challenge
        vm.startPrank(PLAYER_TWO);
        vm.recordLogs();
        game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        // Fulfill VRF to complete the duel
        _fulfillVRFRequest(address(game));

        // Verify final challenge state
        (
            uint32 challengerId,
            uint32 defenderId,
            uint256 createdBlock,
            uint256 createdTimestamp,
            uint256 vrfRequestTimestamp,
            Fighter.PlayerLoadout memory challengerLoadout,
            Fighter.PlayerLoadout memory defenderLoadout,
            DuelGame.ChallengeState finalState
        ) = game.challenges(challengeId);

        // Verify challenge data integrity
        assertEq(challengerId, PLAYER_ONE_ID, "Challenger ID should match");
        assertEq(defenderId, PLAYER_TWO_ID, "Defender ID should match");
        assertTrue(createdTimestamp > 0, "Challenge should have creation timestamp");
        assertTrue(createdBlock > 0, "Challenge should have creation block");
        assertTrue(vrfRequestTimestamp > 0, "Challenge should have VRF request timestamp");
        assertTrue(finalState == DuelGame.ChallengeState.COMPLETED, "Challenge should be COMPLETED");

        // Verify loadouts were stored correctly
        assertEq(challengerLoadout.playerId, PLAYER_ONE_ID, "Challenger loadout should match");
        assertEq(defenderLoadout.playerId, PLAYER_TWO_ID, "Defender loadout should match");

        // Verify next challenge ID incremented
        assertEq(game.nextChallengeId(), 1, "Next challenge ID should increment");
    }

    function test_RevertWhen_UsingDefaultCharacter() public {
        vm.startPrank(PLAYER_ONE);

        Fighter.PlayerLoadout memory loadout =
            Fighter.PlayerLoadout({playerId: 999, skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}), stance: 1});

        vm.expectRevert("Unsupported player ID for Duel mode");
        game.initiateChallengeWithTicket(loadout, PLAYER_TWO_ID);
        vm.stopPrank();
    }

    function test_RevertWhen_CancellingNonExistentChallenge() public {
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert("Challenge does not exist");
        game.cancelChallenge(999);
        vm.stopPrank();
    }

    function test_RevertWhen_WrongDefenderAccepts() public {
        // First create a valid challenge
        vm.startPrank(PLAYER_ONE);

        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);
        uint256 challengeId = game.initiateChallengeWithTicket(loadout, PLAYER_TWO_ID);
        vm.stopPrank();

        // Try to accept with wrong defender
        vm.startPrank(PLAYER_ONE);
        Fighter.PlayerLoadout memory defenderLoadout = _createLoadout(PLAYER_TWO_ID);

        vm.expectRevert(bytes("Not defender"));
        game.acceptChallenge(challengeId, defenderLoadout);
        vm.stopPrank();
    }

    function testGameToggle() public {
        // Verify game starts enabled
        assertTrue(game.isGameEnabled(), "Game should start enabled");

        // Verify non-owner can't disable
        vm.prank(PLAYER_ONE);
        vm.expectRevert("Only callable by owner");
        game.setGameEnabled(false);

        // Owner can disable
        vm.startPrank(game.owner());
        game.setGameEnabled(false);
        assertFalse(game.isGameEnabled(), "Game should be disabled");

        vm.startPrank(PLAYER_ONE);
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);
        vm.expectRevert("Game is disabled");
        game.initiateChallengeWithTicket(loadout, PLAYER_TWO_ID);
        vm.stopPrank();

        // Owner can re-enable
        vm.startPrank(game.owner());
        game.setGameEnabled(true);
        assertTrue(game.isGameEnabled(), "Game should be re-enabled");
        vm.stopPrank();
    }

    function testHelperFunctions() public {
        // Create a challenge
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // 1. Test initial state
        assertTrue(game.isChallengeActive(challengeId), "Challenge should be active initially");
        assertFalse(game.isChallengePending(challengeId), "Challenge should not be pending initially");
        assertFalse(game.isChallengeCompleted(challengeId), "Challenge should not be completed initially");
        assertFalse(game.isChallengeExpired(challengeId), "Challenge should not be expired initially");

        // 2. Create a second challenge to test acceptance
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId2 = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // 3. Accept the second challenge and test pending state
        vm.startPrank(PLAYER_TWO);
        vm.recordLogs();
        game.acceptChallenge(challengeId2, _createLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        assertFalse(game.isChallengeActive(challengeId2), "Challenge should not be active after acceptance");
        assertTrue(game.isChallengePending(challengeId2), "Challenge should be pending after acceptance");
        assertFalse(game.isChallengeCompleted(challengeId2), "Challenge should not be completed after acceptance");

        // 4. Roll forward to expire the first challenge - using timestamps now instead of blocks
        vm.warp(block.timestamp + game.timeUntilExpire() + 1);

        // Test the expired challenge state
        assertFalse(game.isChallengeActive(challengeId), "Challenge should not be active after expiration");
        assertTrue(game.isChallengeExpired(challengeId), "Challenge should be expired");

        // 5. Fulfill randomness for the second (accepted) challenge
        _fulfillVRFRequest(address(game));

        // Test completed state
        assertFalse(game.isChallengeActive(challengeId2), "Challenge should not be active after completion");
        assertFalse(game.isChallengePending(challengeId2), "Challenge should not be pending after completion");
        assertTrue(game.isChallengeCompleted(challengeId2), "Challenge should be completed after fulfillment");
    }

    function testDuelsDoNotUpdateWinLossRecords() public {
        // Get initial win/loss records
        Fighter.Record memory initialP1Record = playerContract.getCurrentSeasonRecord(PLAYER_ONE_ID);
        Fighter.Record memory initialP2Record = playerContract.getCurrentSeasonRecord(PLAYER_TWO_ID);

        // Complete a duel
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        vm.startPrank(PLAYER_TWO);
        vm.recordLogs();
        game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        _fulfillVRFRequest(address(game));

        // Verify win/loss records are unchanged
        Fighter.Record memory finalP1Record = playerContract.getCurrentSeasonRecord(PLAYER_ONE_ID);
        Fighter.Record memory finalP2Record = playerContract.getCurrentSeasonRecord(PLAYER_TWO_ID);

        assertEq(finalP1Record.wins, initialP1Record.wins, "Player 1 wins should be unchanged");
        assertEq(finalP1Record.losses, initialP1Record.losses, "Player 1 losses should be unchanged");
        assertEq(finalP2Record.wins, initialP2Record.wins, "Player 2 wins should be unchanged");
        assertEq(finalP2Record.losses, initialP2Record.losses, "Player 2 losses should be unchanged");
    }

    function testDuelTicketRequired() public {
        // Create new player with no tickets
        address newPlayer = address(0xABC);
        vm.deal(newPlayer, 100 ether);
        uint32 newPlayerId = _createPlayerAndFulfillVRF(newPlayer, playerContract, false);

        // Verify player has no tickets
        assertEq(
            playerTickets.balanceOf(newPlayer, playerTickets.DUEL_TICKET()), 0, "New player should have no tickets"
        );

        // Try to create challenge without ticket - should fail
        vm.startPrank(newPlayer);
        Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
            playerId: newPlayerId, skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}), stance: 1
        });
        vm.expectRevert();
        game.initiateChallengeWithTicket(loadout, PLAYER_TWO_ID);
        vm.stopPrank();

        // Give them a ticket and try again - should work
        _mintDuelTickets(newPlayer, 1);

        // Give approval to burn tickets
        vm.prank(newPlayer);
        playerTickets.setApprovalForAll(address(game), true);

        vm.startPrank(newPlayer);
        uint256 challengeId = game.initiateChallengeWithTicket(loadout, PLAYER_TWO_ID);
        vm.stopPrank();

        // Verify challenge was created
        (uint32 challengerId,,,,,,,) = game.challenges(challengeId);
        assertEq(challengerId, newPlayerId);

        // Verify ticket was burned
        assertEq(playerTickets.balanceOf(newPlayer, playerTickets.DUEL_TICKET()), 0);
    }

    function test_RevertWhen_AcceptingExpiredChallenge() public {
        // Create a challenge
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // Get current challenge state
        (,, uint256 createdBlock, uint256 createdTimestamp,,,, DuelGame.ChallengeState state) =
            game.challenges(challengeId);
        console2.log("Initial state:", uint256(state));
        console2.log("Created at block:", createdBlock);
        console2.log("Created at timestamp:", createdTimestamp);
        console2.log("Current block:", block.number);
        console2.log("Current timestamp:", block.timestamp);
        console2.log("Time until expire:", game.timeUntilExpire());

        // Warp forward enough time to ensure expiration
        vm.warp(block.timestamp + game.timeUntilExpire() + 10); // Add extra time to be safe

        console2.log("After warp, timestamp:", block.timestamp);
        console2.log("Expiration threshold:", createdTimestamp + game.timeUntilExpire());

        // Manually check if it should be expired
        bool shouldBeExpired = block.timestamp > createdTimestamp + game.timeUntilExpire();
        console2.log("Should be expired?", shouldBeExpired);
        console2.log("Is expired according to contract?", game.isChallengeExpired(challengeId));
        console2.log("Is active according to contract?", game.isChallengeActive(challengeId));

        // Try to accept the challenge
        vm.startPrank(PLAYER_TWO);

        // Don't use expectRevert here, instead try/catch to see what happens
        bool didRevert = false;
        try game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID)) {
            console2.log("Call succeeded unexpectedly!");
        } catch Error(string memory reason) {
            console2.log("Reverted with reason:", reason);
            didRevert = true;
        } catch (bytes memory) {
            /*lowLevelData*/
            console2.log("Reverted with no reason");
            didRevert = true;
        }

        // Assert that it did revert
        assertTrue(didRevert, "Challenge acceptance should have reverted");
        vm.stopPrank();
    }

    function test_RevertWhen_PlayerRetiredDuringFulfillment() public {
        // First, we need to give ourselves permission to retire players
        IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
            record: false,
            retire: true, // Need this permission to retire players
            immortal: false,
            experience: false
        });
        playerContract.setGameContractPermission(address(this), perms);

        // Create a challenge
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // Accept the challenge
        vm.startPrank(PLAYER_TWO);
        vm.recordLogs();
        game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        // Retire the player with our permission
        // Using the test contract (this) since it has permissions
        playerContract.setPlayerRetired(PLAYER_ONE_ID, true);

        // Fulfillment should revert
        vm.prank(vrfCoordinator);
        vm.expectRevert(bytes("Challenger is retired"));
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao)));
        game.rawFulfillRandomWords(1, randomWords);
    }

    function test_RevertWhen_ChallengerRetiredBeforeAcceptance() public {
        // Create a challenge
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);

        // Retire the challenger's player using the player's own method
        playerContract.retireOwnPlayer(PLAYER_ONE_ID);

        // Verify retirement was successful
        assertTrue(playerContract.isPlayerRetired(PLAYER_ONE_ID), "Player not retired");
        vm.stopPrank();

        // Try to accept the challenge - should revert due to retired challenger
        vm.startPrank(PLAYER_TWO);

        // Create the loadout FIRST, outside the expectRevert scope
        Fighter.PlayerLoadout memory defenderLoadout = _createLoadout(PLAYER_TWO_ID);

        // Now expect the revert on just the acceptChallenge call
        vm.expectRevert("Challenger is retired");
        game.acceptChallenge(challengeId, defenderLoadout);

        vm.stopPrank();
    }

    function testRecoverTimedOutVRF() public {
        // Step 1: Create a challenge
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // Step 2: Accept the challenge as PLAYER_TWO to make it PENDING
        vm.startPrank(PLAYER_TWO);
        vm.recordLogs();
        game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        // Verify challenge is in PENDING state
        assertTrue(game.isChallengePending(challengeId), "Challenge should be pending after acceptance");

        // Step 3: Fast forward time past VRF timeout
        vm.warp(block.timestamp + game.vrfRequestTimeout() + 1);

        // Step 4: Call recoverTimedOutVRF as challenger
        vm.startPrank(PLAYER_ONE);
        vm.expectEmit(true, false, false, false);
        emit ChallengeRecovered(challengeId);
        game.recoverTimedOutVRF(challengeId);
        vm.stopPrank();

        // Step 5: Verify results
        // Challenge should be completed
        assertTrue(game.isChallengeCompleted(challengeId), "Challenge should be completed after recovery");
    }

    function testRevertWhen_RecoverTimedOutVRF_NotAuthorized() public {
        // Create and accept challenge like in previous test
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        vm.startPrank(PLAYER_TWO);
        game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        // Fast forward time past VRF timeout
        vm.warp(block.timestamp + game.vrfRequestTimeout() + 1);

        // Try to recover as unauthorized address
        address randomUser = address(0x123);
        vm.prank(randomUser);
        vm.expectRevert("Not authorized");
        game.recoverTimedOutVRF(challengeId);
    }

    function testRevertWhen_RecoverTimedOutVRF_TimeoutNotReached() public {
        // Create and accept challenge
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        vm.startPrank(PLAYER_TWO);
        game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        // Try to recover before timeout
        vm.prank(PLAYER_ONE);
        vm.expectRevert("VRF timeout not reached");
        game.recoverTimedOutVRF(challengeId);
    }

    function testMultipleSimultaneousChallenges() public {
        // Test that a player can have multiple open challenges
        vm.startPrank(PLAYER_ONE);

        // Create first challenge against PLAYER_TWO
        uint256 challengeId1 = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);

        // Create second challenge against PLAYER_TWO (same defender)
        uint256 challengeId2 = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);

        // Verify both challenges exist and are OPEN
        (,,,,,,, DuelGame.ChallengeState state1) = game.challenges(challengeId1);
        (,,,,,,, DuelGame.ChallengeState state2) = game.challenges(challengeId2);
        assertTrue(state1 == DuelGame.ChallengeState.OPEN, "First challenge should be OPEN");
        assertTrue(state2 == DuelGame.ChallengeState.OPEN, "Second challenge should be OPEN");

        // Verify challenge IDs are different
        assertTrue(challengeId1 != challengeId2, "Challenge IDs should be different");
        assertEq(challengeId2, challengeId1 + 1, "Challenge IDs should increment");

        vm.stopPrank();

        // Now test PLAYER_TWO can also create challenges while having incoming challenges
        vm.startPrank(PLAYER_TWO);
        uint256 challengeId3 = game.initiateChallengeWithTicket(_createLoadout(PLAYER_TWO_ID), PLAYER_ONE_ID);
        vm.stopPrank();

        // Verify all three challenges coexist
        assertTrue(game.isChallengeActive(challengeId1), "Challenge 1 should be active");
        assertTrue(game.isChallengeActive(challengeId2), "Challenge 2 should be active");
        assertTrue(game.isChallengeActive(challengeId3), "Challenge 3 should be active");
    }

    function testLoadoutOverridesEquipped() public {
        // Create challenge with different loadouts than equipped
        // Use skins with no stat requirements: DefaultWarrior (1) and LowStaminaClubsWarrior (17)
        Fighter.PlayerLoadout memory challengerLoadout = Fighter.PlayerLoadout({
            playerId: PLAYER_ONE_ID,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.LowStaminaClubsWarrior) + 1 // Uses dual clubs (18)
            }),
            stance: 2 // Aggressive (different from default neutral)
        });

        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(challengerLoadout, PLAYER_TWO_ID);
        vm.stopPrank();

        // Accept with different loadout
        Fighter.PlayerLoadout memory defenderLoadout = Fighter.PlayerLoadout({
            playerId: PLAYER_TWO_ID,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.DefaultWarrior) + 1 // Uses quarterstaff (5)
            }),
            stance: 0 // Defensive (different from default neutral)
        });

        vm.startPrank(PLAYER_TWO);
        vm.recordLogs();
        game.acceptChallenge(challengeId, defenderLoadout);
        vm.stopPrank();

        // Retrieve stored loadouts from challenge
        (
            ,,,,,
            Fighter.PlayerLoadout memory storedChallengerLoadout,
            Fighter.PlayerLoadout memory storedDefenderLoadout,
        ) = game.challenges(challengeId);

        // Verify loadouts were stored as passed, not as equipped
        assertEq(
            storedChallengerLoadout.skin.skinTokenId,
            uint16(DefaultPlayerLibrary.CharacterType.LowStaminaClubsWarrior) + 1,
            "Challenger should use LowStaminaClubsWarrior skin from loadout"
        );
        assertEq(storedChallengerLoadout.stance, 2, "Challenger should use aggressive stance from loadout");

        assertEq(
            storedDefenderLoadout.skin.skinTokenId,
            uint16(DefaultPlayerLibrary.CharacterType.DefaultWarrior) + 1,
            "Defender should use DefaultWarrior skin from loadout"
        );
        assertEq(storedDefenderLoadout.stance, 0, "Defender should use defensive stance from loadout");

        // Complete the duel to ensure loadouts are used in combat
        _fulfillVRFRequest(address(game));

        // Challenge completed successfully with override loadouts
        assertTrue(game.isChallengeCompleted(challengeId), "Challenge should complete with override loadouts");
    }

    function testDuelFeeAmountConfiguration() public {
        // Test default value
        assertEq(game.duelFeeAmount(), 0.0001 ether, "Default duel fee should be 0.0001 ETH");

        // Test owner can update fee
        vm.prank(game.owner());
        vm.expectEmit(true, false, false, true);
        emit DuelFeeAmountUpdated(0.0001 ether, 0.0002 ether);
        game.setDuelFeeAmount(0.0002 ether);

        assertEq(game.duelFeeAmount(), 0.0002 ether, "Fee should be updated to 0.0002 ETH");

        // Test non-owner cannot update fee
        vm.prank(PLAYER_ONE);
        vm.expectRevert("Only callable by owner");
        game.setDuelFeeAmount(0.0003 ether);
    }

    function testInitiateChallengeWithETH() public {
        vm.startPrank(PLAYER_ONE);

        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        vm.expectEmit(true, true, true, true);
        emit ChallengeCreated(
            0, PLAYER_ONE_ID, PLAYER_TWO_ID, loadout.skin.skinIndex, loadout.skin.skinTokenId, loadout.stance, false
        );

        uint256 challengeId = game.initiateChallengeWithETH{value: 0.0001 ether}(loadout, PLAYER_TWO_ID);

        assertEq(challengeId, 0);
        (uint32 challengerId, uint32 defenderId,,,,,, DuelGame.ChallengeState state) = game.challenges(challengeId);
        assertEq(challengerId, PLAYER_ONE_ID);
        assertEq(defenderId, PLAYER_TWO_ID);
        assertTrue(state == DuelGame.ChallengeState.OPEN);
        vm.stopPrank();
    }

    function testInitiateChallengeWithTicket() public {
        vm.startPrank(PLAYER_ONE);

        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        vm.expectEmit(true, true, true, true);
        emit ChallengeCreated(
            0, PLAYER_ONE_ID, PLAYER_TWO_ID, loadout.skin.skinIndex, loadout.skin.skinTokenId, loadout.stance, true
        );

        uint256 challengeId = game.initiateChallengeWithTicket(loadout, PLAYER_TWO_ID);

        assertEq(challengeId, 0);
        (uint32 challengerId, uint32 defenderId,,,,,, DuelGame.ChallengeState state) = game.challenges(challengeId);
        assertEq(challengerId, PLAYER_ONE_ID);
        assertEq(defenderId, PLAYER_TWO_ID);
        assertTrue(state == DuelGame.ChallengeState.OPEN);
        vm.stopPrank();
    }

    function testRevertWhen_InsufficientETHForDuel() public {
        vm.startPrank(PLAYER_ONE);

        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // Try with insufficient ETH
        vm.expectRevert("Insufficient fee amount");
        game.initiateChallengeWithETH{value: 0.00005 ether}(loadout, PLAYER_TWO_ID);

        // Try with exact amount (should work)
        uint256 challengeId = game.initiateChallengeWithETH{value: 0.0001 ether}(loadout, PLAYER_TWO_ID);
        assertEq(challengeId, 0);

        vm.stopPrank();
    }

    function testRevertWhen_NoTicketsForDuel() public {
        // Create new player with no tickets
        address newPlayer = address(0xDEF);
        vm.deal(newPlayer, 100 ether);
        uint32 newPlayerId = _createPlayerAndFulfillVRF(newPlayer, playerContract, false);

        // Give approval to burn tickets (needed for the revert test)
        vm.prank(newPlayer);
        playerTickets.setApprovalForAll(address(game), true);

        // Verify player has no tickets
        assertEq(
            playerTickets.balanceOf(newPlayer, playerTickets.DUEL_TICKET()), 0, "New player should have no tickets"
        );

        // Try to create challenge with ticket - should fail due to insufficient balance
        vm.startPrank(newPlayer);
        Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
            playerId: newPlayerId, skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}), stance: 1
        });
        vm.expectRevert();
        game.initiateChallengeWithTicket(loadout, PLAYER_TWO_ID);
        vm.stopPrank();

        // But ETH payment should work - give them enough ETH for the duel fee
        vm.deal(newPlayer, 1 ether);
        vm.startPrank(newPlayer);
        uint256 challengeId = game.initiateChallengeWithETH{value: 0.0001 ether}(loadout, PLAYER_TWO_ID);
        vm.stopPrank();

        // Verify challenge was created
        (uint32 challengerId,,,,,,,) = game.challenges(challengeId);
        assertEq(challengerId, newPlayerId);
    }

    function testETHWithdrawal() public {
        uint256 initialBalance = game.owner().balance;

        // Create some challenges with ETH to accumulate fees
        vm.startPrank(PLAYER_ONE);
        game.initiateChallengeWithETH{value: 0.0001 ether}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        vm.startPrank(PLAYER_TWO);
        game.initiateChallengeWithETH{value: 0.0001 ether}(_createLoadout(PLAYER_TWO_ID), PLAYER_ONE_ID);
        vm.stopPrank();

        // Contract should have 0.0002 ETH
        assertEq(address(game).balance, 0.0002 ether, "Contract should have accumulated fees");

        // Owner can withdraw
        vm.prank(game.owner());
        game.withdrawFees();

        // Check balances
        assertEq(address(game).balance, 0, "Contract balance should be zero after withdrawal");
        assertEq(game.owner().balance, initialBalance + 0.0002 ether, "Owner should receive the fees");
    }

    function testCompleteDuelWorkflowWithETH() public {
        // Complete end-to-end duel workflow using ETH payment
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId =
            game.initiateChallengeWithETH{value: 0.0001 ether}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // Accept challenge
        vm.startPrank(PLAYER_TWO);
        vm.recordLogs();
        game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        // Fulfill VRF to complete the duel
        _fulfillVRFRequest(address(game));

        // Verify final challenge state
        assertTrue(game.isChallengeCompleted(challengeId), "Challenge should be completed");

        // Verify next challenge ID incremented
        assertEq(game.nextChallengeId(), 1, "Next challenge ID should increment");
    }

    function testMixedPaymentMethods() public {
        // Test that both payment methods can be used in the same game
        vm.startPrank(PLAYER_ONE);
        uint256 ethChallengeId =
            game.initiateChallengeWithETH{value: 0.0001 ether}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        uint256 ticketChallengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // Verify both challenges were created
        assertTrue(game.isChallengeActive(ethChallengeId), "ETH challenge should be active");
        assertTrue(game.isChallengeActive(ticketChallengeId), "Ticket challenge should be active");
        assertEq(ethChallengeId + 1, ticketChallengeId, "Challenge IDs should be sequential");
    }

    event DuelFeeAmountUpdated(uint256 oldValue, uint256 newValue);
    event GasProtectionUpdated(bool enabled);
    event MaxAcceptGasPriceUpdated(uint256 oldValue, uint256 newValue);

    function testGasProtectionDefaults() public {
        // Test default values
        assertEq(game.maxAcceptGasPrice(), 100000000, "Default max gas price should be 0.1 gwei");
        assertTrue(game.gasProtectionEnabled(), "Gas protection should be enabled by default");
    }

    function testGasProtectionConfiguration() public {
        // Test owner can update gas protection settings
        vm.startPrank(game.owner());

        // Test disabling gas protection
        vm.expectEmit(true, false, false, true);
        emit GasProtectionUpdated(false);
        game.setGasProtectionEnabled(false);
        assertFalse(game.gasProtectionEnabled(), "Gas protection should be disabled");

        // Test enabling gas protection
        vm.expectEmit(true, false, false, true);
        emit GasProtectionUpdated(true);
        game.setGasProtectionEnabled(true);
        assertTrue(game.gasProtectionEnabled(), "Gas protection should be enabled");

        // Test updating max gas price
        vm.expectEmit(true, false, false, true);
        emit MaxAcceptGasPriceUpdated(100000000, 200000000);
        game.setMaxAcceptGasPrice(200000000); // 0.2 gwei
        assertEq(game.maxAcceptGasPrice(), 200000000, "Max gas price should be updated");

        vm.stopPrank();

        // Test non-owner cannot update settings
        vm.prank(PLAYER_ONE);
        vm.expectRevert("Only callable by owner");
        game.setGasProtectionEnabled(false);

        vm.prank(PLAYER_ONE);
        vm.expectRevert("Only callable by owner");
        game.setMaxAcceptGasPrice(300000000);
    }

    function testGasProtectionValidation() public {
        // Test zero gas price validation
        vm.prank(game.owner());
        vm.expectRevert("Gas price must be positive");
        game.setMaxAcceptGasPrice(0);
    }

    function testAcceptChallengeWithLowGas() public {
        // Create challenge first
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // Accept challenge with low gas (should work)
        vm.startPrank(PLAYER_TWO);
        vm.txGasPrice(50000000); // Set gas price to 0.05 gwei - below limit
        game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        // Verify challenge is now pending
        assertTrue(game.isChallengePending(challengeId), "Challenge should be pending after low-gas acceptance");
    }

    function testAcceptChallengeWithHighGas() public {
        // Create challenge first
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // Try to accept challenge with high gas (should fail)
        vm.startPrank(PLAYER_TWO);
        vm.txGasPrice(200000000); // Set gas price to 0.2 gwei - above limit

        Fighter.PlayerLoadout memory defenderLoadout = _createLoadout(PLAYER_TWO_ID);
        vm.expectRevert("Gas price too high");
        game.acceptChallenge(challengeId, defenderLoadout);
        vm.stopPrank();

        // Verify challenge is still active (not accepted)
        assertTrue(game.isChallengeActive(challengeId), "Challenge should still be active after failed acceptance");
    }

    function testAcceptChallengeWithGasProtectionDisabled() public {
        // Disable gas protection
        vm.prank(game.owner());
        game.setGasProtectionEnabled(false);

        // Create challenge
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // Accept challenge with high gas (should work when protection disabled)
        vm.startPrank(PLAYER_TWO);
        vm.txGasPrice(500000000); // 0.5 gwei - very high but should work
        game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        // Verify challenge is now pending
        assertTrue(game.isChallengePending(challengeId), "Challenge should be pending when gas protection disabled");
    }

    function testGasProtectionAtExactLimit() public {
        // Create challenge
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // Accept challenge at exact gas limit (should work)
        vm.startPrank(PLAYER_TWO);
        vm.txGasPrice(100000000); // Set gas price to exactly 0.1 gwei
        game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        // Verify challenge is now pending
        assertTrue(game.isChallengePending(challengeId), "Challenge should be pending at exact gas limit");
    }

    function testGasProtectionOnlyAppliesToAccept() public {
        // Verify gas protection doesn't affect challenge creation
        vm.startPrank(PLAYER_ONE);
        vm.txGasPrice(500000000); // 0.5 gwei - very high

        // Both initiate functions should work regardless of gas price
        uint256 challengeId1 = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        uint256 challengeId2 =
            game.initiateChallengeWithETH{value: 0.0001 ether}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);

        vm.stopPrank();

        // Verify both challenges were created
        assertTrue(game.isChallengeActive(challengeId1), "Ticket challenge should be created regardless of gas");
        assertTrue(game.isChallengeActive(challengeId2), "ETH challenge should be created regardless of gas");
    }

    function testDynamicGasLimitUpdates() public {
        // Create challenge
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallengeWithTicket(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // First try to accept at 0.15 gwei (above default 0.1 gwei limit)
        vm.startPrank(PLAYER_TWO);
        vm.txGasPrice(150000000); // Set gas price to 0.15 gwei
        Fighter.PlayerLoadout memory defenderLoadout = _createLoadout(PLAYER_TWO_ID);
        vm.expectRevert("Gas price too high");
        game.acceptChallenge(challengeId, defenderLoadout);
        vm.stopPrank();

        // Owner increases gas limit to 0.2 gwei
        vm.prank(game.owner());
        game.setMaxAcceptGasPrice(200000000);

        // Now the same gas price should work
        vm.startPrank(PLAYER_TWO);
        vm.txGasPrice(150000000); // Same gas price, now under new limit
        defenderLoadout = _createLoadout(PLAYER_TWO_ID);
        game.acceptChallenge(challengeId, defenderLoadout);
        vm.stopPrank();

        // Verify challenge is now pending
        assertTrue(game.isChallengePending(challengeId), "Challenge should be pending after gas limit increase");
    }

    receive() external payable {}
}

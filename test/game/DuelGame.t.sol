// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {DuelGame} from "../../src/game/modes/DuelGame.sol";
import {Player} from "../../src/fighters/Player.sol";
import {GameEngine} from "../../src/game/engine/GameEngine.sol";
import {IPlayerSkinRegistry} from "../../src/interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";
import {DefaultPlayerSkinNFT} from "../../src/nft/skins/DefaultPlayerSkinNFT.sol";
import {PlayerNameRegistry} from "../../src/fighters/registries/names/PlayerNameRegistry.sol";
import {PlayerSkinNFT} from "../../src/nft/skins/PlayerSkinNFT.sol";
import {UnlockNFT} from "../mocks/UnlockNFT.sol";
import "../TestBase.sol";
import {IGameEngine} from "../../src/interfaces/game/engine/IGameEngine.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";

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
        uint8 challengerStance
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
    uint256 indexed challengeId, uint32 indexed winnerId, uint256 randomness);
    event ChallengeRecovered(uint256 indexed challengeId);

    function setUp() public override {
        super.setUp();

        game = new DuelGame(address(gameEngine), address(playerContract), operator);

        // Set permissions for game contract
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, attributes: false, immortal: false, experience: false});
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
    }

    function testInitialState() public view {
        assertEq(address(game.gameEngine()), address(gameEngine));
        assertEq(address(game.playerContract()), address(playerContract));
        assertEq(game.nextChallengeId(), 0);
    }

    function testCreateChallenge() public {
        vm.startPrank(PLAYER_ONE);

        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        vm.expectEmit(true, true, true, true);
        emit ChallengeCreated(
            0, PLAYER_ONE_ID, PLAYER_TWO_ID, loadout.skin.skinIndex, loadout.skin.skinTokenId, loadout.stance
        );

        uint256 challengeId = game.initiateChallenge(loadout, PLAYER_TWO_ID);

        assertEq(challengeId, 0);
        (uint32 challengerId, uint32 defenderId,,,,,, DuelGame.ChallengeState state) = game.challenges(challengeId);
        assertEq(challengerId, PLAYER_ONE_ID);
        assertEq(defenderId, PLAYER_TWO_ID);
        assertTrue(state == DuelGame.ChallengeState.OPEN);
        vm.stopPrank();
    }

    function testAcceptChallenge() public {
        // First create a challenge
        vm.startPrank(PLAYER_ONE);

        uint256 challengeId = game.initiateChallenge(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank(); // Stop PLAYER_ONE prank before starting PLAYER_TWO

        // Accept challenge as player two
        vm.startPrank(PLAYER_TWO);
        vm.recordLogs();
        game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID));

        // Decode VRF event and prepare fulfillment data
        (uint256 roundId,) = _decodeVRFRequestEvent(vm.getRecordedLogs());
        bytes memory dataWithRound = _simulateVRFFulfillment(0, roundId);
        vm.stopPrank(); // Stop PLAYER_TWO prank before fulfilling VRF

        // Fulfill VRF with the exact data from the event
        vm.stopPrank(); // Stop any active pranks before fulfilling VRF
        vm.prank(operator);
        game.fulfillRandomness(0, dataWithRound);

        // Get loadouts from challenge
        (,,,,, Fighter.PlayerLoadout memory challengerLoadout, Fighter.PlayerLoadout memory defenderLoadout,) =
            game.challenges(challengeId);

        // Get the appropriate Fighter contracts
        Fighter challengerFighter = _getFighterContract(challengerLoadout.playerId);
        Fighter defenderFighter = _getFighterContract(defenderLoadout.playerId);

        // Process game using Fighter contract conversions
        bytes memory results = gameEngine.processGame(
            challengerFighter.convertToFighterStats(challengerLoadout),
            defenderFighter.convertToFighterStats(defenderLoadout),
            0,
            0
        );

        (, uint16 version, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);

        // Verify challenge completed successfully
        (,,,,,,, DuelGame.ChallengeState finalState) = game.challenges(challengeId);
        assertTrue(finalState == DuelGame.ChallengeState.COMPLETED, "Challenge should be completed");
    }

    function testCancelExpiredChallenge() public {
        vm.startPrank(PLAYER_ONE);

        // Get challenger's address
        address challenger = playerContract.getPlayerOwner(PLAYER_ONE_ID);
        require(challenger == PLAYER_ONE, "Player one should own their player");

        // Create a challenge
        uint256 challengeId = game.initiateChallenge(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);

        // Warp to after expiry - using timestamps now instead of blocks
        vm.warp(block.timestamp + game.timeUntilExpire() + 1);

        // Cancel the challenge
        game.cancelChallenge(challengeId);

        // Verify challenge state
        (,,,,,,, DuelGame.ChallengeState state) = game.challenges(challengeId);
        assertTrue(state == DuelGame.ChallengeState.COMPLETED);
        vm.stopPrank();
    }

    function testCompleteDuel() public {
        vm.startPrank(PLAYER_ONE);

        uint256 challengeId = game.initiateChallenge(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank(); // Stop PLAYER_ONE prank before starting PLAYER_TWO

        // Accept challenge as player two
        vm.startPrank(PLAYER_TWO);
        vm.recordLogs();
        game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID));

        // Decode VRF event and prepare fulfillment data
        (uint256 roundId,) = _decodeVRFRequestEvent(vm.getRecordedLogs());
        bytes memory dataWithRound = _simulateVRFFulfillment(0, roundId);
        vm.stopPrank(); // Stop PLAYER_TWO prank before fulfilling VRF

        // Fulfill VRF with the exact data from the event
        vm.stopPrank(); // Stop any active pranks before fulfilling VRF
        vm.prank(operator);
        game.fulfillRandomness(0, dataWithRound);

        // Get loadouts from challenge
        (,,,,, Fighter.PlayerLoadout memory challengerLoadout, Fighter.PlayerLoadout memory defenderLoadout,) =
            game.challenges(challengeId);

        // Get the appropriate Fighter contracts
        Fighter challengerFighter = _getFighterContract(challengerLoadout.playerId);
        Fighter defenderFighter = _getFighterContract(defenderLoadout.playerId);

        // Process game using Fighter contract conversions
        bytes memory results = gameEngine.processGame(
            challengerFighter.convertToFighterStats(challengerLoadout),
            defenderFighter.convertToFighterStats(defenderLoadout),
            0,
            0
        );

        (, uint16 version, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);

        // Verify challenge completed successfully
        (,,,,,,, DuelGame.ChallengeState finalState) = game.challenges(challengeId);
        assertTrue(finalState == DuelGame.ChallengeState.COMPLETED, "Challenge should be completed");
    }

    function test_RevertWhen_UsingDefaultCharacter() public {
        vm.startPrank(PLAYER_ONE);

        Fighter.PlayerLoadout memory loadout =
            Fighter.PlayerLoadout({playerId: 999, skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}), stance: 1});

        vm.expectRevert("Unsupported player ID for Duel mode");
        game.initiateChallenge(loadout, PLAYER_TWO_ID);
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
        uint256 challengeId = game.initiateChallenge(loadout, PLAYER_TWO_ID);
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
        vm.expectRevert("UNAUTHORIZED");
        game.setGameEnabled(false);

        // Owner can disable
        vm.startPrank(game.owner());
        game.setGameEnabled(false);
        assertFalse(game.isGameEnabled(), "Game should be disabled");

        vm.startPrank(PLAYER_ONE);
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);
        vm.expectRevert("Game is disabled");
        game.initiateChallenge(loadout, PLAYER_TWO_ID);
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
        uint256 challengeId = game.initiateChallenge(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // 1. Test initial state
        assertTrue(game.isChallengeActive(challengeId), "Challenge should be active initially");
        assertFalse(game.isChallengePending(challengeId), "Challenge should not be pending initially");
        assertFalse(game.isChallengeCompleted(challengeId), "Challenge should not be completed initially");
        assertFalse(game.isChallengeExpired(challengeId), "Challenge should not be expired initially");

        // 2. Create a second challenge to test acceptance
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId2 = game.initiateChallenge(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
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
        (uint256 roundId,) = _decodeVRFRequestEvent(vm.getRecordedLogs());
        bytes memory dataWithRound = _simulateVRFFulfillment(0, roundId);

        vm.prank(operator);
        game.fulfillRandomness(0, dataWithRound);

        // Test completed state
        assertFalse(game.isChallengeActive(challengeId2), "Challenge should not be active after completion");
        assertFalse(game.isChallengePending(challengeId2), "Challenge should not be pending after completion");
        assertTrue(game.isChallengeCompleted(challengeId2), "Challenge should be completed after fulfillment");
    }

    function test_RevertWhen_AcceptingExpiredChallenge() public {
        // Create a challenge
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallenge(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
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
        } catch (bytes memory) /*lowLevelData*/ {
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
            attributes: false,
            immortal: false,
            experience: false
        });
        playerContract.setGameContractPermission(address(this), perms);

        // Create a challenge
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallenge(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        // Accept the challenge
        vm.startPrank(PLAYER_TWO);
        vm.recordLogs();
        game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID));
        (uint256 roundId,) = _decodeVRFRequestEvent(vm.getRecordedLogs());
        bytes memory dataWithRound = _simulateVRFFulfillment(0, roundId);
        vm.stopPrank();

        // Retire the player with our permission
        // Using the test contract (this) since it has permissions
        playerContract.setPlayerRetired(PLAYER_ONE_ID, true);

        // Fulfillment should revert
        vm.prank(operator);
        vm.expectRevert(bytes("Challenger is retired"));
        game.fulfillRandomness(0, dataWithRound);
    }

    function test_RevertWhen_ChallengerRetiredBeforeAcceptance() public {
        // Create a challenge
        vm.startPrank(PLAYER_ONE);
        uint256 challengeId = game.initiateChallenge(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);

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
        uint256 challengeId = game.initiateChallenge(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
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
        uint256 challengeId = game.initiateChallenge(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
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
        uint256 challengeId = game.initiateChallenge(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID);
        vm.stopPrank();

        vm.startPrank(PLAYER_TWO);
        game.acceptChallenge(challengeId, _createLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        // Try to recover before timeout
        vm.prank(PLAYER_ONE);
        vm.expectRevert("VRF timeout not reached");
        game.recoverTimedOutVRF(challengeId);
    }

    receive() external payable {}
}

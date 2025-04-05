// SPDX-License-Identifier: UNLICENSED
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
        uint256 wagerAmount,
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
        uint256 indexed challengeId,
        uint32 indexed winnerId,
        uint256 randomness,
        uint256 winnerPayout,
        uint256 feeCollected
    );
    event MinDuelFeeUpdated(uint256 oldFee, uint256 newFee);
    event ChallengeForfeited(uint256 indexed challengeId, uint256 amount);
    event ChallengeRecovered(uint256 indexed challengeId, uint256 challengerRefund, uint256 defenderRefund);

    function setUp() public override {
        super.setUp();

        game = new DuelGame(address(gameEngine), address(playerContract), operator);

        // Set permissions for game contract
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, name: false, attributes: false, immortal: false});
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

    function testInitialState() public {
        assertEq(address(game.gameEngine()), address(gameEngine));
        assertEq(address(game.playerContract()), address(playerContract));
        assertEq(game.nextChallengeId(), 0);
        assertEq(game.totalFeesCollected(), 0);
    }

    function testCreateChallenge() public {
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;

        uint256 totalAmount = wagerAmount + game.minDuelFee();

        // Give enough ETH to cover wager + fee
        vm.deal(PLAYER_ONE, totalAmount);

        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        vm.expectEmit(true, true, true, true);
        emit ChallengeCreated(
            0,
            PLAYER_ONE_ID,
            PLAYER_TWO_ID,
            wagerAmount,
            loadout.skin.skinIndex,
            loadout.skin.skinTokenId,
            loadout.stance
        );

        uint256 challengeId = game.initiateChallenge{value: totalAmount}(loadout, PLAYER_TWO_ID, wagerAmount);

        assertEq(challengeId, 0);
        (
            uint32 challengerId,
            uint32 defenderId,
            uint256 storedWager,
            uint256 createdBlock,
            uint256 createdTimestamp,
            uint256 vrfRequestTimestamp,
            Fighter.PlayerLoadout memory challengerLoadout,
            Fighter.PlayerLoadout memory defenderLoadout,
            DuelGame.ChallengeState state
        ) = game.challenges(challengeId);
        assertEq(challengerId, PLAYER_ONE_ID);
        assertEq(defenderId, PLAYER_TWO_ID);
        assertEq(storedWager, wagerAmount);
        assertTrue(state == DuelGame.ChallengeState.OPEN);
        vm.stopPrank();
    }

    function testAcceptChallenge() public {
        // First create a challenge
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;

        // Calculate fee based on wager amount
        uint256 fee = (((wagerAmount * 2) * game.wagerFeePercentage()) / 10000) + game.minDuelFee();
        uint256 totalAmount = wagerAmount + game.minDuelFee();

        // Give enough ETH to cover wager + fee
        vm.deal(PLAYER_ONE, totalAmount);

        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank(); // Stop PLAYER_ONE prank before starting PLAYER_TWO

        // Give enough ETH to PLAYER_TWO to cover wager
        vm.deal(PLAYER_TWO, wagerAmount);

        // Accept challenge as player two
        vm.startPrank(PLAYER_TWO);
        vm.recordLogs();
        game.acceptChallenge{value: wagerAmount}(challengeId, _createLoadout(PLAYER_TWO_ID));

        // Decode VRF event and prepare fulfillment data
        (uint256 roundId, bytes memory eventData) = _decodeVRFRequestEvent(vm.getRecordedLogs());
        bytes memory dataWithRound = _simulateVRFFulfillment(0, roundId);
        vm.stopPrank(); // Stop PLAYER_TWO prank before fulfilling VRF

        // Get the challenger and defender IDs
        (uint32 challengerId, uint32 defenderId,,,,,,, DuelGame.ChallengeState state) = game.challenges(challengeId);

        // Fulfill VRF with the exact data from the event
        vm.stopPrank(); // Stop any active pranks before fulfilling VRF
        vm.prank(operator);
        game.fulfillRandomness(0, dataWithRound);

        // Get loadouts from challenge
        (
            ,
            ,
            ,
            ,
            ,
            uint256 vrfRequestTime,
            Fighter.PlayerLoadout memory challengerLoadout,
            Fighter.PlayerLoadout memory defenderLoadout,
        ) = game.challenges(challengeId);

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

        (bool player1Won, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);

        console2.log("totalFeesCollected", game.totalFeesCollected());
        console2.log("fee", fee);
        assertTrue(game.totalFeesCollected() == fee, "Fees should be collected");
    }

    function testCancelExpiredChallenge() public {
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;

        uint256 totalAmount = wagerAmount + game.minDuelFee();

        // Give enough ETH to cover wager + fee
        vm.deal(PLAYER_ONE, totalAmount);

        // Get challenger's address
        address challenger = playerContract.getPlayerOwner(PLAYER_ONE_ID);
        require(challenger == PLAYER_ONE, "Player one should own their player");

        // Create a challenge
        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);

        // Warp to after expiry - using timestamps now instead of blocks
        vm.warp(block.timestamp + game.timeUntilExpire() + 1);

        // Record balance before cancellation
        uint256 balanceBefore = address(PLAYER_ONE).balance;

        // Cancel the challenge
        game.cancelChallenge(challengeId);

        // Record balance after cancellation
        uint256 balanceAfter = address(PLAYER_ONE).balance;

        // Expect FULL refund (wager + fee)
        uint256 expectedRefund = wagerAmount + game.minDuelFee();

        assertEq(balanceAfter - balanceBefore, expectedRefund, "Should refund full amount (wager + fee)");

        // Verify challenge state
        (,,,,,,,, DuelGame.ChallengeState state) = game.challenges(challengeId);
        assertTrue(state == DuelGame.ChallengeState.COMPLETED);
        vm.stopPrank();
    }

    function testCompleteDuel() public {
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;

        // Calculate fee based on wager amount
        uint256 fee = (((wagerAmount * 2) * game.wagerFeePercentage()) / 10000) + game.minDuelFee();
        uint256 totalAmount = wagerAmount + game.minDuelFee();

        // Give enough ETH to cover wager + fee
        vm.deal(PLAYER_ONE, totalAmount);

        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank(); // Stop PLAYER_ONE prank before starting PLAYER_TWO

        // Give enough ETH to PLAYER_TWO to cover wager
        vm.deal(PLAYER_TWO, wagerAmount);

        // Accept challenge as player two
        vm.startPrank(PLAYER_TWO);
        vm.recordLogs();
        game.acceptChallenge{value: wagerAmount}(challengeId, _createLoadout(PLAYER_TWO_ID));

        // Decode VRF event and prepare fulfillment data
        (uint256 roundId, bytes memory eventData) = _decodeVRFRequestEvent(vm.getRecordedLogs());
        bytes memory dataWithRound = _simulateVRFFulfillment(0, roundId);
        vm.stopPrank(); // Stop PLAYER_TWO prank before fulfilling VRF

        // Get the challenger and defender IDs
        (uint32 challengerId, uint32 defenderId,,,,,,, DuelGame.ChallengeState state) = game.challenges(challengeId);

        // Fulfill VRF with the exact data from the event
        vm.stopPrank(); // Stop any active pranks before fulfilling VRF
        vm.prank(operator);
        game.fulfillRandomness(0, dataWithRound);

        // Get loadouts from challenge
        (
            ,
            ,
            ,
            ,
            ,
            uint256 vrfRequestTime,
            Fighter.PlayerLoadout memory challengerLoadout,
            Fighter.PlayerLoadout memory defenderLoadout,
        ) = game.challenges(challengeId);

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

        (bool player1Won, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);

        assertTrue(game.totalFeesCollected() == fee, "Fees should be collected");
    }

    function testForceCloseAbandonedChallenge() public {
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;

        // Calculate fee based on wager amount
        uint256 fee = wagerAmount + game.minDuelFee();
        uint256 totalAmount = wagerAmount + game.minDuelFee();

        // Give enough ETH to cover wager + fee
        vm.deal(PLAYER_ONE, totalAmount);

        // Get challenger's address
        address challenger = playerContract.getPlayerOwner(PLAYER_ONE_ID);
        require(challenger == PLAYER_ONE, "Player one should own their player");

        // Create a challenge
        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);

        // Warp to after withdrawal period - using timestamps now instead of blocks
        vm.warp(block.timestamp + game.timeUntilWithdraw() + 1);

        // Force close the challenge as owner
        vm.stopPrank();
        vm.startPrank(game.owner());
        game.forceCloseAbandonedChallenge(challengeId);
        vm.stopPrank();

        // Verify challenge state
        (,,,,,,,, DuelGame.ChallengeState state) = game.challenges(challengeId);
        assertTrue(state == DuelGame.ChallengeState.COMPLETED);
        vm.stopPrank();
    }

    function test_RevertWhen_InsufficientFunds() public {
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        vm.deal(PLAYER_ONE, wagerAmount);
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        vm.expectRevert(bytes("Incorrect ETH amount sent"));
        game.initiateChallenge{value: wagerAmount - 0.1 ether}(loadout, PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();
    }

    function test_RevertWhen_UsingDefaultCharacter() public {
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        vm.deal(PLAYER_ONE, wagerAmount);

        Fighter.PlayerLoadout memory loadout =
            Fighter.PlayerLoadout({playerId: 999, skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}), stance: 1});

        vm.expectRevert("Unsupported player ID for Duel mode");
        game.initiateChallenge{value: wagerAmount}(loadout, PLAYER_TWO_ID, wagerAmount);
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
        uint256 wagerAmount = 1 ether;
        vm.deal(PLAYER_ONE, wagerAmount + game.minDuelFee());

        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);
        uint256 challengeId =
            game.initiateChallenge{value: wagerAmount + game.minDuelFee()}(loadout, PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();

        // Try to accept with wrong defender
        vm.startPrank(PLAYER_ONE);
        vm.deal(PLAYER_ONE, wagerAmount);
        Fighter.PlayerLoadout memory defenderLoadout = _createLoadout(PLAYER_TWO_ID);

        vm.expectRevert(bytes("Not defender"));
        game.acceptChallenge{value: wagerAmount}(challengeId, defenderLoadout);
        vm.stopPrank();
    }

    function testUpdateMinDuelFee() public {
        uint256 newFee = 0.001 ether;
        vm.startPrank(game.owner());
        vm.expectEmit(true, true, false, false);
        emit MinDuelFeeUpdated(game.minDuelFee(), newFee);

        game.setMinDuelFee(newFee);
        assertEq(game.minDuelFee(), newFee);
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

        // Give PLAYER_ONE some ETH
        vm.deal(PLAYER_ONE, 100 ether);
        uint256 wagerAmount = 1 ether;

        vm.startPrank(PLAYER_ONE);
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);
        vm.expectRevert("Game is disabled");
        game.initiateChallenge{value: wagerAmount}(loadout, PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();

        // Owner can re-enable
        vm.startPrank(game.owner());
        game.setGameEnabled(true);
        assertTrue(game.isGameEnabled(), "Game should be re-enabled");
        vm.stopPrank();
    }

    function testWithdrawFees() public {
        // First complete a duel to collect some fees
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;

        // Calculate fee based on wager amount
        uint256 fee = (((wagerAmount * 2) * game.wagerFeePercentage()) / 10000) + game.minDuelFee();
        uint256 totalAmount = wagerAmount + game.minDuelFee();

        vm.deal(PLAYER_ONE, wagerAmount + game.minDuelFee());
        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();

        vm.deal(PLAYER_TWO, wagerAmount);
        vm.startPrank(PLAYER_TWO);
        vm.recordLogs();
        game.acceptChallenge{value: wagerAmount}(challengeId, _createLoadout(PLAYER_TWO_ID));

        (uint256 roundId, bytes memory eventData) = _decodeVRFRequestEvent(vm.getRecordedLogs());
        bytes memory dataWithRound = _simulateVRFFulfillment(0, roundId);
        vm.stopPrank();

        vm.prank(operator);
        game.fulfillRandomness(0, dataWithRound);

        // Verify fees were collected
        uint256 collectedFees = game.totalFeesCollected();
        assertTrue(collectedFees == fee, "Fees should be collected");

        // Store initial balances
        uint256 initialContractBalance = address(game).balance;
        uint256 initialOwnerBalance = address(game.owner()).balance;

        // Withdraw fees as owner
        vm.prank(game.owner());
        game.withdrawFees();

        // Verify balances after withdrawal
        assertEq(game.totalFeesCollected(), 0, "Fees should be 0 after withdrawal");
        assertEq(
            address(game).balance, initialContractBalance - collectedFees, "Contract balance should be reduced by fees"
        );
        assertEq(
            address(game.owner()).balance, initialOwnerBalance + collectedFees, "Owner should receive collected fees"
        );
    }

    function testCancelZeroWagerChallenge() public {
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 0; // Zero wager

        uint256 totalAmount = wagerAmount + game.minDuelFee(); // Just the minDuelFee

        // Give enough ETH to cover just the fee
        vm.deal(PLAYER_ONE, totalAmount);

        // Get challenger's address
        address challenger = playerContract.getPlayerOwner(PLAYER_ONE_ID);
        require(challenger == PLAYER_ONE, "Player one should own their player");

        // Create a challenge with zero wager
        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);

        // Record balance before cancellation
        uint256 balanceBefore = address(PLAYER_ONE).balance;

        // Cancel the challenge
        game.cancelChallenge(challengeId);

        // Record balance after cancellation
        uint256 balanceAfter = address(PLAYER_ONE).balance;

        // Expect FULL refund of minDuelFee (since wager is 0)
        uint256 expectedRefund = game.minDuelFee();

        assertEq(balanceAfter - balanceBefore, expectedRefund, "Should refund minDuelFee for zero-wager challenge");

        // Verify challenge state
        (,,,,,,,, DuelGame.ChallengeState state) = game.challenges(challengeId);
        assertTrue(state == DuelGame.ChallengeState.COMPLETED);
        vm.stopPrank();
    }

    function testWagerToggle() public {
        // Verify wagers start enabled
        assertTrue(game.wagersEnabled(), "Wagers should start enabled");

        // Verify non-owner can't toggle wager setting
        vm.prank(PLAYER_ONE);
        vm.expectRevert("UNAUTHORIZED");
        game.setWagersEnabled(false);

        // Owner can disable wagers
        vm.startPrank(game.owner());
        game.setWagersEnabled(false);
        assertFalse(game.wagersEnabled(), "Wagers should be disabled");
        vm.stopPrank();

        // Test with wagers disabled - creating challenge with wager should fail
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        uint256 totalAmount = wagerAmount + game.minDuelFee();

        // Give enough ETH to cover wager + fee
        vm.deal(PLAYER_ONE, totalAmount);

        // Try to create a challenge with wager - should fail
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);
        vm.expectRevert("Wagers are disabled");
        game.initiateChallenge{value: totalAmount}(loadout, PLAYER_TWO_ID, wagerAmount);

        // But creating a zero-wager challenge should still work
        uint256 challengeId = game.initiateChallenge{value: game.minDuelFee()}(loadout, PLAYER_TWO_ID, 0);
        assertEq(challengeId, 0, "Zero-wager challenge should be created");
        vm.stopPrank();

        // Owner can re-enable wagers
        vm.startPrank(game.owner());
        game.setWagersEnabled(true);
        assertTrue(game.wagersEnabled(), "Wagers should be re-enabled");
        vm.stopPrank();

        // After re-enabling, creating challenge with wager should work again
        vm.startPrank(PLAYER_ONE);
        // Cancel previous challenge to keep test clean
        game.cancelChallenge(0);

        // Create new challenge with wager
        uint256 newChallengeId = game.initiateChallenge{value: totalAmount}(loadout, PLAYER_TWO_ID, wagerAmount);
        assertEq(newChallengeId, 1, "Wager challenge should be created after re-enabling");
        vm.stopPrank();
    }

    function testHelperFunctions() public {
        // Create a challenge
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        uint256 totalAmount = wagerAmount + game.minDuelFee();
        vm.deal(PLAYER_ONE, totalAmount);
        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();

        // 1. Test initial state
        assertTrue(game.isChallengeActive(challengeId), "Challenge should be active initially");
        assertFalse(game.isChallengePending(challengeId), "Challenge should not be pending initially");
        assertFalse(game.isChallengeCompleted(challengeId), "Challenge should not be completed initially");
        assertFalse(game.isChallengeExpired(challengeId), "Challenge should not be expired initially");

        // 2. Create a second challenge to test acceptance
        vm.startPrank(PLAYER_ONE);
        uint256 totalAmount2 = wagerAmount + game.minDuelFee();
        vm.deal(PLAYER_ONE, totalAmount2);
        uint256 challengeId2 =
            game.initiateChallenge{value: totalAmount2}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();

        // 3. Accept the second challenge and test pending state
        vm.startPrank(PLAYER_TWO);
        vm.deal(PLAYER_TWO, wagerAmount);
        vm.recordLogs();
        game.acceptChallenge{value: wagerAmount}(challengeId2, _createLoadout(PLAYER_TWO_ID));
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
        (uint256 roundId, bytes memory eventData) = _decodeVRFRequestEvent(vm.getRecordedLogs());
        bytes memory dataWithRound = _simulateVRFFulfillment(0, roundId);

        vm.prank(operator);
        game.fulfillRandomness(0, dataWithRound);

        // Test completed state
        assertFalse(game.isChallengeActive(challengeId2), "Challenge should not be active after completion");
        assertFalse(game.isChallengePending(challengeId2), "Challenge should not be pending after completion");
        assertTrue(game.isChallengeCompleted(challengeId2), "Challenge should be completed after fulfillment");
    }

    function testFeeCalculation() public {
        // Test zero wager
        uint256 fee = game.calculateFee(0);
        assertEq(fee, game.minDuelFee(), "Zero wager should have minDuelFee");

        // Test below minimum wager
        fee = game.calculateFee(game.minWagerAmount() - 1);
        assertEq(fee, game.minDuelFee(), "Below min wager should have minDuelFee");

        // Test at minimum wager
        fee = game.calculateFee(game.minWagerAmount());
        uint256 expectedFee = ((game.minWagerAmount() * game.wagerFeePercentage()) / 10000) + game.minDuelFee();
        assertEq(fee, expectedFee, "Fee calculation incorrect at min wager");

        // Test larger wager
        uint256 largeWager = 10 ether;
        fee = game.calculateFee(largeWager);
        expectedFee = ((largeWager * game.wagerFeePercentage()) / 10000) + game.minDuelFee();
        assertEq(fee, expectedFee, "Fee calculation incorrect for large wager");
    }

    function test_RevertWhen_AcceptingExpiredChallenge() public {
        // Create a challenge
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        uint256 totalAmount = wagerAmount + game.minDuelFee();
        vm.deal(PLAYER_ONE, totalAmount);
        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();

        // Get current challenge state
        (,, uint256 storedWager, uint256 createdBlock, uint256 createdTimestamp,,,, DuelGame.ChallengeState state) =
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
        vm.deal(PLAYER_TWO, wagerAmount);

        // Don't use expectRevert here, instead try/catch to see what happens
        bool didRevert = false;
        try game.acceptChallenge{value: wagerAmount}(challengeId, _createLoadout(PLAYER_TWO_ID)) {
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
            name: false,
            attributes: false,
            immortal: false
        });
        playerContract.setGameContractPermission(address(this), perms);

        // Create a challenge
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        uint256 totalAmount = wagerAmount + game.minDuelFee();
        vm.deal(PLAYER_ONE, totalAmount);
        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();

        // Accept the challenge
        vm.startPrank(PLAYER_TWO);
        vm.deal(PLAYER_TWO, wagerAmount);
        vm.recordLogs();
        game.acceptChallenge{value: wagerAmount}(challengeId, _createLoadout(PLAYER_TWO_ID));
        (uint256 roundId, bytes memory eventData) = _decodeVRFRequestEvent(vm.getRecordedLogs());
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
        uint256 wagerAmount = 1 ether;
        uint256 totalAmount = wagerAmount + game.minDuelFee();
        vm.deal(PLAYER_ONE, totalAmount);
        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);

        // Retire the challenger's player using the player's own method
        playerContract.retireOwnPlayer(PLAYER_ONE_ID);

        // Verify retirement was successful
        assertTrue(playerContract.isPlayerRetired(PLAYER_ONE_ID), "Player not retired");
        vm.stopPrank();

        // Try to accept the challenge - should revert due to retired challenger
        vm.startPrank(PLAYER_TWO);
        vm.deal(PLAYER_TWO, wagerAmount);

        // Create the loadout FIRST, outside the expectRevert scope
        Fighter.PlayerLoadout memory defenderLoadout = _createLoadout(PLAYER_TWO_ID);

        // Now expect the revert on just the acceptChallenge call
        vm.expectRevert("Challenger is retired");
        game.acceptChallenge{value: wagerAmount}(challengeId, defenderLoadout);

        vm.stopPrank();
    }

    function testRecoverTimedOutVRF() public {
        // Step 1: Create a challenge
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        uint256 totalAmount = wagerAmount + game.minDuelFee();

        // Give enough ETH to cover wager + fee
        vm.deal(PLAYER_ONE, totalAmount);

        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();

        // Step 2: Accept the challenge as PLAYER_TWO to make it PENDING
        vm.startPrank(PLAYER_TWO);
        vm.deal(PLAYER_TWO, wagerAmount);
        vm.recordLogs();
        game.acceptChallenge{value: wagerAmount}(challengeId, _createLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        // Verify challenge is in PENDING state
        assertTrue(game.isChallengePending(challengeId), "Challenge should be pending after acceptance");

        // Step 3: Fast forward time past VRF timeout
        vm.warp(block.timestamp + game.vrfRequestTimeout() + 1);

        // Record balances before recovery
        address challenger = playerContract.getPlayerOwner(PLAYER_ONE_ID);
        address defender = playerContract.getPlayerOwner(PLAYER_TWO_ID);
        uint256 challengerBalanceBefore = address(challenger).balance;
        uint256 defenderBalanceBefore = address(defender).balance;

        // Step 4: Call recoverTimedOutVRF as challenger
        vm.startPrank(PLAYER_ONE);
        vm.expectEmit(true, true, false, true);
        emit ChallengeRecovered(challengeId, wagerAmount + game.minDuelFee(), wagerAmount);
        game.recoverTimedOutVRF(challengeId);
        vm.stopPrank();

        // Step 5: Verify results
        // Challenge should be completed
        assertTrue(game.isChallengeCompleted(challengeId), "Challenge should be completed after recovery");

        // Verify refunds
        uint256 challengerRefund = wagerAmount + game.minDuelFee();
        uint256 defenderRefund = wagerAmount;

        assertEq(
            address(challenger).balance - challengerBalanceBefore,
            challengerRefund,
            "Challenger should receive wager + fee back"
        );
        assertEq(
            address(defender).balance - defenderBalanceBefore, defenderRefund, "Defender should receive wager back"
        );
    }

    function testRevertWhen_RecoverTimedOutVRF_NotAuthorized() public {
        // Create and accept challenge like in previous test
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        uint256 totalAmount = wagerAmount + game.minDuelFee();
        vm.deal(PLAYER_ONE, totalAmount);
        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();

        vm.startPrank(PLAYER_TWO);
        vm.deal(PLAYER_TWO, wagerAmount);
        game.acceptChallenge{value: wagerAmount}(challengeId, _createLoadout(PLAYER_TWO_ID));
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
        uint256 wagerAmount = 1 ether;
        uint256 totalAmount = wagerAmount + game.minDuelFee();
        vm.deal(PLAYER_ONE, totalAmount);
        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();

        vm.startPrank(PLAYER_TWO);
        vm.deal(PLAYER_TWO, wagerAmount);
        game.acceptChallenge{value: wagerAmount}(challengeId, _createLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        // Try to recover before timeout
        vm.prank(PLAYER_ONE);
        vm.expectRevert("VRF timeout not reached");
        game.recoverTimedOutVRF(challengeId);
    }

    receive() external payable {}
}

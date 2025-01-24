// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {DuelGame} from "../src/DuelGame.sol";
import {Player} from "../src/Player.sol";
import {GameEngine} from "../src/GameEngine.sol";
import {PlayerSkinRegistry} from "../src/PlayerSkinRegistry.sol";
import {DefaultPlayerSkinNFT} from "../src/DefaultPlayerSkinNFT.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";
import {PlayerSkinNFT} from "../src/examples/PlayerSkinNFT.sol";
import {IGameDefinitions} from "../src/interfaces/IGameDefinitions.sol";
import {UnlockNFT} from "./mocks/UnlockNFT.sol";
import "./utils/TestBase.sol";

contract DuelGameTest is TestBase {
    DuelGame public game;
    GameEngine public gameEngine;

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
        uint256 createdAtBlock
    );
    event ChallengeAccepted(uint256 indexed challengeId, uint32 defenderId);
    event ChallengeCancelled(uint256 indexed challengeId);
    event DuelComplete(
        uint256 indexed challengeId, uint32 indexed winnerId, uint32 indexed loserId, uint256 winnerPrize
    );
    event MinDuelFeeUpdated(uint256 oldFee, uint256 newFee);
    event ChallengeForfeited(uint256 indexed challengeId, uint256 amount);

    function setUp() public override {
        super.setUp();

        // Set up the test environment with a proper timestamp
        vm.warp(1692803367 + 1000); // Set timestamp to after genesis

        // Deploy contracts in correct order
        vm.startPrank(operator);
        gameEngine = new GameEngine();
        game = new DuelGame(address(gameEngine), address(playerContract), operator);
        vm.stopPrank();

        // Set permissions for game contract
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, name: false, attributes: false});
        Player(address(playerContract)).setGameContractPermission(address(game), perms);

        // Setup test addresses
        PLAYER_ONE = address(0xdF);
        PLAYER_TWO = address(0xeF);

        // Create actual players using VRF
        PLAYER_ONE_ID = _createPlayerAndFulfillVRF(PLAYER_ONE, Player(address(playerContract)), false);
        PLAYER_TWO_ID = _createPlayerAndFulfillVRF(PLAYER_TWO, Player(address(playerContract)), false);

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

        // Calculate fee based on wager amount
        uint256 fee = (wagerAmount * game.wagerFeePercentage()) / 10000;
        uint256 totalAmount = wagerAmount;

        // Give enough ETH to cover wager + fee
        vm.deal(PLAYER_ONE, totalAmount);

        IGameEngine.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        vm.expectEmit(true, true, true, true);
        emit ChallengeCreated(0, PLAYER_ONE_ID, PLAYER_TWO_ID, wagerAmount, block.number);

        uint256 challengeId = game.initiateChallenge{value: totalAmount}(loadout, PLAYER_TWO_ID, wagerAmount);

        assertEq(challengeId, 0);
        (uint32 challengerId, uint32 defenderId, uint256 storedWager,,,, bool fulfilled) = game.challenges(challengeId);
        assertEq(challengerId, PLAYER_ONE_ID);
        assertEq(defenderId, PLAYER_TWO_ID);
        assertEq(storedWager, wagerAmount);
        assertFalse(fulfilled);
        vm.stopPrank();
    }

    function testAcceptChallenge() public {
        // First create a challenge
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;

        // Calculate fee based on wager amount
        uint256 fee = (wagerAmount * game.wagerFeePercentage()) / 10000;
        uint256 totalAmount = wagerAmount;

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
        (uint32 challengerId, uint32 defenderId,,,,,) = game.challenges(challengeId);

        // Fulfill VRF with the exact data from the event
        vm.stopPrank(); // Stop any active pranks before fulfilling VRF
        vm.prank(operator);
        game.fulfillRandomness(0, dataWithRound);

        // Get loadouts from challenge
        (,,,, IGameEngine.PlayerLoadout memory challengerLoadout, IGameEngine.PlayerLoadout memory defenderLoadout,) =
            game.challenges(challengeId);
        bytes memory results =
            gameEngine.processGame(_convertToLoadout(challengerLoadout), _convertToLoadout(defenderLoadout), 0, 0);
        (uint256 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(winner, version, condition, actions, challengerId, defenderId);

        assertTrue(game.totalFeesCollected() > 0, "Fees should be collected");
    }

    function testCancelExpiredChallenge() public {
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;

        // Calculate fee based on wager amount
        uint256 fee = (wagerAmount * game.wagerFeePercentage()) / 10000;
        uint256 totalAmount = wagerAmount;

        // Give enough ETH to cover wager + fee
        vm.deal(PLAYER_ONE, totalAmount);

        // Get challenger's address
        address challenger = Player(address(playerContract)).getPlayerOwner(PLAYER_ONE_ID);
        require(challenger == PLAYER_ONE, "Player one should own their player");

        // Create a challenge
        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);

        // Warp to after expiry
        vm.roll(block.number + game.BLOCKS_UNTIL_EXPIRE() + 1);

        // Cancel the challenge
        game.cancelChallenge(challengeId);

        // Verify challenge state
        (,,,,,, bool fulfilled) = game.challenges(challengeId);
        assertTrue(fulfilled);
        assertFalse(game.userChallenges(challenger, challengeId));
        vm.stopPrank();
    }

    function testCompleteDuel() public {
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;

        // Calculate fee based on wager amount
        uint256 fee = (wagerAmount * game.wagerFeePercentage()) / 10000;
        uint256 totalAmount = wagerAmount;

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
        (uint32 challengerId, uint32 defenderId,,,,,) = game.challenges(challengeId);

        // Fulfill VRF with the exact data from the event
        vm.stopPrank(); // Stop any active pranks before fulfilling VRF
        vm.prank(operator);
        game.fulfillRandomness(0, dataWithRound);

        // Get loadouts from challenge
        (,,,, IGameEngine.PlayerLoadout memory challengerLoadout, IGameEngine.PlayerLoadout memory defenderLoadout,) =
            game.challenges(challengeId);
        bytes memory results =
            gameEngine.processGame(_convertToLoadout(challengerLoadout), _convertToLoadout(defenderLoadout), 0, 0);
        (uint256 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(winner, version, condition, actions, challengerId, defenderId);

        assertTrue(game.totalFeesCollected() > 0, "Fees should be collected");
    }

    function testForceCloseAbandonedChallenge() public {
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;

        // Calculate fee based on wager amount
        uint256 fee = (wagerAmount * game.wagerFeePercentage()) / 10000;
        uint256 totalAmount = wagerAmount;

        // Give enough ETH to cover wager + fee
        vm.deal(PLAYER_ONE, totalAmount);

        // Get challenger's address
        address challenger = Player(address(playerContract)).getPlayerOwner(PLAYER_ONE_ID);
        require(challenger == PLAYER_ONE, "Player one should own their player");

        // Create a challenge
        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);

        // Warp to after withdrawal period
        vm.roll(block.number + game.BLOCKS_UNTIL_WITHDRAW() + 1);

        // Force close the challenge as owner
        vm.stopPrank();
        vm.startPrank(game.owner());
        game.forceCloseAbandonedChallenge(challengeId);
        vm.stopPrank();

        // Verify challenge state
        (,,,,,, bool fulfilled) = game.challenges(challengeId);
        assertTrue(fulfilled);
        assertFalse(game.userChallenges(challenger, challengeId));
    }

    function testFailures() public {
        // Try to create challenge with insufficient funds
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        vm.expectRevert("Incorrect ETH amount sent");
        game.initiateChallenge{value: wagerAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);

        // Try to create challenge with default character
        vm.expectRevert("Cannot use default character as challenger");
        game.initiateChallenge{value: wagerAmount}(_createLoadout(999), PLAYER_TWO_ID, wagerAmount);

        // Try to cancel non-existent challenge
        vm.expectRevert("Challenge does not exist");
        game.cancelChallenge(999);

        // Try to cancel active challenge
        uint256 fee = (wagerAmount * game.wagerFeePercentage()) / 10000;
        uint256 challengeId =
            game.initiateChallenge{value: wagerAmount + fee}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);
        vm.expectRevert("Challenge still active");
        game.cancelChallenge(challengeId);
        vm.stopPrank();

        // Try to accept with wrong defender
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert("Not defender");
        game.acceptChallenge{value: wagerAmount}(challengeId, _createLoadout(PLAYER_TWO_ID));
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
        IGameEngine.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);
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
        vm.deal(PLAYER_ONE, wagerAmount);

        uint256 challengeId =
            game.initiateChallenge{value: wagerAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);
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
        assertTrue(collectedFees > 0, "Fees should be collected");

        // Store initial balances
        uint256 initialContractBalance = address(game).balance;
        uint256 initialOwnerBalance = address(game.owner()).balance;

        // Deal enough ETH to the contract to cover the fees
        vm.deal(address(game), collectedFees);

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

    function testCannotInitiateChallengeWithUnownedSkin() public {
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        uint256 totalAmount = wagerAmount;
        vm.deal(PLAYER_ONE, totalAmount);

        // Create a loadout with an unowned skin
        IGameEngine.PlayerLoadout memory loadout = IGameEngine.PlayerLoadout({
            playerId: PLAYER_ONE_ID,
            skinIndex: 2, // Non-default skin index
            skinTokenId: 999 // Token ID we don't own
        });

        vm.expectRevert("Challenger skin validation failed");
        game.initiateChallenge{value: totalAmount}(loadout, PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();
    }

    function testCannotAcceptChallengeWithUnownedSkin() public {
        // First create a valid challenge
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        uint256 totalAmount = wagerAmount;
        vm.deal(PLAYER_ONE, totalAmount);

        uint256 challengeId =
            game.initiateChallenge{value: totalAmount}(_createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();

        // Try to accept with an unowned skin
        vm.startPrank(PLAYER_TWO);
        vm.deal(PLAYER_TWO, wagerAmount);

        IGameEngine.PlayerLoadout memory loadout = IGameEngine.PlayerLoadout({
            playerId: PLAYER_TWO_ID,
            skinIndex: 2, // Non-default skin index
            skinTokenId: 999 // Token ID we don't own
        });

        vm.expectRevert("Defender skin validation failed");
        game.acceptChallenge{value: wagerAmount}(challengeId, loadout);
        vm.stopPrank();
    }

    function testCannotInitiateChallengeWithUnownedUnlockableSkin() public {
        // Create unlock NFT and skin collection
        UnlockNFT unlockNFT = new UnlockNFT();
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("Unlockable Collection", "UC", 0.01 ether);
        skinNFT.setMintingEnabled(true);

        // Register the skin collection with unlock requirement
        vm.deal(address(this), skinRegistry.registrationFee());
        uint32 skinIndex = skinRegistry.registerSkin{value: skinRegistry.registrationFee()}(address(skinNFT));
        skinRegistry.setSkinVerification(skinIndex, true);
        skinRegistry.setRequiredNFT(skinIndex, address(unlockNFT));

        // Mint the skin but NOT the unlock NFT
        vm.startPrank(PLAYER_ONE);
        vm.deal(PLAYER_ONE, 0.01 ether);
        skinNFT.mintSkin{value: skinNFT.mintPrice()}(
            PLAYER_ONE,
            IGameDefinitions.WeaponType.Greatsword,
            IGameDefinitions.ArmorType.Plate,
            IGameDefinitions.FightingStance.Offensive
        );
        uint16 tokenId = 1;

        // Try to initiate challenge with the skin (should fail because no unlock NFT)
        uint256 wagerAmount = 1 ether;
        uint256 totalAmount = wagerAmount;
        vm.deal(PLAYER_ONE, totalAmount);

        IGameEngine.PlayerLoadout memory loadout =
            IGameEngine.PlayerLoadout({playerId: PLAYER_ONE_ID, skinIndex: skinIndex, skinTokenId: tokenId});

        vm.expectRevert("Challenger skin validation failed");
        game.initiateChallenge{value: totalAmount}(loadout, PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();
    }

    function testCanInitiateChallengeWithUnlockedSkin() public {
        // Create unlock NFT and skin collection
        UnlockNFT unlockNFT = new UnlockNFT();
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("Unlockable Collection", "UC", 0.01 ether);
        skinNFT.setMintingEnabled(true);

        // Register the skin collection with unlock requirement
        vm.deal(address(this), skinRegistry.registrationFee());
        uint32 skinIndex = skinRegistry.registerSkin{value: skinRegistry.registrationFee()}(address(skinNFT));
        skinRegistry.setSkinVerification(skinIndex, true);
        skinRegistry.setRequiredNFT(skinIndex, address(unlockNFT));

        // Mint both the skin AND the unlock NFT
        vm.startPrank(PLAYER_ONE);
        vm.deal(PLAYER_ONE, 0.01 ether);
        skinNFT.mintSkin{value: skinNFT.mintPrice()}(
            PLAYER_ONE,
            IGameDefinitions.WeaponType.Greatsword,
            IGameDefinitions.ArmorType.Plate,
            IGameDefinitions.FightingStance.Offensive
        );
        uint16 tokenId = 1;
        vm.stopPrank();

        // Mint the unlock NFT
        unlockNFT.mint(PLAYER_ONE);

        // Now try to initiate challenge with the skin (should succeed)
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        uint256 totalAmount = wagerAmount;
        vm.deal(PLAYER_ONE, totalAmount);

        IGameEngine.PlayerLoadout memory loadout =
            IGameEngine.PlayerLoadout({playerId: PLAYER_ONE_ID, skinIndex: skinIndex, skinTokenId: tokenId});

        // This should not revert
        game.initiateChallenge{value: totalAmount}(loadout, PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();
    }

    function testCanInitiateChallengeWithDefaultSkin() public {
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        uint256 totalAmount = wagerAmount;
        vm.deal(PLAYER_ONE, totalAmount);

        // Create a loadout with a default collection skin
        IGameEngine.PlayerLoadout memory loadout = IGameEngine.PlayerLoadout({
            playerId: PLAYER_ONE_ID,
            skinIndex: skinRegistry.defaultSkinRegistryId(),
            skinTokenId: 1
        });

        // This should not revert since default skins don't require ownership
        game.initiateChallenge{value: totalAmount}(loadout, PLAYER_TWO_ID, wagerAmount);
        vm.stopPrank();
    }

    function _createLoadout(uint32 playerId) internal view returns (IGameEngine.PlayerLoadout memory) {
        return _createLoadout(playerId, false, true, Player(address(playerContract)));
    }
}

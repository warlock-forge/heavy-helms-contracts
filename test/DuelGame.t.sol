// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {DuelGame} from "../src/DuelGame.sol";
import {Player} from "../src/Player.sol";
import {GameEngine} from "../src/GameEngine.sol";
import {PlayerEquipmentStats} from "../src/PlayerEquipmentStats.sol";
import {PlayerSkinRegistry} from "../src/PlayerSkinRegistry.sol";
import {DefaultPlayerSkinNFT} from "../src/DefaultPlayerSkinNFT.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";
import "../src/interfaces/IPlayer.sol";
import "../src/interfaces/IGameEngine.sol";
import "./utils/TestBase.sol";

contract DuelGameTest is TestBase {
    DuelGame public game;
    GameEngine public gameEngine;
    Player public playerContract;
    PlayerEquipmentStats public equipmentStats;
    PlayerSkinRegistry public skinRegistry;
    PlayerNameRegistry public nameRegistry;
    uint32 public defaultSkinIndex;

    // Test addresses
    address public PLAYER_ONE;
    address public PLAYER_TWO;
    uint256 public PLAYER_ONE_ID;
    uint256 public PLAYER_TWO_ID;

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
        skinRegistry = new PlayerSkinRegistry();
        DefaultPlayerSkinNFT defaultSkin = new DefaultPlayerSkinNFT();
        nameRegistry = new PlayerNameRegistry();
        equipmentStats = new PlayerEquipmentStats();

        // Deploy Player contract with dependencies
        playerContract = new Player(address(skinRegistry), address(nameRegistry), address(equipmentStats), operator);

        // Deploy Game contracts
        gameEngine = new GameEngine();
        game = new DuelGame(address(gameEngine), address(playerContract), operator);

        // Set game contract trust as owner (deployer)
        playerContract.setGameContractTrust(address(game), true);

        // Register default skin
        defaultSkinIndex = _registerSkin(address(defaultSkin));
        skinRegistry.setDefaultSkinRegistryId(defaultSkinIndex);
        skinRegistry.setDefaultCollection(defaultSkinIndex, true);
        skinRegistry.setSkinVerification(defaultSkinIndex, true);
        // Mint default skin token ID 1
        (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        ) = DefaultPlayerLibrary.getDefaultWarrior(defaultSkinIndex, 1);

        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 1);
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

    function _registerSkin(address skinContract) internal returns (uint32) {
        vm.prank(address(this));
        return skinRegistry.registerSkin{value: skinRegistry.registrationFee()}(skinContract);
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
        uint256 fee = (wagerAmount * game.WAGER_FEE_PERCENTAGE()) / 10000;
        // Use max of percentage fee or min fee
        fee = fee > game.minDuelFee() ? fee : game.minDuelFee();
        uint256 totalAmount = wagerAmount + fee;

        // Give enough ETH to cover wager + fee
        vm.deal(PLAYER_ONE, totalAmount);

        // Ensure PLAYER_ONE owns the player
        require(playerContract.getPlayerOwner(PLAYER_ONE_ID) == PLAYER_ONE, "Player one should own their player");

        IGameEngine.PlayerLoadout memory loadout = _createLoadout(uint32(PLAYER_ONE_ID));

        // Expect the challenge created event
        vm.expectEmit(true, true, true, true);
        emit ChallengeCreated(0, uint32(PLAYER_ONE_ID), uint32(PLAYER_TWO_ID), wagerAmount, block.number);

        uint256 challengeId = game.initiateChallenge{value: totalAmount}(loadout, uint32(PLAYER_TWO_ID), wagerAmount);

        assertEq(challengeId, 0);
        (uint32 challengerId, uint32 defenderId, uint256 storedWager,,,,, bool fulfilled) = game.challenges(challengeId);
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
        uint256 fee = (wagerAmount * game.WAGER_FEE_PERCENTAGE()) / 10000;
        // Use max of percentage fee or min fee
        fee = fee > game.minDuelFee() ? fee : game.minDuelFee();
        uint256 totalAmount = wagerAmount + fee;

        // Give enough ETH to cover wager + fee
        vm.deal(PLAYER_ONE, totalAmount);

        uint256 challengeId = game.initiateChallenge{value: totalAmount}(
            _createLoadout(uint32(PLAYER_ONE_ID)), uint32(PLAYER_TWO_ID), wagerAmount
        );
        vm.stopPrank();

        // Give enough ETH to PLAYER_TWO to cover wager
        vm.deal(PLAYER_TWO, wagerAmount);

        // Accept challenge as player two
        vm.startPrank(PLAYER_TWO);
        game.acceptChallenge{value: wagerAmount}(challengeId, _createLoadout(uint32(PLAYER_TWO_ID)));

        // Verify challenge state
        (uint32 challengerId, uint32 defenderId, uint256 storedWager,,,, uint256 requestId, bool fulfilled) =
            game.challenges(challengeId);
        assertEq(challengerId, PLAYER_ONE_ID);
        assertEq(defenderId, PLAYER_TWO_ID);
        assertEq(storedWager, wagerAmount);
        assertFalse(fulfilled);
        assertTrue(game.hasPendingRequest(challengeId));
        assertEq(game.requestToChallengeId(requestId), challengeId);
        vm.stopPrank();
    }

    function testCancelExpiredChallenge() public {
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        uint256 fee = (wagerAmount * game.WAGER_FEE_PERCENTAGE()) / 10000;
        // Use max of percentage fee or min fee
        fee = fee > game.minDuelFee() ? fee : game.minDuelFee();
        uint256 totalAmount = wagerAmount + fee;

        // Give enough ETH to cover wager + fee
        vm.deal(PLAYER_ONE, totalAmount);

        // Get challenger's address
        address challenger = IPlayer(playerContract).getPlayerOwner(PLAYER_ONE_ID);
        require(challenger == PLAYER_ONE, "Player one should own their player");

        // Create a challenge
        uint256 challengeId = game.initiateChallenge{value: totalAmount}(
            _createLoadout(uint32(PLAYER_ONE_ID)), uint32(PLAYER_TWO_ID), wagerAmount
        );

        // Warp to after expiry
        vm.roll(block.number + game.BLOCKS_UNTIL_EXPIRE() + 1);

        // Cancel the challenge
        game.cancelChallenge(challengeId);

        // Verify challenge state
        (,,,,,,, bool fulfilled) = game.challenges(challengeId);
        assertTrue(fulfilled);
        assertFalse(game.userChallenges(challenger, challengeId));
        vm.stopPrank();
    }

    function testCompleteDuel() public {
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        uint256 fee = (wagerAmount * game.WAGER_FEE_PERCENTAGE()) / 10000;

        // Give enough ETH to cover wager + fee
        vm.deal(PLAYER_ONE, wagerAmount + fee);

        uint256 challengeId = game.initiateChallenge{value: wagerAmount + fee}(
            _createLoadout(uint32(PLAYER_ONE_ID)), uint32(PLAYER_TWO_ID), wagerAmount
        );

        vm.stopPrank();

        // Give enough ETH to PLAYER_TWO to cover wager
        vm.deal(PLAYER_TWO, wagerAmount);

        // Accept challenge as player two
        vm.startPrank(PLAYER_TWO);
        vm.recordLogs();
        game.acceptChallenge{value: wagerAmount}(challengeId, _createLoadout(uint32(PLAYER_TWO_ID)));

        // Decode RequestedRandomness event and prepare fulfillment data
        bytes memory dataWithRound;
        uint256 decodedRequestId;
        uint256 roundId;
        bytes memory eventData;

        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            // Try to decode the RequestedRandomness event data
            if (entries[i].topics[0] == keccak256("RequestedRandomness(uint256,bytes)")) {
                // Extract the round ID from the event data
                (roundId, eventData) = abi.decode(entries[i].data, (uint256, bytes));
                decodedRequestId = 0;
                bytes memory extraData = "";
                bytes memory innerData = abi.encode(decodedRequestId, extraData);
                dataWithRound = abi.encode(roundId, innerData);
            }
        }
        vm.stopPrank();

        // Get the request ID from the challenge
        (,,,,,, uint256 requestId,) = game.challenges(challengeId);

        // Fulfill VRF with the exact data from the event
        vm.prank(operator);
        game.fulfillRandomness(decodedRequestId, dataWithRound);

        // Verify challenge is completed
        (,,,,,, uint256 requestId2, bool fulfilled2) = game.challenges(challengeId);
        assertTrue(fulfilled2, "Challenge should be fulfilled");
        assertTrue(game.totalFeesCollected() > 0, "Fees should be collected");
    }

    function testForceCloseAbandonedChallenge() public {
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        uint256 fee = (wagerAmount * game.WAGER_FEE_PERCENTAGE()) / 10000;
        // Use max of percentage fee or min fee
        fee = fee > game.minDuelFee() ? fee : game.minDuelFee();
        uint256 totalAmount = wagerAmount + fee;

        // Give enough ETH to cover wager + fee
        vm.deal(PLAYER_ONE, totalAmount);

        // Get challenger's address
        address challenger = IPlayer(playerContract).getPlayerOwner(PLAYER_ONE_ID);
        require(challenger == PLAYER_ONE, "Player one should own their player");

        // Create a challenge
        uint256 challengeId = game.initiateChallenge{value: totalAmount}(
            _createLoadout(uint32(PLAYER_ONE_ID)), uint32(PLAYER_TWO_ID), wagerAmount
        );

        // Warp to after withdrawal period
        vm.roll(block.number + game.BLOCKS_UNTIL_WITHDRAW() + 1);

        // Force close the challenge as owner
        vm.stopPrank();
        vm.prank(game.owner());
        game.forceCloseAbandonedChallenge(challengeId);

        // Verify challenge state
        (,,,,,,, bool fulfilled) = game.challenges(challengeId);
        assertTrue(fulfilled);
        assertFalse(game.userChallenges(challenger, challengeId));
    }

    function testFailures() public {
        // Try to create challenge with insufficient funds
        vm.startPrank(PLAYER_ONE);
        uint256 wagerAmount = 1 ether;
        vm.expectRevert("Incorrect ETH amount sent");
        game.initiateChallenge{value: wagerAmount}(
            _createLoadout(uint32(PLAYER_ONE_ID)), uint32(PLAYER_TWO_ID), wagerAmount
        );

        // Try to create challenge with default character
        vm.expectRevert("Cannot use default character as challenger");
        game.initiateChallenge{value: wagerAmount}(_createLoadout(999), uint32(PLAYER_TWO_ID), wagerAmount);

        // Try to cancel non-existent challenge
        vm.expectRevert("Challenge does not exist");
        game.cancelChallenge(999);

        // Try to cancel active challenge
        uint256 fee = (wagerAmount * game.WAGER_FEE_PERCENTAGE()) / 10000;
        uint256 challengeId = game.initiateChallenge{value: wagerAmount + fee}(
            _createLoadout(uint32(PLAYER_ONE_ID)), uint32(PLAYER_TWO_ID), wagerAmount
        );
        vm.expectRevert("Challenge still active");
        game.cancelChallenge(challengeId);
        vm.stopPrank();

        // Try to accept with wrong defender
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert("Not defender");
        game.acceptChallenge{value: wagerAmount}(challengeId, _createLoadout(uint32(PLAYER_TWO_ID)));
        vm.stopPrank();
    }

    function testUpdateMinDuelFee() public {
        uint256 newFee = 0.001 ether;
        vm.prank(game.owner());
        vm.expectEmit(true, true, false, false);
        emit MinDuelFeeUpdated(game.minDuelFee(), newFee);

        game.setMinDuelFee(newFee);
        assertEq(game.minDuelFee(), newFee);
    }

    function _createLoadout(uint32 playerId) internal view returns (IGameEngine.PlayerLoadout memory) {
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        return IGameEngine.PlayerLoadout({
            playerId: playerId,
            skinIndex: stats.skinIndex,
            skinTokenId: 1 // Just use token ID 1 since that's what we minted
        });
    }
}

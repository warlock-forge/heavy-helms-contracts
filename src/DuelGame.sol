// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseGame.sol";
import "./interfaces/IGameEngine.sol";
import "./interfaces/IPlayer.sol";
import "solmate/src/utils/ReentrancyGuard.sol";
import "vrf-contracts/contracts/GelatoVRFConsumerBase.sol";
import "./lib/UniformRandomNumber.sol";

contract DuelGame is BaseGame, ReentrancyGuard, GelatoVRFConsumerBase {
    using UniformRandomNumber for uint256;

    // Constants
    uint256 public constant WAGER_FEE_PERCENTAGE = 300; // 3% fee (basis points)
    uint256 public constant BLOCKS_UNTIL_EXPIRE = 43200; // ~24 hours at 2s blocks
    uint256 public constant BLOCKS_UNTIL_WITHDRAW = 1296000; // ~30 days at 2s blocks

    uint256 public minDuelFee = 0.0005 ether;
    uint256 private constant ROUND_ID = 1;

    // Structs
    struct DuelChallenge {
        uint32 challengerId;
        uint32 defenderId;
        uint256 wagerAmount;
        uint256 createdBlock;
        IGameEngine.PlayerLoadout challengerLoadout;
        IGameEngine.PlayerLoadout defenderLoadout;
        uint256 vrfRequestId;
        bool fulfilled;
    }

    // State variables
    uint256 public nextChallengeId;
    uint256 public totalFeesCollected;
    mapping(uint256 => DuelChallenge) public challenges;
    mapping(uint256 => uint256) public requestToChallengeId;
    mapping(uint256 => bool) public hasPendingRequest; // Track if challenge has pending request
    mapping(address => mapping(uint256 => bool)) public userChallenges; // Track challenges per user

    // Add operator as a state variable
    address private immutable _operatorAddress;

    // Events
    event ChallengeCreated(
        uint256 indexed challengeId,
        uint32 indexed challengerId,
        uint32 indexed defenderId,
        uint256 wagerAmount,
        uint256 createdAtBlock
    );
    event ChallengeAccepted(uint256 indexed challengeId, uint32 defenderId);
    event ChallengeCancelled(uint256 indexed challengeId);
    event ChallengeExpired(uint256 indexed challengeId);
    event ChallengeForfeited(uint256 indexed challengeId, uint256 amount);
    event DuelComplete(
        uint256 indexed challengeId, uint32 indexed winnerId, uint32 indexed loserId, uint256 winnerPrize
    );
    event FeesWithdrawn(uint256 amount);
    event MinDuelFeeUpdated(uint256 oldFee, uint256 newFee);

    constructor(address _gameEngine, address _playerContract, address operator)
        BaseGame(_gameEngine, _playerContract)
        GelatoVRFConsumerBase()
    {
        _operatorAddress = operator;
    }

    // Override _operator to use the operator address
    function _operator() internal view override returns (address) {
        return _operatorAddress;
    }

    function setMinDuelFee(uint256 _minDuelFee) external onlyOwner {
        uint256 oldFee = minDuelFee;
        minDuelFee = _minDuelFee;
        emit MinDuelFeeUpdated(oldFee, _minDuelFee);
    }

    function initiateChallenge(
        IGameEngine.PlayerLoadout calldata challengerLoadout,
        uint32 defenderId,
        uint256 wagerAmount
    ) external payable nonReentrant returns (uint256) {
        // Calculate required msg.value based on wager
        uint256 requiredAmount;
        if (wagerAmount == 0) {
            requiredAmount = minDuelFee;
        } else {
            uint256 percentageFee = (wagerAmount * WAGER_FEE_PERCENTAGE) / 10000;
            requiredAmount = wagerAmount + (percentageFee >= minDuelFee ? percentageFee : minDuelFee);
        }

        require(msg.value == requiredAmount, "Incorrect ETH amount sent");

        // Check for overflow when total wager is calculated
        require(wagerAmount <= type(uint256).max / 2, "Wager would overflow");

        // Verify players are not default characters
        require(challengerLoadout.playerId >= 1000, "Cannot use default character as challenger");
        require(defenderId >= 1000, "Cannot use default character as defender");

        // Verify challenger owns the player
        require(
            IPlayer(playerContract).getPlayerOwner(challengerLoadout.playerId) == msg.sender,
            "Must own challenger player"
        );

        // Check if players are retired
        require(!playerContract.isPlayerRetired(challengerLoadout.playerId), "Challenger is retired");
        require(!playerContract.isPlayerRetired(defenderId), "Defender is retired");

        // Create challenge
        uint256 challengeId = nextChallengeId++;
        challenges[challengeId] = DuelChallenge({
            challengerId: challengerLoadout.playerId,
            defenderId: defenderId,
            wagerAmount: wagerAmount,
            createdBlock: block.number,
            challengerLoadout: challengerLoadout,
            defenderLoadout: IGameEngine.PlayerLoadout(0, 0, 0),
            vrfRequestId: 0,
            fulfilled: false
        });

        // Track challenge for challenger
        userChallenges[msg.sender][challengeId] = true;
        // Track challenge for defender
        userChallenges[IPlayer(playerContract).getPlayerOwner(defenderId)][challengeId] = true;

        emit ChallengeCreated(challengeId, challengerLoadout.playerId, defenderId, wagerAmount, block.number);

        return challengeId;
    }

    function isChallengeActive(uint256 challengeId) public view returns (bool) {
        DuelChallenge storage challenge = challenges[challengeId];
        // Challenge is active if:
        // 1. It has a valid challenger (non-zero challengerId means it exists)
        // 2. It hasn't been fulfilled yet
        // 3. It hasn't expired
        return challenge.challengerId != 0 && !challenge.fulfilled
            && block.number <= challenge.createdBlock + BLOCKS_UNTIL_EXPIRE;
    }

    function acceptChallenge(uint256 challengeId, IGameEngine.PlayerLoadout calldata defenderLoadout)
        external
        payable
        nonReentrant
    {
        DuelChallenge storage challenge = challenges[challengeId];

        // Validate challenge state
        require(isChallengeActive(challengeId), "Challenge not active");
        require(!hasPendingRequest[challengeId], "Challenge has pending request");
        require(msg.value == challenge.wagerAmount, "Incorrect wager amount");

        // Verify msg.sender owns the defender
        address defender = IPlayer(playerContract).getPlayerOwner(challenge.defenderId);
        require(msg.sender == defender, "Not defender");
        require(defenderLoadout.playerId == challenge.defenderId, "Wrong defender ID");

        // Validate player ownership and stats
        require(IPlayer(playerContract).getPlayerOwner(defenderLoadout.playerId) == msg.sender, "Not player owner");
        require(!IPlayer(playerContract).isPlayerRetired(defenderLoadout.playerId), "Player retired");

        // Store defender loadout
        challenge.defenderLoadout = defenderLoadout;

        // Request VRF for true randomness
        uint256 requestId = _requestRandomness("");
        challenge.vrfRequestId = requestId;
        requestToChallengeId[requestId] = challengeId;
        hasPendingRequest[challengeId] = true;

        emit ChallengeAccepted(challengeId, defenderLoadout.playerId);
    }

    function cancelChallenge(uint256 challengeId) external nonReentrant {
        DuelChallenge storage challenge = challenges[challengeId];

        // Can only cancel if it exists but is NOT active (has expired)
        require(challenge.challengerId != 0, "Challenge does not exist");
        require(!isChallengeActive(challengeId), "Challenge still active");

        // Get challenger's address
        address challenger = IPlayer(playerContract).getPlayerOwner(challenge.challengerId);
        require(msg.sender == challenger, "Not challenger");

        // Mark as fulfilled to prevent further actions
        challenge.fulfilled = true;

        // Clear challenge tracking for both users
        userChallenges[challenger][challengeId] = false;
        userChallenges[IPlayer(playerContract).getPlayerOwner(challenge.defenderId)][challengeId] = false;

        // Only keep minDuelFee as cancellation fee, return rest
        uint256 refundAmount = challenge.wagerAmount - minDuelFee;
        totalFeesCollected += minDuelFee;

        (bool sent,) = payable(challenger).call{value: refundAmount}("");
        require(sent, "Failed to send refund");

        emit ChallengeCancelled(challengeId);
    }

    function calculateFee(uint256 amount) public view returns (uint256) {
        // If amount is 0 or too small, return minimum fee
        if (amount == 0) return minDuelFee;

        // Calculate percentage fee (3% of amount)
        uint256 percentageFee = (amount * WAGER_FEE_PERCENTAGE) / 10000;

        // Return the larger of percentage fee or minimum fee
        return percentageFee > minDuelFee ? percentageFee : minDuelFee;
    }

    function _fulfillRandomness(uint256 randomness, uint256 requestId, bytes memory extraData) internal override {
        uint256 challengeId = requestToChallengeId[requestId];
        require(challengeId != 0, "Invalid VRF request");
        DuelChallenge storage challenge = challenges[challengeId];
        require(isChallengeActive(challengeId), "Challenge not active");
        require(challenge.vrfRequestId == requestId, "VRF request mismatch");

        // Clear request tracking
        delete requestToChallengeId[requestId];
        delete hasPendingRequest[challengeId];

        // Mark as fulfilled to prevent re-entry
        challenge.fulfilled = true;

        // Get addresses before marking fulfilled
        // address challenger = IPlayer(playerContract).getPlayerOwner(challenge.challengerId);
        // address defender = IPlayer(playerContract).getPlayerOwner(challenge.defenderId);

        // Clear challenge tracking for both users
        address challenger = IPlayer(playerContract).getPlayerOwner(challenge.challengerId);
        address defender = IPlayer(playerContract).getPlayerOwner(challenge.defenderId);
        userChallenges[challenger][challengeId] = false;
        userChallenges[defender][challengeId] = false;

        // Create a new random seed by combining VRF randomness with request data
        uint256 combinedSeed = uint256(keccak256(abi.encodePacked(randomness, requestId)));

        // Execute the duel with the random seed
        bytes memory results = gameEngine.processGame(
            challenge.challengerLoadout, challenge.defenderLoadout, combinedSeed, IPlayer(playerContract)
        );

        // Unpack winner ID from bytes
        uint32 winnerId;
        unchecked {
            winnerId = uint32(uint8(results[0])) << 24 | uint32(uint8(results[1])) << 16
                | uint32(uint8(results[2])) << 8 | uint32(uint8(results[3]));
        }

        // Determine loser ID
        uint32 loserId = winnerId == challenge.challengerId ? challenge.defenderId : challenge.challengerId;

        // Calculate winner's prize (total wager minus fee)
        uint256 totalWager = challenge.wagerAmount * 2;
        uint256 fee = calculateFee(totalWager);
        totalFeesCollected += fee;
        uint256 winnerPrize = totalWager - fee;

        // Get winner's address and transfer prize
        address winner = IPlayer(playerContract).getPlayerOwner(winnerId);
        (bool sent,) = payable(winner).call{value: winnerPrize}("");
        require(sent, "Failed to send prize");

        // Update player stats
        IPlayer(playerContract).incrementWins(winnerId);
        IPlayer(playerContract).incrementLosses(loserId);

        emit DuelComplete(challengeId, winnerId, loserId, winnerPrize);
    }

    function getUserActiveChallenges(address user) external view returns (uint256[] memory) {
        // First count active challenges
        uint256 count = 0;
        for (uint256 i = 0; i < nextChallengeId; i++) {
            if (userChallenges[user][i] && isChallengeActive(i)) {
                count++;
            }
        }

        // Create array and populate
        uint256[] memory activeChallenges = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < nextChallengeId; i++) {
            if (userChallenges[user][i] && isChallengeActive(i)) {
                activeChallenges[index++] = i;
            }
        }

        return activeChallenges;
    }

    function forceCloseAbandonedChallenge(uint256 challengeId) external onlyOwner {
        DuelChallenge storage challenge = challenges[challengeId];

        // Verify challenge exists and is old enough
        require(challenge.challengerId != 0, "Challenge does not exist");
        require(!challenge.fulfilled, "Challenge already fulfilled");
        require(block.number > challenge.createdBlock + BLOCKS_UNTIL_WITHDRAW, "Challenge not old enough");

        // Mark as fulfilled to prevent further actions
        challenge.fulfilled = true;

        // Clear challenge tracking for both users
        address challenger = IPlayer(playerContract).getPlayerOwner(challenge.challengerId);
        address defender = IPlayer(playerContract).getPlayerOwner(challenge.defenderId);
        userChallenges[challenger][challengeId] = false;
        userChallenges[defender][challengeId] = false;

        // Add entire amount to collected fees
        totalFeesCollected += challenge.wagerAmount;

        emit ChallengeForfeited(challengeId, challenge.wagerAmount);
    }

    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = totalFeesCollected;
        require(amount > 0, "No fees to withdraw");

        totalFeesCollected = 0;

        (bool sent,) = owner.call{value: amount}("");
        require(sent, "Failed to withdraw fees");

        emit FeesWithdrawn(amount);
    }

    receive() external payable {}
}

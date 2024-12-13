// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseGame.sol";
import "./interfaces/IGameEngine.sol";
import "./interfaces/IPlayer.sol";
import "solmate/src/utils/ReentrancyGuard.sol";

/*
contract DuelGame is BaseGame, ReentrancyGuard {
    // Constants
    uint256 public constant WAGER_FEE_PERCENTAGE = 500; // 5% fee (basis points)
    uint256 public constant BLOCKS_UNTIL_EXPIRE = 43200; // ~24 hours at 2s blocks
    uint256 public constant BLOCKS_UNTIL_WITHDRAW = 1296000; // ~30 days at 2s blocks
    uint256 public minDuelFee = 0.0005 ether;

    // Constants for retirement reasons
    uint8 public constant RETIREMENT_REASON_DUEL_DEATH = 1;

    // Structs
    struct DuelChallenge {
        uint32 challengerId;
        uint32 defenderId;
        address challenger;
        address defender;
        uint256 wagerAmount;
        uint256 createdBlock;
        bool isActive;
        IGameEngine.PlayerLoadout challengerLoadout;
    }

    // State variables
    uint256 public nextChallengeId;
    uint256 public totalFeesCollected;
    mapping(uint256 => DuelChallenge) public challenges;
    mapping(address => uint256[]) public userActiveChallenges;

    // Events
    event ChallengeCreated(
        uint256 indexed challengeId,
        uint32 indexed challengerId,
        uint32 indexed defenderId,
        uint256 wagerAmount,
        uint256 expiresAtBlock
    );
    event ChallengeAccepted(uint256 indexed challengeId, uint32 defenderId);
    event ChallengeCancelled(uint256 indexed challengeId);
    event ChallengeExpired(uint256 indexed challengeId);
    event DuelComplete(
        uint256 indexed challengeId,
        uint32 indexed winnerId,
        uint32 indexed loserId,
        uint256 prizeAmount
    );
    event FeesWithdrawn(uint256 amount);

    constructor(
        address _gameEngine,
        address _playerContract
    ) BaseGame(_gameEngine, _playerContract) {}

    function setMinDuelFee(uint256 _minDuelFee) external onlyOwner {
        minDuelFee = _minDuelFee;
    }

    function initiateChallenge(
        IGameEngine.PlayerLoadout calldata challengerLoadout,
        uint32 defenderId
    ) external payable nonReentrant returns (uint256) {
        // Validate inputs
        require(msg.value > 0, "Must send ETH for wager");
        require(
            msg.value >= minDuelFee,
            "Wager must be >= minimum duel fee"
        );
        
        // Verify challenger owns the player
        require(
            playerContract.getPlayerOwner(challengerLoadout.playerId) == msg.sender,
            "Must own challenger player"
        );

        // Check if players are retired
        require(!playerContract.isPlayerRetired(challengerLoadout.playerId), "Challenger is retired");
        require(!playerContract.isPlayerRetired(defenderId), "Defender is retired");

        // Calculate fee
        uint256 fee = calculateFee(msg.value);
        
        // Create challenge
        uint256 challengeId = nextChallengeId++;
        challenges[challengeId] = DuelChallenge({
            challengerId: challengerLoadout.playerId,
            defenderId: defenderId,
            challenger: msg.sender,
            defender: playerContract.getPlayerOwner(defenderId),
            wagerAmount: msg.value,
            createdBlock: block.number,
            isActive: true,
            challengerLoadout: challengerLoadout
        });

        // Track for the user
        userActiveChallenges[msg.sender].push(challengeId);

        totalFeesCollected += fee;

        emit ChallengeCreated(
            challengeId,
            challengerLoadout.playerId,
            defenderId,
            msg.value,
            block.number + BLOCKS_UNTIL_EXPIRE
        );

        return challengeId;
    }

    function acceptChallenge(
        uint256 challengeId,
        IGameEngine.PlayerLoadout calldata defenderLoadout
    ) external payable nonReentrant {
        DuelChallenge storage challenge = challenges[challengeId];
        
        // Validate challenge state
        require(challenge.isActive, "Challenge not active");
        require(
            block.number <= challenge.createdBlock + BLOCKS_UNTIL_EXPIRE,
            "Challenge expired"
        );
        require(msg.sender == challenge.defender, "Not the challenged player");
        require(
            msg.value == challenge.wagerAmount,
            "Must match wager amount exactly"
        );
        require(
            defenderLoadout.playerId == challenge.defenderId,
            "Wrong defender player ID"
        );
        require(
            playerContract.getPlayerOwner(defenderLoadout.playerId) == msg.sender,
            "Must own defender player"
        );

        // Check if players are retired
        require(!playerContract.isPlayerRetired(challenge.challengerId), "Challenger is retired");
        require(!playerContract.isPlayerRetired(defenderLoadout.playerId), "Defender is retired");

        // Mark challenge as inactive
        challenge.isActive = false;

        // Remove from active challenges
        removeFromActiveChallenges(challenge.challenger, challengeId);

        // Calculate total fees
        uint256 totalFee = calculateFee(challenge.wagerAmount * 2);
        totalFeesCollected += totalFee;

        // Get VRF for true randomness
        uint256 randomSeed = requestRandomSeedFromVRF();
        
        // Execute the duel
        bytes memory results = gameEngine.processGame(
            challenge.challengerLoadout,
            defenderLoadout,
            randomSeed,
            playerContract
        );

        // Extract winner ID from first 4 bytes
        uint32 winningPlayerId;
        unchecked {
            winningPlayerId = uint32(uint8(results[0])) << 24 |
                uint32(uint8(results[1])) << 16 |
                uint32(uint8(results[2])) << 8 |
                uint32(uint8(results[3]));
        }

        // Calculate prize amount (total wager minus fees)
        uint256 prizeAmount = (challenge.wagerAmount * 2) - totalFee;
        
        // Transfer prize to winner
        address winner = winningPlayerId == challenge.challengerId
            ? challenge.challenger
            : challenge.defender;
        
        (bool sent, ) = winner.call{value: prizeAmount}("");
        require(sent, "Failed to send prize");

        // After determining winner, retire the loser
        uint32 losingPlayerId = winningPlayerId == challenge.challengerId 
            ? defenderLoadout.playerId 
            : challenge.challengerId;
            
        // Retire the losing player
        playerContract.setPlayerRetired(losingPlayerId, true);

        // Emit events
        emit DuelComplete(
            challengeId,
            winningPlayerId,
            losingPlayerId,
            prizeAmount
        );
        
        emit CombatResult(
            challenge.challengerId,
            challenge.defenderId,
            randomSeed,
            results,
            winningPlayerId
        );
    }

    function cancelChallenge(uint256 challengeId) external nonReentrant {
        DuelChallenge storage challenge = challenges[challengeId];
        
        require(challenge.isActive, "Challenge not active");
        require(
            block.number > challenge.createdBlock + BLOCKS_UNTIL_EXPIRE,
            "Challenge not expired"
        );
        require(
            msg.sender == challenge.challenger,
            "Only challenger can cancel"
        );

        // Mark as inactive
        challenge.isActive = false;

        // Remove from active challenges
        removeFromActiveChallenges(challenge.challenger, challengeId);

        // Return wager minus fee
        uint256 fee = calculateFee(challenge.wagerAmount);
        uint256 refundAmount = challenge.wagerAmount - fee;
        
        (bool sent, ) = challenge.challenger.call{value: refundAmount}("");
        require(sent, "Failed to send refund");

        emit ChallengeCancelled(challengeId);
    }

    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = totalFeesCollected;
        require(amount > 0, "No fees to withdraw");
        
        totalFeesCollected = 0;
        
        (bool sent, ) = owner.call{value: amount}("");
        require(sent, "Failed to withdraw fees");
        
        emit FeesWithdrawn(amount);
    }

    function emergencyWithdraw(uint256 challengeId) external onlyOwner nonReentrant {
        DuelChallenge storage challenge = challenges[challengeId];
        require(
            block.number > challenge.createdBlock + BLOCKS_UNTIL_WITHDRAW,
            "Must wait 30 days"
        );
        require(challenge.isActive, "Challenge not active");

        challenge.isActive = false;
        removeFromActiveChallenges(challenge.challenger, challengeId);

        // Return wager minus fee
        uint256 fee = calculateFee(challenge.wagerAmount);
        uint256 refundAmount = challenge.wagerAmount - fee;
        
        (bool sent, ) = challenge.challenger.call{value: refundAmount}("");
        require(sent, "Failed to send refund");

        emit ChallengeExpired(challengeId);
    }

    function calculateFee(uint256 amount) public view returns (uint256) {
        uint256 percentageFee = (amount * WAGER_FEE_PERCENTAGE) / 10000;
        return percentageFee > minDuelFee ? percentageFee : minDuelFee;
    }

    function getUserActiveChallenges(
        address user
    ) external view returns (uint256[] memory) {
        return userActiveChallenges[user];
    }

    function removeFromActiveChallenges(address user, uint256 challengeId) private {
        uint256[] storage challenges = userActiveChallenges[user];
        for (uint256 i = 0; i < challenges.length; i++) {
            if (challenges[i] == challengeId) {
                challenges[i] = challenges[challenges.length - 1];
                challenges.pop();
                break;
            }
        }
    }

    receive() external payable {}
}
*/

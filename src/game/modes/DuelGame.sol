// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import "./BaseGame.sol";
import "solmate/src/utils/ReentrancyGuard.sol";
import "solmate/src/utils/SafeTransferLib.sol";
import "vrf-contracts/contracts/GelatoVRFConsumerBase.sol";
import "../../lib/UniformRandomNumber.sol";
import "../../interfaces/game/engine/IGameEngine.sol";

//==============================================================//
//                         HEAVY HELMS                          //
//                          DUEL GAME                           //
//==============================================================//
/// @title Duel Game Mode for Heavy Helms
/// @notice Allows players to challenge each other to 1v1 combat with wagers
/// @dev Integrates with VRF for fair, random combat resolution
contract DuelGame is BaseGame, ReentrancyGuard, GelatoVRFConsumerBase {
    using UniformRandomNumber for uint256;

    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    // Constants
    /// @notice Percentage fee taken from wagers (in basis points)
    uint256 public wagerFeePercentage = 200; // basis points
    /// @notice Minimum allowed wager amount
    uint256 public minWagerAmount = 0.001 ether;
    /// @notice Maximum allowed wager amount
    uint256 public maxWagerAmount = 100 ether;
    /// @notice Minimum fee required for all duels (even zero-wager duels)
    uint256 public minDuelFee = 0.0002 ether;
    /// @notice Timeout period in seconds after which a VRF request can be considered failed
    uint256 public vrfRequestTimeout = 4 hours;
    /// @notice Time (in seconds) after which a challenge expires
    uint256 public timeUntilExpire = 7 days; // 7 days
    /// @notice Time (in seconds) after which abandoned challenges can be withdrawn
    uint256 public timeUntilWithdraw = 30 days; // 30 days
    /// @notice Address of the Gelato VRF operator
    address private _operatorAddress;

    // Enum
    /// @notice Enum representing the state of a duel challenge
    enum ChallengeState {
        OPEN, // Challenge created but not yet accepted
        PENDING, // Challenge accepted and awaiting VRF result
        COMPLETED // Challenge completed (fulfilled or cancelled)

    }

    // Structs
    /// @notice Structure storing a duel challenge data
    /// @param challengerId ID of the player issuing the challenge
    /// @param defenderId ID of the player being challenged
    /// @param wagerAmount Amount of ETH wagered
    /// @param createdBlock Block number when challenge was created
    /// @param createdTimestamp Timestamp when challenge was created
    /// @param challengerLoadout Loadout of the challenger player
    /// @param defenderLoadout Loadout of the defender player
    /// @param state State of the challenge
    /// @param vrfRequestTimestamp When VRF was requested (set at acceptance time)
    struct DuelChallenge {
        uint32 challengerId;
        uint32 defenderId;
        uint256 wagerAmount;
        uint256 createdBlock;
        uint256 createdTimestamp;
        uint256 vrfRequestTimestamp;
        Fighter.PlayerLoadout challengerLoadout;
        Fighter.PlayerLoadout defenderLoadout;
        ChallengeState state;
    }

    // State variables
    /// @notice Next challenge ID to be assigned
    uint256 public nextChallengeId;
    /// @notice Total fees collected from all duels
    uint256 public totalFeesCollected;
    /// @notice Maps challenge IDs to their challenge data
    mapping(uint256 => DuelChallenge) public challenges;
    /// @notice Maps VRF request IDs to challenge IDs
    /// @dev This mapping connects the random outcomes from Gelato VRF to their corresponding challenges
    /// It's necessary because challenges are created before randomness is requested
    mapping(uint256 => uint256) public requestToChallengeId;

    /// @notice Overall game enabled state
    bool public isGameEnabled = true;
    /// @notice Controls whether wagers are enabled in the game
    bool public wagersEnabled = true;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a new challenge is created
    event ChallengeCreated(
        uint256 indexed challengeId,
        uint32 indexed challengerId,
        uint32 indexed defenderId,
        uint256 wagerAmount,
        uint32 challengerSkinIndex,
        uint16 challengerSkinTokenId,
        uint8 challengerStance
    );
    /// @notice Emitted when a challenge is accepted
    event ChallengeAccepted(
        uint256 indexed challengeId,
        uint32 indexed defenderId,
        uint32 defenderSkinIndex,
        uint16 defenderSkinTokenId,
        uint8 defenderStance
    );
    /// @notice Emitted when a challenge is cancelled
    event ChallengeCancelled(uint256 indexed challengeId);
    /// @notice Emitted when a challenge is forfeited
    event ChallengeForfeited(uint256 indexed challengeId, uint256 amount);
    /// @notice Emitted when a duel is completed
    event DuelComplete(
        uint256 indexed challengeId,
        uint32 indexed winnerId,
        uint256 randomness,
        uint256 winnerPayout,
        uint256 feeCollected
    );
    /// @notice Emitted when accumulated fees are withdrawn
    event FeesWithdrawn(uint256 amount);
    /// @notice Emitted when minimum duel fee is updated
    event MinDuelFeeUpdated(uint256 oldFee, uint256 newFee);
    /// @notice Emitted when minimum wager amount is updated
    event MinWagerAmountUpdated(uint256 newAmount);
    /// @notice Emitted when game enabled state is updated
    event GameEnabledUpdated(bool enabled);
    /// @notice Emitted when wager fee percentage is updated
    event WagerFeePercentageUpdated(uint256 oldPercentage, uint256 newPercentage);
    /// @notice Emitted when wager functionality is enabled or disabled
    event WagersEnabledUpdated(bool enabled);
    /// @notice Emitted when time until expire is updated
    event TimeUntilExpireUpdated(uint256 oldValue, uint256 newValue);
    /// @notice Emitted when time until withdraw is updated
    event TimeUntilWithdrawUpdated(uint256 oldValue, uint256 newValue);
    /// @notice Emitted when a challenge is recovered from a VRF timeout
    event ChallengeRecovered(uint256 indexed challengeId, uint256 challengerRefund, uint256 defenderRefund);
    /// @notice Emitted when VRF request timeout is updated
    event VrfRequestTimeoutUpdated(uint256 oldValue, uint256 newValue);

    //==============================================================//
    //                        MODIFIERS                             //
    //==============================================================//
    /// @notice Ensures game is enabled for function execution
    modifier whenGameEnabled() {
        require(isGameEnabled, "Game is disabled");
        _;
    }

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    /// @notice Initializes the DuelGame contract
    /// @param _gameEngine Address of the game engine contract
    /// @param _playerContract Address of the player contract
    /// @param operator Address of the Gelato VRF operator
    constructor(address _gameEngine, address _playerContract, address operator)
        BaseGame(_gameEngine, _playerContract)
        GelatoVRFConsumerBase()
    {
        require(operator != address(0), "Invalid operator address");
        _operatorAddress = operator;
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Returns the operator address for VRF
    /// @return operator address
    function _operator() internal view override returns (address) {
        return _operatorAddress;
    }

    /// @notice Checks if a challenge exists and is in OPEN state (not expired)
    /// @param challengeId ID of the challenge to check
    /// @return isActive True if challenge exists, is in OPEN state, and not expired
    function isChallengeActive(uint256 challengeId) public view returns (bool) {
        DuelChallenge storage challenge = challenges[challengeId];
        return challenge.challengerId != 0 && challenge.state == ChallengeState.OPEN
            && block.timestamp <= challenge.createdTimestamp + timeUntilExpire;
    }

    /// @notice Checks if a challenge exists and is in PENDING state
    /// @param challengeId ID of the challenge to check
    /// @return isPending True if challenge exists and is in PENDING state
    function isChallengePending(uint256 challengeId) public view returns (bool) {
        DuelChallenge storage challenge = challenges[challengeId];
        return challenge.challengerId != 0 && challenge.state == ChallengeState.PENDING;
    }

    /// @notice Checks if a challenge exists and is in COMPLETED state
    /// @param challengeId ID of the challenge to check
    /// @return isCompleted True if challenge exists and is in COMPLETED state
    function isChallengeCompleted(uint256 challengeId) public view returns (bool) {
        DuelChallenge storage challenge = challenges[challengeId];
        return challenge.challengerId != 0 && challenge.state == ChallengeState.COMPLETED;
    }

    /// @notice Checks if a challenge is expired but still in OPEN state
    /// @param challengeId ID of the challenge to check
    /// @return isExpired True if challenge exists and is in OPEN state but expired
    function isChallengeExpired(uint256 challengeId) public view returns (bool) {
        DuelChallenge storage challenge = challenges[challengeId];
        return challenge.challengerId != 0 && challenge.state == ChallengeState.OPEN
            && block.timestamp > challenge.createdTimestamp + timeUntilExpire;
    }

    /// @notice Calculates fee based on wager amount
    /// @param amount Wager amount to calculate fee for
    /// @return Fee amount
    function calculateFee(uint256 amount) public view returns (uint256) {
        // If amount is 0 or below min wager, return minimum fee
        if (amount < minWagerAmount) return minDuelFee;

        // Always apply percentage fee plus minimum fee
        uint256 percentageFee = (amount * wagerFeePercentage) / 10000;
        return percentageFee + minDuelFee;
    }

    /// @notice Creates a new duel challenge
    /// @param challengerLoadout Loadout for the challenger
    /// @param defenderId ID of the defender
    /// @param wagerAmount Amount to wager
    /// @return challengeId ID of the created challenge
    function initiateChallenge(Fighter.PlayerLoadout calldata challengerLoadout, uint32 defenderId, uint256 wagerAmount)
        external
        payable
        whenGameEnabled
        nonReentrant
        returns (uint256)
    {
        require(wagersEnabled || wagerAmount == 0, "Wagers are disabled");
        require(challengerLoadout.playerId != defenderId, "Cannot duel yourself");
        require(
            address(_getFighterContract(challengerLoadout.playerId)) == address(playerContract),
            "Challenger must be a Player"
        );
        require(address(_getFighterContract(defenderId)) == address(playerContract), "Defender must be a Player");
        require(
            IPlayer(playerContract).getPlayerOwner(challengerLoadout.playerId) == msg.sender,
            "Must own challenger player"
        );

        // Check player existence by calling getPlayer (will revert if player doesn't exist)
        IPlayer(playerContract).getPlayer(challengerLoadout.playerId);
        IPlayer(playerContract).getPlayer(defenderId);

        // Calculate required msg.value based on wager
        uint256 requiredAmount = minDuelFee + wagerAmount;
        if (wagerAmount > 0) {
            require(wagerAmount >= minWagerAmount, "Wager below minimum");
        }
        require(wagerAmount <= maxWagerAmount, "Wager exceeds maximum");
        require(msg.value == requiredAmount, "Incorrect ETH amount sent");

        // Verify players are not retired
        require(!playerContract.isPlayerRetired(challengerLoadout.playerId), "Challenger is retired");
        require(!playerContract.isPlayerRetired(defenderId), "Defender is retired");

        // Validate skin ownership and requirements
        address owner = IPlayer(playerContract).getPlayerOwner(challengerLoadout.playerId);
        IPlayer(playerContract).skinRegistry().validateSkinOwnership(challengerLoadout.skin, owner);
        IPlayer(playerContract).skinRegistry().validateSkinRequirements(
            challengerLoadout.skin,
            IPlayer(playerContract).getPlayer(challengerLoadout.playerId).attributes,
            IPlayer(playerContract).equipmentRequirements()
        );

        // Create challenge
        uint256 challengeId = nextChallengeId++;
        challenges[challengeId] = DuelChallenge({
            challengerId: challengerLoadout.playerId,
            defenderId: defenderId,
            wagerAmount: wagerAmount,
            createdBlock: block.number,
            createdTimestamp: block.timestamp,
            vrfRequestTimestamp: 0,
            challengerLoadout: challengerLoadout,
            defenderLoadout: Fighter.PlayerLoadout(0, Fighter.SkinInfo(0, 0), 1),
            state: ChallengeState.OPEN
        });

        emit ChallengeCreated(
            challengeId,
            challengerLoadout.playerId,
            defenderId,
            wagerAmount,
            challengerLoadout.skin.skinIndex,
            challengerLoadout.skin.skinTokenId,
            challengerLoadout.stance
        );

        return challengeId;
    }

    /// @notice Accepts a duel challenge
    /// @param challengeId ID of the challenge to accept
    /// @param defenderLoadout Loadout for the defender
    function acceptChallenge(uint256 challengeId, Fighter.PlayerLoadout calldata defenderLoadout)
        external
        payable
        nonReentrant
    {
        DuelChallenge storage challenge = challenges[challengeId];

        // Validate challenge state
        require(isChallengeActive(challengeId), "Challenge not active");
        require(msg.value == challenge.wagerAmount, "Incorrect wager amount");

        // Check player existence by calling getPlayer (will revert if player doesn't exist)
        IPlayer(playerContract).getPlayer(defenderLoadout.playerId);

        // Verify msg.sender owns the defender
        address defender = IPlayer(playerContract).getPlayerOwner(challenge.defenderId);
        require(msg.sender == defender, "Not defender");
        require(defenderLoadout.playerId == challenge.defenderId, "Wrong defender ID");

        // Validate player ownership and stats
        require(IPlayer(playerContract).getPlayerOwner(defenderLoadout.playerId) == msg.sender, "Not player owner");
        require(!IPlayer(playerContract).isPlayerRetired(defenderLoadout.playerId), "Defender is retired");
        require(!IPlayer(playerContract).isPlayerRetired(challenge.challengerId), "Challenger is retired");

        // Store defender loadout
        challenge.defenderLoadout = defenderLoadout;

        // Update state to PENDING
        challenge.state = ChallengeState.PENDING;
        challenge.vrfRequestTimestamp = block.timestamp;

        // Request VRF for true randomness
        uint256 requestId = _requestRandomness("");
        requestToChallengeId[requestId] = challengeId;

        // Validate ownership and requirements
        address owner = IPlayer(playerContract).getPlayerOwner(defenderLoadout.playerId);
        IPlayer(playerContract).skinRegistry().validateSkinOwnership(defenderLoadout.skin, owner);
        IPlayer(playerContract).skinRegistry().validateSkinRequirements(
            defenderLoadout.skin,
            IPlayer(playerContract).getPlayer(defenderLoadout.playerId).attributes,
            IPlayer(playerContract).equipmentRequirements()
        );

        emit ChallengeAccepted(
            challengeId,
            defenderLoadout.playerId,
            defenderLoadout.skin.skinIndex,
            defenderLoadout.skin.skinTokenId,
            defenderLoadout.stance
        );
    }

    /// @notice Cancels a duel challenge (challenger only)
    /// @param challengeId ID of the challenge to cancel
    function cancelChallenge(uint256 challengeId) external nonReentrant {
        DuelChallenge storage challenge = challenges[challengeId];

        require(challenge.challengerId != 0, "Challenge does not exist");
        require(challenge.state == ChallengeState.OPEN, "Challenge not cancellable");

        // Get challenger's address
        address challenger = IPlayer(playerContract).getPlayerOwner(challenge.challengerId);
        require(msg.sender == challenger, "Not challenger");

        // Mark as completed
        challenge.state = ChallengeState.COMPLETED;

        // Refund the FULL amount (both wager and minDuelFee)
        uint256 refundAmount = challenge.wagerAmount + minDuelFee;
        SafeTransferLib.safeTransferETH(challenger, refundAmount);

        emit ChallengeCancelled(challengeId);
    }

    /// @notice Allows players to recover from a timed-out VRF request
    /// @param challengeId ID of the challenge to recover
    function recoverTimedOutVRF(uint256 challengeId) external nonReentrant {
        DuelChallenge storage challenge = challenges[challengeId];

        // Verify challenge exists and is in PENDING state
        require(challenge.challengerId != 0, "Challenge does not exist");
        require(challenge.state == ChallengeState.PENDING, "Challenge not pending");

        // Get player addresses early
        address challenger = IPlayer(playerContract).getPlayerOwner(challenge.challengerId);
        address defender = IPlayer(playerContract).getPlayerOwner(challenge.defenderId);

        // Require caller to be either challenger or defender
        require(msg.sender == challenger || msg.sender == defender, "Not authorized");

        // Verify that VRF request timestamp is non-zero
        require(challenge.vrfRequestTimestamp != 0, "Invalid VRF request timestamp");

        // Check if enough time has passed since VRF was requested
        require(block.timestamp >= challenge.vrfRequestTimestamp + vrfRequestTimeout, "VRF timeout not reached");

        // Mark as completed
        challenge.state = ChallengeState.COMPLETED;

        // Calculate refund amounts
        uint256 challengerRefund = challenge.wagerAmount + minDuelFee;
        uint256 defenderRefund = challenge.wagerAmount;

        // Send refunds in just two transactions
        if (defenderRefund > 0) {
            SafeTransferLib.safeTransferETH(defender, defenderRefund);
        }

        SafeTransferLib.safeTransferETH(challenger, challengerRefund);

        emit ChallengeRecovered(challengeId, challengerRefund, defenderRefund);
    }

    //==============================================================//
    //                     ADMIN FUNCTIONS                          //
    //==============================================================//
    /// @notice Sets the VRF operator address
    /// @param newOperator The new operator address
    function setOperator(address newOperator) external onlyOwner {
        require(newOperator != address(0), "Invalid operator address");
        _operatorAddress = newOperator;
    }

    /// @notice Sets the minimum fee required for all duels
    /// @param _minDuelFee The new minimum duel fee
    function setMinDuelFee(uint256 _minDuelFee) external onlyOwner {
        emit MinDuelFeeUpdated(minDuelFee, _minDuelFee);
        minDuelFee = _minDuelFee;
    }

    /// @notice Sets the minimum wager amount
    /// @param _minWagerAmount The new minimum wager amount
    function setMinWagerAmount(uint256 _minWagerAmount) external onlyOwner {
        emit MinWagerAmountUpdated(_minWagerAmount);
        minWagerAmount = _minWagerAmount;
    }

    /// @notice Sets the wager fee percentage (in basis points)
    /// @param _wagerFeePercentage The new wager fee percentage
    function setWagerFeePercentage(uint256 _wagerFeePercentage) external onlyOwner {
        require(_wagerFeePercentage <= 1000, "Fee cannot exceed 10%"); // Safety check
        emit WagerFeePercentageUpdated(wagerFeePercentage, _wagerFeePercentage);
        wagerFeePercentage = _wagerFeePercentage;
    }

    /// @notice Sets whether the game is enabled
    /// @param enabled The new enabled state
    function setGameEnabled(bool enabled) external onlyOwner {
        emit GameEnabledUpdated(enabled);
        isGameEnabled = enabled;
    }

    /// @notice Force closes abandoned challenges (admin only)
    /// @param challengeId ID of the challenge to close
    function forceCloseAbandonedChallenge(uint256 challengeId) external onlyOwner {
        DuelChallenge storage challenge = challenges[challengeId];

        // Verify challenge exists and is in OPEN or PENDING state
        require(challenge.challengerId != 0, "Challenge does not exist");
        require(
            challenge.state == ChallengeState.OPEN || challenge.state == ChallengeState.PENDING, "Challenge not active"
        );
        require(block.timestamp > challenge.createdTimestamp + timeUntilWithdraw, "Challenge not old enough");

        // Mark as completed
        challenge.state = ChallengeState.COMPLETED;

        // Add entire amount to collected fees (wager + minDuelFee)
        totalFeesCollected += challenge.wagerAmount + minDuelFee;

        emit ChallengeForfeited(challengeId, challenge.wagerAmount + minDuelFee);
    }

    /// @notice Withdraws accumulated fees (owner only)
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = totalFeesCollected;
        require(amount > 0, "No fees to withdraw");

        totalFeesCollected = 0;

        SafeTransferLib.safeTransferETH(owner, amount);

        emit FeesWithdrawn(amount);
    }

    /// @notice Sets whether wagers are enabled
    /// @param enabled The new wager enabled state
    function setWagersEnabled(bool enabled) external onlyOwner {
        wagersEnabled = enabled;
        emit WagersEnabledUpdated(enabled);
    }

    /// @notice Updates the time until a challenge expires
    /// @param newValue The new time until expire
    function setTimeUntilExpire(uint256 newValue) external onlyOwner {
        require(newValue > 0, "Value must be positive");
        emit TimeUntilExpireUpdated(timeUntilExpire, newValue);
        timeUntilExpire = newValue;
    }

    /// @notice Updates the time until an abandoned challenge can be withdrawn
    /// @param newValue The new time until withdraw
    function setTimeUntilWithdraw(uint256 newValue) external onlyOwner {
        require(newValue > 0, "Value must be positive");
        emit TimeUntilWithdrawUpdated(timeUntilWithdraw, newValue);
        timeUntilWithdraw = newValue;
    }

    /// @notice Updates the timeout period for VRF requests
    /// @param newValue The new timeout period in seconds
    function setVrfRequestTimeout(uint256 newValue) external onlyOwner {
        require(newValue > 0, "Value must be positive");
        emit VrfRequestTimeoutUpdated(vrfRequestTimeout, newValue);
        vrfRequestTimeout = newValue;
    }

    //==============================================================//
    //                    INTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Processes VRF randomness fulfillment
    /// @param randomness The random value from VRF
    /// @param requestId ID of the VRF request
    function _fulfillRandomness(uint256 randomness, uint256 requestId, bytes memory /* extraData */ )
        internal
        override
    {
        uint256 challengeId = requestToChallengeId[requestId];
        DuelChallenge storage challenge = challenges[challengeId];
        require(isChallengePending(challengeId), "Challenge not pending");

        // Clear state FIRST
        delete requestToChallengeId[requestId];
        challenge.state = ChallengeState.COMPLETED; // Prevent re-entry

        // THEN do external calls
        require(!playerContract.isPlayerRetired(challenge.challengerId), "Challenger is retired");
        require(!playerContract.isPlayerRetired(challenge.defenderId), "Defender is retired");

        // Create a new random seed by combining VRF randomness with request data
        uint256 combinedSeed = uint256(keccak256(abi.encodePacked(randomness, requestId)));

        // Get player stats and update with loadout-specific skin choices
        IPlayer.PlayerStats memory challengerStats = playerContract.getPlayer(challenge.challengerId);
        challengerStats.skin = Fighter.SkinInfo({
            skinIndex: challenge.challengerLoadout.skin.skinIndex,
            skinTokenId: challenge.challengerLoadout.skin.skinTokenId
        });
        challengerStats.stance = challenge.challengerLoadout.stance;

        IPlayer.PlayerStats memory defenderStats = playerContract.getPlayer(challenge.defenderId);
        defenderStats.skin = Fighter.SkinInfo({
            skinIndex: challenge.defenderLoadout.skin.skinIndex,
            skinTokenId: challenge.defenderLoadout.skin.skinTokenId
        });
        defenderStats.stance = challenge.defenderLoadout.stance;

        // Get challenger skin attributes
        IPlayerSkinRegistry.SkinCollectionInfo memory challengerSkinInfo =
            playerContract.skinRegistry().getSkin(challengerStats.skin.skinIndex);
        IPlayerSkinNFT.SkinAttributes memory challengerAttrs =
            IPlayerSkinNFT(challengerSkinInfo.contractAddress).getSkinAttributes(challengerStats.skin.skinTokenId);

        // Get defender skin attributes
        IPlayerSkinRegistry.SkinCollectionInfo memory defenderSkinInfo =
            playerContract.skinRegistry().getSkin(defenderStats.skin.skinIndex);
        IPlayerSkinNFT.SkinAttributes memory defenderAttrs =
            IPlayerSkinNFT(defenderSkinInfo.contractAddress).getSkinAttributes(defenderStats.skin.skinTokenId);

        // Create FighterStats
        IGameEngine.FighterStats memory challengerCombat = IGameEngine.FighterStats({
            weapon: challengerAttrs.weapon,
            armor: challengerAttrs.armor,
            stance: challenge.challengerLoadout.stance,
            attributes: challengerStats.attributes
        });

        // Create FighterStats
        IGameEngine.FighterStats memory defenderCombat = IGameEngine.FighterStats({
            weapon: defenderAttrs.weapon,
            armor: defenderAttrs.armor,
            stance: challenge.defenderLoadout.stance,
            attributes: defenderStats.attributes
        });

        // Execute the duel with the random seed
        bytes memory results = gameEngine.processGame(challengerCombat, defenderCombat, combinedSeed, 0);

        // Use GameEngine's decode method instead of manual unpacking
        (bool player1Won, uint16 version, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions)
        = gameEngine.decodeCombatLog(results);

        // Determine winner and loser IDs based on player1Won
        uint32 winnerId = player1Won ? challenge.challengerId : challenge.defenderId;
        uint32 loserId = player1Won ? challenge.defenderId : challenge.challengerId;

        // Emit combat results with packed player data
        emit CombatResult(
            IPlayer(playerContract).encodePlayerData(challenge.challengerId, challengerStats),
            IPlayer(playerContract).encodePlayerData(challenge.defenderId, defenderStats),
            winnerId,
            results
        );

        uint256 winnerPayout = 0;
        uint256 totalWager = challenge.wagerAmount * 2;
        uint256 fee = calculateFee(totalWager);

        // Add fee to collected fees
        totalFeesCollected += fee;

        if (challenge.wagerAmount > 0) {
            // Winner gets total wager minus fee
            winnerPayout = totalWager - fee;

            // Get winner's address
            address winner = IPlayer(playerContract).getPlayerOwner(winnerId);

            // Verify contract has enough ETH before transferring
            require(address(this).balance >= winnerPayout, "Insufficient contract balance for payout");

            // Safely transfer the winnings
            SafeTransferLib.safeTransferETH(winner, winnerPayout);
        }

        // Update player stats
        IPlayer(playerContract).incrementWins(winnerId);
        IPlayer(playerContract).incrementLosses(loserId);

        // Emit economic results
        emit DuelComplete(challengeId, winnerId, randomness, winnerPayout, fee);
    }

    /// @notice Checks if a player ID is supported in Duel mode
    /// @param playerId The ID to check
    /// @return True if player ID is supported
    function _isPlayerIdSupported(uint32 playerId) internal pure override returns (bool) {
        // Only regular players are supported in Duel mode
        return playerId > MONSTER_END;
    }

    /// @notice Gets the fighter contract for a player ID
    /// @param playerId The ID to check
    /// @return Fighter contract implementation
    function _getFighterContract(uint32 playerId) internal view override returns (Fighter) {
        require(_isPlayerIdSupported(playerId), "Unsupported player ID for Duel mode");
        return Fighter(address(playerContract));
    }

    //==============================================================//
    //                    FALLBACK FUNCTIONS                        //
    //==============================================================//
    /// @notice Allows contract to receive ETH
    receive() external payable {
        totalFeesCollected += msg.value;
    }
}

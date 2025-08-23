// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import "./BaseGame.sol";
import "solmate/src/utils/ReentrancyGuard.sol";
import "solmate/src/utils/SafeTransferLib.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "../../lib/UniformRandomNumber.sol";
import "../../interfaces/game/engine/IGameEngine.sol";

//==============================================================//
//                         INTERFACES                           //
//==============================================================//
/// @notice Interface for PlayerTickets contract functions needed by DuelGame
interface IPlayerTickets {
    function DUEL_TICKET() external view returns (uint256);
    function burnFrom(address from, uint256 tokenId, uint256 amount) external;
}

//==============================================================//
//                         HEAVY HELMS                          //
//                          DUEL GAME                           //
//==============================================================//
/// @title Duel Game Mode for Heavy Helms
/// @notice Allows players to challenge each other to 1v1 combat
/// @dev Integrates with VRF for fair, random combat resolution
contract DuelGame is BaseGame, ReentrancyGuard, VRFConsumerBaseV2Plus {
    using UniformRandomNumber for uint256;

    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    // Constants
    /// @notice Timeout period in seconds after which a VRF request can be considered failed
    uint256 public vrfRequestTimeout = 24 hours;
    /// @notice Time (in seconds) after which a challenge expires
    uint256 public timeUntilExpire = 7 days; // 7 days
    /// @notice Chainlink VRF configuration
    uint256 public subscriptionId;
    bytes32 public keyHash;
    uint32 public callbackGasLimit = 2_000_000;
    uint16 public requestConfirmations = 3;
    /// @notice Player tickets contract for burning duel tickets
    IPlayerTickets public playerTickets;

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
    /// @param createdBlock Block number when challenge was created
    /// @param createdTimestamp Timestamp when challenge was created
    /// @param challengerLoadout Loadout of the challenger player
    /// @param defenderLoadout Loadout of the defender player
    /// @param state State of the challenge
    /// @param vrfRequestTimestamp When VRF was requested (set at acceptance time)
    struct DuelChallenge {
        uint32 challengerId;
        uint32 defenderId;
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
    /// @notice Maps challenge IDs to their challenge data
    mapping(uint256 => DuelChallenge) public challenges;
    /// @notice Maps VRF request IDs to challenge IDs
    /// @dev This mapping connects the random outcomes from Gelato VRF to their corresponding challenges
    /// It's necessary because challenges are created before randomness is requested
    mapping(uint256 => uint256) public requestToChallengeId;

    /// @notice Overall game enabled state
    bool public isGameEnabled = true;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a new challenge is created
    event ChallengeCreated(
        uint256 indexed challengeId,
        uint32 indexed challengerId,
        uint32 indexed defenderId,
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
    /// @notice Emitted when a duel is completed
    event DuelComplete(uint256 indexed challengeId, uint32 indexed winnerId, uint256 randomness);
    /// @notice Emitted when game enabled state is updated
    event GameEnabledUpdated(bool enabled);
    /// @notice Emitted when time until expire is updated
    event TimeUntilExpireUpdated(uint256 oldValue, uint256 newValue);
    /// @notice Emitted when a challenge is recovered from a VRF timeout
    event ChallengeRecovered(uint256 indexed challengeId);
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
    /// @param vrfCoordinator Address of the Chainlink VRF coordinator
    /// @param _subscriptionId Chainlink VRF subscription ID
    /// @param _keyHash Chainlink VRF key hash for the gas lane
    /// @param _playerTickets Address of the player tickets contract
    constructor(
        address _gameEngine,
        address payable _playerContract,
        address vrfCoordinator,
        uint256 _subscriptionId,
        bytes32 _keyHash,
        address _playerTickets
    ) BaseGame(_gameEngine, _playerContract) VRFConsumerBaseV2Plus(vrfCoordinator) {
        require(_playerTickets != address(0), "Invalid player tickets address");
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        playerTickets = IPlayerTickets(_playerTickets);
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//

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

    /// @notice Creates a new duel challenge
    /// @param challengerLoadout Loadout for the challenger
    /// @param defenderId ID of the defender
    /// @return challengeId ID of the created challenge
    function initiateChallenge(Fighter.PlayerLoadout calldata challengerLoadout, uint32 defenderId)
        external
        whenGameEnabled
        nonReentrant
        returns (uint256)
    {
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

        // Verify players are not retired
        require(!playerContract.isPlayerRetired(challengerLoadout.playerId), "Challenger is retired");
        require(!playerContract.isPlayerRetired(defenderId), "Defender is retired");

        // Burn duel ticket from challenger - duels require tickets to prevent spam
        playerTickets.burnFrom(msg.sender, playerTickets.DUEL_TICKET(), 1);

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
        nonReentrant
    {
        DuelChallenge storage challenge = challenges[challengeId];

        // Validate challenge state
        require(isChallengeActive(challengeId), "Challenge not active");

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
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}))
            })
        );
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

        emit ChallengeRecovered(challengeId);
    }

    //==============================================================//
    //                     ADMIN FUNCTIONS                          //
    //==============================================================//

    /// @notice Sets whether the game is enabled
    /// @param enabled The new enabled state
    function setGameEnabled(bool enabled) external onlyOwner {
        emit GameEnabledUpdated(enabled);
        isGameEnabled = enabled;
    }

    /// @notice Updates the time until a challenge expires
    /// @param newValue The new time until expire
    function setTimeUntilExpire(uint256 newValue) external onlyOwner {
        require(newValue > 0, "Value must be positive");
        emit TimeUntilExpireUpdated(timeUntilExpire, newValue);
        timeUntilExpire = newValue;
    }

    /// @notice Updates the timeout period for VRF requests
    /// @param newValue The new timeout period in seconds
    function setVrfRequestTimeout(uint256 newValue) external onlyOwner {
        require(newValue > 0, "Value must be positive");
        emit VrfRequestTimeoutUpdated(vrfRequestTimeout, newValue);
        vrfRequestTimeout = newValue;
    }

    /// @notice Withdraws all accumulated ETH to the owner address
    function withdrawFees() external onlyOwner {
        SafeTransferLib.safeTransferETH(owner, address(this).balance);
    }

    //==============================================================//
    //                    INTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Processes VRF randomness fulfillment
    /// @param requestId ID of the VRF request
    /// @param randomWords Array of random values from VRF (we only use the first one)
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 challengeId = requestToChallengeId[requestId];
        DuelChallenge storage challenge = challenges[challengeId];
        require(isChallengePending(challengeId), "Challenge not pending");

        // Clear state FIRST
        delete requestToChallengeId[requestId];
        challenge.state = ChallengeState.COMPLETED; // Prevent re-entry

        // THEN do external calls
        require(!playerContract.isPlayerRetired(challenge.challengerId), "Challenger is retired");
        require(!playerContract.isPlayerRetired(challenge.defenderId), "Defender is retired");
        
        uint256 randomness = randomWords[0];

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

        // Get challenger skin attributes and construct FighterStats
        IPlayerSkinNFT.SkinAttributes memory challengerSkinAttrs =
            Fighter(address(playerContract)).getSkinAttributes(challengerStats.skin);
        IGameEngine.FighterStats memory challengerCombat = IGameEngine.FighterStats({
            weapon: challengerSkinAttrs.weapon,
            armor: challengerSkinAttrs.armor,
            stance: challengerStats.stance,
            attributes: challengerStats.attributes,
            level: challengerStats.level,
            weaponSpecialization: challengerStats.weaponSpecialization,
            armorSpecialization: challengerStats.armorSpecialization
        });

        // Get defender skin attributes and construct FighterStats
        IPlayerSkinNFT.SkinAttributes memory defenderSkinAttrs =
            Fighter(address(playerContract)).getSkinAttributes(defenderStats.skin);
        IGameEngine.FighterStats memory defenderCombat = IGameEngine.FighterStats({
            weapon: defenderSkinAttrs.weapon,
            armor: defenderSkinAttrs.armor,
            stance: defenderStats.stance,
            attributes: defenderStats.attributes,
            level: defenderStats.level,
            weaponSpecialization: defenderStats.weaponSpecialization,
            armorSpecialization: defenderStats.armorSpecialization
        });

        // Get seasonal records BEFORE the fight (for historical accuracy)
        Fighter.Record memory challengerRecord = IPlayer(playerContract).getCurrentSeasonRecord(challenge.challengerId);
        Fighter.Record memory defenderRecord = IPlayer(playerContract).getCurrentSeasonRecord(challenge.defenderId);

        // Execute the duel with the random seed
        bytes memory results = gameEngine.processGame(challengerCombat, defenderCombat, combinedSeed, 0);

        // Use GameEngine's decode method instead of manual unpacking
        (bool player1Won,,,) = gameEngine.decodeCombatLog(results);

        // Determine winner and loser IDs based on player1Won
        uint32 winnerId = player1Won ? challenge.challengerId : challenge.defenderId;

        // Emit combat results with packed player data
        emit CombatResult(
            IPlayer(playerContract).codec().encodePlayerData(challenge.challengerId, challengerStats, challengerRecord),
            IPlayer(playerContract).codec().encodePlayerData(challenge.defenderId, defenderStats, defenderRecord),
            winnerId,
            results
        );

        // Duels no longer update win/loss records - they're just for flexing!

        // Emit results
        emit DuelComplete(challengeId, winnerId, randomness);
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
    /// @notice Allows contract to receive ETH for VRF funding
    receive() external payable {}
}

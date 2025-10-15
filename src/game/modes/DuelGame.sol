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
import {BaseGame} from "./BaseGame.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IGameEngine} from "../../interfaces/game/engine/IGameEngine.sol";
import {IPlayer} from "../../interfaces/fighters/IPlayer.sol";
import {Fighter} from "../../fighters/Fighter.sol";
import {IPlayerSkinNFT} from "../../interfaces/nft/skins/IPlayerSkinNFT.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
error GameDisabled();
error GasPriceTooHigh();
error InvalidPlayerTicketsAddress();
error InsufficientFeeAmount();
error ChallengeNotActive();
error NotDefender();
error WrongDefenderId();
error NotPlayerOwner();
error DefenderRetired();
error ChallengerRetired();
error CannotDuelYourself();
error ChallengerMustBePlayer();
error DefenderMustBePlayer();
error MustOwnChallengerPlayer();
error ChallengeDoesNotExist();
error ChallengeNotPending();
error NotAuthorized();
error InvalidVrfRequestTimestamp();
error VrfTimeoutNotReached();
error ValueMustBePositive();
error GasPriceMustBePositive();
error UnsupportedPlayerIdForDuelMode();

//==============================================================//
//                         INTERFACES                           //
//=============================================================//
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
contract DuelGame is BaseGame, VRFConsumerBaseV2Plus {
    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    // Constants
    /// @notice Timeout period in seconds after which a VRF request can be considered failed
    uint256 public vrfRequestTimeout = 24 hours;
    /// @notice Chainlink VRF configuration
    uint256 public subscriptionId;
    bytes32 public keyHash;
    uint32 public callbackGasLimit = 2_000_000;
    uint16 public requestConfirmations = 3;
    /// @notice Player tickets contract for burning duel tickets
    IPlayerTickets public playerTickets;
    /// @notice Fee amount in ETH required to start a duel (alternative to ticket)
    uint256 public duelFeeAmount = 0.0001 ether;
    /// @notice Maximum gas price allowed for accepting challenges (in wei)
    uint256 public maxAcceptGasPrice = 100000000; // 0.1 gwei
    /// @notice Whether gas price protection is enabled (true = protection on, false = no protection)
    bool public gasProtectionEnabled = true;

    // Enum
    /// @notice Enum representing the state of a duel challenge
    enum ChallengeState {
        OPEN, // Challenge created but not yet accepted
        PENDING, // Challenge accepted and awaiting VRF result
        COMPLETED // Challenge completed (fulfilled)
    }

    // Structs
    /// @notice Structure storing a duel challenge data
    /// @param challengerId ID of the player issuing the challenge
    /// @param defenderId ID of the player being challenged
    /// @param challengerLoadout Loadout of the challenger player
    /// @param defenderLoadout Loadout of the defender player
    /// @param state State of the challenge
    /// @param vrfRequestTimestamp When VRF was requested (set at acceptance time)
    struct DuelChallenge {
        uint32 challengerId;
        uint32 defenderId;
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
    /// @dev This mapping connects the random outcomes from Chainlink VRF to their corresponding challenges
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
        uint8 challengerStance,
        bool paidWithTicket
    );
    /// @notice Emitted when a challenge is accepted
    event ChallengeAccepted(
        uint256 indexed challengeId,
        uint32 indexed defenderId,
        uint32 defenderSkinIndex,
        uint16 defenderSkinTokenId,
        uint8 defenderStance
    );
    /// @notice Emitted when a duel is completed
    event DuelComplete(uint256 indexed challengeId, uint32 indexed winnerId, uint256 randomness);
    /// @notice Emitted when game enabled state is updated
    event GameEnabledUpdated(bool enabled);
    /// @notice Emitted when a challenge is recovered from a VRF timeout
    event ChallengeRecovered(uint256 indexed challengeId);
    /// @notice Emitted when VRF request timeout is updated
    event VrfRequestTimeoutUpdated(uint256 oldValue, uint256 newValue);
    /// @notice Emitted when duel fee amount is updated
    event DuelFeeAmountUpdated(uint256 oldValue, uint256 newValue);
    /// @notice Emitted when gas protection settings are updated
    event GasProtectionUpdated(bool enabled);
    /// @notice Emitted when max accept gas price is updated
    event MaxAcceptGasPriceUpdated(uint256 oldValue, uint256 newValue);

    //==============================================================//
    //                        MODIFIERS                             //
    //==============================================================//
    /// @notice Ensures game is enabled for function execution
    modifier whenGameEnabled() {
        if (!isGameEnabled) revert GameDisabled();
        _;
    }

    /// @notice Protects against high gas prices when accepting challenges
    modifier gasProtection() {
        if (gasProtectionEnabled && tx.gasprice > maxAcceptGasPrice) revert GasPriceTooHigh();
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
        if (_playerTickets == address(0)) revert InvalidPlayerTicketsAddress();
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        playerTickets = IPlayerTickets(_playerTickets);
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//

    /// @notice Checks if a challenge exists and is in OPEN state
    /// @param challengeId ID of the challenge to check
    /// @return isActive True if challenge exists and is in OPEN state
    function isChallengeActive(uint256 challengeId) public view returns (bool) {
        DuelChallenge storage challenge = challenges[challengeId];
        return challenge.challengerId != 0 && challenge.state == ChallengeState.OPEN;
    }

    /// @notice Checks if a challenge exists and is in PENDING state
    /// @param challengeId ID of the challenge to check
    /// @return isPending True if challenge exists and is in PENDING state
    function isChallengePending(uint256 challengeId) public view returns (bool) {
        DuelChallenge storage challenge = challenges[challengeId];
        return challenge.challengerId != 0 && challenge.state == ChallengeState.PENDING;
    }

    /// @notice Creates a new duel challenge using a DUEL_TICKET
    /// @param challengerLoadout Loadout for the challenger
    /// @param defenderId ID of the defender
    /// @return challengeId ID of the created challenge
    function initiateChallengeWithTicket(Fighter.PlayerLoadout calldata challengerLoadout, uint32 defenderId)
        external
        whenGameEnabled
        returns (uint256)
    {
        // Burn duel ticket from challenger - duels require tickets to prevent spam
        playerTickets.burnFrom(msg.sender, playerTickets.DUEL_TICKET(), 1);
        return _initiateChallenge(challengerLoadout, defenderId, true);
    }

    /// @notice Creates a new duel challenge using ETH payment
    /// @param challengerLoadout Loadout for the challenger
    /// @param defenderId ID of the defender
    /// @return challengeId ID of the created challenge
    function initiateChallengeWithETH(Fighter.PlayerLoadout calldata challengerLoadout, uint32 defenderId)
        external
        payable
        whenGameEnabled
        returns (uint256)
    {
        if (msg.value < duelFeeAmount) revert InsufficientFeeAmount();
        return _initiateChallenge(challengerLoadout, defenderId, false);
    }

    /// @notice Accepts a duel challenge
    /// @param challengeId ID of the challenge to accept
    /// @param defenderLoadout Loadout for the defender
    function acceptChallenge(uint256 challengeId, Fighter.PlayerLoadout calldata defenderLoadout)
        external
        gasProtection
    {
        DuelChallenge storage challenge = challenges[challengeId];

        // Validate challenge state
        if (!isChallengeActive(challengeId)) revert ChallengeNotActive();

        // Check player existence by calling getPlayer (will revert if player doesn't exist)
        IPlayer(playerContract).getPlayer(defenderLoadout.playerId);

        // Verify msg.sender owns the defender
        address defender = IPlayer(playerContract).getPlayerOwner(challenge.defenderId);
        if (msg.sender != defender) revert NotDefender();
        if (defenderLoadout.playerId != challenge.defenderId) revert WrongDefenderId();

        // Validate player ownership and stats
        if (IPlayer(playerContract).getPlayerOwner(defenderLoadout.playerId) != msg.sender) revert NotPlayerOwner();
        if (IPlayer(playerContract).isPlayerRetired(defenderLoadout.playerId)) revert DefenderRetired();
        if (IPlayer(playerContract).isPlayerRetired(challenge.challengerId)) revert ChallengerRetired();

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
        IPlayer(playerContract).skinRegistry()
            .validateSkinRequirements(
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

    /// @notice Allows players to recover from a timed-out VRF request
    /// @param challengeId ID of the challenge to recover
    function recoverTimedOutVRF(uint256 challengeId) external {
        DuelChallenge storage challenge = challenges[challengeId];

        // Verify challenge exists and is in PENDING state
        if (challenge.challengerId == 0) revert ChallengeDoesNotExist();
        if (challenge.state != ChallengeState.PENDING) revert ChallengeNotPending();

        // Get player addresses early
        address challenger = IPlayer(playerContract).getPlayerOwner(challenge.challengerId);
        address defender = IPlayer(playerContract).getPlayerOwner(challenge.defenderId);

        // Require caller to be either challenger or defender
        if (msg.sender != challenger && msg.sender != defender) revert NotAuthorized();

        // Verify that VRF request timestamp is non-zero
        if (challenge.vrfRequestTimestamp == 0) revert InvalidVrfRequestTimestamp();

        // Check if enough time has passed since VRF was requested
        if (block.timestamp < challenge.vrfRequestTimestamp + vrfRequestTimeout) revert VrfTimeoutNotReached();

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

    /// @notice Updates the timeout period for VRF requests
    /// @param newValue The new timeout period in seconds
    function setVrfRequestTimeout(uint256 newValue) external onlyOwner {
        if (newValue == 0) revert ValueMustBePositive();
        emit VrfRequestTimeoutUpdated(vrfRequestTimeout, newValue);
        vrfRequestTimeout = newValue;
    }

    /// @notice Updates the fee required to start a duel with ETH
    /// @param newFeeAmount The new fee amount in ETH
    function setDuelFeeAmount(uint256 newFeeAmount) external onlyOwner {
        emit DuelFeeAmountUpdated(duelFeeAmount, newFeeAmount);
        duelFeeAmount = newFeeAmount;
    }

    /// @notice Enables or disables gas price protection for accepting challenges
    /// @param enabled Whether gas protection should be enabled
    function setGasProtectionEnabled(bool enabled) external onlyOwner {
        gasProtectionEnabled = enabled;
        emit GasProtectionUpdated(enabled);
    }

    /// @notice Updates the maximum gas price allowed for accepting challenges
    /// @param newMaxGasPrice The new maximum gas price in wei
    function setMaxAcceptGasPrice(uint256 newMaxGasPrice) external onlyOwner {
        if (newMaxGasPrice == 0) revert GasPriceMustBePositive();
        emit MaxAcceptGasPriceUpdated(maxAcceptGasPrice, newMaxGasPrice);
        maxAcceptGasPrice = newMaxGasPrice;
    }

    /// @notice Withdraws all accumulated ETH to the owner address
    function withdrawFees() external onlyOwner {
        SafeTransferLib.safeTransferETH(owner(), address(this).balance);
    }

    /// @notice Sets a new game engine address
    /// @param _newEngine Address of the new game engine
    /// @dev Only callable by the contract owner
    function setGameEngine(address _newEngine) public override(BaseGame) onlyOwner {
        super.setGameEngine(_newEngine);
    }

    //==============================================================//
    //                    INTERNAL FUNCTIONS                        //
    //==============================================================//

    /// @notice Internal function to create a duel challenge
    /// @param challengerLoadout Loadout for the challenger
    /// @param defenderId ID of the defender
    /// @param paidWithTicket Whether the challenge was paid for with a ticket
    /// @return challengeId ID of the created challenge
    function _initiateChallenge(
        Fighter.PlayerLoadout calldata challengerLoadout,
        uint32 defenderId,
        bool paidWithTicket
    ) internal returns (uint256) {
        if (challengerLoadout.playerId == defenderId) revert CannotDuelYourself();
        if (address(_getFighterContract(challengerLoadout.playerId)) != address(playerContract)) {
            revert ChallengerMustBePlayer();
        }
        if (address(_getFighterContract(defenderId)) != address(playerContract)) revert DefenderMustBePlayer();
        if (IPlayer(playerContract).getPlayerOwner(challengerLoadout.playerId) != msg.sender) {
            revert MustOwnChallengerPlayer();
        }

        // Check player existence by calling getPlayer (will revert if player doesn't exist)
        IPlayer(playerContract).getPlayer(challengerLoadout.playerId);
        IPlayer(playerContract).getPlayer(defenderId);

        // Verify players are not retired
        if (playerContract.isPlayerRetired(challengerLoadout.playerId)) revert ChallengerRetired();
        if (playerContract.isPlayerRetired(defenderId)) revert DefenderRetired();

        // Validate skin ownership and requirements
        address owner = IPlayer(playerContract).getPlayerOwner(challengerLoadout.playerId);
        IPlayer(playerContract).skinRegistry().validateSkinOwnership(challengerLoadout.skin, owner);
        IPlayer(playerContract).skinRegistry()
            .validateSkinRequirements(
                challengerLoadout.skin,
                IPlayer(playerContract).getPlayer(challengerLoadout.playerId).attributes,
                IPlayer(playerContract).equipmentRequirements()
            );

        // Create challenge
        uint256 challengeId = nextChallengeId++;
        challenges[challengeId] = DuelChallenge({
            challengerId: challengerLoadout.playerId,
            defenderId: defenderId,
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
            challengerLoadout.stance,
            paidWithTicket
        );

        return challengeId;
    }

    /// @notice Processes VRF randomness fulfillment
    /// @param requestId ID of the VRF request
    /// @param randomWords Array of random values from VRF (we only use the first one)
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 challengeId = requestToChallengeId[requestId];
        DuelChallenge storage challenge = challenges[challengeId];
        if (!isChallengePending(challengeId)) revert ChallengeNotPending();

        // Clear state FIRST
        delete requestToChallengeId[requestId];
        challenge.state = ChallengeState.COMPLETED; // Prevent re-entry

        // THEN do external calls
        if (playerContract.isPlayerRetired(challenge.challengerId)) revert ChallengerRetired();
        if (playerContract.isPlayerRetired(challenge.defenderId)) revert DefenderRetired();

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
            skinIndex: challenge.defenderLoadout.skin.skinIndex, skinTokenId: challenge.defenderLoadout.skin.skinTokenId
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
        if (!_isPlayerIdSupported(playerId)) revert UnsupportedPlayerIdForDuelMode();
        return Fighter(address(playerContract));
    }

    //==============================================================//
    //                    FALLBACK FUNCTIONS                        //
    //==============================================================//
    /// @notice Allows contract to receive ETH for VRF funding
    receive() external payable {}
}

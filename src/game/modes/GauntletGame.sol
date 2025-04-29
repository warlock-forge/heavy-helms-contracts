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
import "vrf-contracts/contracts/GelatoVRFConsumerBase.sol";
import "../../lib/UniformRandomNumber.sol";
import "../../interfaces/game/engine/IGameEngine.sol";
import "../../interfaces/fighters/IPlayer.sol";
import "../../interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";
import "../../interfaces/nft/skins/IPlayerSkinNFT.sol";
import "../../fighters/Fighter.sol";
import "../../interfaces/fighters/IDefaultPlayer.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
error GauntletDoesNotExist();
error PlayerNotInQueue();
error AlreadyInQueue();
error PlayerIsRetired();
error InvalidLoadout();
error InvalidSkin();
error CallerNotPlayerOwner();
error GauntletNotPending();
error GameDisabled();
error InvalidGauntletSize(uint8 size);
error QueueNotEmpty();
error IncorrectEntryFee(uint256 expected, uint256 actual);
error InvalidDefaultPlayerRange();
error TimeoutNotReached();
error NoFeesToWithdraw();
error UnsupportedPlayerId();
error InsufficientQueueSize(uint256 current, uint8 required);
error MinTimeNotElapsed();

//==============================================================//
//                         HEAVY HELMS                          //
//                         GAUNTLET GAME                        //
//==============================================================//
/// @title Gauntlet Game Mode for Heavy Helms
/// @notice Manages a queue of players and triggers elimination brackets (Gauntlets)
///         of dynamic size (8, 16, or 32) with a dynamic entry fee.
/// @dev Relies on a trusted off-chain runner and Gelato VRF for randomness.
///      VRF fulfillment and potentially the queue clearing in setEntryFee can be gas-intensive.
contract GauntletGame is BaseGame, ReentrancyGuard, GelatoVRFConsumerBase {
    //==============================================================//
    //                          ENUMS                               //
    //==============================================================//
    /// @notice Represents the state of a Gauntlet run.
    enum GauntletState {
        PENDING, // Gauntlet started, awaiting VRF result or recovery.
        COMPLETED // Gauntlet finished normally or recovered after timeout.

    }

    /// @notice Represents the current status of a player in relation to the Gauntlet mode.
    enum PlayerStatus {
        NONE, // Not participating.
        QUEUED, // Waiting in the queue.
        IN_GAUNTLET // Actively participating in a Gauntlet run.

    }

    //==============================================================//
    //                         STRUCTS                              //
    //==============================================================//
    /// @notice Structure storing data for a specific Gauntlet run instance.
    /// @param id Unique identifier for the Gauntlet.
    /// @param size Number of participants (8, 16, or 32).
    /// @param entryFee The entry fee required for this Gauntlet.
    /// @param state Current state of the Gauntlet (PENDING or COMPLETED).
    /// @param vrfRequestId The ID of the VRF request associated with this Gauntlet.
    /// @param vrfRequestTimestamp Timestamp when the VRF request was initiated.
    /// @param completionTimestamp Timestamp when the Gauntlet was completed or recovered.
    /// @param participants Array of players registered for this Gauntlet, including their loadouts.
    /// @param winners Array storing the winner ID of each match (size - 1 elements).
    /// @param championId The ID of the final Gauntlet winner.
    struct Gauntlet {
        uint256 id;
        uint8 size;
        uint256 entryFee;
        GauntletState state;
        uint256 vrfRequestId;
        uint256 vrfRequestTimestamp;
        uint256 completionTimestamp;
        RegisteredPlayer[] participants;
        uint32[] winners; // Stores winners of each round except the final
        uint32 championId;
    }

    /// @notice Compact struct storing participant data within a Gauntlet.
    /// @param playerId The ID of the registered player.
    /// @param loadout The loadout the player used for this Gauntlet.
    struct RegisteredPlayer {
        uint32 playerId;
        Fighter.PlayerLoadout loadout;
    }

    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//

    // --- Configuration & Roles ---
    /// @notice Contract managing default player data.
    IDefaultPlayer public defaultPlayerContract;
    address private _operatorAddress;
    uint256 public vrfRequestTimeout = 4 hours;
    bool public isGameEnabled = true;
    uint256 public minTimeBetweenGauntlets = 30 minutes;
    uint256 public lastGauntletStartTime;

    // --- Dynamic Settings ---
    /// @notice Current entry fee in wei required to join the queue.
    uint256 public currentEntryFee = 0 ether;
    /// @notice Current number of participants required to start a Gauntlet (8, 16, or 32).
    uint8 public currentGauntletSize = 8;
    /// @notice The maximum ID used when randomly substituting retired players with defaults.
    /// @dev Must be kept in sync with the highest valid ID in the `DefaultPlayer` contract.
    uint32 public maxDefaultPlayerSubstituteId = 18;
    /// @notice Percentage fee (basis points) taken from the total prize pool of each completed gauntlet.
    uint256 public feePercentage = 1000; // 10.00%

    // --- Gauntlet State ---
    /// @notice Counter for assigning unique Gauntlet IDs.
    uint256 public nextGauntletId;
    /// @notice Maps Gauntlet IDs to their detailed `Gauntlet` struct data.
    mapping(uint256 => Gauntlet) public gauntlets;
    /// @notice Maps VRF request IDs back to their corresponding Gauntlet ID.
    mapping(uint256 => uint256) public requestToGauntletId;

    // --- Queue State ---
    /// @notice Stores loadout data for players currently in the queue.
    mapping(uint32 => Fighter.PlayerLoadout) public registrationQueue;
    /// @notice Array containing the IDs of players currently in the queue. Order matters for swap-and-pop removal.
    uint32[] public queueIndex;
    /// @notice Maps player IDs to their (1-based) index within the `queueIndex` array for O(1) lookup during removal. 0 if not in queue.
    mapping(uint32 => uint256) public playerIndexInQueue;

    // --- Player State ---
    /// @notice Tracks the current status (NONE, QUEUED, IN_GAUNTLET) of a player.
    mapping(uint32 => PlayerStatus) public playerStatus;
    /// @notice If status is IN_GAUNTLET, maps player ID to the `gauntletId` they are participating in.
    mapping(uint32 => uint256) public playerCurrentGauntlet;

    // --- Fees ---
    /// @notice Holds entry fees paid by players currently waiting in the queue.
    uint256 public queuedFeesPool;
    /// @notice Fees collected by the contract owner from completed/recovered gauntlets and default player wins.
    uint256 public contractFeesCollected;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a player successfully joins the queue.
    event PlayerQueued(uint32 indexed playerId, uint256 queueSize, uint256 entryFee);
    /// @notice Emitted when a player successfully withdraws from the queue.
    event PlayerWithdrew(uint32 indexed playerId, uint256 queueSize);
    /// @notice Emitted when a new Gauntlet run is started by the off-chain runner.
    event GauntletStarted(
        uint256 indexed gauntletId, uint8 size, uint256 entryFee, uint32[] participantIds, uint256 vrfRequestId
    );
    /// @notice Emitted when a Gauntlet is successfully completed via VRF fulfillment.
    // Amount added to contractFeesCollected for this gauntlet
    event GauntletCompleted( // Amount paid to winner (0 if default player wins)
        uint256 indexed gauntletId,
        uint8 size,
        uint256 entryFee,
        uint32 indexed championId,
        uint256 prizeAwarded,
        uint256 feeCollected
    );
    /// @notice Emitted when a pending Gauntlet is recovered after VRF timeout.
    event GauntletRecovered(uint256 indexed gauntletId);
    /// @notice Emitted when the contract owner withdraws accumulated fees.
    event FeesWithdrawn(uint256 amount);
    /// @notice Emitted when the default player contract address is updated.
    event DefaultPlayerContractSet(address indexed newContract);
    /// @notice Emitted when the Gauntlet entry fee is changed.
    event EntryFeeSet(uint256 oldFee, uint256 newFee);
    /// @notice Emitted when the Gauntlet size (participant count) is changed.
    event GauntletSizeSet(uint8 oldSize, uint8 newSize);
    /// @notice Emitted when the queue is cleared due to `setEntryFee` being called with `refundPlayers=true`.
    event QueueClearedDueToSettingsChange(uint256 playersRefunded, uint256 totalRefunded);
    /// @notice Emitted when the maximum default player ID for substitutions is updated.
    event MaxDefaultPlayerSubstituteIdSet(uint32 newMaxId);
    /// @notice Emitted when the minimum time required between starting gauntlets is updated.
    event MinTimeBetweenGauntletsSet(uint256 newMinTime);
    /// @notice Emitted when the Gelato VRF operator address is updated.
    event OperatorSet(address indexed newOperator);
    /// @notice Emitted when the gauntlet fee percentage is updated.
    event FeePercentageSet(uint256 oldPercentage, uint256 newPercentage);
    // Inherited from BaseGame: event CombatResult(bytes32 indexed player1Data, bytes32 indexed player2Data, uint32 winnerId, bytes combatLog);
    /// @notice Emitted when the game enabled state is updated.
    event GameEnabledUpdated(bool enabled);
    /// @notice Emitted when the queue is cleared due to the game being disabled.
    event QueueClearedDueToGameDisabled(uint256 playersRefunded, uint256 totalRefunded);

    //==============================================================//
    //                        MODIFIERS                             //
    //==============================================================//
    /// @notice Ensures the game is not disabled before proceeding. Reverts with `GameDisabled` otherwise.
    modifier whenGameEnabled() {
        if (!isGameEnabled) revert GameDisabled();
        _;
    }

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    /// @notice Initializes the GauntletGame contract.
    /// @param _gameEngine Address of the `GameEngine` contract.
    /// @param _playerContract Address of the `Player` contract.
    /// @param _defaultPlayerAddress Address of the `DefaultPlayer` contract.
    /// @param _operatorAddr Address of the Gelato VRF operator.
    constructor(address _gameEngine, address _playerContract, address _defaultPlayerAddress, address _operatorAddr)
        BaseGame(_gameEngine, _playerContract)
        GelatoVRFConsumerBase()
    {
        // Input validation
        if (_operatorAddr == address(0)) revert ZeroAddress();
        if (_defaultPlayerAddress == address(0)) revert ZeroAddress();
        if (maxDefaultPlayerSubstituteId == 0) revert InvalidDefaultPlayerRange(); // Ensure initial value is valid

        // Set initial state (operator is no longer immutable)
        _operatorAddress = _operatorAddr;
        defaultPlayerContract = IDefaultPlayer(_defaultPlayerAddress);
        lastGauntletStartTime = block.timestamp; // Initialize to deployment time

        // Emit initial settings (optional, but good practice)
        emit DefaultPlayerContractSet(_defaultPlayerAddress);
        emit EntryFeeSet(0, currentEntryFee);
        emit GauntletSizeSet(0, currentGauntletSize);
        emit MaxDefaultPlayerSubstituteIdSet(maxDefaultPlayerSubstituteId);
        emit MinTimeBetweenGauntletsSet(minTimeBetweenGauntlets);
        emit OperatorSet(_operatorAddr); // Emit initial operator address
        emit FeePercentageSet(0, feePercentage); // Emit initial fee percentage
    }

    //==============================================================//
    //                 GELATO VRF CONFIGURATION                     //
    //==============================================================//
    /// @notice Returns the operator address for VRF. Required by `GelatoVRFConsumerBase`.
    /// @return operator Address of the Gelato VRF operator.
    function _operator() internal view override returns (address) {
        return _operatorAddress;
    }

    //==============================================================//
    //                       QUEUE MANAGEMENT                       //
    //==============================================================//

    /// @notice Allows a player owner to join the Gauntlet queue with a specific loadout.
    /// @param loadout The player's chosen skin and stance for the potential Gauntlet.
    /// @dev Requires payment equal to `currentEntryFee`. Validates player status, ownership, retirement status, and skin requirements.
    function queueForGauntlet(Fighter.PlayerLoadout calldata loadout) external payable whenGameEnabled nonReentrant {
        // Checks
        if (playerStatus[loadout.playerId] != PlayerStatus.NONE) revert AlreadyInQueue();
        address owner = playerContract.getPlayerOwner(loadout.playerId);
        if (msg.sender != owner) revert CallerNotPlayerOwner();
        if (playerContract.isPlayerRetired(loadout.playerId)) revert PlayerIsRetired();
        if (msg.value != currentEntryFee) revert IncorrectEntryFee(currentEntryFee, msg.value);

        // Validate skin and equipment requirements via Player contract registries
        try playerContract.skinRegistry().validateSkinOwnership(loadout.skin, owner) {}
        catch {
            revert InvalidSkin();
        }
        try playerContract.skinRegistry().validateSkinRequirements(
            loadout.skin, playerContract.getPlayer(loadout.playerId).attributes, playerContract.equipmentRequirements()
        ) {} catch {
            revert InvalidLoadout();
        }

        // Effects
        queuedFeesPool += msg.value;
        uint32 playerId = loadout.playerId;
        registrationQueue[playerId] = loadout;
        queueIndex.push(playerId);
        playerIndexInQueue[playerId] = queueIndex.length; // 1-based index
        playerStatus[playerId] = PlayerStatus.QUEUED;

        // Interactions (Event Emission)
        emit PlayerQueued(playerId, queueIndex.length, currentEntryFee);
    }

    /// @notice Allows a player owner to withdraw their player from the queue before a Gauntlet starts.
    /// @param playerId The ID of the player to withdraw.
    /// @dev Refunds the `currentEntryFee` paid upon queuing. Uses swap-and-pop to maintain queue integrity.
    function withdrawFromQueue(uint32 playerId) external nonReentrant {
        // Checks
        address owner = playerContract.getPlayerOwner(playerId);
        if (msg.sender != owner) revert CallerNotPlayerOwner();
        if (playerStatus[playerId] != PlayerStatus.QUEUED) revert PlayerNotInQueue();

        // Effects - update fee pool and player state *before* transfer
        uint256 refundAmount = currentEntryFee;
        queuedFeesPool -= refundAmount;
        _removePlayerFromQueueArrayIndex(playerId); // Handles swap-and-pop and mapping updates
        delete registrationQueue[playerId];
        playerStatus[playerId] = PlayerStatus.NONE;

        // Interactions - transfer ETH and emit event
        SafeTransferLib.safeTransferETH(payable(msg.sender), refundAmount); // Send refund to owner (msg.sender)
        emit PlayerWithdrew(playerId, queueIndex.length);
    }

    /// @notice Returns the current number of players waiting in the queue.
    /// @return The number of players in `queueIndex`.
    function getQueueSize() external view returns (uint256) {
        return queueIndex.length;
    }

    /// @notice Returns the loadout for a player from the queue.
    /// @param playerId The ID of the player to retrieve the loadout for.
    /// @return The loadout for the specified player.
    function getPlayerLoadoutFromQueue(uint32 playerId) external view returns (Fighter.PlayerLoadout memory) {
        return registrationQueue[playerId];
    }

    //==============================================================//
    //                 GAUNTLET LIFECYCLE (Triggered Externally)    //
    //==============================================================//

    /// @notice Attempts to start a new Gauntlet if enough time has passed and the queue has enough players.
    /// @dev Callable by anyone (e.g., Gelato Automation). Randomly selects N players from the queue using
    ///      pseudo-randomness derived from block variables. Uses swap-and-pop to remove selected players efficiently.
    ///      WARNING: Random selection and removal can be more gas-intensive than FIFO, especially with large queues.
    function tryStartGauntlet() external whenGameEnabled nonReentrant {
        // Checks
        uint256 requiredTime = lastGauntletStartTime + minTimeBetweenGauntlets;
        if (block.timestamp < requiredTime) {
            // REVERT instead of return
            revert MinTimeNotElapsed();
        }
        uint8 size = currentGauntletSize;
        uint256 currentQueueSize = queueIndex.length;
        if (currentQueueSize < size) {
            // REVERT instead of return
            revert InsufficientQueueSize(currentQueueSize, size);
        }

        // --- Condition met, proceed to start Gauntlet ---

        // Effects - Update timing
        lastGauntletStartTime = block.timestamp; // Prevent re-entry immediately

        // --- Randomly Select Participants ---
        uint32[] memory selectedPlayerIds = new uint32[](size);
        RegisteredPlayer[] memory participantsData = new RegisteredPlayer[](size);
        uint32[] memory availableQueue = new uint32[](currentQueueSize); // Copy queue for selection
        for (uint256 i = 0; i < currentQueueSize; i++) {
            availableQueue[i] = queueIndex[i];
        }

        // Generate pseudo-random seed for selection
        uint256 selectionSeed =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, address(this), currentQueueSize)));
        uint256 remainingToSelect = currentQueueSize; // Track size of availableQueue effectively

        for (uint256 i = 0; i < size; i++) {
            selectionSeed = uint256(keccak256(abi.encodePacked(selectionSeed, i))); // Evolve seed
            uint256 randomIndex = selectionSeed % remainingToSelect; // Index within the *remaining* available players

            uint32 selectedPlayerId = availableQueue[randomIndex];
            selectedPlayerIds[i] = selectedPlayerId;

            // Store participant data in memory
            participantsData[i] =
                RegisteredPlayer({playerId: selectedPlayerId, loadout: registrationQueue[selectedPlayerId]});

            // Remove selected player from available pool using swap-and-pop for the *temporary* array
            availableQueue[randomIndex] = availableQueue[remainingToSelect - 1];
            remainingToSelect--; // Decrease the effective size
        }
        // `selectedPlayerIds` and `participantsData` now hold the randomly chosen participants

        // --- Prepare Gauntlet Struct ---
        uint256 gauntletId = nextGauntletId++;
        uint256 fee = currentEntryFee; // Load into memory

        Gauntlet storage newGauntlet = gauntlets[gauntletId];
        newGauntlet.id = gauntletId;
        newGauntlet.size = size;
        newGauntlet.entryFee = fee;
        newGauntlet.state = GauntletState.PENDING;
        // Participants assigned *after* removal from main queue

        // --- Remove Selected Participants from Actual Queue & Update State ---
        // Now remove the *actually selected* players from the main queue structures
        for (uint256 i = 0; i < size; i++) {
            uint32 playerIdToRemove = selectedPlayerIds[i];

            // Remove player from main queueIndex array & playerIndexInQueue mapping
            // This helper handles the necessary swap-and-pop on the *actual* queueIndex
            _removePlayerFromQueueArrayIndex(playerIdToRemove);

            // Clear registration data and update status
            delete registrationQueue[playerIdToRemove];
            playerStatus[playerIdToRemove] = PlayerStatus.IN_GAUNTLET;
            playerCurrentGauntlet[playerIdToRemove] = gauntletId;
        }

        // Assign selected participants to storage now that removals are done
        newGauntlet.participants = participantsData;

        // --- Request VRF Randomness ---
        newGauntlet.vrfRequestTimestamp = block.timestamp; // Record timestamp *before* request
        uint256 requestId = _requestRandomness(""); // Request randomness from Gelato VRF
        requestToGauntletId[requestId] = gauntletId; // Link VRF request to this gauntlet
        newGauntlet.vrfRequestId = requestId;

        // Interactions (Event Emission)
        emit GauntletStarted(gauntletId, size, fee, selectedPlayerIds, requestId);
    }

    //==============================================================//
    //                    VRF FULFILLMENT                         //
    //==============================================================//
    /// @notice Internal callback function executed by Gelato VRF Operator upon receiving randomness.
    /// @dev Simulates the Gauntlet bracket, determines the winner, distributes prizes/fees, and updates player states.
    /// @param randomness The random value provided by the VRF oracle.
    /// @param requestId The ID of the VRF request being fulfilled.
    /// @param extraData Additional data (unused in this implementation).
    function _fulfillRandomness(uint256 randomness, uint256 requestId, bytes memory extraData) internal override {
        // Prevent unused parameter warning
        extraData;

        // Checks - Validate request and gauntlet state
        uint256 gauntletId = requestToGauntletId[requestId];
        Gauntlet storage gauntlet = gauntlets[gauntletId];
        // If state is not PENDING (e.g., already completed or recovered), ignore fulfillment
        if (gauntlet.state != GauntletState.PENDING) {
            delete requestToGauntletId[requestId]; // Clean up mapping if stale request arrives
            return;
        }

        // Effects - Update state immediately to prevent re-entry or duplicate processing
        delete requestToGauntletId[requestId]; // Remove link once processed
        // Note: Gauntlet state set to COMPLETED later

        // Load gauntlet parameters into memory for efficiency
        uint8 size = gauntlet.size;
        uint256 entryFee = gauntlet.entryFee;
        RegisteredPlayer[] storage initialParticipants = gauntlet.participants;

        // Prepare arrays for active participants (handling retired player substitution)
        uint32[] memory activeParticipants = new uint32[](size);
        IGameEngine.FighterStats[] memory participantStats = new IGameEngine.FighterStats[](size);
        bytes32[] memory participantEncodedData = new bytes32[](size);

        // Substitute retired players with random default players
        uint32 currentMaxDefaultId = maxDefaultPlayerSubstituteId;
        if (currentMaxDefaultId == 0) currentMaxDefaultId = 1; // Safeguard against invalid config

        for (uint256 i = 0; i < size; i++) {
            RegisteredPlayer storage regPlayer = initialParticipants[i];
            if (playerContract.isPlayerRetired(regPlayer.playerId)) {
                // Generate pseudo-random index for default player selection
                uint256 derivedRand = uint256(keccak256(abi.encodePacked(randomness, i)));
                uint32 defaultId = uint32(derivedRand % currentMaxDefaultId) + 1; // Ensure ID is >= 1

                activeParticipants[i] = defaultId;

                // Fetch substitute player stats
                IPlayer.PlayerStats memory defaultStats = defaultPlayerContract.getDefaultPlayer(defaultId);
                IPlayerSkinRegistry.SkinCollectionInfo memory skinInfo =
                    playerContract.skinRegistry().getSkin(defaultStats.skin.skinIndex);
                IPlayerSkinNFT.SkinAttributes memory skinAttrs =
                    IPlayerSkinNFT(skinInfo.contractAddress).getSkinAttributes(defaultStats.skin.skinTokenId);

                participantStats[i] = IGameEngine.FighterStats({
                    weapon: skinAttrs.weapon,
                    armor: skinAttrs.armor,
                    stance: defaultStats.stance,
                    attributes: defaultStats.attributes
                });
                // Encode default player ID directly as data (no PlayerStats encoding needed)
                participantEncodedData[i] = bytes32(uint256(defaultId));
            } else {
                // Use non-retired player's ID and fetch/encode their stats
                activeParticipants[i] = regPlayer.playerId;
                (participantStats[i], participantEncodedData[i]) =
                    _getFighterCombatStats(regPlayer.playerId, regPlayer.loadout);
            }
        }

        // Shuffle participants using Fisher-Yates based on VRF randomness
        uint32[] memory shuffledParticipantIds = new uint32[](size);
        IGameEngine.FighterStats[] memory shuffledParticipantStats = new IGameEngine.FighterStats[](size);
        bytes32[] memory shuffledParticipantData = new bytes32[](size);
        uint256 shuffleRand = randomness; // Use VRF randomness as initial shuffle seed
        bool[] memory picked = new bool[](size);
        uint256 count = 0;
        while (count < size) {
            shuffleRand = uint256(keccak256(abi.encodePacked(shuffleRand, count))); // Evolve seed
            uint256 k = shuffleRand % size;
            if (!picked[k]) {
                shuffledParticipantIds[count] = activeParticipants[k];
                shuffledParticipantStats[count] = participantStats[k];
                shuffledParticipantData[count] = participantEncodedData[k];
                picked[k] = true;
                count++;
            }
        }

        // Simulate Gauntlet Rounds
        uint32[] memory currentRoundIds = shuffledParticipantIds;
        IGameEngine.FighterStats[] memory currentRoundStats = shuffledParticipantStats;
        bytes32[] memory currentRoundData = shuffledParticipantData;
        uint32[] memory nextRoundIds;
        IGameEngine.FighterStats[] memory nextRoundStats;
        bytes32[] memory nextRoundData;

        uint256 fightSeedBase = uint256(keccak256(abi.encodePacked(randomness, requestId))); // Base seed for all fights
        gauntlet.winners = new uint32[](size - 1); // Initialize array for round winners
        uint256 winnerIndex = 0;

        // Determine number of rounds based on size
        uint8 rounds;
        if (size == 4) rounds = 2;
        else if (size == 8) rounds = 3;
        else if (size == 16) rounds = 4;
        else rounds = 5; // size == 32 (guaranteed by setGauntletSize)

        for (uint256 roundIndex = 0; roundIndex < rounds; roundIndex++) {
            uint256 currentRoundSize = currentRoundIds.length;
            uint256 nextRoundSize = currentRoundSize / 2;
            nextRoundIds = new uint32[](nextRoundSize);
            nextRoundStats = new IGameEngine.FighterStats[](nextRoundSize);
            nextRoundData = new bytes32[](nextRoundSize);

            for (uint256 fightIndex = 0; fightIndex < currentRoundSize; fightIndex += 2) {
                // Get participants and stats for the current fight
                uint32 p1Id = currentRoundIds[fightIndex];
                uint32 p2Id = currentRoundIds[fightIndex + 1];
                IGameEngine.FighterStats memory fighter1Stats = currentRoundStats[fightIndex];
                IGameEngine.FighterStats memory fighter2Stats = currentRoundStats[fightIndex + 1];
                bytes32 p1Data = currentRoundData[fightIndex];
                bytes32 p2Data = currentRoundData[fightIndex + 1];

                // Generate unique seed for this specific fight
                uint256 fightSeed = uint256(keccak256(abi.encodePacked(fightSeedBase, roundIndex, fightIndex)));

                // Call GameEngine to simulate the fight
                bytes memory results = gameEngine.processGame(fighter1Stats, fighter2Stats, fightSeed, 0);
                (bool p1Won,,,) = gameEngine.decodeCombatLog(results);

                // Determine winner and loser, prepare for next round
                uint32 winnerId;
                uint32 loserId;
                uint256 nextRoundArrayIndex = fightIndex / 2;
                if (p1Won) {
                    winnerId = p1Id;
                    loserId = p2Id;
                    nextRoundIds[nextRoundArrayIndex] = p1Id;
                    nextRoundStats[nextRoundArrayIndex] = fighter1Stats;
                    nextRoundData[nextRoundArrayIndex] = p1Data;
                } else {
                    winnerId = p2Id;
                    loserId = p1Id;
                    nextRoundIds[nextRoundArrayIndex] = p2Id;
                    nextRoundStats[nextRoundArrayIndex] = fighter2Stats;
                    nextRoundData[nextRoundArrayIndex] = p2Data;
                }

                // Store round winner (except final winner)
                if (winnerIndex < size - 1) gauntlet.winners[winnerIndex++] = winnerId;

                // Interaction: Emit combat result via BaseGame event
                emit CombatResult(p1Data, p2Data, winnerId, results);

                // Interaction: Update player win/loss records via Player contract
                if (_getFighterType(winnerId) == Fighter.FighterType.PLAYER) playerContract.incrementWins(winnerId);
                if (_getFighterType(loserId) == Fighter.FighterType.PLAYER) playerContract.incrementLosses(loserId);
            }
            // Move to the next round
            currentRoundIds = nextRoundIds;
            currentRoundStats = nextRoundStats;
            currentRoundData = nextRoundData;
        }

        // Final Effects: Record winner, calculate prizes/fees, update states
        uint32 finalWinnerId = currentRoundIds[0];
        gauntlet.championId = finalWinnerId;
        gauntlet.completionTimestamp = block.timestamp;
        gauntlet.state = GauntletState.COMPLETED; // Mark as completed *after* simulation

        uint256 prizePool = entryFee * size;
        uint256 feeAmount = (prizePool * feePercentage) / 10000;
        uint256 winnerPayout = prizePool - feeAmount;

        contractFeesCollected += feeAmount;

        // Clean up player statuses
        for (uint256 i = 0; i < size; i++) {
            uint32 pId = initialParticipants[i].playerId;
            // Check status and current gauntlet ID before clearing
            if (playerStatus[pId] == PlayerStatus.IN_GAUNTLET && playerCurrentGauntlet[pId] == gauntletId) {
                playerStatus[pId] = PlayerStatus.NONE;
                delete playerCurrentGauntlet[pId];
            }
        }

        // Interactions: Distribute prize money & Prepare event data
        uint256 prizeAwardedForEvent = 0; // Default to 0 for event
        if (winnerPayout > 0) {
            Fighter.FighterType winnerType = _getFighterType(finalWinnerId);
            if (winnerType == Fighter.FighterType.DEFAULT_PLAYER) {
                // If default player wins, add payout to contract fees
                contractFeesCollected += winnerPayout;
                // prizeAwardedForEvent remains 0
            } else if (winnerType == Fighter.FighterType.PLAYER) {
                // If regular player wins, pay out to their owner
                address payable winnerOwner = payable(playerContract.getPlayerOwner(finalWinnerId));
                SafeTransferLib.safeTransferETH(winnerOwner, winnerPayout);
                prizeAwardedForEvent = winnerPayout; // Set actual prize for event
            }
            // Else (e.g., MONSTER type if supported) - no payout, prizeAwardedForEvent remains 0
        }

        // Interaction: Emit final completion event using calculated prize for event
        emit GauntletCompleted(gauntletId, size, entryFee, finalWinnerId, prizeAwardedForEvent, feeAmount);
    }

    //==============================================================//
    //                  HELPER & VIEW FUNCTIONS                     //
    //==============================================================//

    /// @notice Internal helper to remove a player from `queueIndex` using swap-and-pop.
    /// @dev Updates `playerIndexInQueue` mapping accordingly.
    /// @param playerId The ID of the player to remove.
    function _removePlayerFromQueueArrayIndex(uint32 playerId) internal {
        uint256 indexToRemove = playerIndexInQueue[playerId] - 1; // Get 0-based index
        _removePlayerFromQueueArrayIndexWithIndex(playerId, indexToRemove);
    }

    /// @notice Internal helper for swap-and-pop, taking the 0-based index directly.
    /// @param playerIdToRemove The ID of the player being removed.
    /// @param indexToRemove The 0-based index in `queueIndex` where the player resides.
    function _removePlayerFromQueueArrayIndexWithIndex(uint32 playerIdToRemove, uint256 indexToRemove) internal {
        uint256 lastIndex = queueIndex.length - 1;
        // If the element to remove is not the last element
        if (indexToRemove != lastIndex) {
            uint32 playerToMove = queueIndex[lastIndex]; // Get the ID of the last player
            queueIndex[indexToRemove] = playerToMove; // Move the last player to the vacated spot
            playerIndexInQueue[playerToMove] = indexToRemove + 1; // Update the moved player's 1-based index
        }
        // Clear the mapping for the removed player and shrink the array
        delete playerIndexInQueue[playerIdToRemove];
        queueIndex.pop();
    }

    /// @notice Internal helper to get combat stats for a registered player.
    /// @param playerId The ID of the player.
    /// @param loadout The loadout used by the player.
    /// @return stats The `FighterStats` struct for the game engine.
    /// @return encodedData The player's encoded data (for logging/identification).
    function _getFighterCombatStats(uint32 playerId, Fighter.PlayerLoadout memory loadout)
        internal
        view
        returns (IGameEngine.FighterStats memory stats, bytes32 encodedData)
    {
        // Ensure it's a regular player
        if (_getFighterType(playerId) != Fighter.FighterType.PLAYER) {
            revert UnsupportedPlayerId();
        }

        // Fetch base stats and apply loadout overrides
        IPlayer.PlayerStats memory pStats = playerContract.getPlayer(playerId);
        pStats.skin = loadout.skin;
        pStats.stance = loadout.stance;

        // Fetch skin attributes from the NFT contract via the registry
        IPlayerSkinRegistry.SkinCollectionInfo memory skinInfo =
            playerContract.skinRegistry().getSkin(pStats.skin.skinIndex);
        IPlayerSkinNFT.SkinAttributes memory skinAttrs =
            IPlayerSkinNFT(skinInfo.contractAddress).getSkinAttributes(pStats.skin.skinTokenId);

        // Construct stats for the GameEngine
        stats = IGameEngine.FighterStats({
            weapon: skinAttrs.weapon,
            armor: skinAttrs.armor,
            stance: pStats.stance,
            attributes: pStats.attributes
        });
        // Encode player data using the Player contract's helper
        encodedData = playerContract.encodePlayerData(playerId, pStats);
    }

    /// @notice Returns the full data structure for a specific Gauntlet run.
    /// @param gauntletId The ID of the Gauntlet to retrieve.
    /// @return The `Gauntlet` struct containing all data for the specified run.
    function getGauntletData(uint256 gauntletId) external view returns (Gauntlet memory) {
        // Basic check to ensure the ID likely corresponds to a created gauntlet
        // Note: Doesn't guarantee existence if nextGauntletId wraps around, but unlikely.
        if (gauntletId >= nextGauntletId) revert GauntletDoesNotExist();
        // Deeper check (optional): if (gauntlets[gauntletId].participants.length == 0 && gauntlets[gauntletId].state == GauntletState.PENDING) revert GauntletDoesNotExist();
        return gauntlets[gauntletId];
    }

    //==============================================================//
    //                     ADMIN FUNCTIONS                          //
    //==============================================================//
    /// @notice Allows the owner to withdraw accumulated contract fees.
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = contractFeesCollected;
        if (amount == 0) revert NoFeesToWithdraw(); // Use custom error

        // Effects first
        contractFeesCollected = 0;

        // Interactions last
        SafeTransferLib.safeTransferETH(payable(owner), amount);
        emit FeesWithdrawn(amount);
    }

    /// @notice Toggles the ability for players to queue for Gauntlets.
    /// @dev If set to `false`, clears the current queue and refunds all players the `currentEntryFee`.
    /// @param enabled The desired state (true = enabled, false = disabled).
    function setGameEnabled(bool enabled) external onlyOwner nonReentrant {
        if (isGameEnabled == enabled) return; // No change needed

        isGameEnabled = enabled;

        // If disabling the game, clear the queue and refund players
        if (!enabled) {
            uint256 playersRefunded = 0;
            uint256 totalRefunded = 0;
            uint256 queueLength = queueIndex.length; // Cache initial length
            uint256 feeToRefund = currentEntryFee; // Cache the fee players paid

            // Iterate backwards for safe swap-and-pop during iteration
            for (uint256 i = queueLength; i > 0; i--) {
                uint256 indexToRemove = i - 1; // Current 0-based index
                uint32 playerId = queueIndex[indexToRemove];

                // Check if player needs refund and state reset (should always be QUEUED if in queueIndex)
                if (playerStatus[playerId] == PlayerStatus.QUEUED) {
                    address playerOwner = playerContract.getPlayerOwner(playerId);
                    uint256 refundAmount = feeToRefund; // Refund the fee they originally paid

                    // Interaction: Refund (Use SafeTransferLib)
                    // Ensure owner address is valid before attempting transfer
                    if (playerOwner != address(0)) {
                        SafeTransferLib.safeTransferETH(playerOwner, refundAmount);
                        totalRefunded += refundAmount;
                    }
                    // Note: If owner somehow became address(0), refund is skipped, but state is still cleared.

                    // Effects: Clear player state *only* if they were QUEUED and processed
                    delete registrationQueue[playerId];
                    playerStatus[playerId] = PlayerStatus.NONE;
                    // Note: playerIndexInQueue[playerId] deletion handled by _removePlayer... below

                    playersRefunded++;
                }

                // Effect: Always remove from queue array via swap-and-pop
                // Use the helper that takes the index directly
                _removePlayerFromQueueArrayIndexWithIndex(playerId, indexToRemove);
            }

            // Effect: Adjust fee pool after processing all players
            // It's safer to recalculate based on the total refunded amount rather than assuming subtraction is safe
            if (queuedFeesPool < totalRefunded) {
                queuedFeesPool = 0; // Avoid underflow (should not happen with correct logic)
            } else {
                queuedFeesPool -= totalRefunded;
            }

            // Interaction: Emit event if refunds occurred
            if (playersRefunded > 0) {
                emit QueueClearedDueToGameDisabled(playersRefunded, totalRefunded);
            }
        }

        // Always emit the state change event
        emit GameEnabledUpdated(enabled);
    }

    /// @notice Sets the Gelato VRF operator address.
    /// @param newOperator The new operator address.
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        if (newOperator == _operatorAddress) return; // No change needed
        _operatorAddress = newOperator;
        emit OperatorSet(newOperator);
    }

    /// @notice Sets the percentage fee taken from the prize pool.
    /// @param _newFeePercentage The new fee percentage in basis points (e.g., 1000 = 10%). Max 10000 (100%).
    function setFeePercentage(uint256 _newFeePercentage) external onlyOwner {
        // Require fee to be between 0% and 100% inclusive
        require(_newFeePercentage <= 10000, "Fee cannot exceed 100%");
        uint256 oldPercentage = feePercentage;
        if (oldPercentage == _newFeePercentage) return; // No change needed

        feePercentage = _newFeePercentage;
        emit FeePercentageSet(oldPercentage, _newFeePercentage);
    }

    /// @notice Allows anyone to trigger recovery for a timed-out Gauntlet.
    /// @dev Marks the Gauntlet as COMPLETED and refunds participants. Intentionally public access after timeout.
    /// @param gauntletId The ID of the Gauntlet to recover.
    function recoverTimedOutVRF(uint256 gauntletId) external nonReentrant {
        // Checks
        Gauntlet storage gauntlet = gauntlets[gauntletId];
        if (gauntlet.state != GauntletState.PENDING) revert GauntletNotPending();
        if (block.timestamp < gauntlet.vrfRequestTimestamp + vrfRequestTimeout) revert TimeoutNotReached();

        // Effects - Mark gauntlet completed first
        gauntlet.state = GauntletState.COMPLETED;
        gauntlet.completionTimestamp = block.timestamp;
        uint256 entryFee = gauntlet.entryFee; // Load fee into memory

        // Clean up VRF request ID mapping if it exists
        if (gauntlet.vrfRequestId != 0 && requestToGauntletId[gauntlet.vrfRequestId] == gauntletId) {
            delete requestToGauntletId[gauntlet.vrfRequestId];
        }

        // Process refunds and state cleanup for participants
        RegisteredPlayer[] storage participants = gauntlet.participants;
        uint8 size = gauntlet.size;
        for (uint256 i = 0; i < size; i++) {
            uint32 pId = participants[i].playerId;
            // Check if the player was actually marked as IN_GAUNTLET for this specific run
            if (playerStatus[pId] == PlayerStatus.IN_GAUNTLET && playerCurrentGauntlet[pId] == gauntletId) {
                // Refund actual players (not default placeholders)
                if (_getFighterType(pId) == Fighter.FighterType.PLAYER) {
                    address playerOwner = playerContract.getPlayerOwner(pId);
                    // Interaction: Refund (Use SafeTransferLib)
                    SafeTransferLib.safeTransferETH(playerOwner, entryFee);
                }
                // Effects: Clean up player state regardless of refund success
                playerStatus[pId] = PlayerStatus.NONE;
                delete playerCurrentGauntlet[pId];
            }
        }

        // Interaction: Emit recovery event
        emit GauntletRecovered(gauntletId);
    }

    /// @notice Updates the address of the `DefaultPlayer` contract.
    /// @param newAddress The new contract address.
    function setDefaultPlayerContract(address newAddress) external onlyOwner {
        if (newAddress == address(0)) revert ZeroAddress();
        defaultPlayerContract = IDefaultPlayer(newAddress);
        emit DefaultPlayerContractSet(newAddress);
    }

    /// @notice Sets the entry fee required to join the queue.
    /// @dev The game must be disabled via `setGameEnabled(false)` before calling this function.
    ///      Disabling the game automatically clears the queue and refunds players.
    /// @param newFee The new entry fee in wei.
    function setEntryFee(uint256 newFee) external onlyOwner {
        // Require game to be disabled. Disabling clears the queue.
        require(!isGameEnabled, "Game must be disabled to change entry fee");

        uint256 oldFee = currentEntryFee;
        if (oldFee == newFee) return; // No change needed

        // Effect: Set the new fee
        currentEntryFee = newFee;

        // Interaction: Emit event
        emit EntryFeeSet(oldFee, newFee);
    }

    /// @notice Sets the number of participants required to start a gauntlet (4, 8, 16, or 32).
    /// @dev The game must be disabled via `setGameEnabled(false)` before calling this function.
    ///      Disabling the game automatically clears the queue.
    /// @param newSize The new gauntlet size.
    function setGauntletSize(uint8 newSize) external onlyOwner {
        // Require game to be disabled. Disabling clears the queue.
        require(!isGameEnabled, "Game must be disabled to change gauntlet size");

        // Checks for valid size parameter
        if (newSize != 4 && newSize != 8 && newSize != 16 && newSize != 32) {
            revert InvalidGauntletSize(newSize);
        }

        uint8 oldSize = currentGauntletSize;
        if (oldSize == newSize) return; // No change needed

        // Effect & Interaction
        currentGauntletSize = newSize;
        emit GauntletSizeSet(oldSize, newSize);
    }

    /// @notice Sets the maximum ID used for default player substitutions during VRF fulfillment.
    /// @dev Owner must ensure this ID corresponds to an existing, valid player in the `DefaultPlayer` contract.
    ///      Must be within the range [1, 2000].
    /// @param _maxId The highest default player ID to consider for substitution.
    function setMaxDefaultPlayerSubstituteId(uint32 _maxId) external onlyOwner {
        // Validate against the absolute range expected for DefaultPlayer IDs
        if (_maxId == 0 || _maxId > 2000) {
            // Assuming 1-2000 is the valid range for DefaultPlayer
            revert InvalidDefaultPlayerRange();
        }
        uint32 oldMaxId = maxDefaultPlayerSubstituteId;
        if (oldMaxId == _maxId) return; // No change needed

        // Effect & Interaction
        maxDefaultPlayerSubstituteId = _maxId;
        emit MaxDefaultPlayerSubstituteIdSet(_maxId);
    }

    /// @notice Sets the minimum time required between starting gauntlets.
    /// @param newMinTime The new minimum time in seconds.
    function setMinTimeBetweenGauntlets(uint256 newMinTime) external onlyOwner {
        // Optional: Add reasonable bounds check if desired (e.g., require(newMinTime >= 60 seconds))
        minTimeBetweenGauntlets = newMinTime;
        emit MinTimeBetweenGauntletsSet(newMinTime);
    }

    //==============================================================//
    //             BASEGAME ABSTRACT IMPLEMENTATIONS                //
    //==============================================================//
    /// @notice Checks if a player ID is supported by this game mode (Player or DefaultPlayer).
    /// @param playerId The ID to check.
    /// @return True if the ID belongs to a Player or DefaultPlayer.
    function _isPlayerIdSupported(uint32 playerId) internal pure override returns (bool) {
        Fighter.FighterType fighterType = _getFighterType(playerId);
        return fighterType == Fighter.FighterType.PLAYER || fighterType == Fighter.FighterType.DEFAULT_PLAYER;
    }

    /// @notice Gets the contract address responsible for handling the given fighter type.
    /// @param playerId The ID of the player/fighter.
    /// @return Fighter The address cast to the `Fighter` base contract type.
    function _getFighterContract(uint32 playerId) internal view override returns (Fighter) {
        Fighter.FighterType fighterType = _getFighterType(playerId);
        // Both Player and DefaultPlayer interactions are managed through the Player contract interface here
        if (fighterType == Fighter.FighterType.PLAYER || fighterType == Fighter.FighterType.DEFAULT_PLAYER) {
            return Fighter(address(playerContract));
        } else {
            revert UnsupportedPlayerId();
        }
    }
}

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
import "../../lib/UniformRandomNumber.sol";
import "../../interfaces/game/engine/IGameEngine.sol";
import "../../interfaces/fighters/IPlayer.sol";
import "../../interfaces/fighters/IPlayerDataCodec.sol";
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
error InvalidDefaultPlayerRange();
error TimeoutNotReached();
error UnsupportedPlayerId();
error InsufficientQueueSize(uint256 current, uint8 required);
error MinTimeNotElapsed();
error PendingGauntletExists();
error NoPendingGauntlet();
error InvalidPhaseTransition();
error SelectionBlockNotReached(uint256 selectionBlock, uint256 currentBlock);
error TournamentBlockNotReached(uint256 tournamentBlock, uint256 currentBlock);
error InvalidFutureBlocks(uint256 blocks);
error CannotRecoverYet();
error NoDefaultPlayersAvailable();
error InsufficientDefaultPlayers(uint256 needed, uint256 available);

//==============================================================//
//                         HEAVY HELMS                          //
//                         GAUNTLET GAME                        //
//==============================================================//
/// @title Gauntlet Game Mode for Heavy Helms
/// @notice Manages a queue of players and triggers elimination brackets (Gauntlets)
///         of dynamic size (4, 8, 16, 32, or 64) with a dynamic entry fee.
/// @dev Uses a commit-reveal pattern with future blockhash for randomness.
///      Eliminates VRF costs and delays while providing secure participant selection.
contract GauntletGame is BaseGame, ReentrancyGuard {
    //==============================================================//
    //                          ENUMS                               //
    //==============================================================//
    /// @notice Represents the state of a Gauntlet run.
    enum GauntletState {
        PENDING, // Gauntlet started, awaiting completion.
        COMPLETED // Gauntlet finished.

    }

    /// @notice Represents the phase of the 3-transaction gauntlet system.
    enum GauntletPhase {
        NONE, // No pending gauntlet
        QUEUE_COMMIT, // Phase 1: Waiting for participant selection block
        PARTICIPANT_SELECT, // Phase 2: Waiting for tournament execution block
        TOURNAMENT_READY // Phase 3: Ready to execute tournament

    }

    /// @notice Represents the current status of a player in relation to the Gauntlet mode.
    enum PlayerStatus {
        NONE, // Not participating.
        QUEUED, // Waiting in the queue, can withdraw.
        IN_TOURNAMENT // Actively participating in a Gauntlet run.

    }

    //==============================================================//
    //                         STRUCTS                              //
    //==============================================================//
    /// @notice Structure storing data for a specific Gauntlet run instance.
    /// @param id Unique identifier for the Gauntlet.
    /// @param size Number of participants (4, 8, 16, 32, or 64).
    /// @param state Current state of the Gauntlet (PENDING or COMPLETED).
    /// @param startTimestamp Timestamp when the Gauntlet was started.
    /// @param completionTimestamp Timestamp when the Gauntlet was completed.
    /// @param participants Array of players registered for this Gauntlet, including their loadouts.
    /// @param winners Array storing the winner ID of each match (size - 1 elements).
    /// @param championId The ID of the final Gauntlet winner.
    struct Gauntlet {
        uint256 id;
        uint8 size;
        GauntletState state;
        uint256 startTimestamp;
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

    /// @notice Structure for pending gauntlet using 3-transaction pattern.
    /// @param phase Current phase of the gauntlet process.
    /// @param selectionBlock Future block for participant selection randomness.
    /// @param tournamentBlock Future block for tournament execution randomness.
    /// @param commitTimestamp Timestamp when the gauntlet was initiated.
    /// @param gauntletId The ID that will be assigned to this gauntlet when executed.
    struct PendingGauntlet {
        GauntletPhase phase;
        uint256 selectionBlock;
        uint256 tournamentBlock;
        uint256 commitTimestamp;
        uint256 gauntletId;
    }

    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//

    // --- Configuration & Roles ---
    /// @notice Contract managing default player data.
    IDefaultPlayer public defaultPlayerContract;
    /// @notice Number of blocks in the future for participant selection.
    uint256 public futureBlocksForSelection = 20;
    /// @notice Number of blocks in the future for tournament execution.
    uint256 public futureBlocksForTournament = 20;
    /// @notice Maximum number of players to clear per emergency clear operation.
    uint256 public constant CLEAR_BATCH_SIZE = 50;
    bool public isGameEnabled = true;
    uint256 public minTimeBetweenGauntlets = 5 minutes;
    uint256 public lastGauntletStartTime;

    // --- Dynamic Settings ---
    /// @notice Current number of participants required to start a Gauntlet (4, 8, 16, or 32).
    uint8 public currentGauntletSize = 4;

    // --- Gauntlet State ---
    /// @notice Counter for assigning unique Gauntlet IDs.
    uint256 public nextGauntletId;
    /// @notice Maps Gauntlet IDs to their detailed `Gauntlet` struct data.
    mapping(uint256 => Gauntlet) public gauntlets;
    /// @notice The pending gauntlet waiting for reveal.
    PendingGauntlet public pendingGauntlet;

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

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a player successfully joins the queue.
    event PlayerQueued(uint32 indexed playerId, uint256 queueSize);
    /// @notice Emitted when a player successfully withdraws from the queue.
    event PlayerWithdrew(uint32 indexed playerId, uint256 queueSize);
    /// @notice Emitted when phase 1 is completed (queue committed).
    event QueueCommitted(uint256 selectionBlock, uint256 queueSize);
    /// @notice Emitted when phase 2 is completed (participants selected).
    event ParticipantsSelected(uint256 indexed gauntletId, uint256 tournamentBlock, uint32[] selectedIds);
    /// @notice Emitted when a Gauntlet is started (phase 3).
    event GauntletStarted(uint256 indexed gauntletId, uint8 size, RegisteredPlayer[] participants);
    /// @notice Emitted when a Gauntlet is successfully completed.
    event GauntletCompleted(
        uint256 indexed gauntletId,
        uint8 size,
        uint32 indexed championId,
        uint32[] participantIds,
        uint32[] roundWinners
    );
    /// @notice Emitted when a pending Gauntlet is recovered after timeout.
    event GauntletRecovered(uint256 commitTimestamp);
    /// @notice Emitted when a pending Gauntlet is automatically recovered.
    event GauntletRecoveredAutomatically();
    /// @notice Emitted when the default player contract address is updated.
    event DefaultPlayerContractSet(address indexed newContract);
    /// @notice Emitted when the Gauntlet size (participant count) is changed.
    event GauntletSizeSet(uint8 oldSize, uint8 newSize);
    /// @notice Emitted when the queue is cleared due to `setEntryFee` being called with `refundPlayers=true`.
    event QueueClearedDueToSettingsChange(uint256 playersRefunded, uint256 totalRefunded);
    /// @notice Emitted when the maximum default player ID for substitutions is updated.
    event MaxDefaultPlayerSubstituteIdSet(uint32 newMaxId);
    /// @notice Emitted when the minimum time required between starting gauntlets is updated.
    event MinTimeBetweenGauntletsSet(uint256 newMinTime);
    /// @notice Emitted when the future blocks for selection is updated.
    event FutureBlocksForSelectionSet(uint256 blocks);
    /// @notice Emitted when the future blocks for tournament is updated.
    event FutureBlocksForTournamentSet(uint256 blocks);
    /// @notice Emitted when emergency queue clear is performed.
    event EmergencyQueueCleared(uint256 cleared, uint256 remaining);
    /// @notice Emitted when queue is partially cleared during game disable.
    event QueuePartiallyCleared(uint256 cleared, uint256 remaining);
    /// @notice Emitted when the game enabled state is updated.
    event GameEnabledUpdated(bool enabled);
    /// @notice Emitted when the queue is cleared due to the game being disabled.
    /// @param playerIds Array of player IDs removed from the queue.
    /// @param totalRefunded Total amount of ETH refunded to the players.
    event QueueClearedDueToGameDisabled(uint32[] playerIds, uint256 totalRefunded);
    // Inherited from BaseGame: event CombatResult(bytes32 indexed player1Data, bytes32 indexed player2Data, uint32 winnerId, bytes combatLog);

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
    constructor(address _gameEngine, address _playerContract, address _defaultPlayerAddress)
        BaseGame(_gameEngine, _playerContract)
    {
        // Input validation
        if (_defaultPlayerAddress == address(0)) revert ZeroAddress();
        // Validation will happen when trying to use defaults

        // Set initial state
        defaultPlayerContract = IDefaultPlayer(_defaultPlayerAddress);
        lastGauntletStartTime = block.timestamp; // Initialize to deployment time

        // Emit initial settings
        emit DefaultPlayerContractSet(_defaultPlayerAddress);
        emit GauntletSizeSet(0, currentGauntletSize);
        // MaxDefaultPlayerSubstituteId no longer used
        emit MinTimeBetweenGauntletsSet(minTimeBetweenGauntlets);
        emit FutureBlocksForSelectionSet(futureBlocksForSelection);
        emit FutureBlocksForTournamentSet(futureBlocksForTournament);
        // No queue size limits - live free or die!
    }

    //==============================================================//
    //                       QUEUE MANAGEMENT                       //
    //==============================================================//

    /// @notice Allows a player owner to join the Gauntlet queue with a specific loadout.
    /// @param loadout The player's chosen skin and stance for the potential Gauntlet.
    /// @dev Validates player status, ownership, retirement status, and skin requirements.
    function queueForGauntlet(Fighter.PlayerLoadout calldata loadout) external whenGameEnabled nonReentrant {
        // Checks
        if (playerStatus[loadout.playerId] != PlayerStatus.NONE) revert AlreadyInQueue();
        address owner = playerContract.getPlayerOwner(loadout.playerId);
        if (msg.sender != owner) revert CallerNotPlayerOwner();
        if (playerContract.isPlayerRetired(loadout.playerId)) revert PlayerIsRetired();

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
        uint32 playerId = loadout.playerId;
        registrationQueue[playerId] = loadout;
        queueIndex.push(playerId);
        playerIndexInQueue[playerId] = queueIndex.length; // 1-based index
        playerStatus[playerId] = PlayerStatus.QUEUED;

        // Interactions (Event Emission)
        emit PlayerQueued(playerId, queueIndex.length);
    }

    /// @notice Allows a player owner to withdraw their player from the queue before a Gauntlet starts.
    /// @param playerId The ID of the player to withdraw.
    /// @dev Uses swap-and-pop to maintain queue integrity. Cannot withdraw after selection.
    function withdrawFromQueue(uint32 playerId) external nonReentrant {
        // Checks
        address owner = playerContract.getPlayerOwner(playerId);
        if (msg.sender != owner) revert CallerNotPlayerOwner();
        if (playerStatus[playerId] != PlayerStatus.QUEUED) {
            revert PlayerNotInQueue();
        }

        // Effects - update player state
        _removePlayerFromQueueArrayIndex(playerId); // Handles swap-and-pop and mapping updates
        delete registrationQueue[playerId];
        playerStatus[playerId] = PlayerStatus.NONE;

        // Interactions - emit event
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

    /// @notice Attempts to start a new Gauntlet using 3-transaction commit-reveal pattern.
    /// @dev Callable by anyone. Handles three phases:
    ///      1. QUEUE_COMMIT: Snapshots queue and sets selection block
    ///      2. PARTICIPANT_SELECT: Selects participants and sets tournament block
    ///      3. TOURNAMENT_READY: Executes the tournament
    function tryStartGauntlet() external whenGameEnabled nonReentrant {
        // Handle pending gauntlet phases
        if (pendingGauntlet.phase != GauntletPhase.NONE) {
            // Check if we're past the 256-block limit from initial commit for auto-recovery
            uint256 commitBlock = (pendingGauntlet.phase == GauntletPhase.QUEUE_COMMIT)
                ? pendingGauntlet.selectionBlock - futureBlocksForSelection
                : pendingGauntlet.tournamentBlock - futureBlocksForTournament - futureBlocksForSelection;

            if (block.number > commitBlock + 256) {
                // Auto-recovery if we missed the window
                _recoverPendingGauntlet();
                emit GauntletRecoveredAutomatically();
            }

            if (pendingGauntlet.phase == GauntletPhase.QUEUE_COMMIT) {
                // Phase 2: Participant Selection
                if (block.number >= pendingGauntlet.selectionBlock) {
                    _selectParticipantsPhase();
                    return;
                } else {
                    revert SelectionBlockNotReached(pendingGauntlet.selectionBlock, block.number);
                }
            } else if (pendingGauntlet.phase == GauntletPhase.PARTICIPANT_SELECT) {
                // Phase 3: Tournament Execution
                if (block.number >= pendingGauntlet.tournamentBlock) {
                    _executeTournamentPhase();
                    return;
                } else {
                    revert TournamentBlockNotReached(pendingGauntlet.tournamentBlock, block.number);
                }
            }

            // If we reach here, we're waiting for the next phase
            return;
        }

        // Phase 1: Queue Commit - Create new pending gauntlet if conditions met
        if (block.timestamp < lastGauntletStartTime + minTimeBetweenGauntlets) {
            revert MinTimeNotElapsed();
        }
        if (queueIndex.length < currentGauntletSize) {
            revert InsufficientQueueSize(queueIndex.length, currentGauntletSize);
        }

        _commitQueuePhase();
    }

    //==============================================================//
    //                    COMMIT-REVEAL FUNCTIONS                   //
    //==============================================================//

    /// @notice Phase 1: Commits the queue and sets up for participant selection.
    function _commitQueuePhase() private {
        // No queue size limits - live free or die!

        // Update timing
        lastGauntletStartTime = block.timestamp;

        // Initialize pending gauntlet for phase 1
        pendingGauntlet.phase = GauntletPhase.QUEUE_COMMIT;
        pendingGauntlet.selectionBlock = block.number + futureBlocksForSelection;
        pendingGauntlet.commitTimestamp = block.timestamp;
        pendingGauntlet.gauntletId = nextGauntletId;

        emit QueueCommitted(pendingGauntlet.selectionBlock, queueIndex.length);
    }

    /// @notice Phase 2: Selects participants using blockhash randomness.
    function _selectParticipantsPhase() private {
        // Get randomness from selection block
        uint256 seed = uint256(blockhash(pendingGauntlet.selectionBlock));
        if (seed == 0) {
            revert("Invalid blockhash");
        }

        // Select participants using hybrid algorithm
        uint32[] memory selectedIds = _selectParticipants(seed, queueIndex);

        // Create the actual gauntlet FIRST
        uint256 gauntletId = pendingGauntlet.gauntletId;
        nextGauntletId++; // Increment for next gauntlet
        Gauntlet storage gauntlet = gauntlets[gauntletId];
        gauntlet.id = gauntletId;
        gauntlet.size = uint8(selectedIds.length);
        gauntlet.state = GauntletState.PENDING;
        gauntlet.startTimestamp = block.timestamp;

        // Store participants ONLY in gauntlet (eliminate duplication)
        for (uint256 i = 0; i < selectedIds.length; i++) {
            uint32 playerId = selectedIds[i];
            Fighter.PlayerLoadout memory loadout = registrationQueue[playerId];

            // Store ONLY in gauntlet
            gauntlet.participants.push(RegisteredPlayer({playerId: playerId, loadout: loadout}));

            // Update player status to final state
            playerStatus[playerId] = PlayerStatus.IN_TOURNAMENT;
            playerCurrentGauntlet[playerId] = gauntletId;
        }

        // Remove selected players from queue one by one
        for (uint256 i = 0; i < selectedIds.length; i++) {
            uint32 playerId = selectedIds[i];
            _removePlayerFromQueueArrayIndex(playerId);
            delete registrationQueue[playerId];
        }

        // Emit start event NOW in TX2
        emit GauntletStarted(gauntletId, gauntlet.size, gauntlet.participants);

        // Set up tournament phase
        pendingGauntlet.phase = GauntletPhase.PARTICIPANT_SELECT;
        pendingGauntlet.tournamentBlock = block.number + futureBlocksForTournament;

        emit ParticipantsSelected(pendingGauntlet.gauntletId, pendingGauntlet.tournamentBlock, selectedIds);
    }

    /// @notice Phase 3: Executes the tournament using blockhash randomness.
    function _executeTournamentPhase() private {
        // Get randomness from tournament block
        uint256 seed = uint256(blockhash(pendingGauntlet.tournamentBlock));
        if (seed == 0) {
            revert("Invalid blockhash");
        }

        // Everything is already set up in TX2, just get the gauntlet ID
        uint256 gauntletId = pendingGauntlet.gauntletId;

        // Clear pending gauntlet
        delete pendingGauntlet;

        // Execute the tournament using gauntlet logic
        _executeGauntletWithRandomness(gauntletId, seed);
    }

    /// @notice Selects participants using hybrid first-half randomization.
    /// @param seed The random seed from blockhash.
    /// @param queue The current queue array to select from.
    /// @return selected Array of selected player IDs.
    function _selectParticipants(uint256 seed, uint32[] memory queue) private view returns (uint32[] memory selected) {
        uint8 size = currentGauntletSize;
        uint256 queueSize = queue.length;

        // Determine selection pool size
        uint256 poolSize;
        if (queueSize >= size * 2) {
            // Hybrid mode: select from first half for fairness
            poolSize = queueSize / 2;
        } else {
            // Pure random: select from entire queue
            poolSize = queueSize;
        }

        // Random selection from pool
        selected = new uint32[](size);
        uint32[] memory pool = new uint32[](poolSize);

        // Copy pool
        for (uint256 i = 0; i < poolSize; i++) {
            pool[i] = queue[i];
        }

        // Select players
        uint256 remaining = poolSize;
        for (uint256 i = 0; i < size; i++) {
            seed = uint256(keccak256(abi.encodePacked(seed, i)));
            uint256 index = seed % remaining;

            selected[i] = pool[index];

            // Swap and pop
            pool[index] = pool[remaining - 1];
            remaining--;
        }
    }

    /// @notice Helper function to clean up pending gauntlet state during recovery.
    function _recoverPendingGauntlet() private {
        // In our architecture, recovery is simple - just clear the pending gauntlet
        // Players remain in queue during QUEUE_COMMIT phase
        // Players are in tournament during PARTICIPANT_SELECT phase (no recovery needed)
        delete pendingGauntlet;
    }

    /// @notice Executes a gauntlet tournament using blockhash randomness.
    /// @param gauntletId The ID of the gauntlet to execute.
    /// @param randomness The random value from blockhash.
    function _executeGauntletWithRandomness(uint256 gauntletId, uint256 randomness) private {
        Gauntlet storage gauntlet = gauntlets[gauntletId];
        // If state is not PENDING (shouldn't happen in blockhash version), return early
        if (gauntlet.state != GauntletState.PENDING) {
            return;
        }

        // Load gauntlet parameters into memory for efficiency
        uint8 size = gauntlet.size;
        RegisteredPlayer[] storage initialParticipants = gauntlet.participants;

        // Prepare arrays for active participants (handling retired player substitution)
        uint32[] memory activeParticipants = new uint32[](size);
        IGameEngine.FighterStats[] memory participantStats = new IGameEngine.FighterStats[](size);
        bytes32[] memory participantEncodedData = new bytes32[](size);

        // First pass: identify retired players
        uint256[] memory retiredIndices = new uint256[](size);
        uint256 retiredCount = 0;
        
        for (uint256 i = 0; i < size; i++) {
            RegisteredPlayer storage regPlayer = initialParticipants[i];
            if (playerContract.isPlayerRetired(regPlayer.playerId)) {
                retiredIndices[retiredCount++] = i;
            }
        }
        
        // Get unique substitutes for all retired players
        uint32[] memory substituteIds = new uint32[](0);
        if (retiredCount > 0) {
            uint32[] memory emptyExcludes = new uint32[](0); // No existing defaults in gauntlet
            substituteIds = _selectUniqueDefaults(randomness, retiredCount, emptyExcludes);
        }

        // Second pass: substitute retired players and load all data
        for (uint256 i = 0; i < size; i++) {
            RegisteredPlayer storage regPlayer = initialParticipants[i];
            uint32 activePlayerId = regPlayer.playerId;
            
            // Check if this player needs substitution
            for (uint256 j = 0; j < retiredCount; j++) {
                if (retiredIndices[j] == i) {
                    activePlayerId = substituteIds[j];
                    break;
                }
            }
            
            activeParticipants[i] = activePlayerId;

            if (activePlayerId != regPlayer.playerId) {
                // This is a substitute default player

                // Fetch substitute player stats
                IPlayer.PlayerStats memory defaultStats = defaultPlayerContract.getDefaultPlayer(activePlayerId);
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
                participantEncodedData[i] = bytes32(uint256(activePlayerId));
            } else {
                // Use non-retired player's ID and fetch/encode their stats
                activeParticipants[i] = regPlayer.playerId;
                (participantStats[i], participantEncodedData[i]) =
                    _getFighterCombatStats(regPlayer.playerId, regPlayer.loadout);
            }
        }

        // Shuffle participants using Fisher-Yates based on randomness
        uint32[] memory shuffledParticipantIds = new uint32[](size);
        IGameEngine.FighterStats[] memory shuffledParticipantStats = new IGameEngine.FighterStats[](size);
        bytes32[] memory shuffledParticipantData = new bytes32[](size);
        uint256 shuffleRand = randomness; // Use randomness as initial shuffle seed
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

        uint256 fightSeedBase = uint256(keccak256(abi.encodePacked(randomness, gauntletId))); // Base seed for all fights
        gauntlet.winners = new uint32[](size - 1); // Initialize array for round winners
        uint256 winnerIndex = 0;

        // Determine number of rounds based on size
        uint8 rounds;
        if (size == 4) rounds = 2;
        else if (size == 8) rounds = 3;
        else if (size == 16) rounds = 4;
        else if (size == 32) rounds = 5;
        else rounds = 6; // size == 64 (guaranteed by setGauntletSize)

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

        // Clean up player statuses
        for (uint256 i = 0; i < size; i++) {
            uint32 pId = initialParticipants[i].playerId;
            // Check status and current gauntlet ID before clearing
            if (playerStatus[pId] == PlayerStatus.IN_TOURNAMENT && playerCurrentGauntlet[pId] == gauntletId) {
                playerStatus[pId] = PlayerStatus.NONE;
                delete playerCurrentGauntlet[pId];
            }
        }

        // Interaction: Emit final completion event with additional data
        emit GauntletCompleted(gauntletId, size, finalWinnerId, shuffledParticipantIds, gauntlet.winners);
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

    /// @notice Efficiently removes multiple players from the queue in a single operation.
    /// @param playerIds Array of player IDs to remove from the queue.
    function _batchRemovePlayersFromQueue(uint32[] memory playerIds) internal {
        // Clear registration data first
        for (uint256 i = 0; i < playerIds.length; i++) {
            delete registrationQueue[playerIds[i]];
        }

        // Use optimized removal: remove from end to avoid index shifting
        // Sort removal indices in descending order for efficient removal
        uint256[] memory indicesToRemove = new uint256[](playerIds.length);
        for (uint256 i = 0; i < playerIds.length; i++) {
            indicesToRemove[i] = playerIndexInQueue[playerIds[i]] - 1; // Convert to 0-based
        }

        // Simple bubble sort in descending order (small arrays only)
        for (uint256 i = 0; i < indicesToRemove.length; i++) {
            for (uint256 j = i + 1; j < indicesToRemove.length; j++) {
                if (indicesToRemove[i] < indicesToRemove[j]) {
                    uint256 temp = indicesToRemove[i];
                    indicesToRemove[i] = indicesToRemove[j];
                    indicesToRemove[j] = temp;
                }
            }
        }

        // Remove players from highest index to lowest to avoid shifting issues
        for (uint256 i = 0; i < indicesToRemove.length; i++) {
            uint32 playerIdToRemove = queueIndex[indicesToRemove[i]];
            _removePlayerFromQueueArrayIndexWithIndex(playerIdToRemove, indicesToRemove[i]);
        }
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
        // Get seasonal record for encoding
        Fighter.Record memory seasonalRecord = playerContract.getCurrentSeasonRecord(playerId);

        // Encode player data using the codec
        encodedData = playerContract.codec().encodePlayerData(playerId, pStats, seasonalRecord);
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

    /// @notice Returns information about the pending gauntlet.
    /// @return exists Whether a pending gauntlet exists.
    /// @return selectionBlock The block for participant selection (if in phase 1).
    /// @return tournamentBlock The block for tournament execution (if in phase 2).
    /// @return phase The current phase of the pending gauntlet.
    /// @return gauntletId The ID assigned to this gauntlet.
    /// @return participantCount Number of selected participants (if in phase 2+).
    function getPendingGauntletInfo()
        external
        view
        returns (
            bool exists,
            uint256 selectionBlock,
            uint256 tournamentBlock,
            uint8 phase,
            uint256 gauntletId,
            uint256 participantCount
        )
    {
        exists = (pendingGauntlet.phase != GauntletPhase.NONE);
        selectionBlock = pendingGauntlet.selectionBlock;
        tournamentBlock = pendingGauntlet.tournamentBlock;
        phase = uint8(pendingGauntlet.phase);
        gauntletId = pendingGauntlet.gauntletId;
        // Get participant count from the actual gauntlet if it exists
        if (pendingGauntlet.phase != GauntletPhase.NONE && pendingGauntlet.phase != GauntletPhase.QUEUE_COMMIT) {
            participantCount = gauntlets[pendingGauntlet.gauntletId].participants.length;
        } else {
            participantCount = 0;
        }
    }

    /// @notice Checks if the pending gauntlet can be recovered.
    /// @return True if recovery is possible (256 blocks have passed since commit).
    function canRecoverPendingGauntlet() public view returns (bool) {
        if (pendingGauntlet.phase == GauntletPhase.NONE) return false;

        // After 256 blocks from commit, blockhash(revealBlock) returns 0
        uint256 commitBlock;
        if (pendingGauntlet.phase == GauntletPhase.QUEUE_COMMIT) {
            commitBlock = pendingGauntlet.selectionBlock - futureBlocksForSelection;
        } else {
            commitBlock = pendingGauntlet.tournamentBlock - futureBlocksForTournament - futureBlocksForSelection;
        }
        return block.number > commitBlock + 256;
    }

    /// @notice Recovers a pending gauntlet after the 256-block window.
    /// @dev Clears the pending gauntlet without executing it.
    function recoverPendingGauntlet() external nonReentrant {
        if (!canRecoverPendingGauntlet()) revert CannotRecoverYet();

        // Store timestamp for event
        uint256 timestamp = pendingGauntlet.commitTimestamp;

        // Clear pending gauntlet
        delete pendingGauntlet;

        // No need to process participants - they're still in queue
        emit GauntletRecovered(timestamp);
    }

    //==============================================================//
    //                     ADMIN FUNCTIONS                          //
    //==============================================================//

    /// @notice Toggles the ability for players to queue for Gauntlets.
    /// @dev If set to `false`, clears the current queue.
    /// @param enabled The desired state (true = enabled, false = disabled).
    function setGameEnabled(bool enabled) external onlyOwner nonReentrant {
        if (isGameEnabled == enabled) return; // No change needed

        isGameEnabled = enabled;

        // If disabling the game, clear queue in batches for gas safety
        if (!enabled && queueIndex.length > 0) {
            // Clear up to CLEAR_BATCH_SIZE players to avoid gas issues
            uint256 clearCount = queueIndex.length > CLEAR_BATCH_SIZE ? CLEAR_BATCH_SIZE : queueIndex.length;

            for (uint256 i = 0; i < clearCount; i++) {
                uint32 playerId = queueIndex[queueIndex.length - 1]; // Always remove last

                // Clear player state if they were QUEUED
                if (playerStatus[playerId] == PlayerStatus.QUEUED) {
                    delete registrationQueue[playerId];
                    playerStatus[playerId] = PlayerStatus.NONE;
                }

                // Remove from queue array
                queueIndex.pop();
            }

            emit QueuePartiallyCleared(clearCount, queueIndex.length);
        }

        // Always emit the state change event
        emit GameEnabledUpdated(enabled);
    }

    /// @notice Sets the number of future blocks for participant selection.
    /// @param blocks The number of blocks to wait before selection.
    function setFutureBlocksForSelection(uint256 blocks) external onlyOwner {
        if (blocks == 0 || blocks > 255) revert InvalidFutureBlocks(blocks);
        if (blocks == futureBlocksForSelection) return; // No change needed
        futureBlocksForSelection = blocks;
        emit FutureBlocksForSelectionSet(blocks);
    }

    /// @notice Sets the number of future blocks for tournament execution.
    /// @param blocks The number of blocks to wait before tournament.
    function setFutureBlocksForTournament(uint256 blocks) external onlyOwner {
        if (blocks == 0 || blocks > 255) revert InvalidFutureBlocks(blocks);
        if (blocks == futureBlocksForTournament) return; // No change needed
        futureBlocksForTournament = blocks;
        emit FutureBlocksForTournamentSet(blocks);
    }

    /// @notice Emergency function to clear players from queue in gas-safe batches.
    /// @dev Clears up to CLEAR_BATCH_SIZE players per call. Call multiple times if needed.
    function emergencyClearQueue() external onlyOwner {
        if (queueIndex.length == 0) return; // Nothing to clear

        uint256 clearCount = queueIndex.length > CLEAR_BATCH_SIZE ? CLEAR_BATCH_SIZE : queueIndex.length;

        for (uint256 i = 0; i < clearCount; i++) {
            uint32 playerId = queueIndex[queueIndex.length - 1]; // Always remove last

            // Clear player state regardless of status for emergency
            delete registrationQueue[playerId];
            if (playerStatus[playerId] == PlayerStatus.QUEUED) {
                playerStatus[playerId] = PlayerStatus.NONE;
            }

            // Remove from queue array
            queueIndex.pop();
        }

        emit EmergencyQueueCleared(clearCount, queueIndex.length);
    }

    /// @notice Updates the address of the `DefaultPlayer` contract.
    /// @param newAddress The new contract address.
    function setDefaultPlayerContract(address newAddress) external onlyOwner {
        if (newAddress == address(0)) revert ZeroAddress();
        defaultPlayerContract = IDefaultPlayer(newAddress);
        emit DefaultPlayerContractSet(newAddress);
    }

    /// @notice Sets the number of participants required to start a gauntlet (4, 8, 16, or 32).
    /// @dev The game must be disabled via `setGameEnabled(false)` before calling this function.
    ///      Disabling the game automatically clears the queue.
    /// @param newSize The new gauntlet size.
    function setGauntletSize(uint8 newSize) external onlyOwner {
        // Require game to be disabled. Disabling clears the queue.
        require(!isGameEnabled, "Game must be disabled to change gauntlet size");

        // Checks for valid size parameter
        if (newSize != 4 && newSize != 8 && newSize != 16 && newSize != 32 && newSize != 64) {
            revert InvalidGauntletSize(newSize);
        }

        uint8 oldSize = currentGauntletSize;
        if (oldSize == newSize) return; // No change needed

        // Effect & Interaction
        currentGauntletSize = newSize;
        emit GauntletSizeSet(oldSize, newSize);
    }

    /// @notice Helper to check if a player ID is a default player (1-2000 range)
    /// @param playerId The player ID to check
    /// @return True if the player ID is in default player range
    function _isDefaultPlayerId(uint32 playerId) internal pure returns (bool) {
        return playerId >= 1 && playerId <= 2000;
    }
    
    /// @notice Helper to get a random valid default player ID
    /// @param randomSeed Random seed for selection
    /// @return A valid default player ID
    function _getRandomDefaultPlayerId(uint256 randomSeed) internal view returns (uint32) {
        uint256 defaultCount = defaultPlayerContract.validDefaultPlayerCount();
        if (defaultCount == 0) revert NoDefaultPlayersAvailable();
        
        uint256 randomIndex = randomSeed % defaultCount;
        return defaultPlayerContract.getValidDefaultPlayerId(randomIndex);
    }
    
    /// @notice Helper to select unique default player IDs without duplicates  
    /// @param randomSeed Random seed for selection
    /// @param count Number of unique defaults needed
    /// @param excludeIds Array of default IDs to exclude from selection
    /// @return Array of unique default player IDs
    function _selectUniqueDefaults(uint256 randomSeed, uint256 count, uint32[] memory excludeIds) 
        internal view returns (uint32[] memory) {
        uint256 totalDefaults = defaultPlayerContract.validDefaultPlayerCount();
        if (count > totalDefaults) revert InsufficientDefaultPlayers(count, totalDefaults);
        
        // Simple approach: select without replacement using exclusion
        uint32[] memory selected = new uint32[](count);
        uint256 selectedCount = 0;
        uint256 attempts = 0;
        uint256 maxAttempts = totalDefaults * 10; // Generous safety limit
        
        while (selectedCount < count && attempts < maxAttempts) {
            // Generate next candidate
            randomSeed = uint256(keccak256(abi.encodePacked(randomSeed, attempts)));
            uint256 randomIndex = randomSeed % totalDefaults;
            uint32 candidate = defaultPlayerContract.getValidDefaultPlayerId(randomIndex);
            
            // Check if candidate is already excluded
            bool isExcluded = false;
            for (uint256 i = 0; i < excludeIds.length; i++) {
                if (candidate == excludeIds[i]) {
                    isExcluded = true;
                    break;
                }
            }
            
            // Check if candidate is already selected
            if (!isExcluded) {
                for (uint256 i = 0; i < selectedCount; i++) {
                    if (candidate == selected[i]) {
                        isExcluded = true;
                        break;
                    }
                }
            }
            
            // Add to selection if unique
            if (!isExcluded) {
                selected[selectedCount] = candidate;
                selectedCount++;
            }
            
            attempts++;
        }
        
        // Safety check - should never happen with sufficient defaults
        if (selectedCount < count) {
            revert InsufficientDefaultPlayers(count, totalDefaults - excludeIds.length);
        }
        
        return selected;
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

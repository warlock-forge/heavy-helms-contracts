// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

//==============================================================//
//                            IMPORTS                           //
//==============================================================//
import {BaseGame, ZeroAddress} from "./BaseGame.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {UniformRandomNumber} from "../../lib/UniformRandomNumber.sol";
import {IGameEngine} from "../../interfaces/game/engine/IGameEngine.sol";
import {IPlayer} from "../../interfaces/fighters/IPlayer.sol";
import {IEquipmentRequirements} from "../../interfaces/game/engine/IEquipmentRequirements.sol";
import {IPlayerSkinRegistry} from "../../interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";
import {IPlayerSkinNFT} from "../../interfaces/nft/skins/IPlayerSkinNFT.sol";
import {Fighter} from "../../fighters/Fighter.sol";
import {IDefaultPlayer} from "../../interfaces/fighters/IDefaultPlayer.sol";
import {IPlayerTickets} from "../../interfaces/nft/IPlayerTickets.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

//==============================================================//
//                         CUSTOM ERRORS                        //
//==============================================================//
error TournamentDoesNotExist();
error PlayerNotInQueue();
error AlreadyInQueue();
error PlayerIsRetired();
error InvalidLoadout();
error InvalidSkin();
error CallerNotPlayerOwner();
error TournamentNotPending();
error GameDisabled();
error InvalidTournamentSize(uint8 size);
error QueueNotEmpty();
error QueueEmpty();
error TimeoutNotReached();
error UnsupportedPlayerId();
error TournamentTooEarly();
error TournamentTooLate();
error MinTimeNotElapsed();
error PendingTournamentExists();
error NoPendingTournament();
error InvalidPhaseTransition();
error SelectionBlockNotReached(uint256 selectionBlock, uint256 currentBlock);
error TournamentBlockNotReached(uint256 tournamentBlock, uint256 currentBlock);
error InvalidFutureBlocks(uint256 blocks);
error CannotRecoverYet();
error InvalidRewardPercentages();
error NoDefaultPlayersAvailable();
error InsufficientDefaultPlayers(uint256 needed, uint256 available);
error PlayerLevelTooLow();
error InvalidBlockhash();

//==============================================================//
//                           HEAVY HELMS                        //
//                        TOURNAMENT GAME                       //
//==============================================================//
/// @title Tournament Game Mode for Heavy Helms
/// @notice Manages daily elimination tournaments with level-based priority,
///         tournament ratings, death mechanics, and reward distribution.
/// @dev Uses a commit-reveal pattern with future blockhash for randomness.
contract TournamentGame is BaseGame, ConfirmedOwner, ReentrancyGuard {
    using UniformRandomNumber for uint256;
    using SafeTransferLib for address;

    //==============================================================//
    //                          ENUMS                               //
    //==============================================================//
    /// @notice Represents the state of a Tournament run.
    enum TournamentState {
        PENDING, // Tournament started, awaiting completion.
        COMPLETED // Tournament finished.

    }

    /// @notice Represents the phase of the 3-transaction tournament system.
    enum TournamentPhase {
        NONE, // No pending tournament
        QUEUE_COMMIT, // Phase 1: Waiting for participant selection block
        PARTICIPANT_SELECT, // Phase 2: Waiting for tournament execution block
        TOURNAMENT_READY // Phase 3: Ready to execute tournament

    }

    /// @notice Represents the current status of a player in relation to the Tournament mode.
    enum PlayerStatus {
        NONE, // Not participating.
        QUEUED, // Waiting in the queue, can withdraw.
        IN_TOURNAMENT // Actively participating in a Tournament run.

    }

    /// @notice Reasons why a player might be replaced in a tournament.
    enum ReplacementReason {
        PLAYER_RETIRED,
        SKIN_OWNERSHIP_LOST
    }

    //==============================================================//
    //                           STRUCTS                            //
    //==============================================================//
    /// @notice Tournament data structure for contract storage.
    /// @dev Participants needed for commit-reveal, other arrays kept in memory only.
    struct Tournament {
        uint256 id;
        uint8 size;
        TournamentState state;
        uint256 startTimestamp;
        uint256 completionTimestamp;
        RegisteredPlayer[] participants; // Needed for commit-reveal pattern
        uint32 championId;
        uint32 runnerUpId;
    }

    /// @notice Compact struct storing participant data within a Tournament.
    struct RegisteredPlayer {
        uint32 playerId;
        Fighter.PlayerLoadout loadout;
    }

    /// @notice Active participant with all combat data ready for tournament execution.
    struct ActiveParticipant {
        uint32 playerId;
        IGameEngine.FighterStats stats;
        bytes32 encodedData;
    }

    /// @notice Structure for pending tournament using 3-transaction pattern.
    struct PendingTournament {
        TournamentPhase phase;
        uint256 selectionBlock;
        uint256 tournamentBlock;
        uint256 commitTimestamp;
        uint256 tournamentId;
    }

    //==============================================================//
    //                          STATE VARIABLES                     //
    //==============================================================//

    // --- Configuration & Roles ---
    /// @notice Contract managing default player data.
    IDefaultPlayer public defaultPlayerContract;
    /// @notice PlayerTickets contract for minting rewards.
    IPlayerTickets public immutable playerTickets;
    /// @notice Number of blocks in the future for participant selection.
    uint256 public futureBlocksForSelection = 20;
    /// @notice Number of blocks in the future for tournament execution.
    uint256 public futureBlocksForTournament = 20;
    /// @notice Whether the game is enabled for queueing.
    bool public isGameEnabled = true;
    /// @notice Daily tournament hour in UTC (20:00).
    uint256 public constant DAILY_TOURNAMENT_HOUR = 20;
    /// @notice Window after tournament hour to run (1 hour).
    uint256 public constant TOURNAMENT_WINDOW_HOURS = 1;
    /// @notice Lethality factor for tournament matches.
    uint16 public lethalityFactor = 20;

    // --- Dynamic Settings ---
    /// @notice Current number of participants required for tournament (16, 32, or 64).
    uint8 public currentTournamentSize = 16;

    // --- Tournament State ---
    /// @notice Counter for assigning unique Tournament IDs.
    uint256 public nextTournamentId;
    /// @notice Maps Tournament IDs to their detailed `Tournament` struct data.
    mapping(uint256 => Tournament) public tournaments;
    /// @notice The pending tournament waiting for reveal.
    PendingTournament public pendingTournament;
    /// @notice Last timestamp when a tournament was started.
    uint256 public lastTournamentStartTimestamp;
    /// @notice Previous tournament winner and runner-up for auto-queue.
    uint32 public previousChampionId;
    uint32 public previousRunnerUpId;

    // --- Queue State ---
    /// @notice Stores loadout data for players currently in the queue.
    mapping(uint32 => RegisteredPlayer) public registrationQueue;
    /// @notice Array containing the IDs of players currently in the queue.
    uint32[] public queueIndex;
    /// @notice Maps player IDs to their (1-based) index within the `queueIndex` array for O(1) lookup during removal.
    mapping(uint32 => uint256) public playerIndexInQueue;

    // --- Player State ---
    /// @notice Tracks the current status (NONE, QUEUED, IN_TOURNAMENT) of a player.
    mapping(uint32 => PlayerStatus) public playerStatus;

    // --- Tournament Rating State ---
    /// @notice Maps player ID to season ID to their tournament rating.
    mapping(uint32 => mapping(uint256 => uint16)) public seasonalRatings;

    // --- Reward Configuration ---
    /// @notice Reward percentages for winners (1st place).
    IPlayerTickets.RewardConfig public winnerRewards = IPlayerTickets.RewardConfig({
        nonePercent: 0,
        attributeSwapPercent: 500,
        createPlayerPercent: 2250,
        playerSlotPercent: 2250,
        weaponSpecPercent: 0,
        armorSpecPercent: 0,
        duelTicketPercent: 0,
        dailyResetPercent: 2000,
        nameChangePercent: 3000
    });

    /// @notice Reward percentages for runner-up (2nd place).
    IPlayerTickets.RewardConfig public runnerUpRewards = IPlayerTickets.RewardConfig({
        nonePercent: 0,
        attributeSwapPercent: 100,
        createPlayerPercent: 1500,
        playerSlotPercent: 1500,
        weaponSpecPercent: 500,
        armorSpecPercent: 500,
        duelTicketPercent: 1000,
        dailyResetPercent: 3000,
        nameChangePercent: 1900
    });

    /// @notice Reward percentages for 3rd-4th place.
    IPlayerTickets.RewardConfig public thirdFourthRewards = IPlayerTickets.RewardConfig({
        nonePercent: 1000,
        attributeSwapPercent: 0,
        createPlayerPercent: 500,
        playerSlotPercent: 500,
        weaponSpecPercent: 1500,
        armorSpecPercent: 1500,
        duelTicketPercent: 3000,
        dailyResetPercent: 1500,
        nameChangePercent: 500
    });

    //==============================================================//
    //                            EVENTS                            //
    //==============================================================//
    /// @notice Emitted when a player successfully joins the queue.
    event PlayerQueued(uint32 indexed playerId, uint256 queueSize);
    /// @notice Emitted when a player successfully withdraws from the queue.
    event PlayerWithdrew(uint32 indexed playerId, uint256 queueSize);
    /// @notice Emitted when phase 1 is completed (queue committed).
    event QueueCommitted(uint256 selectionBlock, uint256 queueSize);
    /// @notice Emitted when phase 2 is completed (participants selected).
    event ParticipantsSelected(uint256 indexed tournamentId, uint256 tournamentBlock, uint32[] selectedIds);
    /// @notice Emitted when a Tournament is started (phase 3).
    event TournamentStarted(uint256 indexed tournamentId, uint8 size, RegisteredPlayer[] participants);
    /// @notice Emitted when a Tournament is successfully completed.
    event TournamentCompleted(
        uint256 indexed tournamentId,
        uint8 size,
        uint32 indexed championId,
        uint32 runnerUpId,
        uint256 seasonId,
        uint32[] participantIds,
        uint32[] roundWinners
    );
    /// @notice Emitted when tournament ratings are awarded.
    event TournamentRatingsAwarded(
        uint256 indexed tournamentId, uint256 indexed seasonId, uint32[] playerIds, uint16[] ratings
    );
    /// @notice Emitted when a player is retired due to death in tournament.
    event PlayerRetiredInTournament(uint256 indexed tournamentId, uint32 indexed playerId);
    /// @notice Emitted when rewards are distributed to a player.
    event RewardDistributed(
        uint256 indexed tournamentId, uint32 indexed playerId, IPlayerTickets.RewardType rewardType, uint256 ticketId
    );
    /// @notice Emitted when a player is replaced during tournament execution.
    event PlayerReplaced(
        uint256 indexed tournamentId,
        uint32 indexed originalPlayerId,
        uint32 indexed replacementPlayerId,
        ReplacementReason reason
    );
    /// @notice Emitted when a tournament is auto-recovered due to blockhash expiration.
    event TournamentAutoRecovered(uint256 commitBlock, uint256 currentBlock, TournamentPhase phase);
    /// @notice Emitted when a new season starts (synced from Player contract).
    /// @notice Emitted when the tournament size is changed.
    event TournamentSizeSet(uint8 oldSize, uint8 newSize);
    /// @notice Emitted when the lethality factor is updated.
    event LethalityFactorSet(uint16 oldFactor, uint16 newFactor);
    /// @notice Emitted when reward configurations are updated.
    event RewardConfigUpdated(uint8 indexed placement, IPlayerTickets.RewardConfig config);
    /// @notice Emitted when the game enabled status is changed.
    event GameEnabledChanged(bool oldEnabled, bool newEnabled);
    // Inherited from BaseGame: event CombatResult(bytes32 indexed player1Data, bytes32 indexed player2Data, uint32 winnerId, bytes combatLog);

    //==============================================================//
    //                          MODIFIERS                           //
    //==============================================================//
    /// @notice Ensures the game is not disabled before proceeding.
    modifier whenGameEnabled() {
        if (!isGameEnabled) revert GameDisabled();
        _;
    }

    //==============================================================//
    //                         CONSTRUCTOR                          //
    //==============================================================//
    /// @notice Initializes the TournamentGame contract.
    /// @param _gameEngine Address of the `GameEngine` contract.
    /// @param _playerContract Address of the `Player` contract.
    /// @param _defaultPlayerAddress Address of the `DefaultPlayer` contract.
    /// @param _playerTicketsAddress Address of the `PlayerTickets` contract.
    constructor(
        address _gameEngine,
        address payable _playerContract,
        address _defaultPlayerAddress,
        address _playerTicketsAddress
    ) BaseGame(_gameEngine, _playerContract) ConfirmedOwner(msg.sender) {
        // Input validation
        if (_defaultPlayerAddress == address(0)) revert ZeroAddress();
        if (_playerTicketsAddress == address(0)) revert ZeroAddress();

        // Set initial state
        defaultPlayerContract = IDefaultPlayer(_defaultPlayerAddress);
        playerTickets = IPlayerTickets(_playerTicketsAddress);
        lastTournamentStartTimestamp = block.timestamp;

        // Emit initial reward configurations
        emit RewardConfigUpdated(0, winnerRewards);
        emit RewardConfigUpdated(1, runnerUpRewards);
        emit RewardConfigUpdated(2, thirdFourthRewards);

        // No need to store season - always get from Player contract
    }

    //==============================================================//
    //                      EXTERNAL FUNCTIONS                      //
    //==============================================================//

    // --- Queue Management ---

    /// @notice Allows a player owner to join the Tournament queue with a specific loadout.
    /// @param loadout The player's chosen skin and stance for the potential Tournament.
    /// @dev Requires level 10+. Auto-accepts previous champion and runner-up.
    function queueForTournament(Fighter.PlayerLoadout calldata loadout) external whenGameEnabled {
        // Checks
        if (playerStatus[loadout.playerId] != PlayerStatus.NONE) revert AlreadyInQueue();

        // Get player stats first (this validates player exists)
        IPlayer.PlayerStats memory playerStats = playerContract.getPlayer(loadout.playerId);
        if (playerStats.level < 10) revert PlayerLevelTooLow();

        // Get owner and validate caller (single external call)
        address owner = playerContract.getPlayerOwner(loadout.playerId);
        if (msg.sender != owner) revert CallerNotPlayerOwner();

        // Check retirement status (single external call)
        if (playerContract.isPlayerRetired(loadout.playerId)) revert PlayerIsRetired();

        // Cache equipment requirements and skin registry to avoid repeated external calls
        IEquipmentRequirements equipmentReqs = playerContract.equipmentRequirements();
        IPlayerSkinRegistry skinRegistry = playerContract.skinRegistry();

        // Validate skin and equipment requirements via cached registry reference
        try skinRegistry.validateSkinOwnership(loadout.skin, owner) {}
        catch {
            revert InvalidSkin();
        }
        try skinRegistry.validateSkinRequirements(loadout.skin, playerStats.attributes, equipmentReqs) {}
        catch {
            revert InvalidLoadout();
        }

        // Effects
        uint32 playerId = loadout.playerId;
        registrationQueue[playerId] = RegisteredPlayer({playerId: playerId, loadout: loadout});
        queueIndex.push(playerId);
        playerIndexInQueue[playerId] = queueIndex.length; // 1-based index
        playerStatus[playerId] = PlayerStatus.QUEUED;

        // Interactions (Event Emission)
        emit PlayerQueued(playerId, queueIndex.length);
    }

    /// @notice Allows a player owner to withdraw their player from the queue before a Tournament starts.
    /// @param playerId The ID of the player to withdraw.
    function withdrawFromQueue(uint32 playerId) external {
        // Checks
        address owner = playerContract.getPlayerOwner(playerId);
        if (msg.sender != owner) revert CallerNotPlayerOwner();
        if (playerStatus[playerId] != PlayerStatus.QUEUED) {
            revert PlayerNotInQueue();
        }

        // Effects - update player state
        _removePlayerFromQueueArrayIndex(playerId);
        delete registrationQueue[playerId];
        playerStatus[playerId] = PlayerStatus.NONE;

        // Interactions - emit event
        emit PlayerWithdrew(playerId, queueIndex.length);
    }

    /// @notice Returns the current number of players waiting in the queue.
    function getQueueSize() external view returns (uint256) {
        return queueIndex.length;
    }

    // --- Tournament Lifecycle ---

    /// @notice Attempts to start a new Tournament using 3-transaction commit-reveal pattern.
    /// @dev Callable by anyone. Enforces daily timing constraints.
    function tryStartTournament() external whenGameEnabled nonReentrant {
        // Handle pending tournament phases
        // Cache pending tournament state to avoid multiple storage reads
        TournamentPhase currentPhase = pendingTournament.phase;
        if (currentPhase != TournamentPhase.NONE) {
            uint256 selectionBlock = pendingTournament.selectionBlock;
            uint256 tournamentBlock = pendingTournament.tournamentBlock;

            // Check if we're past the 256-block limit from initial commit for auto-recovery
            uint256 commitBlock = (currentPhase == TournamentPhase.QUEUE_COMMIT)
                ? selectionBlock - futureBlocksForSelection
                : tournamentBlock - futureBlocksForTournament - futureBlocksForSelection;

            if (block.number >= commitBlock + 256) {
                // Auto-recovery if we missed the window
                emit TournamentAutoRecovered(commitBlock, block.number, currentPhase);
                _recoverPendingTournament();
                return;
            }

            if (currentPhase == TournamentPhase.QUEUE_COMMIT) {
                // Phase 2: Participant Selection
                if (block.number >= selectionBlock) {
                    _selectParticipantsPhase();
                    return;
                } else {
                    revert SelectionBlockNotReached(selectionBlock, block.number);
                }
            } else if (currentPhase == TournamentPhase.PARTICIPANT_SELECT) {
                // Phase 3: Tournament Execution
                if (block.number >= tournamentBlock) {
                    _executeTournamentPhase();
                    return;
                } else {
                    revert TournamentBlockNotReached(tournamentBlock, block.number);
                }
            }

            // If we reach here, we're waiting for the next phase
            return;
        }

        // Phase 1: Queue Commit - Check daily timing constraints
        uint256 currentHour = (block.timestamp / 1 hours) % 24;
        uint256 currentDay = block.timestamp / 1 days;
        uint256 lastTournamentDay = lastTournamentStartTimestamp / 1 days;

        // Must be after tournament hour but within window
        if (currentHour < DAILY_TOURNAMENT_HOUR) {
            revert TournamentTooEarly();
        }
        if (currentHour >= DAILY_TOURNAMENT_HOUR + TOURNAMENT_WINDOW_HOURS) {
            revert TournamentTooLate();
        }
        // Ensure only one tournament per day
        if (currentDay <= lastTournamentDay) {
            revert MinTimeNotElapsed();
        }

        // Require at least one real player in queue (no point running tournament with only defaults)
        if (queueIndex.length == 0) {
            revert QueueEmpty();
        }

        _commitQueuePhase();
    }

    // --- View Functions ---

    /// @notice Returns tournament data.
    function getTournamentData(uint256 tournamentId) external view returns (Tournament memory) {
        if (tournamentId >= nextTournamentId) revert TournamentDoesNotExist();
        return tournaments[tournamentId];
    }

    /// @notice Returns a player's current season tournament rating.
    function getPlayerRating(uint32 playerId) external view returns (uint16) {
        // Always get from seasonal mapping using current season from Player contract
        return seasonalRatings[playerId][playerContract.currentSeason()];
    }

    /// @notice Returns a player's tournament rating for a specific season.
    function getPlayerSeasonRating(uint32 playerId, uint256 seasonId) external view returns (uint16) {
        return seasonalRatings[playerId][seasonId];
    }

    /// @notice Helper function to get a player's current season rating.
    /// @dev This is a convenience method that's equivalent to getPlayerRating.
    function currentSeasonRating(uint32 playerId) external view returns (uint256) {
        return seasonalRatings[playerId][playerContract.currentSeason()];
    }

    /// @notice Returns information about the pending tournament.
    function getPendingTournamentInfo()
        external
        view
        returns (
            bool exists,
            uint256 selectionBlock,
            uint256 tournamentBlock,
            uint8 phase,
            uint256 tournamentId,
            uint256 participantCount
        )
    {
        exists = (pendingTournament.phase != TournamentPhase.NONE);
        selectionBlock = pendingTournament.selectionBlock;
        tournamentBlock = pendingTournament.tournamentBlock;
        phase = uint8(pendingTournament.phase);
        tournamentId = pendingTournament.tournamentId;
        // Get participant count from the actual tournament if it exists
        if (pendingTournament.phase != TournamentPhase.NONE && pendingTournament.phase != TournamentPhase.QUEUE_COMMIT)
        {
            participantCount = tournaments[pendingTournament.tournamentId].participants.length;
        } else {
            participantCount = 0;
        }
    }

    //==============================================================//
    //                       ADMIN FUNCTIONS                        //
    //==============================================================//

    /// @notice Sets the tournament size (16, 32, or 64).
    function setTournamentSize(uint8 newSize) external onlyOwner {
        if (pendingTournament.phase != TournamentPhase.NONE) {
            revert PendingTournamentExists();
        }
        if (newSize != 16 && newSize != 32 && newSize != 64) {
            revert InvalidTournamentSize(newSize);
        }
        uint8 oldSize = currentTournamentSize;
        currentTournamentSize = newSize;
        emit TournamentSizeSet(oldSize, newSize);
    }

    /// @notice Sets the lethality factor for tournament matches.
    function setLethalityFactor(uint16 newFactor) external onlyOwner {
        uint16 oldFactor = lethalityFactor;
        lethalityFactor = newFactor;
        emit LethalityFactorSet(oldFactor, newFactor);
    }

    /// @notice Updates reward configuration for winners.
    function setWinnerRewards(IPlayerTickets.RewardConfig calldata config) external onlyOwner {
        uint256 total = config.nonePercent + config.attributeSwapPercent + config.createPlayerPercent
            + config.playerSlotPercent + config.weaponSpecPercent + config.armorSpecPercent + config.duelTicketPercent
            + config.dailyResetPercent + config.nameChangePercent;
        if (total != 10000) revert InvalidRewardPercentages();

        winnerRewards = config;
        emit RewardConfigUpdated(0, config);
    }

    /// @notice Updates reward configuration for runner-up.
    function setRunnerUpRewards(IPlayerTickets.RewardConfig calldata config) external onlyOwner {
        uint256 total = config.nonePercent + config.attributeSwapPercent + config.createPlayerPercent
            + config.playerSlotPercent + config.weaponSpecPercent + config.armorSpecPercent + config.duelTicketPercent
            + config.dailyResetPercent + config.nameChangePercent;
        if (total != 10000) revert InvalidRewardPercentages();

        runnerUpRewards = config;
        emit RewardConfigUpdated(1, config);
    }

    /// @notice Updates reward configuration for 3rd-4th place.
    function setThirdFourthRewards(IPlayerTickets.RewardConfig calldata config) external onlyOwner {
        uint256 total = config.nonePercent + config.attributeSwapPercent + config.createPlayerPercent
            + config.playerSlotPercent + config.weaponSpecPercent + config.armorSpecPercent + config.duelTicketPercent
            + config.dailyResetPercent + config.nameChangePercent;
        if (total != 10000) revert InvalidRewardPercentages();

        thirdFourthRewards = config;
        emit RewardConfigUpdated(2, config);
    }

    /// @notice Toggles whether the game is enabled.
    function setGameEnabled(bool enabled) external onlyOwner {
        bool oldEnabled = isGameEnabled;
        isGameEnabled = enabled;
        emit GameEnabledChanged(oldEnabled, enabled);
    }

    /// @notice Sets a new game engine address
    /// @param _newEngine Address of the new game engine
    /// @dev Only callable by the contract owner
    function setGameEngine(address _newEngine) public override(BaseGame) onlyOwner {
        super.setGameEngine(_newEngine);
    }

    //==============================================================//
    //                     INTERNAL FUNCTIONS                       //
    //==============================================================//

    // --- Commit-Reveal Functions ---

    /// @notice Phase 1: Commits the queue and sets up for participant selection.
    function _commitQueuePhase() private {
        // Update timing
        lastTournamentStartTimestamp = block.timestamp;

        // Initialize pending tournament for phase 1
        pendingTournament.phase = TournamentPhase.QUEUE_COMMIT;
        pendingTournament.selectionBlock = block.number + futureBlocksForSelection;
        pendingTournament.commitTimestamp = block.timestamp;
        pendingTournament.tournamentId = nextTournamentId;

        emit QueueCommitted(pendingTournament.selectionBlock, queueIndex.length);
    }

    /// @notice Phase 2: Selects participants using enhanced randomness and level priority.
    function _selectParticipantsPhase() private {
        // Get enhanced randomness from selection block
        uint256 seed = _getEnhancedRandomness(pendingTournament.selectionBlock);

        // No need to sync - always get current season from Player contract

        // Select participants (level 10+ requirement enforced at queue entry)
        uint32[] memory selectedIds = _selectParticipantsWithPriority(seed);

        // Create the actual tournament
        uint256 tournamentId = pendingTournament.tournamentId;
        nextTournamentId++;
        Tournament storage tournament = tournaments[tournamentId];
        tournament.id = tournamentId;
        tournament.size = uint8(selectedIds.length);
        tournament.state = TournamentState.PENDING;
        tournament.startTimestamp = block.timestamp;

        // Store participants (needed for commit-reveal pattern)
        uint256 selectedCount = selectedIds.length;
        for (uint256 i = 0; i < selectedCount; i++) {
            uint32 playerId = selectedIds[i];

            // Check if this is a default player (added to fill spots)
            if (_isDefaultPlayerId(playerId)) {
                // Create a default player registration
                RegisteredPlayer memory defaultReg;
                defaultReg.playerId = playerId;
                // Default loadout - will be handled during combat
                tournament.participants.push(defaultReg);
            } else {
                // Regular player from queue
                RegisteredPlayer memory regPlayer = registrationQueue[playerId];
                tournament.participants.push(regPlayer);

                // Update player status
                playerStatus[playerId] = PlayerStatus.IN_TOURNAMENT;
            }
        }

        // Remove selected players from queue (not default players)
        for (uint256 i = 0; i < selectedCount; i++) {
            uint32 playerId = selectedIds[i];
            if (!_isDefaultPlayerId(playerId) && playerIndexInQueue[playerId] > 0) {
                _removePlayerFromQueueArrayIndex(playerId);
                delete registrationQueue[playerId];
            }
        }

        // Emit start event
        emit TournamentStarted(tournamentId, tournament.size, tournament.participants);

        // Set up tournament phase
        pendingTournament.phase = TournamentPhase.PARTICIPANT_SELECT;
        pendingTournament.tournamentBlock = block.number + futureBlocksForTournament;

        emit ParticipantsSelected(pendingTournament.tournamentId, pendingTournament.tournamentBlock, selectedIds);
    }

    /// @notice Selects participants using GauntletGame-style random selection with previous winner priority.
    function _selectParticipantsWithPriority(uint256 seed) private view returns (uint32[] memory selected) {
        uint8 size = currentTournamentSize;
        selected = new uint32[](size);
        uint256 selectedCount = 0;

        // First, auto-accept previous champion and runner-up if they're in queue
        if (previousChampionId != 0 && playerStatus[previousChampionId] == PlayerStatus.QUEUED) {
            selected[selectedCount++] = previousChampionId;
        }
        if (previousRunnerUpId != 0 && playerStatus[previousRunnerUpId] == PlayerStatus.QUEUED && selectedCount < size)
        {
            selected[selectedCount++] = previousRunnerUpId;
        }

        // Use GauntletGame-style selection for remaining spots
        uint256 queueSize = queueIndex.length;
        if (selectedCount < size && queueSize > 0) {
            // Determine selection pool size (first half if queue is large enough)
            uint256 poolSize = (queueSize >= size * 2) ? queueSize / 2 : queueSize;

            // Build pool excluding already selected winners
            uint32[] memory pool = new uint32[](poolSize);
            uint256 poolIndex = 0;

            uint256 queueLength = queueIndex.length;
            for (uint256 i = 0; i < poolSize && i < queueLength; i++) {
                uint32 playerId = queueIndex[i];
                // Skip if already selected (champion/runner-up)
                if (playerId != previousChampionId && playerId != previousRunnerUpId) {
                    pool[poolIndex++] = playerId;
                }
            }

            // Select remaining spots using swap-and-pop (GauntletGame algorithm)
            uint256 remaining = poolIndex;
            for (uint256 i = selectedCount; i < size && remaining > 0; i++) {
                seed = uint256(keccak256(abi.encodePacked(seed, i)));
                uint256 index = seed.uniform(remaining);

                selected[i] = pool[index];

                // Swap and pop
                pool[index] = pool[remaining - 1];
                remaining--;
                selectedCount++;
            }
        }

        // If still not enough players, fill with default players
        if (selectedCount < size) {
            uint256 defaultsNeeded = size - selectedCount;

            // Select unique defaults (no exclusions needed for initial fill)
            // Pass empty array reference to avoid allocation
            uint32[] memory defaultIds = _selectUniqueDefaults(seed, defaultsNeeded, new uint32[](0));

            // Add selected defaults to the result
            for (uint256 i = 0; i < defaultsNeeded; i++) {
                selected[selectedCount + i] = defaultIds[i];
            }
        }

        return selected;
    }

    /// @notice Phase 3: Executes the tournament using enhanced randomness.
    function _executeTournamentPhase() private {
        // Get enhanced randomness from tournament block
        uint256 seed = _getEnhancedRandomness(pendingTournament.tournamentBlock);

        uint256 tournamentId = pendingTournament.tournamentId;

        // Clear pending tournament
        delete pendingTournament;

        // Execute the tournament
        _executeTournamentWithRandomness(tournamentId, seed);
    }

    /// @notice Helper function to clean up pending tournament state during recovery.
    function _recoverPendingTournament() private {
        // If we have participants selected but not executed, restore them to queue
        if (pendingTournament.phase == TournamentPhase.PARTICIPANT_SELECT) {
            Tournament storage tournament = tournaments[pendingTournament.tournamentId];

            // Restore selected players back to queue
            uint256 participantCount = tournament.participants.length;
            for (uint256 i = 0; i < participantCount; i++) {
                uint32 playerId = tournament.participants[i].playerId;

                // Only restore real players, not default players
                if (!_isDefaultPlayerId(playerId)) {
                    // Restore player to queue
                    queueIndex.push(playerId);
                    playerIndexInQueue[playerId] = queueIndex.length;
                    playerStatus[playerId] = PlayerStatus.QUEUED;

                    // Restore registration data (it's still in the tournament.participants)
                    registrationQueue[playerId] = tournament.participants[i];
                }
            }

            // Clean up the incomplete tournament
            delete tournaments[pendingTournament.tournamentId];

            // Roll back the tournament ID since it was never completed
            // (nextTournamentId was incremented in _selectParticipantsPhase)
            nextTournamentId--;
        }

        // Reset daily timer since no tournament actually completed
        // This allows immediate retry after recovery (1-day cooldown was already satisfied when original tournament started)
        lastTournamentStartTimestamp = 0;

        delete pendingTournament;
    }

    // --- Tournament Execution ---

    /// @notice Executes a tournament with death mechanics and rating distribution.
    function _executeTournamentWithRandomness(uint256 tournamentId, uint256 randomness) private {
        // Force season update before tournament execution to ensure correct season for all records
        uint256 season = playerContract.forceCurrentSeason();

        Tournament storage tournament = tournaments[tournamentId];
        if (tournament.state != TournamentState.PENDING) {
            return;
        }

        uint8 size = tournament.size;

        // Create active participants array with proper struct
        ActiveParticipant[] memory activeParticipants = new ActiveParticipant[](size);

        // Single pass: collect existing defaults and handle replacements immediately
        uint32[] memory existingDefaults = new uint32[](size);
        uint256 existingDefaultCount = 0;

        // First collect existing defaults for exclusion
        for (uint256 i = 0; i < size; i++) {
            if (_isDefaultPlayerId(tournament.participants[i].playerId)) {
                existingDefaults[existingDefaultCount++] = tournament.participants[i].playerId;
            }
        }

        // Build active participants with immediate replacement logic
        for (uint256 i = 0; i < size; i++) {
            uint32 activePlayerId = tournament.participants[i].playerId;

            // Check if real player needs replacement
            if (!_isDefaultPlayerId(tournament.participants[i].playerId)) {
                bool shouldReplace = false;
                ReplacementReason reason;

                // Check if player is retired
                if (playerContract.isPlayerRetired(tournament.participants[i].playerId)) {
                    shouldReplace = true;
                    reason = ReplacementReason.PLAYER_RETIRED;
                }

                // Check if player still owns their skin
                if (!shouldReplace) {
                    try playerContract.skinRegistry().validateSkinOwnership(
                        tournament.participants[i].loadout.skin,
                        playerContract.getPlayerOwner(tournament.participants[i].playerId)
                    ) {
                        // Skin validation passed
                    } catch {
                        // Skin validation failed - player no longer owns the skin
                        shouldReplace = true;
                        reason = ReplacementReason.SKIN_OWNERSHIP_LOST;
                    }
                }

                // Replace immediately if needed
                if (shouldReplace) {
                    uint32 originalPlayerId = activePlayerId;

                    // Get a single unique default player
                    uint32[] memory excludeDefaults = new uint32[](existingDefaultCount);
                    for (uint256 j = 0; j < existingDefaultCount; j++) {
                        excludeDefaults[j] = existingDefaults[j];
                    }
                    uint32[] memory singleSubstitute = _selectUniqueDefaults(randomness + i, 1, excludeDefaults);
                    activePlayerId = singleSubstitute[0];

                    // Add this new default to exclusions for future replacements
                    existingDefaults[existingDefaultCount++] = activePlayerId;

                    // Emit replacement event for subgraph tracking
                    emit PlayerReplaced(tournamentId, originalPlayerId, activePlayerId, reason);
                }
            }

            // Load combat data based on player type
            if (_isDefaultPlayerId(activePlayerId)) {
                activeParticipants[i] = _loadDefaultPlayerData(activePlayerId);
            } else {
                // Use original player's loadout since they passed validation
                activeParticipants[i] = _loadPlayerData(activePlayerId, tournament.participants[i].loadout);
            }
        }

        // Shuffle participants using clean Fisher-Yates
        activeParticipants = _shuffleParticipants(activeParticipants, randomness);

        // Run tournament rounds
        _runTournamentRounds(tournament, tournamentId, activeParticipants, randomness, season);
    }

    /// @notice Loads combat data for a default player.
    function _loadDefaultPlayerData(uint32 playerId) private view returns (ActiveParticipant memory) {
        // Tournament always uses level 10 default players for maximum competition
        IPlayer.PlayerStats memory defaultStats = defaultPlayerContract.getDefaultPlayer(playerId, 10);
        IPlayerSkinRegistry.SkinCollectionInfo memory skinInfo =
            playerContract.skinRegistry().getSkin(defaultStats.skin.skinIndex);
        IPlayerSkinNFT.SkinAttributes memory skinAttrs =
            IPlayerSkinNFT(skinInfo.contractAddress).getSkinAttributes(defaultStats.skin.skinTokenId);

        return ActiveParticipant({
            playerId: playerId,
            stats: IGameEngine.FighterStats({
                weapon: skinAttrs.weapon,
                armor: skinAttrs.armor,
                stance: defaultStats.stance,
                attributes: defaultStats.attributes,
                level: defaultStats.level,
                weaponSpecialization: defaultStats.weaponSpecialization,
                armorSpecialization: defaultStats.armorSpecialization
            }),
            encodedData: bytes32(uint256(playerId))
        });
    }

    /// @notice Loads combat data for a regular player.
    function _loadPlayerData(uint32 playerId, Fighter.PlayerLoadout memory loadout)
        private
        view
        returns (ActiveParticipant memory)
    {
        (IGameEngine.FighterStats memory stats, bytes32 encodedData) = _getFighterCombatStats(playerId, loadout);
        return ActiveParticipant({playerId: playerId, stats: stats, encodedData: encodedData});
    }

    /// @notice Runs all tournament rounds with death mechanics.
    function _runTournamentRounds(
        Tournament storage tournament,
        uint256 tournamentId,
        ActiveParticipant[] memory participants,
        uint256 randomness,
        uint256 season
    ) private {
        uint8 size = tournament.size;
        uint256 fightSeedBase = uint256(keccak256(abi.encodePacked(randomness, tournamentId)));

        // Initialize memory arrays to track eliminations (not stored in contract)
        uint32[] memory roundWinners = new uint32[](size - 1);
        uint32[] memory eliminatedByRound = new uint32[](size);
        uint256 winnerIndex = 0;
        uint256 eliminatedIndex = 0;

        // Current round participants - clean struct array
        ActiveParticipant[] memory currentRound = participants;

        // Determine number of rounds
        uint8 rounds = size == 16 ? 4 : (size == 32 ? 5 : 6);

        for (uint256 roundIndex = 0; roundIndex < rounds; roundIndex++) {
            uint256 currentRoundSize = currentRound.length;
            uint256 nextRoundSize = currentRoundSize / 2;

            // Next round participants
            ActiveParticipant[] memory nextRound = new ActiveParticipant[](nextRoundSize);

            // Process fights in this round
            for (uint256 fightIndex = 0; fightIndex < currentRoundSize; fightIndex += 2) {
                ActiveParticipant memory fighter1 = currentRound[fightIndex];
                ActiveParticipant memory fighter2 = currentRound[fightIndex + 1];

                // Generate fight seed
                uint256 fightSeed = uint256(keccak256(abi.encodePacked(fightSeedBase, roundIndex, fightIndex)));

                // Process fight WITH LETHALITY
                bytes memory results =
                    gameEngine.processGame(fighter1.stats, fighter2.stats, fightSeed, lethalityFactor);
                (bool p1Won,, IGameEngine.WinCondition condition,) = gameEngine.decodeCombatLog(results);

                // Determine winner and advance to next round
                ActiveParticipant memory winner;
                uint32 loserId;
                uint256 nextRoundArrayIndex = fightIndex / 2;

                if (p1Won) {
                    winner = fighter1;
                    loserId = fighter2.playerId;
                } else {
                    winner = fighter2;
                    loserId = fighter1.playerId;
                }

                // Advance winner to next round
                nextRound[nextRoundArrayIndex] = winner;

                // Store round winner in memory
                if (winnerIndex < size - 1) {
                    roundWinners[winnerIndex++] = winner.playerId;
                }

                // Track elimination round for rating purposes in memory
                eliminatedByRound[eliminatedIndex++] = loserId;

                // Emit combat result
                emit CombatResult(fighter1.encodedData, fighter2.encodedData, winner.playerId, results);

                // Update records and handle death
                if (_getFighterType(winner.playerId) == Fighter.FighterType.PLAYER) {
                    playerContract.incrementWins(winner.playerId, season);
                    // If opponent died, increment kills for the winner
                    if (condition == IGameEngine.WinCondition.DEATH) {
                        playerContract.incrementKills(winner.playerId, season);
                    }
                }
                if (_getFighterType(loserId) == Fighter.FighterType.PLAYER) {
                    playerContract.incrementLosses(loserId, season);

                    // Check if player died
                    if (condition == IGameEngine.WinCondition.DEATH) {
                        // Retire the player using game contract permission
                        playerContract.setPlayerRetired(loserId, true);
                        emit PlayerRetiredInTournament(tournamentId, loserId);
                    }
                }
            }

            // Move to next round - clean single assignment
            currentRound = nextRound;
        }

        // Tournament complete - record final results
        uint32 finalWinnerId = currentRound[0].playerId;
        tournament.championId = finalWinnerId;
        tournament.runnerUpId = eliminatedByRound[eliminatedIndex - 1]; // Last eliminated
        tournament.completionTimestamp = block.timestamp;
        tournament.state = TournamentState.COMPLETED;

        // Update previous champion/runner-up for next tournament
        previousChampionId = finalWinnerId;
        previousRunnerUpId = tournament.runnerUpId;

        // Clean up player statuses
        for (uint256 i = 0; i < size; i++) {
            uint32 pId = tournament.participants[i].playerId;
            if (!_isDefaultPlayerId(pId) && playerStatus[pId] == PlayerStatus.IN_TOURNAMENT) {
                playerStatus[pId] = PlayerStatus.NONE;
            }
        }

        // Award ratings and distribute rewards
        _awardTournamentRatings(tournament, eliminatedByRound, season);
        _distributeRewards(tournament, eliminatedByRound, randomness);

        // Extract participant IDs for event emission
        uint256 participantCount = participants.length;
        uint32[] memory participantIds = new uint32[](participantCount);
        for (uint256 i = 0; i < participantCount; i++) {
            participantIds[i] = participants[i].playerId;
        }

        // Emit completion event with memory arrays (for subgraph)
        emit TournamentCompleted(
            tournamentId, size, finalWinnerId, tournament.runnerUpId, season, participantIds, roundWinners
        );
    }

    // --- Rating & Rewards ---

    /// @notice Awards tournament rating points based on placement.
    function _awardTournamentRatings(Tournament storage tournament, uint32[] memory eliminatedByRound, uint256 season)
        private
    {
        uint8 size = tournament.size;
        uint32[] memory playerIds = new uint32[](size);
        uint16[] memory ratings = new uint16[](size);
        uint256 playerCount = 0;

        // Award champion (1st place - 100 rating)
        if (_getFighterType(tournament.championId) == Fighter.FighterType.PLAYER) {
            uint16 championRating = 100;
            seasonalRatings[tournament.championId][season] += championRating;
            playerIds[playerCount] = tournament.championId;
            ratings[playerCount++] = championRating;
        }

        // Award runner-up (2nd place - 60 rating, matches gauntlet pattern)
        if (_getFighterType(tournament.runnerUpId) == Fighter.FighterType.PLAYER) {
            uint16 runnerUpRating = 60;
            seasonalRatings[tournament.runnerUpId][season] += runnerUpRating;
            playerIds[playerCount] = tournament.runnerUpId;
            ratings[playerCount++] = runnerUpRating;
        }

        // Award other placements based on elimination round (matches gauntlet XP pattern)
        uint16[] memory roundRatings;
        if (size == 16) {
            roundRatings = new uint16[](4);
            roundRatings[0] = 0; // Round 1 losers (9th-16th) - 0 rating (only top 8 get rating)
            roundRatings[1] = 20; // Round 2 losers (5th-8th) - 20 rating
            roundRatings[2] = 30; // Round 3 losers (3rd-4th) - 30 rating
            roundRatings[3] = 0; // Round 4 loser (2nd) - already handled as runner-up
        } else if (size == 32) {
            roundRatings = new uint16[](5);
            roundRatings[0] = 0; // Round 1 losers (17th-32nd) - 0 rating (only top 16 get rating)
            roundRatings[1] = 10; // Round 2 losers (9th-16th) - 10 rating
            roundRatings[2] = 20; // Round 3 losers (5th-8th) - 20 rating
            roundRatings[3] = 30; // Round 4 losers (3rd-4th) - 30 rating
            roundRatings[4] = 0; // Round 5 loser (2nd) - already handled as runner-up
        } else {
            // size == 64
            roundRatings = new uint16[](6);
            roundRatings[0] = 0; // Round 1 losers (33rd-64th) - 0 rating (only top 32 get rating)
            roundRatings[1] = 5; // Round 2 losers (17th-32nd) - 5 rating
            roundRatings[2] = 10; // Round 3 losers (9th-16th) - 10 rating
            roundRatings[3] = 20; // Round 4 losers (5th-8th) - 20 rating
            roundRatings[4] = 30; // Round 5 losers (3rd-4th) - 30 rating
            roundRatings[5] = 0; // Round 6 loser (2nd) - already handled as runner-up
        }

        // Process eliminated players (skip the last one as it's the runner-up)
        uint256 eliminatedPerRound = size / 2;
        uint256 currentRound = 0;

        uint256 eliminatedCount = eliminatedByRound.length - 1;
        for (uint256 i = 0; i < eliminatedCount; i++) {
            uint32 playerId = eliminatedByRound[i];

            // Calculate which round this player was eliminated in
            if (i > 0 && i % eliminatedPerRound == 0) {
                currentRound++;
                eliminatedPerRound /= 2;
            }

            if (_getFighterType(playerId) == Fighter.FighterType.PLAYER && roundRatings[currentRound] > 0) {
                seasonalRatings[playerId][season] += roundRatings[currentRound];
                playerIds[playerCount] = playerId;
                ratings[playerCount++] = roundRatings[currentRound];
            }
        }

        // Emit rating event with actual player count
        if (playerCount > 0) {
            uint32[] memory actualPlayerIds = new uint32[](playerCount);
            uint16[] memory actualRatings = new uint16[](playerCount);
            for (uint256 i = 0; i < playerCount; i++) {
                actualPlayerIds[i] = playerIds[i];
                actualRatings[i] = ratings[i];
            }
            emit TournamentRatingsAwarded(tournament.id, season, actualPlayerIds, actualRatings);
        }
    }

    /// @notice Distributes rewards to tournament winners.
    function _distributeRewards(Tournament storage tournament, uint32[] memory eliminatedByRound, uint256 randomness)
        private
    {
        // Reward champion
        if (_getFighterType(tournament.championId) == Fighter.FighterType.PLAYER) {
            _distributeReward(tournament.id, tournament.championId, winnerRewards, randomness);
        }

        // Reward runner-up
        if (_getFighterType(tournament.runnerUpId) == Fighter.FighterType.PLAYER) {
            _distributeReward(tournament.id, tournament.runnerUpId, runnerUpRewards, randomness);
        }

        // Reward 3rd-4th place (semi-final losers)
        uint256 eliminatedLength = eliminatedByRound.length;
        uint256 semiFinalistStart = eliminatedLength - 3; // Last 3 eliminated: 2nd, 3rd, 4th
        uint256 semiFinalistEnd = eliminatedLength - 1;
        for (uint256 i = semiFinalistStart; i < semiFinalistEnd; i++) {
            uint32 playerId = eliminatedByRound[i];
            if (_getFighterType(playerId) == Fighter.FighterType.PLAYER) {
                _distributeReward(tournament.id, playerId, thirdFourthRewards, randomness);
            }
        }
    }

    /// @notice Distributes a single reward based on configured percentages.
    function _distributeReward(
        uint256 tournamentId,
        uint32 playerId,
        IPlayerTickets.RewardConfig memory config,
        uint256 randomness
    ) private {
        uint256 random = uint256(keccak256(abi.encodePacked(randomness, tournamentId, playerId)));
        uint256 roll = random.uniform(10000); // 0-9999 for percentage precision

        IPlayerTickets.RewardType rewardType;
        uint256 ticketId;

        if (roll < config.nonePercent) {
            return; // No reward
        }
        roll -= config.nonePercent;

        if (roll < config.attributeSwapPercent) {
            rewardType = IPlayerTickets.RewardType.ATTRIBUTE_SWAP;
        } else if (roll < config.attributeSwapPercent + config.createPlayerPercent) {
            rewardType = IPlayerTickets.RewardType.CREATE_PLAYER_TICKET;
            ticketId = playerTickets.CREATE_PLAYER_TICKET();
        } else if (roll < config.attributeSwapPercent + config.createPlayerPercent + config.playerSlotPercent) {
            rewardType = IPlayerTickets.RewardType.PLAYER_SLOT_TICKET;
            ticketId = playerTickets.PLAYER_SLOT_TICKET();
        } else if (
            roll
                < config.attributeSwapPercent + config.createPlayerPercent + config.playerSlotPercent
                    + config.weaponSpecPercent
        ) {
            rewardType = IPlayerTickets.RewardType.WEAPON_SPECIALIZATION_TICKET;
            ticketId = playerTickets.WEAPON_SPECIALIZATION_TICKET();
        } else if (
            roll
                < config.attributeSwapPercent + config.createPlayerPercent + config.playerSlotPercent
                    + config.weaponSpecPercent + config.armorSpecPercent
        ) {
            rewardType = IPlayerTickets.RewardType.ARMOR_SPECIALIZATION_TICKET;
            ticketId = playerTickets.ARMOR_SPECIALIZATION_TICKET();
        } else if (
            roll
                < config.attributeSwapPercent + config.createPlayerPercent + config.playerSlotPercent
                    + config.weaponSpecPercent + config.armorSpecPercent + config.duelTicketPercent
        ) {
            rewardType = IPlayerTickets.RewardType.DUEL_TICKET;
            ticketId = playerTickets.DUEL_TICKET();
        } else if (
            roll
                < config.attributeSwapPercent + config.createPlayerPercent + config.playerSlotPercent
                    + config.weaponSpecPercent + config.armorSpecPercent + config.duelTicketPercent + config.dailyResetPercent
        ) {
            rewardType = IPlayerTickets.RewardType.DAILY_RESET_TICKET;
            ticketId = playerTickets.DAILY_RESET_TICKET();
        } else {
            // Must be name change ticket (nameChangePercent is the remainder)
            rewardType = IPlayerTickets.RewardType.NAME_CHANGE_TICKET;
        }

        // Handle all reward types with gas-limited minting to prevent DoS
        if (rewardType == IPlayerTickets.RewardType.ATTRIBUTE_SWAP) {
            // Mint attribute swap NFT ticket with gas limit
            try playerTickets.mintFungibleTicketSafe(
                playerContract.getPlayerOwner(playerId), playerTickets.ATTRIBUTE_SWAP_TICKET(), 1
            ) {
                emit RewardDistributed(tournamentId, playerId, rewardType, playerTickets.ATTRIBUTE_SWAP_TICKET());
            } catch {
                emit RewardDistributed(tournamentId, playerId, rewardType, 0);
            }
        } else if (rewardType == IPlayerTickets.RewardType.NAME_CHANGE_TICKET) {
            // Mint name change NFT with VRF randomness and gas limit
            try playerTickets.mintNameChangeNFTSafe(playerContract.getPlayerOwner(playerId), random) returns (
                uint256 newTicketId
            ) {
                emit RewardDistributed(tournamentId, playerId, rewardType, newTicketId);
            } catch {
                emit RewardDistributed(tournamentId, playerId, rewardType, 0);
            }
            return; // Early return for name change tickets
        } else if (ticketId > 0) {
            // Mint fungible ticket for other reward types with gas limit
            try playerTickets.mintFungibleTicketSafe(playerContract.getPlayerOwner(playerId), ticketId, 1) {
                emit RewardDistributed(tournamentId, playerId, rewardType, ticketId);
            } catch {
                emit RewardDistributed(tournamentId, playerId, rewardType, 0);
            }
        } else {
            emit RewardDistributed(tournamentId, playerId, rewardType, ticketId);
        }
    }

    // --- Internal Helpers ---
    /// @notice Generates enhanced randomness combining multiple entropy sources
    /// @param futureBlock The future block number to use for base randomness
    /// @return Enhanced random seed combining blockhash with additional entropy
    function _getEnhancedRandomness(uint256 futureBlock) private view returns (uint256) {
        uint256 baseHash = uint256(blockhash(futureBlock));
        if (baseHash == 0) revert InvalidBlockhash();

        return uint256(keccak256(abi.encodePacked(baseHash, block.timestamp, block.number, gasleft(), tx.origin)));
    }

    /// @notice Internal helper to remove a player from queue using swap-and-pop.
    function _removePlayerFromQueueArrayIndex(uint32 playerId) internal {
        uint256 indexToRemove = playerIndexInQueue[playerId] - 1;
        uint256 lastIndex = queueIndex.length - 1;

        if (indexToRemove != lastIndex) {
            uint32 playerToMove = queueIndex[lastIndex];
            queueIndex[indexToRemove] = playerToMove;
            playerIndexInQueue[playerToMove] = indexToRemove + 1;
        }

        delete playerIndexInQueue[playerId];
        queueIndex.pop();
    }

    /// @notice Gets combat stats for a registered player.
    function _getFighterCombatStats(uint32 playerId, Fighter.PlayerLoadout memory loadout)
        internal
        view
        returns (IGameEngine.FighterStats memory stats, bytes32 encodedData)
    {
        if (_getFighterType(playerId) != Fighter.FighterType.PLAYER) {
            revert UnsupportedPlayerId();
        }

        IPlayer.PlayerStats memory pStats = playerContract.getPlayer(playerId);
        pStats.skin = loadout.skin;
        pStats.stance = loadout.stance;

        IPlayerSkinRegistry.SkinCollectionInfo memory skinInfo =
            playerContract.skinRegistry().getSkin(pStats.skin.skinIndex);
        IPlayerSkinNFT.SkinAttributes memory skinAttrs =
            IPlayerSkinNFT(skinInfo.contractAddress).getSkinAttributes(pStats.skin.skinTokenId);

        stats = IGameEngine.FighterStats({
            weapon: skinAttrs.weapon,
            armor: skinAttrs.armor,
            stance: pStats.stance,
            attributes: pStats.attributes,
            level: pStats.level,
            weaponSpecialization: pStats.weaponSpecialization,
            armorSpecialization: pStats.armorSpecialization
        });

        Fighter.Record memory seasonalRecord = playerContract.getCurrentSeasonRecord(playerId);
        encodedData = playerContract.codec().encodePlayerData(playerId, pStats, seasonalRecord);
    }

    /// @notice Shuffles participants using proper Fisher-Yates algorithm.
    function _shuffleParticipants(ActiveParticipant[] memory participants, uint256 seed)
        private
        pure
        returns (ActiveParticipant[] memory)
    {
        // True Fisher-Yates shuffle - clean and simple!
        uint256 participantCount = participants.length;
        for (uint256 i = participantCount - 1; i > 0; i--) {
            seed = uint256(keccak256(abi.encodePacked(seed, i)));
            uint256 j = seed.uniform(i + 1);

            // Single swap operation
            ActiveParticipant memory temp = participants[i];
            participants[i] = participants[j];
            participants[j] = temp;
        }

        return participants;
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

        uint256 randomIndex = randomSeed.uniform(defaultCount);
        return defaultPlayerContract.getValidDefaultPlayerId(randomIndex);
    }

    /// @notice Helper to select unique default player IDs without duplicates
    /// @param randomSeed Random seed for selection
    /// @param count Number of unique defaults needed
    /// @param excludeIds Array of default IDs to exclude from selection
    /// @return Array of unique default player IDs
    function _selectUniqueDefaults(uint256 randomSeed, uint256 count, uint32[] memory excludeIds)
        internal
        view
        returns (uint32[] memory)
    {
        uint256 totalDefaults = defaultPlayerContract.validDefaultPlayerCount();
        uint256 availableDefaults = totalDefaults - excludeIds.length;
        if (count > availableDefaults) revert InsufficientDefaultPlayers(count, availableDefaults);

        // Simple approach: select without replacement using exclusion
        uint32[] memory selected = new uint32[](count);
        uint256 selectedCount = 0;
        uint256 attempts = 0;
        uint256 maxAttempts = totalDefaults * 10; // Generous safety limit

        while (selectedCount < count && attempts < maxAttempts) {
            // Generate next candidate
            randomSeed = uint256(keccak256(abi.encodePacked(randomSeed, attempts)));
            uint256 randomIndex = randomSeed.uniform(totalDefaults);
            uint32 candidate = defaultPlayerContract.getValidDefaultPlayerId(randomIndex);

            // Check if candidate is already excluded (skip loop if no exclusions)
            bool isExcluded = false;
            uint256 excludeCount = excludeIds.length;
            if (excludeCount > 0) {
                for (uint256 i = 0; i < excludeCount; i++) {
                    if (candidate == excludeIds[i]) {
                        isExcluded = true;
                        break;
                    }
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

    //==============================================================//
    //                 BASEGAME ABSTRACT IMPLEMENTATIONS            //
    //==============================================================//

    /// @notice Checks if a player ID is supported by this game mode.
    function _isPlayerIdSupported(uint32 playerId) internal pure override returns (bool) {
        Fighter.FighterType fighterType = _getFighterType(playerId);
        return fighterType == Fighter.FighterType.PLAYER || fighterType == Fighter.FighterType.DEFAULT_PLAYER;
    }

    /// @notice Gets the contract address responsible for handling the given fighter type.
    function _getFighterContract(uint32 playerId) internal view override returns (Fighter) {
        Fighter.FighterType fighterType = _getFighterType(playerId);
        if (fighterType == Fighter.FighterType.PLAYER || fighterType == Fighter.FighterType.DEFAULT_PLAYER) {
            return Fighter(address(playerContract));
        } else {
            revert UnsupportedPlayerId();
        }
    }
}

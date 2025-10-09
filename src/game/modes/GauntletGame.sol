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
import {BaseGame, ZeroAddress} from "./BaseGame.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {UniformRandomNumber} from "../../lib/UniformRandomNumber.sol";
import {IGameEngine} from "../../interfaces/game/engine/IGameEngine.sol";
import {IPlayer} from "../../interfaces/fighters/IPlayer.sol";
import {IPlayerSkinRegistry} from "../../interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";
import {IPlayerSkinNFT} from "../../interfaces/nft/skins/IPlayerSkinNFT.sol";
import {Fighter} from "../../fighters/Fighter.sol";
import {IDefaultPlayer} from "../../interfaces/fighters/IDefaultPlayer.sol";
import {IEquipmentRequirements} from "../../interfaces/game/engine/IEquipmentRequirements.sol";
import {IPlayerTickets} from "../../interfaces/nft/IPlayerTickets.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

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
error GameDisabled();
error GameEnabled();
error InvalidGauntletSize(uint8 size);
error UnsupportedPlayerId();
error InsufficientQueueSize(uint256 current, uint8 required);
error MinTimeNotElapsed();
error NoPendingGauntlet();
error NotReady(uint256 targetBlock, uint256 currentBlock);
error InvalidFutureBlocks(uint256 blocks);
error CannotRecoverYet();
error NoDefaultPlayersAvailable();
error InvalidBlockhash();
error DailyLimitExceeded(uint8 currentRuns, uint8 limit);
error InsufficientResetFee();
error InvalidRewardConfig();

//==============================================================//
//                         HEAVY HELMS                          //
//                         GAUNTLET GAME                        //
//==============================================================//
/// @title Gauntlet Game Mode for Heavy Helms
/// @notice Manages a queue of players and triggers elimination brackets (Gauntlets)
///         of dynamic size (4, 8, 16, 32, or 64) with a dynamic entry fee.
/// @dev Uses a commit-reveal pattern with future blockhash for randomness.
///      Eliminates VRF costs and delays while providing secure participant selection.
contract GauntletGame is BaseGame, ConfirmedOwner, ReentrancyGuard {
    using UniformRandomNumber for uint256;

    //==============================================================//
    //                          ENUMS                               //
    //==============================================================//
    /// @notice Represents level brackets for different gauntlet tiers.
    enum LevelBracket {
        LEVELS_1_TO_4, // Players level 1-4
        LEVELS_5_TO_9, // Players level 5-9
        LEVEL_10 // Players level 10 only
    }

    /// @notice Custom error for bracket validation.
    error PlayerNotInBracket(uint8 playerLevel, LevelBracket requiredBracket);

    /// @notice Represents the state of a Gauntlet run.
    enum GauntletState {
        PENDING, // Gauntlet started, awaiting completion.
        COMPLETED // Gauntlet finished.
    }

    /// @notice Represents the phase of the 3-transaction gauntlet system.
    enum GauntletPhase {
        NONE, // No pending gauntlet
        QUEUE_COMMIT, // Phase 1: Waiting for participant selection block
        PARTICIPANT_SELECT // Phase 2: Waiting for tournament execution block
    }

    /// @notice Represents the current status of a player in relation to the Gauntlet mode.
    enum PlayerStatus {
        NONE, // Not participating.
        QUEUED, // Waiting in the queue, can withdraw.
        IN_TOURNAMENT // Actively participating in a Gauntlet run.
    }

    /// @notice Reasons why a player might be replaced in a gauntlet.
    enum ReplacementReason {
        PLAYER_RETIRED,
        SKIN_OWNERSHIP_LOST
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
    /// @param championId The ID of the final Gauntlet winner.
    /// @dev Winners array removed for gas efficiency - only needed for events, kept in memory only.
    struct Gauntlet {
        uint256 id;
        uint8 size;
        GauntletState state;
        uint256 startTimestamp;
        uint256 completionTimestamp;
        RegisteredPlayer[] participants; // Needed for commit-reveal pattern
        uint32 championId;
        uint32 runnerUpId;
    }

    /// @notice Compact struct storing participant data within a Gauntlet.
    /// @param playerId The ID of the registered player.
    /// @param loadout The loadout the player used for this Gauntlet.
    struct RegisteredPlayer {
        uint32 playerId;
        Fighter.PlayerLoadout loadout;
    }

    /// @notice Active participant with all combat data ready for gauntlet execution.
    struct ActiveParticipant {
        uint32 playerId;
        IGameEngine.FighterStats stats;
        bytes32 encodedData;
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
    /// @notice Level bracket this gauntlet instance serves.
    LevelBracket public immutable levelBracket;
    /// @notice Contract managing default player data.
    IDefaultPlayer public defaultPlayerContract;
    /// @notice PlayerTickets contract for minting Level 10 rewards.
    IPlayerTickets public immutable playerTickets;
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
    uint8 public currentGauntletSize = 8;

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

    // --- Daily Limit System ---
    /// @notice Maximum gauntlet entries per player per day
    uint8 public dailyGauntletLimit = 10;
    /// @notice Cost in ETH to reset daily limit for a player
    uint256 public dailyResetCost = 0.001 ether;
    /// @notice Maps player ID to day number to run count (playerId => dayNumber => runCount)
    mapping(uint32 => mapping(uint256 => uint8)) private _playerDailyRuns;

    // --- Level 10 Reward Configuration ---
    /// @notice Reward percentages for champions (1st place) in Level 10 gauntlets.
    IPlayerTickets.RewardConfig public championRewards = IPlayerTickets.RewardConfig({
        nonePercent: 1900,
        attributeSwapPercent: 100,
        createPlayerPercent: 500,
        playerSlotPercent: 500,
        weaponSpecPercent: 2500,
        armorSpecPercent: 2500,
        duelTicketPercent: 1200,
        dailyResetPercent: 300,
        nameChangePercent: 500
    });

    /// @notice Reward percentages for runner-ups (2nd place) in Level 10 gauntlets.
    IPlayerTickets.RewardConfig public runnerUpRewards = IPlayerTickets.RewardConfig({
        nonePercent: 4950,
        attributeSwapPercent: 50,
        createPlayerPercent: 200,
        playerSlotPercent: 200,
        weaponSpecPercent: 1500,
        armorSpecPercent: 1500,
        duelTicketPercent: 1200,
        dailyResetPercent: 200,
        nameChangePercent: 200
    });

    /// @notice Reward percentages for 3rd-4th place in Level 10 gauntlets.
    IPlayerTickets.RewardConfig public thirdFourthRewards = IPlayerTickets.RewardConfig({
        nonePercent: 7500,
        attributeSwapPercent: 0,
        createPlayerPercent: 0,
        playerSlotPercent: 0,
        weaponSpecPercent: 500,
        armorSpecPercent: 500,
        duelTicketPercent: 1500,
        dailyResetPercent: 0,
        nameChangePercent: 0
    });

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
    event GauntletStarted(
        uint256 indexed gauntletId, uint8 size, LevelBracket levelBracket, RegisteredPlayer[] participants
    );
    /// @notice Emitted when a Gauntlet is successfully completed.
    event GauntletCompleted(
        uint256 indexed gauntletId,
        uint8 size,
        LevelBracket levelBracket,
        uint32 indexed championId,
        uint256 seasonId,
        uint32[] participantIds,
        uint32[] roundWinners
    );
    /// @notice Emitted when XP is awarded to gauntlet participants.
    event GauntletXPAwarded(
        uint256 indexed gauntletId, LevelBracket levelBracket, uint32[] playerIds, uint16[] xpAmounts
    );
    /// @notice Emitted when rewards are distributed to Level 10 gauntlet participants.
    event GauntletRewardDistributed(
        uint256 indexed gauntletId, uint32 indexed playerId, IPlayerTickets.RewardType rewardType, uint256 ticketId
    );
    /// @notice Emitted when a gauntlet is recovered due to blockhash expiration.
    /// @param gauntletId The ID of the gauntlet being recovered (0 if in QUEUE_COMMIT phase).
    /// @param phase The phase when recovery occurred.
    /// @param targetBlock The block that expired (selectionBlock or tournamentBlock).
    /// @param participantIds Array of participant IDs if gauntlet was started, empty otherwise.
    event GauntletRecovered(uint256 indexed gauntletId, GauntletPhase phase, uint256 targetBlock, uint32[] participantIds);
    /// @notice Emitted when a player is replaced during gauntlet execution.
    event PlayerReplaced(
        uint256 indexed gauntletId,
        uint32 indexed originalPlayerId,
        uint32 indexed replacementPlayerId,
        ReplacementReason reason
    );
    /// @notice Emitted when the default player contract address is updated.
    event DefaultPlayerContractSet(address indexed newContract);
    /// @notice Emitted when the Gauntlet size (participant count) is changed.
    event GauntletSizeSet(uint8 oldSize, uint8 newSize);
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
    /// @notice Emitted when a player's daily gauntlet limit is reset via ETH or ticket payment
    event DailyLimitReset(uint32 indexed playerId, uint256 dayNumber, bool paidWithTicket);
    /// @notice Emitted when the daily reset cost is updated
    event DailyResetCostUpdated(uint256 oldCost, uint256 newCost);
    /// @notice Emitted when the daily gauntlet limit is updated
    event DailyGauntletLimitUpdated(uint8 oldLimit, uint8 newLimit);
    /// @notice Emitted when reward configurations are updated for Level 10 gauntlets.
    /// @param placement 0=champion, 1=runnerUp, 2=thirdFourth
    event RewardConfigUpdated(uint8 placement, IPlayerTickets.RewardConfig config);
    // Inherited from BaseGame: event CombatResult(bytes32 indexed player1Data, bytes32 indexed player2Data, uint32 winnerId, bytes combatLog);

    //==============================================================//
    //                        MODIFIERS                             //
    //==============================================================//
    /// @notice Ensures the game is not disabled before proceeding. Reverts with `GameDisabled` otherwise.
    modifier whenGameEnabled() {
        if (!isGameEnabled) revert GameDisabled();
        _;
    }

    /// @notice Ensures the caller is the owner of the specified player.
    modifier onlyPlayerOwner(uint32 playerId) {
        address owner = playerContract.getPlayerOwner(playerId);
        if (msg.sender != owner) revert CallerNotPlayerOwner();
        _;
    }

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    /// @notice Initializes the GauntletGame contract.
    /// @param _gameEngine Address of the `GameEngine` contract.
    /// @param _playerContract Address of the `Player` contract.
    /// @param _defaultPlayerAddress Address of the `DefaultPlayer` contract.
    /// @param _levelBracket Level bracket this gauntlet instance will serve.
    /// @param _playerTicketsAddress Address of the `PlayerTickets` contract for rewards.
    constructor(
        address _gameEngine,
        address payable _playerContract,
        address _defaultPlayerAddress,
        LevelBracket _levelBracket,
        address _playerTicketsAddress
    ) BaseGame(_gameEngine, _playerContract) ConfirmedOwner(msg.sender) {
        // Input validation
        if (_defaultPlayerAddress == address(0)) revert ZeroAddress();
        if (_playerTicketsAddress == address(0)) revert ZeroAddress();
        // Validation will happen when trying to use defaults

        // Set initial state
        levelBracket = _levelBracket;
        defaultPlayerContract = IDefaultPlayer(_defaultPlayerAddress);
        playerTickets = IPlayerTickets(_playerTicketsAddress);
        lastGauntletStartTime = block.timestamp; // Initialize to deployment time

        // Emit initial settings
        emit DefaultPlayerContractSet(_defaultPlayerAddress);
        emit GauntletSizeSet(0, currentGauntletSize);
        // MaxDefaultPlayerSubstituteId no longer used
        emit MinTimeBetweenGauntletsSet(minTimeBetweenGauntlets);
        emit FutureBlocksForSelectionSet(futureBlocksForSelection);
        emit FutureBlocksForTournamentSet(futureBlocksForTournament);
        emit DailyGauntletLimitUpdated(0, dailyGauntletLimit);
        emit DailyResetCostUpdated(0, dailyResetCost);

        // Emit initial reward configurations for Level 10 gauntlets
        if (_levelBracket == LevelBracket.LEVEL_10) {
            emit RewardConfigUpdated(0, championRewards);
            emit RewardConfigUpdated(1, runnerUpRewards);
            emit RewardConfigUpdated(2, thirdFourthRewards);
        }
    }

    //==============================================================//
    //                       QUEUE MANAGEMENT                       //
    //==============================================================//

    /// @notice Allows a player owner to join the Gauntlet queue with a specific loadout.
    /// @param loadout The player's chosen skin and stance for the potential Gauntlet.
    /// @dev Validates player status, ownership, retirement status, skin requirements, and daily limits.
    function queueForGauntlet(Fighter.PlayerLoadout calldata loadout)
        external
        whenGameEnabled
        onlyPlayerOwner(loadout.playerId)
    {
        // Checks
        if (playerStatus[loadout.playerId] != PlayerStatus.NONE) revert AlreadyInQueue();
        if (playerContract.isPlayerRetired(loadout.playerId)) revert PlayerIsRetired();

        // Check daily limit
        uint256 today = _getDayNumber();
        uint8 currentRuns = _playerDailyRuns[loadout.playerId][today];
        if (currentRuns >= dailyGauntletLimit) {
            revert DailyLimitExceeded(currentRuns, dailyGauntletLimit);
        }

        // Validate player is in correct level bracket
        _validatePlayerLevel(loadout.playerId);

        // Cache external contract references to save gas
        IPlayerSkinRegistry skinRegistry = playerContract.skinRegistry();
        IEquipmentRequirements equipmentReqs = playerContract.equipmentRequirements();

        // Validate skin and equipment requirements via Player contract registries
        try skinRegistry.validateSkinOwnership(loadout.skin, msg.sender) {}
        catch {
            revert InvalidSkin();
        }
        try skinRegistry.validateSkinRequirements(
            loadout.skin, playerContract.getPlayer(loadout.playerId).attributes, equipmentReqs
        ) {}
        catch {
            revert InvalidLoadout();
        }

        // Effects
        uint32 playerId = loadout.playerId;
        _addPlayerToQueue(playerId, loadout);

        // Increment daily run counter (user pays gas for state change)
        _playerDailyRuns[playerId][today]++;

        // Interactions (Event Emission)
        emit PlayerQueued(playerId, queueIndex.length);
    }

    /// @notice Allows a player owner to withdraw their player from the queue before a Gauntlet starts.
    /// @param playerId The ID of the player to withdraw.
    /// @dev Uses swap-and-pop to maintain queue integrity. Cannot withdraw after selection.
    function withdrawFromQueue(uint32 playerId) external onlyPlayerOwner(playerId) {
        // Checks
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


    /// @notice Gets the current daily run count for a player
    /// @param playerId The ID of the player to check
    /// @return The number of gauntlet runs today for this player
    function getDailyRunCount(uint32 playerId) external view returns (uint8) {
        uint256 today = _getDayNumber();
        return _playerDailyRuns[playerId][today];
    }

    /// @notice Resets the daily gauntlet limit for a player by paying ETH
    /// @param playerId The ID of the player to reset limit for
    /// @dev Player owner pays ETH to reset their daily gauntlet entry count to 0
    function resetDailyLimit(uint32 playerId) external payable onlyPlayerOwner(playerId) {
        // Checks
        if (msg.value < dailyResetCost) revert InsufficientResetFee();

        // Effects
        uint256 today = _getDayNumber();
        _playerDailyRuns[playerId][today] = 0;

        // Interactions
        emit DailyLimitReset(playerId, today, false);
    }

    /// @notice Resets the daily gauntlet limit for a player by burning a DAILY_RESET_TICKET
    /// @param playerId The ID of the player to reset limit for
    /// @dev Player owner burns a DAILY_RESET_TICKET to reset their daily gauntlet entry count to 0
    function resetDailyLimitWithTicket(uint32 playerId) external onlyPlayerOwner(playerId) {
        // Checks & Effects - burn ticket first (will revert if insufficient balance)
        playerTickets.burnFrom(msg.sender, playerTickets.DAILY_RESET_TICKET(), 1);

        // Effects
        uint256 today = _getDayNumber();
        _playerDailyRuns[playerId][today] = 0;

        // Interactions
        emit DailyLimitReset(playerId, today, true);
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
        // Cache pending gauntlet state to avoid multiple storage reads
        GauntletPhase currentPhase = pendingGauntlet.phase;
        if (currentPhase != GauntletPhase.NONE) {
            uint256 selectionBlock = pendingGauntlet.selectionBlock;
            uint256 tournamentBlock = pendingGauntlet.tournamentBlock;
            uint256 currentBlock = block.number; // Cache block.number to save gas

            // Check if we're past the 256-block limit for the current phase's target block
            bool shouldRecover = false;
            uint256 targetBlock;
            
            if (currentPhase == GauntletPhase.QUEUE_COMMIT) {
                targetBlock = selectionBlock;
                shouldRecover = currentBlock >= selectionBlock + 256;
            } else {
                targetBlock = tournamentBlock;
                shouldRecover = currentBlock >= tournamentBlock + 256;
            }

            if (shouldRecover) {
                // Auto-recovery if we missed the window - just call the public recovery function
                recoverPendingGauntlet();
                return;
            }

            if (currentPhase == GauntletPhase.QUEUE_COMMIT) {
                // Phase 2: Participant Selection
                if (currentBlock >= selectionBlock) {
                    _selectParticipantsPhase();
                    return;
                } else {
                    revert NotReady(selectionBlock, currentBlock);
                }
            } else if (currentPhase == GauntletPhase.PARTICIPANT_SELECT) {
                // Phase 3: Tournament Execution
                if (currentBlock >= tournamentBlock) {
                    _executeTournamentPhase();
                    return;
                } else {
                    revert NotReady(tournamentBlock, currentBlock);
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
    //                     XP REWARD FUNCTIONS                     //
    //==============================================================//

    /// @notice Awards XP to gauntlet participants based on placement and level bracket.
    /// @param gauntlet The completed gauntlet storage reference
    /// @param eliminatedByRound Array of player IDs eliminated in each round
    /// @param bracket The level bracket of the gauntlet (LEVELS_1_TO_4 or LEVELS_5_TO_9)
    function _awardGauntletXP(Gauntlet storage gauntlet, uint32[] memory eliminatedByRound, LevelBracket bracket)
        private
    {
        uint8 size = gauntlet.size;

        // Base XP amounts for each level bracket
        uint16 championBaseXP = (bracket == LevelBracket.LEVELS_1_TO_4) ? 100 : 150;

        // Track XP awards for event emission
        uint32[] memory awardedPlayerIds = new uint32[](size);
        uint16[] memory awardedXP = new uint16[](size);
        uint256 awardCount = 0;

        // Award champion (1st place - 100% of base XP)
        if (_getFighterType(gauntlet.championId) == Fighter.FighterType.PLAYER) {
            playerContract.awardExperience(gauntlet.championId, championBaseXP);
            awardedPlayerIds[awardCount] = gauntlet.championId;
            awardedXP[awardCount++] = championBaseXP;
        }

        // Award runner-up (2nd place - 60% of base XP)
        if (_getFighterType(gauntlet.runnerUpId) == Fighter.FighterType.PLAYER) {
            uint16 runnerUpXP = (championBaseXP * 60) / 100;
            playerContract.awardExperience(gauntlet.runnerUpId, runnerUpXP);
            awardedPlayerIds[awardCount] = gauntlet.runnerUpId;
            awardedXP[awardCount++] = runnerUpXP;
        }

        // Process eliminated players but exclude final round
        uint256 eliminatedPerRound = size / 2;
        uint256 currentRound = 0;

        // Don't process the final elimination (runner-up) - exclude last element
        uint256 eliminationsToProcess = eliminatedByRound.length - 1;

        for (uint256 i = 0; i < eliminationsToProcess; i++) {
            uint32 playerId = eliminatedByRound[i];

            // Move to next round when we've processed all eliminations for current round
            if (i > 0 && i % eliminatedPerRound == 0) {
                currentRound++;
                eliminatedPerRound /= 2;
            }

            // Award XP if it's a player and they get XP for this round
            if (_getFighterType(playerId) == Fighter.FighterType.PLAYER) {
                uint16 xpAmount = _getRoundXP(size, currentRound, championBaseXP);
                if (xpAmount > 0) {
                    playerContract.awardExperience(playerId, xpAmount);
                    awardedPlayerIds[awardCount] = playerId;
                    awardedXP[awardCount++] = xpAmount;
                }
            }
        }

        // Emit XP awards event with actual count
        if (awardCount > 0) {
            uint32[] memory finalPlayerIds = new uint32[](awardCount);
            uint16[] memory finalXP = new uint16[](awardCount);
            for (uint256 i = 0; i < awardCount; i++) {
                finalPlayerIds[i] = awardedPlayerIds[i];
                finalXP[i] = awardedXP[i];
            }
            emit GauntletXPAwarded(gauntlet.id, bracket, finalPlayerIds, finalXP);
        }
    }

    /// @notice Gets XP for a specific round based on gauntlet size.
    /// @param size The size of the gauntlet (4, 8, 16, 32, or 64)
    /// @param round The round index
    /// @param baseXP The base XP amount for the champion
    /// @return The XP amount for that round (0 if no XP awarded)
    function _getRoundXP(uint8 size, uint256 round, uint16 baseXP) private pure returns (uint16) {
        // Size 4: No XP for any rounds (top 50% rule)
        if (size == 4) return 0;
        
        // Size 8: Only round 1 (3rd-4th place) gets 30%
        if (size == 8) {
            return round == 1 ? (baseXP * 30) / 100 : 0;
        }
        
        // Size 16: Round 1 (5th-8th) gets 20%, round 2 (3rd-4th) gets 30%
        if (size == 16) {
            if (round == 1) return (baseXP * 20) / 100;
            if (round == 2) return (baseXP * 30) / 100;
            return 0;
        }
        
        // Size 32: Round 1 (9th-16th) gets 5%, round 2 (5th-8th) gets 20%, round 3 (3rd-4th) gets 30%
        if (size == 32) {
            if (round == 1) return (baseXP * 5) / 100;
            if (round == 2) return (baseXP * 20) / 100;
            if (round == 3) return (baseXP * 30) / 100;
            return 0;
        }
        
        // Size 64: Similar pattern with one more round
        if (size == 64) {
            if (round == 1) return (baseXP * 5) / 100;
            if (round == 2) return (baseXP * 10) / 100;
            if (round == 3) return (baseXP * 20) / 100;
            if (round == 4) return (baseXP * 30) / 100;
            return 0;
        }
        
        return 0;
    }

    //==============================================================//
    //                   LEVEL 10 REWARD FUNCTIONS                  //
    //==============================================================//

    /// @notice Distributes rewards to Level 10 gauntlet participants.
    function _distributeGauntletRewards(
        Gauntlet storage gauntlet,
        uint32[] memory eliminatedByRound,
        uint256 gauntletId,
        uint256 randomness
    ) private {
        // Reward champion
        if (_getFighterType(gauntlet.championId) == Fighter.FighterType.PLAYER) {
            _distributeReward(gauntletId, gauntlet.championId, championRewards, randomness);
        }

        // Reward runner-up
        if (_getFighterType(gauntlet.runnerUpId) == Fighter.FighterType.PLAYER) {
            _distributeReward(gauntletId, gauntlet.runnerUpId, runnerUpRewards, randomness);
        }

        // Reward 3rd-4th place (semi-final losers)
        uint256 eliminatedLength = eliminatedByRound.length;
        uint256 semiFinalistStart = eliminatedLength - 3; // Last 3 eliminated: 2nd, 3rd, 4th
        uint256 semiFinalistEnd = eliminatedLength - 1;
        for (uint256 i = semiFinalistStart; i < semiFinalistEnd; i++) {
            uint32 playerId = eliminatedByRound[i];
            if (_getFighterType(playerId) == Fighter.FighterType.PLAYER) {
                _distributeReward(gauntletId, playerId, thirdFourthRewards, randomness);
            }
        }
    }

    /// @notice Distributes a single reward based on configured percentages.
    function _distributeReward(
        uint256 gauntletId,
        uint32 playerId,
        IPlayerTickets.RewardConfig memory config,
        uint256 randomness
    ) private {
        uint256 random = uint256(keccak256(abi.encodePacked(randomness, gauntletId, playerId)));
        uint256 roll = random.uniform(10000); // 0-9999 for percentage precision

        // Calculate cumulative thresholds (including none)
        uint256 t0 = config.nonePercent;
        uint256 t1 = t0 + config.attributeSwapPercent;
        uint256 t2 = t1 + config.createPlayerPercent;
        uint256 t3 = t2 + config.playerSlotPercent;
        uint256 t4 = t3 + config.weaponSpecPercent;
        uint256 t5 = t4 + config.armorSpecPercent;
        uint256 t6 = t5 + config.duelTicketPercent;
        uint256 t7 = t6 + config.dailyResetPercent;

        IPlayerTickets.RewardType rewardType;
        uint256 ticketId;

        if (roll < t0) {
            return; // No reward
        }

        // Get owner once for all reward types
        address owner = playerContract.getPlayerOwner(playerId);

        if (roll < t1) {
            rewardType = IPlayerTickets.RewardType.ATTRIBUTE_SWAP;
            ticketId = playerTickets.ATTRIBUTE_SWAP_TICKET();
        } else if (roll < t2) {
            rewardType = IPlayerTickets.RewardType.CREATE_PLAYER_TICKET;
            ticketId = playerTickets.CREATE_PLAYER_TICKET();
        } else if (roll < t3) {
            rewardType = IPlayerTickets.RewardType.PLAYER_SLOT_TICKET;
            ticketId = playerTickets.PLAYER_SLOT_TICKET();
        } else if (roll < t4) {
            rewardType = IPlayerTickets.RewardType.WEAPON_SPECIALIZATION_TICKET;
            ticketId = playerTickets.WEAPON_SPECIALIZATION_TICKET();
        } else if (roll < t5) {
            rewardType = IPlayerTickets.RewardType.ARMOR_SPECIALIZATION_TICKET;
            ticketId = playerTickets.ARMOR_SPECIALIZATION_TICKET();
        } else if (roll < t6) {
            rewardType = IPlayerTickets.RewardType.DUEL_TICKET;
            ticketId = playerTickets.DUEL_TICKET();
        } else if (roll < t7) {
            rewardType = IPlayerTickets.RewardType.DAILY_RESET_TICKET;
            ticketId = playerTickets.DAILY_RESET_TICKET();
        } else {
            // Must be name change ticket (nameChangePercent is the remainder)
            rewardType = IPlayerTickets.RewardType.NAME_CHANGE_TICKET;
            // Name change tickets are non-fungible, minted with randomness
            try playerTickets.mintNameChangeNFTSafe(owner, random) returns (uint256 newTokenId) {
                emit GauntletRewardDistributed(gauntletId, playerId, rewardType, newTokenId);
            } catch {
                emit GauntletRewardDistributed(gauntletId, playerId, rewardType, 0);
            }
            return;
        }

        // Mint fungible ticket for other reward types with gas limit
        try playerTickets.mintFungibleTicketSafe(owner, ticketId, 1) {
            emit GauntletRewardDistributed(gauntletId, playerId, rewardType, ticketId);
        } catch {
            emit GauntletRewardDistributed(gauntletId, playerId, rewardType, 0);
        }
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

    /// @notice Phase 2: Selects participants using enhanced randomness.
    function _selectParticipantsPhase() private {
        // Get enhanced randomness from selection block
        uint256 seed = _getEnhancedRandomness(pendingGauntlet.selectionBlock);

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

        // Store participants in gauntlet AND remove from queue in single loop
        uint256 selectedCount = selectedIds.length; // Cache length to save gas
        for (uint256 i = 0; i < selectedCount; i++) {
            uint32 playerId = selectedIds[i];
            Fighter.PlayerLoadout memory loadout = registrationQueue[playerId];

            // Store in gauntlet
            gauntlet.participants.push(RegisteredPlayer({playerId: playerId, loadout: loadout}));

            // Update player status to final state
            playerStatus[playerId] = PlayerStatus.IN_TOURNAMENT;
            playerCurrentGauntlet[playerId] = gauntletId;

            // Remove from queue immediately
            _removePlayerFromQueueArrayIndex(playerId);
            delete registrationQueue[playerId];
        }

        // Emit start event NOW in TX2
        emit GauntletStarted(gauntletId, gauntlet.size, levelBracket, gauntlet.participants);

        // Set up tournament phase with fresh 256-block window
        pendingGauntlet.phase = GauntletPhase.PARTICIPANT_SELECT;
        pendingGauntlet.tournamentBlock = block.number + futureBlocksForTournament;
        pendingGauntlet.commitTimestamp = block.timestamp;

        emit ParticipantsSelected(pendingGauntlet.gauntletId, pendingGauntlet.tournamentBlock, selectedIds);
    }

    /// @notice Phase 3: Executes the tournament using blockhash randomness.
    function _executeTournamentPhase() private {
        // Get enhanced randomness from tournament block
        uint256 seed = _getEnhancedRandomness(pendingGauntlet.tournamentBlock);

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
            uint256 index = seed.uniform(remaining);

            selected[i] = pool[index];

            // Swap and pop
            pool[index] = pool[remaining - 1];
            remaining--;
        }
    }

    /// @notice Recovers a pending gauntlet after the 256-block window expires.
    /// @dev Can be called directly or through auto-recovery in tryStartGauntlet.
    function recoverPendingGauntlet() public {
        // Check if recovery is possible (256 blocks have passed)
        if (pendingGauntlet.phase == GauntletPhase.NONE) revert NoPendingGauntlet();
        
        GauntletPhase currentPhase = pendingGauntlet.phase;
        uint256 targetBlock;
        bool canRecover;
        
        if (currentPhase == GauntletPhase.QUEUE_COMMIT) {
            targetBlock = pendingGauntlet.selectionBlock;
            canRecover = block.number > targetBlock + 256;
        } else {
            targetBlock = pendingGauntlet.tournamentBlock;
            canRecover = block.number > targetBlock + 256;
        }
        if (!canRecover) revert CannotRecoverYet();
        
        // Cache data for event before deletion
        uint256 gauntletId = pendingGauntlet.gauntletId;
        uint32[] memory participantIds;
        
        if (currentPhase == GauntletPhase.QUEUE_COMMIT) {
            // No participants yet, just clear pending gauntlet
            delete pendingGauntlet;
        } else {
            // If we're past participant selection, need to clean up player states
            Gauntlet storage gauntlet = gauntlets[gauntletId];

            // Only process if gauntlet exists and is pending
            if (gauntlet.state == GauntletState.PENDING) {
                uint256 participantCount = gauntlet.participants.length;
                
                // Get participant IDs for event
                participantIds = new uint32[](participantCount);
                for (uint256 i = 0; i < participantCount; i++) {
                    participantIds[i] = gauntlet.participants[i].playerId;
                }

                // Clear pending gauntlet after getting participant data
                delete pendingGauntlet;

                // Return all participants back to queue
                for (uint256 i = 0; i < participantCount; i++) {
                    uint32 playerId = gauntlet.participants[i].playerId;

                    // Only reset if they're still in this tournament
                    if (
                        playerStatus[playerId] == PlayerStatus.IN_TOURNAMENT
                            && playerCurrentGauntlet[playerId] == gauntletId
                    ) {
                        // Clear tournament status first
                        playerStatus[playerId] = PlayerStatus.NONE;
                        delete playerCurrentGauntlet[playerId];

                        // Re-add to queue using shared helper
                        _addPlayerToQueue(playerId, gauntlet.participants[i].loadout);
                    }
                }

                // Mark gauntlet as completed to prevent future issues
                gauntlet.state = GauntletState.COMPLETED;
                gauntlet.completionTimestamp = block.timestamp;
            }
        }
        
        emit GauntletRecovered(gauntletId, currentPhase, targetBlock, participantIds);
    }

    /// @notice Executes a gauntlet tournament using blockhash randomness.
    /// @param gauntletId The ID of the gauntlet to execute.
    /// @param randomness The random value from blockhash.
    function _executeGauntletWithRandomness(uint256 gauntletId, uint256 randomness) private {
        // Force season update before gauntlet execution to ensure correct season for all records
        uint256 season = playerContract.forceCurrentSeason();

        Gauntlet storage gauntlet = gauntlets[gauntletId];
        // If state is not PENDING (shouldn't happen in blockhash version), return early
        if (gauntlet.state != GauntletState.PENDING) {
            return;
        }

        // Load gauntlet parameters into memory for efficiency
        uint8 size = gauntlet.size;
        RegisteredPlayer[] storage initialParticipants = gauntlet.participants;

        // Create active participants array with proper struct
        ActiveParticipant[] memory activeParticipants = new ActiveParticipant[](size);

        // Cache skin registry to save gas on repeated calls
        IPlayerSkinRegistry skinRegistry = playerContract.skinRegistry();

        // Build active participants with simple replacement logic for gauntlets
        for (uint256 i = 0; i < size; i++) {
            RegisteredPlayer storage regPlayer = initialParticipants[i];
            uint32 activePlayerId = regPlayer.playerId;

            // Check if player needs replacement
            bool shouldReplace = false;
            ReplacementReason reason;

            // Check if player is retired
            if (playerContract.isPlayerRetired(regPlayer.playerId)) {
                shouldReplace = true;
                reason = ReplacementReason.PLAYER_RETIRED;
            }

            // Check if player still owns their skin
            if (!shouldReplace) {
                address playerOwner = playerContract.getPlayerOwner(regPlayer.playerId);
                try skinRegistry.validateSkinOwnership(
                    regPlayer.loadout.skin, playerOwner
                ) {
                // Skin validation passed
                }
                catch {
                    // Skin validation failed - player no longer owns the skin
                    shouldReplace = true;
                    reason = ReplacementReason.SKIN_OWNERSHIP_LOST;
                }
            }

            // Replace with simple random default if needed
            if (shouldReplace) {
                uint32 originalPlayerId = activePlayerId;

                // Get a simple random default player (no uniqueness needed for gauntlets)
                activePlayerId = _getRandomDefaultPlayerId(randomness + i);

                // Emit replacement event for subgraph tracking
                emit PlayerReplaced(gauntletId, originalPlayerId, activePlayerId, reason);
            }

            // Load combat data based on player type
            if (_isDefaultPlayerId(activePlayerId)) {
                activeParticipants[i] = _loadDefaultPlayerData(activePlayerId);
            } else {
                // Use original player's loadout since they passed validation
                activeParticipants[i] = _loadPlayerData(activePlayerId, regPlayer.loadout);
            }
        }

        // Shuffle participants using clean Fisher-Yates (tournament pattern)
        activeParticipants = _shuffleParticipants(activeParticipants, randomness);

        // Run gauntlet rounds with improved structure
        (uint32[] memory eliminatedByRound, uint32[] memory roundWinners) =
            _runGauntletRounds(gauntlet, gauntletId, activeParticipants, randomness, season);

        // Award XP for levels 1-9 brackets, tickets for level 10
        if (levelBracket != LevelBracket.LEVEL_10) {
            _awardGauntletXP(gauntlet, eliminatedByRound, levelBracket);
        } else {
            _distributeGauntletRewards(gauntlet, eliminatedByRound, gauntletId, randomness);
        }

        // Clean up player statuses
        for (uint256 i = 0; i < size; i++) {
            uint32 pId = gauntlet.participants[i].playerId;
            // Check status and current gauntlet ID before clearing
            if (playerStatus[pId] == PlayerStatus.IN_TOURNAMENT && playerCurrentGauntlet[pId] == gauntletId) {
                playerStatus[pId] = PlayerStatus.NONE;
                delete playerCurrentGauntlet[pId];
            }
        }

        // Extract participant IDs for event emission
        uint256 participantCount = activeParticipants.length;
        uint32[] memory participantIds = new uint32[](participantCount);
        for (uint256 i = 0; i < participantCount; i++) {
            participantIds[i] = activeParticipants[i].playerId;
        }

        // Emit completion event with memory arrays (for subgraph)
        emit GauntletCompleted(
            gauntletId, size, levelBracket, gauntlet.championId, season, participantIds, roundWinners
        );
    }

    /// @notice Runs all gauntlet rounds with clean memory management.
    /// @return eliminatedByRound Array of player IDs eliminated in each round
    /// @return roundWinners Array of winner IDs for each match
    function _runGauntletRounds(
        Gauntlet storage gauntlet,
        uint256 gauntletId,
        ActiveParticipant[] memory participants,
        uint256 randomness,
        uint256 season
    ) private returns (uint32[] memory eliminatedByRound, uint32[] memory roundWinners) {
        // Initialize memory arrays to track round winners and eliminations (not stored in contract)
        roundWinners = new uint32[](gauntlet.size - 1);
        eliminatedByRound = new uint32[](gauntlet.size);
        uint256 winnerIndex = 0;
        uint256 eliminatedIndex = 0;

        // Current round participants - clean struct array
        ActiveParticipant[] memory currentRound = participants;

        // Calculate number of rounds: log2(size) since each round halves participants
        uint256 totalRounds = gauntlet.size == 4 ? 2 : gauntlet.size == 8 ? 3 : gauntlet.size == 16 ? 4 : gauntlet.size == 32 ? 5 : 6;
        
        for (uint256 roundIndex = 0; roundIndex < totalRounds; roundIndex++) {
            uint256 currentRoundSize = currentRound.length;
            uint256 nextRoundSize = currentRoundSize / 2;

            // Next round participants
            ActiveParticipant[] memory nextRound = new ActiveParticipant[](nextRoundSize);

            // Process fights in this round
            for (uint256 fightIndex = 0; fightIndex < currentRoundSize; fightIndex += 2) {
                ActiveParticipant memory fighter1 = currentRound[fightIndex];
                ActiveParticipant memory fighter2 = currentRound[fightIndex + 1];

                // Generate fight seed (inline fightSeedBase calculation)
                uint256 fightSeed = uint256(
                    keccak256(
                        abi.encodePacked(
                            uint256(keccak256(abi.encodePacked(randomness, gauntletId))), roundIndex, fightIndex
                        )
                    )
                );

                // Process fight (no lethality for gauntlets)
                bytes memory results = gameEngine.processGame(fighter1.stats, fighter2.stats, fightSeed, 0);
                (bool p1Won,,,) = gameEngine.decodeCombatLog(results);

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
                if (winnerIndex < gauntlet.size - 1) {
                    roundWinners[winnerIndex++] = winner.playerId;
                }

                // Track elimination for XP distribution
                eliminatedByRound[eliminatedIndex++] = loserId;

                // Emit combat result
                emit CombatResult(fighter1.encodedData, fighter2.encodedData, winner.playerId, results);

                // Update records
                if (_getFighterType(winner.playerId) == Fighter.FighterType.PLAYER) {
                    playerContract.incrementWins(winner.playerId, season);
                }
                if (_getFighterType(loserId) == Fighter.FighterType.PLAYER) {
                    playerContract.incrementLosses(loserId, season);
                }
            }

            // Move to next round - clean single assignment
            currentRound = nextRound;
        }

        // Gauntlet complete - record final results
        uint32 finalWinnerId = currentRound[0].playerId;
        gauntlet.championId = finalWinnerId;
        gauntlet.runnerUpId = eliminatedByRound[eliminatedIndex - 1]; // Last eliminated is runner-up
        gauntlet.completionTimestamp = block.timestamp;
        gauntlet.state = GauntletState.COMPLETED;

        // Return elimination data for XP/reward processing and round winners for event
        return (eliminatedByRound, roundWinners);
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

    /// @notice Efficiently clears players from queue in batches to save gas.
    /// @param maxClearCount Maximum number of players to clear in this batch.
    /// @return actualCleared The actual number of players cleared.
    function _batchClearQueue(uint256 maxClearCount) internal returns (uint256 actualCleared) {
        if (queueIndex.length == 0) return 0; // Nothing to clear

        // Determine how many players to clear
        actualCleared = queueIndex.length > maxClearCount ? maxClearCount : queueIndex.length;

        // Clear mappings first in a batch (most gas efficient)
        uint256 queueLength = queueIndex.length; // Cache length to save gas
        uint256 startIndex = queueLength - actualCleared;
        for (uint256 i = startIndex; i < queueLength; i++) {
            uint32 playerId = queueIndex[i];
            // Clear all mappings in batch
            delete registrationQueue[playerId];
            delete playerIndexInQueue[playerId];
            if (playerStatus[playerId] == PlayerStatus.QUEUED) {
                playerStatus[playerId] = PlayerStatus.NONE;
            }
        }

        // Shrink array once at the end (much more gas efficient than repeated pop())
        uint256 newLength = queueIndex.length - actualCleared;
        assembly {
            sstore(queueIndex.slot, newLength)
        }

        return actualCleared;
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

        // Get player stats and apply loadout overrides
        IPlayer.PlayerStats memory pStats = playerContract.getPlayer(playerId);
        pStats.skin = loadout.skin;
        pStats.stance = loadout.stance;

        // Get skin attributes and construct FighterStats
        IPlayerSkinNFT.SkinAttributes memory skinAttrs = Fighter(address(playerContract)).getSkinAttributes(pStats.skin);
        stats = IGameEngine.FighterStats({
            weapon: skinAttrs.weapon,
            armor: skinAttrs.armor,
            stance: pStats.stance,
            attributes: pStats.attributes,
            level: pStats.level,
            weaponSpecialization: pStats.weaponSpecialization,
            armorSpecialization: pStats.armorSpecialization
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



    //==============================================================//
    //                     ADMIN FUNCTIONS                          //
    //==============================================================//

    /// @notice Toggles the ability for players to queue for Gauntlets.
    /// @dev If set to `false`, clears the current queue.
    /// @param enabled The desired state (true = enabled, false = disabled).
    function setGameEnabled(bool enabled) external onlyOwner {
        if (isGameEnabled == enabled) return; // No change needed

        isGameEnabled = enabled;

        // If disabling the game, clear queue in batches for gas safety
        if (!enabled && queueIndex.length > 0) {
            uint256 clearCount = _batchClearQueue(CLEAR_BATCH_SIZE);
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

        uint256 clearCount = _batchClearQueue(CLEAR_BATCH_SIZE);
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
        if (isGameEnabled) revert GameEnabled();

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

        uint256 randomIndex = randomSeed.uniform(defaultCount);
        return defaultPlayerContract.getValidDefaultPlayerId(randomIndex);
    }

    /// @notice Sets the minimum time required between starting gauntlets.
    /// @param newMinTime The new minimum time in seconds.
    function setMinTimeBetweenGauntlets(uint256 newMinTime) external onlyOwner {
        // Optional: Add reasonable bounds check if desired (e.g., require(newMinTime >= 60 seconds))
        minTimeBetweenGauntlets = newMinTime;
        emit MinTimeBetweenGauntletsSet(newMinTime);
    }

    /// @notice Sets the cost for resetting daily gauntlet limits
    /// @param newCost The new cost in ETH for daily limit resets
    function setDailyResetCost(uint256 newCost) external onlyOwner {
        uint256 oldCost = dailyResetCost;
        dailyResetCost = newCost;
        emit DailyResetCostUpdated(oldCost, newCost);
    }

    /// @notice Withdraws accumulated daily reset fees to the owner
    /// @dev Only callable by contract owner
    function withdrawFees() external onlyOwner {
        SafeTransferLib.safeTransferETH(owner(), address(this).balance);
    }

    /// @notice Sets the daily gauntlet entry limit per player
    /// @param newLimit The new daily entry limit
    function setDailyGauntletLimit(uint8 newLimit) external onlyOwner {
        if (newLimit == 0) revert InvalidGauntletSize(newLimit);
        uint8 oldLimit = dailyGauntletLimit;
        dailyGauntletLimit = newLimit;
        emit DailyGauntletLimitUpdated(oldLimit, newLimit);
    }

    // --- Level 10 Reward Configuration ---

    /// @notice Updates reward configuration for champions in Level 10 gauntlets.
    /// @dev Only Level 10 bracket gauntlets use rewards.
    function setChampionRewards(IPlayerTickets.RewardConfig calldata config) external onlyOwner {
        if (levelBracket != LevelBracket.LEVEL_10) revert InvalidRewardConfig();
        uint256 total =
            config.nonePercent + config.createPlayerPercent + config.playerSlotPercent + config.weaponSpecPercent
            + config.armorSpecPercent + config.duelTicketPercent + config.dailyResetPercent + config.nameChangePercent;
        if (total != 10000) revert InvalidRewardConfig();

        championRewards = config;
        emit RewardConfigUpdated(0, config);
    }

    /// @notice Updates reward configuration for runner-ups in Level 10 gauntlets.
    /// @dev Only Level 10 bracket gauntlets use rewards.
    function setRunnerUpRewards(IPlayerTickets.RewardConfig calldata config) external onlyOwner {
        if (levelBracket != LevelBracket.LEVEL_10) revert InvalidRewardConfig();
        uint256 total =
            config.nonePercent + config.createPlayerPercent + config.playerSlotPercent + config.weaponSpecPercent
            + config.armorSpecPercent + config.duelTicketPercent + config.dailyResetPercent + config.nameChangePercent;
        if (total != 10000) revert InvalidRewardConfig();

        runnerUpRewards = config;
        emit RewardConfigUpdated(1, config);
    }

    /// @notice Updates reward configuration for 3rd-4th place in Level 10 gauntlets.
    /// @dev Only Level 10 bracket gauntlets use rewards.
    function setThirdFourthRewards(IPlayerTickets.RewardConfig calldata config) external onlyOwner {
        if (levelBracket != LevelBracket.LEVEL_10) revert InvalidRewardConfig();
        uint256 total =
            config.nonePercent + config.createPlayerPercent + config.playerSlotPercent + config.weaponSpecPercent
            + config.armorSpecPercent + config.duelTicketPercent + config.dailyResetPercent + config.nameChangePercent;
        if (total != 10000) revert InvalidRewardConfig();

        thirdFourthRewards = config;
        emit RewardConfigUpdated(2, config);
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

    // --- Queue Management Helpers ---

    /// @notice Internal helper to add a player to the queue with their loadout.
    /// @param playerId The ID of the player to add.
    /// @param loadout The player's loadout configuration.
    /// @dev Used by both queueForGauntlet and recovery functions for DRY.
    function _addPlayerToQueue(uint32 playerId, Fighter.PlayerLoadout memory loadout) internal {
        registrationQueue[playerId] = loadout;
        queueIndex.push(playerId);
        playerIndexInQueue[playerId] = queueIndex.length; // 1-based index
        playerStatus[playerId] = PlayerStatus.QUEUED;
    }

    // --- Level Bracket Validation ---

    /// @notice Validates that a player's level matches this gauntlet's bracket.
    /// @param playerId The ID of the player to validate.
    /// @dev Reverts with PlayerNotInBracket if the player's level doesn't match the bracket.
    function _validatePlayerLevel(uint32 playerId) internal view {
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        uint8 playerLevel = stats.level;

        if (levelBracket == LevelBracket.LEVELS_1_TO_4) {
            if (playerLevel < 1 || playerLevel > 4) {
                revert PlayerNotInBracket(playerLevel, levelBracket);
            }
        } else if (levelBracket == LevelBracket.LEVELS_5_TO_9) {
            if (playerLevel < 5 || playerLevel > 9) {
                revert PlayerNotInBracket(playerLevel, levelBracket);
            }
        } else {
            // LevelBracket.LEVEL_10
            if (playerLevel != 10) {
                revert PlayerNotInBracket(playerLevel, levelBracket);
            }
        }
    }

    // --- Enhanced Randomness ---

    /// @notice Generates enhanced randomness combining multiple entropy sources
    /// @param futureBlock The future block number to use for base randomness
    /// @return Enhanced random seed combining blockhash with additional entropy
    function _getEnhancedRandomness(uint256 futureBlock) private view returns (uint256) {
        uint256 baseHash = uint256(blockhash(futureBlock));
        if (baseHash == 0) revert InvalidBlockhash();

        return uint256(keccak256(abi.encodePacked(baseHash, block.timestamp, block.number, gasleft(), tx.origin)));
    }

    /// @notice Calculates the current day number since Unix epoch
    /// @return Day number (resets at midnight UTC)
    function _getDayNumber() private view returns (uint256) {
        return block.timestamp / 1 days;
    }

    // --- Helper Functions ---

    /// @notice Loads combat data for a default player.
    function _loadDefaultPlayerData(uint32 playerId) private view returns (ActiveParticipant memory) {
        // Get appropriate level based on bracket
        uint8 targetLevel;
        if (levelBracket == LevelBracket.LEVELS_1_TO_4) {
            targetLevel = 4;
        } else if (levelBracket == LevelBracket.LEVELS_5_TO_9) {
            targetLevel = 9;
        } else {
            // LEVEL_10
            targetLevel = 10;
        }

        IPlayer.PlayerStats memory defaultStats = defaultPlayerContract.getDefaultPlayer(playerId, targetLevel);
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

    /// @notice Shuffles participants using proper Fisher-Yates algorithm.
    function _shuffleParticipants(ActiveParticipant[] memory participants, uint256 seed)
        private
        pure
        returns (ActiveParticipant[] memory)
    {
        // True Fisher-Yates shuffle - clean and simple!
        uint256 length = participants.length;
        for (uint256 i = length - 1; i > 0; i--) {
            seed = uint256(keccak256(abi.encodePacked(seed, i)));
            uint256 j = seed.uniform(i + 1);

            // Single swap operation
            ActiveParticipant memory temp = participants[i];
            participants[i] = participants[j];
            participants[j] = temp;
        }

        return participants;
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

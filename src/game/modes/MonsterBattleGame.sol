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
import {IMonster} from "../../interfaces/fighters/IMonster.sol";
import {IPlayerTickets} from "../../interfaces/nft/IPlayerTickets.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
error GameDisabled();
error PlayerIsRetired();
error InvalidPlayerLoadout();
error CallerNotPlayerOwner();
error MonsterNotInDifficultyTier();
error MonsterAlreadyDead();
error DailyLimitExceeded(uint8 currentRuns, uint8 limit);
error InsufficientResetFee();
error ResetNotNeeded(uint8 currentRuns, uint8 limit);
error InvalidDifficulty();
error NoMonstersAvailable();
error PlayerLevelTooLow();
error BountyHuntingRequiresLevel10();
error MonsterHasNoKills();
error UnsupportedPlayerIdForMonsterMode();
error VrfRequestTimestamp();
error VrfTimeoutNotReached();
error BattleDoesNotExist();
error BattleNotPending();
error NotAuthorized();
error ValueMustBePositive();
error InvalidVrfRequestTimestamp();

//==============================================================//
//                         INTERFACES                           //
//==============================================================//
/// @notice Interface for PlayerTickets contract functions needed by MonsterBattleGame
interface IPlayerTicketsForMonsters {
    function DAILY_RESET_TICKET() external view returns (uint256);
    function CREATE_PLAYER_TICKET() external view returns (uint256);
    function ATTRIBUTE_SWAP_TICKET() external view returns (uint256);
    function burnFrom(address from, uint256 tokenId, uint256 amount) external;
    function mintFungibleTicketSafe(address to, uint256 tokenId, uint256 amount) external;
    function awardAttributeSwap(address playerOwner) external;
}

//==============================================================//
//                         HEAVY HELMS                          //
//                      MONSTER BATTLE GAME                     //
//==============================================================//
/// @title Monster Battle Game Mode for Heavy Helms
/// @notice Allows players to fight monsters for XP and bounty rewards with real death risk
/// @dev Integrates with VRF for fair, random combat resolution with lethality mechanics
///      XP Rewards: Easy (50 win/5 loss), Normal (100 win/15 loss), Hard (150 win/30 loss)
contract MonsterBattleGame is BaseGame, VRFConsumerBaseV2Plus {
    //==============================================================//
    //                          ENUMS                               //
    //==============================================================//
    /// @notice Monster difficulty levels
    enum DifficultyLevel {
        EASY, // 62-71 attribute points (levels 1-10)
        NORMAL, // 72-81 attribute points (levels 1-10)
        HARD // 82-91 attribute points (levels 1-10)
    }

    /// @notice Battle state for tracking VRF requests
    enum BattleState {
        PENDING, // Battle initiated, awaiting VRF
        COMPLETED // Battle completed
    }

    //==============================================================//
    //                         STRUCTS                              //
    //==============================================================//
    /// @notice Structure storing a monster battle data
    struct MonsterBattle {
        uint32 playerId;
        uint32 monsterId;
        DifficultyLevel difficulty;
        Fighter.PlayerLoadout playerLoadout;
        BattleState state;
        uint256 vrfRequestTimestamp;
    }

    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    // --- VRF Configuration ---
    /// @notice Timeout period in seconds after which a VRF request can be considered failed
    uint256 public vrfRequestTimeout = 24 hours;
    /// @notice Chainlink VRF configuration
    uint256 public subscriptionId;
    bytes32 public keyHash;
    uint32 public callbackGasLimit = 2_000_000;
    uint16 public requestConfirmations = 3;

    // --- Contract References ---
    /// @notice Player tickets contract for burning reset tickets and minting rewards
    IPlayerTicketsForMonsters public playerTickets;
    /// @notice Monster contract for reading monster data and kill counts
    IMonster public monsterContract;

    // --- Game Configuration ---
    /// @notice Whether the game is enabled for battles
    bool public isGameEnabled = true;
    /// @notice Lethality factor for monster battles (higher = more death risk)
    uint16 public lethalityFactor = 75;

    // --- Daily Limit System ---
    /// @notice Maximum monster battles per player per day
    uint8 public dailyMonsterLimit = 5;
    /// @notice Cost in ETH to reset daily limit for a player
    uint256 public dailyResetCost = 0.001 ether;
    /// @notice Maps player ID to day number to run count (playerId => dayNumber => runCount)
    mapping(uint32 => mapping(uint256 => uint8)) private _playerDailyRuns;

    // --- Monster Availability ---
    /// @notice Maps difficulty levels to available monster IDs
    mapping(DifficultyLevel => uint32[]) public availableMonstersByDifficulty;
    /// @notice Maps monster ID to its difficulty level for quick lookup
    mapping(uint32 => DifficultyLevel) public monsterDifficulty;

    // --- Monster State Tracking (Game Mode Specific) ---
    /// @notice Tracks if a monster is retired (dead) in this game mode
    mapping(uint32 => bool) private _monsterRetired;
    /// @notice Tracks monster battle records (wins, losses, kills) in this game mode
    mapping(uint32 => Fighter.Record) private _monsterRecords;

    // --- Battle Tracking ---
    /// @notice Next battle ID to be assigned
    uint256 public nextBattleId;
    /// @notice Maps battle IDs to their battle data
    mapping(uint256 => MonsterBattle) public battles;
    /// @notice Maps VRF request IDs to battle IDs
    mapping(uint256 => uint256) public requestToBattleId;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a monster battle is initiated
    event MonsterBattleStarted(
        uint256 indexed battleId,
        uint32 indexed playerId,
        uint32 indexed monsterId,
        DifficultyLevel difficulty,
        uint32 playerSkinIndex,
        uint16 playerSkinTokenId,
        uint8 playerStance
    );
    /// @notice Emitted when a monster battle is completed
    event MonsterBattleCompleted(
        uint256 indexed battleId,
        uint32 indexed winnerId,
        bool playerWon,
        IGameEngine.WinCondition winCondition,
        uint256 randomness
    );
    /// @notice Emitted when XP is awarded to a player
    event MonsterBattleXPAwarded(uint32 indexed playerId, uint16 xpAmount, bool playerWon, DifficultyLevel difficulty);
    /// @notice Emitted when bounty rewards are distributed
    event BountyRewardDistributed(
        uint32 indexed playerId, uint32 indexed monsterId, uint32 monsterKillCount, bool isLegendary
    );
    /// @notice Emitted when a player's daily monster battle limit is reset
    event DailyLimitReset(uint32 indexed playerId, uint256 dayNumber, bool paidWithTicket);
    /// @notice Emitted when a monster is permanently removed (killed)
    event MonsterKilled(uint32 indexed monsterId, uint32 indexed killerPlayerId, DifficultyLevel difficulty);
    /// @notice Emitted when a player dies in monster battle
    event PlayerDiedInBattle(uint32 indexed playerId, uint32 indexed monsterId);
    /// @notice Emitted when game enabled state is updated
    event GameEnabledUpdated(bool enabled);
    /// @notice Emitted when lethality factor is updated
    event LethalityFactorUpdated(uint16 oldFactor, uint16 newFactor);
    /// @notice Emitted when daily reset cost is updated
    event DailyResetCostUpdated(uint256 oldCost, uint256 newCost);
    /// @notice Emitted when daily monster limit is updated
    event DailyMonsterLimitUpdated(uint8 oldLimit, uint8 newLimit);
    /// @notice Emitted when VRF request timeout is updated
    event VrfRequestTimeoutUpdated(uint256 oldValue, uint256 newValue);
    /// @notice Emitted when a battle is recovered from a VRF timeout
    event BattleRecovered(uint256 indexed battleId);

    //==============================================================//
    //                        MODIFIERS                             //
    //==============================================================//
    /// @notice Ensures game is enabled for function execution
    modifier whenGameEnabled() {
        if (!isGameEnabled) revert GameDisabled();
        _;
    }

    /// @notice Ensures the caller is the owner of the specified player
    modifier onlyPlayerOwner(uint32 playerId) {
        address owner = IPlayer(playerContract).getPlayerOwner(playerId);
        if (msg.sender != owner) revert CallerNotPlayerOwner();
        _;
    }

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    /// @notice Initializes the MonsterBattleGame contract
    /// @param _gameEngine Address of the game engine contract
    /// @param _playerContract Address of the player contract
    /// @param _monsterContract Address of the monster contract
    /// @param vrfCoordinator Address of the Chainlink VRF coordinator
    /// @param _subscriptionId Chainlink VRF subscription ID
    /// @param _keyHash Chainlink VRF key hash for the gas lane
    /// @param _playerTickets Address of the player tickets contract
    constructor(
        address _gameEngine,
        address payable _playerContract,
        address _monsterContract,
        address vrfCoordinator,
        uint256 _subscriptionId,
        bytes32 _keyHash,
        address _playerTickets
    ) BaseGame(_gameEngine, _playerContract) VRFConsumerBaseV2Plus(vrfCoordinator) {
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        monsterContract = IMonster(_monsterContract);
        playerTickets = IPlayerTicketsForMonsters(_playerTickets);
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//

    /// @notice Fight a random monster from the specified difficulty tier
    /// @param difficulty The difficulty level of monsters to choose from
    /// @param loadout The player's loadout for this battle
    /// @return battleId ID of the created battle
    function fightMonster(DifficultyLevel difficulty, Fighter.PlayerLoadout calldata loadout)
        external
        whenGameEnabled
        onlyPlayerOwner(loadout.playerId)
        returns (uint256)
    {
        // Check daily limit
        uint256 today = block.timestamp / 1 days;
        uint8 currentRuns = _playerDailyRuns[loadout.playerId][today];
        if (currentRuns >= dailyMonsterLimit) {
            revert DailyLimitExceeded(currentRuns, dailyMonsterLimit);
        }

        // Validate player and loadout
        _validatePlayerBattle(loadout);

        // Get random monster from difficulty tier
        uint32[] storage availableMonsters = availableMonstersByDifficulty[difficulty];
        if (availableMonsters.length == 0) revert NoMonstersAvailable();

        // Use simple randomness for monster selection (VRF will be used for combat)
        uint32 monsterId = availableMonsters[block.timestamp % availableMonsters.length];

        // Increment daily run counter
        _playerDailyRuns[loadout.playerId][today]++;

        return _initiateBattle(loadout, monsterId, difficulty);
    }

    /// @notice Fight a specific monster by ID (Level 10 bounty hunting only)
    /// @param monsterId The specific monster to fight
    /// @param loadout The player's loadout for this battle
    /// @return battleId ID of the created battle
    function fightSpecificMonster(uint32 monsterId, Fighter.PlayerLoadout calldata loadout)
        external
        whenGameEnabled
        onlyPlayerOwner(loadout.playerId)
        returns (uint256)
    {
        // Check player level requirement for bounty hunting
        IPlayer.PlayerStats memory playerStats = IPlayer(playerContract).getPlayer(loadout.playerId);
        if (playerStats.level < 10) revert BountyHuntingRequiresLevel10();

        // Check daily limit
        uint256 today = block.timestamp / 1 days;
        uint8 currentRuns = _playerDailyRuns[loadout.playerId][today];
        if (currentRuns >= dailyMonsterLimit) {
            revert DailyLimitExceeded(currentRuns, dailyMonsterLimit);
        }

        // Validate player and loadout
        _validatePlayerBattle(loadout);

        // Check monster has kills (bounty requirement)
        uint32 killCount = _monsterRecords[monsterId].kills;
        if (killCount == 0) revert MonsterHasNoKills();

        // Check monster exists and is alive
        if (_monsterRetired[monsterId]) revert MonsterAlreadyDead();

        // Get monster difficulty
        DifficultyLevel difficulty = monsterDifficulty[monsterId];

        // Increment daily run counter
        _playerDailyRuns[loadout.playerId][today]++;

        return _initiateBattle(loadout, monsterId, difficulty);
    }

    /// @notice Resets the daily monster battle limit for a player by paying ETH
    /// @param playerId The ID of the player to reset limit for
    function resetMonsterDailyLimit(uint32 playerId) external payable onlyPlayerOwner(playerId) {
        if (msg.value < dailyResetCost) revert InsufficientResetFee();

        uint256 today = block.timestamp / 1 days;
        uint8 currentRuns = _playerDailyRuns[playerId][today];
        if (dailyMonsterLimit > 2 && currentRuns <= dailyMonsterLimit - 2) {
            revert ResetNotNeeded(currentRuns, dailyMonsterLimit);
        }

        _playerDailyRuns[playerId][today] = 0;
        emit DailyLimitReset(playerId, today, false);
    }

    /// @notice Resets the daily monster battle limit for a player by burning a DAILY_RESET_TICKET
    /// @param playerId The ID of the player to reset limit for
    function resetMonsterDailyLimitWithTicket(uint32 playerId) external onlyPlayerOwner(playerId) {
        uint256 today = block.timestamp / 1 days;
        uint8 currentRuns = _playerDailyRuns[playerId][today];
        if (dailyMonsterLimit > 2 && currentRuns <= dailyMonsterLimit - 2) {
            revert ResetNotNeeded(currentRuns, dailyMonsterLimit);
        }

        playerTickets.burnFrom(msg.sender, playerTickets.DAILY_RESET_TICKET(), 1);
        _playerDailyRuns[playerId][today] = 0;
        emit DailyLimitReset(playerId, today, true);
    }

    /// @notice Gets the current daily run count for a player
    /// @param playerId The ID of the player to check
    /// @return The number of monster battles today for this player
    function getDailyRunCount(uint32 playerId) external view returns (uint8) {
        uint256 today = block.timestamp / 1 days;
        return _playerDailyRuns[playerId][today];
    }

    /// @notice Check if a monster is retired (dead) in this game mode
    /// @param monsterId The ID of the monster to check
    /// @return True if the monster is retired/dead
    function isMonsterRetired(uint32 monsterId) external view returns (bool) {
        return _monsterRetired[monsterId];
    }

    /// @notice Get the full battle record for a monster
    /// @param monsterId The ID of the monster
    /// @return The monster's complete battle record (wins, losses, kills)
    function getMonsterRecord(uint32 monsterId) external view returns (Fighter.Record memory) {
        return _monsterRecords[monsterId];
    }

    /// @notice Get the kill count for a specific monster (convenience method)
    /// @param monsterId The ID of the monster
    /// @return The number of players this monster has killed
    function getMonsterKillCount(uint32 monsterId) external view returns (uint32) {
        return _monsterRecords[monsterId].kills;
    }

    /// @notice Allows recovery from timed-out VRF requests
    /// @param battleId ID of the battle to recover
    function recoverTimedOutVRF(uint256 battleId) external {
        MonsterBattle storage battle = battles[battleId];

        if (battle.playerId == 0) revert BattleDoesNotExist();
        if (battle.state != BattleState.PENDING) revert BattleNotPending();

        address playerOwner = IPlayer(playerContract).getPlayerOwner(battle.playerId);
        if (msg.sender != playerOwner) revert NotAuthorized();

        if (battle.vrfRequestTimestamp == 0) revert InvalidVrfRequestTimestamp();
        if (block.timestamp < battle.vrfRequestTimestamp + vrfRequestTimeout) revert VrfTimeoutNotReached();

        battle.state = BattleState.COMPLETED;
        emit BattleRecovered(battleId);
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

    /// @notice Updates the lethality factor for monster battles
    /// @param newFactor The new lethality factor
    function setLethalityFactor(uint16 newFactor) external onlyOwner {
        emit LethalityFactorUpdated(lethalityFactor, newFactor);
        lethalityFactor = newFactor;
    }

    /// @notice Updates the daily reset cost
    /// @param newCost The new cost in ETH for daily limit resets
    function setDailyResetCost(uint256 newCost) external onlyOwner {
        emit DailyResetCostUpdated(dailyResetCost, newCost);
        dailyResetCost = newCost;
    }

    /// @notice Sets the daily monster battle entry limit per player
    /// @param newLimit The new daily entry limit
    function setDailyMonsterLimit(uint8 newLimit) external onlyOwner {
        if (newLimit == 0) revert ValueMustBePositive();
        emit DailyMonsterLimitUpdated(dailyMonsterLimit, newLimit);
        dailyMonsterLimit = newLimit;
    }

    /// @notice Updates the timeout period for VRF requests
    /// @param newValue The new timeout period in seconds
    function setVrfRequestTimeout(uint256 newValue) external onlyOwner {
        if (newValue == 0) revert ValueMustBePositive();
        emit VrfRequestTimeoutUpdated(vrfRequestTimeout, newValue);
        vrfRequestTimeout = newValue;
    }

    /// @notice Adds a batch of monsters to a specific difficulty tier
    /// @param monsterIds Array of monster IDs to add
    /// @param difficulty The difficulty tier to add them to
    function addNewMonsterBatch(uint32[] calldata monsterIds, DifficultyLevel difficulty) external onlyOwner {
        uint256 length = monsterIds.length;
        for (uint256 i = 0; i < length; i++) {
            uint32 monsterId = monsterIds[i];
            availableMonstersByDifficulty[difficulty].push(monsterId);
            monsterDifficulty[monsterId] = difficulty;
        }
    }

    /// @notice Withdraws accumulated ETH fees to the owner address
    function withdrawFees() external onlyOwner {
        SafeTransferLib.safeTransferETH(owner(), address(this).balance);
    }

    /// @notice Sets a new game engine address
    /// @param _newEngine Address of the new game engine
    function setGameEngine(address _newEngine) public override(BaseGame) onlyOwner {
        super.setGameEngine(_newEngine);
    }

    //==============================================================//
    //                    INTERNAL FUNCTIONS                        //
    //==============================================================//

    /// @notice Internal function to validate player and loadout for battle
    /// @param loadout The player's loadout to validate
    function _validatePlayerBattle(Fighter.PlayerLoadout calldata loadout) internal view {
        if (IPlayer(playerContract).isPlayerRetired(loadout.playerId)) revert PlayerIsRetired();

        // Validate skin ownership and requirements
        address owner = IPlayer(playerContract).getPlayerOwner(loadout.playerId);
        IPlayer(playerContract).skinRegistry().validateSkinOwnership(loadout.skin, owner);
        IPlayer(playerContract).skinRegistry()
            .validateSkinRequirements(
                loadout.skin,
                IPlayer(playerContract).getPlayer(loadout.playerId).attributes,
                IPlayer(playerContract).equipmentRequirements()
            );
    }

    /// @notice Internal function to initiate a monster battle
    /// @param loadout The player's loadout
    /// @param monsterId The ID of the monster to fight
    /// @param difficulty The difficulty level of the monster
    /// @return battleId The ID of the created battle
    function _initiateBattle(Fighter.PlayerLoadout calldata loadout, uint32 monsterId, DifficultyLevel difficulty)
        internal
        returns (uint256)
    {
        uint256 battleId = nextBattleId++;
        battles[battleId] = MonsterBattle({
            playerId: loadout.playerId,
            monsterId: monsterId,
            difficulty: difficulty,
            playerLoadout: loadout,
            state: BattleState.PENDING,
            vrfRequestTimestamp: block.timestamp
        });

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
        requestToBattleId[requestId] = battleId;

        emit MonsterBattleStarted(
            battleId,
            loadout.playerId,
            monsterId,
            difficulty,
            loadout.skin.skinIndex,
            loadout.skin.skinTokenId,
            loadout.stance
        );

        return battleId;
    }

    /// @notice Processes VRF randomness fulfillment for monster battles
    /// @param requestId ID of the VRF request
    /// @param randomWords Array of random values from VRF
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 battleId = requestToBattleId[requestId];
        MonsterBattle storage battle = battles[battleId];

        if (battle.state != BattleState.PENDING) return;

        // Clear state FIRST
        delete requestToBattleId[requestId];
        battle.state = BattleState.COMPLETED;

        // Check if player is still alive
        if (IPlayer(playerContract).isPlayerRetired(battle.playerId)) return;
        // Check if monster is still alive
        if (_monsterRetired[battle.monsterId]) return;

        uint256 randomness = randomWords[0];
        uint256 combinedSeed = uint256(keccak256(abi.encodePacked(randomness, requestId)));

        // Execute the battle with lethality
        _executeBattle(battleId, combinedSeed);
    }

    /// @notice Executes a monster battle with the given randomness
    /// @param battleId The ID of the battle to execute
    /// @param randomness The random seed for combat
    function _executeBattle(uint256 battleId, uint256 randomness) internal {
        MonsterBattle storage battle = battles[battleId];

        // Load player combat stats with loadout
        IPlayer.PlayerStats memory playerStats = IPlayer(playerContract).getPlayer(battle.playerId);
        playerStats.skin = battle.playerLoadout.skin;
        playerStats.stance = battle.playerLoadout.stance;

        // Get player skin attributes and construct FighterStats
        IPlayerSkinNFT.SkinAttributes memory playerSkinAttrs =
            Fighter(address(playerContract)).getSkinAttributes(playerStats.skin);
        IGameEngine.FighterStats memory playerCombat = IGameEngine.FighterStats({
            weapon: playerSkinAttrs.weapon,
            armor: playerSkinAttrs.armor,
            stance: playerStats.stance,
            attributes: playerStats.attributes,
            level: playerStats.level,
            weaponSpecialization: playerStats.weaponSpecialization,
            armorSpecialization: playerStats.armorSpecialization
        });

        // Load monster combat stats - derive level from player level
        uint8 monsterLevel = _deriveMonsterLevel(playerStats.level, battle.difficulty);
        IMonster.MonsterStats memory monsterStats = monsterContract.getMonster(battle.monsterId, monsterLevel);

        // Get monster skin attributes (monsters use PlayerSkinRegistry for skins)
        IPlayerSkinNFT.SkinAttributes memory monsterSkinAttrs =
            Fighter(address(monsterContract)).getSkinAttributes(monsterStats.skin);

        IGameEngine.FighterStats memory monsterCombat = IGameEngine.FighterStats({
            weapon: monsterSkinAttrs.weapon,
            armor: monsterSkinAttrs.armor,
            stance: monsterStats.stance,
            attributes: monsterStats.attributes,
            level: monsterStats.level,
            weaponSpecialization: monsterStats.weaponSpecialization,
            armorSpecialization: monsterStats.armorSpecialization
        });

        // Execute combat with lethality factor
        bytes memory results = gameEngine.processGame(playerCombat, monsterCombat, randomness, lethalityFactor);
        (bool playerWon,, IGameEngine.WinCondition condition,) = gameEngine.decodeCombatLog(results);

        // Get seasonal records for event emission
        Fighter.Record memory playerRecord = IPlayer(playerContract).getCurrentSeasonRecord(battle.playerId);

        // Emit combat result with player data and simple monster data
        emit CombatResult(
            IPlayer(playerContract).codec().encodePlayerData(battle.playerId, playerStats, playerRecord),
            bytes32(uint256(battle.monsterId)), // Simple monster encoding
            playerWon ? battle.playerId : battle.monsterId,
            results
        );

        // Handle battle outcome
        if (playerWon) {
            // Player victory
            uint256 currentSeason = IPlayer(playerContract).forceCurrentSeason();
            IPlayer(playerContract).incrementWins(battle.playerId, currentSeason);
            _monsterRecords[battle.monsterId].losses++;

            // Award XP if player is under level 10
            if (playerStats.level < 10) {
                _awardMonsterBattleXP(battle.playerId, battle.difficulty, true);
            }

            // Handle monster death and bounty rewards if death condition
            if (condition == IGameEngine.WinCondition.DEATH) {
                IPlayer(playerContract).incrementKills(battle.playerId, currentSeason);
                _handleMonsterDeath(battle.monsterId, battle.playerId, battle.difficulty);
            }
        } else {
            // Monster victory
            uint256 currentSeason = IPlayer(playerContract).forceCurrentSeason();
            IPlayer(playerContract).incrementLosses(battle.playerId, currentSeason);
            _monsterRecords[battle.monsterId].wins++;

            // Award loss XP if player is under level 10
            if (playerStats.level < 10) {
                _awardMonsterBattleXP(battle.playerId, battle.difficulty, false);
            }

            // Handle player death if death condition
            if (condition == IGameEngine.WinCondition.DEATH) {
                _monsterRecords[battle.monsterId].kills++;
                IPlayer(playerContract).setPlayerRetired(battle.playerId, true);
                emit PlayerDiedInBattle(battle.playerId, battle.monsterId);
            }
        }

        emit MonsterBattleCompleted(
            battleId, playerWon ? battle.playerId : battle.monsterId, playerWon, condition, randomness
        );
    }

    /// @notice Awards XP for monster battle based on difficulty and outcome
    /// @param playerId The ID of the player to award XP to
    /// @param difficulty The difficulty of the monster fought
    /// @param playerWon Whether the player won the battle
    function _awardMonsterBattleXP(uint32 playerId, DifficultyLevel difficulty, bool playerWon) internal {
        uint16 xpAmount;

        if (playerWon) {
            // Win XP amounts
            if (difficulty == DifficultyLevel.EASY) {
                xpAmount = 50;
            } else if (difficulty == DifficultyLevel.NORMAL) {
                xpAmount = 100;
            } else {
                // HARD
                xpAmount = 150;
            }
        } else {
            // Loss XP amounts (consolation XP)
            if (difficulty == DifficultyLevel.EASY) {
                xpAmount = 5;
            } else if (difficulty == DifficultyLevel.NORMAL) {
                xpAmount = 15;
            } else {
                // HARD
                xpAmount = 30;
            }
        }

        IPlayer(playerContract).awardExperience(playerId, xpAmount);
        emit MonsterBattleXPAwarded(playerId, xpAmount, playerWon, difficulty);
    }

    /// @notice Handles monster death - retirement, bounty rewards, and removal from availability
    /// @param monsterId The ID of the dead monster
    /// @param killerPlayerId The ID of the player who killed the monster
    /// @param difficulty The difficulty tier of the killed monster
    function _handleMonsterDeath(uint32 monsterId, uint32 killerPlayerId, DifficultyLevel difficulty) internal {
        // Retire the monster permanently
        _monsterRetired[monsterId] = true;

        // Get monster record for bounty calculation
        Fighter.Record memory monsterRecord = _monsterRecords[monsterId];

        // Distribute bounty rewards based on monster's battle record
        _distributeBountyRewards(killerPlayerId, monsterId, monsterRecord);

        // Remove monster from availability array
        _removeMonsterFromAvailability(monsterId, difficulty);

        emit MonsterKilled(monsterId, killerPlayerId, difficulty);
    }

    /// @notice Distributes bounty rewards based on monster's battle record
    /// @param playerId The ID of the player to reward
    /// @param monsterId The ID of the killed monster
    /// @param monsterRecord The complete battle record of the monster
    function _distributeBountyRewards(uint32 playerId, uint32 monsterId, Fighter.Record memory monsterRecord) internal {
        if (monsterRecord.kills == 0) return; // No bounty for monsters with no kills

        address playerOwner = IPlayer(playerContract).getPlayerOwner(playerId);

        // Base bounty: DAILY_RESET_TICKETS and CREATE_PLAYER_TICKETS × kill_count
        try playerTickets.mintFungibleTicketSafe(
            playerOwner, playerTickets.DAILY_RESET_TICKET(), monsterRecord.kills
        ) {}
            catch {}

        try playerTickets.mintFungibleTicketSafe(
            playerOwner, playerTickets.CREATE_PLAYER_TICKET(), monsterRecord.kills
        ) {}
            catch {}

        bool isLegendary = false;

        // Legendary bounty for 5+ kills
        if (monsterRecord.kills >= 5) {
            isLegendary = true;
            // Award attribute swap charge (bound to account)
            try playerTickets.awardAttributeSwap(playerOwner) {} catch {}
            // Note: Name/ID etching and exclusive skin unlock would be handled separately
        }

        emit BountyRewardDistributed(playerId, monsterId, monsterRecord.kills, isLegendary);
    }

    /// @notice Removes a dead monster from the availability arrays
    /// @param monsterId The ID of the monster to remove
    /// @param difficulty The difficulty tier to remove from
    function _removeMonsterFromAvailability(uint32 monsterId, DifficultyLevel difficulty) internal {
        uint32[] storage monsters = availableMonstersByDifficulty[difficulty];
        uint256 length = monsters.length;

        // Find and remove using swap-and-pop
        for (uint256 i = 0; i < length; i++) {
            if (monsters[i] == monsterId) {
                monsters[i] = monsters[length - 1];
                monsters.pop();
                break;
            }
        }

        // Clean up difficulty mapping
        delete monsterDifficulty[monsterId];
    }

    /// @notice Derives monster level based on player level and difficulty
    /// @param playerLevel The player's current level
    /// @param difficulty The difficulty tier of the monster
    /// @return The appropriate monster level
    function _deriveMonsterLevel(uint8 playerLevel, DifficultyLevel difficulty) internal pure returns (uint8) {
        // Level 10 players always face level 10 monsters
        if (playerLevel == 10) {
            return 10;
        }

        // For players under level 10
        if (difficulty == DifficultyLevel.EASY) {
            return playerLevel == 1 ? 1 : playerLevel - 1;
        } else if (difficulty == DifficultyLevel.NORMAL) {
            return playerLevel;
        } else {
            // HARD
            return playerLevel + 1;
        }
    }

    /// @notice Checks if a player ID is supported in Monster Battle mode
    /// @param playerId The ID to check
    /// @return True if player ID is supported
    function _isPlayerIdSupported(uint32 playerId) internal pure override returns (bool) {
        // Only regular players are supported in Monster Battle mode
        return playerId > MONSTER_END;
    }

    /// @notice Gets the fighter contract for a player ID
    /// @param playerId The ID to check
    /// @return Fighter contract implementation
    function _getFighterContract(uint32 playerId) internal view override returns (Fighter) {
        if (!_isPlayerIdSupported(playerId)) revert UnsupportedPlayerIdForMonsterMode();
        return Fighter(address(playerContract));
    }

    //==============================================================//
    //                    FALLBACK FUNCTIONS                        //
    //==============================================================//
    /// @notice Allows contract to receive ETH for VRF funding
    receive() external payable {}
}

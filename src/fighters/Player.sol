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
// External imports
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
// Internal imports
import "../interfaces/fighters/IPlayer.sol";
import "../interfaces/fighters/registries/names/IPlayerNameRegistry.sol";
import "../interfaces/game/engine/IEquipmentRequirements.sol";
import "../nft/PlayerTickets.sol";
import "./Fighter.sol";
import "../interfaces/fighters/IPlayerDataCodec.sol";
import "../lib/UniformRandomNumber.sol";
// DateTime library for PST season calculations
import "BokkyPooBahsDateTimeLibrary/BokkyPooBahsDateTimeLibrary.sol";
//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
/// @notice Thrown when a player ID doesn't exist

error PlayerDoesNotExist(uint32 playerId);
/// @notice Thrown when caller doesn't own the player they're trying to modify
error NotPlayerOwner();
/// @notice Thrown when VRF request timeout hasn't been reached yet
error VrfRequestNotTimedOut();
/// @notice Thrown when a value must be positive but zero was provided
error ValueMustBePositive();
/// @notice Thrown when attempting to modify a retired player
error PlayerIsRetired(uint32 playerId);
/// @notice Thrown when contract is in paused state
error ContractPaused();
/// @notice Thrown when an address attempts to create more players than allowed
error TooManyPlayers();
/// @notice Thrown when trying to create a new player while another request is pending
error PendingRequestExists();
/// @notice Thrown when attempting to fulfill an invalid VRF request
error InvalidRequestID();
/// @notice Thrown when attempting to fulfill an already fulfilled VRF request
error RequestAlreadyFulfilled();
/// @notice Thrown when insufficient ETH is sent for player creation
error InsufficientFeeAmount();
/// @notice Thrown when caller doesn't have required permission
error NoPermission();
/// @notice Thrown when attempting to set zero address for critical contract references
error BadZeroAddress();
/// @notice Thrown when insufficient charges are available
error InsufficientCharges();
/// @notice Thrown when attempting to swap invalid attributes
error InvalidAttributeSwap();
/// @notice Thrown when attempting to use an invalid name index
error InvalidNameIndex();
/// @notice Thrown when attempting to use an invalid player ID range
error InvalidPlayerRange();
/// @notice Thrown when no pending request exists
error NoPendingRequest();
/// @notice Thrown when player level is too low for weapon specialization (requires level 10)
error WeaponSpecializationLevelTooLow();
/// @notice Thrown when player level is too low for armor specialization (requires level 5)
error ArmorSpecializationLevelTooLow();

//==============================================================//
//                         HEAVY HELMS                          //
//                           PLAYER                             //
//==============================================================//
/// @title Player Contract for Heavy Helms
/// @notice Manages player creation, attributes, skins, and persistent player data
/// @dev Integrates with VRF for random stat generation and interfaces with skin/name registries
contract Player is IPlayer, VRFConsumerBaseV2Plus, Fighter {
    using UniformRandomNumber for uint256;
    //==============================================================//
    //                     TYPE DECLARATIONS                        //
    //==============================================================//
    // Structs
    /// @notice Tracks the state of a pending player creation request
    /// @dev Used to manage VRF requests and their fulfillment
    /// @param owner Address that requested the player creation
    /// @param useNameSetB Whether to use name set B (true) or A (false) for generation
    /// @param fulfilled Whether the VRF request has been fulfilled
    /// @param timestamp Timestamp when request was created
    /// @param paidWithTicket Whether the player was paid for with a ticket (true) or ETH (false)

    struct PendingPlayer {
        address owner;
        bool useNameSetB;
        bool fulfilled;
        uint64 timestamp;
        bool paidWithTicket;
    }

    /// @notice Contains metadata about a season
    /// @param startTimestamp Unix timestamp when the season started
    /// @param startBlock Block number when the season started
    struct Season {
        uint256 startTimestamp;
        uint256 startBlock;
    }

    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    // Constants
    /// @notice Minimum value for any player stat
    uint8 private constant MIN_STAT = 3;
    /// @notice Maximum value for any player stat from initial creation or swaps
    uint8 private constant MAX_STAT = 21;
    /// @notice Maximum value for any player stat with leveling attribute points
    uint8 private constant MAX_LEVELING_STAT = 25;
    /// @notice Total points available for player stats (sum of all stats must equal this)
    uint16 private constant TOTAL_STATS = 72;
    /// @notice Base number of player slots per address
    uint8 public constant BASE_PLAYER_SLOTS = 3;
    /// @notice Maximum total player slots an address can have (base + purchased)
    uint8 private constant MAX_TOTAL_SLOTS = 100;
    /// @notice Starting ID for user-created players (1-2000 reserved for default characters)
    uint32 private constant USER_PLAYER_START = 10001;
    /// @notice End ID for user-created players (no upper limit for user players)
    uint32 private constant USER_PLAYER_END = type(uint32).max;
    /// @notice Timeout period in seconds after which a player creation request can be recovered
    uint256 public vrfRequestTimeout = 24 hours;
    /// @notice Base experience points for first level up
    uint16 private constant BASE_XP = 100;

    // Configuration
    /// @notice Fee amount in ETH required to create a new player
    uint256 public createPlayerFeeAmount = 0.001 ether;
    /// @notice Cost in ETH for each additional slot batch (1 slot) - fixed cost
    uint256 public slotBatchCost = 0.001 ether;
    /// @notice Number of slots added per batch purchase
    uint8 public immutable SLOT_BATCH_SIZE = 1;
    /// @notice Whether the contract is paused (prevents new player creation)
    bool public isPaused;

    // Contract References
    /// @notice Registry contract for managing player name sets and validation
    IPlayerNameRegistry private immutable _nameRegistry;
    /// @notice Interface for equipment requirements validation
    IEquipmentRequirements private _equipmentRequirements;
    /// @notice PlayerTickets contract for burnable NFT tickets
    PlayerTickets private immutable _playerTickets;
    /// @notice PlayerDataCodec contract for encoding/decoding player data
    IPlayerDataCodec private immutable _playerDataCodec;

    // Player state tracking
    /// @notice Starting ID for user-created players (1-2000 reserved for default characters)
    uint32 private nextPlayerId = USER_PLAYER_START;
    /// @notice Maps player ID to their stats and attributes
    mapping(uint32 => IPlayer.PlayerStats) private _players;
    /// @notice Maps player ID to their owner's address
    mapping(uint32 => address) private _playerOwners;
    /// @notice Tracks how many active (non-retired) players each address has
    mapping(address => uint256) private _addressActivePlayerCount;
    /// @notice Maps player ID to their retirement status
    mapping(uint32 => bool) private _retiredPlayers;
    /// @notice Maps player ID to their immortality status
    mapping(uint32 => bool) private _immortalPlayers;
    /// @notice Maps game contract address to their granted permissions
    mapping(address => IPlayer.GamePermissions) private _gameContractPermissions;
    /// @notice Maps address to their number of purchased extra player slots
    mapping(address => uint8) private _extraPlayerSlots;
    /// @notice Maps player ID to their available attribute points from leveling
    mapping(uint32 => uint256) private _attributePoints;

    // VRF Request tracking
    /// @notice Maps VRF request IDs to their pending player creation details
    mapping(uint256 => PendingPlayer) private _pendingPlayers;
    /// @notice Maps user address to their current pending request ID
    /// @dev 0 indicates no pending request, >0 is the active request ID
    mapping(address => uint256) private _userPendingRequest;

    // Chainlink VRF Configuration
    /// @notice Chainlink VRF subscription ID for funding requests
    uint256 public subscriptionId;
    /// @notice Gas lane key hash for VRF requests
    bytes32 public keyHash;
    /// @notice Gas limit for the VRF callback function
    uint32 public callbackGasLimit = 2000000;
    /// @notice Number of block confirmations to wait before fulfillment
    uint16 public requestConfirmations = 3;

    // Season tracking
    /// @notice Current season number (starts at 0)
    uint256 public currentSeason;
    /// @notice Timestamp when the next season will start
    uint256 public nextSeasonStart;
    /// @notice Length of each season in months (configurable by owner)
    uint256 public seasonLengthMonths = 1;
    /// @notice Maps season ID to season metadata
    mapping(uint256 => Season) public seasons;
    /// @notice Maps player ID to seasonal records (playerId => seasonId => Record)
    mapping(uint32 => mapping(uint256 => Fighter.Record)) public seasonalRecords;
    /// @notice Maps player ID to lifetime records (playerId => Record)
    mapping(uint32 => Fighter.Record) public lifetimeRecords;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a player's retirement status changes
    /// @param playerId The ID of the player being retired/unretired
    /// @param caller The address that changed the retirement status
    /// @param retired The new retirement status
    event PlayerRetired(uint32 indexed playerId, address indexed caller, bool retired);

    /// @notice Emitted when a player's immortality status changes
    /// @param playerId The ID of the player
    /// @param caller The address that changed the immortality status
    /// @param immortal The new immortality status
    event PlayerImmortalityChanged(uint32 indexed playerId, address indexed caller, bool immortal);

    /// @notice Emitted when a player equips a new skin and sets stance
    /// @param playerId The ID of the player
    /// @param skinIndex The index of the skin collection in the registry
    /// @param tokenId The token ID of the specific skin being equipped
    /// @param stance The new stance value (0=Defensive, 1=Balanced, 2=Offensive)
    event PlayerSkinEquipped(uint32 indexed playerId, uint32 indexed skinIndex, uint16 tokenId, uint8 stance);

    /// @notice Emitted when a VRF request for player creation is fulfilled with all player data
    /// @param requestId The VRF request ID
    /// @param playerId The ID of the newly created player
    /// @param owner The address that will own the new player
    /// @param randomness The random value provided by VRF
    /// @param firstNameIndex Index of the first name in the registry
    /// @param surnameIndex Index of the surname in the registry
    /// @param strength Initial strength value
    /// @param constitution Initial constitution value
    /// @param size Initial size value
    /// @param agility Initial agility value
    /// @param stamina Initial stamina value
    /// @param luck Initial luck value
    /// @param paidWithTicket Whether the player was paid for with a ticket (true) or ETH (false)
    event PlayerCreationComplete(
        uint256 indexed requestId,
        uint32 indexed playerId,
        address indexed owner,
        uint256 randomness,
        uint16 firstNameIndex,
        uint16 surnameIndex,
        uint8 strength,
        uint8 constitution,
        uint8 size,
        uint8 agility,
        uint8 stamina,
        uint8 luck,
        bool paidWithTicket
    );

    /// @notice Emitted when a new player creation is requested
    /// @param requestId The VRF request ID
    /// @param requester The address requesting the player creation
    /// @param paidWithTicket Whether the player was paid for with a ticket (true) or ETH (false)
    event PlayerCreationRequested(uint256 indexed requestId, address indexed requester, bool paidWithTicket);

    /// @notice Emitted when the player creation fee is updated
    /// @param oldFee The previous fee amount
    /// @param newFee The new fee amount
    event CreatePlayerFeeUpdated(uint256 oldFee, uint256 newFee);

    /// @notice Emitted when the contract's paused state changes
    /// @param isPaused The new paused state
    event PausedStateChanged(bool isPaused);

    /// @notice Emitted when the slot batch cost is updated
    /// @param oldCost The previous cost
    /// @param newCost The new cost
    event SlotBatchCostUpdated(uint256 oldCost, uint256 newCost);

    /// @notice Emitted when a user purchases additional player slots
    /// @param user Address of the purchaser
    /// @param totalSlots New total slots for the user
    /// @param paidWithTicket Whether the slots were paid for with a ticket (true) or ETH (false)
    event PlayerSlotsPurchased(address indexed user, uint8 totalSlots, bool paidWithTicket);

    /// @notice Emitted when a game contract's permissions are updated
    /// @param gameContract Address of the game contract
    /// @param permissions New permissions struct
    event GameContractPermissionsUpdated(address indexed gameContract, GamePermissions permissions);

    /// @notice Emitted when a player wins a match
    /// @param playerId The ID of the player
    /// @param seasonId The season this win occurred in
    event PlayerWinRecorded(uint32 indexed playerId, uint256 indexed seasonId);

    /// @notice Emitted when a player loses a match
    /// @param playerId The ID of the player
    /// @param seasonId The season this loss occurred in
    event PlayerLossRecorded(uint32 indexed playerId, uint256 indexed seasonId);

    /// @notice Emitted when a player kills an opponent
    /// @param playerId The ID of the player
    /// @param seasonId The season this kill occurred in
    event PlayerKillRecorded(uint32 indexed playerId, uint256 indexed seasonId);

    /// @notice Emitted when a player's name is changed
    /// @param playerId The ID of the player
    /// @param firstNameIndex New first name index
    /// @param surnameIndex New surname index
    event PlayerNameUpdated(uint32 indexed playerId, uint16 firstNameIndex, uint16 surnameIndex);

    /// @notice Emitted when a name change charge is awarded
    /// @param to Address receiving the charge
    /// @param totalCharges Total number of name change charges available
    event NameChangeAwarded(address indexed to, uint256 totalCharges);

    /// @notice Emitted when a player's attributes are swapped
    /// @param playerId The ID of the player
    /// @param decreaseAttribute Attribute being decreased
    /// @param increaseAttribute Attribute being increased
    /// @param newDecreaseValue New value of the decreased attribute
    /// @param newIncreaseValue New value of the increased attribute
    event PlayerAttributesSwapped(
        uint32 indexed playerId,
        Attribute decreaseAttribute,
        Attribute increaseAttribute,
        uint8 newDecreaseValue,
        uint8 newIncreaseValue
    );

    /// @notice Emitted when the equipment requirements contract is updated
    /// @param oldAddress The previous contract address
    /// @param newAddress The new contract address
    event EquipmentRequirementsUpdated(address indexed oldAddress, address indexed newAddress);

    /// @notice Emitted when a player creation request is recovered due to timeout or admin action
    /// @param requestId The VRF request ID that was recovered
    /// @param user The address of the user whose request was recovered
    /// @param amount The amount of ETH refunded
    /// @param adminInitiated Whether the recovery was initiated by an admin
    /// @param recoveryTimestamp The timestamp when the recovery occurred
    event RequestRecovered(
        uint256 indexed requestId, address indexed user, uint256 amount, bool adminInitiated, uint256 recoveryTimestamp
    );

    /// @notice Emitted when VRF request timeout is updated
    event VrfRequestTimeoutUpdated(uint256 oldValue, uint256 newValue);

    /// @notice Emitted when a player's stance is updated
    /// @param playerId The ID of the player
    /// @param stance The new stance value
    event StanceUpdated(uint32 indexed playerId, uint8 stance);

    /// @notice Emitted when a player gains experience
    /// @param playerId The ID of the player
    /// @param xpGained Amount of experience gained
    /// @param newXP New total experience
    event ExperienceGained(uint32 indexed playerId, uint16 xpGained, uint16 newXP);

    /// @notice Emitted when a player levels up
    /// @param playerId The ID of the player
    /// @param newLevel The new level achieved
    /// @param attributePointsAwarded Number of attribute points awarded
    event PlayerLevelUp(uint32 indexed playerId, uint8 newLevel, uint8 attributePointsAwarded);

    /// @notice Emitted when a player's weapon specialization changes
    /// @param playerId The ID of the player
    /// @param weaponClass The new weapon class specialization (0-6, 255 = none)
    event PlayerWeaponSpecializationChanged(uint32 indexed playerId, uint8 weaponClass);

    /// @notice Emitted when a player's armor specialization changes
    /// @param playerId The ID of the player
    /// @param armorType The new armor specialization (255 = none)
    event PlayerArmorSpecializationChanged(uint32 indexed playerId, uint8 armorType);

    /// @notice Emitted when an attribute point charge is awarded
    /// @param to Address receiving the charge
    /// @param totalCharges Total number of attribute point charges available
    event AttributePointAwarded(address indexed to, uint256 totalCharges);

    /// @notice Emitted when VRF configuration is updated
    /// @param keyHash New gas lane key hash
    /// @param callbackGasLimit New callback gas limit
    /// @param requestConfirmations New request confirmations
    event VRFConfigUpdated(bytes32 keyHash, uint32 callbackGasLimit, uint16 requestConfirmations);

    /// @notice Emitted when subscription ID is updated
    /// @param oldSubscriptionId Previous subscription ID
    /// @param newSubscriptionId New subscription ID
    event SubscriptionIdUpdated(uint256 oldSubscriptionId, uint256 newSubscriptionId);

    /// @notice Emitted when a new season starts
    /// @param seasonId The ID of the new season
    /// @param startTimestamp The timestamp when the season started
    /// @param startBlock The block number when the season started
    event SeasonStarted(uint256 indexed seasonId, uint256 startTimestamp, uint256 startBlock);

    /// @notice Emitted when the season length is updated
    /// @param oldLength The previous season length in months
    /// @param newLength The new season length in months
    event SeasonLengthUpdated(uint256 oldLength, uint256 newLength);

    /// @notice Emitted when a player uses an attribute point from leveling
    /// @param playerId The ID of the player
    /// @param attribute The attribute that was increased
    /// @param newValue The new attribute value
    /// @param remainingPoints Remaining attribute points for this player
    event PlayerAttributePointUsed(
        uint32 indexed playerId, Attribute attribute, uint8 newValue, uint256 remainingPoints
    );

    //==============================================================//
    //                        MODIFIERS                             //
    //==============================================================//
    /// @notice Ensures caller has the required game permission
    /// @param permission The specific permission being checked
    /// @dev Reverts with NoPermission if the caller lacks the required permission
    modifier hasPermission(IPlayer.GamePermission permission) {
        _checkPermission(permission);
        _;
    }

    /// @notice Ensures the specified player exists and is within valid user player range
    /// @param playerId The ID of the player to check
    /// @dev Reverts with PlayerDoesNotExist if the player ID is invalid
    modifier playerExists(uint32 playerId) {
        _checkPlayerExists(playerId);
        _;
    }

    modifier onlyPlayerOwner(uint32 playerId) {
        if (_playerOwners[playerId] != msg.sender) revert NotPlayerOwner();
        _;
    }

    /// @notice Ensures the contract is not paused
    /// @dev Reverts with ContractPaused if the contract is in a paused state
    modifier whenNotPaused() {
        if (isPaused) revert ContractPaused();
        _;
    }

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    /// @notice Initializes the Player contract with required dependencies
    /// @param skinRegistryAddress Address of the PlayerSkinRegistry contract
    /// @param nameRegistryAddress Address of the PlayerNameRegistry contract
    /// @param equipmentRequirementsAddress Address of the EquipmentRequirements contract
    /// @param vrfCoordinator Address of the Chainlink VRF v2.5 coordinator contract
    /// @param _subscriptionId Chainlink VRF subscription ID for funding
    /// @param _keyHash Chainlink VRF gas lane key hash
    /// @param playerTicketsAddress Address of the PlayerTickets contract
    /// @param playerDataCodecAddress Address of the PlayerDataCodec contract
    /// @dev Sets initial configuration values and connects to required registries
    constructor(
        address skinRegistryAddress,
        address nameRegistryAddress,
        address equipmentRequirementsAddress,
        address vrfCoordinator,
        uint256 _subscriptionId,
        bytes32 _keyHash,
        address playerTicketsAddress,
        address playerDataCodecAddress
    ) VRFConsumerBaseV2Plus(vrfCoordinator) Fighter(skinRegistryAddress) {
        // Set VRF configuration
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;

        _nameRegistry = IPlayerNameRegistry(nameRegistryAddress);
        _equipmentRequirements = IEquipmentRequirements(equipmentRequirementsAddress);
        _playerTickets = PlayerTickets(playerTicketsAddress);
        _playerDataCodec = IPlayerDataCodec(playerDataCodecAddress);

        // Initialize season 0
        currentSeason = 0;
        seasons[0] = Season({startTimestamp: block.timestamp, startBlock: block.number});
        nextSeasonStart = getNextSeasonStartPST();
        emit SeasonStarted(0, block.timestamp, block.number);

        // Emit initial fee events for subgraph tracking
        emit CreatePlayerFeeUpdated(0, createPlayerFeeAmount);
        emit SlotBatchCostUpdated(0, slotBatchCost);
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//

    // View Functions
    /// @notice Gets the complete stats and attributes for a player
    /// @param playerId The ID of the player to query
    /// @return PlayerStats struct containing all player data
    /// @dev Handles both default characters (1-999) and user-created players (1000+)
    function getPlayer(uint32 playerId) external view playerExists(playerId) returns (PlayerStats memory) {
        return _players[playerId];
    }

    /// @notice Gets the owner address of a specific player
    /// @param playerId The ID of the player to query
    /// @return Address of the player's owner
    /// @dev Reverts if player doesn't exist
    function getPlayerOwner(uint32 playerId) external view returns (address) {
        if (_playerOwners[playerId] == address(0)) revert PlayerDoesNotExist(playerId);
        return _playerOwners[playerId];
    }

    /// @notice Gets the permissions granted to a game contract
    /// @param gameContract The address of the game contract to check
    /// @return GamePermissions struct containing the contract's permissions
    function gameContractPermissions(address gameContract) external view returns (GamePermissions memory) {
        return _gameContractPermissions[gameContract];
    }

    /// @notice Gets pending VRF request ID for a user
    /// @param user The address to check
    /// @return requestId The pending request ID (0 if none)
    function getPendingRequest(address user) external view returns (uint256) {
        return _userPendingRequest[user];
    }

    /// @notice Checks if a player is retired
    /// @param playerId The ID of the player to check
    /// @return True if the player is retired, false otherwise
    function isPlayerRetired(uint32 playerId) external view returns (bool) {
        return _retiredPlayers[playerId];
    }

    /// @notice Checks if a player is immortal
    /// @param playerId The ID of the player to check
    /// @return True if the player is immortal, false otherwise
    function isPlayerImmortal(uint32 playerId) external view returns (bool) {
        return _immortalPlayers[playerId];
    }

    /// @notice Gets the number of available attribute points for a player
    /// @param playerId The player ID to check
    /// @return Number of available attribute points from leveling
    function attributePoints(uint32 playerId) external view returns (uint256) {
        return _attributePoints[playerId];
    }

    /// @notice Calculates XP required for a specific level
    /// @param level The level to calculate XP requirement for (1-9, since level 10 is max)
    /// @return XP required to reach that level from previous level
    function getXPRequiredForLevel(uint8 level) public pure returns (uint16) {
        if (level == 1) return 0; // Already at level 1
        if (level > 10) return 0; // Invalid level

        // Moderate exponential: BASE_XP * (1.5^(level-2))
        // Level 2: 100, Level 3: 150, Level 4: 225, etc.
        uint256 multiplier = 100; // Start at 100 (1.0x)
        for (uint8 i = 2; i < level; i++) {
            multiplier = (multiplier * 150) / 100; // Multiply by 1.5
        }
        return uint16((uint256(BASE_XP) * multiplier) / 100);
    }

    /// @notice Gets the status of a VRF request
    /// @param requestId The ID of the request to check
    /// @return exists Whether the request exists
    /// @return fulfilled Whether the request has been fulfilled
    /// @return owner Address that made the request
    function getRequestStatus(uint256 requestId) external view returns (bool exists, bool fulfilled, address owner) {
        PendingPlayer memory pending = _pendingPlayers[requestId];
        exists = pending.owner != address(0);
        fulfilled = pending.fulfilled;
        owner = pending.owner;
        return (exists, fulfilled, owner);
    }

    /// @notice Gets the number of active players for an address
    /// @param owner The address to check
    /// @return Number of active players
    function getActivePlayerCount(address owner) external view returns (uint256) {
        return _addressActivePlayerCount[owner];
    }

    /// @notice Gets the total player slots available for an address
    /// @param owner The address to check
    /// @return Total number of player slots (base + purchased)
    function getPlayerSlots(address owner) public view returns (uint256) {
        return BASE_PLAYER_SLOTS + _extraPlayerSlots[owner];
    }

    /// @notice Gets the skin registry contract reference
    /// @return The PlayerSkinRegistry contract instance
    function skinRegistry() public view virtual override(Fighter, IPlayer) returns (IPlayerSkinRegistry) {
        return super.skinRegistry();
    }

    function nameRegistry() public view returns (IPlayerNameRegistry) {
        return _nameRegistry;
    }

    function equipmentRequirements() public view returns (IEquipmentRequirements) {
        return _equipmentRequirements;
    }

    /// @notice Gets the PlayerTickets contract address
    /// @return The PlayerTickets contract instance
    function playerTickets() public view returns (PlayerTickets) {
        return _playerTickets;
    }

    /// @notice Gets the PlayerDataCodec contract address
    /// @return The PlayerDataCodec contract instance
    function codec() public view returns (IPlayerDataCodec) {
        return _playerDataCodec;
    }

    /// @notice Check if a player ID is valid
    /// @param playerId The ID to check
    /// @return bool True if the ID is within valid user player range
    function isValidId(uint32 playerId) public pure override(Fighter, IPlayer) returns (bool) {
        return playerId >= USER_PLAYER_START && playerId <= USER_PLAYER_END;
    }

    // State-Changing Functions
    /// @notice Initiates the creation of a new player with random stats
    /// @param useNameSetB If true, uses name set B for generation, otherwise uses set A
    /// @return requestId The VRF request ID for tracking the creation
    /// @dev Requires ETH payment of createPlayerFeeAmount. Reverts if caller has pending requests or is over max players
    function requestCreatePlayer(bool useNameSetB) external payable whenNotPaused returns (uint256 requestId) {
        if (msg.value < createPlayerFeeAmount) revert InsufficientFeeAmount();
        return _requestCreatePlayerInternal(useNameSetB, false);
    }

    /// @notice Requests creation of a new player using CREATE_PLAYER_TICKET
    /// @param useNameSetB If true, uses name set B for generation, otherwise uses set A
    /// @return requestId The VRF request ID for tracking the creation
    /// @dev Requires burning 1 CREATE_PLAYER_TICKET token. Reverts if caller has pending requests or is over max players
    function requestCreatePlayerWithTicket(bool useNameSetB) external whenNotPaused returns (uint256 requestId) {
        // Burn the ticket first (will revert if insufficient balance)
        _playerTickets.burnFrom(msg.sender, _playerTickets.CREATE_PLAYER_TICKET(), 1);
        return _requestCreatePlayerInternal(useNameSetB, true);
    }

    /// @notice Equips a skin and sets stance for a player
    /// @param playerId The ID of the player to modify
    /// @param skinIndex The index of the skin collection in the registry
    /// @param skinTokenId The token ID of the specific skin being equipped
    /// @param stance The new stance value (0=Defensive, 1=Balanced, 2=Offensive)
    /// @dev Verifies ownership and collection requirements. Reverts if player is retired
    function equipSkin(uint32 playerId, uint32 skinIndex, uint16 skinTokenId, uint8 stance)
        external
        playerExists(playerId)
        onlyPlayerOwner(playerId)
    {
        // Check if player is retired
        if (_retiredPlayers[playerId]) {
            revert PlayerIsRetired(playerId);
        }

        // Validate skin ownership through registry
        skinRegistry().validateSkinOwnership(
            Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: skinTokenId}), msg.sender
        );

        // Validate stat requirements
        skinRegistry().validateSkinRequirements(
            Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: skinTokenId}),
            _players[playerId].attributes,
            _equipmentRequirements
        );

        // Update player's skin and stance
        _players[playerId].skin.skinIndex = skinIndex;
        _players[playerId].skin.skinTokenId = skinTokenId;
        _players[playerId].stance = stance;

        emit PlayerSkinEquipped(playerId, skinIndex, skinTokenId, stance);
    }

    /// @notice Sets a player's stance
    /// @param playerId The ID of the player to modify
    /// @param stance The new stance value (0=Defensive, 1=Balanced, 2=Offensive)
    function setStance(uint32 playerId, uint8 stance) external playerExists(playerId) {
        // Check ownership
        if (_playerOwners[playerId] != msg.sender) {
            revert NotPlayerOwner();
        }

        // Check if player is retired
        if (_retiredPlayers[playerId]) {
            revert PlayerIsRetired(playerId);
        }

        _players[playerId].stance = stance;
        emit StanceUpdated(playerId, stance);
    }

    /// @notice Purchase additional player slots
    /// @dev Each purchase adds exactly SLOT_BATCH_SIZE slots for a fixed cost
    function purchasePlayerSlots() external payable {
        if (msg.value < slotBatchCost) revert InsufficientFeeAmount();
        _addPlayerSlotBatch(msg.sender, false);
    }

    /// @notice Purchase additional player slots using PLAYER_SLOT_TICKET tokens
    /// @dev Burns exactly 1 ticket to add SLOT_BATCH_SIZE slots
    function purchasePlayerSlotsWithTickets() external {
        // Burn exactly 1 ticket (will revert if insufficient balance)
        _playerTickets.burnFrom(msg.sender, _playerTickets.PLAYER_SLOT_TICKET(), 1);
        _addPlayerSlotBatch(msg.sender, true);
    }

    /// @notice Changes a player's name by burning a name change NFT
    /// @param playerId The ID of the player to update
    /// @param nameChangeTokenId The token ID of the name change NFT to burn
    function changeName(uint32 playerId, uint256 nameChangeTokenId)
        external
        playerExists(playerId)
        onlyPlayerOwner(playerId)
    {
        // Get name data from the NFT
        (uint16 firstNameIndex, uint16 surnameIndex) = _playerTickets.getNameChangeData(nameChangeTokenId);

        // Validate name indices
        if (!nameRegistry().isValidFirstNameIndex(firstNameIndex) || surnameIndex >= nameRegistry().getSurnamesLength())
        {
            revert InvalidNameIndex();
        }

        // Burn the name change NFT
        _playerTickets.burnFrom(msg.sender, nameChangeTokenId, 1);

        PlayerStats storage player = _players[playerId];
        player.name.firstNameIndex = firstNameIndex;
        player.name.surnameIndex = surnameIndex;

        emit PlayerNameUpdated(playerId, firstNameIndex, surnameIndex);
    }

    /// @notice Swaps attributes between two player attributes by burning an attribute swap ticket
    /// @param playerId The ID of the player to update
    /// @param decreaseAttribute The attribute to decrease
    /// @param increaseAttribute The attribute to increase
    /// @dev Requires burning an attribute swap ticket. Reverts if player doesn't exist or swap is invalid
    function swapAttributes(uint32 playerId, Attribute decreaseAttribute, Attribute increaseAttribute)
        external
        playerExists(playerId)
        onlyPlayerOwner(playerId)
    {
        if (decreaseAttribute == increaseAttribute) revert InvalidAttributeSwap();

        PlayerStats storage player = _players[playerId];

        uint8 decreaseValue = _getAttributeValue(player, decreaseAttribute);
        uint8 increaseValue = _getAttributeValue(player, increaseAttribute);

        if (decreaseValue <= MIN_STAT || increaseValue >= MAX_STAT) {
            revert InvalidAttributeSwap();
        }

        // Burn attribute swap NFT ticket
        _playerTickets.burnFrom(msg.sender, _playerTickets.ATTRIBUTE_SWAP_TICKET(), 1);

        _setAttributeValue(player, decreaseAttribute, decreaseValue - 1);
        _setAttributeValue(player, increaseAttribute, increaseValue + 1);

        emit PlayerAttributesSwapped(
            playerId,
            decreaseAttribute,
            increaseAttribute,
            _getAttributeValue(player, decreaseAttribute),
            _getAttributeValue(player, increaseAttribute)
        );
    }

    /// @notice Uses an attribute point earned from leveling to increase a player's attribute by 1
    /// @param playerId The ID of the player to update
    /// @param attribute The attribute to increase
    /// @dev Uses attribute points earned from leveling up, allows stats to go above 21 (max 25)
    function useAttributePoint(uint32 playerId, Attribute attribute)
        external
        playerExists(playerId)
        onlyPlayerOwner(playerId)
    {
        // Check if this player has available attribute points
        if (_attributePoints[playerId] == 0) {
            revert InsufficientCharges();
        }

        PlayerStats storage player = _players[playerId];
        uint8 currentValue = _getAttributeValue(player, attribute);

        // Check if attribute is already at maximum for leveled players
        if (currentValue >= MAX_LEVELING_STAT) {
            revert InvalidAttributeSwap(); // Reuse this error for simplicity
        }

        // Consume one attribute point from THIS player
        _attributePoints[playerId]--;

        // Increase the attribute
        _setAttributeValue(player, attribute, currentValue + 1);

        emit PlayerAttributePointUsed(playerId, attribute, currentValue + 1, _attributePoints[playerId]);
    }

    /// @notice Sets weapon specialization for a player
    /// @param playerId The ID of the player
    /// @param weaponClass The weapon class to specialize in (0-6, 255 = none)
    /// @dev Free if current specialization is 255 (none), otherwise requires burning a respec ticket
    /// @dev Requires player to be level 10 or higher
    function setWeaponSpecialization(uint32 playerId, uint8 weaponClass)
        external
        playerExists(playerId)
        onlyPlayerOwner(playerId)
    {
        // Check player level requirement (level 10 minimum)
        if (_players[playerId].level < 10) {
            revert WeaponSpecializationLevelTooLow();
        }

        // Get current specialization
        uint8 currentSpecialization = _players[playerId].weaponSpecialization;

        // Effects: Update state first
        _players[playerId].weaponSpecialization = weaponClass;

        // Interactions: Burn ticket if this was a respec (not initial free change)
        if (currentSpecialization != 255) {
            _playerTickets.burnFrom(msg.sender, _playerTickets.WEAPON_SPECIALIZATION_TICKET(), 1);
        }

        emit PlayerWeaponSpecializationChanged(playerId, weaponClass);
    }

    /// @notice Sets armor specialization for a player
    /// @param playerId The ID of the player
    /// @param armorType The armor type to specialize in (255 = none)
    /// @dev Free if current specialization is 255 (none), otherwise requires burning a respec ticket
    /// @dev Requires player to be level 5 or higher
    function setArmorSpecialization(uint32 playerId, uint8 armorType)
        external
        playerExists(playerId)
        onlyPlayerOwner(playerId)
    {
        // Check player level requirement (level 5 minimum)
        if (_players[playerId].level < 5) {
            revert ArmorSpecializationLevelTooLow();
        }

        // Get current specialization
        uint8 currentSpecialization = _players[playerId].armorSpecialization;

        // Effects: Update state first
        _players[playerId].armorSpecialization = armorType;

        // Interactions: Burn ticket if this was a respec (not initial free change)
        if (currentSpecialization != 255) {
            _playerTickets.burnFrom(msg.sender, _playerTickets.ARMOR_SPECIALIZATION_TICKET(), 1);
        }

        emit PlayerArmorSpecializationChanged(playerId, armorType);
    }

    /// @notice Retires a player owned by the caller
    /// @param playerId The ID of the player to retire
    /// @dev Retired players cannot be used in games but can still be viewed
    function retireOwnPlayer(uint32 playerId) external playerExists(playerId) {
        // Check caller owns it
        if (_playerOwners[playerId] != msg.sender) revert NotPlayerOwner();

        // Prevent double retirement
        if (_retiredPlayers[playerId]) revert PlayerIsRetired(playerId);

        // Mark as retired and decrease active count
        _retiredPlayers[playerId] = true;
        _addressActivePlayerCount[msg.sender]--;

        emit PlayerRetired(playerId, msg.sender, true);
    }

    // Game Contract Functions (hasPermission)
    /// @notice Increments the win count for a player
    /// @param playerId The ID of the player to update
    /// @param season The season to record the win in
    /// @dev Requires RECORD permission. Reverts if player doesn't exist
    function incrementWins(uint32 playerId, uint256 season)
        external
        hasPermission(IPlayer.GamePermission.RECORD)
        playerExists(playerId)
    {
        // Update both seasonal and lifetime records
        lifetimeRecords[playerId].wins++;
        seasonalRecords[playerId][season].wins++;

        // Emit atomic event for this specific win
        emit PlayerWinRecorded(playerId, season);
    }

    /// @notice Increments the loss count for a player
    /// @param playerId The ID of the player to update
    /// @param season The season to record the loss in
    /// @dev Requires RECORD permission. Reverts if player doesn't exist
    function incrementLosses(uint32 playerId, uint256 season)
        external
        hasPermission(IPlayer.GamePermission.RECORD)
        playerExists(playerId)
    {
        // Update both seasonal and lifetime records
        lifetimeRecords[playerId].losses++;
        seasonalRecords[playerId][season].losses++;

        // Emit atomic event for this specific loss
        emit PlayerLossRecorded(playerId, season);
    }

    /// @notice Increments the kill count for a player
    /// @param playerId The ID of the player to update
    /// @param season The season to record the kill in
    /// @dev Requires RECORD permission. Reverts if player doesn't exist
    function incrementKills(uint32 playerId, uint256 season)
        external
        hasPermission(IPlayer.GamePermission.RECORD)
        playerExists(playerId)
    {
        // Update both seasonal and lifetime records
        lifetimeRecords[playerId].kills++;
        seasonalRecords[playerId][season].kills++;

        // Emit atomic event for this specific kill
        emit PlayerKillRecorded(playerId, season);
    }

    /// @notice Sets the retirement status of a player
    /// @param playerId The ID of the player to update
    /// @param retired The new retirement status
    /// @dev Requires RETIRE permission. Reverts if player doesn't exist
    function setPlayerRetired(uint32 playerId, bool retired)
        external
        hasPermission(IPlayer.GamePermission.RETIRE)
        playerExists(playerId)
    {
        bool wasRetired = _retiredPlayers[playerId];
        address owner = _playerOwners[playerId];

        // Only update if status is actually changing
        if (wasRetired != retired) {
            if (retired) {
                _addressActivePlayerCount[owner]--;
            } else {
                _addressActivePlayerCount[owner]++;
            }
        }

        _retiredPlayers[playerId] = retired;
        emit PlayerRetired(playerId, msg.sender, retired);
    }

    /// @notice Sets the immortality status of a player
    /// @param playerId The ID of the player to update
    /// @param immortal The new immortality status
    /// @dev Requires IMMORTAL permission. Reverts if player doesn't exist
    function setPlayerImmortal(uint32 playerId, bool immortal)
        external
        hasPermission(IPlayer.GamePermission.IMMORTAL)
        playerExists(playerId)
    {
        _immortalPlayers[playerId] = immortal;
        emit PlayerImmortalityChanged(playerId, msg.sender, immortal);
    }

    /// @notice Awards experience points to a player and handles level ups
    /// @param playerId The ID of the player to award experience to
    /// @param xpAmount The amount of experience to award
    /// @dev Requires EXPERIENCE permission. Automatically handles level ups and attribute point awards
    function awardExperience(uint32 playerId, uint16 xpAmount)
        external
        hasPermission(IPlayer.GamePermission.EXPERIENCE)
        playerExists(playerId)
    {
        PlayerStats storage player = _players[playerId];
        address owner = _playerOwners[playerId];

        // Add experience
        player.currentXP += xpAmount;
        emit ExperienceGained(playerId, xpAmount, player.currentXP);

        // Check for level ups (max level 10)
        while (player.level < 10) {
            uint16 xpRequired = getXPRequiredForLevel(player.level + 1);
            if (player.currentXP < xpRequired) break;

            // Level up!
            player.currentXP -= xpRequired;
            player.level++;

            // Award attribute points to this player
            uint8 attributePointsAwarded = 1;
            _attributePoints[playerId] += attributePointsAwarded;

            emit PlayerLevelUp(playerId, player.level, attributePointsAwarded);
            emit AttributePointAwarded(owner, _attributePoints[playerId]);
        }
    }

    /// @notice Allows a user to recover ETH from a timed-out player creation request
    /// @dev Checks if the request has exceeded the timeout period before allowing recovery
    function recoverTimedOutRequest() external {
        uint256 requestId = _userPendingRequest[msg.sender];
        if (requestId == 0) revert NoPendingRequest();

        PendingPlayer storage request = _pendingPlayers[requestId];
        if (request.owner != msg.sender) revert NotPlayerOwner();
        if (request.fulfilled) revert RequestAlreadyFulfilled();
        if (block.timestamp <= request.timestamp + vrfRequestTimeout) revert VrfRequestNotTimedOut();

        // Effects - clear request data before transfer
        delete _pendingPlayers[requestId];
        delete _userPendingRequest[msg.sender];

        // Interactions - transfer ETH after state changes
        SafeTransferLib.safeTransferETH(msg.sender, createPlayerFeeAmount);

        emit RequestRecovered(requestId, msg.sender, createPlayerFeeAmount, false, block.timestamp);
    }

    // Admin Functions

    /// @notice Updates the fee required to create a new player
    /// @param newFeeAmount The new fee amount in ETH
    function setCreatePlayerFeeAmount(uint256 newFeeAmount) external onlyOwner {
        uint256 oldFee = createPlayerFeeAmount;
        createPlayerFeeAmount = newFeeAmount;
        emit CreatePlayerFeeUpdated(oldFee, newFeeAmount);
    }

    /// @notice Withdraws all accumulated fees to the owner address
    function withdrawFees() external onlyOwner {
        SafeTransferLib.safeTransferETH(owner(), address(this).balance);
    }

    /// @notice Recovers any ERC20 tokens accidentally sent to the contract
    /// @param token The address of the ERC20 token to recover
    /// @param amount The amount of tokens to recover
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        SafeTransferLib.safeTransfer(token, owner(), amount);
    }

    /// @notice Emergency function to clear pending VRF requests for an address
    /// @param user The address whose pending requests should be cleared
    /// @param refund Whether to refund the player creation fee to the user
    /// @dev Use with caution - will invalidate any pending player creation requests
    function clearPendingRequestsForAddress(address user, bool refund) external onlyOwner {
        uint256 requestId = _userPendingRequest[user];
        if (requestId != 0) {
            // Effects - clear request data first
            delete _pendingPlayers[requestId];
            delete _userPendingRequest[user];

            // Interactions - optionally refund ETH
            if (refund) {
                SafeTransferLib.safeTransferETH(user, createPlayerFeeAmount);
            }

            emit RequestRecovered(requestId, user, refund ? createPlayerFeeAmount : 0, true, block.timestamp);
        }
    }

    /// @notice Sets the contract's paused state
    /// @param paused The new paused state
    function setPaused(bool paused) external onlyOwner {
        isPaused = paused;
        emit PausedStateChanged(paused);
    }

    /// @notice Updates permissions for a game contract
    /// @param gameContract The address of the game contract
    /// @param permissions The new permissions to set
    function setGameContractPermission(address gameContract, IPlayer.GamePermissions memory permissions)
        external
        onlyOwner
    {
        _gameContractPermissions[gameContract] = permissions;
        emit GameContractPermissionsUpdated(gameContract, permissions);
    }

    /// @notice Updates the cost for purchasing additional player slots
    /// @param newCost The new cost in ETH for each slot batch
    function setSlotBatchCost(uint256 newCost) external onlyOwner {
        uint256 oldCost = slotBatchCost;
        slotBatchCost = newCost;
        emit SlotBatchCostUpdated(oldCost, newCost);
    }

    /// @notice Sets the contract address for equipment requirements validation
    /// @param newAddress The address of the new equipment requirements contract
    /// @dev Used to update equipment requirements logic if needed
    function setEquipmentRequirements(address newAddress) external onlyOwner {
        if (newAddress == address(0)) revert BadZeroAddress();
        address oldAddress = address(_equipmentRequirements);
        _equipmentRequirements = IEquipmentRequirements(newAddress);
        emit EquipmentRequirementsUpdated(oldAddress, newAddress);
    }

    /// @notice Updates the timeout period for VRF requests
    /// @param newValue The new timeout period in seconds
    function setVrfRequestTimeout(uint256 newValue) external onlyOwner {
        if (newValue == 0) revert ValueMustBePositive();
        emit VrfRequestTimeoutUpdated(vrfRequestTimeout, newValue);
        vrfRequestTimeout = newValue;
    }

    /// @notice Updates the season length in months
    /// @param months The new season length (1-12 months)
    /// @dev Only callable by contract owner. Takes effect on next season transition.
    function setSeasonLength(uint256 months) external onlyOwner {
        require(months > 0 && months <= 12, "Invalid season length");

        uint256 oldLength = seasonLengthMonths;
        seasonLengthMonths = months;

        // Recalculate next season start with new length
        nextSeasonStart = getNextSeasonStartPST();

        emit SeasonLengthUpdated(oldLength, months);
    }

    /// @notice Updates VRF configuration
    /// @param newKeyHash Gas lane key hash (use Base 2 gwei or 30 gwei lane)
    /// @param newCallbackGasLimit Gas limit for callback function (max 2,500,000)
    /// @param newRequestConfirmations Number of confirmations to wait
    /// @dev Only owner can update configuration
    function setVRFConfig(bytes32 newKeyHash, uint32 newCallbackGasLimit, uint16 newRequestConfirmations)
        external
        onlyOwner
    {
        if (newKeyHash == bytes32(0)) revert BadZeroAddress();
        if (newCallbackGasLimit == 0 || newCallbackGasLimit > 2500000) revert ValueMustBePositive();
        if (newRequestConfirmations > 200) revert ValueMustBePositive();

        keyHash = newKeyHash;
        callbackGasLimit = newCallbackGasLimit;
        requestConfirmations = newRequestConfirmations;

        emit VRFConfigUpdated(newKeyHash, newCallbackGasLimit, newRequestConfirmations);
    }

    /// @notice Updates the Chainlink VRF subscription ID
    /// @param newSubscriptionId New subscription ID to use for funding VRF requests
    /// @dev Only owner can update subscription ID
    function setSubscriptionId(uint256 newSubscriptionId) external onlyOwner {
        if (newSubscriptionId == 0) revert ValueMustBePositive();

        uint256 oldSubscriptionId = subscriptionId;
        subscriptionId = newSubscriptionId;

        emit SubscriptionIdUpdated(oldSubscriptionId, newSubscriptionId);
    }

    //==============================================================//
    //                    SEASON FUNCTIONS                          //
    //==============================================================//
    /// @notice Forces season update check and returns current season
    /// @return The current season ID (auto-updates if season transition is due)
    /// @dev Game contracts should call this at tournament start for consistent season tracking
    function forceCurrentSeason() external returns (uint256) {
        if (block.timestamp >= nextSeasonStart) {
            currentSeason++;
            seasons[currentSeason] = Season({startTimestamp: block.timestamp, startBlock: block.number});

            // Calculate next season start
            nextSeasonStart = getNextSeasonStartPST();

            emit SeasonStarted(currentSeason, block.timestamp, block.number);
        }
        return currentSeason;
    }

    /// @notice Calculates the timestamp for the first day of next season at midnight PST
    /// @return Timestamp for next season start
    function getNextSeasonStartPST() public view returns (uint256) {
        // Adjust current time to UTC-8 by adding 8 hours
        uint256 adjustedTime = block.timestamp + 8 hours;

        // Get current date components in UTC-8
        (uint256 year, uint256 month, /* uint256 day */ ) = BokkyPooBahsDateTimeLibrary.timestampToDate(adjustedTime);

        // Add the configured number of months
        month += seasonLengthMonths;
        while (month > 12) {
            month -= 12;
            year += 1;
        }

        // Create timestamp for 1st of target month at midnight UTC-8
        uint256 firstOfMonthUTC = BokkyPooBahsDateTimeLibrary.timestampFromDate(year, month, 1);

        // Subtract 8 hours to get the actual UTC timestamp
        return firstOfMonthUTC - 8 hours;
    }

    /// @notice Gets the current season record for a player
    /// @param playerId The ID of the player
    /// @return record The player's record for the current season
    function getCurrentSeasonRecord(uint32 playerId) external view returns (Fighter.Record memory) {
        return seasonalRecords[playerId][currentSeason];
    }

    /// @notice Gets the lifetime record for a player
    /// @param playerId The ID of the player
    /// @return record The player's lifetime record (all seasons combined)
    function getLifetimeRecord(uint32 playerId) external view returns (Fighter.Record memory) {
        return lifetimeRecords[playerId];
    }

    /// @notice Gets the record for a player in a specific season
    /// @param playerId The ID of the player
    /// @param seasonId The season ID to get the record for
    /// @return record The player's record for the specified season
    function getSeasonRecord(uint32 playerId, uint256 seasonId) external view returns (Fighter.Record memory) {
        return seasonalRecords[playerId][seasonId];
    }

    //==============================================================//
    //                    INTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Internal method to validate caller has required game permission
    /// @param permission The specific permission being checked
    /// @dev Reverts with NoPermission if the caller lacks the required permission
    function _checkPermission(IPlayer.GamePermission permission) internal view {
        IPlayer.GamePermissions storage perms = _gameContractPermissions[msg.sender];
        if (permission == IPlayer.GamePermission.RECORD && !perms.record) revert NoPermission();
        if (permission == IPlayer.GamePermission.RETIRE && !perms.retire) revert NoPermission();
        if (permission == IPlayer.GamePermission.IMMORTAL && !perms.immortal) revert NoPermission();
        if (permission == IPlayer.GamePermission.EXPERIENCE && !perms.experience) revert NoPermission();
    }

    /// @notice Internal method to validate player exists and is within valid range
    /// @param playerId The ID of the player to check
    /// @dev Reverts with InvalidPlayerRange or PlayerDoesNotExist if validation fails
    function _checkPlayerExists(uint32 playerId) internal view {
        if (!isValidId(playerId)) {
            revert InvalidPlayerRange();
        }
        if (_players[playerId].attributes.strength == 0) {
            revert PlayerDoesNotExist(playerId);
        }
    }

    // VRF Implementation
    /// @notice Requests randomness from Chainlink VRF using subscription
    /// @return requestId The VRF request ID
    /// @dev Uses subscription-based funding - charges actual gas used after fulfillment
    function _requestRandomness() internal returns (uint256 requestId) {
        // Request randomness using subscription funding
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: true // Use native ETH from subscription
                    })
                )
            })
        );

        return requestId;
    }

    /// @notice Handles the fulfillment of VRF requests for player creation
    /// @param requestId The ID of the request being fulfilled
    /// @param randomWords Array of random values (we only use the first one)
    /// @dev Required override from ChainlinkVRFConsumerBase. Reverts if request is invalid or already fulfilled
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // Checks
        PendingPlayer memory pending = _pendingPlayers[requestId];
        if (pending.owner == address(0)) revert InvalidRequestID();
        if (pending.fulfilled) revert RequestAlreadyFulfilled();

        // Effects
        _pendingPlayers[requestId].fulfilled = true;
        uint256 randomness = randomWords[0];
        uint256 combinedSeed = uint256(keccak256(abi.encodePacked(randomness, requestId, pending.owner)));

        // Check player slot limit
        if (_addressActivePlayerCount[pending.owner] >= getPlayerSlots(pending.owner)) revert TooManyPlayers();

        // Generate player data using internal function
        IPlayer.PlayerStats memory stats = _generatePlayerData(combinedSeed, pending.useNameSetB);

        // Handle state changes in Player contract
        uint32 playerId = nextPlayerId++;
        _players[playerId] = stats;
        _playerOwners[playerId] = pending.owner;
        _addressActivePlayerCount[pending.owner]++;

        // Remove from user's pending requests and cleanup
        _removeFromPendingRequests(pending.owner, requestId);
        delete _pendingPlayers[requestId];

        // Emit the combined event with all data
        emit PlayerCreationComplete(
            requestId,
            playerId,
            pending.owner,
            randomness,
            stats.name.firstNameIndex,
            stats.name.surnameIndex,
            stats.attributes.strength,
            stats.attributes.constitution,
            stats.attributes.size,
            stats.attributes.agility,
            stats.attributes.stamina,
            stats.attributes.luck,
            pending.paidWithTicket
        );
    }

    /// @notice Generates complete player data from random seed
    /// @param randomSeed Random seed for stat and name generation
    /// @param useNameSetB Whether to use name set B for first name generation
    /// @return stats Complete player stats struct
    /// @dev Internal version of PlayerCreation.generatePlayerData merged for contract size optimization
    function _generatePlayerData(uint256 randomSeed, bool useNameSetB)
        internal
        view
        returns (IPlayer.PlayerStats memory stats)
    {
        // Initialize base stats array with minimum values
        uint8[6] memory statArray = [3, 3, 3, 3, 3, 3];
        uint256 remainingPoints = 54; // 72 total - (6 * 3 minimum)

        // Distribute remaining points across stats
        uint256 order = uint256(keccak256(abi.encodePacked(randomSeed, "order")));

        unchecked {
            // Handle all 6 stats
            for (uint256 i; i < 6; ++i) {
                // Select random stat index and update order
                uint256 statIndex = order.uniform(6 - i);
                order = uint256(keccak256(abi.encodePacked(order)));

                // Calculate available points for this stat
                uint256 pointsNeededForRemaining = (5 - i) * 3; // Ensure minimum 3 points for each remaining stat
                uint256 availablePoints =
                    remainingPoints > pointsNeededForRemaining ? remainingPoints - pointsNeededForRemaining : 0;

                // Add extra entropy and make high points rarer
                uint256 chance = randomSeed.uniform(100);
                randomSeed = uint256(keccak256(abi.encodePacked(randomSeed, "chance")));

                uint256 pointsCap = chance < 50
                    ? 9 // 0-49: normal roll (3+9=12)
                    : chance < 80
                        ? 12 // 50-79: medium roll (3+12=15)
                        : chance < 95
                            ? 15 // 80-94: high roll (3+15=18)
                            : 18; // 95-99: max roll (3+18=21)

                // Add random points to selected stat using the cap
                uint256 pointsToAdd = randomSeed.uniform(_min(availablePoints, pointsCap) + 1);
                randomSeed = uint256(keccak256(abi.encodePacked(randomSeed)));

                // Update stat and remaining points
                statArray[statIndex] += uint8(pointsToAdd);
                remainingPoints -= pointsToAdd;

                // Swap with last unprocessed stat to avoid reselecting
                if (statIndex != 5 - i) {
                    uint8 temp = statArray[statIndex];
                    statArray[statIndex] = statArray[5 - i];
                    statArray[5 - i] = temp;
                }
            }
        }

        // Generate name indices based on player preference
        uint16 firstNameIndex;
        if (useNameSetB) {
            firstNameIndex = uint16(randomSeed.uniform(_nameRegistry.getNameSetBLength()));
        } else {
            firstNameIndex =
                uint16(randomSeed.uniform(_nameRegistry.getNameSetALength())) + _nameRegistry.getSetAStart();
        }

        uint16 surnameIndex = uint16(randomSeed.uniform(_nameRegistry.getSurnamesLength()));

        // Create stats struct
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({
                strength: statArray[0],
                constitution: statArray[1],
                size: statArray[2],
                agility: statArray[3],
                stamina: statArray[4],
                luck: statArray[5]
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            name: IPlayer.PlayerName({firstNameIndex: firstNameIndex, surnameIndex: surnameIndex}),
            stance: 1, // Initialize to BALANCED stance
            level: 1, // Start at level 1
            currentXP: 0, // Start with 0 XP
            weaponSpecialization: 255, // No specialization
            armorSpecialization: 255 // No specialization
        });

        // Validate and fix if necessary
        if (!_validateStats(stats)) {
            stats = _fixStats(stats, randomSeed);
        }

        return stats;
    }

    //==============================================================//
    //                    PRIVATE FUNCTIONS                         //
    //==============================================================//
    // Pure helpers
    /// @notice Returns the minimum of two numbers
    /// @param a First number to compare
    /// @param b Second number to compare
    /// @return The smaller of the two numbers
    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice Validates that player stats are within allowed ranges and total correctly
    /// @param player The player stats to validate
    /// @return True if stats are valid, false otherwise
    /// @dev Checks each stat is between MIN_STAT and MAX_STAT and total equals TOTAL_STATS
    function _validateStats(IPlayer.PlayerStats memory player) private pure returns (bool) {
        // Check stat bounds
        if (player.attributes.strength < MIN_STAT || player.attributes.strength > MAX_STAT) return false;
        if (player.attributes.constitution < MIN_STAT || player.attributes.constitution > MAX_STAT) return false;
        if (player.attributes.size < MIN_STAT || player.attributes.size > MAX_STAT) return false;
        if (player.attributes.agility < MIN_STAT || player.attributes.agility > MAX_STAT) return false;
        if (player.attributes.stamina < MIN_STAT || player.attributes.stamina > MAX_STAT) return false;
        if (player.attributes.luck < MIN_STAT || player.attributes.luck > MAX_STAT) return false;

        // Calculate total stat points
        uint256 total = uint256(player.attributes.strength) + uint256(player.attributes.constitution)
            + uint256(player.attributes.size) + uint256(player.attributes.agility) + uint256(player.attributes.stamina)
            + uint256(player.attributes.luck);

        // Total should be exactly 72 (6 stats * 3 minimum = 18, plus 54 points to distribute)
        return total == TOTAL_STATS;
    }

    /// @notice Adjusts invalid player stats to meet requirements
    /// @param player The player stats to fix
    /// @param seed Random seed for stat adjustment
    /// @return Fixed player stats that meet all requirements
    /// @dev Ensures stats are within bounds and total exactly TOTAL_STATS
    function _fixStats(IPlayer.PlayerStats memory player, uint256 seed)
        private
        pure
        returns (IPlayer.PlayerStats memory)
    {
        uint16 total = uint16(player.attributes.strength) + uint16(player.attributes.constitution)
            + uint16(player.attributes.size) + uint16(player.attributes.agility) + uint16(player.attributes.stamina)
            + uint16(player.attributes.luck);

        // First ensure all stats are within 3-21 range
        uint8[6] memory stats = [
            player.attributes.strength,
            player.attributes.constitution,
            player.attributes.size,
            player.attributes.agility,
            player.attributes.stamina,
            player.attributes.luck
        ];

        for (uint256 i = 0; i < 6; i++) {
            if (stats[i] < 3) {
                total += (3 - stats[i]);
                stats[i] = 3;
            } else if (stats[i] > 21) {
                total -= (stats[i] - 21);
                stats[i] = 21;
            }
        }

        // Now adjust total to 72 if needed
        while (total != 72) {
            seed = uint256(keccak256(abi.encodePacked(seed)));

            if (total < 72) {
                uint256 statIndex = seed.uniform(6);
                if (stats[statIndex] < 21) {
                    stats[statIndex] += 1;
                    total += 1;
                }
            } else {
                seed = uint256(keccak256(abi.encodePacked(seed)));
                uint256 statIndex = seed.uniform(6);
                if (stats[statIndex] > 3) {
                    stats[statIndex] -= 1;
                    total -= 1;
                }
            }
        }

        return IPlayer.PlayerStats({
            attributes: Fighter.Attributes({
                strength: stats[0],
                constitution: stats[1],
                size: stats[2],
                agility: stats[3],
                stamina: stats[4],
                luck: stats[5]
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            name: IPlayer.PlayerName({firstNameIndex: player.name.firstNameIndex, surnameIndex: player.name.surnameIndex}),
            stance: 1, // Initialize to BALANCED stance
            level: player.level, // Preserve level
            currentXP: player.currentXP, // Preserve XP
            weaponSpecialization: player.weaponSpecialization, // Preserve specialization
            armorSpecialization: player.armorSpecialization // Preserve specialization
        });
    }

    // State-modifying helpers

    /// @notice Internal function to handle common player creation logic
    /// @param useNameSetB If true, uses name set B for generation, otherwise uses set A
    /// @param paidWithTicket Whether the player was paid for with a ticket (true) or ETH (false)
    /// @return requestId The VRF request ID for tracking the creation
    /// @dev Shared logic for both ETH and ticket-based player creation
    function _requestCreatePlayerInternal(bool useNameSetB, bool paidWithTicket) private returns (uint256 requestId) {
        if (_addressActivePlayerCount[msg.sender] >= getPlayerSlots(msg.sender)) revert TooManyPlayers();
        if (_userPendingRequest[msg.sender] != 0) revert PendingRequestExists();

        // Effects - Get requestId first since it's deterministic and can't fail
        requestId = _requestRandomness();
        _pendingPlayers[requestId] = PendingPlayer({
            owner: msg.sender,
            useNameSetB: useNameSetB,
            fulfilled: false,
            timestamp: uint64(block.timestamp),
            paidWithTicket: paidWithTicket
        });
        _userPendingRequest[msg.sender] = requestId;

        emit PlayerCreationRequested(requestId, msg.sender, paidWithTicket);
    }

    /// @notice Removes a request ID from a user's pending requests
    /// @param user The address whose request is being removed
    /// @param requestId The ID of the request to remove
    function _removeFromPendingRequests(address user, uint256 requestId) private {
        if (_userPendingRequest[user] == requestId) {
            delete _userPendingRequest[user];
        }
    }

    /// @notice Internal function to add exactly one batch of player slots
    /// @param user The address receiving the slots
    /// @param paidWithTicket Whether the slots were paid for with a ticket (true) or ETH (false)
    function _addPlayerSlotBatch(address user, bool paidWithTicket) internal {
        // Calculate current total slots
        uint8 currentExtraSlots = _extraPlayerSlots[user];
        uint8 currentTotalSlots = BASE_PLAYER_SLOTS + currentExtraSlots;

        // Simple check - either the full batch fits or we revert
        if (currentTotalSlots + SLOT_BATCH_SIZE > MAX_TOTAL_SLOTS) {
            revert TooManyPlayers();
        }

        // Update state - always add exactly SLOT_BATCH_SIZE
        _extraPlayerSlots[user] += SLOT_BATCH_SIZE;

        // Emit event
        emit PlayerSlotsPurchased(user, currentTotalSlots + SLOT_BATCH_SIZE, paidWithTicket);
    }

    /// @notice Gets the current value of a specified attribute
    /// @param player The player stats storage reference
    /// @param attr The attribute to get
    /// @return The current value of the attribute
    function _getAttributeValue(PlayerStats storage player, Attribute attr) internal view returns (uint8) {
        if (attr == Attribute.STRENGTH) return player.attributes.strength;
        if (attr == Attribute.CONSTITUTION) return player.attributes.constitution;
        if (attr == Attribute.SIZE) return player.attributes.size;
        if (attr == Attribute.AGILITY) return player.attributes.agility;
        if (attr == Attribute.STAMINA) return player.attributes.stamina;
        return player.attributes.luck;
    }

    /// @notice Sets the value of a specified attribute
    /// @param player The player stats storage reference
    /// @param attr The attribute to set
    /// @param value The new value for the attribute
    function _setAttributeValue(PlayerStats storage player, Attribute attr, uint8 value) internal {
        if (attr == Attribute.STRENGTH) player.attributes.strength = value;
        else if (attr == Attribute.CONSTITUTION) player.attributes.constitution = value;
        else if (attr == Attribute.SIZE) player.attributes.size = value;
        else if (attr == Attribute.AGILITY) player.attributes.agility = value;
        else if (attr == Attribute.STAMINA) player.attributes.stamina = value;
        else player.attributes.luck = value;
    }

    //==============================================================//
    //                    FALLBACK FUNCTIONS                        //
    //==============================================================//
    /// @notice Allows contract to receive ETH for VRF funding
    receive() external payable {}
}

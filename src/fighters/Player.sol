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
import "solmate/src/auth/Owned.sol";
import "solmate/src/utils/SafeTransferLib.sol";
import "vrf-contracts/contracts/GelatoVRFConsumerBase.sol";
// Internal imports
import "../interfaces/fighters/IPlayer.sol";
import "../interfaces/fighters/registries/names/IPlayerNameRegistry.sol";
import "../interfaces/game/engine/IEquipmentRequirements.sol";
import "../nft/PlayerTickets.sol";
import "./Fighter.sol";
import "../interfaces/fighters/IPlayerCreation.sol";
import "../interfaces/fighters/IPlayerDataCodec.sol";
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

//==============================================================//
//                         HEAVY HELMS                          //
//                           PLAYER                             //
//==============================================================//
/// @title Player Contract for Heavy Helms
/// @notice Manages player creation, attributes, skins, and persistent player data
/// @dev Integrates with VRF for random stat generation and interfaces with skin/name registries
contract Player is IPlayer, Owned, GelatoVRFConsumerBase, Fighter {
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
    struct PendingPlayer {
        address owner;
        bool useNameSetB;
        bool fulfilled;
        uint64 timestamp;
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
    uint8 public constant BASE_PLAYER_SLOTS = 5;
    /// @notice Maximum total player slots an address can have (base + purchased)
    uint8 private constant MAX_TOTAL_SLOTS = 200;
    /// @notice Starting ID for user-created players (1-2000 reserved for default characters)
    uint32 private constant USER_PLAYER_START = 10001;
    /// @notice End ID for user-created players (no upper limit for user players)
    uint32 private constant USER_PLAYER_END = type(uint32).max;
    /// @notice Timeout period in seconds after which a player creation request can be recovered
    uint256 public vrfRequestTimeout = 4 hours;
    /// @notice Base experience points for first level up
    uint16 private constant BASE_XP = 100;

    // Configuration
    /// @notice Fee amount in ETH required to create a new player
    uint256 public createPlayerFeeAmount = 0.001 ether;
    /// @notice Cost in ETH for each additional slot batch (5 slots) - fixed cost
    uint256 public slotBatchCost = 0.005 ether;
    /// @notice Number of slots added per batch purchase
    uint8 public immutable SLOT_BATCH_SIZE = 5;
    /// @notice Whether the contract is paused (prevents new player creation)
    bool public isPaused;

    // Contract References
    /// @notice Registry contract for managing player name sets and validation
    IPlayerNameRegistry private immutable _nameRegistry;
    /// @notice Interface for equipment requirements validation
    IEquipmentRequirements private _equipmentRequirements;
    /// @notice PlayerTickets contract for burnable NFT tickets
    PlayerTickets private immutable _playerTickets;
    /// @notice PlayerCreation contract for generating player stats and names
    IPlayerCreation private immutable _playerCreation;
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
    /// @notice Maps address to their attribute swap charges
    mapping(address => uint256) private _attributeSwapCharges;
    /// @notice Maps player ID to their available attribute points from leveling
    mapping(uint32 => uint256) private _attributePoints;

    // VRF Request tracking
    /// @notice Address of the Gelato VRF operator
    address private _operatorAddress;
    /// @notice Maps VRF request IDs to their pending player creation details
    mapping(uint256 => PendingPlayer) private _pendingPlayers;
    /// @notice Maps user address to their current pending request ID
    /// @dev 0 indicates no pending request, >0 is the active request ID
    mapping(address => uint256) private _userPendingRequest;

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
        uint8 luck
    );

    /// @notice Emitted when a new player creation is requested
    /// @param requestId The VRF request ID
    /// @param requester The address requesting the player creation
    event PlayerCreationRequested(uint256 indexed requestId, address indexed requester);

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
    /// @param slotsAdded Number of new slots purchased
    /// @param totalSlots New total slots for the user
    /// @param amountPaid Amount of ETH paid for the slots
    event PlayerSlotsPurchased(address indexed user, uint8 slotsAdded, uint8 totalSlots, uint256 amountPaid);

    /// @notice Emitted when a game contract's permissions are updated
    /// @param gameContract Address of the game contract
    /// @param permissions New permissions struct
    event GameContractPermissionsUpdated(address indexed gameContract, GamePermissions permissions);

    /// @notice Emitted when a player's win/loss record is updated
    /// @param playerId The ID of the player
    /// @param wins Current win count
    /// @param losses Current loss count
    event PlayerWinLossUpdated(uint32 indexed playerId, uint16 wins, uint16 losses);

    /// @notice Emitted when a player's kill count is updated
    /// @param playerId The ID of the player
    /// @param kills Current kill count
    event PlayerKillUpdated(uint32 indexed playerId, uint16 kills);

    /// @notice Emitted when a player's name is changed
    /// @param playerId The ID of the player
    /// @param firstNameIndex New first name index
    /// @param surnameIndex New surname index
    event PlayerNameUpdated(uint32 indexed playerId, uint16 firstNameIndex, uint16 surnameIndex);

    /// @notice Emitted when a name change charge is awarded
    /// @param to Address receiving the charge
    /// @param totalCharges Total number of name change charges available
    event NameChangeAwarded(address indexed to, uint256 totalCharges);

    /// @notice Emitted when an attribute swap charge is awarded
    /// @param to Address receiving the charge
    /// @param totalCharges Total number of attribute swap charges available
    event AttributeSwapAwarded(address indexed to, uint256 totalCharges);

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
    /// @param weaponType The new weapon specialization (255 = none)
    event PlayerWeaponSpecializationChanged(uint32 indexed playerId, uint8 weaponType);

    /// @notice Emitted when a player's armor specialization changes
    /// @param playerId The ID of the player
    /// @param armorType The new armor specialization (255 = none)
    event PlayerArmorSpecializationChanged(uint32 indexed playerId, uint8 armorType);

    /// @notice Emitted when an attribute point charge is awarded
    /// @param to Address receiving the charge
    /// @param totalCharges Total number of attribute point charges available
    event AttributePointAwarded(address indexed to, uint256 totalCharges);

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
        IPlayer.GamePermissions storage perms = _gameContractPermissions[msg.sender];
        if (permission == IPlayer.GamePermission.RECORD && !perms.record) revert NoPermission();
        if (permission == IPlayer.GamePermission.RETIRE && !perms.retire) revert NoPermission();
        if (permission == IPlayer.GamePermission.ATTRIBUTES && !perms.attributes) revert NoPermission();
        if (permission == IPlayer.GamePermission.IMMORTAL && !perms.immortal) revert NoPermission();
        if (permission == IPlayer.GamePermission.EXPERIENCE && !perms.experience) revert NoPermission();
        _;
    }

    /// @notice Ensures the specified player exists and is within valid user player range
    /// @param playerId The ID of the player to check
    /// @dev Reverts with PlayerDoesNotExist if the player ID is invalid
    modifier playerExists(uint32 playerId) {
        if (!isValidId(playerId)) {
            revert InvalidPlayerRange();
        }
        if (_players[playerId].attributes.strength == 0) {
            revert PlayerDoesNotExist(playerId);
        }
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
    /// @param operator Address of the Gelato VRF operator
    /// @param playerTicketsAddress Address of the PlayerTickets contract
    /// @param playerCreationAddress Address of the PlayerCreation contract
    /// @param playerDataCodecAddress Address of the PlayerDataCodec contract
    /// @dev Sets initial configuration values and connects to required registries
    constructor(
        address skinRegistryAddress,
        address nameRegistryAddress,
        address equipmentRequirementsAddress,
        address operator,
        address playerTicketsAddress,
        address playerCreationAddress,
        address playerDataCodecAddress
    ) Owned(msg.sender) Fighter(skinRegistryAddress) {
        _nameRegistry = IPlayerNameRegistry(nameRegistryAddress);
        _equipmentRequirements = IEquipmentRequirements(equipmentRequirementsAddress);
        _operatorAddress = operator;
        _playerTickets = PlayerTickets(playerTicketsAddress);
        _playerCreation = IPlayerCreation(playerCreationAddress);
        _playerDataCodec = IPlayerDataCodec(playerDataCodecAddress);

        // Initialize season 0
        currentSeason = 0;
        seasons[0] = Season({startTimestamp: block.timestamp, startBlock: block.number});
        nextSeasonStart = getNextSeasonStartPST();
        emit SeasonStarted(0, block.timestamp, block.number);
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

    /// @notice Gets the number of attribute swap charges available for an address
    /// @param owner The address to check
    /// @return Number of attribute swap charges available
    function attributeSwapTickets(address owner) external view returns (uint256) {
        return _attributeSwapCharges[owner];
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

    /// @notice Get the current skin information for a player
    /// @param playerId The ID of the player
    /// @return The player's equipped skin information (index and token ID)
    function getCurrentSkin(uint32 playerId) public view override(Fighter, IPlayer) returns (SkinInfo memory) {
        return _players[playerId].skin;
    }

    /// @notice Gets the current stance for a player
    /// @param playerId The ID of the player to query
    /// @return The player's current stance
    function getCurrentStance(uint32 playerId)
        public
        view
        override(Fighter, IPlayer)
        playerExists(playerId)
        returns (uint8)
    {
        return _players[playerId].stance;
    }

    /// @notice Get the current attributes for a player
    /// @param playerId The ID of the player
    /// @return attributes The player's current base attributes
    function getCurrentAttributes(uint32 playerId)
        public
        view
        override(Fighter, IPlayer)
        playerExists(playerId)
        returns (Attributes memory)
    {
        return _players[playerId].attributes;
    }

    /// @notice Get the current combat record for a player
    /// @param playerId The ID of the player
    /// @return The player's current win/loss/kill record
    function getCurrentRecord(uint32 playerId)
        public
        view
        override(Fighter, IPlayer)
        playerExists(playerId)
        returns (Record memory)
    {
        return seasonalRecords[playerId][currentSeason];
    }

    /// @notice Get the current name for a player
    /// @param playerId The ID of the player
    /// @return The player's current name
    function getCurrentName(uint32 playerId) public view playerExists(playerId) returns (PlayerName memory) {
        return _players[playerId].name;
    }

    // State-Changing Functions
    /// @notice Initiates the creation of a new player with random stats
    /// @param useNameSetB If true, uses name set B for generation, otherwise uses set A
    /// @return requestId The VRF request ID for tracking the creation
    /// @dev Requires ETH payment of createPlayerFeeAmount. Reverts if caller has pending requests or is over max players
    function requestCreatePlayer(bool useNameSetB) external payable whenNotPaused returns (uint256 requestId) {
        if (msg.value < createPlayerFeeAmount) revert InsufficientFeeAmount();
        return _requestCreatePlayerInternal(useNameSetB);
    }

    /// @notice Requests creation of a new player using CREATE_PLAYER_TICKET
    /// @param useNameSetB If true, uses name set B for generation, otherwise uses set A
    /// @return requestId The VRF request ID for tracking the creation
    /// @dev Requires burning 1 CREATE_PLAYER_TICKET token. Reverts if caller has pending requests or is over max players
    function requestCreatePlayerWithTicket(bool useNameSetB) external whenNotPaused returns (uint256 requestId) {
        // Burn the ticket first (will revert if insufficient balance)
        _playerTickets.burnFrom(msg.sender, _playerTickets.CREATE_PLAYER_TICKET(), 1);
        return _requestCreatePlayerInternal(useNameSetB);
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
        _addPlayerSlotBatch(msg.sender);
    }

    /// @notice Purchase additional player slots using PLAYER_SLOT_TICKET tokens
    /// @dev Burns exactly 1 ticket to add SLOT_BATCH_SIZE slots
    function purchasePlayerSlotsWithTickets() external {
        // Burn exactly 1 ticket (will revert if insufficient balance)
        _playerTickets.burnFrom(msg.sender, _playerTickets.PLAYER_SLOT_TICKET(), 1);
        _addPlayerSlotBatch(msg.sender);
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

        // Use an attribute swap charge
        if (_attributeSwapCharges[msg.sender] == 0) revert InsufficientCharges();
        _attributeSwapCharges[msg.sender]--;

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

    /// @notice Sets weapon specialization for a player by burning a specialization ticket
    /// @param playerId The ID of the player
    /// @param weaponType The weapon type to specialize in (255 = none)
    function setWeaponSpecialization(uint32 playerId, uint8 weaponType)
        external
        playerExists(playerId)
        onlyPlayerOwner(playerId)
    {
        // Burn a weapon specialization ticket
        _playerTickets.burnFrom(msg.sender, _playerTickets.WEAPON_SPECIALIZATION_TICKET(), 1);

        _players[playerId].weaponSpecialization = weaponType;

        emit PlayerWeaponSpecializationChanged(playerId, weaponType);
    }

    /// @notice Sets armor specialization for a player by burning a specialization ticket
    /// @param playerId The ID of the player
    /// @param armorType The armor type to specialize in (255 = none)
    function setArmorSpecialization(uint32 playerId, uint8 armorType)
        external
        playerExists(playerId)
        onlyPlayerOwner(playerId)
    {
        // Burn an armor specialization ticket
        _playerTickets.burnFrom(msg.sender, _playerTickets.ARMOR_SPECIALIZATION_TICKET(), 1);

        _players[playerId].armorSpecialization = armorType;

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
    /// @dev Requires RECORD permission. Reverts if player doesn't exist
    function incrementWins(uint32 playerId)
        external
        hasPermission(IPlayer.GamePermission.RECORD)
        playerExists(playerId)
    {
        // Check for season transition
        checkAndUpdateSeason();

        // Update both seasonal and lifetime records
        lifetimeRecords[playerId].wins++;
        seasonalRecords[playerId][currentSeason].wins++;

        // Get current seasonal record for event
        Fighter.Record memory seasonalRecord = seasonalRecords[playerId][currentSeason];
        emit PlayerWinLossUpdated(playerId, seasonalRecord.wins, seasonalRecord.losses);
    }

    /// @notice Increments the loss count for a player
    /// @param playerId The ID of the player to update
    /// @dev Requires RECORD permission. Reverts if player doesn't exist
    function incrementLosses(uint32 playerId)
        external
        hasPermission(IPlayer.GamePermission.RECORD)
        playerExists(playerId)
    {
        // Check for season transition
        checkAndUpdateSeason();

        // Update both seasonal and lifetime records
        lifetimeRecords[playerId].losses++;
        seasonalRecords[playerId][currentSeason].losses++;

        // Get current seasonal record for event
        Fighter.Record memory seasonalRecord = seasonalRecords[playerId][currentSeason];
        emit PlayerWinLossUpdated(playerId, seasonalRecord.wins, seasonalRecord.losses);
    }

    /// @notice Increments the kill count for a player
    /// @param playerId The ID of the player to update
    /// @dev Requires RECORD permission. Reverts if player doesn't exist
    function incrementKills(uint32 playerId)
        external
        hasPermission(IPlayer.GamePermission.RECORD)
        playerExists(playerId)
    {
        // Check for season transition
        checkAndUpdateSeason();

        // Update both seasonal and lifetime records
        lifetimeRecords[playerId].kills++;
        seasonalRecords[playerId][currentSeason].kills++;

        // Get current seasonal record for event
        Fighter.Record memory seasonalRecord = seasonalRecords[playerId][currentSeason];
        emit PlayerKillUpdated(playerId, seasonalRecord.kills);
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

    /// @notice Awards an attribute swap charge to an address
    /// @param to Address to receive the charge
    /// @dev Requires ATTRIBUTES permission
    function awardAttributeSwap(address to) external hasPermission(IPlayer.GamePermission.ATTRIBUTES) {
        if (to == address(0)) revert BadZeroAddress();
        _attributeSwapCharges[to]++;
        emit AttributeSwapAwarded(to, _attributeSwapCharges[to]);
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
    /// @notice Updates the Gelato VRF operator address
    /// @param newOperator The new operator address
    /// @dev Reverts if zero address provided
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert BadZeroAddress();
        _operatorAddress = newOperator;
    }

    /// @notice Updates the fee required to create a new player
    /// @param newFeeAmount The new fee amount in ETH
    function setCreatePlayerFeeAmount(uint256 newFeeAmount) external onlyOwner {
        uint256 oldFee = createPlayerFeeAmount;
        createPlayerFeeAmount = newFeeAmount;
        emit CreatePlayerFeeUpdated(oldFee, newFeeAmount);
    }

    /// @notice Withdraws all accumulated fees to the owner address
    function withdrawFees() external onlyOwner {
        SafeTransferLib.safeTransferETH(owner, address(this).balance);
    }

    /// @notice Recovers any ERC20 tokens accidentally sent to the contract
    /// @param token The address of the ERC20 token to recover
    /// @param amount The amount of tokens to recover
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        SafeTransferLib.safeTransfer(ERC20(token), owner, amount);
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

    //==============================================================//
    //                    SEASON FUNCTIONS                          //
    //==============================================================//
    /// @notice Checks if a new season should start and updates accordingly
    /// @dev Can be called by anyone when timestamp condition is met
    function checkAndUpdateSeason() public {
        if (block.timestamp >= nextSeasonStart) {
            currentSeason++;
            seasons[currentSeason] = Season({startTimestamp: block.timestamp, startBlock: block.number});

            // Calculate next season start
            nextSeasonStart = getNextSeasonStartPST();

            emit SeasonStarted(currentSeason, block.timestamp, block.number);
        }
    }

    /// @notice Calculates the timestamp for the first day of next season at midnight PST
    /// @return Timestamp for next season start
    function getNextSeasonStartPST() public view returns (uint256) {
        // Adjust current time to UTC-8 by adding 8 hours
        uint256 adjustedTime = block.timestamp + 8 hours;

        // Get current date components in UTC-8
        (uint256 year, uint256 month, uint256 day) = BokkyPooBahsDateTimeLibrary.timestampToDate(adjustedTime);

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
    // VRF Implementation
    /// @notice Returns the address of the Gelato VRF operator
    /// @return Address of the operator
    /// @dev Required override from GelatoVRFConsumerBase
    function _operator() internal view override returns (address) {
        return _operatorAddress;
    }

    /// @notice Handles the fulfillment of VRF requests for player creation
    /// @param randomness The random value provided by VRF
    /// @param requestId The ID of the request being fulfilled
    /// @dev Required override from GelatoVRFConsumerBase. Reverts if request is invalid or already fulfilled
    function _fulfillRandomness(uint256 randomness, uint256 requestId, bytes memory /* extraData */ )
        internal
        override
    {
        // Checks
        PendingPlayer memory pending = _pendingPlayers[requestId];
        if (pending.owner == address(0)) revert InvalidRequestID();
        if (pending.fulfilled) revert RequestAlreadyFulfilled();

        // Effects
        _pendingPlayers[requestId].fulfilled = true;
        uint256 combinedSeed = uint256(keccak256(abi.encodePacked(randomness, requestId, pending.owner)));

        // Check player slot limit
        if (_addressActivePlayerCount[pending.owner] >= getPlayerSlots(pending.owner)) revert TooManyPlayers();

        // Generate player data using external helper
        IPlayer.PlayerStats memory stats = _playerCreation.generatePlayerData(combinedSeed, pending.useNameSetB);

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
            stats.attributes.luck
        );
    }

    //==============================================================//
    //                    PRIVATE FUNCTIONS                         //
    //==============================================================//
    // Pure helpers

    // State-modifying helpers

    /// @notice Internal function to handle common player creation logic
    /// @param useNameSetB If true, uses name set B for generation, otherwise uses set A
    /// @return requestId The VRF request ID for tracking the creation
    /// @dev Shared logic for both ETH and ticket-based player creation
    function _requestCreatePlayerInternal(bool useNameSetB) private returns (uint256 requestId) {
        if (_addressActivePlayerCount[msg.sender] >= getPlayerSlots(msg.sender)) revert TooManyPlayers();
        if (_userPendingRequest[msg.sender] != 0) revert PendingRequestExists();

        // Effects - Get requestId first since it's deterministic and can't fail
        requestId = _requestRandomness("");
        _pendingPlayers[requestId] = PendingPlayer({
            owner: msg.sender,
            useNameSetB: useNameSetB,
            fulfilled: false,
            timestamp: uint64(block.timestamp)
        });
        _userPendingRequest[msg.sender] = requestId;

        emit PlayerCreationRequested(requestId, msg.sender);
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
    function _addPlayerSlotBatch(address user) internal {
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
        emit PlayerSlotsPurchased(user, SLOT_BATCH_SIZE, currentTotalSlots + SLOT_BATCH_SIZE, msg.value);
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
    //                  LEVEL-AWARE IMPLEMENTATIONS                 //
    //==============================================================//
    /// @notice Get attributes for a player at a specific level
    /// @dev Player level is intrinsic - use getCurrentAttributes instead
    function getAttributesAtLevel(uint32 playerId, uint8 level) public view override returns (Attributes memory) {
        revert("Player: Use getCurrentAttributes - level is intrinsic to player");
    }

    /// @notice Get stance for a player at a specific level
    /// @dev Player level is intrinsic - use getCurrentStance instead
    function getStanceAtLevel(uint32 playerId, uint8 level) public view override returns (uint8) {
        revert("Player: Use getCurrentStance - level is intrinsic to player");
    }

    /// @notice Get skin for a player at a specific level
    /// @dev Player level is intrinsic - use getCurrentSkin instead
    function getSkinAtLevel(uint32 playerId, uint8 level) public view override returns (SkinInfo memory) {
        revert("Player: Use getCurrentSkin - level is intrinsic to player");
    }

    /// @notice Get record for a player at a specific level
    /// @dev Player level is intrinsic - use getCurrentRecord instead
    function getRecordAtLevel(uint32 playerId, uint8 level) public view override returns (Record memory) {
        revert("Player: Use getCurrentRecord - level is intrinsic to player");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
// External imports
import "solmate/src/auth/Owned.sol";
import "solmate/src/utils/SafeTransferLib.sol";
import "vrf-contracts/contracts/GelatoVRFConsumerBase.sol";
// Internal imports
import "../lib/UniformRandomNumber.sol";
import "../interfaces/fighters/IPlayer.sol";
import "../interfaces/fighters/registries/names/IPlayerNameRegistry.sol";
import "../interfaces/game/engine/IEquipmentRequirements.sol";
import "./Fighter.sol";
//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
/// @notice Thrown when a player ID doesn't exist

error PlayerDoesNotExist(uint32 playerId);
/// @notice Thrown when caller doesn't own the NFT skin they're trying to equip
error NotSkinOwner();
/// @notice Thrown when caller doesn't own the player they're trying to modify
error NotPlayerOwner();
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
/// @notice Thrown when attempting to set invalid player statistics
error InvalidPlayerStats();
/// @notice Thrown when caller doesn't have required permission
error NoPermission();
/// @notice Thrown when attempting to set zero address for critical contract references
error BadZeroAddress();
/// @notice Thrown when attempting to use an invalid token ID for a skin
error InvalidTokenId(uint16 tokenId);
/// @notice Thrown when insufficient charges are available
error InsufficientCharges();
/// @notice Thrown when attempting to swap invalid attributes
error InvalidAttributeSwap();
/// @notice Thrown when attempting to use an invalid name index
error InvalidNameIndex();
/// @notice Thrown when user doesn't own required NFT
error RequiredNFTNotOwned(address nftAddress);
/// @notice Thrown when attempting to use an invalid player ID range
error InvalidPlayerRange();
/// @notice Thrown when attempting to use an invalid skin type
error InvalidSkinType();

//==============================================================//
//                         HEAVY HELMS                          //
//                           PLAYER                             //
//==============================================================//
/// @title Player Contract for Heavy Helms
/// @notice Manages player creation, attributes, skins, and persistent player data
/// @dev Integrates with VRF for random stat generation and interfaces with skin/name registries
contract Player is IPlayer, Owned, GelatoVRFConsumerBase, Fighter {
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
    struct PendingPlayer {
        address owner;
        bool useNameSetB;
        bool fulfilled;
    }

    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    // Constants
    /// @notice Minimum value for any player stat
    uint8 private constant MIN_STAT = 3;
    /// @notice Maximum value for any player stat
    uint8 private constant MAX_STAT = 21;
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

    // Configuration
    /// @notice Fee amount in ETH required to create a new player
    uint256 public createPlayerFeeAmount = 0.001 ether;
    /// @notice Cost in ETH for each additional slot batch (5 slots), increases linearly with purchases
    uint256 public slotBatchCost = 0.005 ether;
    /// @notice Whether the contract is paused (prevents new player creation)
    bool public isPaused;

    // Contract References
    /// @notice Registry contract for managing player name sets and validation
    IPlayerNameRegistry private immutable _nameRegistry;
    /// @notice Interface for equipment requirements validation
    IEquipmentRequirements private _equipmentRequirements;

    // Player state tracking
    /// @notice Starting ID for user-created players (1-2000 reserved for default characters)
    uint32 private nextPlayerId = USER_PLAYER_START;
    /// @notice Maps player ID to their stats and attributes
    mapping(uint32 => IPlayer.PlayerStats) private _players;
    /// @notice Maps player ID to their owner's address
    mapping(uint32 => address) private _playerOwners;
    /// @notice Maps player ID to their retirement status
    mapping(uint32 => bool) private _retiredPlayers;
    /// @notice Maps player ID to their immortality status
    mapping(uint32 => bool) private _immortalPlayers;
    /// @notice Tracks how many players each address has created
    mapping(address => uint256) private _addressPlayerCount;
    /// @notice Maps address to array of their owned player IDs
    mapping(address => uint32[]) private _addressToPlayerIds;
    /// @notice Maps game contract address to their granted permissions
    mapping(address => IPlayer.GamePermissions) private _gameContractPermissions;
    /// @notice Tracks how many active (non-retired) players each address has
    mapping(address => uint256) private _addressActivePlayerCount;
    /// @notice Maps address to their number of purchased extra player slots
    mapping(address => uint8) private _extraPlayerSlots;
    /// @notice Maps address to the number of name change charges available
    mapping(address => uint256) private _nameChangeCharges;
    /// @notice Maps address to the number of attribute swap charges available
    mapping(address => uint256) private _attributeSwapCharges;

    // VRF Request tracking
    /// @notice Address of the Gelato VRF operator
    address private _operatorAddress;
    /// @notice Maps VRF request IDs to their pending player creation details
    mapping(uint256 => PendingPlayer) private _pendingPlayers;
    /// @notice Maps user address to their current pending request ID
    /// @dev 0 indicates no pending request, >0 is the active request ID
    mapping(address => uint256) private _userPendingRequest;

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

    /// @notice Emitted when a player equips a new skin
    /// @param playerId The ID of the player
    /// @param skinIndex The index of the skin collection in the registry
    /// @param tokenId The token ID of the specific skin being equipped
    event PlayerSkinEquipped(uint32 indexed playerId, uint32 indexed skinIndex, uint16 tokenId);

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

    /// @notice Emitted when a player's attributes are updated
    /// @param playerId The ID of the player
    /// @param strength New strength value
    /// @param constitution New constitution value
    /// @param size New size value
    /// @param agility New agility value
    /// @param stamina New stamina value
    /// @param luck New luck value
    event PlayerAttributesUpdated(
        uint32 indexed playerId,
        uint8 strength,
        uint8 constitution,
        uint8 size,
        uint8 agility,
        uint8 stamina,
        uint8 luck
    );

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

    //==============================================================//
    //                        MODIFIERS                             //
    //==============================================================//
    /// @notice Ensures caller has the required game permission
    /// @param permission The specific permission being checked
    /// @dev Reverts with NoPermission if the caller lacks the required permission
    modifier hasPermission(IPlayer.GamePermission permission) {
        IPlayer.GamePermissions storage perms = _gameContractPermissions[msg.sender];
        bool hasAccess = permission == IPlayer.GamePermission.RECORD
            ? perms.record
            : permission == IPlayer.GamePermission.RETIRE
                ? perms.retire
                : permission == IPlayer.GamePermission.NAME
                    ? perms.name
                    : permission == IPlayer.GamePermission.ATTRIBUTES
                        ? perms.attributes
                        : permission == IPlayer.GamePermission.IMMORTAL ? perms.immortal : false;
        if (!hasAccess) revert NoPermission();
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
    /// @param operator Address of the Gelato VRF operator
    /// @dev Sets initial configuration values and connects to required registries
    constructor(
        address skinRegistryAddress,
        address nameRegistryAddress,
        address equipmentRequirementsAddress,
        address operator
    ) Owned(msg.sender) Fighter(skinRegistryAddress) {
        _nameRegistry = IPlayerNameRegistry(nameRegistryAddress);
        _equipmentRequirements = IEquipmentRequirements(equipmentRequirementsAddress);
        _operatorAddress = operator;
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    // Pure Functions
    /// @notice Packs player data into a compact bytes32 format for efficient storage/transmission
    /// @param playerId The ID of the player to encode
    /// @param stats The player's stats and attributes to encode
    /// @return bytes32 Packed player data in the format: [playerId(4)][stats(6)][skinIndex(4)][tokenId(2)][names(4)][records(6)]
    /// @dev Byte layout: [0-3:playerId][4-9:stats][10-13:skinIndex][14-25:other data]
    function encodePlayerData(uint32 playerId, PlayerStats memory stats) external pure returns (bytes32) {
        bytes memory packed = new bytes(32);

        // Pack playerId (4 bytes)
        packed[0] = bytes1(uint8(playerId >> 24));
        packed[1] = bytes1(uint8(playerId >> 16));
        packed[2] = bytes1(uint8(playerId >> 8));
        packed[3] = bytes1(uint8(playerId));

        // Pack uint8 stats (6 bytes)
        packed[4] = bytes1(stats.attributes.strength);
        packed[5] = bytes1(stats.attributes.constitution);
        packed[6] = bytes1(stats.attributes.size);
        packed[7] = bytes1(stats.attributes.agility);
        packed[8] = bytes1(stats.attributes.stamina);
        packed[9] = bytes1(stats.attributes.luck);

        // Pack skinIndex (4 bytes)
        packed[10] = bytes1(uint8(stats.skin.skinIndex >> 24));
        packed[11] = bytes1(uint8(stats.skin.skinIndex >> 16));
        packed[12] = bytes1(uint8(stats.skin.skinIndex >> 8));
        packed[13] = bytes1(uint8(stats.skin.skinIndex));

        // Pack uint16 values (14 bytes)
        packed[14] = bytes1(uint8(stats.skin.skinTokenId >> 8));
        packed[15] = bytes1(uint8(stats.skin.skinTokenId));

        packed[16] = bytes1(uint8(stats.name.firstNameIndex >> 8));
        packed[17] = bytes1(uint8(stats.name.firstNameIndex));

        packed[18] = bytes1(uint8(stats.name.surnameIndex >> 8));
        packed[19] = bytes1(uint8(stats.name.surnameIndex));

        packed[20] = bytes1(uint8(stats.record.wins >> 8));
        packed[21] = bytes1(uint8(stats.record.wins));

        packed[22] = bytes1(uint8(stats.record.losses >> 8));
        packed[23] = bytes1(uint8(stats.record.losses));

        packed[24] = bytes1(uint8(stats.record.kills >> 8));
        packed[25] = bytes1(uint8(stats.record.kills));

        // Last 6 bytes are padded with zeros by default

        return bytes32(packed);
    }

    /// @notice Unpacks player data from bytes32 format back into structured data
    /// @param data The packed bytes32 data to decode
    /// @return playerId The decoded player ID
    /// @return stats The decoded player stats and attributes
    /// @dev Reverses the encoding process from encodePlayerData
    function decodePlayerData(bytes32 data) external pure returns (uint32 playerId, PlayerStats memory stats) {
        bytes memory packed = new bytes(32);
        assembly {
            mstore(add(packed, 32), data)
        }

        // Decode playerId
        playerId = uint32(uint8(packed[0])) << 24 | uint32(uint8(packed[1])) << 16 | uint32(uint8(packed[2])) << 8
            | uint32(uint8(packed[3]));

        // Decode uint8 stats
        stats.attributes.strength = uint8(packed[4]);
        stats.attributes.constitution = uint8(packed[5]);
        stats.attributes.size = uint8(packed[6]);
        stats.attributes.agility = uint8(packed[7]);
        stats.attributes.stamina = uint8(packed[8]);
        stats.attributes.luck = uint8(packed[9]);

        // Decode skinIndex
        uint32 skinIndex = uint32(uint8(packed[10])) << 24 | uint32(uint8(packed[11])) << 16
            | uint32(uint8(packed[12])) << 8 | uint32(uint8(packed[13]));
        uint16 skinTokenId = uint16(uint8(packed[14])) << 8 | uint16(uint8(packed[15]));

        // Decode uint16 values
        stats.name.firstNameIndex = uint16(uint8(packed[16])) << 8 | uint16(uint8(packed[17]));
        stats.name.surnameIndex = uint16(uint8(packed[18])) << 8 | uint16(uint8(packed[19]));
        stats.record.wins = uint16(uint8(packed[20])) << 8 | uint16(uint8(packed[21]));
        stats.record.losses = uint16(uint8(packed[22])) << 8 | uint16(uint8(packed[23]));
        stats.record.kills = uint16(uint8(packed[24])) << 8 | uint16(uint8(packed[25]));

        // Construct skin
        stats.skin = SkinInfo({skinIndex: skinIndex, skinTokenId: skinTokenId});

        return (playerId, stats);
    }

    // View Functions
    /// @notice Gets all player IDs owned by a specific address
    /// @param owner The address to check
    /// @return Array of player IDs owned by the address
    function getPlayerIds(address owner) external view returns (uint32[] memory) {
        return _addressToPlayerIds[owner];
    }

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

    /// @notice Gets the number of name change charges available for an address
    /// @param owner The address to check
    /// @return Number of name change charges available
    function nameChangeCharges(address owner) external view returns (uint256) {
        return _nameChangeCharges[owner];
    }

    /// @notice Gets the number of attribute swap charges available for an address
    /// @param owner The address to check
    /// @return Number of attribute swap charges available
    function attributeSwapCharges(address owner) external view returns (uint256) {
        return _attributeSwapCharges[owner];
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

    /// @notice Calculate the cost for the next slot batch purchase for an address
    /// @param user The address to calculate the cost for
    /// @return Cost in ETH for the next slot batch purchase
    function getNextSlotBatchCost(address user) public view returns (uint256) {
        uint8 currentExtraSlots = _extraPlayerSlots[user];
        uint256 batchesPurchased = currentExtraSlots / 5;
        return slotBatchCost * (batchesPurchased + 1);
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

    /// @notice Check if a player ID is valid
    /// @param playerId The ID to check
    /// @return bool True if the ID is within valid user player range
    function isValidId(uint32 playerId) public pure override returns (bool) {
        return playerId >= USER_PLAYER_START && playerId <= USER_PLAYER_END;
    }

    /// @notice Get the current skin information for a player
    /// @param playerId The ID of the player
    /// @return The player's equipped skin information (index and token ID)
    function getCurrentSkin(uint32 playerId) public view override returns (SkinInfo memory) {
        PlayerStats memory stats = _players[playerId];
        return stats.skin;
    }

    // State-Changing Functions
    /// @notice Initiates the creation of a new player with random stats
    /// @param useNameSetB If true, uses name set B for generation, otherwise uses set A
    /// @return requestId The VRF request ID for tracking the creation
    /// @dev Requires ETH payment of createPlayerFeeAmount. Reverts if caller has pending requests or is over max players
    function requestCreatePlayer(bool useNameSetB) external payable whenNotPaused returns (uint256 requestId) {
        if (_addressActivePlayerCount[msg.sender] >= getPlayerSlots(msg.sender)) revert TooManyPlayers();
        if (_userPendingRequest[msg.sender] != 0) revert PendingRequestExists();
        if (msg.value < createPlayerFeeAmount) revert InsufficientFeeAmount();

        // Effects - Get requestId first since it's deterministic and can't fail
        requestId = _requestRandomness("");
        _pendingPlayers[requestId] = PendingPlayer({owner: msg.sender, useNameSetB: useNameSetB, fulfilled: false});
        _userPendingRequest[msg.sender] = requestId;

        emit PlayerCreationRequested(requestId, msg.sender);
    }

    /// @notice Equips a skin to a player
    /// @param playerId The ID of the player to modify
    /// @param skinIndex The index of the skin collection in the registry
    /// @param skinTokenId The token ID of the specific skin being equipped
    /// @dev Verifies ownership and collection requirements. Reverts if player is retired
    function equipSkin(uint32 playerId, uint32 skinIndex, uint16 skinTokenId) external {
        // Verify player exists and is owned by sender
        if (!_exists(playerId) || _ownerOf(playerId) != msg.sender) {
            revert PlayerDoesNotExist(playerId);
        }

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

        // Update player's skin
        _players[playerId].skin.skinIndex = skinIndex;
        _players[playerId].skin.skinTokenId = skinTokenId;

        emit PlayerSkinEquipped(playerId, skinIndex, skinTokenId);
    }

    /// @notice Purchase additional player slots
    /// @dev Each purchase adds 5 slots, cost increases linearly with number of existing extra slots
    /// @return Number of slots purchased
    function purchasePlayerSlots() external payable returns (uint8) {
        // Calculate current total slots
        uint8 currentExtraSlots = _extraPlayerSlots[msg.sender];
        uint8 currentTotalSlots = BASE_PLAYER_SLOTS + currentExtraSlots;

        // Ensure we don't exceed maximum
        if (currentTotalSlots >= MAX_TOTAL_SLOTS) revert TooManyPlayers();

        // Calculate cost based on current extra slots
        // Cost increases by slotBatchCost for each batch already purchased
        uint256 requiredPayment = getNextSlotBatchCost(msg.sender);
        if (msg.value < requiredPayment) revert InsufficientFeeAmount();

        // Calculate new slots to add (cap at MAX_TOTAL_SLOTS)
        uint8 slotsToAdd = 5;
        if (currentTotalSlots + slotsToAdd > MAX_TOTAL_SLOTS) {
            slotsToAdd = MAX_TOTAL_SLOTS - currentTotalSlots;
        }

        _extraPlayerSlots[msg.sender] += slotsToAdd;

        emit PlayerSlotsPurchased(msg.sender, slotsToAdd, currentTotalSlots, msg.value);

        return slotsToAdd;
    }

    /// @notice Changes a player's name
    /// @param playerId The ID of the player to update
    /// @param firstNameIndex Index of the first name in the name registry
    /// @param surnameIndex Index of the surname in the name registry
    function changeName(uint32 playerId, uint16 firstNameIndex, uint16 surnameIndex) external playerExists(playerId) {
        if (_nameChangeCharges[msg.sender] == 0) revert InsufficientCharges();
        if (_playerOwners[playerId] != msg.sender) revert NotPlayerOwner();

        // Validate name indices
        if (!nameRegistry().isValidFirstNameIndex(firstNameIndex) || surnameIndex >= nameRegistry().getSurnamesLength())
        {
            revert InvalidNameIndex();
        }

        _nameChangeCharges[msg.sender]--;

        PlayerStats storage player = _players[playerId];
        player.name.firstNameIndex = firstNameIndex;
        player.name.surnameIndex = surnameIndex;

        emit PlayerNameUpdated(playerId, firstNameIndex, surnameIndex);
    }

    /// @notice Swaps attributes between two player attributes
    /// @param playerId The ID of the player to update
    /// @param decreaseAttribute The attribute to decrease
    /// @param increaseAttribute The attribute to increase
    /// @dev Requires ATTRIBUTES permission and sufficient charges. Reverts if player doesn't exist or charges are insufficient
    function swapAttributes(uint32 playerId, Attribute decreaseAttribute, Attribute increaseAttribute)
        external
        playerExists(playerId)
    {
        if (_attributeSwapCharges[msg.sender] == 0) revert InsufficientCharges();
        if (_playerOwners[playerId] != msg.sender) revert NotPlayerOwner();
        if (decreaseAttribute == increaseAttribute) revert InvalidAttributeSwap();

        PlayerStats storage player = _players[playerId];

        uint8 decreaseValue = _getAttributeValue(player, decreaseAttribute);
        uint8 increaseValue = _getAttributeValue(player, increaseAttribute);

        if (decreaseValue <= MIN_STAT || increaseValue >= MAX_STAT) {
            revert InvalidAttributeSwap();
        }

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

    /// @notice Retires a player owned by the caller
    /// @param playerId The ID of the player to retire
    /// @dev Retired players cannot be used in games but can still be viewed
    function retireOwnPlayer(uint32 playerId) external playerExists(playerId) {
        // Check caller owns it
        if (_ownerOf(playerId) != msg.sender) revert NotPlayerOwner();

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
        PlayerStats storage stats = _players[playerId];
        stats.record.wins++;
        emit PlayerWinLossUpdated(playerId, stats.record.wins, stats.record.losses);
    }

    /// @notice Increments the loss count for a player
    /// @param playerId The ID of the player to update
    /// @dev Requires RECORD permission. Reverts if player doesn't exist
    function incrementLosses(uint32 playerId)
        external
        hasPermission(IPlayer.GamePermission.RECORD)
        playerExists(playerId)
    {
        PlayerStats storage stats = _players[playerId];
        stats.record.losses++;
        emit PlayerWinLossUpdated(playerId, stats.record.wins, stats.record.losses);
    }

    /// @notice Increments the kill count for a player
    /// @param playerId The ID of the player to update
    /// @dev Requires RECORD permission. Reverts if player doesn't exist
    function incrementKills(uint32 playerId)
        external
        hasPermission(IPlayer.GamePermission.RECORD)
        playerExists(playerId)
    {
        PlayerStats storage stats = _players[playerId];
        stats.record.kills++;
        emit PlayerKillUpdated(playerId, stats.record.kills);
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

    /// @notice Awards a name change charge to an address
    /// @param to Address to receive the charge
    /// @dev Requires NAME permission
    function awardNameChange(address to) external hasPermission(IPlayer.GamePermission.NAME) {
        if (to == address(0)) revert BadZeroAddress();
        _nameChangeCharges[to]++;
        emit NameChangeAwarded(to, _nameChangeCharges[to]);
    }

    /// @notice Awards an attribute swap charge to an address
    /// @param to Address to receive the charge
    /// @dev Requires ATTRIBUTES permission
    function awardAttributeSwap(address to) external hasPermission(IPlayer.GamePermission.ATTRIBUTES) {
        if (to == address(0)) revert BadZeroAddress();
        _attributeSwapCharges[to]++;
        emit AttributeSwapAwarded(to, _attributeSwapCharges[to]);
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
    /// @dev Use with caution - will invalidate any pending player creation requests
    function clearPendingRequestsForAddress(address user) external onlyOwner {
        uint256 requestId = _userPendingRequest[user];
        if (requestId != 0) {
            delete _pendingPlayers[requestId];
            delete _userPendingRequest[user];
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
        _equipmentRequirements = IEquipmentRequirements(newAddress);
        emit EquipmentRequirementsUpdated(address(_equipmentRequirements), newAddress);
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
        (uint32 playerId, IPlayer.PlayerStats memory stats) =
            _createPlayerWithRandomness(pending.owner, pending.useNameSetB, combinedSeed);

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
            skin: SkinInfo({skinIndex: 0, skinTokenId: 1}),
            name: PlayerName({firstNameIndex: player.name.firstNameIndex, surnameIndex: player.name.surnameIndex}),
            record: Fighter.Record({wins: player.record.wins, losses: player.record.losses, kills: player.record.kills})
        });
    }

    // View helpers
    /// @notice Checks if a player ID exists
    /// @param playerId The ID to check
    /// @return True if the player exists, false otherwise
    function _exists(uint32 playerId) private view returns (bool) {
        return _playerOwners[playerId] != address(0);
    }

    /// @notice Gets the owner of a player
    /// @param playerId The ID of the player
    /// @return Address of the player's owner
    function _ownerOf(uint32 playerId) private view returns (address) {
        return _playerOwners[playerId];
    }

    /// @notice Checks if an address owns any NFT from a collection
    /// @param owner The address to check
    /// @param nftContract The NFT contract address
    /// @return True if owner has any NFTs from the collection
    /// @dev Uses balanceOf call, returns false if call fails
    function _checkCollectionOwnership(address owner, address nftContract) private view returns (bool) {
        (bool success, bytes memory data) = nftContract.staticcall(abi.encodeWithSignature("balanceOf(address)", owner));

        if (!success) return false;

        uint256 balance = abi.decode(data, (uint256));
        return balance > 0;
    }

    // State-modifying helpers
    /// @notice Creates a new player with random stats
    /// @param owner Address that will own the player
    /// @param useNameSetB Whether to use name set B for generation
    /// @param randomSeed Seed for random number generation
    /// @return playerId ID of the created player
    /// @return stats Stats of the created player
    /// @dev Handles stat distribution and name generation
    function _createPlayerWithRandomness(address owner, bool useNameSetB, uint256 randomSeed)
        private
        returns (uint32 playerId, IPlayer.PlayerStats memory stats)
    {
        if (_addressActivePlayerCount[owner] >= getPlayerSlots(owner)) revert TooManyPlayers();

        // Use incremental playerId
        playerId = nextPlayerId++;

        // Initialize base stats array with minimum values
        uint8[6] memory statArray = [3, 3, 3, 3, 3, 3];
        uint256 remainingPoints = 54; // 72 total - (6 * 3 minimum)

        // Distribute remaining points across stats
        uint256 order = uint256(keccak256(abi.encodePacked(randomSeed, "order")));

        unchecked {
            // Change to handle all 6 stats
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
            firstNameIndex = uint16(randomSeed.uniform(nameRegistry().getNameSetBLength()));
        } else {
            firstNameIndex =
                uint16(randomSeed.uniform(nameRegistry().getNameSetALength())) + nameRegistry().getSetAStart();
        }

        uint16 surnameIndex = uint16(randomSeed.uniform(nameRegistry().getSurnamesLength()));

        // Create stats struct
        stats = IPlayer.PlayerStats({
            attributes: Attributes({
                strength: statArray[0],
                constitution: statArray[1],
                size: statArray[2],
                agility: statArray[3],
                stamina: statArray[4],
                luck: statArray[5]
            }),
            skin: SkinInfo({skinIndex: 0, skinTokenId: 1}),
            name: PlayerName({firstNameIndex: firstNameIndex, surnameIndex: surnameIndex}),
            record: Fighter.Record({wins: 0, losses: 0, kills: 0})
        });

        // Validate and fix if necessary
        if (!_validateStats(stats)) {
            stats = _fixStats(stats, randomSeed);
        }

        // Store player data
        _players[playerId] = stats;
        _playerOwners[playerId] = owner;
        _addressToPlayerIds[owner].push(playerId);
        _addressPlayerCount[owner]++;
        _addressActivePlayerCount[owner]++;

        return (playerId, stats);
    }

    /// @notice Removes a request ID from a user's pending requests
    /// @param user The address whose request is being removed
    /// @param requestId The ID of the request to remove
    function _removeFromPendingRequests(address user, uint256 requestId) private {
        if (_userPendingRequest[user] == requestId) {
            delete _userPendingRequest[user];
        }
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

    /// @notice Get the base attributes for a player
    /// @param playerId The ID of the player
    /// @return attributes The player's base attributes
    function getFighterAttributes(uint32 playerId) internal view override returns (Attributes memory) {
        PlayerStats memory stats = _players[playerId];
        return stats.attributes;
    }
}

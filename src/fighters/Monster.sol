// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import "../interfaces/fighters/IMonster.sol";
import "../interfaces/fighters/registries/names/IMonsterNameRegistry.sol";
import "solmate/src/auth/Owned.sol";
import "./Fighter.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
/// @notice Thrown when attempting to use an invalid monster ID outside the monster range
error InvalidMonsterRange();
/// @notice Thrown when attempting to access a monster that doesn't exist
error MonsterDoesNotExist();
/// @notice Thrown when a caller doesn't have the required permission
error UnauthorizedCaller();
/// @notice Thrown when a required address argument is the zero address
error BadZeroAddress();

//==============================================================//
//                         HEAVY HELMS                          //
//                           MONSTER                            //
//==============================================================//
/// @title Monster Contract for Heavy Helms
/// @notice Manages monster characters for the game
/// @dev Monsters are system-controlled characters (IDs 2001-10000)
contract Monster is IMonster, Owned, Fighter {
    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    /// @notice Reference to the name registry contract for monster names
    IMonsterNameRegistry private immutable _nameRegistry;

    /// @notice ID range constants for monsters
    /// @dev Monsters occupy IDs 2001-10000
    uint32 private constant MONSTER_ID_START = 2001;
    uint32 private constant MONSTER_ID_END = 10000;

    /// @notice Next available monster ID
    uint32 private _nextMonsterId = MONSTER_ID_START;

    /// @notice Maps monster ID to their stats
    mapping(uint32 => MonsterStats) private _monsters;

    /// @notice Maps monster ID to their retirement status
    mapping(uint32 => bool) private _isRetired;

    /// @notice Maps monster ID to their immortality status
    mapping(uint32 => bool) private _isImmortal;

    /// @notice Maps game contract address to their granted permissions
    mapping(address => GamePermissions) private _gameContractPermissions;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a monster's win/loss record is updated
    /// @param monsterId The ID of the monster
    /// @param wins Current number of wins
    /// @param losses Current number of losses
    event MonsterWinLossUpdated(uint32 indexed monsterId, uint16 wins, uint16 losses);

    /// @notice Emitted when a monster's kill count is updated
    /// @param monsterId The ID of the monster
    /// @param kills Current number of kills
    event MonsterKillsUpdated(uint32 indexed monsterId, uint16 kills);

    /// @notice Emitted when a monster's immortality status is changed
    /// @param monsterId The ID of the monster
    /// @param immortal New immortality status
    event MonsterImmortalStatusUpdated(uint32 indexed monsterId, bool immortal);

    /// @notice Emitted when a monster's retirement status is changed
    /// @param monsterId The ID of the monster
    /// @param retired New retirement status
    event MonsterRetired(uint32 indexed monsterId, bool retired);

    /// @notice Emitted when a new monster is created
    /// @param monsterId The ID of the newly created monster
    /// @param stats The stats for the new monster
    event MonsterCreated(uint32 indexed monsterId, MonsterStats stats);

    /// @notice Emitted when a monster's stats are updated
    /// @param monsterId The ID of the monster
    /// @param stats The new stats for the monster
    event MonsterStatsUpdated(uint32 indexed monsterId, MonsterStats stats);

    /// @notice Emitted when a game contract's permissions are updated
    /// @param gameContract Address of the game contract
    /// @param permissions New permission settings
    event GameContractPermissionsUpdated(address indexed gameContract, GamePermissions permissions);

    //==============================================================//
    //                        MODIFIERS                             //
    //==============================================================//
    /// @notice Ensures the caller has the specified permission
    /// @param permission The permission required for the operation
    /// @dev Owner always has all permissions. Reverts with UnauthorizedCaller if permission is missing
    modifier hasPermission(GamePermission permission) {
        GamePermissions memory permissions = _gameContractPermissions[msg.sender];
        bool hasAccess = msg.sender == owner // Owner has all permissions
            || (permission == GamePermission.RECORD && permissions.record)
            || (permission == GamePermission.RETIRE && permissions.retire)
            || (permission == GamePermission.IMMORTAL && permissions.immortal);
        if (!hasAccess) revert UnauthorizedCaller();
        _;
    }

    /// @notice Ensures the monster ID is within valid range and exists
    /// @param monsterId The ID of the monster to check
    /// @dev Reverts with InvalidMonsterRange or MonsterDoesNotExist if validation fails
    modifier monsterExists(uint32 monsterId) {
        if (!isValidId(monsterId)) {
            revert InvalidMonsterRange();
        }
        if (_monsters[monsterId].attributes.strength == 0) {
            revert MonsterDoesNotExist();
        }
        _;
    }

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    /// @notice Initializes the Monster contract
    /// @param skinRegistryAddress Address of the skin registry contract
    /// @param nameRegistryAddress Address of the name registry contract
    /// @dev Reverts with BadZeroAddress if name registry address is zero
    constructor(address skinRegistryAddress, address nameRegistryAddress)
        Owned(msg.sender)
        Fighter(skinRegistryAddress)
    {
        if (nameRegistryAddress == address(0)) {
            revert BadZeroAddress();
        }
        _nameRegistry = IMonsterNameRegistry(nameRegistryAddress);
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    // View Functions
    /// @notice Gets the name registry contract reference
    /// @return The MonsterNameRegistry contract instance
    function nameRegistry() public view returns (IMonsterNameRegistry) {
        return _nameRegistry;
    }

    /// @notice Check if a monster ID is valid
    /// @param monsterId The ID to check
    /// @return bool True if the ID is within valid monster range
    function isValidId(uint32 monsterId) public pure override(Fighter, IMonster) returns (bool) {
        return monsterId >= MONSTER_ID_START && monsterId <= MONSTER_ID_END;
    }

    /// @notice Get the current skin information for a monster
    /// @param monsterId The ID of the monster
    /// @return The monster's equipped skin information (index and token ID)
    function getCurrentSkin(uint32 monsterId) public view override(Fighter, IMonster) returns (SkinInfo memory) {
        MonsterStats memory stats = _monsters[monsterId];
        return stats.skin;
    }

    /// @notice Gets the complete stats for a monster
    /// @param monsterId The ID of the monster to query
    /// @return The monster's complete stats and attributes
    function getMonster(uint32 monsterId) external view monsterExists(monsterId) returns (MonsterStats memory) {
        return _monsters[monsterId];
    }

    /// @notice Checks if a monster is retired
    /// @param monsterId The ID of the monster to check
    /// @return True if the monster is retired
    function isMonsterRetired(uint32 monsterId) external view monsterExists(monsterId) returns (bool) {
        return _isRetired[monsterId];
    }

    /// @notice Checks if a monster is immortal
    /// @param monsterId The ID of the monster to check
    /// @return True if the monster is immortal
    function isMonsterImmortal(uint32 monsterId) external view monsterExists(monsterId) returns (bool) {
        return _isImmortal[monsterId];
    }

    /// @notice Gets the permissions for a game contract
    /// @param gameContract Address of the game contract to query
    /// @return The permissions granted to the game contract
    function gameContractPermissions(address gameContract) external view returns (GamePermissions memory) {
        return _gameContractPermissions[gameContract];
    }

    // State-Changing Functions
    /// @notice Creates a new monster with specified stats
    /// @param stats The stats for the new monster
    /// @return The ID of the created monster
    /// @dev Only callable by the contract owner
    function createMonster(MonsterStats memory stats) external onlyOwner returns (uint32) {
        if (_nextMonsterId > MONSTER_ID_END) revert InvalidMonsterRange();

        uint32 monsterId = _nextMonsterId++;
        _monsters[monsterId] = stats;

        emit MonsterCreated(monsterId, stats);
        return monsterId;
    }

    /// @notice Updates the stats of an existing monster
    /// @param monsterId The ID of the monster to update
    /// @param newStats The new stats to assign to the monster
    /// @dev Only callable by the contract owner, requires monster to exist
    function updateMonsterStats(uint32 monsterId, MonsterStats memory newStats)
        external
        onlyOwner
        monsterExists(monsterId)
    {
        _monsters[monsterId] = newStats;

        emit MonsterStatsUpdated(monsterId, newStats);
    }

    /// @notice Increments a monster's win count
    /// @param monsterId The ID of the monster
    /// @dev Requires RECORD permission
    function incrementWins(uint32 monsterId) external hasPermission(GamePermission.RECORD) monsterExists(monsterId) {
        _monsters[monsterId].record.wins++;
        emit MonsterWinLossUpdated(monsterId, _monsters[monsterId].record.wins, _monsters[monsterId].record.losses);
    }

    /// @notice Increments a monster's loss count
    /// @param monsterId The ID of the monster
    /// @dev Requires RECORD permission
    function incrementLosses(uint32 monsterId) external hasPermission(GamePermission.RECORD) monsterExists(monsterId) {
        _monsters[monsterId].record.losses++;
        emit MonsterWinLossUpdated(monsterId, _monsters[monsterId].record.wins, _monsters[monsterId].record.losses);
    }

    /// @notice Increments a monster's kill count
    /// @param monsterId The ID of the monster
    /// @dev Requires RECORD permission
    function incrementKills(uint32 monsterId) external hasPermission(GamePermission.RECORD) monsterExists(monsterId) {
        _monsters[monsterId].record.kills++;
        emit MonsterKillsUpdated(monsterId, _monsters[monsterId].record.kills);
    }

    /// @notice Sets a monster's retirement status
    /// @param monsterId The ID of the monster
    /// @param retired The new retirement status
    /// @dev Requires RETIRE permission
    function setMonsterRetired(uint32 monsterId, bool retired)
        external
        hasPermission(GamePermission.RETIRE)
        monsterExists(monsterId)
    {
        _isRetired[monsterId] = retired;
        emit MonsterRetired(monsterId, retired);
    }

    /// @notice Sets a monster's immortality status
    /// @param monsterId The ID of the monster
    /// @param immortal The new immortality status
    /// @dev Requires IMMORTAL permission
    function setMonsterImmortal(uint32 monsterId, bool immortal)
        external
        hasPermission(GamePermission.IMMORTAL)
        monsterExists(monsterId)
    {
        _isImmortal[monsterId] = immortal;
        emit MonsterImmortalStatusUpdated(monsterId, immortal);
    }

    /// @notice Sets permissions for a game contract
    /// @param gameContract Address of the game contract
    /// @param permissions Permission flags to set
    /// @dev Only callable by the contract owner
    function setGameContractPermissions(address gameContract, GamePermissions memory permissions) external onlyOwner {
        _gameContractPermissions[gameContract] = permissions;
        emit GameContractPermissionsUpdated(gameContract, permissions);
    }

    //==============================================================//
    //                    INTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Get the base attributes for a monster
    /// @param monsterId The ID of the monster
    /// @return attributes The monster's base attributes
    /// @dev Used by the Fighter base contract for stat-based calculations
    function getFighterAttributes(uint32 monsterId) internal view override returns (Attributes memory) {
        MonsterStats memory stats = _monsters[monsterId];
        return stats.attributes;
    }
}

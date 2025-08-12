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

    /// @notice Maps monster ID to their stats progression across all levels
    /// @dev Each monster has complete stats for levels 1-10
    mapping(uint32 => MonsterStats[10]) private _monsterProgressions;

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
        if (_monsterProgressions[monsterId][0].attributes.strength == 0) {
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
        revert("Monster: Use getSkinAtLevel - level must be specified");
    }

    /// @notice Gets the current stance for a monster
    /// @param monsterId The ID of the monster to query
    /// @return The monster's current stance
    function getCurrentStance(uint32 monsterId) public view override(Fighter, IMonster) returns (uint8) {
        revert("Monster: Use getStanceAtLevel - level must be specified");
    }

    /// @notice Get the current attributes for a monster
    /// @param monsterId The ID of the monster
    /// @return attributes The monster's current base attributes
    function getCurrentAttributes(uint32 monsterId)
        public
        view
        override(Fighter, IMonster)
        returns (Attributes memory)
    {
        revert("Monster: Use getAttributesAtLevel - level must be specified");
    }

    /// @notice Get the current combat record for a monster
    /// @param monsterId The ID of the monster
    /// @return The monster's current win/loss/kill record
    function getCurrentRecord(uint32 monsterId) public view override(Fighter, IMonster) returns (Record memory) {
        revert("Monster: Use getRecordAtLevel - level must be specified");
    }

    /// @notice Get the current name for a monster
    /// @param monsterId The ID of the monster
    /// @return The monster's current name
    function getCurrentName(uint32 monsterId)
        public
        view
        override(IMonster)
        monsterExists(monsterId)
        returns (MonsterName memory)
    {
        // Name is consistent across all levels, return from level 1
        return _monsterProgressions[monsterId][0].name;
    }

    /// @notice Get the current level for a monster
    /// @param monsterId The ID of the monster
    /// @return The monster's current level
    function getCurrentLevel(uint32 monsterId) public view override(IMonster) returns (uint8) {
        revert("Monster: Use getMonsterAtLevel - level must be specified");
    }

    /// @notice Gets the complete stats for a monster at a specific level
    /// @param monsterId The ID of the monster to query
    /// @param level The level to get stats for (1-10)
    /// @return The monster's complete stats and attributes at the specified level
    function getMonster(uint32 monsterId, uint8 level)
        external
        view
        monsterExists(monsterId)
        returns (MonsterStats memory)
    {
        require(level >= 1 && level <= 10, "Invalid level");
        return _monsterProgressions[monsterId][level - 1];
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

    /// @notice Gets the skin registry contract reference
    /// @return The PlayerSkinRegistry contract instance
    function skinRegistry() public view override(Fighter, IMonster) returns (IPlayerSkinRegistry) {
        return super.skinRegistry();
    }

    // State-Changing Functions
    /// @notice Creates a new monster with specified stats for all levels
    /// @param allLevelStats Array of stats for levels 1-10
    /// @return The ID of the created monster
    /// @dev Only callable by the contract owner
    function createMonster(MonsterStats[10] memory allLevelStats) external onlyOwner returns (uint32) {
        if (_nextMonsterId > MONSTER_ID_END) revert InvalidMonsterRange();

        uint32 monsterId = _nextMonsterId++;
        _monsterProgressions[monsterId] = allLevelStats;

        emit MonsterCreated(monsterId, allLevelStats[0]); // Emit level 1 stats for backwards compatibility
        return monsterId;
    }

    /// @notice Updates the stats of an existing monster for all levels
    /// @param monsterId The ID of the monster to update
    /// @param newAllLevelStats The new stats to assign to the monster for all levels 1-10
    /// @dev Only callable by the contract owner, requires monster to exist
    function updateMonsterStats(uint32 monsterId, MonsterStats[10] memory newAllLevelStats)
        external
        onlyOwner
        monsterExists(monsterId)
    {
        _monsterProgressions[monsterId] = newAllLevelStats;

        emit MonsterStatsUpdated(monsterId, newAllLevelStats[0]); // Emit level 1 stats for backwards compatibility
    }

    /// @notice Increments a monster's win count across all levels
    /// @param monsterId The ID of the monster
    /// @dev Requires RECORD permission
    function incrementWins(uint32 monsterId) external hasPermission(GamePermission.RECORD) monsterExists(monsterId) {
        // Update wins across all levels
        for (uint8 i = 0; i < 10; i++) {
            _monsterProgressions[monsterId][i].record.wins++;
        }
        emit MonsterWinLossUpdated(
            monsterId, _monsterProgressions[monsterId][0].record.wins, _monsterProgressions[monsterId][0].record.losses
        );
    }

    /// @notice Increments a monster's loss count across all levels
    /// @param monsterId The ID of the monster
    /// @dev Requires RECORD permission
    function incrementLosses(uint32 monsterId) external hasPermission(GamePermission.RECORD) monsterExists(monsterId) {
        // Update losses across all levels
        for (uint8 i = 0; i < 10; i++) {
            _monsterProgressions[monsterId][i].record.losses++;
        }
        emit MonsterWinLossUpdated(
            monsterId, _monsterProgressions[monsterId][0].record.wins, _monsterProgressions[monsterId][0].record.losses
        );
    }

    /// @notice Increments a monster's kill count across all levels
    /// @param monsterId The ID of the monster
    /// @dev Requires RECORD permission
    function incrementKills(uint32 monsterId) external hasPermission(GamePermission.RECORD) monsterExists(monsterId) {
        // Update kills across all levels
        for (uint8 i = 0; i < 10; i++) {
            _monsterProgressions[monsterId][i].record.kills++;
        }
        emit MonsterKillsUpdated(monsterId, _monsterProgressions[monsterId][0].record.kills);
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
    //                  LEVEL-AWARE IMPLEMENTATIONS                 //
    //==============================================================//
    /// @notice Get attributes for a monster at a specific level
    /// @param monsterId The ID of the monster
    /// @param level The level to get attributes for (1-10)
    /// @return attributes The monster's attributes at the specified level
    function getAttributesAtLevel(uint32 monsterId, uint8 level)
        public
        view
        override
        monsterExists(monsterId)
        returns (Attributes memory)
    {
        require(level >= 1 && level <= 10, "Invalid level");
        return _monsterProgressions[monsterId][level - 1].attributes;
    }

    /// @notice Get stance for a monster at a specific level
    /// @param monsterId The ID of the monster
    /// @param level The level to get stance for (1-10)
    /// @return The monster's stance at the specified level
    function getStanceAtLevel(uint32 monsterId, uint8 level)
        public
        view
        override
        monsterExists(monsterId)
        returns (uint8)
    {
        require(level >= 1 && level <= 10, "Invalid level");
        return _monsterProgressions[monsterId][level - 1].stance;
    }

    /// @notice Get skin for a monster at a specific level
    /// @param monsterId The ID of the monster
    /// @param level The level to get skin for (1-10)
    /// @return The monster's skin at the specified level
    function getSkinAtLevel(uint32 monsterId, uint8 level)
        public
        view
        override
        monsterExists(monsterId)
        returns (SkinInfo memory)
    {
        require(level >= 1 && level <= 10, "Invalid level");
        return _monsterProgressions[monsterId][level - 1].skin;
    }

    /// @notice Get record for a monster at a specific level
    /// @param monsterId The ID of the monster
    /// @param level The level to get record for (1-10)
    /// @return The monster's record at the specified level
    function getRecordAtLevel(uint32 monsterId, uint8 level)
        public
        view
        override
        monsterExists(monsterId)
        returns (Record memory)
    {
        require(level >= 1 && level <= 10, "Invalid level");
        return _monsterProgressions[monsterId][level - 1].record;
    }
}

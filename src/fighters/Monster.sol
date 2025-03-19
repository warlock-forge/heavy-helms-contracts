// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../interfaces/fighters/IMonster.sol";
import "../interfaces/fighters/registries/names/IMonsterNameRegistry.sol";
import "solmate/src/auth/Owned.sol";
import "./Fighter.sol";

error InvalidMonsterRange();
error MonsterDoesNotExist();
error UnauthorizedCaller();
error BadZeroAddress();

contract Monster is IMonster, Owned, Fighter {
    IMonsterNameRegistry private immutable _nameRegistry;

    function nameRegistry() public view returns (IMonsterNameRegistry) {
        return _nameRegistry;
    }

    // Constants for ID range
    uint32 private constant MONSTER_ID_START = 2001;
    uint32 private constant MONSTER_ID_END = 10000;
    uint32 private _nextMonsterId = MONSTER_ID_START;

    // Core state
    mapping(uint32 => MonsterStats) private _monsters;
    mapping(uint32 => bool) private _isRetired;
    mapping(uint32 => bool) private _isImmortal;

    // Maps game contract address to their granted permissions
    mapping(address => GamePermissions) private _gameContractPermissions;

    /// @notice Permission flags for game contracts
    /// @param record Can modify game records (wins, losses, kills)
    /// @param retire Can modify monster retirement status
    /// @param immortal Monster cannot be retired
    struct GamePermissions {
        bool record;
        bool retire;
        bool immortal;
    }

    /// @notice Types of permissions that can be granted to game contracts
    enum GamePermission {
        RECORD, // Can modify wins/losses/kills
        RETIRE, // Can retire monsters
        IMMORTAL // Cannot be retired

    }

    modifier hasPermission(GamePermission permission) {
        GamePermissions memory permissions = _gameContractPermissions[msg.sender];
        bool hasAccess = msg.sender == owner // Owner has all permissions
            || (permission == GamePermission.RECORD && permissions.record)
            || (permission == GamePermission.RETIRE && permissions.retire)
            || (permission == GamePermission.IMMORTAL && permissions.immortal);
        if (!hasAccess) revert UnauthorizedCaller();
        _;
    }

    // Add events
    event MonsterWinLossUpdated(uint32 indexed monsterId, uint16 wins, uint16 losses);
    event MonsterKillsUpdated(uint32 indexed monsterId, uint16 kills);
    event MonsterImmortalStatusUpdated(uint32 indexed monsterId, bool immortal);
    event MonsterTierUpdated(uint16 indexed tokenId, uint8 newTier);
    event MonsterStatsUpdated(uint32 indexed monsterId, MonsterStats stats);

    constructor(address skinRegistryAddress, address nameRegistryAddress)
        Owned(msg.sender)
        Fighter(skinRegistryAddress)
    {
        if (nameRegistryAddress == address(0)) {
            revert BadZeroAddress();
        }
        _nameRegistry = IMonsterNameRegistry(nameRegistryAddress);
    }

    function createMonster(MonsterStats memory stats) external onlyOwner returns (uint32) {
        if (_nextMonsterId > MONSTER_ID_END) revert InvalidMonsterRange();

        uint32 monsterId = _nextMonsterId++;
        _monsters[monsterId] = stats;

        emit MonsterCreated(monsterId);
        return monsterId;
    }

    /// @notice Ensures the monster ID is within valid range and exists
    /// @param monsterId The ID of the monster to check
    modifier monsterExists(uint32 monsterId) {
        if (!isValidId(monsterId)) {
            revert InvalidMonsterRange();
        }
        if (_monsters[monsterId].attributes.strength == 0) {
            revert MonsterDoesNotExist();
        }
        _;
    }

    function getMonster(uint32 monsterId) external view monsterExists(monsterId) returns (MonsterStats memory) {
        return _monsters[monsterId];
    }

    function isMonsterRetired(uint32 monsterId) external view monsterExists(monsterId) returns (bool) {
        return _isRetired[monsterId];
    }

    function isMonsterImmortal(uint32 monsterId) external view monsterExists(monsterId) returns (bool) {
        return _isImmortal[monsterId];
    }

    function incrementWins(uint32 monsterId) external hasPermission(GamePermission.RECORD) monsterExists(monsterId) {
        _monsters[monsterId].record.wins++;
        emit MonsterWinLossUpdated(monsterId, _monsters[monsterId].record.wins, _monsters[monsterId].record.losses);
    }

    function incrementLosses(uint32 monsterId) external hasPermission(GamePermission.RECORD) monsterExists(monsterId) {
        _monsters[monsterId].record.losses++;
        emit MonsterWinLossUpdated(monsterId, _monsters[monsterId].record.wins, _monsters[monsterId].record.losses);
    }

    function incrementKills(uint32 monsterId) external hasPermission(GamePermission.RECORD) monsterExists(monsterId) {
        _monsters[monsterId].record.kills++;
        emit MonsterKillsUpdated(monsterId, _monsters[monsterId].record.kills);
    }

    function setMonsterRetired(uint32 monsterId, bool retired) external onlyOwner monsterExists(monsterId) {
        _isRetired[monsterId] = retired;
        emit MonsterRetired(monsterId);
    }

    function setMonsterImmortal(uint32 monsterId, bool immortal)
        external
        hasPermission(GamePermission.IMMORTAL)
        monsterExists(monsterId)
    {
        _isImmortal[monsterId] = immortal;
        emit MonsterImmortalStatusUpdated(monsterId, immortal);
    }

    function setGameContractPermissions(address gameContract, GamePermissions memory permissions) external onlyOwner {
        _gameContractPermissions[gameContract] = permissions;
    }

    function updateMonsterStats(uint32 monsterId, MonsterStats memory newStats)
        external
        onlyOwner
        monsterExists(monsterId)
    {
        if (_isRetired[monsterId]) revert("Cannot update retired monster");
        if (_isImmortal[monsterId]) revert("Cannot update immortal monster");

        _monsters[monsterId] = newStats;

        emit MonsterStatsUpdated(monsterId, newStats);
    }

    /// @notice Check if a monster ID is valid
    /// @param monsterId The ID to check
    /// @return bool True if the ID is within valid monster range
    function isValidId(uint32 monsterId) public pure override returns (bool) {
        return monsterId >= MONSTER_ID_START && monsterId <= MONSTER_ID_END;
    }

    /// @notice Get the current skin information for a monster
    /// @param monsterId The ID of the monster
    /// @return The monster's equipped skin information (index and token ID)
    function getCurrentSkin(uint32 monsterId) public view override returns (SkinInfo memory) {
        MonsterStats memory stats = _monsters[monsterId];
        return stats.skin;
    }

    /// @notice Get the base attributes for a monster
    /// @param monsterId The ID of the monster
    /// @return attributes The monster's base attributes
    function getFighterAttributes(uint32 monsterId) internal view override returns (Attributes memory) {
        MonsterStats memory stats = _monsters[monsterId];
        return stats.attributes;
    }
}

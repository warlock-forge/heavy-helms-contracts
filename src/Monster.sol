// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IMonster.sol";
import "./interfaces/IPlayerSkinRegistry.sol";
import "./interfaces/IPlayerNameRegistry.sol";
import "solmate/src/auth/Owned.sol";

contract Monster is IMonster, Owned {
    IPlayerSkinRegistry public immutable skinRegistry;
    IPlayerNameRegistry public immutable nameRegistry;

    // Constants for ID range
    uint32 private constant MONSTER_ID_START = 2001;
    uint32 private constant MONSTER_ID_END = 10000;
    uint32 private _nextMonsterId = MONSTER_ID_START;

    // Core state
    mapping(uint32 => MonsterStats) private _monsters;
    mapping(uint32 => bool) private _isRetired;
    mapping(uint32 => bool) private _isImmortal;

    // Errors
    error InvalidMonsterRange();
    error MonsterDoesNotExist();
    error UnauthorizedCaller();
    error BadZeroAddress();

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

    constructor(address skinRegistryAddress, address nameRegistryAddress) Owned(msg.sender) {
        if (skinRegistryAddress == address(0) || nameRegistryAddress == address(0)) {
            revert BadZeroAddress();
        }
        skinRegistry = IPlayerSkinRegistry(skinRegistryAddress);
        nameRegistry = IPlayerNameRegistry(nameRegistryAddress);
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
        if (monsterId < MONSTER_ID_START || monsterId > MONSTER_ID_END) {
            revert InvalidMonsterRange();
        }
        if (_monsters[monsterId].strength == 0) {
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
        _monsters[monsterId].wins++;
        emit MonsterWinLossUpdated(monsterId, _monsters[monsterId].wins, _monsters[monsterId].losses);
    }

    function incrementLosses(uint32 monsterId) external hasPermission(GamePermission.RECORD) monsterExists(monsterId) {
        _monsters[monsterId].losses++;
        emit MonsterWinLossUpdated(monsterId, _monsters[monsterId].wins, _monsters[monsterId].losses);
    }

    function incrementKills(uint32 monsterId) external hasPermission(GamePermission.RECORD) monsterExists(monsterId) {
        _monsters[monsterId].kills++;
        emit MonsterKillsUpdated(monsterId, _monsters[monsterId].kills);
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
}

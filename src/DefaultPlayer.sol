// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IDefaultPlayer.sol";
import "./interfaces/IPlayerSkinRegistry.sol";
import "./interfaces/IPlayerNameRegistry.sol";
import "./lib/GameHelpers.sol";
import "solmate/src/auth/Owned.sol";

error PlayerDoesNotExist(uint32 playerId);
error InvalidDefaultPlayerRange();
error BadZeroAddress();
error InvalidNameIndex();

contract DefaultPlayer is IDefaultPlayer, Owned {
    IPlayerSkinRegistry public immutable skinRegistry;
    IPlayerNameRegistry public immutable nameRegistry;

    // Maps default player ID to their stats
    mapping(uint32 => DefaultPlayerStats) private _defaultPlayers;

    event DefaultPlayerStatsUpdated(uint32 indexed playerId, DefaultPlayerStats stats);

    // Constants
    uint32 private constant DEFAULT_PLAYER_START = 1;
    uint32 private constant DEFAULT_PLAYER_END = 2000;

    constructor(address skinRegistryAddress, address nameRegistryAddress) Owned(msg.sender) {
        if (skinRegistryAddress == address(0) || nameRegistryAddress == address(0)) {
            revert BadZeroAddress();
        }
        skinRegistry = IPlayerSkinRegistry(skinRegistryAddress);
        nameRegistry = IPlayerNameRegistry(nameRegistryAddress);
    }

    /// @notice Ensures the default player ID is within valid range and exists
    /// @param playerId The ID of the default player to check
    modifier defaultPlayerExists(uint32 playerId) {
        if (playerId < DEFAULT_PLAYER_START || playerId > DEFAULT_PLAYER_END) {
            revert InvalidDefaultPlayerRange();
        }
        if (_defaultPlayers[playerId].strength == 0) {
            revert PlayerDoesNotExist(playerId);
        }
        _;
    }

    function getDefaultPlayer(uint32 playerId)
        external
        view
        defaultPlayerExists(playerId)
        returns (DefaultPlayerStats memory)
    {
        return _defaultPlayers[playerId];
    }

    function setDefaultPlayer(uint32 playerId, DefaultPlayerStats memory stats) external onlyOwner {
        if (playerId < DEFAULT_PLAYER_START || playerId > DEFAULT_PLAYER_END) {
            revert InvalidDefaultPlayerRange();
        }

        // Verify skin exists and is valid
        skinRegistry.getSkin(stats.skinIndex);

        // Validate name indices
        if (
            !nameRegistry.isValidFirstNameIndex(stats.firstNameIndex)
                || stats.surnameIndex >= nameRegistry.getSurnamesLength()
        ) {
            revert InvalidNameIndex();
        }

        _defaultPlayers[playerId] = stats;
    }

    function updateDefaultPlayerStats(uint32 playerId, DefaultPlayerStats memory newStats)
        external
        onlyOwner
        defaultPlayerExists(playerId)
    {
        // Verify skin exists and is valid
        skinRegistry.getSkin(newStats.skinIndex);

        // Validate name indices
        if (
            !nameRegistry.isValidFirstNameIndex(newStats.firstNameIndex)
                || newStats.surnameIndex >= nameRegistry.getSurnamesLength()
        ) {
            revert InvalidNameIndex();
        }

        _defaultPlayers[playerId] = newStats;

        emit DefaultPlayerStatsUpdated(playerId, newStats);
    }
}

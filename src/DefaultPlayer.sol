// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IPlayer.sol";
import "./lib/GameHelpers.sol";
import "solmate/src/auth/Owned.sol";

error PlayerDoesNotExist(uint32 playerId);
error InvalidDefaultPlayerRange();

contract DefaultPlayer is Owned {
    // Maps default player ID to their stats
    mapping(uint32 => IPlayer.PlayerStats) private _defaultPlayers;

    // Constants
    uint32 private constant DEFAULT_PLAYER_START = 1;
    uint32 private constant DEFAULT_PLAYER_END = 2000;

    constructor() Owned(msg.sender) {}

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
        returns (IPlayer.PlayerStats memory)
    {
        return _defaultPlayers[playerId];
    }

    function setDefaultPlayer(uint32 playerId, IPlayer.PlayerStats memory stats) external onlyOwner {
        if (playerId < DEFAULT_PLAYER_START || playerId > DEFAULT_PLAYER_END) {
            revert InvalidDefaultPlayerRange();
        }

        _defaultPlayers[playerId] = stats;
    }
}

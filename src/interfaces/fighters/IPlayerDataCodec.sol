// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "./IPlayer.sol";

/// @title IPlayerDataCodec
/// @notice Interface for encoding and decoding player data for efficient storage/transmission
/// @dev Used by Player contract and game modes for data packing
interface IPlayerDataCodec {
    /// @notice Packs player data into a compact bytes32 format for efficient storage/transmission
    /// @param playerId The ID of the player to encode
    /// @param stats The player's stats and attributes to encode
    /// @return Packed bytes32 representation of the player data
    /// @dev Encodes all player attributes, skin info, and combat-relevant data into 32 bytes
    function encodePlayerData(uint32 playerId, IPlayer.PlayerStats memory stats) external pure returns (bytes32);

    /// @notice Unpacks player data from bytes32 format back into structured data
    /// @param data The packed bytes32 data to decode
    /// @return playerId The decoded player ID
    /// @return stats The decoded player stats and attributes
    /// @dev Reverses the encoding process from encodePlayerData
    function decodePlayerData(bytes32 data) external pure returns (uint32 playerId, IPlayer.PlayerStats memory stats);
}

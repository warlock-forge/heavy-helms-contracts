// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IPlayer.sol";
import "./IPlayerSkinNFT.sol";
import "../PlayerSkinRegistry.sol";

interface IGameEngine {
    /// @notice Returns the current version of the game engine
    function version() external pure returns (uint16);

    /// @notice Decodes a version number into major and minor components
    /// @param _version The version number to decode
    /// @return major The major version number (0-255)
    /// @return minor The minor version number (0-255)
    function decodeVersion(uint16 _version) external pure returns (uint8 major, uint8 minor);

    struct PlayerLoadout {
        uint32 playerId;
        uint32 skinIndex;
        uint16 skinTokenId;
    }

    /// @notice Process a game between two players
    /// @param player1 The first player's loadout
    /// @param player2 The second player's loadout
    /// @param randomSeed The random seed for the game
    /// @param playerContract The player contract to get stats from
    /// @return A byte array containing the encoded combat log
    function processGame(
        PlayerLoadout memory player1,
        PlayerLoadout memory player2,
        uint256 randomSeed,
        IPlayer playerContract
    ) external view returns (bytes memory);
}

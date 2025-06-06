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
import "../../fighters/Fighter.sol";
import "../fighters/IPlayer.sol";
import "./registries/names/IPlayerNameRegistry.sol";
import "./registries/skins/IPlayerSkinRegistry.sol";

//==============================================================//
//                         HEAVY HELMS                          //
//                   DEFAULT PLAYER INTERFACE                   //
//==============================================================//
/// @title Default Player Interface for Heavy Helms
/// @notice Defines the core functionality for default player management and game interactions
/// @dev Used for managing pre-created characters
interface IDefaultPlayer {
    //==============================================================//
    //                    VIEW FUNCTIONS                            //
    //==============================================================//
    /// @notice Get a reference to the name registry
    /// @return The PlayerNameRegistry contract instance
    function nameRegistry() external view returns (IPlayerNameRegistry);

    /// @notice Gets the skin registry contract reference
    /// @return The PlayerSkinRegistry contract instance
    function skinRegistry() external view returns (IPlayerSkinRegistry);

    /// @notice Get the complete stats for a default player
    /// @param playerId The ID of the default player to query
    /// @return PlayerStats struct containing all player data
    function getDefaultPlayer(uint32 playerId) external view returns (IPlayer.PlayerStats memory);

    /// @notice Check if a default player ID is valid
    /// @param playerId The ID to check
    /// @return bool True if the ID is within valid default player range
    function isValidId(uint32 playerId) external pure returns (bool);

    /// @notice Get the current skin information for a default player
    /// @param playerId The ID of the default player
    /// @return The default player's equipped skin information (index and token ID)
    function getCurrentSkin(uint32 playerId) external view returns (Fighter.SkinInfo memory);

    /// @notice Gets the current stance for a default player
    /// @param playerId The ID of the default player to query
    /// @return The default player's current stance
    function getCurrentStance(uint32 playerId) external view returns (uint8);

    /// @notice Get the current attributes for a default player
    /// @param playerId The ID of the default player
    /// @return attributes The default player's current base attributes
    function getCurrentAttributes(uint32 playerId) external view returns (Fighter.Attributes memory);

    /// @notice Get the current combat record for a default player
    /// @param playerId The ID of the default player
    /// @return The default player's current win/loss/kill record
    function getCurrentRecord(uint32 playerId) external view returns (Fighter.Record memory);

    /// @notice Get the current name for a default player
    /// @param playerId The ID of the default player
    /// @return The default player's current name
    function getCurrentName(uint32 playerId) external view returns (IPlayer.PlayerName memory);

    //==============================================================//
    //                 STATE-CHANGING FUNCTIONS                     //
    //==============================================================//
    /// @notice Create or update a default player with the provided stats
    /// @param playerId The ID of the default player to create/update
    /// @param stats The complete stats to assign to the player
    /// @dev Only callable by the contract owner
    function createDefaultPlayer(uint32 playerId, IPlayer.PlayerStats memory stats) external;

    /// @notice Update the stats of an existing default player
    /// @param playerId The ID of the default player to update
    /// @param newStats The new stats to assign to the player
    /// @dev Only callable by the contract owner, requires player to exist
    function updateDefaultPlayerStats(uint32 playerId, IPlayer.PlayerStats memory newStats) external;
}

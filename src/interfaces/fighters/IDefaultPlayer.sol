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
import {IPlayer} from "./IPlayer.sol";
import {IPlayerNameRegistry} from "./registries/names/IPlayerNameRegistry.sol";
import {IPlayerSkinRegistry} from "./registries/skins/IPlayerSkinRegistry.sol";

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

    /// @notice Get the complete stats for a default player at a specific level
    /// @param playerId The ID of the default player to query
    /// @param level The level to get stats for (1-10)
    /// @return PlayerStats struct containing all player data at the specified level
    function getDefaultPlayer(uint32 playerId, uint8 level) external view returns (IPlayer.PlayerStats memory);

    /// @notice Check if a default player ID is valid
    /// @param playerId The ID to check
    /// @return bool True if the ID is within valid default player range
    function isValidId(uint32 playerId) external pure returns (bool);

    /// @notice Gets a valid default player ID by index
    /// @param index The index in the valid IDs array (0 to validDefaultPlayerCount-1)
    /// @return The default player ID at that index
    function getValidDefaultPlayerId(uint256 index) external view returns (uint32);

    /// @notice Gets the count of valid default players created
    /// @return The number of valid default player IDs
    function validDefaultPlayerCount() external view returns (uint256);

    //==============================================================//
    //                 STATE-CHANGING FUNCTIONS                     //
    //==============================================================//
    /// @notice Create or update a default player with the provided stats for all levels
    /// @param playerId The ID of the default player to create/update
    /// @param allLevelStats The complete stats to assign to the player for all levels 1-10
    /// @dev Only callable by the contract owner
    function createDefaultPlayer(uint32 playerId, IPlayer.PlayerStats[10] memory allLevelStats) external;

    /// @notice Update the stats of an existing default player for all levels
    /// @param playerId The ID of the default player to update
    /// @param newAllLevelStats The new stats to assign to the player for all levels 1-10
    /// @dev Only callable by the contract owner, requires player to exist
    function updateDefaultPlayerStats(uint32 playerId, IPlayer.PlayerStats[10] memory newAllLevelStats) external;
}

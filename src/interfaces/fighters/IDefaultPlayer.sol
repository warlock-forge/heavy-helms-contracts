// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import "../../fighters/Fighter.sol";
import "../fighters/IPlayer.sol";
import "./registries/names/IPlayerNameRegistry.sol";

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

    /// @notice Get the complete stats for a default player
    /// @param playerId The ID of the default player to query
    /// @return PlayerStats struct containing all player data
    function getDefaultPlayer(uint32 playerId) external view returns (IPlayer.PlayerStats memory);

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

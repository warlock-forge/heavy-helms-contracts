// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "./IPlayer.sol";

/// @title IPlayerCreation
/// @notice Interface for the PlayerCreation helper contract
/// @dev Used by Player contract to generate player stats and names
interface IPlayerCreation {
    /// @notice Generates complete player data from random seed
    /// @param randomSeed Random seed for stat and name generation
    /// @param useNameSetB Whether to use name set B for first name generation
    /// @return stats Complete player stats struct
    function generatePlayerData(uint256 randomSeed, bool useNameSetB)
        external
        view
        returns (IPlayer.PlayerStats memory stats);
}

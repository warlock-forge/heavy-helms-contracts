// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IMonsterNameRegistry {
    /// @notice Gets a monster's full name by index
    /// @param nameIndex The index of the name to retrieve
    /// @return The monster's full name
    function getMonsterName(uint16 nameIndex) external view returns (string memory);

    /// @notice Gets the total number of monster names
    /// @return The number of names in the registry
    function getMonsterNamesLength() external view returns (uint16);
}

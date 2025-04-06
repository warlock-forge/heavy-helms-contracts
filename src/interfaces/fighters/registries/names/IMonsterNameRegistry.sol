// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

//==============================================================//
//                    MONSTER NAME REGISTRY                     //
//                          INTERFACE                           //
//==============================================================//
/// @title Monster Name Registry Interface for Heavy Helms
/// @notice Defines functionality for managing monster name collections
interface IMonsterNameRegistry {
    //==============================================================//
    //                       VIEW FUNCTIONS                         //
    //==============================================================//
    /// @notice Gets a monster's full name by index
    /// @param nameIndex The index of the name to retrieve
    /// @return The monster's full name
    function getMonsterName(uint16 nameIndex) external view returns (string memory);

    /// @notice Gets the total number of monster names
    /// @return The number of names in the registry
    function getMonsterNamesLength() external view returns (uint16);

    //==============================================================//
    //                    STATE-CHANGING FUNCTIONS                  //
    //==============================================================//
    /// @notice Add monster names to the registry
    /// @param names Array of names to add
    /// @dev Only callable by the contract owner
    function addMonsterNames(string[] calldata names) external;
}

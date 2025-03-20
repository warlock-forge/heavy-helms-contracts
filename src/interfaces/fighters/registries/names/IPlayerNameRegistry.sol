// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//==============================================================//
//                    PLAYER NAME REGISTRY                      //
//                          INTERFACE                           //
//==============================================================//
/// @title Player Name Registry Interface for Heavy Helms
/// @notice Defines functionality for managing player name collections
interface IPlayerNameRegistry {
    //==============================================================//
    //                       VIEW FUNCTIONS                         //
    //==============================================================//
    /// @notice Gets the starting index for name set A
    /// @return The index where name set A begins
    function getSetAStart() external view returns (uint16);

    /// @notice Gets the number of names in name set B
    /// @return The count of names in set B
    function getNameSetBLength() external view returns (uint16);

    /// @notice Gets the number of names in name set A
    /// @return The count of names in set A
    function getNameSetALength() external view returns (uint16);

    /// @notice Gets the number of surnames in the registry
    /// @return The count of surnames
    function getSurnamesLength() external view returns (uint16);

    /// @notice Gets the full name from name parts
    /// @param firstNameIndex Index of the first name
    /// @param surnameIndex Index of the surname
    /// @return firstName The first name as a string
    /// @return surname The surname as a string
    function getFullName(uint16 firstNameIndex, uint16 surnameIndex)
        external
        view
        returns (string memory firstName, string memory surname);

    /// @notice Check if a first name index is valid (exists in either Set A or Set B)
    /// @param index The index to check
    /// @return bool True if the index is valid
    function isValidFirstNameIndex(uint256 index) external view returns (bool);

    //==============================================================//
    //                    STATE-CHANGING FUNCTIONS                  //
    //==============================================================//
    /// @notice Add first names to Set A
    /// @param names Array of names to add
    /// @dev Only callable by the contract owner
    function addNamesToSetA(string[] calldata names) external;

    /// @notice Add first names to Set B
    /// @param names Array of names to add
    /// @dev Only callable by the contract owner
    function addNamesToSetB(string[] calldata names) external;

    /// @notice Add surnames to the registry
    /// @param names Array of surnames to add
    /// @dev Only callable by the contract owner
    function addSurnames(string[] calldata names) external;
}

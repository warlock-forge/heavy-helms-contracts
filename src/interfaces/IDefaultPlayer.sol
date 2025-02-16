// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Fighter.sol";

interface IDefaultPlayer {
    /// @notice Contains all stats and attributes for a default player
    /// @param attributes Core fighter attributes (strength, constitution, size, agility, stamina, luck)
    /// @param skinIndex Index of player skin/type
    /// @param skinTokenId Token ID of player skin/type
    /// @param firstNameIndex Index for first name in name registry
    /// @param surnameIndex Index for surname in name registry
    struct DefaultPlayerStats {
        Fighter.Attributes attributes;
        uint32 skinIndex;
        uint16 skinTokenId;
        uint16 firstNameIndex;
        uint16 surnameIndex;
    }

    function getDefaultPlayer(uint32 playerId) external view returns (DefaultPlayerStats memory);
    function setDefaultPlayer(uint32 playerId, DefaultPlayerStats memory stats) external;
}

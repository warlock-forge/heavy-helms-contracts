// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IDefaultPlayer {
    struct DefaultPlayerStats {
        uint8 strength;
        uint8 constitution;
        uint8 size;
        uint8 agility;
        uint8 stamina;
        uint8 luck;
        uint32 skinIndex;
        uint16 skinTokenId;
        uint16 firstNameIndex;
        uint16 surnameIndex;
    }

    function getDefaultPlayer(uint32 playerId) external view returns (DefaultPlayerStats memory);
}

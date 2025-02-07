// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPlayerNameRegistry {
    function SET_A_START() external view returns (uint16);
    function getNameSetBLength() external view returns (uint16);
    function getNameSetALength() external view returns (uint16);
    function getSurnamesLength() external view returns (uint16);
    function getFullName(uint16 firstNameIndex, uint16 surnameIndex)
        external
        view
        returns (string memory firstName, string memory surname);
}

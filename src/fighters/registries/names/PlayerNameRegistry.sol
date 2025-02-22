// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/src/auth/Owned.sol";
import "../../../interfaces/fighters/registries/names/IPlayerNameRegistry.sol";

error MaxNamesReached();
error MaxSetBNamesReached();
error MaxSurnamesReached();
error InvalidNameIndexSetA();
error InvalidNameIndexSetB();
error InvalidSurnameIndex();
error EmptyBatch();
error BatchTooLarge();
error InvalidNameLength();

contract PlayerNameRegistry is IPlayerNameRegistry, Owned {
    string[] public nameSetA;
    string[] public nameSetB;
    string[] public surnames;

    // Events
    event NameAdded(uint8 nameType, uint16 index, string name);

    // Constants
    uint16 public constant SET_B_MAX = 999;
    uint16 public constant SET_A_START = 1000;
    uint256 public constant MAX_BATCH_SIZE = 500;
    uint256 public constant MAX_NAME_LENGTH = 32;

    modifier validateNames(string[] calldata names) {
        uint256 length = names.length;
        if (length == 0) revert EmptyBatch();
        if (length > MAX_BATCH_SIZE) revert BatchTooLarge();
        for (uint256 i = 0; i < length; i++) {
            uint256 len = bytes(names[i]).length;
            if (len == 0 || len > MAX_NAME_LENGTH) revert InvalidNameLength();
        }
        _;
    }

    constructor() Owned(msg.sender) {}

    function addNamesToSetA(string[] calldata names) external onlyOwner validateNames(names) {
        uint16 newLength = uint16(nameSetA.length + names.length);
        if (SET_A_START + newLength > type(uint16).max) revert MaxNamesReached();

        for (uint256 i = 0; i < names.length; i++) {
            nameSetA.push(names[i]);
            emit NameAdded(0, SET_A_START + uint16(nameSetA.length) - 1, names[i]);
        }
    }

    function addNamesToSetB(string[] calldata names) external onlyOwner validateNames(names) {
        if (nameSetB.length + names.length > SET_B_MAX + 1) revert MaxSetBNamesReached();

        for (uint256 i = 0; i < names.length; i++) {
            nameSetB.push(names[i]);
            emit NameAdded(1, uint16(nameSetB.length - 1), names[i]);
        }
    }

    function addSurnames(string[] calldata names) external onlyOwner validateNames(names) {
        if (surnames.length + names.length > type(uint16).max) revert MaxSurnamesReached();

        for (uint256 i = 0; i < names.length; i++) {
            surnames.push(names[i]);
            emit NameAdded(2, uint16(surnames.length - 1), names[i]);
        }
    }

    function getFullName(uint16 firstNameIndex, uint16 surnameIndex)
        external
        view
        returns (string memory firstName, string memory surname)
    {
        if (firstNameIndex < SET_A_START) {
            if (firstNameIndex >= nameSetB.length) revert InvalidNameIndexSetB();
            firstName = nameSetB[firstNameIndex];
        } else {
            uint16 setAIndex = firstNameIndex - SET_A_START;
            if (setAIndex >= nameSetA.length) revert InvalidNameIndexSetA();
            firstName = nameSetA[setAIndex];
        }

        if (surnameIndex >= surnames.length) revert InvalidSurnameIndex();
        surname = surnames[surnameIndex];
    }

    // View functions
    function getNameSetALength() external view returns (uint16) {
        return uint16(nameSetA.length);
    }

    function getNameSetBLength() external view returns (uint16) {
        return uint16(nameSetB.length);
    }

    function getSurnamesLength() external view returns (uint16) {
        return uint16(surnames.length);
    }

    function isValidFirstNameIndex(uint256 index) external view returns (bool) {
        // Check Set B (0-999)
        if (index <= SET_B_MAX) {
            return index < nameSetB.length;
        }
        // Check Set A (1000+)
        if (index >= SET_A_START) {
            return index < SET_A_START + nameSetA.length;
        }
        return false;
    }
}

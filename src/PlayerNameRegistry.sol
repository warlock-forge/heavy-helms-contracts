// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/src/auth/Owned.sol";

error MaxNamesReached();
error MaxSetBNamesReached();
error MaxSurnamesReached();
error InvalidNameIndexSetA();
error InvalidNameIndexSetB();
error InvalidSurnameIndex();

contract PlayerNameRegistry is Owned {
    string[] public nameSetA;
    string[] public nameSetB;
    string[] public surnames;

    // Events
    event NameAdded(uint8 nameType, uint16 index, string name);

    // Constants
    uint16 public constant SET_B_MAX = 999;
    uint16 public constant SET_A_START = 1000;

    constructor() Owned(msg.sender) {
        // Add initial Set A names (masculine)
        nameSetA.push("Alex");
        nameSetA.push("Bob");
        nameSetA.push("Dan");
        nameSetA.push("Fred");
        nameSetA.push("Jim");
        nameSetA.push("Mike");
        nameSetA.push("Tom");
        nameSetA.push("Sam");
        nameSetA.push("Joe");
        nameSetA.push("Bill");

        // Add initial Set B names (feminine)
        nameSetB.push("Alex");
        nameSetB.push("Amy");
        nameSetB.push("Beth");
        nameSetB.push("Cora");
        nameSetB.push("Dawn");
        nameSetB.push("Eve");
        nameSetB.push("Fay");
        nameSetB.push("Gwen");
        nameSetB.push("Hope");
        nameSetB.push("Iris");

        // Add initial surnames/titles
        surnames.push("the Novice");
        surnames.push("the Apprentice");
        surnames.push("the Viking");
        surnames.push("the Balanced");
        surnames.push("the Impaler");
        surnames.push("the Pretty");
        surnames.push("Dragonheart");
        surnames.push("Shieldbreaker");
        surnames.push("Stormbringer");
        surnames.push("the Wise");
        surnames.push("Bloodaxe");
        surnames.push("Ironside");
        surnames.push("the Undefeated");
        surnames.push("Skullcrusher");
        surnames.push("the Swift");
        surnames.push("Grimheart");
        surnames.push("the Mighty");
        surnames.push("Frostborn");

        // Emit events for initial names
        for (uint256 i = 0; i < nameSetA.length; i++) {
            emit NameAdded(0, SET_A_START + uint16(i), nameSetA[i]);
        }
        for (uint256 i = 0; i < nameSetB.length; i++) {
            emit NameAdded(1, uint16(i), nameSetB[i]);
        }
        for (uint256 i = 0; i < surnames.length; i++) {
            emit NameAdded(2, uint16(i), surnames[i]);
        }
    }

    function addNameToSetA(string calldata name) external onlyOwner {
        uint16 newIndex = SET_A_START + uint16(nameSetA.length);
        if (newIndex >= type(uint16).max) revert MaxNamesReached();
        nameSetA.push(name);
        emit NameAdded(0, newIndex, name);
    }

    function addNameToSetB(string calldata name) external onlyOwner {
        if (nameSetB.length >= SET_B_MAX + 1) revert MaxSetBNamesReached();
        uint16 newIndex = uint16(nameSetB.length);
        nameSetB.push(name);
        emit NameAdded(1, newIndex, name);
    }

    function addSurname(string calldata name) external onlyOwner {
        if (surnames.length >= type(uint16).max) revert MaxSurnamesReached();
        surnames.push(name);
        emit NameAdded(2, uint16(surnames.length - 1), name);
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

    function addNamesToSetA(string[] calldata names) external onlyOwner {
        uint16 newLength = uint16(nameSetA.length + names.length);
        if (SET_A_START + newLength > type(uint16).max) revert MaxNamesReached();

        for (uint256 i = 0; i < names.length; i++) {
            nameSetA.push(names[i]);
            emit NameAdded(0, SET_A_START + uint16(nameSetA.length) - 1, names[i]);
        }
    }

    function addNamesToSetB(string[] calldata names) external onlyOwner {
        if (nameSetB.length + names.length > SET_B_MAX + 1) revert MaxSetBNamesReached();

        for (uint256 i = 0; i < names.length; i++) {
            nameSetB.push(names[i]);
            emit NameAdded(1, uint16(nameSetB.length - 1), names[i]);
        }
    }

    function addSurnames(string[] calldata names) external onlyOwner {
        for (uint256 i = 0; i < names.length; i++) {
            if (surnames.length >= type(uint16).max) revert MaxSurnamesReached();
            surnames.push(names[i]);
            emit NameAdded(2, uint16(surnames.length - 1), names[i]);
        }
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
}

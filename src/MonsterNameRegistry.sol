// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IMonsterNameRegistry.sol";
import "solmate/src/auth/Owned.sol";

error InvalidNameIndex();
error EmptyBatch();
error BatchTooLarge();
error InvalidNameLength();

contract MonsterNameRegistry is IMonsterNameRegistry, Owned {
    string[] public monsterNames;

    // Constants
    uint256 public constant MAX_BATCH_SIZE = 500;
    uint256 public constant MAX_NAME_LENGTH = 32;

    event NameAdded(uint16 indexed nameIndex, string name);

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

    constructor() Owned(msg.sender) {
        // Add empty name at index 0 for "nameless" monsters
        monsterNames.push("");
    }

    function getMonsterName(uint16 nameIndex) external view returns (string memory) {
        if (nameIndex >= monsterNames.length || nameIndex == 0) revert InvalidNameIndex();
        return monsterNames[nameIndex];
    }

    function getMonsterNamesLength() external view returns (uint16) {
        return uint16(monsterNames.length);
    }

    function addMonsterNames(string[] calldata names) external onlyOwner validateNames(names) {
        for (uint256 i = 0; i < names.length; i++) {
            monsterNames.push(names[i]);
            emit NameAdded(uint16(monsterNames.length - 1), names[i]);
        }
    }
}

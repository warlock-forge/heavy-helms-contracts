// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/src/auth/Owned.sol";

error MaxNamesReached();
error MaxSetBNamesReached();
error MaxSurnamesReached();
error InvalidNameIndexSetA();
error InvalidNameIndexSetB();
error InvalidSurnameIndex();
error EmptyBatch();
error BatchTooLarge();
error InvalidNameLength();

contract PlayerNameRegistry is Owned {
    string[] public nameSetA;
    string[] public nameSetB;
    string[] public surnames;

    // Events
    event NameAdded(uint8 nameType, uint16 index, string name);

    // Constants
    uint16 public constant SET_B_MAX = 999;
    uint16 public constant SET_A_START = 1000;
    uint256 public constant MAX_BATCH_SIZE = 100;
    uint256 public constant MAX_NAME_LENGTH = 32;

    modifier validateNames(string[] calldata names) {
        if (names.length == 0) revert EmptyBatch();
        if (names.length > MAX_BATCH_SIZE) revert BatchTooLarge();
        for (uint256 i = 0; i < names.length; i++) {
            uint256 len = bytes(names[i]).length;
            if (len == 0 || len > MAX_NAME_LENGTH) revert InvalidNameLength();
        }
        _;
    }

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
        nameSetA.push("Gary");
        nameSetA.push("Adam");
        nameSetA.push("Ben");
        nameSetA.push("Carl");
        nameSetA.push("Dave");
        nameSetA.push("Eric");
        nameSetA.push("Greg");
        nameSetA.push("Hans");
        nameSetA.push("Ian");
        nameSetA.push("Jack");
        nameSetA.push("Ken");
        nameSetA.push("Luke");
        nameSetA.push("Mark");
        nameSetA.push("Nick");
        nameSetA.push("Owen");
        nameSetA.push("Paul");
        nameSetA.push("Rick");
        nameSetA.push("Steve");
        nameSetA.push("Tim");
        nameSetA.push("Wade");
        nameSetA.push("Will");
        nameSetA.push("Zack");
        nameSetA.push("Brad");
        nameSetA.push("Chad");
        nameSetA.push("Dean");
        nameSetA.push("Ed");
        nameSetA.push("Frank");
        nameSetA.push("George");
        nameSetA.push("Henry");
        nameSetA.push("Jake");
        nameSetA.push("Keith");
        nameSetA.push("Lee");
        nameSetA.push("Matt");
        nameSetA.push("Neil");
        nameSetA.push("Pete");
        nameSetA.push("Ray");
        nameSetA.push("Scott");
        nameSetA.push("Ted");
        nameSetA.push("Vince");

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
        nameSetB.push("Mary");
        nameSetB.push("Anna");
        nameSetB.push("Brynn");
        nameSetB.push("Claire");
        nameSetB.push("Dina");
        nameSetB.push("Emma");
        nameSetB.push("Flora");
        nameSetB.push("Grace");
        nameSetB.push("Hazel");
        nameSetB.push("Jade");
        nameSetB.push("Kate");
        nameSetB.push("Lisa");
        nameSetB.push("Maya");
        nameSetB.push("Nina");
        nameSetB.push("Pam");

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
        surnames.push("the Greatsword");
        surnames.push("the Bold");
        surnames.push("Steelfist");
        surnames.push("the Valiant");
        surnames.push("Lionheart");
        surnames.push("the Cunning");
        surnames.push("Blackforge");
        surnames.push("the Relentless");
        surnames.push("Stormborn");
        surnames.push("the Fierce");
        surnames.push("Dawnbringer");
        surnames.push("the Unstoppable");
        surnames.push("Ravencall");
        surnames.push("the Fearless");
        surnames.push("Flamebrand");
        surnames.push("the Renowned");
        surnames.push("Thornheart");
        surnames.push("the Savage");
        surnames.push("Shadowbane");
        surnames.push("the Merciless");
        surnames.push("Steelborn");
        surnames.push("the Legendary");
        surnames.push("Frostweaver");
        surnames.push("the Destroyer");
        surnames.push("Duskblade");
        surnames.push("the Champion");
        surnames.push("Ironwill");
        surnames.push("the Conqueror");
        surnames.push("Stormweaver");
        surnames.push("the Gladiator");
        surnames.push("Lightbringer");
        surnames.push("the Warrior");
        surnames.push("Wolfheart");
        surnames.push("the Dauntless");
        surnames.push("Steelstrike");
        surnames.push("the Victorious");
        surnames.push("Dreadborn");
        surnames.push("the Indomitable");
        surnames.push("Flameheart");
        surnames.push("the Unyielding");
        surnames.push("Stormfist");
        surnames.push("the Nightblade");
        surnames.push("Ironheart");
        surnames.push("the Eternal");
        surnames.push("Frostbite");
        surnames.push("the Warlord");
        surnames.push("Dawnstrike");
        surnames.push("the Resolute");
        surnames.push("Steelclaw");
        surnames.push("the Steadfast");
        surnames.push("Stormrage");
        surnames.push("the Revered");

        // Removed event emissions from constructor to save gas
    }

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
}

// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import {IPlayerNameRegistry} from "../../../interfaces/fighters/registries/names/IPlayerNameRegistry.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
/// @notice Thrown when maximum number of names has been reached
error MaxNamesReached();
/// @notice Thrown when maximum number of Set B names has been reached
error MaxSetBNamesReached();
/// @notice Thrown when maximum number of surnames has been reached
error MaxSurnamesReached();
/// @notice Thrown when accessing an invalid name index in Set A
error InvalidNameIndexSetA();
/// @notice Thrown when accessing an invalid name index in Set B
error InvalidNameIndexSetB();
/// @notice Thrown when accessing an invalid surname index
error InvalidSurnameIndex();
/// @notice Thrown when submitting an empty batch of names
error EmptyBatch();
/// @notice Thrown when submitting a batch that exceeds size limit
error BatchTooLarge();
/// @notice Thrown when a name has invalid length
error InvalidNameLength();

//==============================================================//
//                         HEAVY HELMS                          //
//                     PLAYER NAME REGISTRY                     //
//==============================================================//
/// @title Player Name Registry for Heavy Helms
/// @notice Manages player name collections for the game
/// @dev Stores first names (in two sets) and surnames
contract PlayerNameRegistry is IPlayerNameRegistry, ConfirmedOwner {
    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    /// @notice Collection of first names in Set A
    string[] public nameSetA;

    /// @notice Collection of first names in Set B
    string[] public nameSetB;

    /// @notice Collection of surnames
    string[] public surnames;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a name is added to any collection
    /// @param nameType Type of name collection (0=Set A, 1=Set B, 2=Surname)
    /// @param index Index of the name in its collection
    /// @param name The name string that was added
    event NameAdded(uint8 nameType, uint16 index, string name);

    //==============================================================//
    //                         CONSTANTS                            //
    //==============================================================//
    /// @notice Maximum index for Set B names
    uint16 public constant SET_B_MAX = 999;

    /// @notice Starting index for Set A names
    uint16 public constant SET_A_START = 1000;

    /// @notice Maximum size for name batch additions
    uint256 public constant MAX_BATCH_SIZE = 500;

    /// @notice Maximum length of any name string
    uint256 public constant MAX_NAME_LENGTH = 32;

    //==============================================================//
    //                        MODIFIERS                             //
    //==============================================================//
    /// @notice Validates name arrays for batch addition
    /// @param names Array of names to validate
    /// @dev Checks for empty batches, batch size, and name length
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

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    /// @notice Initializes the Player Name Registry
    constructor() ConfirmedOwner(msg.sender) {}

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    // View Functions
    /// @notice Gets the starting index for name set A
    /// @return The index where name set A begins
    function getSetAStart() external pure returns (uint16) {
        return SET_A_START;
    }

    /// @notice Gets the number of names in name set A
    /// @return The count of names in set A
    function getNameSetALength() external view returns (uint16) {
        return uint16(nameSetA.length);
    }

    /// @notice Gets the number of names in name set B
    /// @return The count of names in set B
    function getNameSetBLength() external view returns (uint16) {
        return uint16(nameSetB.length);
    }

    /// @notice Gets the number of surnames in the registry
    /// @return The count of surnames
    function getSurnamesLength() external view returns (uint16) {
        return uint16(surnames.length);
    }

    /// @notice Gets the full name from name parts
    /// @param firstNameIndex Index of the first name
    /// @param surnameIndex Index of the surname
    /// @return firstName The first name as a string
    /// @return surname The surname as a string
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

    /// @notice Check if a first name index is valid (exists in either Set A or Set B)
    /// @param index The index to check
    /// @return True if the index is valid
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

    // State-Changing Functions
    /// @notice Add first names to Set A
    /// @param names Array of names to add
    /// @dev Only callable by the contract owner
    function addNamesToSetA(string[] calldata names) external onlyOwner validateNames(names) {
        uint16 newLength = uint16(nameSetA.length + names.length);
        if (SET_A_START + newLength > type(uint16).max) revert MaxNamesReached();

        for (uint256 i = 0; i < names.length; i++) {
            nameSetA.push(names[i]);
            emit NameAdded(0, SET_A_START + uint16(nameSetA.length) - 1, names[i]);
        }
    }

    /// @notice Add first names to Set B
    /// @param names Array of names to add
    /// @dev Only callable by the contract owner
    function addNamesToSetB(string[] calldata names) external onlyOwner validateNames(names) {
        if (nameSetB.length + names.length > SET_B_MAX + 1) revert MaxSetBNamesReached();

        for (uint256 i = 0; i < names.length; i++) {
            nameSetB.push(names[i]);
            emit NameAdded(1, uint16(nameSetB.length - 1), names[i]);
        }
    }

    /// @notice Add surnames to the registry
    /// @param names Array of surnames to add
    /// @dev Only callable by the contract owner
    function addSurnames(string[] calldata names) external onlyOwner validateNames(names) {
        if (surnames.length + names.length > type(uint16).max) revert MaxSurnamesReached();

        for (uint256 i = 0; i < names.length; i++) {
            surnames.push(names[i]);
            emit NameAdded(2, uint16(surnames.length - 1), names[i]);
        }
    }
}

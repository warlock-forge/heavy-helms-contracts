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
import {IMonsterNameRegistry} from "../../../interfaces/fighters/registries/names/IMonsterNameRegistry.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
/// @notice Thrown when accessing an invalid monster name index
error InvalidNameIndex();
/// @notice Thrown when submitting an empty batch of names
error EmptyBatch();
/// @notice Thrown when submitting a batch that exceeds size limit
error BatchTooLarge();
/// @notice Thrown when a name has invalid length
error InvalidNameLength();

//==============================================================//
//                         HEAVY HELMS                          //
//                    MONSTER NAME REGISTRY                     //
//==============================================================//
/// @title Monster Name Registry for Heavy Helms
/// @notice Manages monster name collections for the game
/// @dev Stores names for monsters with index 0 reserved for nameless monsters
contract MonsterNameRegistry is IMonsterNameRegistry, ConfirmedOwner {
    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    /// @notice Collection of monster names
    string[] public monsterNames;

    //==============================================================//
    //                         CONSTANTS                            //
    //==============================================================//
    /// @notice Maximum size for name batch additions
    uint256 public constant MAX_BATCH_SIZE = 500;

    /// @notice Maximum length of any name string
    uint256 public constant MAX_NAME_LENGTH = 31;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a monster name is added
    /// @param nameIndex Index of the name in the collection
    /// @param name The name string that was added
    event NameAdded(uint16 indexed nameIndex, string name);

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
    /// @notice Initializes the Monster Name Registry
    /// @dev Creates an empty name at index 0 for nameless monsters
    constructor() ConfirmedOwner(msg.sender) {
        // Add empty name at index 0 for "nameless" monsters
        monsterNames.push("");
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    // View Functions
    /// @notice Gets a monster's full name by index
    /// @param nameIndex The index of the name to retrieve
    /// @return The monster's full name
    /// @dev Reverts if the index is 0 (reserved for nameless) or out of range
    function getMonsterName(uint16 nameIndex) external view returns (string memory) {
        if (nameIndex >= monsterNames.length || nameIndex == 0) revert InvalidNameIndex();
        return monsterNames[nameIndex];
    }

    /// @notice Gets the total number of monster names
    /// @return The number of names in the registry
    function getMonsterNamesLength() external view returns (uint16) {
        return uint16(monsterNames.length);
    }

    // State-Changing Functions
    /// @notice Add monster names to the registry
    /// @param names Array of names to add
    /// @dev Only callable by the contract owner
    function addMonsterNames(string[] calldata names) external onlyOwner validateNames(names) {
        for (uint256 i = 0; i < names.length; i++) {
            monsterNames.push(names[i]);
            emit NameAdded(uint16(monsterNames.length - 1), names[i]);
        }
    }
}

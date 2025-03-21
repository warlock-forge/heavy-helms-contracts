// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import "../../fighters/Fighter.sol";
import "./registries/names/IMonsterNameRegistry.sol";

//==============================================================//
//                         HEAVY HELMS                          //
//                        MONSTER INTERFACE                     //
//==============================================================//
/// @title Monster Interface for Heavy Helms
/// @notice Defines the core functionality for monster management and game interactions
/// @dev Used for managing system-controlled NPCs (non-player characters)
interface IMonster {
    //==============================================================//
    //                          STRUCTS                             //
    //==============================================================//
    /// @notice Contains all stats and attributes for a monster
    /// @param attributes Core attributes (strength, constitution, size, agility, stamina, luck)
    /// @param skin Skin information (index and token ID)
    /// @param name Monster name information
    /// @param record Game record stats (wins, losses, kills)
    /// @param tier Tier/level of the monster (affects difficulty and rewards)
    struct MonsterStats {
        Fighter.Attributes attributes;
        Fighter.SkinInfo skin;
        MonsterName name;
        Fighter.Record record;
        uint8 tier;
    }

    /// @notice Name details for a monster
    /// @param nameIndex Index of the monster's name in the name registry
    struct MonsterName {
        uint16 nameIndex;
    }

    /// @notice Permission flags for game contracts
    /// @param record Can modify game records (wins, losses, kills)
    /// @param retire Can modify monster retirement status
    /// @param immortal Can modify monster immortality status
    struct GamePermissions {
        bool record;
        bool retire;
        bool immortal;
    }

    //==============================================================//
    //                          ENUMS                               //
    //==============================================================//
    /// @notice Types of permissions that can be granted to game contracts
    enum GamePermission {
        RECORD, // Can modify wins/losses/kills
        RETIRE, // Can retire monsters
        IMMORTAL // Can modify immortality status

    }

    //==============================================================//
    //                    VIEW FUNCTIONS                            //
    //==============================================================//
    /// @notice Gets the name registry contract reference
    /// @return The MonsterNameRegistry contract instance
    function nameRegistry() external view returns (IMonsterNameRegistry);

    /// @notice Gets the skin registry contract reference
    /// @return The PlayerSkinRegistry contract instance
    function skinRegistry() external view returns (IPlayerSkinRegistry);

    /// @notice Gets the complete stats for a monster
    /// @param monsterId The ID of the monster to query
    /// @return The monster's complete stats and attributes
    function getMonster(uint32 monsterId) external view returns (MonsterStats memory);

    /// @notice Checks if a monster is immortal
    /// @param monsterId The ID of the monster to check
    /// @return True if the monster is immortal
    function isMonsterImmortal(uint32 monsterId) external view returns (bool);

    /// @notice Checks if a monster is retired
    /// @param monsterId The ID of the monster to check
    /// @return True if the monster is retired
    function isMonsterRetired(uint32 monsterId) external view returns (bool);

    /// @notice Check if a monster ID is valid
    /// @param monsterId The ID to check
    /// @return True if the ID is within valid monster range
    function isValidId(uint32 monsterId) external pure returns (bool);

    /// @notice Get the current skin information for a monster
    /// @param monsterId The ID of the monster
    /// @return The monster's equipped skin information
    function getCurrentSkin(uint32 monsterId) external view returns (Fighter.SkinInfo memory);

    /// @notice Gets the permissions for a game contract
    /// @param gameContract Address of the game contract to query
    /// @return The permissions granted to the game contract
    function gameContractPermissions(address gameContract) external view returns (GamePermissions memory);

    //==============================================================//
    //                 STATE-CHANGING FUNCTIONS                     //
    //==============================================================//
    /// @notice Sets a monster's retirement status
    /// @param monsterId The ID of the monster
    /// @param retired The new retirement status
    /// @dev Requires RETIRE permission
    function setMonsterRetired(uint32 monsterId, bool retired) external;

    /// @notice Sets a monster's immortality status
    /// @param monsterId The ID of the monster
    /// @param immortal The new immortality status
    /// @dev Requires IMMORTAL permission
    function setMonsterImmortal(uint32 monsterId, bool immortal) external;

    /// @notice Increments a monster's win count
    /// @param monsterId The ID of the monster
    /// @dev Requires RECORD permission
    function incrementWins(uint32 monsterId) external;

    /// @notice Increments a monster's loss count
    /// @param monsterId The ID of the monster
    /// @dev Requires RECORD permission
    function incrementLosses(uint32 monsterId) external;

    /// @notice Increments a monster's kill count
    /// @param monsterId The ID of the monster
    /// @dev Requires RECORD permission
    function incrementKills(uint32 monsterId) external;
}

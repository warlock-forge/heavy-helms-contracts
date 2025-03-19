// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../fighters/Fighter.sol";

/// @title Monster Interface for Heavy Helms
/// @notice Defines the core functionality for monster management and game interactions
interface IMonster {
    //==============================================================//
    //                          STRUCTS                             //
    //==============================================================//
    /// @notice Contains all stats and attributes for a monster
    /// @param attributes Attributes for monster -> (strength, constitution, size, agility, stamina, luck)
    /// @param skin SkinInfo for monster -> (skinIndex, skinTokenId)
    /// @param name Name for monster -> (firstNameIndex, surnameIndex)
    /// @param record Record for monster -> (wins, losses, kills)
    /// @param tier Tier of the monster
    struct MonsterStats {
        Fighter.Attributes attributes;
        Fighter.SkinInfo skin;
        uint16 monsterNameIndex;
        Fighter.Record record;
        uint8 tier;
    }

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a new monster is created
    /// @param monsterId The ID of the created monster
    event MonsterCreated(uint32 indexed monsterId);

    /// @notice Emitted when a monster is retired
    /// @param monsterId The ID of the retired monster
    event MonsterRetired(uint32 indexed monsterId);

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//

    /// @notice Gets the complete stats for a monster
    /// @param monsterId The ID of the monster to query
    /// @return The monster's complete stats and attributes
    function getMonster(uint32 monsterId) external view returns (MonsterStats memory);

    /// @notice Checks if a monster is retired
    /// @param monsterId The ID of the monster to check
    /// @return True if the monster is retired
    function isMonsterRetired(uint32 monsterId) external view returns (bool);

    /// @notice Creates a new monster with specified stats (owner only)
    /// @param stats The stats for the new monster
    /// @return The ID of the created monster
    function createMonster(MonsterStats memory stats) external returns (uint32);

    /// @notice Sets a monster's retirement status (owner only)
    /// @param monsterId The ID of the monster
    /// @param retired The new retirement status
    function setMonsterRetired(uint32 monsterId, bool retired) external;

    /// @notice Increments a monster's win count (game contracts only)
    /// @param monsterId The ID of the monster
    function incrementWins(uint32 monsterId) external;

    /// @notice Increments a monster's loss count (game contracts only)
    /// @param monsterId The ID of the monster
    function incrementLosses(uint32 monsterId) external;

    /// @notice Increments a monster's kill count (game contracts only)
    /// @param monsterId The ID of the monster
    function incrementKills(uint32 monsterId) external;
}

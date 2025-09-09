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
import {Fighter} from "../../fighters/Fighter.sol";
import {IMonsterNameRegistry} from "./registries/names/IMonsterNameRegistry.sol";
import {IPlayerSkinRegistry} from "./registries/skins/IPlayerSkinRegistry.sol";

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
    /// @param level Level of the monster (affects difficulty and rewards)
    struct MonsterStats {
        Fighter.Attributes attributes;
        MonsterName name;
        Fighter.SkinInfo skin;
        uint8 stance;
        uint8 level;
        uint16 currentXP;
        uint8 weaponSpecialization;
        uint8 armorSpecialization;
    }

    /// @notice Name details for a monster
    /// @param nameIndex Index of the monster's name in the name registry
    struct MonsterName {
        uint16 nameIndex;
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

    /// @notice Gets the complete stats for a monster at a specific level
    /// @param monsterId The ID of the monster to query
    /// @param level The level to get stats for (1-10)
    /// @return The monster's complete stats and attributes at the specified level
    function getMonster(uint32 monsterId, uint8 level) external view returns (MonsterStats memory);

    /// @notice Check if a monster ID is valid
    /// @param monsterId The ID to check
    /// @return True if the ID is within valid monster range
    function isValidId(uint32 monsterId) external pure returns (bool);
}

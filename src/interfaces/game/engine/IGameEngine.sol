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
import {Fighter} from "../../../fighters/Fighter.sol";

//==============================================================//
//                         HEAVY HELMS                          //
//                     GAME ENGINE INTERFACE                    //
//==============================================================//
/// @title Game Engine Interface for Heavy Helms
/// @notice Defines the core combat engine functionality
/// @dev Used by game contracts to process combat between fighters
interface IGameEngine {
    //==============================================================//
    //                          ENUMS                               //
    //==============================================================//
    /// @notice Defines how a battle was won
    enum WinCondition {
        HEALTH, // KO
        EXHAUSTION, // Won because opponent couldn't attack (low stamina)
        MAX_ROUNDS, // Won by having more health after max rounds
        DEATH // RIP

    }

    /// @notice Types of combat results for each action
    enum CombatResultType {
        MISS, // 0 - Complete miss, some stamina cost
        ATTACK, // 1 - Normal successful attack
        CRIT, // 2 - Critical hit
        BLOCK, // 3 - Successfully blocked attack
        COUNTER, // 4 - Counter attack after block/dodge
        COUNTER_CRIT, // 5 - Critical counter attack
        DODGE, // 6 - Successfully dodged attack
        PARRY, // 7 - Successfully parried attack
        RIPOSTE, // 8 - Counter attack after parry
        RIPOSTE_CRIT, // 9 - Critical counter after parry
        EXHAUSTED, // 10 - Failed due to stamina
        HIT // 11 - Taking full damage (failed defense)

    }

    //==============================================================//
    //                          STRUCTS                             //
    //==============================================================//
    /// @notice Represents a single combat action between two fighters
    /// @param p1Result The result type for player 1's action
    /// @param p1Damage Damage dealt by player 1
    /// @param p1StaminaLost Stamina consumed by player 1
    /// @param p2Result The result type for player 2's action
    /// @param p2Damage Damage dealt by player 2
    /// @param p2StaminaLost Stamina consumed by player 2
    struct CombatAction {
        CombatResultType p1Result;
        uint16 p1Damage;
        uint8 p1StaminaLost;
        CombatResultType p2Result;
        uint16 p2Damage;
        uint8 p2StaminaLost;
    }

    /// @notice Complete stats for a fighter in combat
    /// @param weapon Equipped weapon type
    /// @param armor Equipped armor type
    /// @param stance Combat stance
    /// @param attributes Fighter's base attributes
    /// @param level Fighter's level
    /// @param weaponSpecialization Weapon mastery type
    /// @param armorSpecialization Armor mastery type
    struct FighterStats {
        uint8 weapon;
        uint8 armor;
        uint8 stance;
        Fighter.Attributes attributes;
        uint8 level;
        uint8 weaponSpecialization;
        uint8 armorSpecialization;
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Decodes a version number into major and minor components
    /// @param _version The packed version number
    /// @return major The major version number
    /// @return minor The minor version number
    function decodeVersion(uint16 _version) external pure returns (uint8 major, uint8 minor);

    /// @notice Decodes combat log bytes into structured combat data
    /// @param results The encoded combat results
    /// @return player1Won Whether player 1 won the battle
    /// @return gameEngineVersion Version of the game engine used
    /// @return condition How the battle was won
    /// @return actions Array of all combat actions that occurred
    function decodeCombatLog(bytes memory results)
        external
        pure
        returns (bool player1Won, uint16 gameEngineVersion, WinCondition condition, CombatAction[] memory actions);

    /// @notice Processes a complete game between two fighters
    /// @param player1 Stats for the first fighter
    /// @param player2 Stats for the second fighter
    /// @param randomSeed Random seed for combat calculations
    /// @param lethalityFactor Modifier affecting combat damage
    /// @return Encoded combat log containing all battle results
    function processGame(
        FighterStats calldata player1,
        FighterStats calldata player2,
        uint256 randomSeed,
        uint16 lethalityFactor
    ) external view returns (bytes memory);
}

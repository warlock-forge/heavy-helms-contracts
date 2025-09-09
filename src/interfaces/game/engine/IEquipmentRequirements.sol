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
//                 EQUIPMENT REQUIREMENTS INTERFACE             //
//==============================================================//
/// @title Equipment Requirements Interface for Heavy Helms
/// @notice Defines functionality for equipment attribute requirements
/// @dev Used by game contracts to validate equipment can be used by fighters
interface IEquipmentRequirements {
    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Gets the attribute requirements for a specific weapon
    /// @param weapon The weapon type to query requirements for
    /// @return The minimum attributes required to wield the weapon
    function getWeaponRequirements(uint8 weapon) external pure returns (Fighter.Attributes memory);

    /// @notice Gets the attribute requirements for a specific armor type
    /// @param armor The armor type to query requirements for
    /// @return The minimum attributes required to wear the armor
    function getArmorRequirements(uint8 armor) external pure returns (Fighter.Attributes memory);
}

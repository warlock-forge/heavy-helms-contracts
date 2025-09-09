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
import {IPlayer} from "./IPlayer.sol";
import {Fighter} from "../../fighters/Fighter.sol";

//==============================================================//
//                         HEAVY HELMS                          //
//                   PLAYER DATA CODEC INTERFACE                //
//==============================================================//
/// @title Player Data Codec Interface for Heavy Helms
/// @notice Defines functionality for encoding/decoding player data for efficient storage
/// @dev Used by Player contract and game modes for data packing
interface IPlayerDataCodec {
    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Packs player data into a compact bytes32 format for efficient storage/transmission
    /// @param playerId The ID of the player to encode
    /// @param stats The player's stats and attributes to encode
    /// @param seasonalRecord The player's seasonal record to encode
    /// @return Packed bytes32 representation of the player data
    /// @dev Encodes all player attributes, skin info, and combat-relevant data into 32 bytes
    function encodePlayerData(uint32 playerId, IPlayer.PlayerStats memory stats, Fighter.Record memory seasonalRecord)
        external
        pure
        returns (bytes32);

    /// @notice Unpacks player data from bytes32 format back into structured data
    /// @param data The packed bytes32 data to decode
    /// @return playerId The decoded player ID
    /// @return stats The decoded player stats and attributes
    /// @return seasonalRecord The decoded seasonal record
    /// @dev Reverses the encoding process from encodePlayerData
    function decodePlayerData(bytes32 data)
        external
        pure
        returns (uint32 playerId, IPlayer.PlayerStats memory stats, Fighter.Record memory seasonalRecord);
}

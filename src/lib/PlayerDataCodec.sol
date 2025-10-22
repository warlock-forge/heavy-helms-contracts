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
import {IPlayerDataCodec} from "../interfaces/fighters/IPlayerDataCodec.sol";
import {IPlayer} from "../interfaces/fighters/IPlayer.sol";
import {Fighter} from "../fighters/Fighter.sol";

//==============================================================//
//                         HEAVY HELMS                          //
//                      PLAYER DATA CODEC                       //
//==============================================================//
/// @title Player Data Codec for Heavy Helms
/// @notice Handles encoding and decoding of player data for efficient storage/transmission
/// @dev Pure functions extracted from Player contract to reduce size
contract PlayerDataCodec is IPlayerDataCodec {
    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Packs player data into a compact bytes32 format for efficient storage/transmission
    /// @param playerId The ID of the player to encode
    /// @param stats The player's stats and attributes to encode
    /// @param seasonalRecord The player's seasonal record to encode
    /// @return Packed player data in the format: [playerId(4)][stats(6)][skinIndex(4)][tokenId(2)][stance(1)][names(4)][records(6)][progression(5)]
    /// @dev Byte layout: [0-3:playerId][4-9:stats][10-13:skinIndex][14-15:tokenId][16:stance][17-20:names][21-26:records][27-31:progression]
    function encodePlayerData(uint32 playerId, IPlayer.PlayerStats memory stats, Fighter.Record memory seasonalRecord)
        external
        pure
        returns (bytes32)
    {
        bytes memory packed = new bytes(32);

        // Pack playerId (4 bytes)
        packed[0] = bytes1(uint8(playerId >> 24));
        packed[1] = bytes1(uint8(playerId >> 16));
        packed[2] = bytes1(uint8(playerId >> 8));
        packed[3] = bytes1(uint8(playerId));

        // Pack uint8 stats (6 bytes)
        packed[4] = bytes1(stats.attributes.strength);
        packed[5] = bytes1(stats.attributes.constitution);
        packed[6] = bytes1(stats.attributes.size);
        packed[7] = bytes1(stats.attributes.agility);
        packed[8] = bytes1(stats.attributes.stamina);
        packed[9] = bytes1(stats.attributes.luck);

        // Pack skinIndex (4 bytes)
        packed[10] = bytes1(uint8(stats.skin.skinIndex >> 24));
        packed[11] = bytes1(uint8(stats.skin.skinIndex >> 16));
        packed[12] = bytes1(uint8(stats.skin.skinIndex >> 8));
        packed[13] = bytes1(uint8(stats.skin.skinIndex));

        // Pack tokenId (2 bytes)
        packed[14] = bytes1(uint8(stats.skin.skinTokenId >> 8));
        packed[15] = bytes1(uint8(stats.skin.skinTokenId));

        // Pack stance (1 byte)
        packed[16] = bytes1(stats.stance);

        // Pack name indices (4 bytes)
        packed[17] = bytes1(uint8(stats.name.firstNameIndex >> 8));
        packed[18] = bytes1(uint8(stats.name.firstNameIndex));
        packed[19] = bytes1(uint8(stats.name.surnameIndex >> 8));
        packed[20] = bytes1(uint8(stats.name.surnameIndex));

        // Pack record data (6 bytes)
        packed[21] = bytes1(uint8(seasonalRecord.wins >> 8));
        packed[22] = bytes1(uint8(seasonalRecord.wins));
        packed[23] = bytes1(uint8(seasonalRecord.losses >> 8));
        packed[24] = bytes1(uint8(seasonalRecord.losses));
        packed[25] = bytes1(uint8(seasonalRecord.kills >> 8));
        packed[26] = bytes1(uint8(seasonalRecord.kills));

        // Pack progression data (5 bytes: level, currentXP, weapon spec, armor spec)
        packed[27] = bytes1(stats.level);
        packed[28] = bytes1(uint8(stats.currentXP >> 8));
        packed[29] = bytes1(uint8(stats.currentXP));
        packed[30] = bytes1(stats.weaponSpecialization);
        packed[31] = bytes1(stats.armorSpecialization);

        return bytes32(packed);
    }

    /// @notice Unpacks player data from bytes32 format back into structured data
    /// @param data The packed bytes32 data to decode
    /// @return playerId The decoded player ID
    /// @return stats The decoded player stats and attributes
    /// @return seasonalRecord The decoded seasonal record
    /// @dev Reverses the encoding process from encodePlayerData
    function decodePlayerData(bytes32 data)
        external
        pure
        returns (uint32 playerId, IPlayer.PlayerStats memory stats, Fighter.Record memory seasonalRecord)
    {
        bytes memory packed = new bytes(32);
        assembly {
            mstore(add(packed, 32), data)
        }

        // Decode playerId
        playerId = uint32(uint8(packed[0])) << 24 | uint32(uint8(packed[1])) << 16 | uint32(uint8(packed[2])) << 8
            | uint32(uint8(packed[3]));

        // Decode uint8 stats
        stats.attributes.strength = uint8(packed[4]);
        stats.attributes.constitution = uint8(packed[5]);
        stats.attributes.size = uint8(packed[6]);
        stats.attributes.agility = uint8(packed[7]);
        stats.attributes.stamina = uint8(packed[8]);
        stats.attributes.luck = uint8(packed[9]);

        // Decode skinIndex
        uint32 skinIndex = uint32(uint8(packed[10])) << 24 | uint32(uint8(packed[11])) << 16 | uint32(uint8(packed[12]))
            << 8 | uint32(uint8(packed[13]));
        uint16 skinTokenId = uint16(uint8(packed[14])) << 8 | uint16(uint8(packed[15]));

        // Decode stance
        uint8 stance = uint8(packed[16]);

        // Decode name indices
        stats.name.firstNameIndex = uint16(uint8(packed[17])) << 8 | uint16(uint8(packed[18]));
        stats.name.surnameIndex = uint16(uint8(packed[19])) << 8 | uint16(uint8(packed[20]));

        // Decode record data
        seasonalRecord.wins = uint16(uint8(packed[21])) << 8 | uint16(uint8(packed[22]));
        seasonalRecord.losses = uint16(uint8(packed[23])) << 8 | uint16(uint8(packed[24]));
        seasonalRecord.kills = uint16(uint8(packed[25])) << 8 | uint16(uint8(packed[26]));

        // Decode progression data
        stats.level = uint8(packed[27]);
        stats.currentXP = uint16(uint8(packed[28])) << 8 | uint16(uint8(packed[29]));
        stats.weaponSpecialization = uint8(packed[30]);
        stats.armorSpecialization = uint8(packed[31]);

        // Construct skin and set stance
        stats.skin = Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: skinTokenId});
        stats.stance = stance;

        return (playerId, stats, seasonalRecord);
    }
}

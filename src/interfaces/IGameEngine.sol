// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IPlayer.sol";
import "../lib/GameHelpers.sol";

interface IGameEngine {
    // Used by game modes for validation and tracking
    struct PlayerLoadout {
        uint32 playerId;
        uint32 skinIndex;
        uint16 skinTokenId;
    }

    struct FighterStats {
        uint32 playerId; // Temporary until we can remove this dependency
        uint8 weapon;
        uint8 armor;
        uint8 stance;
        GameHelpers.Attributes attributes;
    }

    function decodeVersion(uint16 _version) external pure returns (uint8 major, uint8 minor);

    function processGame(
        FighterStats calldata player1,
        FighterStats calldata player2,
        uint256 randomSeed,
        uint16 lethalityFactor
    ) external view returns (bytes memory);
}

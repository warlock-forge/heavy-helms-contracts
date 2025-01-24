// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IPlayer.sol";
import "./IGameDefinitions.sol";

interface IGameEngine {
    // Used by game modes for validation and tracking
    struct PlayerLoadout {
        uint32 playerId;
        uint32 skinIndex;
        uint16 skinTokenId;
    }

    // Used internally by GameEngine for combat
    struct CombatLoadout {
        uint32 playerId;
        IGameDefinitions.WeaponType weapon;
        IGameDefinitions.ArmorType armor;
        IGameDefinitions.FightingStance stance;
        IPlayer.PlayerStats stats;
    }

    function decodeVersion(uint16 _version) external pure returns (uint8 major, uint8 minor);

    function processGame(
        CombatLoadout calldata player1,
        CombatLoadout calldata player2,
        uint256 randomSeed,
        uint16 lethalityFactor
    ) external view returns (bytes memory);
}

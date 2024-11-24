// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPlayer {
    struct PlayerStats {
        int8 strength;
        int8 constitution;
        int8 agility;
        int8 stamina;
    }

    struct CalculatedStats {
        uint8 maxHealth;
        uint8 damage;
        uint8 hitChance;
        uint8 blockChance;
        uint8 dodgeChance;
        uint8 maxEndurance;
        uint8 critChance;
        uint8 initiative;
        uint8 counterChance;
        uint8 critMultiplier;
    }

    function createPlayer(uint256 randomSeed) external returns (uint256 playerId, PlayerStats memory stats);
    function getPlayerIds(address owner) external view returns (uint256[] memory);
    function getPlayer(uint256 playerId) external view returns (PlayerStats memory);
    function getPlayerOwner(uint256 playerId) external view returns (address);
    function players(uint256 playerId) external view returns (PlayerStats memory);
    function getPlayerState(uint256 playerId) external view returns (uint256 health, uint256 stamina);
    function calculateStats(PlayerStats memory player) external pure returns (CalculatedStats memory);
}

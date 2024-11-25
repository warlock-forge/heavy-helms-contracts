// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPlayer {
    struct PlayerStats {
        uint8 strength;
        uint8 constitution;
        uint8 size;
        uint8 agility;
        uint8 stamina;
        uint8 luck;
    }

    struct CalculatedStats {
        uint16 maxHealth;
        uint16 damageModifier;
        uint16 hitChance;
        uint16 blockChance;
        uint16 dodgeChance;
        uint16 maxEndurance;
        uint16 critChance;
        uint16 initiative;
        uint16 counterChance;
        uint16 critMultiplier;
    }

    function createPlayer() external returns (uint256 playerId, PlayerStats memory stats);
    function getPlayerIds(address owner) external view returns (uint256[] memory);
    function getPlayer(uint256 playerId) external view returns (PlayerStats memory);
    function getPlayerOwner(uint256 playerId) external view returns (address);
    function players(uint256 playerId) external view returns (PlayerStats memory);
    function getPlayerState(uint256 playerId) external view returns (uint256 health, uint256 stamina);
    function calculateStats(PlayerStats memory player) external pure returns (CalculatedStats memory);
}

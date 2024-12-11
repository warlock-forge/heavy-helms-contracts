// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../PlayerEquipmentStats.sol";
import "../PlayerSkinRegistry.sol";

interface IPlayer {
    struct PlayerStats {
        uint8 strength;
        uint8 constitution;
        uint8 size;
        uint8 agility;
        uint8 stamina;
        uint8 luck;
        uint32 skinIndex;
        uint16 skinTokenId;
        uint16 firstNameIndex;
        uint16 surnameIndex;
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
        uint16 parryChance;
    }

    function equipmentStats() external view returns (PlayerEquipmentStats);
    function skinRegistry() external view returns (PlayerSkinRegistry);
    function getPlayerIds(address owner) external view returns (uint256[] memory);
    function getPlayer(uint256 playerId) external view returns (PlayerStats memory);
    function getPlayerOwner(uint256 playerId) external view returns (address);
    function players(uint256 playerId) external view returns (PlayerStats memory);
    function getPlayerState(uint256 playerId) external view returns (uint256 health, uint256 stamina);
    function calculateStats(PlayerStats memory player) external pure returns (CalculatedStats memory);
    function requestCreatePlayer(bool useNameSetB) external returns (uint256 requestId);
    function getPendingRequests(address user) external view returns (uint256[] memory);
    function getRequestStatus(uint256 requestId) external view returns (bool exists, bool fulfilled, address owner);
}

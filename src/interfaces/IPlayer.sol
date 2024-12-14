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
        uint16 wins;
        uint16 losses;
        uint16 kills;
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

    enum GamePermission {
        RECORD, // For wins, losses, kills
        RETIRE, // For retirement status
        NAME, // For name changes
        ATTRIBUTES // For attribute modifications

    }

    struct GamePermissions {
        bool record; // Can modify game records
        bool retire; // Can retire players
        bool name; // Can change names
        bool attributes; // Can modify attributes
    }

    function equipmentStats() external view returns (PlayerEquipmentStats);
    function skinRegistry() external view returns (PlayerSkinRegistry);
    function getPlayerIds(address owner) external view returns (uint256[] memory);
    function getPlayer(uint256 playerId) external view returns (PlayerStats memory);
    function getPlayerOwner(uint256 playerId) external view returns (address);
    function players(uint256 playerId) external view returns (PlayerStats memory);
    function getPlayerState(uint256 playerId) external view returns (uint256 health, uint256 stamina);
    function calculateStats(PlayerStats memory player) external pure returns (CalculatedStats memory);
    function requestCreatePlayer(bool useNameSetB) external payable returns (uint256 requestId);
    function getPendingRequests(address user) external view returns (uint256[] memory);
    function getRequestStatus(uint256 requestId) external view returns (bool exists, bool fulfilled, address owner);
    function isPlayerRetired(uint256 playerId) external view returns (bool);
    function setPlayerRetired(uint256 playerId, bool retired) external;
    function gameContractPermissions(address gameContract) external view returns (GamePermissions memory);
    function setGameContractPermission(address gameContract, GamePermissions memory permissions) external;
    function incrementWins(uint32 playerId) external;
    function incrementLosses(uint32 playerId) external;
    function incrementKills(uint32 playerId) external;
    function setPlayerName(uint32 playerId, uint16 firstNameIndex, uint16 surnameIndex) external;
    function setPlayerAttributes(
        uint32 playerId,
        uint8 strength,
        uint8 constitution,
        uint8 size,
        uint8 agility,
        uint8 stamina,
        uint8 luck
    ) external;
    function retireOwnPlayer(uint32 playerId) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../PlayerEquipmentStats.sol";
import "../PlayerSkinRegistry.sol";

interface IPlayer {
    /// @notice Returns the maximum number of players allowed per address
    function maxPlayersPerAddress() external view returns (uint256);

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

    error PlayerDoesNotExist(uint32 playerId);

    // Events
    event PlayerRetired(uint32 indexed playerId, address indexed caller, bool retired);
    event PlayerResurrected(uint32 indexed playerId);
    event PlayerSkinEquipped(uint32 indexed playerId, uint32 indexed skinIndex, uint16 tokenId);
    event PlayerCreationFulfilled(uint256 indexed requestId, uint32 indexed playerId, address indexed owner);

    function equipmentStats() external view returns (PlayerEquipmentStats);
    function skinRegistry() external view returns (PlayerSkinRegistry);
    function getPlayerIds(address owner) external view returns (uint32[] memory);
    function getPlayer(uint32 playerId) external view returns (PlayerStats memory);
    function getPlayerOwner(uint32 playerId) external view returns (address);
    function calculateStats(PlayerStats memory player) external pure returns (CalculatedStats memory);
    function requestCreatePlayer(bool useNameSetB) external payable returns (uint256 requestId);
    function getPendingRequests(address user) external view returns (uint256[] memory);
    function getRequestStatus(uint256 requestId) external view returns (bool exists, bool fulfilled, address owner);
    function isPlayerRetired(uint32 playerId) external view returns (bool);
    function setPlayerRetired(uint32 playerId, bool retired) external;
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

    /// @notice Encodes a player ID and their stats into a bytes32 value (using first 26 bytes)
    /// @param playerId The ID of the player
    /// @param stats The PlayerStats struct to encode
    /// @return result The encoded bytes32 with player data (26 bytes used, 6 bytes padded)
    function encodePlayerData(uint32 playerId, PlayerStats memory stats) external pure returns (bytes32);

    /// @notice Decodes a bytes32 value back into a player ID and PlayerStats
    /// @param data The encoded bytes32 data
    /// @return playerId The decoded player ID
    /// @return stats The decoded PlayerStats
    function decodePlayerData(bytes32 data) external pure returns (uint32 playerId, PlayerStats memory stats);
}

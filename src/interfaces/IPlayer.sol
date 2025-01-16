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

    // Public errors that can be thrown by any public/external function
    error PlayerDoesNotExist(uint32 playerId);
    error NotSkinOwner();
    error InvalidContractAddress();
    error RequiredNFTNotOwned(address nftAddress);
    error PlayerIsRetired(uint32 playerId);

    // Events
    event PlayerRetired(uint32 indexed playerId, address indexed caller, bool retired);
    event PlayerSkinEquipped(uint32 indexed playerId, uint32 indexed skinIndex, uint16 tokenId);
    event PlayerCreationFulfilled(uint256 indexed requestId, uint32 indexed playerId, address indexed owner);
    event PlayerCreationRequested(uint256 indexed requestId, address indexed requester);
    event MaxPlayersUpdated(uint256 newMax);
    event EquipmentStatsUpdated(address indexed oldStats, address indexed newStats);
    event CreatePlayerFeeUpdated(uint256 oldFee, uint256 newFee);

    // Contract References
    /// @notice Returns the equipment stats contract reference
    function equipmentStats() external view returns (PlayerEquipmentStats);

    /// @notice Returns the skin registry contract reference
    function skinRegistry() external view returns (PlayerSkinRegistry);

    // Player Management
    /// @notice Returns all player IDs owned by an address
    /// @param owner The address to get player IDs for
    function getPlayerIds(address owner) external view returns (uint32[] memory);

    /// @notice Returns the stats for a specific player
    /// @param playerId The ID of the player to get stats for
    function getPlayer(uint32 playerId) external view returns (PlayerStats memory);

    /// @notice Returns the owner of a specific player
    /// @param playerId The ID of the player to get owner for
    function getPlayerOwner(uint32 playerId) external view returns (address);

    /// @notice Calculates derived stats from base player stats
    /// @param player The player stats to calculate from
    function calculateStats(PlayerStats memory player) external pure returns (CalculatedStats memory);

    // Player Creation
    /// @notice Returns the current fee amount required to create a player
    function createPlayerFeeAmount() external view returns (uint256);

    /// @notice Requests creation of a new player
    /// @param useNameSetB Whether to use name set B for the player name
    /// @return requestId The ID of the creation request
    function requestCreatePlayer(bool useNameSetB) external payable returns (uint256 requestId);

    /// @notice Gets all pending creation requests for a user
    /// @param user The address to get pending requests for
    function getPendingRequests(address user) external view returns (uint256[] memory);

    /// @notice Gets the status of a creation request
    /// @param requestId The ID of the request to check
    function getRequestStatus(uint256 requestId) external view returns (bool exists, bool fulfilled, address owner);

    // Player Updates
    /// @notice Checks if a player is retired
    /// @param playerId The ID of the player to check
    function isPlayerRetired(uint32 playerId) external view returns (bool);

    /// @notice Sets the retirement status of a player
    /// @param playerId The ID of the player to retire/unretire
    /// @param retired The new retirement status
    function setPlayerRetired(uint32 playerId, bool retired) external;

    /// @notice Equips a skin to a player
    /// @param playerId The ID of the player to equip the skin to
    /// @param skinIndex The index of the skin in the registry
    /// @param tokenId The token ID of the skin NFT
    function equipSkin(uint32 playerId, uint32 skinIndex, uint16 tokenId) external;

    /// @notice Increments the win count for a player
    /// @param playerId The ID of the player
    function incrementWins(uint32 playerId) external;

    /// @notice Increments the loss count for a player
    /// @param playerId The ID of the player
    function incrementLosses(uint32 playerId) external;

    /// @notice Increments the kill count for a player
    /// @param playerId The ID of the player
    function incrementKills(uint32 playerId) external;

    /// @notice Sets the name indices for a player
    /// @param playerId The ID of the player
    /// @param firstNameIndex The index of the first name
    /// @param surnameIndex The index of the surname
    function setPlayerName(uint32 playerId, uint16 firstNameIndex, uint16 surnameIndex) external;

    /// @notice Sets the base attributes for a player
    /// @param playerId The ID of the player
    /// @param strength The new strength value
    /// @param constitution The new constitution value
    /// @param size The new size value
    /// @param agility The new agility value
    /// @param stamina The new stamina value
    /// @param luck The new luck value
    function setPlayerAttributes(
        uint32 playerId,
        uint8 strength,
        uint8 constitution,
        uint8 size,
        uint8 agility,
        uint8 stamina,
        uint8 luck
    ) external;

    /// @notice Allows a player owner to retire their own player
    /// @param playerId The ID of the player to retire
    function retireOwnPlayer(uint32 playerId) external;

    // Game Contract Management
    /// @notice Gets the permissions for a game contract
    /// @param gameContract The address of the game contract
    function gameContractPermissions(address gameContract) external view returns (GamePermissions memory);

    /// @notice Sets permissions for a game contract
    /// @param gameContract The address of the game contract
    /// @param permissions The new permissions to set
    function setGameContractPermission(address gameContract, GamePermissions memory permissions) external;

    // Contract Configuration
    /// @notice Sets the operator address for VRF operations
    /// @param newOperator The new operator address
    /// @dev Only callable by contract owner
    function setOperator(address newOperator) external;

    /// @notice Updates the maximum number of players allowed per address
    /// @param newMax The new maximum number of players
    /// @dev Only callable by contract owner
    function setMaxPlayersPerAddress(uint256 newMax) external;

    /// @notice Updates the equipment stats contract address
    /// @param newEquipmentStats The new equipment stats contract address
    /// @dev Only callable by contract owner
    function setEquipmentStats(address newEquipmentStats) external;

    /// @notice Updates the fee amount required to create a new player
    /// @param newFeeAmount The new fee amount in wei
    /// @dev Only callable by contract owner
    function setCreatePlayerFeeAmount(uint256 newFeeAmount) external;

    /// @notice Withdraws accumulated fees to the contract owner
    /// @dev Only callable by contract owner
    function withdrawFees() external;

    /// @notice Clears all pending player creation requests for a given address
    /// @param user The address to clear requests for
    /// @dev Only callable by contract owner
    function clearPendingRequestsForAddress(address user) external;

    // Utility Functions
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

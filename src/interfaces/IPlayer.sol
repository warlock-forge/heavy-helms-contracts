// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../PlayerSkinRegistry.sol";
import "../PlayerNameRegistry.sol";

/// @title Player Interface for Heavy Helms
/// @notice Defines the core functionality for player management and game interactions
interface IPlayer {
    //==============================================================//
    //                          STRUCTS                             //
    //==============================================================//
    /// @notice Contains all stats and attributes for a player
    /// @param strength Physical power stat (3-21)
    /// @param constitution Health and durability stat (3-21)
    /// @param size Physical size stat (3-21)
    /// @param agility Speed and dexterity stat (3-21)
    /// @param stamina Endurance stat (3-21)
    /// @param luck Fortune and critical chance stat (3-21)
    /// @param skinIndex Index of equipped skin collection
    /// @param skinTokenId Token ID of equipped skin
    /// @param firstNameIndex Index of player's first name
    /// @param surnameIndex Index of player's surname
    /// @param wins Total victories
    /// @param losses Total defeats
    /// @param kills Total kills
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

    /// @notice Permission flags for game contracts
    /// @param record Can modify game records (wins, losses, kills)
    /// @param retire Can modify player retirement status
    /// @param name Can modify player names
    /// @param attributes Can modify player attributes
    struct GamePermissions {
        bool record;
        bool retire;
        bool name;
        bool attributes;
    }

    //==============================================================//
    //                          ENUMS                               //
    //==============================================================//
    /// @notice Types of permissions that can be granted to game contracts
    enum GamePermission {
        RECORD, // For wins, losses, kills
        RETIRE, // For retirement status
        NAME, // For name changes
        ATTRIBUTES // For attribute modifications

    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    // View Functions
    /// @notice Gets the skin registry contract reference
    /// @return The PlayerSkinRegistry contract instance
    function skinRegistry() external view returns (PlayerSkinRegistry);

    /// @notice Gets the name registry contract reference
    /// @return The PlayerNameRegistry contract instance
    function nameRegistry() external view returns (PlayerNameRegistry);

    /// @notice Gets all player IDs owned by an address
    /// @param owner The address to query
    /// @return Array of player IDs owned by the address
    function getPlayerIds(address owner) external view returns (uint32[] memory);

    /// @notice Gets the complete stats for a player
    /// @param playerId The ID of the player to query
    /// @return The player's complete stats and attributes
    function getPlayer(uint32 playerId) external view returns (PlayerStats memory);

    /// @notice Gets the owner of a player
    /// @param playerId The ID of the player to query
    /// @return The address that owns the player
    function getPlayerOwner(uint32 playerId) external view returns (address);

    /// @notice Gets the current fee required to create a new player
    /// @return The fee amount in wei
    function createPlayerFeeAmount() external view returns (uint256);

    /// @notice Gets pending VRF request ID for a user
    /// @param user The address to check
    /// @return requestId The pending request ID (0 if none)
    function getPendingRequest(address user) external view returns (uint256);

    /// @notice Gets the status of a VRF request
    /// @param requestId The ID of the request to query
    /// @return exists Whether the request exists
    /// @return fulfilled Whether the request has been fulfilled
    /// @return owner Address that made the request
    function getRequestStatus(uint256 requestId) external view returns (bool exists, bool fulfilled, address owner);

    /// @notice Checks if a player is retired
    /// @param playerId The ID of the player to check
    /// @return True if the player is retired
    function isPlayerRetired(uint32 playerId) external view returns (bool);

    /// @notice Gets the permissions granted to a game contract
    /// @param gameContract The address of the game contract
    /// @return The permissions granted to the contract
    function gameContractPermissions(address gameContract) external view returns (GamePermissions memory);

    // Pure Functions
    /// @notice Encodes player data into a compact bytes32 format
    /// @param playerId The ID of the player to encode
    /// @param stats The player stats to encode
    /// @return The encoded player data
    function encodePlayerData(uint32 playerId, PlayerStats memory stats) external pure returns (bytes32);

    /// @notice Decodes player data from bytes32 format
    /// @param data The encoded player data
    /// @return playerId The decoded player ID
    /// @return stats The decoded player stats
    function decodePlayerData(bytes32 data) external pure returns (uint32 playerId, PlayerStats memory stats);

    // State-Changing Functions
    /// @notice Requests creation of a new player with random stats
    /// @param useNameSetB If true, uses name set B for generation
    /// @return requestId The VRF request ID
    function requestCreatePlayer(bool useNameSetB) external payable returns (uint256 requestId);

    /// @notice Equips a skin to a player
    /// @param playerId The ID of the player
    /// @param skinIndex The index of the skin collection
    /// @param tokenId The token ID of the skin
    function equipSkin(uint32 playerId, uint32 skinIndex, uint16 tokenId) external;

    /// @notice Retires a player owned by the caller
    /// @param playerId The ID of the player to retire
    function retireOwnPlayer(uint32 playerId) external;

    // Game Contract Functions
    /// @notice Increments a player's win count
    /// @param playerId The ID of the player
    function incrementWins(uint32 playerId) external;

    /// @notice Increments a player's loss count
    /// @param playerId The ID of the player
    function incrementLosses(uint32 playerId) external;

    /// @notice Increments a player's kill count
    /// @param playerId The ID of the player
    function incrementKills(uint32 playerId) external;

    /// @notice Sets a player's retirement status
    /// @param playerId The ID of the player
    /// @param retired The new retirement status
    function setPlayerRetired(uint32 playerId, bool retired) external;

    /// @notice Updates a player's name indices
    /// @param playerId The ID of the player
    /// @param firstNameIndex Index in the name registry for first name
    /// @param surnameIndex Index in the name registry for surname
    function setPlayerName(uint32 playerId, uint16 firstNameIndex, uint16 surnameIndex) external;

    /// @notice Updates a player's attribute stats
    /// @param playerId The ID of the player
    /// @param strength New strength value (3-21)
    /// @param constitution New constitution value (3-21)
    /// @param size New size value (3-21)
    /// @param agility New agility value (3-21)
    /// @param stamina New stamina value (3-21)
    /// @param luck New luck value (3-21)
    function setPlayerAttributes(
        uint32 playerId,
        uint8 strength,
        uint8 constitution,
        uint8 size,
        uint8 agility,
        uint8 stamina,
        uint8 luck
    ) external;
}

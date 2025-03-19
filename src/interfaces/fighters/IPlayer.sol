// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./registries/names/IPlayerNameRegistry.sol";
import "./registries/skins/IPlayerSkinRegistry.sol";
import "../../fighters/Fighter.sol";
import "../game/engine/IEquipmentRequirements.sol";

/// @title Player Interface for Heavy Helms
/// @notice Defines the core functionality for player management and game interactions
interface IPlayer {
    //==============================================================//
    //                          STRUCTS                             //
    //==============================================================//
    /// @notice Contains all stats and attributes for a player
    /// @param attributes Attributes for player -> (strength, constitution, size, agility, stamina, luck)
    /// @param skin SkinInfo for player -> (skinIndex, skinTokenId)
    /// @param name Name for player -> (firstNameIndex, surnameIndex)
    /// @param record Record for player -> (wins, losses, kills)
    struct PlayerStats {
        Fighter.Attributes attributes;
        Fighter.SkinInfo skin;
        Fighter.Name name;
        Fighter.Record record;
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
        bool immortal;
    }

    //==============================================================//
    //                          ENUMS                               //
    //==============================================================//
    /// @notice Types of permissions that can be granted to game contracts
    enum GamePermission {
        RECORD,
        RETIRE,
        NAME,
        ATTRIBUTES,
        IMMORTAL
    }

    /// @notice Represents the different attributes that can be modified on a player
    /// @dev Used for attribute swapping functionality
    enum Attribute {
        STRENGTH,
        CONSTITUTION,
        SIZE,
        AGILITY,
        STAMINA,
        LUCK
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    // View Functions
    /// @notice Gets the name registry contract reference
    /// @return The PlayerNameRegistry contract instance
    function nameRegistry() external view returns (IPlayerNameRegistry);

    /// @notice Gets the skin registry contract reference
    /// @return The PlayerSkinRegistry contract instance
    function skinRegistry() external view returns (IPlayerSkinRegistry);

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

    /// @notice Get the number of player slots an address has
    /// @param owner The address to check slots for
    /// @return The number of player slots the address has
    function getPlayerSlots(address owner) external view returns (uint256);

    /// @notice Calculate the cost for the next slot batch purchase for an address
    /// @param user The address to calculate the cost for
    /// @return Cost in ETH for the next slot batch purchase
    function getNextSlotBatchCost(address user) external view returns (uint256);

    /// @notice Gets the number of active players for an address
    /// @param owner The address to check
    /// @return Number of active players
    function getActivePlayerCount(address owner) external view returns (uint256);

    /// @notice Check if a player is immortal
    /// @param playerId The ID of the player to check
    /// @return True if the player is immortal, false otherwise
    function isPlayerImmortal(uint32 playerId) external view returns (bool);

    /// @notice Gets the equipment requirements contract reference
    /// @return The EquipmentRequirements contract instance
    function equipmentRequirements() external view returns (IEquipmentRequirements);

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

    /// @notice Awards a name change charge to an address
    /// @param to Address to receive the charge
    function awardNameChange(address to) external;

    /// @notice Awards an attribute swap charge to an address
    /// @param to Address to receive the charge
    function awardAttributeSwap(address to) external;

    /// @notice Changes a player's name using a name change charge
    /// @param playerId The ID of the player to update
    /// @param firstNameIndex Index of the first name in the name registry
    /// @param surnameIndex Index of the surname in the name registry
    function changeName(uint32 playerId, uint16 firstNameIndex, uint16 surnameIndex) external;

    /// @notice Swaps attributes between two player attributes
    /// @param playerId The ID of the player to update
    /// @param decreaseAttribute The attribute to decrease
    /// @param increaseAttribute The attribute to increase
    function swapAttributes(uint32 playerId, Attribute decreaseAttribute, Attribute increaseAttribute) external;

    /// @notice Gets the number of name change charges available for an address
    /// @param owner The address to check
    /// @return Number of name change charges available
    function nameChangeCharges(address owner) external view returns (uint256);

    /// @notice Gets the number of attribute swap charges available for an address
    /// @param owner The address to check
    /// @return Number of attribute swap charges available
    function attributeSwapCharges(address owner) external view returns (uint256);

    /// @notice Purchase additional player slots
    /// @dev Each purchase adds 5 slots, cost increases linearly with number of existing extra slots
    /// @return Number of slots purchased
    function purchasePlayerSlots() external payable returns (uint8);

    /// @notice Set a player's immortality status
    /// @param playerId The ID of the player to update
    /// @param isImmortal The new immortality status
    function setPlayerImmortal(uint32 playerId, bool isImmortal) external;
}

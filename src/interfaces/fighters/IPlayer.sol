// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import "./registries/names/IPlayerNameRegistry.sol";
import "./registries/skins/IPlayerSkinRegistry.sol";
import "./IPlayerDataCodec.sol";
import "../../fighters/Fighter.sol";
import "../game/engine/IEquipmentRequirements.sol";

//==============================================================//
//                         HEAVY HELMS                          //
//                        PLAYER INTERFACE                      //
//==============================================================//
/// @title Player Interface for Heavy Helms
/// @notice Defines the core functionality for player management and game interactions
/// @dev Used for managing user-controlled characters
interface IPlayer {
    //==============================================================//
    //                          STRUCTS                             //
    //==============================================================//
    /// @notice Contains all stats and attributes for a player
    /// @param attributes Attributes for player -> (strength, constitution, size, agility, stamina, luck)
    /// @param skin SkinInfo for player -> (skinIndex, skinTokenId)
    /// @param name PlayerName for player -> (firstNameIndex, surnameIndex)
    /// @param level Player level (1-10)
    /// @param currentXP Experience points toward next level
    /// @param weaponSpecialization Weapon type specialization (255 = none)
    /// @param armorSpecialization Armor type specialization (255 = none)
    struct PlayerStats {
        Fighter.Attributes attributes;
        PlayerName name;
        Fighter.SkinInfo skin;
        uint8 stance;
        uint8 level;
        uint16 currentXP;
        uint8 weaponSpecialization;
        uint8 armorSpecialization;
    }

    struct PlayerName {
        uint16 firstNameIndex;
        uint16 surnameIndex;
    }

    /// @notice Permission flags for game contracts
    /// @param record Can modify game records (wins, losses, kills)
    /// @param retire Can modify player retirement status
    /// @param immortal Can modify player immortality status
    /// @param experience Can award experience points
    struct GamePermissions {
        bool record;
        bool retire;
        bool immortal;
        bool experience;
    }

    //==============================================================//
    //                          ENUMS                               //
    //==============================================================//
    /// @notice Types of permissions that can be granted to game contracts
    enum GamePermission {
        RECORD,
        RETIRE,
        IMMORTAL,
        EXPERIENCE
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

    /// @notice Gets the PlayerDataCodec contract reference
    /// @return The PlayerDataCodec contract instance
    function codec() external view returns (IPlayerDataCodec);

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

    /// @notice Gets the current cost for purchasing a slot batch
    /// @return The cost in wei for 1 slot
    function slotBatchCost() external view returns (uint256);

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

    /// @notice Check if a player ID is valid
    /// @param playerId The ID to check
    /// @return bool True if the ID is within valid player range
    function isValidId(uint32 playerId) external pure returns (bool);

    // State-Changing Functions
    /// @notice Requests creation of a new player with random stats
    /// @param useNameSetB If true, uses name set B for generation
    /// @return requestId The VRF request ID
    function requestCreatePlayer(bool useNameSetB) external payable returns (uint256 requestId);

    /// @notice Requests creation of a new player using CREATE_PLAYER_TICKET
    /// @param useNameSetB If true, uses name set B for generation
    /// @return requestId The VRF request ID
    function requestCreatePlayerWithTicket(bool useNameSetB) external returns (uint256 requestId);

    /// @notice Equips a skin to a player
    /// @param playerId The ID of the player
    /// @param skinIndex The index of the skin collection
    /// @param tokenId The token ID of the skin
    /// @param stance The new stance value
    function equipSkin(uint32 playerId, uint32 skinIndex, uint16 tokenId, uint8 stance) external;

    /// @notice Retires a player owned by the caller
    /// @param playerId The ID of the player to retire
    function retireOwnPlayer(uint32 playerId) external;

    // Game Contract Functions
    /// @notice Increments a player's win count
    /// @param playerId The ID of the player
    /// @param season The season to record the win in
    function incrementWins(uint32 playerId, uint256 season) external;

    /// @notice Increments a player's loss count
    /// @param playerId The ID of the player
    /// @param season The season to record the loss in
    function incrementLosses(uint32 playerId, uint256 season) external;

    /// @notice Increments a player's kill count
    /// @param playerId The ID of the player
    /// @param season The season to record the kill in
    function incrementKills(uint32 playerId, uint256 season) external;

    /// @notice Sets a player's retirement status
    /// @param playerId The ID of the player
    /// @param retired The new retirement status
    function setPlayerRetired(uint32 playerId, bool retired) external;

    /// @notice Changes a player's name by burning a name change NFT
    /// @param playerId The ID of the player to update
    /// @param nameChangeTokenId The token ID of the name change NFT to burn
    function changeName(uint32 playerId, uint256 nameChangeTokenId) external;

    /// @notice Swaps attributes between two player attributes
    /// @param playerId The ID of the player to update
    /// @param decreaseAttribute The attribute to decrease
    /// @param increaseAttribute The attribute to increase
    function swapAttributes(uint32 playerId, Attribute decreaseAttribute, Attribute increaseAttribute) external;

    /// @notice Gets the number of available attribute points for a player
    /// @param playerId The player ID to check
    /// @return Number of available attribute points from leveling
    function attributePoints(uint32 playerId) external view returns (uint256);

    /// @notice Uses an attribute point earned from leveling to increase a player's attribute by 1
    /// @param playerId The ID of the player to update
    /// @param attribute The attribute to increase
    function useAttributePoint(uint32 playerId, Attribute attribute) external;

    /// @notice Calculates XP required for a specific level
    /// @param level The level to calculate XP requirement for
    /// @return XP required to reach that level from previous level
    function getXPRequiredForLevel(uint8 level) external pure returns (uint16);

    /// @notice Purchase additional player slots
    /// @dev Each purchase adds exactly 1 slot for a fixed cost
    function purchasePlayerSlots() external payable;

    /// @notice Purchase additional player slots using PLAYER_SLOT_TICKET tokens
    /// @dev Burns exactly 1 ticket to add 1 slot
    function purchasePlayerSlotsWithTickets() external;

    /// @notice Set a player's immortality status
    /// @param playerId The ID of the player to update
    /// @param isImmortal The new immortality status
    function setPlayerImmortal(uint32 playerId, bool isImmortal) external;

    /// @notice Awards experience points to a player and handles level ups
    /// @param playerId The ID of the player to award experience to
    /// @param xpAmount The amount of experience to award
    function awardExperience(uint32 playerId, uint16 xpAmount) external;

    /// @notice Sets weapon specialization for a player
    /// @param playerId The ID of the player
    /// @param weaponType The weapon type to specialize in (255 = none)
    function setWeaponSpecialization(uint32 playerId, uint8 weaponType) external;

    /// @notice Sets armor specialization for a player
    /// @param playerId The ID of the player
    /// @param armorType The armor type to specialize in (255 = none)
    function setArmorSpecialization(uint32 playerId, uint8 armorType) external;

    /// @notice Gets the current season number (view-only)
    /// @return The current season ID
    function currentSeason() external view returns (uint256);

    /// @notice Forces season update check and returns current season
    /// @return The current season ID (auto-updates if season transition is due)
    function forceCurrentSeason() external returns (uint256);

    /// @notice Gets the current season record for a player
    /// @param playerId The ID of the player
    /// @return record The player's record for the current season
    function getCurrentSeasonRecord(uint32 playerId) external view returns (Fighter.Record memory);

    /// @notice Gets the lifetime record for a player
    /// @param playerId The ID of the player
    /// @return record The player's lifetime record (all seasons combined)
    function getLifetimeRecord(uint32 playerId) external view returns (Fighter.Record memory);

    /// @notice Gets the record for a player in a specific season
    /// @param playerId The ID of the player
    /// @param seasonId The season ID to get the record for
    /// @return record The player's record for the specified season
    function getSeasonRecord(uint32 playerId, uint256 seasonId) external view returns (Fighter.Record memory);
}

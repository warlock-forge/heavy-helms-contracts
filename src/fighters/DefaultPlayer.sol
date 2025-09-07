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
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {Fighter} from "./Fighter.sol";
import {IPlayer} from "../interfaces/fighters/IPlayer.sol";
import {IDefaultPlayer} from "../interfaces/fighters/IDefaultPlayer.sol";
import {IPlayerNameRegistry} from "../interfaces/fighters/registries/names/IPlayerNameRegistry.sol";
import {IPlayerSkinRegistry} from "../interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
/// @notice Thrown when attempting to access a player that doesn't exist
/// @param playerId The ID of the non-existent player
error PlayerDoesNotExist(uint32 playerId);
/// @param playerId The ID of the DefaultPlayer that already exists
error DefaultPlayerExists(uint32 playerId);
/// @notice Thrown when attempting to use an invalid player ID outside the default player range
error InvalidDefaultPlayerRange();
/// @notice Thrown when a required address argument is the zero address
error BadZeroAddress();
/// @notice Thrown when an invalid name index is provided
error InvalidNameIndex();
/// @notice Thrown when attempting to use a skin type not compatible with default players
/// @param skinIndex The invalid skin index
error InvalidDefaultPlayerSkinType(uint32 skinIndex);

//==============================================================//
//                         HEAVY HELMS                          //
//                        DEFAULT PLAYER                        //
//==============================================================//
/// @title Default Player Contract for Heavy Helms
/// @notice Manages default player characters for the game
/// @dev Default players are pre-created game characters (IDs 1-2000)
contract DefaultPlayer is IDefaultPlayer, ConfirmedOwner, Fighter {
    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    /// @notice Reference to the name registry contract for player names
    IPlayerNameRegistry private immutable _nameRegistry;

    /// @notice Maps default player ID to their stats progression across all levels
    /// @dev Each default player has complete stats for levels 1-10
    mapping(uint32 => IPlayer.PlayerStats[10]) private _defaultPlayerProgressions;

    /// @notice Array of all valid default player IDs that have been created
    uint32[] private validDefaultPlayerIds;

    /// @notice Count of valid default players (gas-efficient alternative to array.length)
    uint256 public validDefaultPlayerCount;

    /// @notice ID range constants for default players
    /// @dev Default players occupy IDs 1-2000
    uint32 private constant DEFAULT_PLAYER_START = 1;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a default player's stats are updated
    /// @param playerId The ID of the player that was updated
    /// @param stats The new stats for the player
    event DefaultPlayerStatsUpdated(uint32 indexed playerId, IPlayer.PlayerStats stats);

    /// @notice Emitted when a new default player is created
    /// @param playerId The ID of the newly created player
    /// @param allLevelStats Array of stats for all 10 levels
    event DefaultPlayerCreated(uint32 indexed playerId, IPlayer.PlayerStats[10] allLevelStats);

    //==============================================================//
    //                        MODIFIERS                             //
    //==============================================================//
    /// @notice Ensures the default player ID is within valid range and exists
    /// @param playerId The ID of the default player to check
    /// @dev Reverts with InvalidDefaultPlayerRange or PlayerDoesNotExist if validation fails
    modifier defaultPlayerExists(uint32 playerId) {
        if (!isValidId(playerId)) {
            revert InvalidDefaultPlayerRange();
        }
        if (_defaultPlayerProgressions[playerId][0].attributes.strength == 0) {
            revert PlayerDoesNotExist(playerId);
        }
        _;
    }

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    /// @notice Initializes the DefaultPlayer contract
    /// @param skinRegistryAddress Address of the skin registry contract
    /// @param nameRegistryAddress Address of the name registry contract
    /// @dev Reverts with BadZeroAddress if any address is zero
    constructor(address skinRegistryAddress, address nameRegistryAddress)
        ConfirmedOwner(msg.sender)
        Fighter(skinRegistryAddress)
    {
        if (nameRegistryAddress == address(0)) {
            revert BadZeroAddress();
        }
        _nameRegistry = IPlayerNameRegistry(nameRegistryAddress);
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    // View Functions
    /// @notice Gets the name registry contract reference
    /// @return The PlayerNameRegistry contract instance
    function nameRegistry() public view returns (IPlayerNameRegistry) {
        return _nameRegistry;
    }

    /// @notice Check if a default player ID is valid
    /// @param playerId The ID to check
    /// @return bool True if the ID is within valid default player range
    function isValidId(uint32 playerId) public pure override(IDefaultPlayer, Fighter) returns (bool) {
        return playerId >= DEFAULT_PLAYER_START && playerId <= Fighter.DEFAULT_PLAYER_END;
    }

    /// @notice Get the complete stats for a default player at a specific level
    /// @param playerId The ID of the default player to query
    /// @param level The level to get stats for (1-10)
    /// @return PlayerStats struct containing all player data at the specified level
    /// @dev Reverts if the player doesn't exist or level is invalid
    function getDefaultPlayer(uint32 playerId, uint8 level)
        external
        view
        defaultPlayerExists(playerId)
        returns (IPlayer.PlayerStats memory)
    {
        require(level >= 1 && level <= 10, "Invalid level");
        return _defaultPlayerProgressions[playerId][level - 1];
    }

    /// @notice Gets the skin registry contract reference
    /// @return The PlayerSkinRegistry contract instance
    function skinRegistry() public view override(Fighter, IDefaultPlayer) returns (IPlayerSkinRegistry) {
        return super.skinRegistry();
    }

    /// @notice Gets a valid default player ID by index
    /// @param index The index in the valid IDs array (0 to validDefaultPlayerCount-1)
    /// @return The default player ID at that index
    function getValidDefaultPlayerId(uint256 index) external view returns (uint32) {
        require(index < validDefaultPlayerIds.length, "Index out of bounds");
        return validDefaultPlayerIds[index];
    }

    // State-Changing Functions
    /// @notice Creates a new default player with specified stats for all levels
    /// @param playerId The ID to assign to the new default player
    /// @param allLevelStats Array of stats for levels 1-10
    /// @dev Only callable by the contract owner
    function createDefaultPlayer(uint32 playerId, IPlayer.PlayerStats[10] memory allLevelStats) external onlyOwner {
        if (!isValidId(playerId)) {
            revert InvalidDefaultPlayerRange();
        }
        if (_defaultPlayerProgressions[playerId][0].attributes.strength != 0) {
            revert DefaultPlayerExists(playerId);
        }

        // Validate all level stats (using level 1 for skin/name validation)
        IPlayer.PlayerStats memory level1Stats = allLevelStats[0];

        // Verify skin exists and is valid for default players
        IPlayerSkinRegistry.SkinCollectionInfo memory skinCollection =
            skinRegistry().getSkin(level1Stats.skin.skinIndex);
        if (skinCollection.skinType != IPlayerSkinRegistry.SkinType.DefaultPlayer) {
            revert InvalidDefaultPlayerSkinType(level1Stats.skin.skinIndex);
        }

        // Validate name indices
        if (
            !nameRegistry().isValidFirstNameIndex(level1Stats.name.firstNameIndex)
                || level1Stats.name.surnameIndex >= nameRegistry().getSurnamesLength()
        ) {
            revert InvalidNameIndex();
        }

        // Store all level progressions
        _defaultPlayerProgressions[playerId] = allLevelStats;

        // Add to valid IDs list
        validDefaultPlayerIds.push(playerId);
        validDefaultPlayerCount++;

        // Emit event for new player creation
        emit DefaultPlayerCreated(playerId, allLevelStats);
    }

    /// @notice Updates the stats of an existing default player for all levels
    /// @param playerId The ID of the default player to update
    /// @param newAllLevelStats The new stats to assign to the player for all levels 1-10
    /// @dev Only callable by the contract owner, requires player to exist
    function updateDefaultPlayerStats(uint32 playerId, IPlayer.PlayerStats[10] memory newAllLevelStats)
        external
        onlyOwner
        defaultPlayerExists(playerId)
    {
        // Validate all level stats (using level 1 for skin/name validation)
        IPlayer.PlayerStats memory level1Stats = newAllLevelStats[0];

        // Verify skin exists and is valid for default players
        IPlayerSkinRegistry.SkinCollectionInfo memory skinCollection =
            skinRegistry().getSkin(level1Stats.skin.skinIndex);
        if (skinCollection.skinType != IPlayerSkinRegistry.SkinType.DefaultPlayer) {
            revert InvalidDefaultPlayerSkinType(level1Stats.skin.skinIndex);
        }

        // Validate name indices
        if (
            !nameRegistry().isValidFirstNameIndex(level1Stats.name.firstNameIndex)
                || level1Stats.name.surnameIndex >= nameRegistry().getSurnamesLength()
        ) {
            revert InvalidNameIndex();
        }

        // Update all level progressions
        _defaultPlayerProgressions[playerId] = newAllLevelStats;

        emit DefaultPlayerStatsUpdated(playerId, level1Stats);
    }
}

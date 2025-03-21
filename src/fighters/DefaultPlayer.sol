// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import "solmate/src/auth/Owned.sol";
import "./Fighter.sol";
import "../interfaces/fighters/IPlayer.sol";
import "../interfaces/fighters/IDefaultPlayer.sol";
import "../interfaces/fighters/registries/names/IPlayerNameRegistry.sol";

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
contract DefaultPlayer is IDefaultPlayer, Owned, Fighter {
    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    /// @notice Reference to the name registry contract for player names
    IPlayerNameRegistry private immutable _nameRegistry;

    /// @notice Maps default player ID to their stats
    /// @dev Only IDs within DEFAULT_PLAYER_START and DEFAULT_PLAYER_END range are valid
    mapping(uint32 => IPlayer.PlayerStats) private _defaultPlayers;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a default player's stats are updated
    /// @param playerId The ID of the player that was updated
    /// @param stats The new stats for the player
    event DefaultPlayerStatsUpdated(uint32 indexed playerId, IPlayer.PlayerStats stats);

    /// @notice Emitted when a new default player is created
    /// @param playerId The ID of the newly created player
    /// @param stats The stats for the new player
    event DefaultPlayerCreated(uint32 indexed playerId, IPlayer.PlayerStats stats);

    /// @notice ID range constants for default players
    /// @dev Default players occupy IDs 1-2000
    uint32 private constant DEFAULT_PLAYER_START = 1;
    uint32 private constant DEFAULT_PLAYER_END = 2000;

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
        if (_defaultPlayers[playerId].attributes.strength == 0) {
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
        Owned(msg.sender)
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
        return playerId >= DEFAULT_PLAYER_START && playerId <= DEFAULT_PLAYER_END;
    }

    /// @notice Get the current skin information for a default player
    /// @param playerId The ID of the default player
    /// @return The default player's equipped skin information (index and token ID)
    function getCurrentSkin(uint32 playerId) public view override(IDefaultPlayer, Fighter) returns (SkinInfo memory) {
        IPlayer.PlayerStats memory stats = _defaultPlayers[playerId];
        return stats.skin;
    }

    /// @notice Get the complete stats for a default player
    /// @param playerId The ID of the default player to query
    /// @return PlayerStats struct containing all player data
    /// @dev Reverts if the player doesn't exist
    function getDefaultPlayer(uint32 playerId)
        external
        view
        defaultPlayerExists(playerId)
        returns (IPlayer.PlayerStats memory)
    {
        return _defaultPlayers[playerId];
    }

    /// @notice Gets the skin registry contract reference
    /// @return The PlayerSkinRegistry contract instance
    function skinRegistry() public view override(Fighter, IDefaultPlayer) returns (IPlayerSkinRegistry) {
        return super.skinRegistry();
    }

    // State-Changing Functions
    /// @notice Creates a new default player with specified stats
    /// @param playerId The ID to assign to the new default player
    /// @param stats The stats to assign to the player
    /// @dev Only callable by the contract owner
    function createDefaultPlayer(uint32 playerId, IPlayer.PlayerStats memory stats) external onlyOwner {
        if (!isValidId(playerId)) {
            revert InvalidDefaultPlayerRange();
        }
        if (_defaultPlayers[playerId].attributes.strength != 0) {
            revert DefaultPlayerExists(playerId);
        }

        // Verify skin exists and is valid for default players
        IPlayerSkinRegistry.SkinCollectionInfo memory skinCollection = skinRegistry().getSkin(stats.skin.skinIndex);
        if (skinCollection.skinType != IPlayerSkinRegistry.SkinType.DefaultPlayer) {
            revert InvalidDefaultPlayerSkinType(stats.skin.skinIndex);
        }

        // Validate name indices
        if (
            !nameRegistry().isValidFirstNameIndex(stats.name.firstNameIndex)
                || stats.name.surnameIndex >= nameRegistry().getSurnamesLength()
        ) {
            revert InvalidNameIndex();
        }

        _defaultPlayers[playerId] = stats;

        // Emit event for new player creation
        emit DefaultPlayerCreated(playerId, stats);
    }

    /// @notice Updates the stats of an existing default player
    /// @param playerId The ID of the default player to update
    /// @param newStats The new stats to assign to the player
    /// @dev Only callable by the contract owner, requires player to exist
    function updateDefaultPlayerStats(uint32 playerId, IPlayer.PlayerStats memory newStats)
        external
        onlyOwner
        defaultPlayerExists(playerId)
    {
        // Verify skin exists and is valid for default players
        IPlayerSkinRegistry.SkinCollectionInfo memory skinCollection = skinRegistry().getSkin(newStats.skin.skinIndex);
        if (skinCollection.skinType != IPlayerSkinRegistry.SkinType.DefaultPlayer) {
            revert InvalidDefaultPlayerSkinType(newStats.skin.skinIndex);
        }

        // Validate name indices
        if (
            !nameRegistry().isValidFirstNameIndex(newStats.name.firstNameIndex)
                || newStats.name.surnameIndex >= nameRegistry().getSurnamesLength()
        ) {
            revert InvalidNameIndex();
        }

        _defaultPlayers[playerId] = newStats;

        emit DefaultPlayerStatsUpdated(playerId, newStats);
    }

    //==============================================================//
    //                    INTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Get the base attributes for a default player
    /// @param playerId The ID of the default player
    /// @return attributes The default player's base attributes
    /// @dev Used by the Fighter base contract for stat-based calculations
    function getFighterAttributes(uint32 playerId) internal view override returns (Attributes memory) {
        IPlayer.PlayerStats memory stats = _defaultPlayers[playerId];
        return stats.attributes;
    }
}

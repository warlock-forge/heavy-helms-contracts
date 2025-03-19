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
error PlayerDoesNotExist(uint32 playerId);
error InvalidDefaultPlayerRange();
error BadZeroAddress();
error InvalidNameIndex();
error InvalidDefaultPlayerSkinType(uint32 skinIndex);

//==============================================================//
//                         HEAVY HELMS                          //
//                        DEFAULT PLAYER                        //
//==============================================================//
contract DefaultPlayer is IDefaultPlayer, Owned, Fighter {
    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    // Contract References
    IPlayerNameRegistry private immutable _nameRegistry;

    // Player state tracking
    // Maps default player ID to their stats
    mapping(uint32 => IPlayer.PlayerStats) private _defaultPlayers;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    event DefaultPlayerStatsUpdated(uint32 indexed playerId, IPlayer.PlayerStats stats);
    event DefaultPlayerCreated(uint32 indexed playerId, IPlayer.PlayerStats stats);

    // Constants
    uint32 private constant DEFAULT_PLAYER_START = 1;
    uint32 private constant DEFAULT_PLAYER_END = 2000;

    //==============================================================//
    //                        MODIFIERS                             //
    //==============================================================//
    /// @notice Ensures the default player ID is within valid range and exists
    /// @param playerId The ID of the default player to check
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
    function nameRegistry() public view returns (IPlayerNameRegistry) {
        return _nameRegistry;
    }

    /// @notice Check if a default player ID is valid
    /// @param playerId The ID to check
    /// @return bool True if the ID is within valid default player range
    function isValidId(uint32 playerId) public pure override returns (bool) {
        return playerId >= DEFAULT_PLAYER_START && playerId <= DEFAULT_PLAYER_END;
    }

    /// @notice Get the current skin information for a default player
    /// @param playerId The ID of the default player
    /// @return The default player's equipped skin information (index and token ID)
    function getCurrentSkin(uint32 playerId) public view override returns (SkinInfo memory) {
        IPlayer.PlayerStats memory stats = _defaultPlayers[playerId];
        return stats.skin;
    }

    function getDefaultPlayer(uint32 playerId)
        external
        view
        defaultPlayerExists(playerId)
        returns (IPlayer.PlayerStats memory)
    {
        return _defaultPlayers[playerId];
    }

    // State-Changing Functions
    function setDefaultPlayer(uint32 playerId, IPlayer.PlayerStats memory stats) external onlyOwner {
        if (!isValidId(playerId)) {
            revert InvalidDefaultPlayerRange();
        }

        // Verify skin exists and is valid for default players
        IPlayerSkinRegistry.SkinCollectionInfo memory skinCollection = skinRegistry().getSkin(stats.skin.skinIndex);
        if (skinCollection.skinType != IPlayerSkinRegistry.SkinType.DefaultPlayer) {
            revert InvalidDefaultPlayerSkinType(stats.skin.skinIndex);
        }

        // Validate name indices
        if (
            !nameRegistry().isValidFirstNameIndex(stats.firstNameIndex)
                || stats.surnameIndex >= nameRegistry().getSurnamesLength()
        ) {
            revert InvalidNameIndex();
        }

        _defaultPlayers[playerId] = stats;

        // Emit event for new player creation
        emit DefaultPlayerCreated(playerId, stats);
    }

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
            !nameRegistry().isValidFirstNameIndex(newStats.firstNameIndex)
                || newStats.surnameIndex >= nameRegistry().getSurnamesLength()
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
    function getFighterAttributes(uint32 playerId) internal view override returns (Attributes memory) {
        IPlayer.PlayerStats memory stats = _defaultPlayers[playerId];
        return stats.attributes;
    }
}

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
import {IPlayerSkinRegistry} from "../interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";
import {IPlayerSkinNFT} from "../interfaces/nft/skins/IPlayerSkinNFT.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
/// @notice Thrown when a zero address is provided for skin registry
error InvalidSkinRegistry();
/// @notice Thrown when an invalid skin is provided
error InvalidSkin();

//==============================================================//
//                         HEAVY HELMS                          //
//                           FIGHTER                            //
//==============================================================//
/// @title Fighter Base Contract for Heavy Helms
/// @notice Abstract base contract for all fighter types (players, monsters, etc.)
/// @dev Provides common functionality for all fighter types
abstract contract Fighter {
    //==============================================================//
    //                          STRUCTS                             //
    //==============================================================//
    /// @notice Information about a fighter's equipped gear and ID
    /// @param playerId The ID of the fighter
    /// @param skin The skin information (index and token ID)
    struct PlayerLoadout {
        uint32 playerId;
        SkinInfo skin;
        uint8 stance;
    }

    /// @notice Core attributes that define a fighter's capabilities
    /// @param strength Affects damage output
    /// @param constitution Affects health points
    /// @param size Affects carrying capacity and some combat mechanics
    /// @param agility Affects dodge chance and speed
    /// @param stamina Affects endurance and action points
    /// @param luck Affects critical hit chance and rare item finds
    struct Attributes {
        uint8 strength;
        uint8 constitution;
        uint8 size;
        uint8 agility;
        uint8 stamina;
        uint8 luck;
    }

    /// @notice Information about a fighter's equipped skin
    /// @param skinIndex The index of the skin collection in the registry
    /// @param skinTokenId The specific token ID within the collection
    struct SkinInfo {
        uint32 skinIndex;
        uint16 skinTokenId;
    }

    /// @notice A fighter's combat statistics
    /// @param wins Number of victories
    /// @param losses Number of defeats
    /// @param kills Number of kills (opponents defeated)
    struct Record {
        uint16 wins;
        uint16 losses;
        uint16 kills;
    }

    //==============================================================//
    //                          ENUMS                               //
    //==============================================================//
    enum FighterType {
        DEFAULT_PLAYER,
        MONSTER,
        PLAYER
    }

    //==============================================================//
    //                          CONSTANTS                           //
    //==============================================================//
    /// @notice End of default player ID range
    uint32 internal constant DEFAULT_PLAYER_END = 2000;
    /// @notice End of monster ID range
    uint32 internal constant MONSTER_END = 10000;

    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    /// @notice Reference to the skin registry contract
    /// @dev Immutable reference set during construction
    IPlayerSkinRegistry private immutable _skinRegistry;

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    /// @notice Initializes the Fighter contract
    /// @param skinRegistryAddress Address of the skin registry contract
    /// @dev Reverts if the skin registry address is zero
    constructor(address skinRegistryAddress) {
        if (skinRegistryAddress == address(0)) revert InvalidSkinRegistry();
        _skinRegistry = IPlayerSkinRegistry(skinRegistryAddress);
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Gets the skin registry contract reference
    /// @return The PlayerSkinRegistry contract instance
    function skinRegistry() public view virtual returns (IPlayerSkinRegistry) {
        return _skinRegistry;
    }

    //==============================================================//
    //                    INTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Determines the fighter type based on ID range
    /// @param playerId The ID to check
    /// @return The fighter type (DEFAULT_PLAYER, MONSTER, or PLAYER)
    function _getFighterType(uint32 playerId) internal pure returns (FighterType) {
        if (playerId <= DEFAULT_PLAYER_END) {
            return FighterType.DEFAULT_PLAYER;
        } else if (playerId <= MONSTER_END) {
            return FighterType.MONSTER;
        } else {
            return FighterType.PLAYER;
        }
    }

    function getSkinAttributes(SkinInfo memory skin) public view returns (IPlayerSkinNFT.SkinAttributes memory) {
        IPlayerSkinRegistry skinReg = skinRegistry();
        IPlayerSkinRegistry.SkinCollectionInfo memory skinInfo = skinReg.getSkin(skin.skinIndex);

        // Validate skin collection exists
        if (skinInfo.contractAddress == address(0)) revert InvalidSkin();

        return IPlayerSkinNFT(skinInfo.contractAddress).getSkinAttributes(skin.skinTokenId);
    }

    //==============================================================//
    //                    VIRTUAL FUNCTIONS                         //
    //==============================================================//
    /// @notice Check if a fighter ID is valid
    /// @param playerId The ID to check
    /// @return True if the ID is valid for the specific fighter type
    /// @dev Must be implemented by child contracts to define valid ID ranges
    function isValidId(uint32 playerId) public pure virtual returns (bool);
}

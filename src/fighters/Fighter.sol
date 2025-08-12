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
import "../interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";
import "../interfaces/game/engine/IGameEngine.sol";
import "../interfaces/nft/skins/IPlayerSkinNFT.sol";

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
        require(skinRegistryAddress != address(0), "Invalid skin registry");
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

    /// @notice Get stats for a fighter with their currently equipped skin
    /// @param playerId The ID of the fighter
    /// @return Complete fighter stats including weapon, armor, stance and attributes
    /// @dev Combines base attributes with skin/equipment modifiers
    function getFighterStats(uint32 playerId) external view returns (IGameEngine.FighterStats memory) {
        require(isValidId(playerId), "Invalid player ID");

        // Get base attributes (fighter-type aware)
        Attributes memory attributes;
        FighterType fighterType = _getFighterType(playerId);

        if (fighterType == FighterType.PLAYER) {
            attributes = getCurrentAttributes(playerId);
        } else {
            // For DefaultPlayer/Monster, use level 5 as default
            attributes = getAttributesAtLevel(playerId, 5);
        }

        // Get current skin info (fighter-type aware)
        SkinInfo memory skinInfo;
        if (fighterType == FighterType.PLAYER) {
            skinInfo = getCurrentSkin(playerId);
        } else {
            // For DefaultPlayer/Monster, use level 5 as default
            skinInfo = getSkinAtLevel(playerId, 5);
        }

        // Get stance (fighter-type aware)
        uint8 stance;
        if (fighterType == FighterType.PLAYER) {
            stance = getCurrentStance(playerId);
        } else {
            // For DefaultPlayer/Monster, use level 5 as default
            stance = getStanceAtLevel(playerId, 5);
        }

        // Get skin attributes
        IPlayerSkinRegistry skinReg = skinRegistry(); // Get the registry instance first
        IPlayerSkinRegistry.SkinCollectionInfo memory skinInfoFromRegistry = skinReg.getSkin(skinInfo.skinIndex);
        IPlayerSkinNFT.SkinAttributes memory skinAttrs =
            IPlayerSkinNFT(skinInfoFromRegistry.contractAddress).getSkinAttributes(skinInfo.skinTokenId);

        return IGameEngine.FighterStats({
            weapon: skinAttrs.weapon,
            armor: skinAttrs.armor,
            stance: stance,
            attributes: attributes
        });
    }

    /// @notice Convert a loadout configuration to complete fighter stats
    /// @param loadout The loadout configuration (playerId and skin)
    /// @return Complete fighter stats for the specified loadout
    /// @dev Allows calculating stats for hypothetical loadouts
    function convertToFighterStats(PlayerLoadout memory loadout)
        public
        view
        returns (IGameEngine.FighterStats memory)
    {
        require(isValidId(loadout.playerId), "Invalid player ID");

        // Get base attributes (fighter-type aware)
        Attributes memory attributes;
        FighterType fighterType = _getFighterType(loadout.playerId);

        if (fighterType == FighterType.PLAYER) {
            attributes = getCurrentAttributes(loadout.playerId);
        } else {
            // For DefaultPlayer/Monster, use level 5 as default in practice
            attributes = getAttributesAtLevel(loadout.playerId, 5);
        }

        // Get skin data from loadout
        IPlayerSkinRegistry skinReg = skinRegistry();
        IPlayerSkinRegistry.SkinCollectionInfo memory skinInfo = skinReg.getSkin(loadout.skin.skinIndex);
        IPlayerSkinNFT.SkinAttributes memory skinAttrs =
            IPlayerSkinNFT(skinInfo.contractAddress).getSkinAttributes(loadout.skin.skinTokenId);

        return IGameEngine.FighterStats({
            weapon: skinAttrs.weapon,
            armor: skinAttrs.armor,
            stance: loadout.stance,
            attributes: attributes
        });
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

    //==============================================================//
    //                    VIRTUAL FUNCTIONS                         //
    //==============================================================//
    /// @notice Check if a fighter ID is valid
    /// @param playerId The ID to check
    /// @return True if the ID is valid for the specific fighter type
    /// @dev Must be implemented by child contracts to define valid ID ranges
    function isValidId(uint32 playerId) public pure virtual returns (bool);

    /// @notice Get the current skin information for a fighter
    /// @param playerId The ID of the fighter
    /// @return The fighter's equipped skin information (index and token ID)
    /// @dev Must be implemented by child contracts
    function getCurrentSkin(uint32 playerId) public view virtual returns (SkinInfo memory);

    /// @notice Get the current stance for a fighter
    /// @param playerId The ID of the fighter
    /// @return The fighter's current stance
    /// @dev Must be implemented by child contracts
    function getCurrentStance(uint32 playerId) public view virtual returns (uint8);

    /// @notice Get the current attributes for a fighter
    /// @param playerId The ID of the fighter
    /// @return attributes The fighter's current base attributes
    /// @dev Must be implemented by child contracts
    function getCurrentAttributes(uint32 playerId) public view virtual returns (Attributes memory);

    /// @notice Get the current combat record for a fighter
    /// @param playerId The ID of the fighter
    /// @return The fighter's current win/loss/kill record
    /// @dev Must be implemented by child contracts
    function getCurrentRecord(uint32 playerId) public view virtual returns (Record memory);

    //==============================================================//
    //                  LEVEL-AWARE VIRTUAL FUNCTIONS               //
    //==============================================================//
    /// @notice Get attributes for a fighter at a specific level
    /// @param playerId The ID of the fighter
    /// @param level The level to get attributes for
    /// @return attributes The fighter's attributes at the specified level
    /// @dev Player type should revert, DefaultPlayer/Monster should implement
    function getAttributesAtLevel(uint32 playerId, uint8 level) public view virtual returns (Attributes memory);

    /// @notice Get stance for a fighter at a specific level
    /// @param playerId The ID of the fighter
    /// @param level The level to get stance for
    /// @return The fighter's stance at the specified level
    /// @dev Player type should revert, DefaultPlayer/Monster should implement
    function getStanceAtLevel(uint32 playerId, uint8 level) public view virtual returns (uint8);

    /// @notice Get skin for a fighter at a specific level
    /// @param playerId The ID of the fighter
    /// @param level The level to get skin for
    /// @return The fighter's skin at the specified level
    /// @dev Player type should revert, DefaultPlayer/Monster should implement
    function getSkinAtLevel(uint32 playerId, uint8 level) public view virtual returns (SkinInfo memory);

    /// @notice Get record for a fighter at a specific level
    /// @param playerId The ID of the fighter
    /// @param level The level to get record for
    /// @return The fighter's record at the specified level
    /// @dev Player type should revert, DefaultPlayer/Monster should implement
    function getRecordAtLevel(uint32 playerId, uint8 level) public view virtual returns (Record memory);
}

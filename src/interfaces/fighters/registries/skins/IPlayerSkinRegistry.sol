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
import "../../../../fighters/Fighter.sol";
import "../../../game/engine/IEquipmentRequirements.sol";

//==============================================================//
//                    PLAYER SKIN REGISTRY                      //
//                          INTERFACE                           //
//==============================================================//
/// @title Player Skin Registry Interface for Heavy Helms
/// @notice Defines functionality for managing player skin collections
interface IPlayerSkinRegistry {
    //==============================================================//
    //                          ENUMS                               //
    //==============================================================//
    /// @notice Types of skins with different ownership requirements
    /// @param Player Regular player skins that need ownership
    /// @param DefaultPlayer Default skins anyone can use
    /// @param Monster Monster-only skins
    enum SkinType {
        Player,
        DefaultPlayer,
        Monster
    }

    //==============================================================//
    //                          STRUCTS                             //
    //==============================================================//
    /// @notice Information about a registered skin collection
    /// @param contractAddress Address of the skin NFT contract
    /// @param isVerified Whether the collection is verified
    /// @param skinType Type of the skin
    /// @param requiredNFTAddress Optional NFT required to use skins
    struct SkinCollectionInfo {
        address contractAddress;
        bool isVerified;
        SkinType skinType;
        address requiredNFTAddress; // For collections requiring NFT ownership
    }

    //==============================================================//
    //                       VIEW FUNCTIONS                         //
    //==============================================================//
    /// @notice Gets information about a specific skin collection
    /// @param index Registry ID to query
    /// @return SkinCollectionInfo struct containing collection details
    function getSkin(uint32 index) external view returns (SkinCollectionInfo memory);

    /// @notice Validates ownership of a skin or required NFT
    /// @param skin The skin information (index and token ID)
    /// @param owner Address to check ownership for
    /// @dev Reverts if ownership validation fails
    function validateSkinOwnership(Fighter.SkinInfo memory skin, address owner) external view;

    /// @notice Gets all verified skin collections
    /// @return Array of verified SkinCollectionInfo structs
    function getVerifiedSkins() external view returns (SkinCollectionInfo[] memory);

    /// @notice Validates skin requirements against player attributes
    /// @param skin The skin information (index and token ID)
    /// @param attributes The attributes of the player
    /// @param equipmentRequirements The EquipmentRequirements contract
    /// @dev Reverts if requirements are not met
    function validateSkinRequirements(
        Fighter.SkinInfo memory skin,
        Fighter.Attributes memory attributes,
        IEquipmentRequirements equipmentRequirements
    ) external view;

    //==============================================================//
    //                    STATE-CHANGING FUNCTIONS                  //
    //==============================================================//
    /// @notice Registers a new skin collection
    /// @param contractAddress Address of the skin NFT contract
    /// @return Registry ID of the new collection
    function registerSkin(address contractAddress) external payable returns (uint32);

    /// @notice The current fee required to register a new skin collection
    /// @return Fee amount in wei
    function registrationFee() external view returns (uint256);
}

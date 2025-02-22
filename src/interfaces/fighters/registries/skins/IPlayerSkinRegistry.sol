// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Fighter.sol";
import "./IEquipmentRequirements.sol";

interface IPlayerSkinRegistry {
    enum SkinType {
        Player, // Regular player skins that need ownership
        DefaultPlayer, // Default skins anyone can use
        Monster // Monster-only skins

    }

    //==============================================================//
    //                     TYPE DECLARATIONS                        //
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

    function getSkin(uint32 index) external view returns (SkinCollectionInfo memory);
    function validateSkinOwnership(Fighter.SkinInfo memory skin, address owner) external view;
    function getVerifiedSkins() external view returns (SkinCollectionInfo[] memory);
    function validateSkinRequirements(
        Fighter.SkinInfo memory skin,
        Fighter.Attributes memory attributes,
        IEquipmentRequirements equipmentRequirements
    ) external view;
}

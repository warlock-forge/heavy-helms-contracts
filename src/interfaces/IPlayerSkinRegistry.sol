// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPlayerSkinRegistry {
    //==============================================================//
    //                     TYPE DECLARATIONS                        //
    //==============================================================//
    /// @notice Information about a registered skin collection
    /// @param contractAddress Address of the skin NFT contract
    /// @param isVerified Whether the collection is verified
    /// @param isDefaultCollection Whether it's a default collection
    /// @param requiredNFTAddress Optional NFT required to use skins
    struct SkinInfo {
        address contractAddress;
        bool isVerified;
        bool isDefaultCollection;
        address requiredNFTAddress;
    }

    function getSkin(uint32 index) external view returns (SkinInfo memory);
    function validateSkinOwnership(uint32 skinIndex, uint16 tokenId, address owner) external view;
    function getVerifiedSkins() external view returns (SkinInfo[] memory);
    function defaultSkinRegistryId() external view returns (uint32);
}

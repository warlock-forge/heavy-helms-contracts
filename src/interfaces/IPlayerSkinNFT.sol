// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPlayerSkinNFT {
    struct SkinAttributes {
        uint8 weapon;
        uint8 armor;
        uint8 stance;
    }

    error TokenDoesNotExist();

    // Core minting function
    function mintSkin(
        address to,
        uint8 weapon,
        uint8 armor,
        uint8 stance
    ) external payable returns (uint16 tokenId);

    // Required view functions
    function MAX_SUPPLY() external view returns (uint16);
    function CURRENT_TOKEN_ID() external view returns (uint16);
    function getSkinAttributes(uint256 tokenId) external view returns (SkinAttributes memory);
    function ownerOf(uint256 tokenId) external view returns (address owner);

    event SkinMinted(
        address indexed to,
        uint16 indexed tokenId,
        uint8 weapon,
        uint8 armor,
        uint8 stance
    );
}

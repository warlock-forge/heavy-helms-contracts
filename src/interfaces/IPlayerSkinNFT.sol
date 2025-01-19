// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IGameDefinitions.sol";

interface IPlayerSkinNFT {
    struct SkinAttributes {
        IGameDefinitions.WeaponType weapon;
        IGameDefinitions.ArmorType armor;
        IGameDefinitions.FightingStance stance;
    }

    error TokenDoesNotExist();

    // Core minting function
    function mintSkin(
        address to,
        IGameDefinitions.WeaponType weapon,
        IGameDefinitions.ArmorType armor,
        IGameDefinitions.FightingStance stance
    ) external payable returns (uint16 tokenId);

    // Required view functions
    function MAX_SUPPLY() external view returns (uint16);
    function CURRENT_TOKEN_ID() external view returns (uint16);
    function getSkinAttributes(uint256 tokenId) external view returns (SkinAttributes memory);
    function ownerOf(uint256 tokenId) external view returns (address owner);

    event SkinMinted(
        address indexed to,
        uint16 indexed tokenId,
        IGameDefinitions.WeaponType weapon,
        IGameDefinitions.ArmorType armor,
        IGameDefinitions.FightingStance stance
    );
}

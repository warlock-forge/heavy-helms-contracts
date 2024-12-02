// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPlayerSkinNFT {
    // Enums for skin attributes
    enum WeaponType {
        SwordAndShield,
        MaceAndShield,
        Greatsword,
        Battleaxe,
        Quarterstaff,
        Spear,
        RapierAndShield
    }
    enum ArmorType {
        Plate,
        Chain,
        Leather,
        Cloth
    }
    enum FightingStance {
        Defensive,
        Balanced,
        Offensive
    }

    struct SkinAttributes {
        WeaponType weapon;
        ArmorType armor;
        FightingStance stance;
    }

    error TokenDoesNotExist();

    // Core minting function
    function mintSkin(address to, WeaponType weapon, ArmorType armor, FightingStance stance)
        external
        payable
        returns (uint16 tokenId);

    // Required view functions
    function MAX_SUPPLY() external view returns (uint16);
    function CURRENT_TOKEN_ID() external view returns (uint16);
    function getSkinAttributes(uint256 tokenId) external view returns (SkinAttributes memory);
    function ownerOf(uint256 tokenId) external view returns (address owner);

    event SkinMinted(
        address indexed to, uint16 indexed tokenId, WeaponType weapon, ArmorType armor, FightingStance stance
    );
}

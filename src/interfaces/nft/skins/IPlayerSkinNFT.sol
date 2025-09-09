// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

//==============================================================//
//                         HEAVY HELMS                          //
//                  PLAYER SKIN NFT INTERFACE                   //
//==============================================================//
/// @title Player Skin NFT Interface for Heavy Helms
/// @notice Base interface for all player skin NFT contracts
/// @dev Defines core functionality for skin NFTs with weapon/armor attributes
interface IPlayerSkinNFT {
    //==============================================================//
    //                          STRUCTS                             //
    //==============================================================//
    /// @notice Attributes associated with a skin NFT
    /// @param weapon The weapon type for this skin
    /// @param armor The armor type for this skin
    struct SkinAttributes {
        uint8 weapon;
        uint8 armor;
    }

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a new skin is minted
    /// @param tokenId The ID of the newly minted token
    /// @param weapon The weapon type of the skin
    /// @param armor The armor type of the skin
    event SkinMinted(uint16 indexed tokenId, uint8 indexed weapon, uint8 indexed armor);

    //==============================================================//
    //                       VIEW FUNCTIONS                         //
    //==============================================================//
    /// @notice Gets the maximum supply of skins for this collection
    /// @return The maximum number of tokens that can be minted
    function MAX_SUPPLY() external view returns (uint16);

    /// @notice Gets the current token ID counter
    /// @return The current highest token ID minted
    function CURRENT_TOKEN_ID() external view returns (uint16);

    /// @notice Gets the skin attributes for a specific token
    /// @param tokenId The token ID to query
    /// @return The SkinAttributes struct containing weapon and armor types
    function getSkinAttributes(uint256 tokenId) external view returns (SkinAttributes memory);

    /// @notice Gets the owner of a specific token
    /// @param tokenId The token ID to query
    /// @return owner The address that owns the token
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

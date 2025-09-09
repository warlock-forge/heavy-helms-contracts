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
import {GameOwnedNFT} from "../base/GameOwnedNFT.sol";

//==============================================================//
//                         HEAVY HELMS                          //
//                  DEFAULT PLAYER SKIN NFT                     //
//==============================================================//
/// @title Default Player Skin NFT for Heavy Helms
/// @notice NFT collection for default player skins in the Heavy Helms game
/// @dev Extends GameOwnedNFT with a max supply of 2000 tokens
contract DefaultPlayerSkinNFT is GameOwnedNFT {
    //==============================================================//
    //                        CONSTRUCTOR                           //
    //==============================================================//
    /// @notice Initializes the default player skin collection
    /// @dev Sets name to "Heavy Helms Default Player Skins", symbol to "HHSKIN", and max supply to 2000
    constructor() GameOwnedNFT("Heavy Helms Default Player Skins", "HHSKIN", 2000) {}

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Mints a new default player skin with specified attributes
    /// @param weapon The weapon type for this skin
    /// @param armor The armor type for this skin
    /// @param ipfsCid The IPFS content identifier for the skin's metadata
    /// @param desiredTokenId The desired token ID (must be available)
    /// @return tokenId The token ID of the newly minted skin
    /// @dev Only callable by owner, emits SkinMinted event
    function mintDefaultPlayerSkin(uint8 weapon, uint8 armor, string memory ipfsCid, uint16 desiredTokenId)
        external
        onlyOwner
        returns (uint16)
    {
        uint16 tokenId = _mintGameSkin(weapon, armor, ipfsCid, desiredTokenId);
        emit SkinMinted(tokenId, weapon, armor);
        return tokenId;
    }
}

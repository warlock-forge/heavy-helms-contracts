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
import {IPlayerSkinNFT} from "./IPlayerSkinNFT.sol";

//==============================================================//
//                         HEAVY HELMS                          //
//                DEFAULT PLAYER SKIN NFT INTERFACE             //
//==============================================================//
/// @title Default Player Skin NFT Interface for Heavy Helms
/// @notice Extends IPlayerSkinNFT with default player-specific minting
/// @dev Used for minting skins that can be used by default players
interface IDefaultPlayerSkinNFT is IPlayerSkinNFT {
    //==============================================================//
    //                  STATE-CHANGING FUNCTIONS                    //
    //==============================================================//
    /// @notice Mints a new default player skin with specified attributes
    /// @param weapon The weapon type for this skin
    /// @param armor The armor type for this skin
    /// @param stance The stance for this skin
    /// @param ipfsCid The IPFS content identifier for the skin's metadata
    /// @param desiredTokenId The desired token ID (must be available)
    /// @return The token ID of the newly minted skin
    /// @dev Only callable by authorized minters
    function mintDefaultPlayerSkin(
        uint8 weapon,
        uint8 armor,
        uint8 stance,
        string memory ipfsCid,
        uint16 desiredTokenId
    ) external returns (uint16);
}

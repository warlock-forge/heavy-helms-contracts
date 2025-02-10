// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IPlayerSkinNFT.sol";
import "./IDefaultPlayer.sol";

interface IDefaultPlayerSkinNFT is IPlayerSkinNFT {
    function mintDefaultPlayerSkin(
        uint8 weapon,
        uint8 armor,
        uint8 stance,
        IDefaultPlayer.DefaultPlayerStats memory stats,
        string memory ipfsCID,
        uint16 desiredTokenId
    ) external returns (uint16);

    function getDefaultPlayerStats(uint32 tokenId) external view returns (IDefaultPlayer.DefaultPlayerStats memory);

    event DefaultPlayerSkinMinted(uint16 indexed tokenId, IDefaultPlayer.DefaultPlayerStats stats);
}

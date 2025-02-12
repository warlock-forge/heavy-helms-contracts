// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IPlayerSkinNFT.sol";

interface IDefaultPlayerSkinNFT is IPlayerSkinNFT {
    function mintDefaultPlayerSkin(
        uint8 weapon,
        uint8 armor,
        uint8 stance,
        string memory ipfsCID,
        uint16 desiredTokenId
    ) external returns (uint16);
}

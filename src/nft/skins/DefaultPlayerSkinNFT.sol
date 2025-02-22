// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./GameOwnedNFT.sol";

contract DefaultPlayerSkinNFT is GameOwnedNFT {
    event DefaultPlayerSkinMinted(uint16 indexed tokenId);

    constructor() GameOwnedNFT("Heavy Helms Default Player Skins", "HHSKIN", 2000) {}

    function mintDefaultPlayerSkin(
        uint8 weapon,
        uint8 armor,
        uint8 stance,
        string memory ipfsCID,
        uint16 desiredTokenId
    ) external onlyOwner returns (uint16) {
        uint16 tokenId = _mintGameSkin(weapon, armor, stance, ipfsCID, desiredTokenId);
        emit DefaultPlayerSkinMinted(tokenId);
        return tokenId;
    }
}

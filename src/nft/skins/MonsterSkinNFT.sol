// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../base/GameOwnedNFT.sol";

contract MonsterSkinNFT is GameOwnedNFT {
    event MonsterSkinMinted(uint16 indexed tokenId, uint8 indexed weapon, uint8 indexed armor);

    constructor() GameOwnedNFT("Heavy Helms Monster Skins", "HHMON", 8000) {}

    function mintMonsterSkin(uint8 weapon, uint8 armor, string memory ipfsCID, uint16 desiredTokenId)
        external
        onlyOwner
        returns (uint16)
    {
        uint16 tokenId = _mintGameSkin(weapon, armor, ipfsCID, desiredTokenId);
        emit MonsterSkinMinted(tokenId, weapon, armor);
        return tokenId;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IGameDefinitions.sol";
import "./IPlayer.sol";
import "./IPlayerSkinNFT.sol";

interface IDefaultPlayerSkinNFT is IPlayerSkinNFT {
    function mintDefaultPlayerSkin(
        IGameDefinitions.WeaponType weapon,
        IGameDefinitions.ArmorType armor,
        IGameDefinitions.FightingStance stance,
        IPlayer.PlayerStats memory stats,
        string memory ipfsCID,
        uint16 desiredTokenId
    ) external returns (uint16);

    function getDefaultPlayerStats(uint32 tokenId) external view returns (IPlayer.PlayerStats memory);

    event DefaultPlayerSkinMinted(uint16 indexed tokenId, IPlayer.PlayerStats stats);
}

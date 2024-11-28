// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IPlayer.sol";
import "./IPlayerSkinNFT.sol";

interface IDefaultPlayerSkinNFT is IPlayerSkinNFT {
    function mintDefaultPlayerSkin(
        WeaponType weapon,
        ArmorType armor,
        FightingStance stance,
        IPlayer.PlayerStats calldata stats,
        bytes32 ipfsCID
    ) external returns (uint16 tokenId);

    function getDefaultPlayerStats(uint256 tokenId) external view returns (IPlayer.PlayerStats memory);

    event DefaultPlayerSkinMinted(uint16 indexed tokenId, IPlayer.PlayerStats stats);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../interfaces/IPlayer.sol";
import "../interfaces/IPlayerSkinNFT.sol";

library DefaultPlayerLibrary {
    function getBalancedWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            bytes32 ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.SwordAndShield,
            IPlayerSkinNFT.ArmorType.Chain,
            IPlayerSkinNFT.FightingStance.Balanced,
            IPlayer.PlayerStats({
                strength: 12,
                constitution: 12,
                size: 12,
                agility: 12,
                stamina: 12,
                luck: 12,
                skinIndex: skinIndex,
                skinTokenId: tokenId
            }),
            bytes32("Qm...") // Placeholder CID
        );
    }

    function getGreatswordUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            bytes32 ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.Greatsword,
            IPlayerSkinNFT.ArmorType.Leather,
            IPlayerSkinNFT.FightingStance.Offensive,
            IPlayer.PlayerStats({
                strength: 18,
                constitution: 10,
                size: 14,
                agility: 10,
                stamina: 10,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId
            }),
            bytes32("Qm...") // Placeholder CID
        );
    }

    function getBattleaxeUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            bytes32 ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.Battleaxe,
            IPlayerSkinNFT.ArmorType.Chain,
            IPlayerSkinNFT.FightingStance.Offensive,
            IPlayer.PlayerStats({
                strength: 16,
                constitution: 12,
                size: 14,
                agility: 10,
                stamina: 10,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId
            }),
            bytes32("Qm...") // Placeholder CID
        );
    }

    function getSpearUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            bytes32 ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.Spear,
            IPlayerSkinNFT.ArmorType.Leather,
            IPlayerSkinNFT.FightingStance.Balanced,
            IPlayer.PlayerStats({
                strength: 14,
                constitution: 12,
                size: 12,
                agility: 12,
                stamina: 12,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId
            }),
            bytes32("Qm...") // Placeholder CID
        );
    }

    function getQuarterstaffUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            bytes32 ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.Quarterstaff,
            IPlayerSkinNFT.ArmorType.Chain,
            IPlayerSkinNFT.FightingStance.Defensive,
            IPlayer.PlayerStats({
                strength: 10,
                constitution: 14,
                size: 12,
                agility: 12,
                stamina: 14,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId
            }),
            bytes32("Qm...") // Placeholder CID
        );
    }

    function getRapierAndShieldUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            bytes32 ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.RapierAndShield,
            IPlayerSkinNFT.ArmorType.Leather,
            IPlayerSkinNFT.FightingStance.Defensive,
            IPlayer.PlayerStats({
                strength: 10,
                constitution: 12,
                size: 12,
                agility: 14,
                stamina: 12,
                luck: 12,
                skinIndex: skinIndex,
                skinTokenId: tokenId
            }),
            bytes32("Qm...") // Placeholder CID
        );
    }

    function getOffensiveTestWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            bytes32 ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.Greatsword,
            IPlayerSkinNFT.ArmorType.Leather,
            IPlayerSkinNFT.FightingStance.Offensive,
            IPlayer.PlayerStats({
                strength: 18, // High strength for offensive
                constitution: 8,
                size: 16, // High size for offensive
                agility: 10,
                stamina: 10,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId
            }),
            bytes32("Qm...") // Placeholder CID
        );
    }

    function getDefensiveTestWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            bytes32 ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.SwordAndShield,
            IPlayerSkinNFT.ArmorType.Chain,
            IPlayerSkinNFT.FightingStance.Defensive,
            IPlayer.PlayerStats({
                strength: 10,
                constitution: 16, // High constitution for defensive
                size: 10,
                agility: 10,
                stamina: 16, // High stamina for defensive
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId
            }),
            bytes32("Qm...") // Placeholder CID
        );
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../interfaces/IPlayer.sol";
import "../interfaces/IGameDefinitions.sol";

library DefaultPlayerLibrary {
    function getDefaultWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IGameDefinitions.WeaponType weapon,
            IGameDefinitions.ArmorType armor,
            IGameDefinitions.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        weapon = IGameDefinitions.WeaponType.Quarterstaff;
        armor = IGameDefinitions.ArmorType.Cloth;
        stance = IGameDefinitions.FightingStance.Balanced;
        stats = IPlayer.PlayerStats({
            strength: 12,
            constitution: 12,
            size: 12,
            agility: 12,
            stamina: 12,
            luck: 12,
            skinIndex: skinIndex,
            skinTokenId: tokenId,
            firstNameIndex: 0,
            surnameIndex: 155,
            wins: 0,
            losses: 0,
            kills: 0
        });
        ipfsCID = "QmRQEMsXzytfLuhRyntfD23Gu41GNxdn4PyrBL1XoM3sPb";
    }

    function getBalancedWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IGameDefinitions.WeaponType weapon,
            IGameDefinitions.ArmorType armor,
            IGameDefinitions.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        weapon = IGameDefinitions.WeaponType.SwordAndShield;
        armor = IGameDefinitions.ArmorType.Chain;
        stance = IGameDefinitions.FightingStance.Balanced;
        stats = IPlayer.PlayerStats({
            strength: 12,
            constitution: 12,
            size: 12,
            agility: 12,
            stamina: 12,
            luck: 12,
            skinIndex: skinIndex,
            skinTokenId: tokenId,
            firstNameIndex: 1015,
            surnameIndex: 97,
            wins: 0,
            losses: 0,
            kills: 0
        });
        ipfsCID = "QmSVzjJMzZ8ARnYVHHsse1N2VJU3tUvacV1GUiJ2vqgFDZ";
    }

    function getGreatswordUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IGameDefinitions.WeaponType weapon,
            IGameDefinitions.ArmorType armor,
            IGameDefinitions.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IGameDefinitions.WeaponType.Greatsword,
            IGameDefinitions.ArmorType.Leather,
            IGameDefinitions.FightingStance.Offensive,
            IPlayer.PlayerStats({
                strength: 18,
                constitution: 10,
                size: 14,
                agility: 10,
                stamina: 10,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1062,
                surnameIndex: 131,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmUCL71TD41AFZBd1BkVMLVbjDTAF5A6HiNyGcmiXa8upT"
        );
    }

    function getBattleaxeUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IGameDefinitions.WeaponType weapon,
            IGameDefinitions.ArmorType armor,
            IGameDefinitions.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IGameDefinitions.WeaponType.Battleaxe,
            IGameDefinitions.ArmorType.Chain,
            IGameDefinitions.FightingStance.Offensive,
            IPlayer.PlayerStats({
                strength: 16,
                constitution: 12,
                size: 14,
                agility: 10,
                stamina: 10,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1,
                surnameIndex: 1,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmSwordAndShieldUserCIDHere"
        );
    }

    function getSpearUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IGameDefinitions.WeaponType weapon,
            IGameDefinitions.ArmorType armor,
            IGameDefinitions.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IGameDefinitions.WeaponType.Spear,
            IGameDefinitions.ArmorType.Leather,
            IGameDefinitions.FightingStance.Balanced,
            IPlayer.PlayerStats({
                strength: 14,
                constitution: 12,
                size: 12,
                agility: 12,
                stamina: 12,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1,
                surnameIndex: 1,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmSwordAndShieldUserCIDHere"
        );
    }

    function getQuarterstaffUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IGameDefinitions.WeaponType weapon,
            IGameDefinitions.ArmorType armor,
            IGameDefinitions.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IGameDefinitions.WeaponType.Quarterstaff,
            IGameDefinitions.ArmorType.Chain,
            IGameDefinitions.FightingStance.Defensive,
            IPlayer.PlayerStats({
                strength: 10,
                constitution: 14,
                size: 12,
                agility: 12,
                stamina: 14,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1,
                surnameIndex: 1,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmSwordAndShieldUserCIDHere"
        );
    }

    function getRapierAndShieldUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IGameDefinitions.WeaponType weapon,
            IGameDefinitions.ArmorType armor,
            IGameDefinitions.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IGameDefinitions.WeaponType.RapierAndShield,
            IGameDefinitions.ArmorType.Leather,
            IGameDefinitions.FightingStance.Balanced,
            IPlayer.PlayerStats({
                strength: 10,
                constitution: 12,
                size: 8,
                agility: 16,
                stamina: 12,
                luck: 14,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 38,
                surnameIndex: 15,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmXJH9LwZ1nk4aood3R6i9JC1NMg1KyWvUYByWD25Ddtoe"
        );
    }

    function getOffensiveTestWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IGameDefinitions.WeaponType weapon,
            IGameDefinitions.ArmorType armor,
            IGameDefinitions.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IGameDefinitions.WeaponType.Greatsword,
            IGameDefinitions.ArmorType.Leather,
            IGameDefinitions.FightingStance.Offensive,
            IPlayer.PlayerStats({
                strength: 18,
                constitution: 8,
                size: 16,
                agility: 10,
                stamina: 10,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1,
                surnameIndex: 1,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmSwordAndShieldUserCIDHere"
        );
    }

    function getDefensiveTestWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IGameDefinitions.WeaponType weapon,
            IGameDefinitions.ArmorType armor,
            IGameDefinitions.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IGameDefinitions.WeaponType.SwordAndShield,
            IGameDefinitions.ArmorType.Chain,
            IGameDefinitions.FightingStance.Defensive,
            IPlayer.PlayerStats({
                strength: 10,
                constitution: 16,
                size: 10,
                agility: 10,
                stamina: 16,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1,
                surnameIndex: 1,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmSwordAndShieldUserCIDHere"
        );
    }

    function getSwordAndShieldUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IGameDefinitions.WeaponType weapon,
            IGameDefinitions.ArmorType armor,
            IGameDefinitions.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IGameDefinitions.WeaponType.SwordAndShield,
            IGameDefinitions.ArmorType.Chain,
            IGameDefinitions.FightingStance.Defensive,
            IPlayer.PlayerStats({
                strength: 12,
                constitution: 14,
                size: 12,
                agility: 12,
                stamina: 12,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1,
                surnameIndex: 1,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmSwordAndShieldUserCIDHere"
        );
    }
}

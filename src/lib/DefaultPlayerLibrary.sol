// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../interfaces/IDefaultPlayer.sol";

library DefaultPlayerLibrary {
    function getDefaultWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            uint8 weapon,
            uint8 armor,
            uint8 stance,
            IDefaultPlayer.DefaultPlayerStats memory stats,
            string memory ipfsCID
        )
    {
        weapon = 5; // WEAPON_QUARTERSTAFF
        armor = 0; // ARMOR_CLOTH
        stance = 1; // STANCE_BALANCED
        stats = IDefaultPlayer.DefaultPlayerStats({
            strength: 12,
            constitution: 12,
            size: 12,
            agility: 12,
            stamina: 12,
            luck: 12,
            skinIndex: skinIndex,
            skinTokenId: tokenId,
            firstNameIndex: 0,
            surnameIndex: 155
        });
        ipfsCID = "QmRQEMsXzytfLuhRyntfD23Gu41GNxdn4PyrBL1XoM3sPb";
    }

    function getBalancedWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            uint8 weapon,
            uint8 armor,
            uint8 stance,
            IDefaultPlayer.DefaultPlayerStats memory stats,
            string memory ipfsCID
        )
    {
        weapon = 0; // WEAPON_SWORD_AND_SHIELD
        armor = 2; // ARMOR_CHAIN
        stance = 1; // STANCE_BALANCED
        stats = IDefaultPlayer.DefaultPlayerStats({
            strength: 12,
            constitution: 12,
            size: 12,
            agility: 12,
            stamina: 12,
            luck: 12,
            skinIndex: skinIndex,
            skinTokenId: tokenId,
            firstNameIndex: 1015,
            surnameIndex: 97
        });
        ipfsCID = "QmSVzjJMzZ8ARnYVHHsse1N2VJU3tUvacV1GUiJ2vqgFDZ";
    }

    function getGreatswordUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            uint8 weapon,
            uint8 armor,
            uint8 stance,
            IDefaultPlayer.DefaultPlayerStats memory stats,
            string memory ipfsCID
        )
    {
        weapon = 3; // WEAPON_GREATSWORD
        armor = 1; // ARMOR_LEATHER
        stance = 2; // STANCE_OFFENSIVE
        stats = IDefaultPlayer.DefaultPlayerStats({
            strength: 18,
            constitution: 10,
            size: 14,
            agility: 10,
            stamina: 10,
            luck: 10,
            skinIndex: skinIndex,
            skinTokenId: tokenId,
            firstNameIndex: 1062,
            surnameIndex: 131
        });
        ipfsCID = "QmUCL71TD41AFZBd1BkVMLVbjDTAF5A6HiNyGcmiXa8upT";
    }

    function getBattleaxeUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            uint8 weapon,
            uint8 armor,
            uint8 stance,
            IDefaultPlayer.DefaultPlayerStats memory stats,
            string memory ipfsCID
        )
    {
        weapon = 4; // WEAPON_BATTLEAXE
        armor = 2; // ARMOR_CHAIN
        stance = 2; // STANCE_OFFENSIVE
        stats = IDefaultPlayer.DefaultPlayerStats({
            strength: 16,
            constitution: 12,
            size: 14,
            agility: 10,
            stamina: 10,
            luck: 10,
            skinIndex: skinIndex,
            skinTokenId: tokenId,
            firstNameIndex: 1,
            surnameIndex: 1
        });
        ipfsCID = "QmSwordAndShieldUserCIDHere";
    }

    function getSpearUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            uint8 weapon,
            uint8 armor,
            uint8 stance,
            IDefaultPlayer.DefaultPlayerStats memory stats,
            string memory ipfsCID
        )
    {
        weapon = 6; // WEAPON_SPEAR
        armor = 1; // ARMOR_LEATHER
        stance = 1; // STANCE_BALANCED
        stats = IDefaultPlayer.DefaultPlayerStats({
            strength: 14,
            constitution: 12,
            size: 12,
            agility: 12,
            stamina: 12,
            luck: 10,
            skinIndex: skinIndex,
            skinTokenId: tokenId,
            firstNameIndex: 1,
            surnameIndex: 1
        });
        ipfsCID = "QmSwordAndShieldUserCIDHere";
    }

    function getQuarterstaffUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            uint8 weapon,
            uint8 armor,
            uint8 stance,
            IDefaultPlayer.DefaultPlayerStats memory stats,
            string memory ipfsCID
        )
    {
        weapon = 5; // WEAPON_QUARTERSTAFF
        armor = 2; // ARMOR_CHAIN
        stance = 0; // STANCE_DEFENSIVE
        stats = IDefaultPlayer.DefaultPlayerStats({
            strength: 10,
            constitution: 14,
            size: 12,
            agility: 12,
            stamina: 14,
            luck: 10,
            skinIndex: skinIndex,
            skinTokenId: tokenId,
            firstNameIndex: 1,
            surnameIndex: 1
        });
        ipfsCID = "QmSwordAndShieldUserCIDHere";
    }

    function getRapierAndShieldUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            uint8 weapon,
            uint8 armor,
            uint8 stance,
            IDefaultPlayer.DefaultPlayerStats memory stats,
            string memory ipfsCID
        )
    {
        weapon = 2; // WEAPON_RAPIER_AND_SHIELD
        armor = 1; // ARMOR_LEATHER
        stance = 1; // STANCE_BALANCED
        stats = IDefaultPlayer.DefaultPlayerStats({
            strength: 10,
            constitution: 12,
            size: 8,
            agility: 16,
            stamina: 12,
            luck: 14,
            skinIndex: skinIndex,
            skinTokenId: tokenId,
            firstNameIndex: 38,
            surnameIndex: 15
        });
        ipfsCID = "QmXJH9LwZ1nk4aood3R6i9JC1NMg1KyWvUYByWD25Ddtoe";
    }

    function getOffensiveTestWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            uint8 weapon,
            uint8 armor,
            uint8 stance,
            IDefaultPlayer.DefaultPlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            3, // WEAPON_GREATSWORD
            1, // ARMOR_LEATHER
            2, // STANCE_OFFENSIVE
            IDefaultPlayer.DefaultPlayerStats({
                strength: 18,
                constitution: 8,
                size: 16,
                agility: 10,
                stamina: 10,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1,
                surnameIndex: 1
            }),
            "QmSwordAndShieldUserCIDHere"
        );
    }

    function getDefensiveTestWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            uint8 weapon,
            uint8 armor,
            uint8 stance,
            IDefaultPlayer.DefaultPlayerStats memory stats,
            string memory ipfsCID
        )
    {
        weapon = 0; // WEAPON_SWORD_AND_SHIELD
        armor = 2; // ARMOR_CHAIN
        stance = 0; // STANCE_DEFENSIVE
        stats = IDefaultPlayer.DefaultPlayerStats({
            strength: 10,
            constitution: 16,
            size: 10,
            agility: 10,
            stamina: 16,
            luck: 10,
            skinIndex: skinIndex,
            skinTokenId: tokenId,
            firstNameIndex: 1,
            surnameIndex: 1
        });
        ipfsCID = "QmSwordAndShieldUserCIDHere";
    }

    function getSwordAndShieldUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            uint8 weapon,
            uint8 armor,
            uint8 stance,
            IDefaultPlayer.DefaultPlayerStats memory stats,
            string memory ipfsCID
        )
    {
        weapon = 0; // WEAPON_SWORD_AND_SHIELD
        armor = 2; // ARMOR_CHAIN
        stance = 0; // STANCE_DEFENSIVE
        stats = IDefaultPlayer.DefaultPlayerStats({
            strength: 12,
            constitution: 14,
            size: 12,
            agility: 12,
            stamina: 12,
            luck: 10,
            skinIndex: skinIndex,
            skinTokenId: tokenId,
            firstNameIndex: 1,
            surnameIndex: 1
        });
        ipfsCID = "QmSwordAndShieldUserCIDHere";
    }
}

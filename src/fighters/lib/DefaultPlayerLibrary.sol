// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../interfaces/fighters/IPlayer.sol";
import "../../nft/skins/DefaultPlayerSkinNFT.sol";
import "../../fighters/Fighter.sol";
import "../../interfaces/fighters/IDefaultPlayer.sol";

library DefaultPlayerLibrary {
    enum CharacterType {
        DefaultWarrior, // ID 1
        BalancedWarrior, // ID 2
        GreatswordOffensive, // ID 3
        BattleaxeOffensive, // ID 4
        SpearBalanced, // ID 5
        MaceAndShieldDefensive, // ID 6
        RapierAndShieldDefensive // ID 7

    }

    function getDefaultWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, uint8 stance, IPlayer.PlayerStats memory stats, string memory ipfsCID)
    {
        weapon = 5; // WEAPON_QUARTERSTAFF
        armor = 0; // ARMOR_CLOTH
        stance = 1; // STANCE_BALANCED
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 12, size: 12, agility: 12, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            name: IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 155}),
            record: Fighter.Record({wins: 0, losses: 0, kills: 0})
        });
        ipfsCID = "bafkreid4j7qd4chkycansnx3zktu3lsysszkbf5674le4ergnltthyf7dm";
    }

    function getBalancedWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, uint8 stance, IPlayer.PlayerStats memory stats, string memory ipfsCID)
    {
        weapon = 0; // WEAPON_SWORD_AND_SHIELD
        armor = 2; // ARMOR_CHAIN
        stance = 1; // STANCE_BALANCED
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 12, size: 12, agility: 12, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            name: IPlayer.PlayerName({firstNameIndex: 1015, surnameIndex: 97}),
            record: Fighter.Record({wins: 0, losses: 0, kills: 0})
        });
        ipfsCID = "bafkreiciuv6jctzbyut75pezrfcqxut6h4gwoeqv5oejw6ccvvc5aejwp4";
    }

    function getGreatswordUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, uint8 stance, IPlayer.PlayerStats memory stats, string memory ipfsCID)
    {
        weapon = 3; // WEAPON_GREATSWORD
        armor = 1; // ARMOR_LEATHER
        stance = 2; // STANCE_OFFENSIVE
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 18, constitution: 10, size: 14, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            name: IPlayer.PlayerName({firstNameIndex: 1062, surnameIndex: 131}),
            record: Fighter.Record({wins: 0, losses: 0, kills: 0})
        });
        ipfsCID = "bafkreihyxl5sta2nh7f5zmeq4bvob3relwdwiyql5t5zupomiqy2vg4bpa";
    }

    function getBattleaxeUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, uint8 stance, IPlayer.PlayerStats memory stats, string memory ipfsCID)
    {
        weapon = 4; // WEAPON_BATTLEAXE
        armor = 1; // ARMOR_LEATHER
        stance = 1; // STANCE_BALANCED
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 12, size: 14, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            name: IPlayer.PlayerName({firstNameIndex: 1102, surnameIndex: 241}),
            record: Fighter.Record({wins: 0, losses: 0, kills: 0})
        });
        ipfsCID = "bafkreibgsck2mqp7cal5ivinzl65i72mqfwbaopuc3gr6dnq4s5f5rjke4";
    }

    function getSpearUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, uint8 stance, IPlayer.PlayerStats memory stats, string memory ipfsCID)
    {
        weapon = 6; // WEAPON_SPEAR
        armor = 1; // ARMOR_LEATHER
        stance = 2; // STANCE_OFFENSIVE
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 8, size: 12, agility: 16, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            name: IPlayer.PlayerName({firstNameIndex: 1146, surnameIndex: 25}),
            record: Fighter.Record({wins: 0, losses: 0, kills: 0})
        });
        ipfsCID = "bafkreidkhaqtp5x67v5xvp4rdpfvnue7osxxccqsg26mclnd3mca342l7q";
    }

    function getRapierAndShieldUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, uint8 stance, IPlayer.PlayerStats memory stats, string memory ipfsCID)
    {
        weapon = 2; // WEAPON_RAPIER_AND_SHIELD
        armor = 1; // ARMOR_LEATHER
        stance = 1; // STANCE_BALANCED
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 10, constitution: 12, size: 8, agility: 16, stamina: 12, luck: 14}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            name: IPlayer.PlayerName({firstNameIndex: 38, surnameIndex: 15}),
            record: Fighter.Record({wins: 0, losses: 0, kills: 0})
        });
        ipfsCID = "bafkreib55kqspxbhjicrkrb3ajakxs2rugzwovwxoi2nfdpbzyrzepran4";
    }

    function getMaceAndShieldUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, uint8 stance, IPlayer.PlayerStats memory stats, string memory ipfsCID)
    {
        weapon = 1; // WEAPON_MACE_AND_SHIELD
        armor = 3; // ARMOR_PLATE
        stance = 0; // STANCE_DEFENSIVE
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 19, size: 14, agility: 6, stamina: 15, luck: 6}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            name: IPlayer.PlayerName({firstNameIndex: 1079, surnameIndex: 165}),
            record: Fighter.Record({wins: 0, losses: 0, kills: 0})
        });
        ipfsCID = "bafkreie7vtabnq4tku4d4u7q3ucnvrvfjyjhthxrd7n4pq77lvpy527m3m";
    }

    function createDefaultCharacter(
        DefaultPlayerSkinNFT defaultSkin,
        IDefaultPlayer defaultPlayer,
        uint32 skinIndex,
        uint16 tokenId,
        CharacterType characterType
    ) internal returns (uint16) {
        // Get character data based on type
        (uint8 weapon, uint8 armor, uint8 stance, IPlayer.PlayerStats memory stats, string memory ipfsCID) =
            _getCharacterData(characterType, skinIndex, tokenId);

        // Create the default player first
        defaultPlayer.setDefaultPlayer(tokenId, stats);
        // Then mint the skin
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, ipfsCID, tokenId);

        return tokenId;
    }

    function _getCharacterData(CharacterType charType, uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, uint8 stance, IPlayer.PlayerStats memory stats, string memory ipfsCID)
    {
        if (charType == CharacterType.DefaultWarrior) {
            return getDefaultWarrior(skinIndex, tokenId);
        } else if (charType == CharacterType.GreatswordOffensive) {
            return getGreatswordUser(skinIndex, tokenId);
        } else if (charType == CharacterType.BattleaxeOffensive) {
            return getBattleaxeUser(skinIndex, tokenId);
        } else if (charType == CharacterType.SpearBalanced) {
            return getSpearUser(skinIndex, tokenId);
        } else if (charType == CharacterType.MaceAndShieldDefensive) {
            return getMaceAndShieldUser(skinIndex, tokenId);
        } else if (charType == CharacterType.RapierAndShieldDefensive) {
            return getRapierAndShieldUser(skinIndex, tokenId);
        } else if (charType == CharacterType.BalancedWarrior) {
            return getBalancedWarrior(skinIndex, tokenId);
        }
    }

    function createAllDefaultCharacters(
        DefaultPlayerSkinNFT defaultSkin,
        IDefaultPlayer defaultPlayer,
        uint32 defaultSkinIndex
    ) internal {
        for (uint16 i = 1; i <= 7; i++) {
            createDefaultCharacter(
                defaultSkin,
                defaultPlayer,
                defaultSkinIndex,
                i,
                CharacterType(i - 1) // TokenId 1 = DefaultWarrior (0), TokenId 2 = BalancedWarrior (1), etc.
            );
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../fighters/Monster.sol";
import "../../nft/skins/MonsterSkinNFT.sol";
import "../../interfaces/fighters/IMonster.sol";
import "../../game/engine/GameEngine.sol";

library MonsterLibrary {
    enum MonsterType {
        Goblin,
        Orc,
        Troll,
        Giant
    }

    function createMonster(
        MonsterSkinNFT monsterSkin,
        Monster monster,
        uint32 skinIndex,
        uint16 tokenId,
        MonsterType monsterType
    ) internal returns (uint32) {
        // Get monster data based on type
        (uint8 weapon, uint8 armor, uint8 stance, IMonster.MonsterStats memory stats, string memory ipfsCID) =
            _getMonsterData(monsterType, skinIndex, tokenId);

        // Create the monster first
        uint32 monsterId = monster.createMonster(stats);
        // Then mint the skin
        monsterSkin.mintMonsterSkin(weapon, armor, stance, ipfsCID, tokenId);

        return monsterId;
    }

    function createAllMonsters(MonsterSkinNFT monsterSkin, Monster monster, uint32 skinIndex) internal {
        uint16 tokenId = 1;
        createMonster(monsterSkin, monster, skinIndex, tokenId++, MonsterType.Goblin);
        createMonster(monsterSkin, monster, skinIndex, tokenId++, MonsterType.Orc);
        createMonster(monsterSkin, monster, skinIndex, tokenId++, MonsterType.Troll);
        createMonster(monsterSkin, monster, skinIndex, tokenId++, MonsterType.Giant);
    }

    function _getMonsterData(MonsterType monsterType, uint32 skinIndex, uint16 tokenId)
        private
        pure
        returns (uint8, uint8, uint8, IMonster.MonsterStats memory, string memory)
    {
        if (monsterType == MonsterType.Goblin) {
            return _getGoblinData(skinIndex, tokenId);
        } else if (monsterType == MonsterType.Orc) {
            return _getOrcData(skinIndex, tokenId);
        } else if (monsterType == MonsterType.Troll) {
            return _getTrollData(skinIndex, tokenId);
        } else {
            return _getGiantData(skinIndex, tokenId);
        }
    }

    // Individual monster type data functions...
    function _getGoblinData(uint32 skinIndex, uint16 tokenId)
        private
        pure
        returns (uint8, uint8, uint8, IMonster.MonsterStats memory, string memory)
    {
        IMonster.MonsterStats memory stats = IMonster.MonsterStats({
            attributes: Fighter.Attributes({strength: 8, constitution: 8, size: 6, agility: 14, stamina: 10, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            tier: 1,
            wins: 0,
            losses: 0,
            kills: 0
        });

        return (
            0, // WEAPON_SWORD_AND_SHIELD
            0, // ARMOR_CLOTH
            0, // STANCE_DEFENSIVE
            stats,
            "Qm..." // Add actual IPFS CID
        );
    }

    function _getOrcData(uint32 skinIndex, uint16 tokenId)
        private
        pure
        returns (uint8, uint8, uint8, IMonster.MonsterStats memory, string memory)
    {
        IMonster.MonsterStats memory stats = IMonster.MonsterStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 14, size: 14, agility: 8, stamina: 12, luck: 8}),
            tier: 2,
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            wins: 0,
            losses: 0,
            kills: 0
        });

        return (
            4, // WEAPON_BATTLEAXE
            2, // ARMOR_CHAIN
            2, // STANCE_OFFENSIVE
            stats,
            "Qm..." // Add actual IPFS CID
        );
    }

    function _getTrollData(uint32 skinIndex, uint16 tokenId)
        private
        pure
        returns (uint8, uint8, uint8, IMonster.MonsterStats memory, string memory)
    {
        IMonster.MonsterStats memory stats = IMonster.MonsterStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 16, size: 16, agility: 6, stamina: 14, luck: 6}),
            tier: 3,
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            wins: 0,
            losses: 0,
            kills: 0
        });

        return (
            3, // WEAPON_GREATSWORD
            3, // ARMOR_PLATE
            1, // STANCE_BALANCED
            stats,
            "Qm..." // Add actual IPFS CID
        );
    }

    function _getGiantData(uint32 skinIndex, uint16 tokenId)
        private
        pure
        returns (uint8, uint8, uint8, IMonster.MonsterStats memory, string memory)
    {
        IMonster.MonsterStats memory stats = IMonster.MonsterStats({
            attributes: Fighter.Attributes({strength: 18, constitution: 18, size: 18, agility: 4, stamina: 16, luck: 4}),
            tier: 4,
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            wins: 0,
            losses: 0,
            kills: 0
        });

        return (
            4, // WEAPON_BATTLEAXE
            3, // ARMOR_PLATE
            2, // STANCE_OFFENSIVE
            stats,
            "Qm..." // Add actual IPFS CID
        );
    }

    // Add similar functions for other monster types...
}

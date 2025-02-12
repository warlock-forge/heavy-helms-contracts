// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Monster.sol";
import "../MonsterSkinNFT.sol";
import "../interfaces/IMonster.sol";

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
        returns (uint8 weapon, uint8 armor, uint8 stance, IMonster.MonsterStats memory stats, string memory ipfsCID)
    {
        if (monsterType == MonsterType.Goblin) {
            return _getGoblinData(skinIndex, tokenId);
        }
        // } else if (monsterType == MonsterType.Orc) {
        //     return _getOrcData(skinIndex, tokenId);
        // } else if (monsterType == MonsterType.Troll) {
        //     return _getTrollData(skinIndex, tokenId);
        // } else {
        //     return _getGiantData(skinIndex, tokenId);
        // }
    }

    // Individual monster type data functions...
    function _getGoblinData(uint32 skinIndex, uint16 tokenId)
        private
        pure
        returns (uint8, uint8, uint8, IMonster.MonsterStats memory, string memory)
    {
        IMonster.MonsterStats memory stats = IMonster.MonsterStats({
            strength: 8,
            constitution: 8,
            size: 6,
            agility: 14,
            stamina: 10,
            luck: 12,
            tier: 1,
            skinIndex: skinIndex,
            skinTokenId: tokenId,
            wins: 0,
            losses: 0,
            kills: 0
        });

        return (
            1, // weapon (dagger)
            1, // armor (light)
            1, // stance (agile)
            stats,
            "Qm..." // Add actual IPFS CID
        );
    }

    // Add similar functions for other monster types...
}

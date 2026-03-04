// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Monster} from "../../fighters/Monster.sol";
import {MonsterSkinNFT} from "../../nft/skins/MonsterSkinNFT.sol";
import {IMonster} from "../../interfaces/fighters/IMonster.sol";
import {Fighter} from "../../fighters/Fighter.sol";

library MonsterLibrary {
    //==============================================================//
    //                           STRUCTS                            //
    //==============================================================//

    /// @dev Compact monster definition - base stats + level-up pattern
    struct MonsterDef {
        uint8 str;
        uint8 con;
        uint8 size;
        uint8 agi;
        uint8 sta;
        uint8 luck;
        uint8 stance;
        uint8 armorSpec;
        uint8 weaponSpec;
        uint8 armorFromLevel;
        uint8 weaponFromLevel;
        // Which stat index to bump at levels 2-10
        // Values: 0=STR, 1=CON, 2=SIZE, 3=AGI, 4=STA, 5=LUCK
        uint8[9] levelUps;
    }

    //==============================================================//
    //                     MONSTER FUNCTIONS                        //
    //==============================================================//

    function createGoblinMonster001(Monster monster, uint16 skinTokenId, uint16 nameIndex) internal returns (uint32) {
        IMonster.MonsterStats[10] memory allLevelStats = getGoblinMonster001Stats(skinTokenId, nameIndex);
        return monster.createMonster(allLevelStats);
    }

    function createUndeadMonster001(Monster monster, uint16 skinTokenId, uint16 nameIndex) internal returns (uint32) {
        IMonster.MonsterStats[10] memory allLevelStats = getUndeadMonster001Stats(skinTokenId, nameIndex);
        return monster.createMonster(allLevelStats);
    }

    function createDemonMonster001(Monster monster, uint16 skinTokenId, uint16 nameIndex) internal returns (uint32) {
        IMonster.MonsterStats[10] memory allLevelStats = getDemonMonster001Stats(skinTokenId, nameIndex);
        return monster.createMonster(allLevelStats);
    }

    //==============================================================//
    //                     PRIVATE FUNCTIONS                        //
    //==============================================================//

    function getGoblinMonster001Stats(uint16 skinTokenId, uint16 nameIndex)
        private
        pure
        returns (IMonster.MonsterStats[10] memory)
    {
        MonsterDef memory def = MonsterDef({
            str: 12,
            con: 9,
            size: 6,
            agi: 11,
            sta: 11,
            luck: 13,
            stance: 1,
            armorSpec: 1,
            weaponSpec: 18,
            armorFromLevel: 5,
            weaponFromLevel: 10,
            levelUps: [uint8(0), 0, 0, 0, 0, 1, 1, 5, 5]
        });
        return _buildStats(def, skinTokenId, nameIndex);
    }

    function getUndeadMonster001Stats(uint16 skinTokenId, uint16 nameIndex)
        private
        pure
        returns (IMonster.MonsterStats[10] memory)
    {
        MonsterDef memory def = MonsterDef({
            str: 10,
            con: 10,
            size: 12,
            agi: 16,
            sta: 10,
            luck: 14,
            stance: 2,
            armorSpec: 0,
            weaponSpec: 9,
            armorFromLevel: 5,
            weaponFromLevel: 10,
            levelUps: [uint8(3), 5, 5, 5, 4, 4, 3, 3, 5]
        });
        return _buildStats(def, skinTokenId, nameIndex);
    }

    function getDemonMonster001Stats(uint16 skinTokenId, uint16 nameIndex)
        private
        pure
        returns (IMonster.MonsterStats[10] memory)
    {
        MonsterDef memory def = MonsterDef({
            str: 18,
            con: 18,
            size: 14,
            agi: 10,
            sta: 10,
            luck: 12,
            stance: 1,
            armorSpec: 3,
            weaponSpec: 0,
            armorFromLevel: 1,
            weaponFromLevel: 5,
            levelUps: [uint8(2), 2, 2, 2, 0, 0, 0, 1, 1]
        });
        return _buildStats(def, skinTokenId, nameIndex);
    }

    function _buildStats(MonsterDef memory def, uint16 skinTokenId, uint16 nameIndex)
        private
        pure
        returns (IMonster.MonsterStats[10] memory stats)
    {
        uint8[6] memory current = [def.str, def.con, def.size, def.agi, def.sta, def.luck];
        IMonster.MonsterName memory name = IMonster.MonsterName({nameIndex: nameIndex});

        for (uint8 level = 1; level <= 10; level++) {
            if (level > 1) {
                current[def.levelUps[level - 2]]++;
            }

            stats[level - 1] = IMonster.MonsterStats({
                attributes: Fighter.Attributes({
                    strength: current[0],
                    constitution: current[1],
                    size: current[2],
                    agility: current[3],
                    stamina: current[4],
                    luck: current[5]
                }),
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
                stance: def.stance,
                name: name,
                level: level,
                currentXP: 0,
                armorSpecialization: level >= def.armorFromLevel ? def.armorSpec : 255,
                weaponSpecialization: level >= def.weaponFromLevel ? def.weaponSpec : 255
            });
        }
    }
}

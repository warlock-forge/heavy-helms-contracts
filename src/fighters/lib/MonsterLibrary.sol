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

    // Individual monster type data functions...
    function getGoblinMonster001Stats(uint16 skinTokenId, uint16 nameIndex)
        private
        pure
        returns (IMonster.MonsterStats[10] memory)
    {
        IMonster.MonsterStats[10] memory stats;
        IMonster.MonsterName memory name = IMonster.MonsterName({nameIndex: nameIndex});
        uint8 stance = 1;

        // Level 1 - 62 attribute points (Easy tier)
        stats[0] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 12, constitution: 9, size: 6, agility: 11, stamina: 11, luck: 13
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 1,
            currentXP: 0,
            armorSpecialization: 255,
            weaponSpecialization: 255
        });
        stats[1] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 13, constitution: 9, size: 6, agility: 11, stamina: 11, luck: 13
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 2,
            currentXP: 0,
            armorSpecialization: 255,
            weaponSpecialization: 255
        });
        stats[2] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 14, constitution: 9, size: 6, agility: 11, stamina: 11, luck: 13
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 3,
            currentXP: 0,
            armorSpecialization: 255,
            weaponSpecialization: 255
        });
        stats[3] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 15, constitution: 9, size: 6, agility: 11, stamina: 11, luck: 13
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 4,
            currentXP: 0,
            armorSpecialization: 255,
            weaponSpecialization: 255
        });
        stats[4] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 16, constitution: 9, size: 6, agility: 11, stamina: 11, luck: 13
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 5,
            currentXP: 0,
            armorSpecialization: 1,
            weaponSpecialization: 255
        });
        stats[5] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 17, constitution: 9, size: 6, agility: 11, stamina: 11, luck: 13
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 6,
            currentXP: 0,
            armorSpecialization: 1,
            weaponSpecialization: 255
        });
        stats[6] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 17, constitution: 10, size: 6, agility: 11, stamina: 11, luck: 13
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 7,
            currentXP: 0,
            armorSpecialization: 1,
            weaponSpecialization: 255
        });
        stats[7] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 17, constitution: 11, size: 6, agility: 11, stamina: 11, luck: 13
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 8,
            currentXP: 0,
            armorSpecialization: 1,
            weaponSpecialization: 255
        });
        stats[8] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 17, constitution: 11, size: 6, agility: 11, stamina: 11, luck: 14
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 9,
            currentXP: 0,
            armorSpecialization: 1,
            weaponSpecialization: 255
        });
        stats[9] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 17, constitution: 11, size: 6, agility: 11, stamina: 11, luck: 15
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 10,
            currentXP: 0,
            armorSpecialization: 1,
            weaponSpecialization: 18
        });

        return stats;
    }

    function getUndeadMonster001Stats(uint16 skinTokenId, uint16 nameIndex)
        private
        pure
        returns (IMonster.MonsterStats[10] memory)
    {
        IMonster.MonsterStats[10] memory stats;
        IMonster.MonsterName memory name = IMonster.MonsterName({nameIndex: nameIndex});
        uint8 stance = 2;

        // Level 1 - 72 attribute points (Normal tier)
        stats[0] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 10, constitution: 10, size: 12, agility: 16, stamina: 10, luck: 14
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 1,
            currentXP: 0,
            armorSpecialization: 255,
            weaponSpecialization: 255
        });
        stats[1] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 10, constitution: 10, size: 12, agility: 17, stamina: 10, luck: 14
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 2,
            currentXP: 0,
            armorSpecialization: 255,
            weaponSpecialization: 255
        });
        stats[2] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 10, constitution: 10, size: 12, agility: 17, stamina: 10, luck: 15
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 3,
            currentXP: 0,
            armorSpecialization: 255,
            weaponSpecialization: 255
        });
        stats[3] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 10, constitution: 10, size: 12, agility: 17, stamina: 10, luck: 16
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 4,
            currentXP: 0,
            armorSpecialization: 255,
            weaponSpecialization: 255
        });
        stats[4] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 10, constitution: 10, size: 12, agility: 17, stamina: 10, luck: 17
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 5,
            currentXP: 0,
            armorSpecialization: 0,
            weaponSpecialization: 255
        });
        stats[5] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 10, constitution: 10, size: 12, agility: 17, stamina: 11, luck: 17
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 6,
            currentXP: 0,
            armorSpecialization: 0,
            weaponSpecialization: 255
        });
        stats[6] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 10, constitution: 10, size: 12, agility: 17, stamina: 12, luck: 17
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 7,
            currentXP: 0,
            armorSpecialization: 0,
            weaponSpecialization: 255
        });
        stats[7] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 10, constitution: 10, size: 12, agility: 18, stamina: 12, luck: 17
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 8,
            currentXP: 0,
            armorSpecialization: 0,
            weaponSpecialization: 255
        });
        stats[8] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 10, constitution: 10, size: 12, agility: 19, stamina: 12, luck: 17
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 9,
            currentXP: 0,
            armorSpecialization: 0,
            weaponSpecialization: 255
        });
        stats[9] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 10, constitution: 10, size: 12, agility: 19, stamina: 12, luck: 18
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 10,
            currentXP: 0,
            armorSpecialization: 0,
            weaponSpecialization: 9
        });

        return stats;
    }

    function getDemonMonster001Stats(uint16 skinTokenId, uint16 nameIndex)
        private
        pure
        returns (IMonster.MonsterStats[10] memory)
    {
        IMonster.MonsterStats[10] memory stats;
        IMonster.MonsterName memory name = IMonster.MonsterName({nameIndex: nameIndex});
        uint8 stance = 1;

        // Level 1 - 82 attribute points (Hard tier)
        stats[0] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 18, constitution: 18, size: 14, agility: 10, stamina: 10, luck: 12
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 1,
            currentXP: 0,
            armorSpecialization: 3,
            weaponSpecialization: 255
        });
        stats[1] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 18, constitution: 18, size: 15, agility: 10, stamina: 10, luck: 12
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 2,
            currentXP: 0,
            armorSpecialization: 3,
            weaponSpecialization: 255
        });
        stats[2] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 18, constitution: 18, size: 16, agility: 10, stamina: 10, luck: 12
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 3,
            currentXP: 0,
            armorSpecialization: 3,
            weaponSpecialization: 255
        });
        stats[3] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 18, constitution: 18, size: 17, agility: 10, stamina: 10, luck: 12
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 4,
            currentXP: 0,
            armorSpecialization: 3,
            weaponSpecialization: 255
        });
        stats[4] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 18, constitution: 18, size: 18, agility: 10, stamina: 10, luck: 12
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 5,
            currentXP: 0,
            armorSpecialization: 3,
            weaponSpecialization: 0
        });
        stats[5] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 19, constitution: 18, size: 18, agility: 10, stamina: 10, luck: 12
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 6,
            currentXP: 0,
            armorSpecialization: 3,
            weaponSpecialization: 0
        });
        stats[6] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 20, constitution: 18, size: 18, agility: 10, stamina: 10, luck: 12
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 7,
            currentXP: 0,
            armorSpecialization: 3,
            weaponSpecialization: 0
        });
        stats[7] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 21, constitution: 18, size: 18, agility: 10, stamina: 10, luck: 12
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 8,
            currentXP: 0,
            armorSpecialization: 3,
            weaponSpecialization: 0
        });
        stats[8] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 21, constitution: 19, size: 18, agility: 10, stamina: 10, luck: 12
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 9,
            currentXP: 0,
            armorSpecialization: 3,
            weaponSpecialization: 0
        });
        stats[9] = IMonster.MonsterStats({
            attributes: Fighter.Attributes({
                strength: 21, constitution: 20, size: 18, agility: 10, stamina: 10, luck: 12
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: skinTokenId}),
            stance: stance,
            name: name,
            level: 10,
            currentXP: 0,
            armorSpecialization: 3,
            weaponSpecialization: 0
        });

        return stats;
    }
}

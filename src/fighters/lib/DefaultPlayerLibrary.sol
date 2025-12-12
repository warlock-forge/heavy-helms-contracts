// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {IPlayer} from "../../interfaces/fighters/IPlayer.sol";
import {DefaultPlayerSkinNFT} from "../../nft/skins/DefaultPlayerSkinNFT.sol";
import {Fighter} from "../../fighters/Fighter.sol";
import {IDefaultPlayer} from "../../interfaces/fighters/IDefaultPlayer.sol";

//==============================================================//
//                     DEFAULT PLAYER LIBRARY                   //
//==============================================================//
/// @title DefaultPlayerLibrary
/// @notice Library for creating default player characters with predefined stats
/// @dev Uses compact encoding for level-up patterns to reduce code size
///      Character IDs are 1-based (matching tokenId, range 1-2000 for default players)
///      Current characters:
///        1: DefaultWarrior          10: DualClubsWarrior
///        2: BalancedWarrior         11: AxeKitePlateBalanced
///        3: GreatswordOffensive     12: DualScimitarsWarrior
///        4: BattleaxeOffensive      13: ShortswordTowerWarrior
///        5: SpearBalanced           14: VanguardWarrior
///        6: MaceShieldDefensive     15: MageWarrior
///        7: RapierShieldDefensive   16: ValkyrieWarrior
///        8: DaggersUser             17: LowStaminaClubsWarrior
///        9: ScimitarBucklerUser     18: AltDaggersUser
library DefaultPlayerLibrary {
    //==============================================================//
    //                          CONSTANTS                           //
    //==============================================================//
    uint16 public constant CHARACTER_COUNT = 24;

    //==============================================================//
    //                           STRUCTS                            //
    //==============================================================//
    /// @dev Compact character definition - base stats + level-up pattern
    struct CharacterDef {
        uint8 weapon;
        uint8 armor;
        uint8 stance;
        uint16 firstName;
        uint16 surname;
        uint8 weaponSpec;
        uint8 armorSpec;
        // Base stats at level 1
        uint8 str;
        uint8 con;
        uint8 size;
        uint8 agi;
        uint8 sta;
        uint8 luck;
        // 9 bytes encoding which stat increases at each level (2-10)
        // Values: 0=STR, 1=CON, 2=SIZE, 3=AGI, 4=STA, 5=LUCK
        bytes9 levelUps;
        string ipfsCid;
    }

    //==============================================================//
    //                      EXTERNAL FUNCTIONS                      //
    //==============================================================//
    function createDefaultCharacter(
        DefaultPlayerSkinNFT defaultSkin,
        IDefaultPlayer defaultPlayer,
        uint32 skinIndex,
        uint16 characterId
    ) internal {
        require(characterId >= 1 && characterId <= CHARACTER_COUNT, "Invalid character ID");

        CharacterDef memory def = _getCharacterDefs()[characterId - 1];
        IPlayer.PlayerStats[10] memory stats = _buildStats(def, skinIndex, characterId);

        defaultPlayer.createDefaultPlayer(characterId, stats);
        defaultSkin.mintDefaultPlayerSkin(def.weapon, def.armor, def.ipfsCid, characterId);
    }

    //==============================================================//
    //                      INTERNAL FUNCTIONS                      //
    //==============================================================//
    function _getCharacterDefs() internal pure returns (CharacterDef[] memory defs) {
        defs = new CharacterDef[](CHARACTER_COUNT);
        // 1: DefaultWarrior
        defs[0] = CharacterDef({
            weapon: 5,
            armor: 0,
            stance: 1,
            firstName: 0,
            surname: 155,
            weaponSpec: 5,
            armorSpec: 0,
            str: 12,
            con: 12,
            size: 12,
            agi: 12,
            sta: 12,
            luck: 12,
            levelUps: hex"000103000103000103",
            ipfsCid: "bafkreifbjayatwb3chcfacso3cligrob3l3ykliyqev4j4cmzgpls2saeq"
        });
        // 2: BalancedWarrior
        defs[1] = CharacterDef({
            weapon: 0,
            armor: 2,
            stance: 1,
            firstName: 1015,
            surname: 97,
            weaponSpec: 0,
            armorSpec: 2,
            str: 12,
            con: 12,
            size: 12,
            agi: 12,
            sta: 12,
            luck: 12,
            levelUps: hex"000001010103040000",
            ipfsCid: "bafkreiekllubajc7auisldffitig2j4afrc4hbedyjtqtdv7vbhgcqcmy4"
        });
        // 3: GreatswordOffensive
        defs[2] = CharacterDef({
            weapon: 3,
            armor: 1,
            stance: 2,
            firstName: 1062,
            surname: 131,
            weaponSpec: 3,
            armorSpec: 1,
            str: 18,
            con: 10,
            size: 14,
            agi: 10,
            sta: 10,
            luck: 10,
            levelUps: hex"000000020202040404",
            ipfsCid: "bafkreid5npakg2yxd3542voibvlwtikgg4ai3eecu2jl4qdwmidsvpzsnu"
        });
        // 4: BattleaxeOffensive
        defs[3] = CharacterDef({
            weapon: 4,
            armor: 1,
            stance: 2,
            firstName: 1102,
            surname: 241,
            weaponSpec: 4,
            armorSpec: 1,
            str: 16,
            con: 12,
            size: 14,
            agi: 10,
            sta: 10,
            luck: 10,
            levelUps: hex"000000000002020202",
            ipfsCid: "bafkreifoy2xwhckb53zawn7hzvxprcchw7m3iu66mwldxo3gi2ttryjfma"
        });
        // 5: SpearBalanced
        defs[4] = CharacterDef({
            weapon: 6,
            armor: 1,
            stance: 1,
            firstName: 1146,
            surname: 25,
            weaponSpec: 6,
            armorSpec: 1,
            str: 16,
            con: 8,
            size: 12,
            agi: 16,
            sta: 12,
            luck: 8,
            levelUps: hex"000300030003000305",
            ipfsCid: "bafkreidcehmxbkeoym6dz6zwtw35nf5uswoonycqtdn57vha35qkuengfe"
        });
        // 6: MaceShieldDefensive
        defs[5] = CharacterDef({
            weapon: 1,
            armor: 3,
            stance: 0,
            firstName: 1079,
            surname: 165,
            weaponSpec: 1,
            armorSpec: 3,
            str: 12,
            con: 19,
            size: 14,
            agi: 6,
            sta: 15,
            luck: 6,
            levelUps: hex"010101010101040402",
            ipfsCid: "bafkreib5umhjzlug3a4mxabqbsdgo4q5xwpubixjyhvcv36gjhty5sadwu"
        });
        // 7: RapierShieldDefensive
        defs[6] = CharacterDef({
            weapon: 2,
            armor: 1,
            stance: 1,
            firstName: 38,
            surname: 15,
            weaponSpec: 2,
            armorSpec: 1,
            str: 10,
            con: 12,
            size: 8,
            agi: 16,
            sta: 12,
            luck: 14,
            levelUps: hex"030303030303030303",
            ipfsCid: "bafkreiajp62udpay6ffa6q5s3hxthkiherqrl6alx4jpoeviqhenkmtbfa"
        });
        // 8: DaggersUser
        defs[7] = CharacterDef({
            weapon: 9,
            armor: 1,
            stance: 2,
            firstName: 1043,
            surname: 158,
            weaponSpec: 9,
            armorSpec: 1,
            str: 14,
            con: 6,
            size: 10,
            agi: 16,
            sta: 10,
            luck: 16,
            levelUps: hex"030303030303030303",
            ipfsCid: "bafkreichxvcymgfql6t2qrbiyjlerxcrei7kriqv4abc7d2f5xjbi54zpy"
        });
        // 9: ScimitarBucklerUser
        defs[8] = CharacterDef({
            weapon: 11,
            armor: 0,
            stance: 0,
            firstName: 1139,
            surname: 216,
            weaponSpec: 11,
            armorSpec: 0,
            str: 12,
            con: 14,
            size: 8,
            agi: 14,
            sta: 12,
            luck: 12,
            levelUps: hex"010101000003030300",
            ipfsCid: "bafkreihmbsfcov2jy7vlebsh5jg7i7k7pnzgcdthnd55drts7ode2wjm3y"
        });
        // 10: DualClubsWarrior
        defs[9] = CharacterDef({
            weapon: 18,
            armor: 1,
            stance: 2,
            firstName: 1071,
            surname: 37,
            weaponSpec: 18,
            armorSpec: 1,
            str: 16,
            con: 8,
            size: 16,
            agi: 8,
            sta: 12,
            luck: 12,
            levelUps: hex"000000000000000000",
            ipfsCid: "bafkreid5ufeacbogoagtcfba2367nmnpjyxa5czu36btghg7d3af34vtnu"
        });
        // 11: AxeKitePlateBalanced
        defs[10] = CharacterDef({
            weapon: 12,
            armor: 3,
            stance: 1,
            firstName: 1145,
            surname: 4,
            weaponSpec: 12,
            armorSpec: 3,
            str: 12,
            con: 18,
            size: 12,
            agi: 8,
            sta: 14,
            luck: 8,
            levelUps: hex"000000000000040202",
            ipfsCid: "bafkreicyyzq5tv4akfqblvixftzct5mifs4ymg7l56koy52zomnhxkosky"
        });
        // 12: DualScimitarsWarrior
        defs[11] = CharacterDef({
            weapon: 14,
            armor: 0,
            stance: 2,
            firstName: 1084,
            surname: 242,
            weaponSpec: 14,
            armorSpec: 0,
            str: 16,
            con: 4,
            size: 12,
            agi: 16,
            sta: 12,
            luck: 12,
            levelUps: hex"000300030003000304",
            ipfsCid: "bafkreif2wab4gyi45koar4mzitvryg3npik4s4dxwka73zvyfrqpp3g5iu"
        });
        // 13: ShortswordTowerWarrior
        defs[12] = CharacterDef({
            weapon: 8,
            armor: 3,
            stance: 0,
            firstName: 1031,
            surname: 104,
            weaponSpec: 8,
            armorSpec: 3,
            str: 12,
            con: 20,
            size: 12,
            agi: 8,
            sta: 12,
            luck: 8,
            levelUps: hex"010101010104040402",
            ipfsCid: "bafkreibrfl56qwfyrfuaxto7jgnhe73b4qxcsenjkt27zs3fdjo7yrmf3m"
        });
        // 14: VanguardWarrior
        defs[13] = CharacterDef({
            weapon: 3,
            armor: 2,
            stance: 0,
            firstName: 1078,
            surname: 139,
            weaponSpec: 3,
            armorSpec: 2,
            str: 19,
            con: 19,
            size: 12,
            agi: 5,
            sta: 12,
            luck: 5,
            levelUps: hex"000001010404040202",
            ipfsCid: "bafkreihm7xfvb35obizx5bypcpsom3pnqg4jakgnootb7c4r4bkafi4u4a"
        });
        // 15: MageWarrior
        defs[14] = CharacterDef({
            weapon: 5,
            armor: 1,
            stance: 0,
            firstName: 1135,
            surname: 198,
            weaponSpec: 5,
            armorSpec: 1,
            str: 12,
            con: 12,
            size: 12,
            agi: 12,
            sta: 19,
            luck: 5,
            levelUps: hex"000000000101010103",
            ipfsCid: "bafkreihndxzbu7vyxb4jnzrdlyhvmjzxivvbtnkbaq7fn6ejfuvmjwenxa"
        });
        // 16: ValkyrieWarrior
        defs[15] = CharacterDef({
            weapon: 0,
            armor: 3,
            stance: 1,
            firstName: 10,
            surname: 188,
            weaponSpec: 0,
            armorSpec: 3,
            str: 12,
            con: 14,
            size: 11,
            agi: 9,
            sta: 17,
            luck: 9,
            levelUps: hex"000000010202020205",
            ipfsCid: "bafkreibzvmc7skc5v7lsghi6ug5vehttoxcqpsi7nraewkr6z72pcjhfwy"
        });
        // 17: LowStaminaClubsWarrior
        defs[16] = CharacterDef({
            weapon: 18,
            armor: 0,
            stance: 1,
            firstName: 83,
            surname: 232,
            weaponSpec: 18,
            armorSpec: 0,
            str: 19,
            con: 5,
            size: 19,
            agi: 12,
            sta: 5,
            luck: 12,
            levelUps: hex"000002020505050505",
            ipfsCid: "bafkreiaio3mlfiqnoshu35qgpnmid2c24wwmivi2h3tbb67yvguo66btky"
        });
        // 18: AltDaggersUser
        defs[17] = CharacterDef({
            weapon: 9,
            armor: 1,
            stance: 2,
            firstName: 95,
            surname: 5,
            weaponSpec: 9,
            armorSpec: 1,
            str: 12,
            con: 7,
            size: 12,
            agi: 17,
            sta: 9,
            luck: 15,
            levelUps: hex"030303030303030304",
            ipfsCid: "bafkreieh2vw6eobqqawgujacaq7z6oc5gzqptczxa3ko42rlewahtyoxpe"
        });
        // 19: CrusaderTank
        defs[18] = CharacterDef({
            weapon: 8,
            armor: 3,
            stance: 0,
            firstName: 1092,
            surname: 142,
            weaponSpec: 8,
            armorSpec: 3,
            str: 10,
            con: 17,
            size: 14,
            agi: 10,
            sta: 12,
            luck: 9,
            levelUps: hex"020202040401010101",
            ipfsCid: "bafkreihbpwhdc75m6lbaq6vmr5ibywuavzbagq3kyy6vatwv6vcdbkq34u"
        });
        // 20: UmbrellaMonk
        defs[19] = CharacterDef({
            weapon: 5,
            armor: 0,
            stance: 1,
            firstName: 16,
            surname: 56,
            weaponSpec: 5,
            armorSpec: 0,
            str: 17,
            con: 10,
            size: 7,
            agi: 16,
            sta: 12,
            luck: 10,
            levelUps: hex"030303030300000000",
            ipfsCid: "bafkreic4vodwzwgzms3x2bqg7cyebzdyyok5vhoivtw7eraveddrnqnvrm"
        });
        // 21: BattleaxeViking
        defs[20] = CharacterDef({
            weapon: 4,
            armor: 1,
            stance: 2,
            firstName: 1035,
            surname: 192,
            weaponSpec: 4,
            armorSpec: 1,
            str: 18,
            con: 10,
            size: 18,
            agi: 6,
            sta: 10,
            luck: 10,
            levelUps: hex"020202020000000005",
            ipfsCid: "bafkreibpaq5vn7xbu5jvmtpjlo75wtfst5and3jt43mcri5qgl6f2lzm3i"
        });
        // 22: SpearGladiator
        defs[21] = CharacterDef({
            weapon: 6,
            armor: 1,
            stance: 2,
            firstName: 1110,
            surname: 190,
            weaponSpec: 6,
            armorSpec: 1,
            str: 16,
            con: 10,
            size: 12,
            agi: 16,
            sta: 8,
            luck: 10,
            levelUps: hex"000305000300030003",
            ipfsCid: "bafkreihbo23z4xmlyh6wmbull7t4kwytbrsmsfe25qm2nmrn7f6chuon44"
        });
        // 23: PlateGladiator
        defs[22] = CharacterDef({
            weapon: 3,
            armor: 3,
            stance: 1,
            firstName: 1026,
            surname: 34,
            weaponSpec: 3,
            armorSpec: 3,
            str: 16,
            con: 8,
            size: 16,
            agi: 6,
            sta: 16,
            luck: 10,
            levelUps: hex"000204020202020200",
            ipfsCid: "bafkreichn3t3n6nakqtc42kvyrtqsscppj47i4vip4cjmc6fswee5ysyh4"
        });
        // 24: AssassinSwords
        defs[23] = CharacterDef({
            weapon: 19,
            armor: 1,
            stance: 2,
            firstName: 1050,
            surname: 106,
            weaponSpec: 19,
            armorSpec: 1,
            str: 17,
            con: 8,
            size: 8,
            agi: 15,
            sta: 12,
            luck: 12,
            levelUps: hex"000000000003030505",
            ipfsCid: "bafkreigmhp4sowm7njghxscjzmd2spjcsq3uv7ea3mdcxzaaf5zmemla24"
        });
    }

    function _buildStats(CharacterDef memory def, uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (IPlayer.PlayerStats[10] memory stats)
    {
        // Initialize current stats from base
        uint8[6] memory current = [def.str, def.con, def.size, def.agi, def.sta, def.luck];

        for (uint8 level = 1; level <= 10; level++) {
            // Apply level-up if not level 1
            if (level > 1) {
                uint8 statIndex = uint8(def.levelUps[level - 2]);
                current[statIndex]++;
            }

            // Determine specializations based on level
            uint8 weaponSpec = level == 10 ? def.weaponSpec : 255;
            uint8 armorSpec = level >= 5 ? def.armorSpec : 255;

            stats[level - 1] = IPlayer.PlayerStats({
                attributes: Fighter.Attributes({
                    strength: current[0],
                    constitution: current[1],
                    size: current[2],
                    agility: current[3],
                    stamina: current[4],
                    luck: current[5]
                }),
                skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
                stance: def.stance,
                name: IPlayer.PlayerName({firstNameIndex: def.firstName, surnameIndex: def.surname}),
                level: level,
                currentXP: 0,
                weaponSpecialization: weaponSpec,
                armorSpecialization: armorSpec
            });
        }
    }

    function createAllDefaultCharacters(
        DefaultPlayerSkinNFT defaultSkin,
        IDefaultPlayer defaultPlayer,
        uint32 defaultSkinIndex
    ) internal {
        for (uint16 i = 1; i <= CHARACTER_COUNT; i++) {
            createDefaultCharacter(defaultSkin, defaultPlayer, defaultSkinIndex, i);
        }
    }
}

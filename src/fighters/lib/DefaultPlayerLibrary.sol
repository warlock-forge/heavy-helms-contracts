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

library DefaultPlayerLibrary {
    enum CharacterType {
        DefaultWarrior, // ID 1
        BalancedWarrior, // ID 2
        GreatswordOffensive, // ID 3
        BattleaxeOffensive, // ID 4
        SpearBalanced, // ID 5
        MaceAndShieldDefensive, // ID 6
        RapierAndShieldDefensive, // ID 7
        DaggersUser, // ID 8
        ScimitarAndBucklerUser, // ID 9
        DualClubsWarrior, // ID 10
        AxeKitePlateBalancedWarrior, // ID 11
        DualScimitarsWarrior, // ID 12
        ShortswordTowerdWarrior, // ID 13
        VanguardWarrior, // ID 14
        MageWarrior, // ID 15
        ValkyrieWarrior, // ID 16
        LowStaminaClubsWarrior, // ID 17
        AltDaggersUser // ID 18

    }

    function getDefaultWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 5; // WEAPON_QUARTERSTAFF
        armor = 0; // ARMOR_CLOTH
        ipfsCid = "bafkreifbjayatwb3chcfacso3cligrob3l3ykliyqev4j4cmzgpls2saeq";

        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 12, size: 12, agility: 12, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 155}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 13, constitution: 12, size: 12, agility: 12, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 155}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 13, constitution: 13, size: 12, agility: 12, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 155}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 13, constitution: 13, size: 12, agility: 13, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 155}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 13, size: 12, agility: 13, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 155}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 14, size: 12, agility: 13, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 155}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 14, size: 12, agility: 14, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 155}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 14, size: 12, agility: 14, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 155}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 15, size: 12, agility: 14, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 155}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 15, size: 12, agility: 15, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 155}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 5,
            armorSpecialization: 0
        });
    }

    function getBalancedWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 0; // WEAPON_SWORD_AND_SHIELD
        armor = 2; // ARMOR_CHAIN
        ipfsCid = "bafkreiekllubajc7auisldffitig2j4afrc4hbedyjtqtdv7vbhgcqcmy4";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 12, size: 12, agility: 12, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1015, surnameIndex: 97}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 13, constitution: 12, size: 12, agility: 12, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1015, surnameIndex: 97}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 12, size: 12, agility: 12, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1015, surnameIndex: 97}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 12, size: 12, agility: 12, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1015, surnameIndex: 97}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 13, size: 12, agility: 12, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1015, surnameIndex: 97}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 2
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 14, size: 12, agility: 12, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1015, surnameIndex: 97}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 2
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 15, size: 12, agility: 12, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1015, surnameIndex: 97}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 2
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 15, size: 12, agility: 13, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1015, surnameIndex: 97}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 2
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 15, size: 12, agility: 13, stamina: 13, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1015, surnameIndex: 97}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 2
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 15, size: 12, agility: 13, stamina: 13, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1015, surnameIndex: 97}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 0,
            armorSpecialization: 2
        });
    }

    function getGreatswordUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 3; // WEAPON_GREATSWORD
        armor = 1; // ARMOR_LEATHER
        ipfsCid = "bafkreid5npakg2yxd3542voibvlwtikgg4ai3eecu2jl4qdwmidsvpzsnu";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 18, constitution: 10, size: 14, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1062, surnameIndex: 131}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 19, constitution: 10, size: 14, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1062, surnameIndex: 131}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 20, constitution: 10, size: 14, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1062, surnameIndex: 131}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 10, size: 14, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1062, surnameIndex: 131}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 10, size: 15, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1062, surnameIndex: 131}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 10, size: 16, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1062, surnameIndex: 131}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 10, size: 17, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1062, surnameIndex: 131}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 10, size: 17, agility: 10, stamina: 11, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1062, surnameIndex: 131}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 10, size: 17, agility: 10, stamina: 12, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1062, surnameIndex: 131}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 10, size: 17, agility: 10, stamina: 13, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1062, surnameIndex: 131}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 3,
            armorSpecialization: 1
        });
    }

    function getBattleaxeUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 4; // WEAPON_BATTLEAXE
        armor = 1; // ARMOR_LEATHER
        ipfsCid = "bafkreifoy2xwhckb53zawn7hzvxprcchw7m3iu66mwldxo3gi2ttryjfma";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 12, size: 14, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1102, surnameIndex: 241}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 17, constitution: 12, size: 14, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1102, surnameIndex: 241}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 18, constitution: 12, size: 14, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1102, surnameIndex: 241}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 19, constitution: 12, size: 14, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1102, surnameIndex: 241}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 20, constitution: 12, size: 14, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1102, surnameIndex: 241}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 12, size: 14, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1102, surnameIndex: 241}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 12, size: 15, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1102, surnameIndex: 241}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 12, size: 16, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1102, surnameIndex: 241}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 12, size: 17, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1102, surnameIndex: 241}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 12, size: 18, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1102, surnameIndex: 241}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 4,
            armorSpecialization: 1
        });
    }

    function getSpearUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 6; // WEAPON_SPEAR
        armor = 1; // ARMOR_LEATHER
        ipfsCid = "bafkreidcehmxbkeoym6dz6zwtw35nf5uswoonycqtdn57vha35qkuengfe";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 8, size: 12, agility: 16, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1146, surnameIndex: 25}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 17, constitution: 8, size: 12, agility: 16, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1146, surnameIndex: 25}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 17, constitution: 8, size: 12, agility: 17, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1146, surnameIndex: 25}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 18, constitution: 8, size: 12, agility: 17, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1146, surnameIndex: 25}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 18, constitution: 8, size: 12, agility: 18, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1146, surnameIndex: 25}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 19, constitution: 8, size: 12, agility: 18, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1146, surnameIndex: 25}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 19, constitution: 8, size: 12, agility: 19, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1146, surnameIndex: 25}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 20, constitution: 8, size: 12, agility: 19, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1146, surnameIndex: 25}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 20, constitution: 8, size: 12, agility: 20, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1146, surnameIndex: 25}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 20, constitution: 8, size: 12, agility: 20, stamina: 12, luck: 9}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1146, surnameIndex: 25}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 6,
            armorSpecialization: 1
        });
    }

    function getRapierAndShieldUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 2; // WEAPON_RAPIER_AND_SHIELD
        armor = 1; // ARMOR_LEATHER
        ipfsCid = "bafkreiajp62udpay6ffa6q5s3hxthkiherqrl6alx4jpoeviqhenkmtbfa";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 10, constitution: 12, size: 8, agility: 16, stamina: 12, luck: 14}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 38, surnameIndex: 15}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 10, constitution: 12, size: 8, agility: 17, stamina: 12, luck: 14}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 38, surnameIndex: 15}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 10, constitution: 12, size: 8, agility: 18, stamina: 12, luck: 14}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 38, surnameIndex: 15}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 10, constitution: 12, size: 8, agility: 19, stamina: 12, luck: 14}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 38, surnameIndex: 15}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 10, constitution: 12, size: 8, agility: 20, stamina: 12, luck: 14}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 38, surnameIndex: 15}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 10, constitution: 12, size: 8, agility: 21, stamina: 12, luck: 14}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 38, surnameIndex: 15}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 10, constitution: 12, size: 8, agility: 22, stamina: 12, luck: 14}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 38, surnameIndex: 15}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 10, constitution: 12, size: 8, agility: 23, stamina: 12, luck: 14}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 38, surnameIndex: 15}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 10, constitution: 12, size: 8, agility: 24, stamina: 12, luck: 14}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 38, surnameIndex: 15}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 10, constitution: 12, size: 8, agility: 25, stamina: 12, luck: 14}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 38, surnameIndex: 15}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 2,
            armorSpecialization: 1
        });
    }

    function getMaceAndShieldUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 1; // WEAPON_MACE_AND_SHIELD
        armor = 3; // ARMOR_PLATE
        ipfsCid = "bafkreib5umhjzlug3a4mxabqbsdgo4q5xwpubixjyhvcv36gjhty5sadwu";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 19, size: 14, agility: 6, stamina: 15, luck: 6}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1079, surnameIndex: 165}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 20, size: 14, agility: 6, stamina: 15, luck: 6}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1079, surnameIndex: 165}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 21, size: 14, agility: 6, stamina: 15, luck: 6}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1079, surnameIndex: 165}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 22, size: 14, agility: 6, stamina: 15, luck: 6}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1079, surnameIndex: 165}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 23, size: 14, agility: 6, stamina: 15, luck: 6}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1079, surnameIndex: 165}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 24, size: 14, agility: 6, stamina: 15, luck: 6}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1079, surnameIndex: 165}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 25, size: 14, agility: 6, stamina: 15, luck: 6}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1079, surnameIndex: 165}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 25, size: 14, agility: 6, stamina: 16, luck: 6}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1079, surnameIndex: 165}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 25, size: 14, agility: 6, stamina: 17, luck: 6}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1079, surnameIndex: 165}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 25, size: 15, agility: 6, stamina: 17, luck: 6}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1079, surnameIndex: 165}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 1,
            armorSpecialization: 3
        });
    }

    function getDaggersUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 9; // WEAPON_DUAL_DAGGERS
        armor = 1; // ARMOR_LEATHER
        ipfsCid = "bafkreichxvcymgfql6t2qrbiyjlerxcrei7kriqv4abc7d2f5xjbi54zpy";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 6, size: 10, agility: 16, stamina: 10, luck: 16}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1043, surnameIndex: 158}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 6, size: 10, agility: 17, stamina: 10, luck: 16}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1043, surnameIndex: 158}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 6, size: 10, agility: 18, stamina: 10, luck: 16}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1043, surnameIndex: 158}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 6, size: 10, agility: 19, stamina: 10, luck: 16}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1043, surnameIndex: 158}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 6, size: 10, agility: 20, stamina: 10, luck: 16}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1043, surnameIndex: 158}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 6, size: 10, agility: 21, stamina: 10, luck: 16}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1043, surnameIndex: 158}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 6, size: 10, agility: 22, stamina: 10, luck: 16}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1043, surnameIndex: 158}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 6, size: 10, agility: 23, stamina: 10, luck: 16}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1043, surnameIndex: 158}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 6, size: 10, agility: 24, stamina: 10, luck: 16}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1043, surnameIndex: 158}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 6, size: 10, agility: 25, stamina: 10, luck: 16}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1043, surnameIndex: 158}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 9,
            armorSpecialization: 1
        });
    }

    function getScimitarAndBucklerUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 11; // WEAPON_SCIMITAR_BUCKLER
        armor = 0; // ARMOR_CLOTH
        ipfsCid = "bafkreihmbsfcov2jy7vlebsh5jg7i7k7pnzgcdthnd55drts7ode2wjm3y";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 14, size: 8, agility: 14, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1139, surnameIndex: 216}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 15, size: 8, agility: 14, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1139, surnameIndex: 216}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 16, size: 8, agility: 14, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1139, surnameIndex: 216}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 17, size: 8, agility: 14, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1139, surnameIndex: 216}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 13, constitution: 17, size: 8, agility: 14, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1139, surnameIndex: 216}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 17, size: 8, agility: 14, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1139, surnameIndex: 216}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 17, size: 8, agility: 15, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1139, surnameIndex: 216}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 17, size: 8, agility: 16, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1139, surnameIndex: 216}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 17, size: 8, agility: 17, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1139, surnameIndex: 216}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 17, size: 8, agility: 17, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1139, surnameIndex: 216}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 11,
            armorSpecialization: 0
        });
    }

    function getDualClubsWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 18; // WEAPON_DUAL_CLUBS
        armor = 1; // ARMOR_LEATHER
        ipfsCid = "bafkreid5ufeacbogoagtcfba2367nmnpjyxa5czu36btghg7d3af34vtnu";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 8, size: 16, agility: 8, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1071, surnameIndex: 37}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 17, constitution: 8, size: 16, agility: 8, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1071, surnameIndex: 37}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 18, constitution: 8, size: 16, agility: 8, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1071, surnameIndex: 37}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 19, constitution: 8, size: 16, agility: 8, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1071, surnameIndex: 37}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 20, constitution: 8, size: 16, agility: 8, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1071, surnameIndex: 37}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 8, size: 16, agility: 8, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1071, surnameIndex: 37}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 22, constitution: 8, size: 16, agility: 8, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1071, surnameIndex: 37}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 23, constitution: 8, size: 16, agility: 8, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1071, surnameIndex: 37}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 24, constitution: 8, size: 16, agility: 8, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1071, surnameIndex: 37}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 25, constitution: 8, size: 16, agility: 8, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1071, surnameIndex: 37}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 18,
            armorSpecialization: 1
        });
    }

    function getAxeKitePlateBalancedWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 12; // WEAPON_AXE_KITE
        armor = 3; // ARMOR_PLATE
        ipfsCid = "bafkreicyyzq5tv4akfqblvixftzct5mifs4ymg7l56koy52zomnhxkosky";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 18, size: 12, agility: 8, stamina: 14, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1145, surnameIndex: 4}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 13, constitution: 18, size: 12, agility: 8, stamina: 14, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1145, surnameIndex: 4}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 18, size: 12, agility: 8, stamina: 14, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1145, surnameIndex: 4}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 18, size: 12, agility: 8, stamina: 14, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1145, surnameIndex: 4}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 18, size: 12, agility: 8, stamina: 14, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1145, surnameIndex: 4}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 17, constitution: 18, size: 12, agility: 8, stamina: 14, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1145, surnameIndex: 4}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 18, constitution: 18, size: 12, agility: 8, stamina: 14, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1145, surnameIndex: 4}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 18, constitution: 18, size: 12, agility: 8, stamina: 15, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1145, surnameIndex: 4}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 18, constitution: 18, size: 13, agility: 8, stamina: 15, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1145, surnameIndex: 4}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 18, constitution: 18, size: 14, agility: 8, stamina: 15, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1145, surnameIndex: 4}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 12,
            armorSpecialization: 3
        });
    }

    function getDualScimitarsWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 14; // WEAPON_DUAL_SCIMITARS
        armor = 0; // ARMOR_CLOTH
        ipfsCid = "bafkreif2wab4gyi45koar4mzitvryg3npik4s4dxwka73zvyfrqpp3g5iu";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 4, size: 12, agility: 16, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1084, surnameIndex: 242}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 17, constitution: 4, size: 12, agility: 16, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1084, surnameIndex: 242}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 17, constitution: 4, size: 12, agility: 17, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1084, surnameIndex: 242}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 18, constitution: 4, size: 12, agility: 17, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1084, surnameIndex: 242}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 18, constitution: 4, size: 12, agility: 18, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1084, surnameIndex: 242}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 19, constitution: 4, size: 12, agility: 18, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1084, surnameIndex: 242}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 19, constitution: 4, size: 12, agility: 19, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1084, surnameIndex: 242}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 20, constitution: 4, size: 12, agility: 19, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1084, surnameIndex: 242}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 20, constitution: 4, size: 12, agility: 20, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1084, surnameIndex: 242}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 20, constitution: 4, size: 12, agility: 20, stamina: 13, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1084, surnameIndex: 242}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 14,
            armorSpecialization: 0
        });
    }

    function getShortswordTowerdWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 8; // WEAPON_SHORTSWORD_TOWER
        armor = 3; // ARMOR_PLATE
        ipfsCid = "bafkreibrfl56qwfyrfuaxto7jgnhe73b4qxcsenjkt27zs3fdjo7yrmf3m";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 20, size: 12, agility: 8, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1031, surnameIndex: 104}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 21, size: 12, agility: 8, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1031, surnameIndex: 104}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 22, size: 12, agility: 8, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1031, surnameIndex: 104}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 23, size: 12, agility: 8, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1031, surnameIndex: 104}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 24, size: 12, agility: 8, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1031, surnameIndex: 104}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 25, size: 12, agility: 8, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1031, surnameIndex: 104}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 25, size: 12, agility: 8, stamina: 13, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1031, surnameIndex: 104}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 25, size: 12, agility: 8, stamina: 14, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1031, surnameIndex: 104}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 25, size: 12, agility: 8, stamina: 15, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1031, surnameIndex: 104}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 25, size: 13, agility: 8, stamina: 15, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1031, surnameIndex: 104}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 8,
            armorSpecialization: 3
        });
    }

    function getVanguardWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 3; // WEAPON_GREATSWORD
        armor = 2; // ARMOR_CHAIN
        ipfsCid = "bafkreihm7xfvb35obizx5bypcpsom3pnqg4jakgnootb7c4r4bkafi4u4a";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 19, constitution: 19, size: 12, agility: 5, stamina: 12, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1078, surnameIndex: 139}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 20, constitution: 19, size: 12, agility: 5, stamina: 12, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1078, surnameIndex: 139}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 19, size: 12, agility: 5, stamina: 12, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1078, surnameIndex: 139}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 20, size: 12, agility: 5, stamina: 12, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1078, surnameIndex: 139}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 21, size: 12, agility: 5, stamina: 12, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1078, surnameIndex: 139}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 2
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 21, size: 12, agility: 5, stamina: 13, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1078, surnameIndex: 139}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 2
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 21, size: 12, agility: 5, stamina: 14, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1078, surnameIndex: 139}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 2
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 21, size: 12, agility: 5, stamina: 15, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1078, surnameIndex: 139}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 2
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 21, size: 13, agility: 5, stamina: 15, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1078, surnameIndex: 139}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 2
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 21, size: 14, agility: 5, stamina: 15, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1078, surnameIndex: 139}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 3,
            armorSpecialization: 2
        });
    }

    function getMageWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 5; // WEAPON_QUARTERSTAFF
        armor = 1; // ARMOR_LEATHER
        ipfsCid = "bafkreihndxzbu7vyxb4jnzrdlyhvmjzxivvbtnkbaq7fn6ejfuvmjwenxa";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 12, size: 12, agility: 12, stamina: 19, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1135, surnameIndex: 198}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 13, constitution: 12, size: 12, agility: 12, stamina: 19, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1135, surnameIndex: 198}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 12, size: 12, agility: 12, stamina: 19, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1135, surnameIndex: 198}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 12, size: 12, agility: 12, stamina: 19, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1135, surnameIndex: 198}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 12, size: 12, agility: 12, stamina: 19, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1135, surnameIndex: 198}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 13, size: 12, agility: 12, stamina: 19, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1135, surnameIndex: 198}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 14, size: 12, agility: 12, stamina: 19, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1135, surnameIndex: 198}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 15, size: 12, agility: 12, stamina: 19, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1135, surnameIndex: 198}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 16, size: 12, agility: 12, stamina: 19, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1135, surnameIndex: 198}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 16, size: 12, agility: 13, stamina: 19, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1135, surnameIndex: 198}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 5,
            armorSpecialization: 1
        });
    }

    function getValkyrieWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 0; // WEAPON_ARMING_SWORD_KITE
        armor = 3; // ARMOR_PLATE
        ipfsCid = "bafkreibzvmc7skc5v7lsghi6ug5vehttoxcqpsi7nraewkr6z72pcjhfwy";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 14, size: 11, agility: 9, stamina: 17, luck: 9}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 10, surnameIndex: 188}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 13, constitution: 14, size: 11, agility: 9, stamina: 17, luck: 9}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 10, surnameIndex: 188}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 14, size: 11, agility: 9, stamina: 17, luck: 9}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 10, surnameIndex: 188}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 14, size: 11, agility: 9, stamina: 17, luck: 9}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 10, surnameIndex: 188}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 15, size: 11, agility: 9, stamina: 17, luck: 9}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 10, surnameIndex: 188}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 15, size: 12, agility: 9, stamina: 17, luck: 9}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 10, surnameIndex: 188}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 15, size: 13, agility: 9, stamina: 17, luck: 9}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 10, surnameIndex: 188}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 15, size: 14, agility: 9, stamina: 17, luck: 9}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 10, surnameIndex: 188}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 15, size: 15, agility: 9, stamina: 17, luck: 9}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 10, surnameIndex: 188}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 3
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 15, constitution: 15, size: 15, agility: 9, stamina: 17, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 10, surnameIndex: 188}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 0,
            armorSpecialization: 3
        });
    }

    function getLowStaminaClubsWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 18; // WEAPON_DUAL_CLUBS
        armor = 0; // ARMOR_CLOTH
        ipfsCid = "bafkreiaio3mlfiqnoshu35qgpnmid2c24wwmivi2h3tbb67yvguo66btky";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 19, constitution: 5, size: 19, agility: 12, stamina: 5, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 83, surnameIndex: 232}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 20, constitution: 5, size: 19, agility: 12, stamina: 5, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 83, surnameIndex: 232}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 5, size: 19, agility: 12, stamina: 5, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 83, surnameIndex: 232}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 5, size: 20, agility: 12, stamina: 5, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 83, surnameIndex: 232}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 5, size: 21, agility: 12, stamina: 5, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 83, surnameIndex: 232}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 5, size: 21, agility: 12, stamina: 5, luck: 13}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 83, surnameIndex: 232}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 5, size: 21, agility: 12, stamina: 5, luck: 14}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 83, surnameIndex: 232}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 5, size: 21, agility: 12, stamina: 5, luck: 15}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 83, surnameIndex: 232}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 5, size: 21, agility: 12, stamina: 5, luck: 16}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 83, surnameIndex: 232}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 0
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 21, constitution: 5, size: 21, agility: 12, stamina: 5, luck: 17}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 83, surnameIndex: 232}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 18,
            armorSpecialization: 0
        });
    }

    function getAltDaggersUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
    {
        weapon = 9; // WEAPON_DUAL_DAGGERS
        armor = 1; // ARMOR_LEATHER
        ipfsCid = "bafkreieh2vw6eobqqawgujacaq7z6oc5gzqptczxa3ko42rlewahtyoxpe";
        stats[0] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 7, size: 12, agility: 17, stamina: 9, luck: 15}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 95, surnameIndex: 5}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[1] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 7, size: 12, agility: 18, stamina: 9, luck: 15}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 95, surnameIndex: 5}),
            level: 2,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[2] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 7, size: 12, agility: 19, stamina: 9, luck: 15}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 95, surnameIndex: 5}),
            level: 3,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[3] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 7, size: 12, agility: 20, stamina: 9, luck: 15}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 95, surnameIndex: 5}),
            level: 4,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        stats[4] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 7, size: 12, agility: 21, stamina: 9, luck: 15}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 95, surnameIndex: 5}),
            level: 5,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[5] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 7, size: 12, agility: 22, stamina: 9, luck: 15}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 95, surnameIndex: 5}),
            level: 6,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[6] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 7, size: 12, agility: 23, stamina: 9, luck: 15}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 95, surnameIndex: 5}),
            level: 7,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[7] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 7, size: 12, agility: 24, stamina: 9, luck: 15}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 95, surnameIndex: 5}),
            level: 8,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[8] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 7, size: 12, agility: 25, stamina: 9, luck: 15}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 95, surnameIndex: 5}),
            level: 9,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 1
        });
        stats[9] = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 7, size: 12, agility: 25, stamina: 10, luck: 15}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 95, surnameIndex: 5}),
            level: 10,
            currentXP: 0,
            weaponSpecialization: 9,
            armorSpecialization: 1
        });
    }

    function createDefaultCharacter(
        DefaultPlayerSkinNFT defaultSkin,
        IDefaultPlayer defaultPlayer,
        uint32 skinIndex,
        uint16 tokenId,
        CharacterType characterType
    ) internal returns (uint16) {
        // Get character data based on type
        (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid) =
            _getCharacterData(characterType, skinIndex, tokenId);

        // Create the default player with level-specific stats
        defaultPlayer.createDefaultPlayer(tokenId, stats);
        // Then mint the skin
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, ipfsCid, tokenId);

        return tokenId;
    }

    function _getCharacterData(CharacterType charType, uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats[10] memory stats, string memory ipfsCid)
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
        } else if (charType == CharacterType.DaggersUser) {
            return getDaggersUser(skinIndex, tokenId);
        } else if (charType == CharacterType.ScimitarAndBucklerUser) {
            return getScimitarAndBucklerUser(skinIndex, tokenId);
        } else if (charType == CharacterType.DualClubsWarrior) {
            return getDualClubsWarrior(skinIndex, tokenId);
        } else if (charType == CharacterType.AxeKitePlateBalancedWarrior) {
            return getAxeKitePlateBalancedWarrior(skinIndex, tokenId);
        } else if (charType == CharacterType.DualScimitarsWarrior) {
            return getDualScimitarsWarrior(skinIndex, tokenId);
        } else if (charType == CharacterType.ShortswordTowerdWarrior) {
            return getShortswordTowerdWarrior(skinIndex, tokenId);
        } else if (charType == CharacterType.VanguardWarrior) {
            return getVanguardWarrior(skinIndex, tokenId);
        } else if (charType == CharacterType.MageWarrior) {
            return getMageWarrior(skinIndex, tokenId);
        } else if (charType == CharacterType.ValkyrieWarrior) {
            return getValkyrieWarrior(skinIndex, tokenId);
        } else if (charType == CharacterType.LowStaminaClubsWarrior) {
            return getLowStaminaClubsWarrior(skinIndex, tokenId);
        } else if (charType == CharacterType.AltDaggersUser) {
            return getAltDaggersUser(skinIndex, tokenId);
        }
    }

    function createAllDefaultCharacters(
        DefaultPlayerSkinNFT defaultSkin,
        IDefaultPlayer defaultPlayer,
        uint32 defaultSkinIndex
    ) internal {
        for (uint16 i = 1; i <= 18; i++) {
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

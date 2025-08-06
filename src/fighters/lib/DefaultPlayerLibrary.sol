// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
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
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 5; // WEAPON_QUARTERSTAFF
        armor = 0; // ARMOR_CLOTH
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 12, size: 12, agility: 12, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 0, surnameIndex: 155}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreifbjayatwb3chcfacso3cligrob3l3ykliyqev4j4cmzgpls2saeq";
    }

    function getBalancedWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 0; // WEAPON_SWORD_AND_SHIELD
        armor = 2; // ARMOR_CHAIN
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 12, size: 12, agility: 12, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1015, surnameIndex: 97}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreiekllubajc7auisldffitig2j4afrc4hbedyjtqtdv7vbhgcqcmy4";
    }

    function getGreatswordUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 3; // WEAPON_GREATSWORD
        armor = 1; // ARMOR_LEATHER
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 18, constitution: 10, size: 14, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1062, surnameIndex: 131}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreid5npakg2yxd3542voibvlwtikgg4ai3eecu2jl4qdwmidsvpzsnu";
    }

    function getBattleaxeUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 4; // WEAPON_BATTLEAXE
        armor = 1; // ARMOR_LEATHER
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 12, size: 14, agility: 10, stamina: 10, luck: 10}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1102, surnameIndex: 241}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreifoy2xwhckb53zawn7hzvxprcchw7m3iu66mwldxo3gi2ttryjfma";
    }

    function getSpearUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 6; // WEAPON_SPEAR
        armor = 1; // ARMOR_LEATHER
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 8, size: 12, agility: 16, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1146, surnameIndex: 25}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreidcehmxbkeoym6dz6zwtw35nf5uswoonycqtdn57vha35qkuengfe";
    }

    function getRapierAndShieldUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 2; // WEAPON_RAPIER_AND_SHIELD
        armor = 1; // ARMOR_LEATHER
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 10, constitution: 12, size: 8, agility: 16, stamina: 12, luck: 14}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 38, surnameIndex: 15}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreiajp62udpay6ffa6q5s3hxthkiherqrl6alx4jpoeviqhenkmtbfa";
    }

    function getMaceAndShieldUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 1; // WEAPON_MACE_AND_SHIELD
        armor = 3; // ARMOR_PLATE
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 19, size: 14, agility: 6, stamina: 15, luck: 6}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1079, surnameIndex: 165}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreib5umhjzlug3a4mxabqbsdgo4q5xwpubixjyhvcv36gjhty5sadwu";
    }

    function getDaggersUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 9; // WEAPON_DUAL_DAGGERS
        armor = 1; // ARMOR_LEATHER
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 14, constitution: 6, size: 10, agility: 16, stamina: 10, luck: 16}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1043, surnameIndex: 158}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreichxvcymgfql6t2qrbiyjlerxcrei7kriqv4abc7d2f5xjbi54zpy";
    }

    function getScimitarAndBucklerUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 11; // WEAPON_SCIMITAR_BUCKLER
        armor = 0; // ARMOR_CLOTH
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 14, size: 8, agility: 14, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1139, surnameIndex: 216}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreihmbsfcov2jy7vlebsh5jg7i7k7pnzgcdthnd55drts7ode2wjm3y";
    }

    function getDualClubsWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 18; // WEAPON_DUAL_CLUBS
        armor = 1; // ARMOR_LEATHER
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 8, size: 16, agility: 8, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1071, surnameIndex: 37}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreid5ufeacbogoagtcfba2367nmnpjyxa5czu36btghg7d3af34vtnu";
    }

    function getAxeKitePlateBalancedWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 12; // WEAPON_AXE_KITE
        armor = 3; // ARMOR_PLATE
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 18, size: 12, agility: 8, stamina: 14, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 1145, surnameIndex: 4}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreicyyzq5tv4akfqblvixftzct5mifs4ymg7l56koy52zomnhxkosky";
    }

    function getDualScimitarsWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 14; // WEAPON_DUAL_SCIMITARS
        armor = 0; // ARMOR_CLOTH
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 16, constitution: 4, size: 12, agility: 16, stamina: 12, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 1084, surnameIndex: 242}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreif2wab4gyi45koar4mzitvryg3npik4s4dxwka73zvyfrqpp3g5iu";
    }

    function getShortswordTowerdWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 8; // WEAPON_SHORTSWORD_TOWER
        armor = 3; // ARMOR_PLATE
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 20, size: 12, agility: 8, stamina: 12, luck: 8}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1031, surnameIndex: 104}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreibrfl56qwfyrfuaxto7jgnhe73b4qxcsenjkt27zs3fdjo7yrmf3m";
    }

    function getVanguardWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 3; // WEAPON_GREATSWORD
        armor = 2; // ARMOR_CHAIN
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 19, constitution: 19, size: 12, agility: 5, stamina: 12, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1078, surnameIndex: 139}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreihm7xfvb35obizx5bypcpsom3pnqg4jakgnootb7c4r4bkafi4u4a";
    }

    function getMageWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 5; // WEAPON_QUARTERSTAFF
        armor = 1; // ARMOR_LEATHER
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 12, size: 12, agility: 12, stamina: 19, luck: 5}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 0,
            name: IPlayer.PlayerName({firstNameIndex: 1135, surnameIndex: 198}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreihndxzbu7vyxb4jnzrdlyhvmjzxivvbtnkbaq7fn6ejfuvmjwenxa";
    }

    function getValkyrieWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 0; // WEAPON_ARMING_SWORD_KITE
        armor = 3; // ARMOR_PLATE
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 14, size: 11, agility: 9, stamina: 17, luck: 9}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 10, surnameIndex: 188}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreibzvmc7skc5v7lsghi6ug5vehttoxcqpsi7nraewkr6z72pcjhfwy";
    }

    function getLowStaminaClubsWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 18; // WEAPON_DUAL_CLUBS
        armor = 0; // ARMOR_CLOTH
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 19, constitution: 5, size: 19, agility: 12, stamina: 5, luck: 12}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 1,
            name: IPlayer.PlayerName({firstNameIndex: 83, surnameIndex: 232}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreiaio3mlfiqnoshu35qgpnmid2c24wwmivi2h3tbb67yvguo66btky";
    }

    function getAltDaggersUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
    {
        weapon = 9; // WEAPON_DUAL_DAGGERS
        armor = 1; // ARMOR_LEATHER
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({strength: 12, constitution: 7, size: 12, agility: 17, stamina: 9, luck: 15}),
            skin: Fighter.SkinInfo({skinIndex: skinIndex, skinTokenId: tokenId}),
            stance: 2,
            name: IPlayer.PlayerName({firstNameIndex: 95, surnameIndex: 5}),
            level: 1,
            currentXP: 0,
            weaponSpecialization: 255,
            armorSpecialization: 255
        });
        ipfsCid = "bafkreieh2vw6eobqqawgujacaq7z6oc5gzqptczxa3ko42rlewahtyoxpe";
    }

    function createDefaultCharacter(
        DefaultPlayerSkinNFT defaultSkin,
        IDefaultPlayer defaultPlayer,
        uint32 skinIndex,
        uint16 tokenId,
        CharacterType characterType
    ) internal returns (uint16) {
        // Get character data based on type
        (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid) =
            _getCharacterData(characterType, skinIndex, tokenId);

        // Create the default player first
        defaultPlayer.createDefaultPlayer(tokenId, stats);
        // Then mint the skin
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, ipfsCid, tokenId);

        return tokenId;
    }

    function _getCharacterData(CharacterType charType, uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (uint8 weapon, uint8 armor, IPlayer.PlayerStats memory stats, string memory ipfsCid)
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

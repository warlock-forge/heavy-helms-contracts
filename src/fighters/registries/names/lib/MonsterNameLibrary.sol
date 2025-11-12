// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

//==============================================================//
//                         HEAVY HELMS                          //
//                     MONSTER NAME LIBRARY                     //
//==============================================================//
/// @title MonsterNameLibrary
/// @notice Library containing monster names organized by creature types
/// @dev Provides pre-defined monster names for goblins, undead, and demons

library MonsterNameLibrary {
    //==============================================================//
    //                         GOBLINS                             //
    //==============================================================//

    function getGoblinNames() internal pure returns (string[] memory) {
        string[] memory names = new string[](30);
        names[0] = "Grak Skullsplitter";
        names[1] = "Murg the Rotten";
        names[2] = "Brokk Ironhide";
        names[3] = "Grizzak Bonegnawer";
        names[4] = "Throk the Mangler";
        names[5] = "Razgut Fleshripper";
        names[6] = "Ugluk Warborn";
        names[7] = "Skarr Bloodfang";
        names[8] = "Gornak the Foul";
        names[9] = "Drog Gutslasher";
        names[10] = "Varg the Brutal";
        names[11] = "Grishnak Skullcrusher";
        names[12] = "Rakk Ironfist";
        names[13] = "Mugrak the Vile";
        names[14] = "Thargul Bonecleaver";
        names[15] = "Snagga Ragehowl";
        names[16] = "Grokk Steelgrin";
        names[17] = "Durz the Savage";
        names[18] = "Urgat Painbringer";
        names[19] = "Nazgrak Warfang";
        names[20] = "Kraggor Fleshrender";
        names[21] = "Thrusk the Merciless";
        names[22] = "Brugol Ironjaw";
        names[23] = "Garbuk Skullbreaker";
        names[24] = "Vorak the Cruel";
        names[25] = "Snarlak Doomfist";
        names[26] = "Zugor Bonegnasher";
        names[27] = "Grimgor the Fierce";
        names[28] = "Morgash Steeltooth";
        names[29] = "Grubnash Warbringer";
        return names;
    }

    //==============================================================//
    //                          UNDEAD                             //
    //==============================================================//

    function getUndeadNames() internal pure returns (string[] memory) {
        string[] memory names = new string[](30);
        names[0] = "Morticus the Risen";
        names[1] = "Grimwald Bonecaller";
        names[2] = "Velkor Deathrattle";
        names[3] = "Thane Cryptborn";
        names[4] = "Malachar the Withered";
        names[5] = "Nervok the Lifeless";
        names[6] = "Corvus Gravewhisper";
        names[7] = "Draven Soulreaper";
        names[8] = "Osric the Decayed";
        names[9] = "Necros the Eternal";
        names[10] = "Valthus Doomwalker";
        names[11] = "Kravix Ashenblade";
        names[12] = "Mordrin Deathshroud";
        names[13] = "Lazarus Fleshless";
        names[14] = "Golgoth the Hollow";
        names[15] = "Vexrus Tombwarden";
        names[16] = "Carrion the Cursed";
        names[17] = "Balthazar Bonewraith";
        names[18] = "Theron Palegrasp";
        names[19] = "Morwen the Soulless";
        names[20] = "Dredge Cryptkeeper";
        names[21] = "Valthar Darkmarrow";
        names[22] = "Skellis the Ancient";
        names[23] = "Grendok Deathchill";
        names[24] = "Morthos Gravewarden";
        names[25] = "Nihilus the Empty";
        names[26] = "Vladris Soulbound";
        names[27] = "Thresh the Undying";
        names[28] = "Kaelthor Tombclaw";
        names[29] = "Revrus the Rotted";
        return names;
    }

    //==============================================================//
    //                          DEMONS                             //
    //==============================================================//

    function getDemonNames() internal pure returns (string[] memory) {
        string[] memory names = new string[](30);
        names[0] = "Azgaroth the Tormentor";
        names[1] = "Vex'thul Flameheart";
        names[2] = "Malphas the Defiler";
        names[3] = "Korgath Hellspawn";
        names[4] = "Zar'koth Doomwing";
        names[5] = "Belzarak the Voidborn";
        names[6] = "Xul'gothar Painbringer";
        names[7] = "Vraxxus Darkflame";
        names[8] = "Nul'tharok the Abyssal";
        names[9] = "Gorathrax Soulshredder";
        names[10] = "Zyx'thul the Corrupted";
        names[11] = "Mal'krathos Hellbound";
        names[12] = "Vel'zarak Dreadlord";
        names[13] = "Thul'goroth Vileheart";
        names[14] = "Kaz'thuul the Wretched";
        names[15] = "Drak'xul Netherbane";
        names[16] = "Vor'malgoth Terrorwing";
        names[17] = "Zyth'rakul Flamescourge";
        names[18] = "Gul'kathor Bloodreaver";
        names[19] = "Nex'varus the Malevolent";
        names[20] = "Krath'ul Voidcaller";
        names[21] = "Zal'gorath Nightbringer";
        names[22] = "Vel'thurak Chaosblade";
        names[23] = "Mog'xarath Doomflayer";
        names[24] = "Xar'kothul Shadowfiend";
        names[25] = "Drex'varus the Burning";
        names[26] = "Thul'mazok Hellwrath";
        names[27] = "Goth'zuul Abysswalker";
        names[28] = "Rak'vel Soulsunder";
        names[29] = "Kul'zathar the Damned";
        return names;
    }
}

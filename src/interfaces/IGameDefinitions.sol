// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IGameDefinitions {
    enum WeaponType {
        SwordAndShield,
        MaceAndShield,
        RapierAndShield,
        Greatsword,
        Battleaxe,
        Quarterstaff,
        Spear
    }

    enum ArmorType {
        Cloth,
        Leather,
        Chain,
        Plate
    }

    enum FightingStance {
        Defensive,
        Balanced,
        Offensive
    }
}

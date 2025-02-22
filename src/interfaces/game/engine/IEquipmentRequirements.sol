// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Fighter.sol";

interface IEquipmentRequirements {
    function getWeaponRequirements(uint8 weapon) external pure returns (Fighter.Attributes memory);
    function getArmorRequirements(uint8 armor) external pure returns (Fighter.Attributes memory);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Player} from "../../../src/fighters/Player.sol";
import {IPlayer} from "../../../src/interfaces/fighters/IPlayer.sol";
import {Fighter} from "../../../src/fighters/Fighter.sol";

/// @notice Handler for Player contract invariant testing.
/// @dev Exercises retirement, leveling, attribute spending, attribute swaps,
///      and specialization -- the operations that modify critical state.
contract PlayerHandler is Test {
    Player public playerContract;

    // Pool of valid player IDs and their owners
    uint32[] public playerIds;
    mapping(uint32 => address) public playerOwners;

    // Ghost variables
    uint256 public ghost_totalRetired;
    uint256 public ghost_totalAttributePointsUsed;

    // Call counters
    uint256 public calls_retire;
    uint256 public calls_awardXP;
    uint256 public calls_useAttributePoint;
    uint256 public calls_swapAttributes;
    uint256 public calls_setWeaponSpec;
    uint256 public calls_setArmorSpec;

    constructor(Player _playerContract, uint32[] memory _playerIds, address[] memory _owners) {
        playerContract = _playerContract;

        for (uint256 i = 0; i < _playerIds.length; i++) {
            playerIds.push(_playerIds[i]);
            playerOwners[_playerIds[i]] = _owners[i];
        }
    }

    // --- Handler Actions ---

    /// @notice Retire a random player
    function retirePlayer(uint256 playerSeed) external {
        if (playerIds.length == 0) return;
        uint32 playerId = playerIds[playerSeed % playerIds.length];
        address owner = playerOwners[playerId];

        if (playerContract.isPlayerRetired(playerId)) return;

        vm.prank(owner);
        try playerContract.retireOwnPlayer(playerId) {
            ghost_totalRetired++;
            calls_retire++;
        } catch {}
    }

    /// @notice Award XP to a random player to trigger level-ups
    function awardXP(uint256 playerSeed, uint16 xpAmount) external {
        if (playerIds.length == 0) return;
        uint32 playerId = playerIds[playerSeed % playerIds.length];

        if (playerContract.isPlayerRetired(playerId)) return;
        xpAmount = uint16(bound(xpAmount, 1, 500)); // High enough to trigger level-ups

        try playerContract.awardExperience(playerId, xpAmount) {
            calls_awardXP++;
        } catch {}
    }

    /// @notice Spend an attribute point on a random attribute
    function useAttributePoint(uint256 playerSeed, uint256 attributeSeed) external {
        if (playerIds.length == 0) return;
        uint32 playerId = playerIds[playerSeed % playerIds.length];
        address owner = playerOwners[playerId];

        if (playerContract.isPlayerRetired(playerId)) return;

        // Check if player has points to spend
        uint256 points = playerContract.attributePoints(playerId);
        if (points == 0) return;

        // Pick random attribute (0-5: STR, CON, SIZE, AGI, STA, LUCK)
        IPlayer.Attribute attr = IPlayer.Attribute(attributeSeed % 6);

        vm.prank(owner);
        try playerContract.useAttributePoint(playerId, attr) {
            ghost_totalAttributePointsUsed++;
            calls_useAttributePoint++;
        } catch {}
    }

    /// @notice Swap two attributes (requires burning a ticket, so we mint one first)
    function swapAttributes(uint256 playerSeed, uint256 decreaseSeed, uint256 increaseSeed) external {
        if (playerIds.length == 0) return;
        uint32 playerId = playerIds[playerSeed % playerIds.length];
        address owner = playerOwners[playerId];

        if (playerContract.isPlayerRetired(playerId)) return;

        IPlayer.Attribute decreaseAttr = IPlayer.Attribute(decreaseSeed % 6);
        IPlayer.Attribute increaseAttr = IPlayer.Attribute(increaseSeed % 6);
        if (decreaseAttr == increaseAttr) return;

        // Check the decrease attribute has room (must be > 3 after decrease)
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        uint8 decreaseVal = _getAttributeValue(stats.attributes, decreaseAttr);
        if (decreaseVal <= 3) return;

        // Check increase attribute has room (must be < 25)
        uint8 increaseVal = _getAttributeValue(stats.attributes, increaseAttr);
        if (increaseVal >= 25) return;

        // Mint an attribute swap ticket to the owner
        // (handler has permission via test setup)
        vm.prank(owner);
        try playerContract.swapAttributes(playerId, decreaseAttr, increaseAttr) {
            calls_swapAttributes++;
        } catch {}
    }

    /// @notice Set weapon specialization
    function setWeaponSpec(uint256 playerSeed, uint8 weaponClass) external {
        if (playerIds.length == 0) return;
        uint32 playerId = playerIds[playerSeed % playerIds.length];
        address owner = playerOwners[playerId];

        if (playerContract.isPlayerRetired(playerId)) return;
        weaponClass = uint8(bound(weaponClass, 0, 6));

        vm.prank(owner);
        try playerContract.setWeaponSpecialization(playerId, weaponClass) {
            calls_setWeaponSpec++;
        } catch {}
    }

    /// @notice Set armor specialization
    function setArmorSpec(uint256 playerSeed, uint8 armorType) external {
        if (playerIds.length == 0) return;
        uint32 playerId = playerIds[playerSeed % playerIds.length];
        address owner = playerOwners[playerId];

        if (playerContract.isPlayerRetired(playerId)) return;
        armorType = uint8(bound(armorType, 0, 3));

        vm.prank(owner);
        try playerContract.setArmorSpecialization(playerId, armorType) {
            calls_setArmorSpec++;
        } catch {}
    }

    // --- Internal helpers ---

    function _getAttributeValue(Fighter.Attributes memory attrs, IPlayer.Attribute attr) internal pure returns (uint8) {
        if (attr == IPlayer.Attribute.STRENGTH) return attrs.strength;
        if (attr == IPlayer.Attribute.CONSTITUTION) return attrs.constitution;
        if (attr == IPlayer.Attribute.SIZE) return attrs.size;
        if (attr == IPlayer.Attribute.AGILITY) return attrs.agility;
        if (attr == IPlayer.Attribute.STAMINA) return attrs.stamina;
        return attrs.luck;
    }

    // --- View helpers ---

    function getPlayerIdsLength() external view returns (uint256) {
        return playerIds.length;
    }

    function getPlayerId(uint256 index) external view returns (uint32) {
        return playerIds[index];
    }
}

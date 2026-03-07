// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {Player} from "../../src/fighters/Player.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";
import {PlayerHandler} from "./handlers/PlayerHandler.sol";

contract PlayerInvariantTest is TestBase {
    PlayerHandler public handler;

    uint32[] public pIds;
    address[] public pOwners;

    // 3 owners with 3 players each = 9 players
    // Tests multi-player accounting per owner
    uint256 constant NUM_OWNERS = 3;
    uint256 constant PLAYERS_PER_OWNER = 3;

    function setUp() public override {
        super.setUp();

        // Grant handler game permissions for XP
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, immortal: false, experience: true});

        // Create players: multiple per owner to test activePlayerCount accounting
        for (uint256 i = 0; i < NUM_OWNERS; i++) {
            address owner = address(uint160(0x3001 + i));
            vm.deal(owner, 100 ether);
            for (uint256 j = 0; j < PLAYERS_PER_OWNER; j++) {
                uint32 playerId = _createPlayerAndFulfillVRF(owner, false);
                pIds.push(playerId);
                pOwners.push(owner);
            }
        }

        // Deploy handler
        handler = new PlayerHandler(playerContract, pIds, pOwners);

        // Grant handler game permissions
        playerContract.setGameContractPermission(address(handler), perms);

        // Mint attribute swap tickets to all owners so swapAttributes can work
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: false,
            attributeSwaps: true
        });
        playerTickets.setGameContractPermission(address(this), ticketPerms);
        for (uint256 i = 0; i < NUM_OWNERS; i++) {
            address owner = address(uint160(0x3001 + i));
            playerTickets.mintFungibleTicket(owner, playerTickets.ATTRIBUTE_SWAP_TICKET(), 50);
            // Approve playerContract to burn tickets
            vm.prank(owner);
            playerTickets.setApprovalForAll(address(playerContract), true);
        }

        targetContract(address(handler));
    }

    //==============================================================//
    //                         INVARIANTS                           //
    //==============================================================//

    /// @notice activePlayerCount for each owner must match non-retired player count.
    /// This is the most important Player invariant -- if retire() has a bug in the
    /// decrement logic, this catches it across multiple players per owner.
    function invariant_ActiveCountMatchesNonRetired() public view {
        for (uint256 ownerIdx = 0; ownerIdx < NUM_OWNERS; ownerIdx++) {
            address owner = address(uint160(0x3001 + ownerIdx));

            uint256 expectedCount = 0;
            for (uint256 j = 0; j < handler.getPlayerIdsLength(); j++) {
                uint32 pid = handler.getPlayerId(j);
                if (handler.playerOwners(pid) == owner && !playerContract.isPlayerRetired(pid)) {
                    expectedCount++;
                }
            }

            assertEq(playerContract.getActivePlayerCount(owner), expectedCount, "activePlayerCount mismatch for owner");
        }
    }

    /// @notice All 6 attributes must stay within [3, 25] after any combination of
    /// useAttributePoint + swapAttributes operations. This is the invariant that
    /// would catch an underflow/overflow in attribute modification.
    function invariant_AttributeRanges() public view {
        for (uint256 i = 0; i < handler.getPlayerIdsLength(); i++) {
            uint32 pid = handler.getPlayerId(i);
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(pid);

            assertGe(stats.attributes.strength, 3, "STR below 3");
            assertLe(stats.attributes.strength, 25, "STR above 25");
            assertGe(stats.attributes.constitution, 3, "CON below 3");
            assertLe(stats.attributes.constitution, 25, "CON above 25");
            assertGe(stats.attributes.size, 3, "SIZE below 3");
            assertLe(stats.attributes.size, 25, "SIZE above 25");
            assertGe(stats.attributes.agility, 3, "AGI below 3");
            assertLe(stats.attributes.agility, 25, "AGI above 25");
            assertGe(stats.attributes.stamina, 3, "STA below 3");
            assertLe(stats.attributes.stamina, 25, "STA above 25");
            assertGe(stats.attributes.luck, 3, "LUCK below 3");
            assertLe(stats.attributes.luck, 25, "LUCK above 25");
        }
    }

    /// @notice Attribute sum must equal base sum (72) + attribute points spent.
    /// swapAttributes is zero-sum, so only useAttributePoint increases the total.
    function invariant_AttributeSumConsistent() public view {
        for (uint256 i = 0; i < handler.getPlayerIdsLength(); i++) {
            uint32 pid = handler.getPlayerId(i);
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(pid);

            uint256 sum = uint256(stats.attributes.strength) + uint256(stats.attributes.constitution)
                + uint256(stats.attributes.size) + uint256(stats.attributes.agility) + uint256(stats.attributes.stamina)
                + uint256(stats.attributes.luck);

            // Points spent = levels gained (each level-up gives 1 point) - remaining unspent points
            uint256 levelsGained = uint256(stats.level) - 1;
            uint256 unspent = playerContract.attributePoints(pid);
            uint256 pointsSpent = levelsGained - unspent;

            assertEq(sum, 72 + pointsSpent, "Attribute sum inconsistent with points spent");
        }
    }

    /// @notice Unspent attribute points must never exceed levels gained.
    /// Each level-up grants exactly 1 point.
    function invariant_AttributePointsCapped() public view {
        for (uint256 i = 0; i < handler.getPlayerIdsLength(); i++) {
            uint32 pid = handler.getPlayerId(i);
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(pid);
            uint256 levelsGained = uint256(stats.level) - 1;
            uint256 unspent = playerContract.attributePoints(pid);
            assertLe(unspent, levelsGained, "More attribute points than levels gained");
        }
    }

    /// @notice Call summary for debugging
    function invariant_callSummary() public view {
        handler.calls_retire();
        handler.calls_awardXP();
        handler.calls_useAttributePoint();
        handler.calls_swapAttributes();
        handler.calls_setWeaponSpec();
        handler.calls_setArmorSpec();
    }
}

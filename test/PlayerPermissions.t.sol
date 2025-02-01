// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Player, NoPermission, InvalidPlayerStats} from "../src/Player.sol";
import {IPlayer} from "../src/interfaces/IPlayer.sol";
import {PlayerSkinRegistry} from "../src/PlayerSkinRegistry.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";
import "./utils/TestBase.sol";

contract PlayerPermissionsTest is TestBase {
    address public gameContract;
    address public gameContract2;
    uint32 public playerId;

    function setUp() public override {
        super.setUp();

        // Setup game contract address
        gameContract = address(0xdead);

        // Create a test player using VRF
        playerId = uint32(_createPlayerAndFulfillVRF(address(1), playerContract, false));
    }

    function test_PermissionChecks() public {
        // Try operations without permissions (should fail)
        vm.startPrank(gameContract);

        vm.expectRevert(NoPermission.selector);
        Player(playerContract).incrementWins(playerId);

        vm.expectRevert(NoPermission.selector);
        Player(playerContract).setPlayerRetired(playerId, true);

        vm.expectRevert(NoPermission.selector);
        Player(playerContract).awardNameChange(address(1));

        vm.expectRevert(NoPermission.selector);
        Player(playerContract).awardAttributeSwap(address(1));

        vm.stopPrank();
    }

    function test_RecordPermission() public {
        // Grant only RECORD permission
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, name: false, attributes: false, immortal: false});
        Player(playerContract).setGameContractPermission(gameContract, perms);

        vm.startPrank(gameContract);

        // These should succeed
        Player(playerContract).incrementWins(playerId);
        Player(playerContract).incrementLosses(playerId);
        Player(playerContract).incrementKills(playerId);

        // Other operations should still fail
        vm.expectRevert(NoPermission.selector);
        Player(playerContract).setPlayerRetired(playerId, true);

        vm.stopPrank();
    }

    function test_AttributePermission() public {
        // Grant only ATTRIBUTES permission
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: false, retire: false, name: false, attributes: true, immortal: false});
        Player(playerContract).setGameContractPermission(gameContract, perms);

        vm.startPrank(gameContract);

        // Should succeed
        Player(playerContract).awardAttributeSwap(address(1));

        // Other operations should fail
        vm.expectRevert(NoPermission.selector);
        Player(playerContract).incrementWins(playerId);

        vm.stopPrank();

        // Test attribute swap with awarded charge
        vm.startPrank(address(1));
        Player(playerContract).swapAttributes(playerId, IPlayer.Attribute.STRENGTH, IPlayer.Attribute.AGILITY);
        vm.stopPrank();
    }

    function test_NamePermission() public {
        // Grant only NAME permission
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: false, retire: false, name: true, attributes: false, immortal: false});
        Player(playerContract).setGameContractPermission(gameContract, perms);

        vm.startPrank(gameContract);

        // Should succeed
        Player(playerContract).awardNameChange(address(1));

        // Other operations should fail
        vm.expectRevert(NoPermission.selector);
        Player(playerContract).incrementWins(playerId);

        vm.stopPrank();

        // Verify name change works with awarded charge
        vm.startPrank(address(1));
        Player(playerContract).changeName(playerId, 1, 1);
        vm.stopPrank();
    }

    function test_RetirePermission() public {
        // Grant only RETIRE permission
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: false, retire: true, name: false, attributes: false, immortal: false});
        Player(playerContract).setGameContractPermission(gameContract, perms);

        vm.startPrank(gameContract);

        // Should succeed
        Player(playerContract).setPlayerRetired(playerId, true);
        assertTrue(Player(playerContract).isPlayerRetired(playerId));

        // Should be able to un-retire
        Player(playerContract).setPlayerRetired(playerId, false);
        assertFalse(Player(playerContract).isPlayerRetired(playerId));

        // Other operations should fail
        vm.expectRevert(NoPermission.selector);
        Player(playerContract).incrementWins(playerId);

        vm.stopPrank();
    }
}

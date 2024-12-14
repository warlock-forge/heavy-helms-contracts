// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Player} from "../src/Player.sol";
import {IPlayer} from "../src/interfaces/IPlayer.sol";
import {PlayerSkinRegistry} from "../src/PlayerSkinRegistry.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";
import {PlayerEquipmentStats} from "../src/PlayerEquipmentStats.sol";
import "./utils/TestBase.sol";

contract PlayerPermissionsTest is TestBase {
    Player public playerContract;
    PlayerNameRegistry public nameRegistry;
    PlayerEquipmentStats public equipmentStats;
    address public gameContract;
    uint32 public playerId;

    function setUp() public override {
        super.setUp();

        // Setup game contract address
        gameContract = address(0xdead);

        // Set up the test environment with a proper timestamp
        vm.warp(1692803367 + 1000); // Set timestamp to after genesis

        // Deploy contracts in correct order
        nameRegistry = new PlayerNameRegistry();
        equipmentStats = new PlayerEquipmentStats();

        // Deploy Player contract with dependencies
        playerContract = new Player(address(skinRegistry), address(nameRegistry), address(equipmentStats), operator);

        // Create a test player using VRF
        playerId = uint32(_createPlayerAndFulfillVRF(address(1), playerContract, false));
    }

    function test_PermissionChecks() public {
        // Try operations without permissions (should fail)
        vm.startPrank(gameContract);
        
        vm.expectRevert("Missing required permission");
        playerContract.incrementWins(playerId);
        
        vm.expectRevert("Missing required permission");
        playerContract.setPlayerRetired(playerId, true);
        
        vm.expectRevert("Missing required permission");
        playerContract.setPlayerName(playerId, 1, 1);
        
        vm.expectRevert("Missing required permission");
        playerContract.setPlayerAttributes(playerId, 10, 10, 10, 10, 10, 10);
        
        vm.stopPrank();
    }

    function test_RecordPermission() public {
        // Grant only RECORD permission
        IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
            record: true,
            retire: false,
            name: false,
            attributes: false
        });
        playerContract.setGameContractPermission(gameContract, perms);

        vm.startPrank(gameContract);
        
        // These should succeed
        playerContract.incrementWins(playerId);
        playerContract.incrementLosses(playerId);
        playerContract.incrementKills(playerId);
        
        // Other operations should still fail
        vm.expectRevert("Missing required permission");
        playerContract.setPlayerRetired(playerId, true);
        
        vm.stopPrank();
    }

    function test_AttributePermission() public {
        // Grant only ATTRIBUTES permission
        IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
            record: false,
            retire: false,
            name: false,
            attributes: true
        });
        playerContract.setGameContractPermission(gameContract, perms);

        vm.startPrank(gameContract);
        
        // Should succeed with valid stats (sum = 72)
        playerContract.setPlayerAttributes(playerId, 12, 12, 12, 12, 12, 12);
        
        // Should fail with invalid total
        vm.expectRevert("Invalid player stats");
        playerContract.setPlayerAttributes(playerId, 5, 5, 5, 5, 5, 5);
        
        vm.stopPrank();
    }

    function test_NamePermission() public {
        // Grant only NAME permission
        IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
            record: false,
            retire: false,
            name: true,
            attributes: false
        });
        playerContract.setGameContractPermission(gameContract, perms);

        vm.startPrank(gameContract);
        
        // Should succeed
        playerContract.setPlayerName(playerId, 1, 1);
        
        // Other operations should fail
        vm.expectRevert("Missing required permission");
        playerContract.incrementWins(playerId);
        
        vm.stopPrank();
    }

    function test_RetirePermission() public {
        // Grant only RETIRE permission
        IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
            record: false,
            retire: true,
            name: false,
            attributes: false
        });
        playerContract.setGameContractPermission(gameContract, perms);

        vm.startPrank(gameContract);
        
        // Should succeed
        playerContract.setPlayerRetired(playerId, true);
        assertTrue(playerContract.isPlayerRetired(playerId));
        
        // Should be able to un-retire
        playerContract.setPlayerRetired(playerId, false);
        assertFalse(playerContract.isPlayerRetired(playerId));
        
        // Other operations should fail
        vm.expectRevert("Missing required permission");
        playerContract.incrementWins(playerId);
        
        vm.stopPrank();
    }
}

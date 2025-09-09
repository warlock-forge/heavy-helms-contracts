// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Player, NoPermission} from "../../src/fighters/Player.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {TestBase} from "../TestBase.sol";

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

        uint256 currentSeason = playerContract.currentSeason();
        vm.expectRevert(NoPermission.selector);
        Player(playerContract).incrementWins(playerId, currentSeason);

        vm.expectRevert(NoPermission.selector);
        Player(playerContract).setPlayerRetired(playerId, true);

        // NAME permission no longer exists in Player contract
        // (name changes are now handled through PlayerTickets)

        // awardAttributeSwap function no longer exists - attribute swaps are now handled via PlayerTickets NFTs
        // This test is no longer applicable since we removed the awardAttributeSwap function

        vm.stopPrank();
    }

    function test_RecordPermission() public {
        // Grant only RECORD permission
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, immortal: false, experience: false});
        Player(playerContract).setGameContractPermission(gameContract, perms);

        vm.startPrank(gameContract);

        // These should succeed
        uint256 currentSeason = playerContract.currentSeason();
        Player(playerContract).incrementWins(playerId, currentSeason);
        Player(playerContract).incrementLosses(playerId, currentSeason);
        Player(playerContract).incrementKills(playerId, currentSeason);

        // Other operations should still fail
        vm.expectRevert(NoPermission.selector);
        Player(playerContract).setPlayerRetired(playerId, true);

        vm.stopPrank();
    }

    function test_NamePermission() public {
        // Grant only NAME permission
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: false, retire: false, immortal: false, experience: false});
        Player(playerContract).setGameContractPermission(gameContract, perms);

        vm.startPrank(gameContract);

        // NOTE: NAME permission removed from Player contract
        // Names are now handled through PlayerTickets contract

        // Other operations should fail
        uint256 currentSeason = playerContract.currentSeason();
        vm.expectRevert(NoPermission.selector);
        Player(playerContract).incrementWins(playerId, currentSeason);

        vm.stopPrank();

        // NOTE: Name changes now require NFT tokens from PlayerTickets
        // This test would need to be updated to use the new system
    }

    function test_RetirePermission() public {
        // Grant only RETIRE permission
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: false, retire: true, immortal: false, experience: false});
        Player(playerContract).setGameContractPermission(gameContract, perms);

        vm.startPrank(gameContract);

        // Should succeed
        Player(playerContract).setPlayerRetired(playerId, true);
        assertTrue(Player(playerContract).isPlayerRetired(playerId));

        // Should be able to un-retire
        Player(playerContract).setPlayerRetired(playerId, false);
        assertFalse(Player(playerContract).isPlayerRetired(playerId));

        // Other operations should fail
        uint256 currentSeason = playerContract.currentSeason();
        vm.expectRevert(NoPermission.selector);
        Player(playerContract).incrementWins(playerId, currentSeason);

        vm.stopPrank();
    }
}

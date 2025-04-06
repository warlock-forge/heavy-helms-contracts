// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {DuelGame} from "../../src/game/modes/DuelGame.sol";
import {GameEngine} from "../../src/game/engine/GameEngine.sol";
import {Player} from "../../src/fighters/Player.sol";
import "../TestBase.sol";

contract GasAnalysisTest is TestBase {
    DuelGame public game;

    // Test addresses
    address public PLAYER_ONE;
    address public PLAYER_TWO;
    uint32 public PLAYER_ONE_ID;
    uint32 public PLAYER_TWO_ID;

    function setUp() public override {
        super.setUp();

        // Deploy contracts
        game = new DuelGame(address(gameEngine), address(playerContract), operator);

        // Set permissions
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, name: false, attributes: false, immortal: false});
        playerContract.setGameContractPermission(address(game), perms);

        // Setup test addresses and players
        PLAYER_ONE = address(0xdF);
        PLAYER_TWO = address(0xeF);
        PLAYER_ONE_ID = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        PLAYER_TWO_ID = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);

        vm.deal(PLAYER_ONE, 100 ether);
        vm.deal(PLAYER_TWO, 100 ether);
    }

    function testAverageDuelGasCost() public {
        uint256[] memory gasCosts = new uint256[](5);

        for (uint256 i = 0; i < 5; i++) {
            // Create and accept a challenge
            vm.startPrank(PLAYER_ONE);
            uint256 wagerAmount = 1 ether;
            uint256 challengeId = game.initiateChallenge{value: wagerAmount + game.minDuelFee()}(
                _createLoadout(PLAYER_ONE_ID), PLAYER_TWO_ID, wagerAmount
            );
            vm.stopPrank();

            vm.startPrank(PLAYER_TWO);
            vm.recordLogs();
            game.acceptChallenge{value: wagerAmount}(challengeId, _createLoadout(PLAYER_TWO_ID));

            // Get VRF data
            (uint256 roundId, bytes memory eventData) = _decodeVRFRequestEvent(vm.getRecordedLogs());
            bytes memory dataWithRound = _simulateVRFFulfillment(i, roundId); // Use i as different seed
            vm.stopPrank();

            // Measure gas for VRF fulfillment (actual duel execution)
            uint256 gasBefore = gasleft();
            vm.prank(operator);
            game.fulfillRandomness(i, dataWithRound);
            gasCosts[i] = gasBefore - gasleft();

            console2.log("Fight", i + 1, "gas used:", gasCosts[i]);
        }

        // Calculate average
        uint256 totalGas = 0;
        for (uint256 i = 0; i < gasCosts.length; i++) {
            totalGas += gasCosts[i];
        }
        uint256 averageGas = totalGas / gasCosts.length;

        console2.log("\nAverage gas used across", gasCosts.length, "fights:", averageGas);
    }
}

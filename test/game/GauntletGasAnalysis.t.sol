// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {GauntletGame} from "../../src/game/modes/GauntletGame.sol";
import {GameEngine} from "../../src/game/engine/GameEngine.sol";
import {Player} from "../../src/fighters/Player.sol";
import "../TestBase.sol";

contract GauntletGasAnalysisTest is TestBase {
    GauntletGame public game;

    function setUp() public override {
        super.setUp();

        // Deploy gauntlet game with operator
        game = new GauntletGame(address(gameEngine), address(playerContract), address(defaultPlayerContract), operator);

        // Set permissions
        IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
            record: true,
            retire: false,
            attributes: false,
            immortal: false,
            experience: false
        });
        playerContract.setGameContractPermission(address(game), perms);

        // Set minimum time between gauntlets to 0 for testing
        game.setMinTimeBetweenGauntlets(0);
    }

    function test8PlayerGauntletGas() public {
        _testGauntletSize(8);
    }

    function test16PlayerGauntletGas() public {
        _testGauntletSize(16);
    }

    function test32PlayerGauntletGas() public {
        _testGauntletSize(32);
    }

    function test64PlayerGauntletGas() public {
        _testGauntletSize(64);
    }

    function _testGauntletSize(uint8 size) internal {
        console2.log("=== TESTING", size, "PLAYER GAUNTLET ===");

        // Set gauntlet size
        game.setGameEnabled(false);
        game.setGauntletSize(size);
        game.setGameEnabled(true);

        // Create players and queue them
        address[] memory players = new address[](size);
        uint32[] memory playerIds = new uint32[](size);

        for (uint256 i = 0; i < size; i++) {
            players[i] = address(uint160(0x1000 + i));
            playerIds[i] = _createPlayerAndFulfillVRF(players[i], playerContract, false);

            // Queue player for gauntlet
            vm.startPrank(players[i]);
            game.queueForGauntlet(_createLoadout(playerIds[i]));
            vm.stopPrank();
        }

        console2.log("Players queued:", game.getQueueSize());

        // Start gauntlet (advance time to meet minimum requirement)
        vm.warp(block.timestamp + 6 minutes);

        // Start gauntlet and get VRF request info
        vm.recordLogs();
        game.tryStartGauntlet();
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Decode VRF request
        (uint256 roundId, bytes memory eventData) = _decodeVRFRequestEvent(entries);

        // Extract requestId from eventData (it's encoded as the first parameter)
        uint256 requestId = 0; // Using 0 as requestId should work with mock

        // Prepare VRF fulfillment data
        uint256 randomnessFromBlock = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, roundId)));
        bytes memory dataWithRound = _simulateVRFFulfillment(requestId, roundId);

        // Measure gas for VRF fulfillment (the expensive part - bracket execution)
        uint256 gasBefore = gasleft();
        vm.prank(operator);
        game.fulfillRandomness(randomnessFromBlock, dataWithRound);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for", size, "player gauntlet:", gasUsed);

        // Calculate theoretical limits
        uint256 fights = size - 1; // Total fights in elimination bracket
        uint256 gasPerFight = gasUsed / fights;
        console2.log("Average gas per fight:", gasPerFight);

        // Check if it would hit block gas limit (assuming 30M gas limit)
        uint256 blockGasLimit = 30_000_000;
        if (gasUsed > blockGasLimit) {
            console2.log("WARNING: EXCEEDS BLOCK GAS LIMIT!");
        } else {
            uint256 remaining = blockGasLimit - gasUsed;
            console2.log("OK Gas remaining:", remaining);
            console2.log("Percent remaining:", (remaining * 100) / blockGasLimit);
        }
    }

    function testShuffleGasConsumption() public {
        console2.log("\n=== SHUFFLE ALGORITHM GAS ANALYSIS ===");

        // Test the Fisher-Yates shuffle gas consumption separately
        uint8 size = 32;

        // Disable game to change size
        game.setGameEnabled(false);
        game.setGauntletSize(size);
        game.setGameEnabled(true);

        // Set minimum time to 0 for testing
        game.setMinTimeBetweenGauntlets(0);

        // Create and queue players
        for (uint256 i = 0; i < size; i++) {
            address player = address(uint160(0x2000 + i));
            uint32 playerId = _createPlayerAndFulfillVRF(player, playerContract, false);

            vm.startPrank(player);
            game.queueForGauntlet(_createLoadout(playerId));
            vm.stopPrank();
        }

        // Advance time to meet minimum requirement
        vm.warp(block.timestamp + 6 minutes);

        // Start gauntlet and measure just the shuffle portion
        uint256 gasBeforeShuffle = gasleft();
        game.tryStartGauntlet();
        uint256 gasAfterStart = gasleft();

        console2.log("Gas for tryStartGauntlet (includes selection + VRF request):", gasBeforeShuffle - gasAfterStart);
    }

    function testWorstCaseGauntletScenario() public {
        console2.log("\n=== WORST CASE SCENARIO ANALYSIS ===");

        // Test 32-player gauntlet with all retired players (forces default substitution)
        uint8 size = 32;

        game.setGameEnabled(false);
        game.setGauntletSize(size);
        game.setGameEnabled(true);

        // Set minimum time to 0 for testing
        game.setMinTimeBetweenGauntlets(0);

        // Create players, queue them, then retire them to force substitution
        for (uint256 i = 0; i < size; i++) {
            address player = address(uint160(0x3000 + i));
            uint32 playerId = _createPlayerAndFulfillVRF(player, playerContract, false);

            vm.startPrank(player);
            game.queueForGauntlet(_createLoadout(playerId));

            // Retire the player to force default substitution during VRF fulfillment
            playerContract.retireOwnPlayer(playerId);
            vm.stopPrank();
        }

        // Start gauntlet (advance time to meet minimum requirement)
        vm.warp(block.timestamp + 6 minutes);

        // Measure gas for worst-case setup
        uint256 gasBefore = gasleft();
        game.tryStartGauntlet();
        uint256 gasUsed = gasBefore - gasleft();

        // Estimate total including VRF fulfillment with retired player substitution
        uint256 fights = size - 1;
        uint256 estimatedCombatGas = fights * 120000; // Higher estimate for substitution overhead
        uint256 estimatedOverheadGas = fights * 80000; // Higher overhead for worst case
        uint256 totalEstimated = gasUsed + estimatedCombatGas + estimatedOverheadGas;

        console2.log("Worst-case setup gas:", gasUsed);
        console2.log("Worst-case total estimated:", totalEstimated);

        // Compare to block gas limit
        uint256 blockGasLimit = 30_000_000;
        if (totalEstimated > blockGasLimit) {
            console2.log("WARNING: WORST CASE EXCEEDS BLOCK GAS LIMIT!");
        } else {
            console2.log("OK Worst case still within limits, remaining:", blockGasLimit - totalEstimated);
        }
    }
}

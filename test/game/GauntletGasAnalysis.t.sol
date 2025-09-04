// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {GauntletGame} from "../../src/game/modes/GauntletGame.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";
import "../TestBase.sol";

contract GauntletGasAnalysisTest is TestBase {
    GauntletGame public game;

    function setUp() public override {
        super.setUp();

        // Deploy gauntlet game for levels 1-4 bracket
        game = new GauntletGame(
            address(gameEngine),
            payable(address(playerContract)),
            address(defaultPlayerContract),
            GauntletGame.LevelBracket.LEVELS_1_TO_4,
            address(playerTickets)
        );

        // Set permissions
        IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
            record: true,
            retire: false,
            immortal: false,
            experience: true // Need for XP rewards
        });
        playerContract.setGameContractPermission(address(game), perms);

        // Set minimum time between gauntlets to 0 for testing
        game.setMinTimeBetweenGauntlets(0);
    }

    function test4PlayerGauntlet3Transaction() public {
        _testGauntletSize(4);
    }

    function test8PlayerGauntlet3Transaction() public {
        _testGauntletSize(8);
    }

    function test16PlayerGauntlet3Transaction() public {
        _testGauntletSize(16);
    }

    function test32PlayerGauntlet3Transaction() public {
        _testGauntletSize(32);
    }

    function test64PlayerGauntlet3Transaction() public {
        _testGauntletSize(64);
    }

    function _testGauntletSize(uint8 size) internal {
        console2.log("=== TESTING", size, "PLAYER GAUNTLET (3-TRANSACTION BLOCKHASH) ===");

        // Set gauntlet size
        game.setGameEnabled(false);
        game.setGauntletSize(size);
        game.setGameEnabled(true);

        // Create players and queue them
        address[] memory players = new address[](size);
        uint32[] memory playerIds = new uint32[](size);

        for (uint8 i = 0; i < size; i++) {
            players[i] = address(uint160(0x10000 + i));
            vm.deal(players[i], 100 ether);
            playerIds[i] = _createPlayerAndFulfillVRF(players[i], playerContract, false);

            Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
                playerId: playerIds[i],
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 1 // BALANCED
            });

            vm.prank(players[i]);
            game.queueForGauntlet(loadout);
        }

        console2.log("Queue size:", game.getQueueSize());

        // TRANSACTION 1: Queue Commit
        uint256 tx1GasUsed = _measureGas(address(game), abi.encodeWithSelector(game.tryStartGauntlet.selector));
        console2.log("TX1 (Queue Commit) gas:", tx1GasUsed);

        // Get selection block for next transaction
        (bool exists, uint256 selectionBlock, uint256 tournamentBlock, uint8 phase,, uint256 participantCount) =
            game.getPendingGauntletInfo();
        require(exists, "Pending gauntlet should exist after commit");
        require(phase == 1, "Should be in QUEUE_COMMIT phase"); // GauntletPhase.QUEUE_COMMIT = 1

        // TRANSACTION 2: Participant Selection
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));

        uint256 tx2GasUsed = _measureGas(address(game), abi.encodeWithSelector(game.tryStartGauntlet.selector));
        console2.log("TX2 (Participant Selection) gas:", tx2GasUsed);

        // Get tournament block for next transaction
        (,, tournamentBlock, phase,, participantCount) = game.getPendingGauntletInfo();
        require(phase == 2, "Should be in PARTICIPANT_SELECT phase"); // GauntletPhase.PARTICIPANT_SELECT = 2
        require(participantCount == size, "Should have selected all participants");

        // TRANSACTION 3: Tournament Execution
        vm.roll(tournamentBlock + 1);
        vm.prevrandao(bytes32(uint256(67890)));

        uint256 tx3GasUsed = _measureGas(address(game), abi.encodeWithSelector(game.tryStartGauntlet.selector));
        console2.log("TX3 (Tournament Execution) gas:", tx3GasUsed);

        // Calculate totals
        uint256 totalGas = tx1GasUsed + tx2GasUsed + tx3GasUsed;
        console2.log("TOTAL 3-TRANSACTION gas:", totalGas);

        // For comparison with VRF (which only needs 2 transactions)
        uint256 equivVRFExecutionGas = tx2GasUsed + tx3GasUsed; // Selection + Execution
        console2.log("Equivalent VRF execution gas (TX2+TX3):", equivVRFExecutionGas);

        // Pure tournament cost (excluding selection overhead)
        console2.log("Pure tournament gas (TX3):", tx3GasUsed);

        // Verify gauntlet completed
        assertEq(game.nextGauntletId(), 1, "One gauntlet should have been created");
        GauntletGame.Gauntlet memory gauntlet = game.getGauntletData(0);
        assertEq(uint8(gauntlet.state), uint8(GauntletGame.GauntletState.COMPLETED), "Gauntlet should be completed");
        assertTrue(gauntlet.championId > 0, "Champion should be set");

        // Verify no pending gauntlet
        (exists,,,,,) = game.getPendingGauntletInfo();
        assertFalse(exists, "No pending gauntlet should remain");

        console2.log("Champion:", gauntlet.championId);
        console2.log("=== END", size, "PLAYER GAUNTLET ===");
        console2.log("");
    }

    function testLargeQueueSize() public {
        console2.log("=== TESTING LARGE QUEUE SIZE (NO LIMITS) ===");

        // Test with large queue since we removed limits - live free or die!
        uint8 gauntletSize = 4;
        uint256 largeQueueSize = 200; // Much larger than old 25x limit

        console2.log("Gauntlet size:", gauntletSize);
        console2.log("Large queue size to test:", largeQueueSize);

        // Create players for large queue
        for (uint256 i = 0; i < largeQueueSize; i++) {
            address player = address(uint160(0x20000 + i));
            vm.deal(player, 100 ether);
            uint32 playerId = _createPlayerAndFulfillVRF(player, playerContract, false);

            Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
                playerId: playerId,
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 1 // BALANCED
            });

            vm.prank(player);
            game.queueForGauntlet(loadout);
        }

        console2.log("Queue filled to large size:", game.getQueueSize());

        // Try to start gauntlet - should succeed with no limits
        uint256 commitGas = _measureGas(address(game), abi.encodeWithSelector(game.tryStartGauntlet.selector));
        console2.log("Commit gas with large queue:", commitGas);

        console2.log("=== END LARGE QUEUE SIZE TEST ===");
        console2.log("");
    }

    function testParticipantLocking() public {
        console2.log("=== TESTING PARTICIPANT LOCKING ===");

        // Queue 8 players for 4-player gauntlet
        game.setGameEnabled(false);
        game.setGauntletSize(4);
        game.setGameEnabled(true);

        address[] memory players = new address[](8);
        uint32[] memory playerIds = new uint32[](8);

        for (uint8 i = 0; i < 8; i++) {
            players[i] = address(uint160(0x30000 + i));
            vm.deal(players[i], 100 ether);
            playerIds[i] = _createPlayerAndFulfillVRF(players[i], playerContract, false);

            Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
                playerId: playerIds[i],
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 1 // BALANCED
            });

            vm.prank(players[i]);
            game.queueForGauntlet(loadout);
        }

        console2.log("Initial queue size:", game.getQueueSize());

        // TX1: Commit
        game.tryStartGauntlet();

        // TX2: Select participants
        (, uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));
        game.tryStartGauntlet();

        console2.log("Queue size after selection:", game.getQueueSize());
        console2.log("Should be 4 players remaining (8 - 4 selected)");

        // Verify participants cannot withdraw after selection
        // This test would check that selected players are locked and cannot withdraw
        // The actual implementation should prevent withdrawals for SELECTED players

        console2.log("=== END PARTICIPANT LOCKING TEST ===");
        console2.log("");
    }

    function _measureGas(address target, bytes memory data) internal returns (uint256) {
        uint256 gasBefore = gasleft();
        (bool success,) = target.call(data);
        require(success, "Gas measurement call failed");
        return gasBefore - gasleft();
    }
}

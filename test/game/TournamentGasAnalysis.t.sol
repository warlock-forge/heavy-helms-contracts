// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {TournamentGame} from "../../src/game/modes/TournamentGame.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";
import "../TestBase.sol";

contract TournamentGasAnalysisTest is TestBase {
    TournamentGame public game;

    function setUp() public override {
        super.setUp();

        // Deploy tournament game
        game = new TournamentGame(
            address(gameEngine), address(playerContract), address(defaultPlayerContract), address(playerTickets)
        );

        // Transfer ownership of defaultPlayerContract to the game
        defaultPlayerContract.transferOwnership(address(game));

        // Set permissions with RETIRE for death mechanics and attributes for rewards
        IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
            record: true,
            retire: true,
            attributes: true, // Need this for attribute swap rewards
            immortal: false,
            experience: true
        });
        playerContract.setGameContractPermission(address(game), perms);

        // Give tournament game permissions to mint reward tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: true,
            playerSlots: true,
            nameChanges: false,
            weaponSpecialization: true,
            armorSpecialization: true,
            duels: true
        });
        playerTickets.setGameContractPermission(address(game), ticketPerms);
    }

    // Tournaments only support sizes 16, 32, 64

    function test16PlayerTournament3Transaction() public skipInCI {
        _testTournamentSize(16);
    }

    function test16PlayerTournamentWithDefaultLethality() public skipInCI {
        _testTournamentSizeWithLethality(16, 20); // Default lethality
    }

    function test16PlayerTournamentWithZeroLethality() public skipInCI {
        _testTournamentSizeWithLethality(16, 0); // No lethality like gauntlet
    }

    function test16PlayerTournamentWithHighLethality() public skipInCI {
        _testTournamentSizeWithLethality(16, 100); // High lethality to test for lingering bugs
    }

    function test32PlayerTournament3Transaction() public skipInCI {
        _testTournamentSize(32);
    }

    function test64PlayerTournament3Transaction() public skipInCI {
        _testTournamentSize(64);
    }

    function _testTournamentSize(uint8 size) internal {
        console2.log("=== TESTING", size, "PLAYER TOURNAMENT (3-TRANSACTION BLOCKHASH) ===");

        // Set tournament size (lethality defaults to 20)
        game.setTournamentSize(size);

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
            game.queueForTournament(loadout);
        }

        console2.log("Queue size:", game.getQueueSize());

        // Set proper daily time (20:00 UTC) at least 48 hours after deployment
        uint256 futureTime = block.timestamp + 48 hours;
        futureTime = futureTime - (futureTime % 1 days) + 20 hours; // Align to 20:00 UTC
        vm.warp(futureTime);

        // TRANSACTION 1: Queue Commit
        uint256 tx1GasUsed = _measureGas(address(game), abi.encodeWithSelector(game.tryStartTournament.selector));
        console2.log("TX1 (Queue Commit) gas:", tx1GasUsed);

        // Get selection block for next transaction
        (bool exists, uint256 selectionBlock, uint256 tournamentBlock, uint8 phase,, uint256 participantCount) =
            game.getPendingTournamentInfo();
        require(exists, "Pending tournament should exist after commit");
        require(phase == 1, "Should be in QUEUE_COMMIT phase"); // TournamentPhase.QUEUE_COMMIT = 1

        // TRANSACTION 2: Participant Selection
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));

        uint256 tx2GasUsed = _measureGas(address(game), abi.encodeWithSelector(game.tryStartTournament.selector));
        console2.log("TX2 (Participant Selection) gas:", tx2GasUsed);

        // Get tournament block for next transaction
        (,, tournamentBlock, phase,, participantCount) = game.getPendingTournamentInfo();
        require(phase == 2, "Should be in PARTICIPANT_SELECT phase"); // TournamentPhase.PARTICIPANT_SELECT = 2
        require(participantCount == size, "Should have selected all participants");

        // TRANSACTION 3: Tournament Execution
        vm.roll(tournamentBlock + 1);
        vm.prevrandao(bytes32(uint256(67890)));

        uint256 tx3GasUsed = _measureGas(address(game), abi.encodeWithSelector(game.tryStartTournament.selector));
        console2.log("TX3 (Tournament Execution) gas:", tx3GasUsed);

        // Calculate totals
        uint256 totalGas = tx1GasUsed + tx2GasUsed + tx3GasUsed;
        console2.log("TOTAL 3-TRANSACTION gas:", totalGas);

        // For comparison with VRF (which only needs 2 transactions)
        uint256 equivVRFExecutionGas = tx2GasUsed + tx3GasUsed; // Selection + Execution
        console2.log("Equivalent VRF execution gas (TX2+TX3):", equivVRFExecutionGas);

        // Pure tournament cost (excluding selection overhead)
        console2.log("Pure tournament gas (TX3):", tx3GasUsed);

        // Verify tournament completed
        assertEq(game.nextTournamentId(), 1, "One tournament should have been created");
        TournamentGame.Tournament memory tournament = game.getTournamentData(0);
        assertEq(
            uint8(tournament.state), uint8(TournamentGame.TournamentState.COMPLETED), "Tournament should be completed"
        );
        assertTrue(tournament.championId > 0, "Champion should be set");

        // Verify no pending tournament
        (exists,,,,,) = game.getPendingTournamentInfo();
        assertFalse(exists, "No pending tournament should remain");

        console2.log("Champion:", tournament.championId);
        console2.log("=== END", size, "PLAYER TOURNAMENT ===");
        console2.log("");
    }

    function _testTournamentSizeWithLethality(uint8 size, uint16 lethalityFactor) internal {
        console2.log("=== TESTING TOURNAMENT WITH LETHALITY ===");
        console2.log("Size:", size);
        console2.log("Lethality:", lethalityFactor);

        // Set tournament size and specific lethality
        game.setTournamentSize(size);
        game.setLethalityFactor(lethalityFactor);

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
            game.queueForTournament(loadout);
        }

        // Set proper daily time (20:00 UTC) at least 48 hours after deployment
        uint256 futureTime = block.timestamp + 48 hours;
        futureTime = futureTime - (futureTime % 1 days) + 20 hours; // Align to 20:00 UTC
        vm.warp(futureTime);

        // TRANSACTION 1: Queue Commit
        uint256 tx1GasUsed = _measureGas(address(game), abi.encodeWithSelector(game.tryStartTournament.selector));

        // Get selection block for next transaction
        (bool exists, uint256 selectionBlock, uint256 tournamentBlock, uint8 phase,, uint256 participantCount) =
            game.getPendingTournamentInfo();
        require(exists, "Pending tournament should exist after commit");

        // TRANSACTION 2: Participant Selection
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));

        uint256 tx2GasUsed = _measureGas(address(game), abi.encodeWithSelector(game.tryStartTournament.selector));

        // Get tournament block for next transaction
        (,, tournamentBlock, phase,, participantCount) = game.getPendingTournamentInfo();

        // TRANSACTION 3: Tournament Execution
        vm.roll(tournamentBlock + 1);
        vm.prevrandao(bytes32(uint256(67890)));

        uint256 tx3GasUsed = _measureGas(address(game), abi.encodeWithSelector(game.tryStartTournament.selector));

        console2.log("TX3 (Tournament Execution) gas:", tx3GasUsed);
        console2.log("=== END LETHALITY TEST ===");
        console2.log("");
    }

    function _measureGas(address target, bytes memory data) internal returns (uint256) {
        uint256 gasBefore = gasleft();
        (bool success,) = target.call(data);
        require(success, "Gas measurement call failed");
        return gasBefore - gasleft();
    }
}

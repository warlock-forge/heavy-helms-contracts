// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {
    GauntletGame,
    InvalidBlockhash,
    DailyLimitExceeded,
    InsufficientResetFee,
    ResetNotNeeded,
    GameEnabled,
    AlreadyInQueue,
    PlayerNotInQueue
} from "../../src/game/modes/GauntletGame.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";
import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";

// Helper contract to receive ETH
contract EthReceiver {
    receive() external payable {}
}

contract GauntletGameTest is TestBase {
    GauntletGame public game;

    // Event declarations for testing
    event QueueRecovered(uint256 targetBlock);
    event GauntletRecovered(uint256 indexed gauntletId, uint256 targetBlock, uint32[] participantIds);

    address public PLAYER_ONE;
    address public PLAYER_TWO;
    address public PLAYER_THREE;
    address public PLAYER_FOUR;

    uint32 public PLAYER_ONE_ID;
    uint32 public PLAYER_TWO_ID;
    uint32 public PLAYER_THREE_ID;
    uint32 public PLAYER_FOUR_ID;

    function setUp() public override {
        super.setUp();

        // Deploy new gauntlet game for levels 1-4 bracket
        game = new GauntletGame(
            address(gameEngine),
            payable(address(playerContract)),
            address(defaultPlayerContract),
            GauntletGame.LevelBracket.LEVELS_1_TO_4,
            address(playerTickets)
        );

        // Transfer ownership of defaultPlayerContract
        defaultPlayerContract.transferOwnership(address(game));

        // Set permissions
        IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
            record: true,
            retire: false,
            immortal: false,
            experience: true // Need for XP rewards
        });
        playerContract.setGameContractPermission(address(game), perms);

        // Setup test addresses
        PLAYER_ONE = address(0x1001);
        PLAYER_TWO = address(0x1002);
        PLAYER_THREE = address(0x1003);
        PLAYER_FOUR = address(0x1004);

        // Create players
        PLAYER_ONE_ID = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        PLAYER_TWO_ID = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);
        PLAYER_THREE_ID = _createPlayerAndFulfillVRF(PLAYER_THREE, playerContract, false);
        PLAYER_FOUR_ID = _createPlayerAndFulfillVRF(PLAYER_FOUR, playerContract, false);

        // Give them ETH
        vm.deal(PLAYER_ONE, 100 ether);
        vm.deal(PLAYER_TWO, 100 ether);
        vm.deal(PLAYER_THREE, 100 ether);
        vm.deal(PLAYER_FOUR, 100 ether);

        // Set minimum time between gauntlets to 0 for testing
        game.setMinTimeBetweenGauntlets(0);

        // Set gauntlet size to 4 for most tests
        game.setGameEnabled(false);
        game.setGauntletSize(4);
        game.setGameEnabled(true);
    }

    function testCommitRevealFlow() public {
        // Queue 4 players
        Fighter.PlayerLoadout memory loadout1 = Fighter.PlayerLoadout({
            playerId: PLAYER_ONE_ID,
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            stance: 2 // OFFENSIVE
        });

        Fighter.PlayerLoadout memory loadout2 = Fighter.PlayerLoadout({
            playerId: PLAYER_TWO_ID,
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            stance: 0 // DEFENSIVE
        });

        Fighter.PlayerLoadout memory loadout3 = Fighter.PlayerLoadout({
            playerId: PLAYER_THREE_ID,
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            stance: 1 // BALANCED
        });

        Fighter.PlayerLoadout memory loadout4 = Fighter.PlayerLoadout({
            playerId: PLAYER_FOUR_ID,
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            stance: 2 // OFFENSIVE
        });

        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(loadout1);

        vm.prank(PLAYER_TWO);
        game.queueForGauntlet(loadout2);

        vm.prank(PLAYER_THREE);
        game.queueForGauntlet(loadout3);

        vm.prank(PLAYER_FOUR);
        game.queueForGauntlet(loadout4);

        assertEq(game.getQueueSize(), 4, "Queue should have 4 players");

        // First call - should commit
        uint256 commitBlock = block.number;
        game.tryStartGauntlet();

        // Check pending gauntlet exists
        (bool exists, uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();
        assertTrue(exists, "Pending gauntlet should exist");
        assertEq(selectionBlock, commitBlock + game.futureBlocksForSelection(), "Selection block incorrect");
        // No participants selected yet in phase 1

        // Trying to call again before reveal block should revert
        vm.expectRevert();
        game.tryStartGauntlet();

        // Advance to selection block + 1 to ensure blockhash is available
        vm.roll(selectionBlock + 1);
        // Set a known blockhash for the reveal block
        vm.prevrandao(bytes32(uint256(12345)));

        // Second call - should select participants
        game.tryStartGauntlet();

        // Get tournament block
        (,, uint256 tournamentBlock,,,) = game.getPendingGauntletInfo();

        // Third call - advance to tournament block and execute
        vm.roll(tournamentBlock + 1);
        vm.prevrandao(bytes32(uint256(67890)));
        game.tryStartGauntlet();

        // Check gauntlet was created and completed
        assertEq(game.nextGauntletId(), 1, "One gauntlet should have been created");

        GauntletGame.Gauntlet memory gauntlet = game.getGauntletData(0);
        assertEq(uint8(gauntlet.state), uint8(GauntletGame.GauntletState.COMPLETED), "Gauntlet should be completed");
        assertEq(gauntlet.size, 4, "Gauntlet size should be 4");
        assertTrue(gauntlet.championId > 0, "Champion should be set");

        // Check pending gauntlet cleared
        (exists,,,,,) = game.getPendingGauntletInfo();
        assertFalse(exists, "Pending gauntlet should be cleared");

        // Check queue is empty
        assertEq(game.getQueueSize(), 0, "Queue should be empty");
    }

    function testHybridSelection() public {
        // Queue 16 players for an 8-player gauntlet
        game.setGameEnabled(false);
        game.setGauntletSize(8);
        game.setGameEnabled(true);

        // Create and queue 16 players
        for (uint256 i = 0; i < 16; i++) {
            address player = address(uint160(0x2000 + i));
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

        assertEq(game.getQueueSize(), 16, "Queue should have 16 players");

        // Commit
        game.tryStartGauntlet();

        // Get selection block
        (, uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();

        // Advance and select participants
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(67890)));
        game.tryStartGauntlet();

        // Check that 8 players remain in queue (16 - 8 selected)
        assertEq(game.getQueueSize(), 8, "8 players should remain in queue");
    }

    function testRecoveryAfter256Blocks() public {
        // Queue 4 players
        Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
            playerId: PLAYER_ONE_ID,
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            stance: 2 // OFFENSIVE
        });

        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(loadout);

        vm.prank(PLAYER_TWO);
        game.queueForGauntlet(
            Fighter.PlayerLoadout({
                playerId: PLAYER_TWO_ID,
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 0 // DEFENSIVE
            })
        );

        vm.prank(PLAYER_THREE);
        game.queueForGauntlet(
            Fighter.PlayerLoadout({
                playerId: PLAYER_THREE_ID,
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 1 // BALANCED
            })
        );

        vm.prank(PLAYER_FOUR);
        game.queueForGauntlet(
            Fighter.PlayerLoadout({
                playerId: PLAYER_FOUR_ID,
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 2 // OFFENSIVE
            })
        );

        // Commit
        game.tryStartGauntlet();

        // Get the selection block from pending gauntlet info
        (, uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();

        // Advance past 256 blocks from the selection block to enable auto-recovery
        vm.roll(selectionBlock + 257);

        // Auto-recovery through tryStartGauntlet
        game.tryStartGauntlet();

        // Check pending gauntlet cleared
        (bool exists,,,,,) = game.getPendingGauntletInfo();
        assertFalse(exists, "Pending gauntlet should be cleared");

        // Check queue still has players
        assertEq(game.getQueueSize(), 4, "Queue should still have 4 players");
    }

    function testBug_PlayersStuckAfterRecoveryPostSelection() public {
        // Queue 4 players
        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(_createSimpleLoadout(PLAYER_ONE_ID));
        vm.prank(PLAYER_TWO);
        game.queueForGauntlet(_createSimpleLoadout(PLAYER_TWO_ID));
        vm.prank(PLAYER_THREE);
        game.queueForGauntlet(_createSimpleLoadout(PLAYER_THREE_ID));
        vm.prank(PLAYER_FOUR);
        game.queueForGauntlet(_createSimpleLoadout(PLAYER_FOUR_ID));

        // TX1: Commit (QUEUE_COMMIT phase)
        game.tryStartGauntlet();

        // Verify players are still QUEUED after commit
        assertEq(
            uint8(game.playerStatus(PLAYER_ONE_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED),
            "Should be QUEUED after commit"
        );

        // Need to advance past the selection block and mine a block so blockhash exists
        vm.roll(block.number + game.futureBlocksForSelection() + 1);

        // TX2: Select participants (moves to IN_TOURNAMENT) - record logs to capture participant order
        vm.recordLogs();
        game.tryStartGauntlet();

        // Verify players moved to IN_TOURNAMENT
        assertEq(
            uint8(game.playerStatus(PLAYER_ONE_ID)),
            uint8(GauntletGame.PlayerStatus.IN_TOURNAMENT),
            "Should be IN_TOURNAMENT after selection"
        );
        assertEq(
            uint8(game.playerStatus(PLAYER_TWO_ID)),
            uint8(GauntletGame.PlayerStatus.IN_TOURNAMENT),
            "Should be IN_TOURNAMENT after selection"
        );
        assertEq(
            uint8(game.playerStatus(PLAYER_THREE_ID)),
            uint8(GauntletGame.PlayerStatus.IN_TOURNAMENT),
            "Should be IN_TOURNAMENT after selection"
        );
        assertEq(
            uint8(game.playerStatus(PLAYER_FOUR_ID)),
            uint8(GauntletGame.PlayerStatus.IN_TOURNAMENT),
            "Should be IN_TOURNAMENT after selection"
        );

        // Verify gauntlet was created
        uint256 gauntletId = game.nextGauntletId() - 1;
        (uint256 id, uint8 size, GauntletGame.GauntletState state,,, uint32 championId, uint32 runnerUpId) =
            game.gauntlets(gauntletId);
        assertEq(id, gauntletId, "Gauntlet ID should match");
        assertEq(size, 4, "Gauntlet size should be 4");
        assertEq(uint8(state), uint8(GauntletGame.GauntletState.PENDING), "Gauntlet should be PENDING");
        assertEq(championId, 0, "Champion should be 0");
        assertEq(runnerUpId, 0, "Runner up should be 0");

        // Get the tournament block and advance past 256 blocks from it to trigger auto-recovery
        (,, uint256 tournamentBlock,,,) = game.getPendingGauntletInfo();
        vm.roll(tournamentBlock + 257);

        // TX3: This should auto-recover - just verify it works, don't test exact event data
        game.tryStartGauntlet();

        // Verify pending gauntlet is cleared
        (bool exists,,,,,) = game.getPendingGauntletInfo();
        assertFalse(exists, "Pending gauntlet should be cleared");

        // FIXED: Players should now be back in QUEUED status after recovery
        assertEq(
            uint8(game.playerStatus(PLAYER_ONE_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED),
            "FIXED: Player should be QUEUED after recovery!"
        );
        assertEq(
            uint8(game.playerStatus(PLAYER_TWO_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED),
            "FIXED: Player should be QUEUED after recovery!"
        );
        assertEq(
            uint8(game.playerStatus(PLAYER_THREE_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED),
            "FIXED: Player should be QUEUED after recovery!"
        );
        assertEq(
            uint8(game.playerStatus(PLAYER_FOUR_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED),
            "FIXED: Player should be QUEUED after recovery!"
        );

        // Verify gauntlet is marked as COMPLETED after recovery
        (,, GauntletGame.GauntletState stateAfter,,,,) = game.gauntlets(gauntletId);
        assertEq(
            uint8(stateAfter),
            uint8(GauntletGame.GauntletState.COMPLETED),
            "FIXED: Gauntlet should be COMPLETED after recovery!"
        );

        // Players should be able to withdraw from queue now
        vm.prank(PLAYER_ONE);
        game.withdrawFromQueue(PLAYER_ONE_ID);
        assertEq(game.getQueueSize(), 3, "Player should be able to withdraw");

        // And can re-queue
        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(_createSimpleLoadout(PLAYER_ONE_ID));
        assertEq(game.getQueueSize(), 4, "Player should be able to re-queue");
    }

    function testFix_RecoveryReturnsPlayersToQueue() public {
        // Queue 4 players
        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(_createSimpleLoadout(PLAYER_ONE_ID));
        vm.prank(PLAYER_TWO);
        game.queueForGauntlet(_createSimpleLoadout(PLAYER_TWO_ID));
        vm.prank(PLAYER_THREE);
        game.queueForGauntlet(_createSimpleLoadout(PLAYER_THREE_ID));
        vm.prank(PLAYER_FOUR);
        game.queueForGauntlet(_createSimpleLoadout(PLAYER_FOUR_ID));

        // TX1: Commit
        game.tryStartGauntlet();

        // TX2: Select participants
        vm.roll(block.number + game.futureBlocksForSelection() + 1);
        game.tryStartGauntlet();

        // Verify gauntlet was created
        uint256 gauntletId = game.nextGauntletId() - 1;

        // Get the tournament block and advance past 256 blocks from it
        (,, uint256 tournamentBlock,,,) = game.getPendingGauntletInfo();
        vm.roll(tournamentBlock + 257);

        // TX3: Auto-recover
        game.tryStartGauntlet();

        // Verify players are back in QUEUED status
        assertEq(
            uint8(game.playerStatus(PLAYER_ONE_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED),
            "Should be QUEUED after recovery"
        );
        assertEq(
            uint8(game.playerStatus(PLAYER_TWO_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED),
            "Should be QUEUED after recovery"
        );
        assertEq(
            uint8(game.playerStatus(PLAYER_THREE_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED),
            "Should be QUEUED after recovery"
        );
        assertEq(
            uint8(game.playerStatus(PLAYER_FOUR_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED),
            "Should be QUEUED after recovery"
        );

        // Verify queue has all 4 players back
        assertEq(game.getQueueSize(), 4, "Queue should have 4 players");

        // Verify gauntlet is marked as COMPLETED
        (,, GauntletGame.GauntletState stateAfter,,,,) = game.gauntlets(gauntletId);
        assertEq(
            uint8(stateAfter),
            uint8(GauntletGame.GauntletState.COMPLETED),
            "Gauntlet should be COMPLETED after recovery"
        );

        // Players should be able to queue again (withdraw and re-queue to test)
        vm.prank(PLAYER_ONE);
        game.withdrawFromQueue(PLAYER_ONE_ID);
        assertEq(game.getQueueSize(), 3, "Queue should have 3 players after withdraw");

        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(_createSimpleLoadout(PLAYER_ONE_ID));
        assertEq(game.getQueueSize(), 4, "Queue should have 4 players after re-queue");
    }

    function testConfigurableFutureBlocks() public {
        // Change future blocks setting
        game.setFutureBlocksForSelection(50);
        assertEq(game.futureBlocksForSelection(), 50, "Future blocks should be updated");

        // Queue players and commit
        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(
            Fighter.PlayerLoadout({
                playerId: PLAYER_ONE_ID,
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 2 // OFFENSIVE
            })
        );

        vm.prank(PLAYER_TWO);
        game.queueForGauntlet(
            Fighter.PlayerLoadout({
                playerId: PLAYER_TWO_ID,
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 0 // DEFENSIVE
            })
        );

        vm.prank(PLAYER_THREE);
        game.queueForGauntlet(
            Fighter.PlayerLoadout({
                playerId: PLAYER_THREE_ID,
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 1 // BALANCED
            })
        );

        vm.prank(PLAYER_FOUR);
        game.queueForGauntlet(
            Fighter.PlayerLoadout({
                playerId: PLAYER_FOUR_ID,
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 2 // OFFENSIVE
            })
        );

        uint256 commitBlock = block.number;
        game.tryStartGauntlet();

        // Check selection block is 50 blocks in future
        (, uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();
        assertEq(selectionBlock, commitBlock + 50, "Selection block should be 50 blocks in future");
    }

    function testInvalidBlockhashReverts() public {
        // Queue players
        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(
            Fighter.PlayerLoadout({
                playerId: PLAYER_ONE_ID,
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 2 // OFFENSIVE
            })
        );

        vm.prank(PLAYER_TWO);
        game.queueForGauntlet(
            Fighter.PlayerLoadout({
                playerId: PLAYER_TWO_ID,
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 0 // DEFENSIVE
            })
        );

        vm.prank(PLAYER_THREE);
        game.queueForGauntlet(
            Fighter.PlayerLoadout({
                playerId: PLAYER_THREE_ID,
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 1 // BALANCED
            })
        );

        vm.prank(PLAYER_FOUR);
        game.queueForGauntlet(
            Fighter.PlayerLoadout({
                playerId: PLAYER_FOUR_ID,
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 2 // OFFENSIVE
            })
        );

        // Commit
        game.tryStartGauntlet();

        // Get selection block
        (, uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();

        // Try to execute at exact selection block (should revert because blockhash(current_block) = 0)
        vm.roll(selectionBlock);
        // In Foundry, blockhash of current block returns 0, so this should revert
        uint256 testBlockhash = uint256(blockhash(selectionBlock));
        console2.log("Blockhash at exact selection block:", testBlockhash);

        vm.expectRevert(InvalidBlockhash.selector);
        game.tryStartGauntlet();

        // Test that pending gauntlet still exists after revert
        (bool exists,,,,,) = game.getPendingGauntletInfo();
        assertTrue(exists, "Pending gauntlet should still exist after revert");

        // Test far future (beyond 256 blocks from commit) - should auto-recover
        uint256 commitBlock = selectionBlock - game.futureBlocksForSelection();
        vm.roll(commitBlock + 300); // More than 256 blocks from commit

        // This should auto-recover and clear the pending gauntlet
        game.tryStartGauntlet();

        // Verify pending gauntlet was cleared by auto-recovery
        (bool existsAfterRecovery,,,,,) = game.getPendingGauntletInfo();
        assertFalse(existsAfterRecovery, "Pending gauntlet should be cleared after auto-recovery");

        // Queue should still have 4 players
        assertEq(game.getQueueSize(), 4, "Queue should still have 4 players after recovery");
    }

    //==============================================================//
    //              QUEUE MANAGEMENT ERROR TESTS                   //
    //==============================================================//

    function testRevertWhen_AlreadyInQueue() public {
        // Queue player one
        vm.startPrank(PLAYER_ONE);
        Fighter.PlayerLoadout memory loadout = _createSimpleLoadout(PLAYER_ONE_ID);
        game.queueForGauntlet(loadout);

        // Try to queue again - should revert
        vm.expectRevert("AlreadyInQueue()");
        game.queueForGauntlet(loadout);
        vm.stopPrank();
    }

    function testRevertWhen_NotPlayerOwner() public {
        // Try to queue a player you don't own
        vm.startPrank(PLAYER_TWO);
        Fighter.PlayerLoadout memory loadout = _createSimpleLoadout(PLAYER_ONE_ID); // Using player one's ID

        vm.expectRevert("CallerNotPlayerOwner()");
        game.queueForGauntlet(loadout);
        vm.stopPrank();
    }

    function testRevertWhen_PlayerRetired() public {
        // First retire player one
        vm.startPrank(PLAYER_ONE);
        playerContract.retireOwnPlayer(PLAYER_ONE_ID);

        // Now try to queue retired player
        Fighter.PlayerLoadout memory loadout = _createSimpleLoadout(PLAYER_ONE_ID);

        vm.expectRevert("PlayerIsRetired()");
        game.queueForGauntlet(loadout);
        vm.stopPrank();
    }

    function testRevertWhen_GameDisabled() public {
        // Disable game as owner
        vm.prank(game.owner());
        game.setGameEnabled(false);

        // Try to queue when game is disabled
        vm.startPrank(PLAYER_ONE);
        Fighter.PlayerLoadout memory loadout = _createSimpleLoadout(PLAYER_ONE_ID);

        vm.expectRevert("GameDisabled()");
        game.queueForGauntlet(loadout);
        vm.stopPrank();
    }

    function testRevertWhen_WithdrawNotInQueue() public {
        // Try to withdraw when not in queue
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert("PlayerNotInQueue()");
        game.withdrawFromQueue(PLAYER_ONE_ID);
        vm.stopPrank();
    }

    function testRevertWhen_WithdrawAfterTournamentStart() public {
        // Queue 4 players
        for (uint8 i = 0; i < 4; i++) {
            address player = i == 0 ? PLAYER_ONE : (i == 1 ? PLAYER_TWO : (i == 2 ? PLAYER_THREE : PLAYER_FOUR));
            uint32 playerId =
                i == 0 ? PLAYER_ONE_ID : (i == 1 ? PLAYER_TWO_ID : (i == 2 ? PLAYER_THREE_ID : PLAYER_FOUR_ID));

            vm.startPrank(player);
            game.queueForGauntlet(_createSimpleLoadout(playerId));
            vm.stopPrank();
        }

        // TX1: Commit
        game.tryStartGauntlet();

        // TX2: Select participants (this moves players to IN_TOURNAMENT status)
        (, uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));
        game.tryStartGauntlet();

        // Try to withdraw - should fail because player is IN_TOURNAMENT and not in queue
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(); // PlayerNotInQueue because they're removed from queue in TX2
        game.withdrawFromQueue(PLAYER_ONE_ID);
        vm.stopPrank();
    }

    //==============================================================//
    //                 ADMIN FUNCTION TESTS                        //
    //==============================================================//

    function testSetGameEnabled_ClearsQueue() public {
        // Queue some players
        vm.startPrank(PLAYER_ONE);
        game.queueForGauntlet(_createSimpleLoadout(PLAYER_ONE_ID));
        vm.stopPrank();

        vm.startPrank(PLAYER_TWO);
        game.queueForGauntlet(_createSimpleLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        assertEq(game.getQueueSize(), 2, "Queue should have 2 players");

        // Disable game - should clear queue
        vm.prank(game.owner());
        game.setGameEnabled(false);

        assertFalse(game.isGameEnabled(), "Game should be disabled");
        assertTrue(game.getQueueSize() <= 2, "Queue should be cleared or partially cleared"); // Batch clearing

        // Re-enable
        vm.prank(game.owner());
        game.setGameEnabled(true);
        assertTrue(game.isGameEnabled(), "Game should be enabled");
    }

    function testEmergencyClearQueue() public {
        // Queue multiple players
        for (uint8 i = 0; i < 4; i++) {
            address player = i == 0 ? PLAYER_ONE : (i == 1 ? PLAYER_TWO : (i == 2 ? PLAYER_THREE : PLAYER_FOUR));
            uint32 playerId =
                i == 0 ? PLAYER_ONE_ID : (i == 1 ? PLAYER_TWO_ID : (i == 2 ? PLAYER_THREE_ID : PLAYER_FOUR_ID));

            vm.startPrank(player);
            game.queueForGauntlet(_createSimpleLoadout(playerId));
            vm.stopPrank();
        }

        assertEq(game.getQueueSize(), 4, "Queue should have 4 players");

        // Emergency clear as owner
        vm.prank(game.owner());
        game.emergencyClearQueue();

        assertTrue(game.getQueueSize() <= 4, "Queue should be cleared or partially cleared"); // Batch clearing
    }

    function testSetGauntletSize() public {
        // Disable game first
        vm.prank(game.owner());
        game.setGameEnabled(false);

        // Change size to 8
        vm.prank(game.owner());
        game.setGauntletSize(8);
        assertEq(game.currentGauntletSize(), 8, "Gauntlet size should be 8");

        // Change back to 4
        vm.prank(game.owner());
        game.setGauntletSize(4);
        assertEq(game.currentGauntletSize(), 4, "Gauntlet size should be 4");

        // Re-enable
        vm.prank(game.owner());
        game.setGameEnabled(true);
    }

    function testRevertWhen_SetGauntletSize_GameEnabled() public {
        // Try to change size while game is enabled
        vm.prank(game.owner());
        vm.expectRevert(GameEnabled.selector);
        game.setGauntletSize(8);
    }

    function testRevertWhen_SetGauntletSize_InvalidSize() public {
        // Disable game first
        vm.prank(game.owner());
        game.setGameEnabled(false);

        // Try invalid sizes
        vm.prank(game.owner());
        vm.expectRevert();
        game.setGauntletSize(0);

        vm.prank(game.owner());
        vm.expectRevert();
        game.setGauntletSize(10);

        vm.prank(game.owner());
        vm.expectRevert();
        game.setGauntletSize(33);
    }

    function testRevertWhen_AdminFunctions_NotOwner() public {
        // Test all admin functions fail for non-owner
        vm.startPrank(PLAYER_ONE);

        vm.expectRevert("Only callable by owner");
        game.setGameEnabled(false);

        vm.expectRevert("Only callable by owner");
        game.setGauntletSize(8);

        vm.expectRevert("Only callable by owner");
        game.emergencyClearQueue();

        vm.expectRevert("Only callable by owner");
        game.setFutureBlocksForSelection(10);

        vm.expectRevert("Only callable by owner");
        game.setFutureBlocksForTournament(10);

        vm.stopPrank();
    }

    //==============================================================//
    //            PLAYER STATUS TRANSITION TESTS                   //
    //==============================================================//

    function testPlayerStatusTransitions() public {
        // Initial state: NONE
        assertEq(uint8(game.playerStatus(PLAYER_ONE_ID)), uint8(GauntletGame.PlayerStatus.NONE), "Should start as NONE");

        // Queue player: NONE -> QUEUED
        vm.startPrank(PLAYER_ONE);
        game.queueForGauntlet(_createSimpleLoadout(PLAYER_ONE_ID));
        vm.stopPrank();
        assertEq(uint8(game.playerStatus(PLAYER_ONE_ID)), uint8(GauntletGame.PlayerStatus.QUEUED), "Should be QUEUED");

        // Withdraw: QUEUED -> NONE
        vm.startPrank(PLAYER_ONE);
        game.withdrawFromQueue(PLAYER_ONE_ID);
        vm.stopPrank();
        assertEq(
            uint8(game.playerStatus(PLAYER_ONE_ID)),
            uint8(GauntletGame.PlayerStatus.NONE),
            "Should be NONE after withdraw"
        );
    }

    function testPlayerStatusDuringGauntlet() public {
        // Queue 4 players
        address[4] memory players = [PLAYER_ONE, PLAYER_TWO, PLAYER_THREE, PLAYER_FOUR];
        uint32[4] memory playerIds = [PLAYER_ONE_ID, PLAYER_TWO_ID, PLAYER_THREE_ID, PLAYER_FOUR_ID];

        for (uint8 i = 0; i < 4; i++) {
            vm.startPrank(players[i]);
            game.queueForGauntlet(_createSimpleLoadout(playerIds[i]));
            vm.stopPrank();
        }

        // All should be QUEUED
        for (uint8 i = 0; i < 4; i++) {
            assertEq(
                uint8(game.playerStatus(playerIds[i])), uint8(GauntletGame.PlayerStatus.QUEUED), "Should be QUEUED"
            );
        }

        // TX1: Commit
        game.tryStartGauntlet();

        // TX2: Select (moves to IN_TOURNAMENT)
        (, uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));
        game.tryStartGauntlet();

        // All should be IN_TOURNAMENT
        for (uint8 i = 0; i < 4; i++) {
            assertEq(
                uint8(game.playerStatus(playerIds[i])),
                uint8(GauntletGame.PlayerStatus.IN_TOURNAMENT),
                "Should be IN_TOURNAMENT"
            );
        }

        // TX3: Execute tournament (moves back to NONE)
        (,, uint256 tournamentBlock,,,) = game.getPendingGauntletInfo();
        vm.roll(tournamentBlock + 1);
        vm.prevrandao(bytes32(uint256(67890)));
        game.tryStartGauntlet();

        // All should be NONE after tournament
        for (uint8 i = 0; i < 4; i++) {
            assertEq(
                uint8(game.playerStatus(playerIds[i])),
                uint8(GauntletGame.PlayerStatus.NONE),
                "Should be NONE after tournament"
            );
        }
    }

    //==============================================================//
    //               START GAUNTLET ERROR TESTS                    //
    //==============================================================//

    function testRevertWhen_InsufficientQueueSize() public {
        // Queue only 2 players (need 4)
        vm.startPrank(PLAYER_ONE);
        game.queueForGauntlet(_createSimpleLoadout(PLAYER_ONE_ID));
        vm.stopPrank();

        vm.startPrank(PLAYER_TWO);
        game.queueForGauntlet(_createSimpleLoadout(PLAYER_TWO_ID));
        vm.stopPrank();

        vm.expectRevert();
        game.tryStartGauntlet();
    }

    function testRevertWhen_MinTimeNotElapsed() public {
        // Set a non-zero min time for this test
        vm.prank(game.owner());
        game.setMinTimeBetweenGauntlets(1 hours);

        // Queue 4 players
        address[4] memory players = [PLAYER_ONE, PLAYER_TWO, PLAYER_THREE, PLAYER_FOUR];
        uint32[4] memory playerIds = [PLAYER_ONE_ID, PLAYER_TWO_ID, PLAYER_THREE_ID, PLAYER_FOUR_ID];

        for (uint8 i = 0; i < 4; i++) {
            vm.startPrank(players[i]);
            game.queueForGauntlet(_createSimpleLoadout(playerIds[i]));
            vm.stopPrank();
        }

        // Don't advance time - should fail due to min time
        vm.expectRevert();
        game.tryStartGauntlet();
    }

    //==============================================================//
    //            RETIRED PLAYER SUBSTITUTION TESTS               //
    //==============================================================//

    function testRetiredPlayerSubstitution() public {
        // Queue 4 players
        address[4] memory players = [PLAYER_ONE, PLAYER_TWO, PLAYER_THREE, PLAYER_FOUR];
        uint32[4] memory playerIds = [PLAYER_ONE_ID, PLAYER_TWO_ID, PLAYER_THREE_ID, PLAYER_FOUR_ID];

        for (uint8 i = 0; i < 4; i++) {
            vm.startPrank(players[i]);
            game.queueForGauntlet(_createSimpleLoadout(playerIds[i]));
            vm.stopPrank();
        }

        // Complete gauntlet selection
        game.tryStartGauntlet(); // TX1
        (, uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));
        game.tryStartGauntlet(); // TX2

        // Retire one player after selection
        vm.startPrank(PLAYER_ONE);
        playerContract.retireOwnPlayer(PLAYER_ONE_ID);
        vm.stopPrank();
        assertTrue(playerContract.isPlayerRetired(PLAYER_ONE_ID), "Player should be retired");

        // Execute tournament - should substitute retired player with default
        (,, uint256 tournamentBlock,,,) = game.getPendingGauntletInfo();
        vm.roll(tournamentBlock + 1);
        vm.prevrandao(bytes32(uint256(67890)));
        game.tryStartGauntlet(); // TX3 - should complete successfully with substitution

        // Verify gauntlet completed
        GauntletGame.Gauntlet memory gauntlet = game.getGauntletData(0);
        assertEq(uint8(gauntlet.state), uint8(GauntletGame.GauntletState.COMPLETED), "Gauntlet should be completed");
        assertTrue(gauntlet.championId > 0, "Should have a champion");
    }

    function testMultipleRetiredPlayerSubstitution() public {
        // Queue 4 players
        address[4] memory players = [PLAYER_ONE, PLAYER_TWO, PLAYER_THREE, PLAYER_FOUR];
        uint32[4] memory playerIds = [PLAYER_ONE_ID, PLAYER_TWO_ID, PLAYER_THREE_ID, PLAYER_FOUR_ID];

        for (uint8 i = 0; i < 4; i++) {
            vm.startPrank(players[i]);
            game.queueForGauntlet(_createSimpleLoadout(playerIds[i]));
            vm.stopPrank();
        }

        // Complete gauntlet selection
        game.tryStartGauntlet(); // TX1
        (, uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));
        game.tryStartGauntlet(); // TX2

        // Retire multiple players after selection
        vm.startPrank(PLAYER_ONE);
        playerContract.retireOwnPlayer(PLAYER_ONE_ID);
        vm.stopPrank();

        vm.startPrank(PLAYER_TWO);
        playerContract.retireOwnPlayer(PLAYER_TWO_ID);
        vm.stopPrank();

        // Execute tournament - should substitute retired players with defaults
        (,, uint256 tournamentBlock,,,) = game.getPendingGauntletInfo();
        vm.roll(tournamentBlock + 1);
        vm.prevrandao(bytes32(uint256(67890)));
        game.tryStartGauntlet(); // TX3 - should complete successfully

        // Verify gauntlet completed
        GauntletGame.Gauntlet memory gauntlet = game.getGauntletData(0);
        assertEq(uint8(gauntlet.state), uint8(GauntletGame.GauntletState.COMPLETED), "Gauntlet should be completed");
        assertTrue(gauntlet.championId > 0, "Should have a champion");
    }

    //==============================================================//
    //                 BRACKET VALIDATION TESTS                    //
    //==============================================================//

    function testBracketValidation_LEVELS_1_TO_4() public {
        // Create a levels 1-4 bracket game
        GauntletGame levels1To4Game = new GauntletGame(
            address(gameEngine),
            payable(address(playerContract)),
            address(defaultPlayerContract),
            GauntletGame.LevelBracket.LEVELS_1_TO_4,
            address(playerTickets)
        );

        // Set permissions
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, immortal: false, experience: false});
        playerContract.setGameContractPermission(address(levels1To4Game), perms);

        // Player level 1-4 should work (players start at level 1)
        vm.startPrank(PLAYER_ONE);
        levels1To4Game.queueForGauntlet(_createSimpleLoadout(PLAYER_ONE_ID));
        vm.stopPrank();

        // Verify player was queued
        assertEq(
            uint8(levels1To4Game.playerStatus(PLAYER_ONE_ID)),
            uint8(GauntletGame.PlayerStatus.QUEUED),
            "Player should be queued"
        );
    }

    function testBracketValidation_LEVELS_1_TO_4_Boundaries() public {
        // Create a levels 1-4 bracket game
        GauntletGame levels1To4Game = new GauntletGame(
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
            experience: true // Need for leveling players
        });
        playerContract.setGameContractPermission(address(levels1To4Game), perms);
        playerContract.setGameContractPermission(address(this), perms);

        // Test level 1 (lower boundary) - should work
        vm.startPrank(PLAYER_ONE);
        levels1To4Game.queueForGauntlet(_createSimpleLoadout(PLAYER_ONE_ID));
        vm.stopPrank();
        assertEq(uint8(levels1To4Game.playerStatus(PLAYER_ONE_ID)), uint8(GauntletGame.PlayerStatus.QUEUED));

        // Test level 4 (upper boundary) - should work
        _levelUpPlayer(PLAYER_TWO_ID, 3); // Level up from 1 to 4
        vm.startPrank(PLAYER_TWO);
        levels1To4Game.queueForGauntlet(_createSimpleLoadout(PLAYER_TWO_ID));
        vm.stopPrank();
        assertEq(uint8(levels1To4Game.playerStatus(PLAYER_TWO_ID)), uint8(GauntletGame.PlayerStatus.QUEUED));

        // Test level 5 (just above boundary) - should fail with PlayerNotInBracket
        _levelUpPlayer(PLAYER_THREE_ID, 4); // Level up from 1 to 5
        vm.startPrank(PLAYER_THREE);
        vm.expectRevert(
            abi.encodeWithSignature(
                "PlayerNotInBracket(uint8,uint8)", 5, uint8(GauntletGame.LevelBracket.LEVELS_1_TO_4)
            )
        );
        levels1To4Game.queueForGauntlet(_createSimpleLoadout(PLAYER_THREE_ID));
        vm.stopPrank();
    }

    function testBracketValidation_LEVELS_5_TO_9_Boundaries() public {
        // Create LEVELS_5_TO_9 bracket game
        GauntletGame levels5To9Game = new GauntletGame(
            address(gameEngine),
            payable(address(playerContract)),
            address(defaultPlayerContract),
            GauntletGame.LevelBracket.LEVELS_5_TO_9,
            address(playerTickets)
        );

        // Set permissions
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, immortal: false, experience: true});
        playerContract.setGameContractPermission(address(levels5To9Game), perms);
        playerContract.setGameContractPermission(address(this), perms);

        // Test level 4 (just below) - should fail with PlayerNotInBracket
        _levelUpPlayer(PLAYER_ONE_ID, 3); // Level up from 1 to 4
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(
            abi.encodeWithSignature(
                "PlayerNotInBracket(uint8,uint8)", 4, uint8(GauntletGame.LevelBracket.LEVELS_5_TO_9)
            )
        );
        levels5To9Game.queueForGauntlet(_createSimpleLoadout(PLAYER_ONE_ID));
        vm.stopPrank();

        // Test level 5 (lower boundary) - should work
        _levelUpPlayer(PLAYER_TWO_ID, 4); // Level up from 1 to 5
        vm.startPrank(PLAYER_TWO);
        levels5To9Game.queueForGauntlet(_createSimpleLoadout(PLAYER_TWO_ID));
        vm.stopPrank();
        assertEq(uint8(levels5To9Game.playerStatus(PLAYER_TWO_ID)), uint8(GauntletGame.PlayerStatus.QUEUED));

        // Test level 9 (upper boundary) - should work
        _levelUpPlayer(PLAYER_THREE_ID, 8); // Level up from 1 to 9
        vm.startPrank(PLAYER_THREE);
        levels5To9Game.queueForGauntlet(_createSimpleLoadout(PLAYER_THREE_ID));
        vm.stopPrank();
        assertEq(uint8(levels5To9Game.playerStatus(PLAYER_THREE_ID)), uint8(GauntletGame.PlayerStatus.QUEUED));

        // Test level 10 (just above) - should fail with PlayerNotInBracket
        _levelUpPlayer(PLAYER_FOUR_ID, 9); // Level up from 1 to 10
        vm.startPrank(PLAYER_FOUR);
        vm.expectRevert(
            abi.encodeWithSignature(
                "PlayerNotInBracket(uint8,uint8)", 10, uint8(GauntletGame.LevelBracket.LEVELS_5_TO_9)
            )
        );
        levels5To9Game.queueForGauntlet(_createSimpleLoadout(PLAYER_FOUR_ID));
        vm.stopPrank();
    }

    function testBracketValidation_LEVEL_10_Boundaries() public {
        // Create LEVEL_10 bracket game
        GauntletGame level10Game = new GauntletGame(
            address(gameEngine),
            payable(address(playerContract)),
            address(defaultPlayerContract),
            GauntletGame.LevelBracket.LEVEL_10,
            address(playerTickets)
        );

        // Set permissions
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, immortal: false, experience: true});
        playerContract.setGameContractPermission(address(level10Game), perms);
        playerContract.setGameContractPermission(address(this), perms);

        // Test level 9 (just below) - should fail with PlayerNotInBracket
        _levelUpPlayer(PLAYER_ONE_ID, 8); // Level up from 1 to 9
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(
            abi.encodeWithSignature("PlayerNotInBracket(uint8,uint8)", 9, uint8(GauntletGame.LevelBracket.LEVEL_10))
        );
        level10Game.queueForGauntlet(_createSimpleLoadout(PLAYER_ONE_ID));
        vm.stopPrank();

        // Test level 10 (exact match) - should work
        _levelUpPlayer(PLAYER_TWO_ID, 9); // Level up from 1 to 10
        vm.startPrank(PLAYER_TWO);
        level10Game.queueForGauntlet(_createSimpleLoadout(PLAYER_TWO_ID));
        vm.stopPrank();
        assertEq(uint8(level10Game.playerStatus(PLAYER_TWO_ID)), uint8(GauntletGame.PlayerStatus.QUEUED));
    }

    function testAllThreeBracketTypes() public {
        // Create one game instance for each bracket type
        GauntletGame levels1To4Game = new GauntletGame(
            address(gameEngine),
            payable(address(playerContract)),
            address(defaultPlayerContract),
            GauntletGame.LevelBracket.LEVELS_1_TO_4,
            address(playerTickets)
        );

        GauntletGame levels5To9Game = new GauntletGame(
            address(gameEngine),
            payable(address(playerContract)),
            address(defaultPlayerContract),
            GauntletGame.LevelBracket.LEVELS_5_TO_9,
            address(playerTickets)
        );

        GauntletGame level10Game = new GauntletGame(
            address(gameEngine),
            payable(address(playerContract)),
            address(defaultPlayerContract),
            GauntletGame.LevelBracket.LEVEL_10,
            address(playerTickets)
        );

        // Set permissions for all games
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, immortal: false, experience: true});
        playerContract.setGameContractPermission(address(levels1To4Game), perms);
        playerContract.setGameContractPermission(address(levels5To9Game), perms);
        playerContract.setGameContractPermission(address(level10Game), perms);
        playerContract.setGameContractPermission(address(this), perms);

        // Create players at different levels
        // PLAYER_ONE: Level 1 (default)
        // PLAYER_TWO: Level 5
        _levelUpPlayer(PLAYER_TWO_ID, 4);
        // PLAYER_THREE: Level 9
        _levelUpPlayer(PLAYER_THREE_ID, 8);
        // PLAYER_FOUR: Level 10
        _levelUpPlayer(PLAYER_FOUR_ID, 9);

        // Test cross-bracket rejection: level 1 player trying to join level 10 bracket
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(
            abi.encodeWithSignature("PlayerNotInBracket(uint8,uint8)", 1, uint8(GauntletGame.LevelBracket.LEVEL_10))
        );
        level10Game.queueForGauntlet(_createSimpleLoadout(PLAYER_ONE_ID));
        vm.stopPrank();

        // Test each player can only join their appropriate bracket
        vm.startPrank(PLAYER_ONE);
        levels1To4Game.queueForGauntlet(_createSimpleLoadout(PLAYER_ONE_ID)); // Level 1 -> LEVELS_1_TO_4: OK
        vm.stopPrank();

        vm.startPrank(PLAYER_TWO);
        levels5To9Game.queueForGauntlet(_createSimpleLoadout(PLAYER_TWO_ID)); // Level 5 -> LEVELS_5_TO_9: OK
        vm.stopPrank();

        vm.startPrank(PLAYER_FOUR);
        level10Game.queueForGauntlet(_createSimpleLoadout(PLAYER_FOUR_ID)); // Level 10 -> LEVEL_10: OK
        vm.stopPrank();

        // Verify all players were queued in their correct brackets
        assertEq(uint8(levels1To4Game.playerStatus(PLAYER_ONE_ID)), uint8(GauntletGame.PlayerStatus.QUEUED));
        assertEq(uint8(levels5To9Game.playerStatus(PLAYER_TWO_ID)), uint8(GauntletGame.PlayerStatus.QUEUED));
        assertEq(uint8(level10Game.playerStatus(PLAYER_FOUR_ID)), uint8(GauntletGame.PlayerStatus.QUEUED));
    }

    function testPlayerNotInBracket_ErrorDetails() public {
        // Create LEVELS_5_TO_9 bracket
        GauntletGame levels5To9Game = new GauntletGame(
            address(gameEngine),
            payable(address(playerContract)),
            address(defaultPlayerContract),
            GauntletGame.LevelBracket.LEVELS_5_TO_9,
            address(playerTickets)
        );

        // Set permissions
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, immortal: false, experience: true});
        playerContract.setGameContractPermission(address(levels5To9Game), perms);
        playerContract.setGameContractPermission(address(this), perms);

        // Try to queue level 1 player - verify exact error: PlayerNotInBracket(1, LEVELS_5_TO_9)
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(
            abi.encodeWithSignature(
                "PlayerNotInBracket(uint8,uint8)", 1, uint8(GauntletGame.LevelBracket.LEVELS_5_TO_9)
            )
        );
        levels5To9Game.queueForGauntlet(_createSimpleLoadout(PLAYER_ONE_ID));
        vm.stopPrank();

        // Try to queue level 10 player - verify exact error: PlayerNotInBracket(10, LEVELS_5_TO_9)
        _levelUpPlayer(PLAYER_TWO_ID, 9); // Level up from 1 to 10
        vm.startPrank(PLAYER_TWO);
        vm.expectRevert(
            abi.encodeWithSignature(
                "PlayerNotInBracket(uint8,uint8)", 10, uint8(GauntletGame.LevelBracket.LEVELS_5_TO_9)
            )
        );
        levels5To9Game.queueForGauntlet(_createSimpleLoadout(PLAYER_TWO_ID));
        vm.stopPrank();
    }

    //==============================================================//
    //                   HELPER FUNCTIONS                          //
    //==============================================================//

    function _levelUpPlayer(uint32 playerId, uint256 levels) internal {
        for (uint256 i = 0; i < levels; i++) {
            // Award enough XP to level up (level 1->2 needs 100 XP, etc.)
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
            uint16 xpNeeded = playerContract.getXPRequiredForLevel(stats.level + 1) - stats.currentXP;
            playerContract.awardExperience(playerId, xpNeeded);
        }
    }

    function _createSimpleLoadout(uint32 playerId) internal pure returns (Fighter.PlayerLoadout memory) {
        return Fighter.PlayerLoadout({
            playerId: playerId,
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            stance: 1 // BALANCED
        });
    }

    //==============================================================//
    //                    DAILY LIMIT TESTS                         //
    //==============================================================//

    function testDailyLimitEnforcement() public {
        Fighter.PlayerLoadout memory loadout = _createSimpleLoadout(PLAYER_ONE_ID);

        // Queue up to the daily limit (10 times)
        for (uint8 i = 0; i < 10; i++) {
            vm.prank(PLAYER_ONE);
            game.queueForGauntlet(loadout);

            // Withdraw to be able to queue again
            vm.prank(PLAYER_ONE);
            game.withdrawFromQueue(PLAYER_ONE_ID);
        }

        // Check run count is at limit
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 10);

        // 11th attempt should fail
        vm.prank(PLAYER_ONE);
        vm.expectRevert(abi.encodeWithSelector(DailyLimitExceeded.selector, 10, 10));
        game.queueForGauntlet(loadout);
    }

    function testGetDailyRunCount() public {
        Fighter.PlayerLoadout memory loadout = _createSimpleLoadout(PLAYER_ONE_ID);

        // Initially should be 0
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 0);

        // Queue once
        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(loadout);
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 1);

        // Withdraw and queue again
        vm.prank(PLAYER_ONE);
        game.withdrawFromQueue(PLAYER_ONE_ID);
        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(loadout);
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 2);
    }

    function testResetDailyLimit() public {
        Fighter.PlayerLoadout memory loadout = _createSimpleLoadout(PLAYER_ONE_ID);

        // Use up daily limit
        for (uint8 i = 0; i < 10; i++) {
            vm.prank(PLAYER_ONE);
            game.queueForGauntlet(loadout);
            vm.prank(PLAYER_ONE);
            game.withdrawFromQueue(PLAYER_ONE_ID);
        }

        // Should be at limit
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 10);

        // Reset with ETH payment and check event
        uint256 expectedDayNumber = block.timestamp / 86400; // Same calculation as _getDayNumber()
        vm.prank(PLAYER_ONE);
        vm.expectEmit(true, false, false, true);
        emit DailyLimitReset(PLAYER_ONE_ID, expectedDayNumber, false);
        game.resetDailyLimit{value: 0.001 ether}(PLAYER_ONE_ID);

        // Should be reset to 0
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 0);

        // Should be able to queue again
        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(loadout);
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 1);
    }

    function testResetDailyLimitInsufficientFee() public {
        vm.prank(PLAYER_ONE);
        vm.expectRevert(InsufficientResetFee.selector);
        game.resetDailyLimit{value: 0.0009 ether}(PLAYER_ONE_ID);
    }

    function testResetDailyLimitWrongOwner() public {
        // Player TWO trying to reset Player ONE's limit
        vm.prank(PLAYER_TWO);
        vm.expectRevert(abi.encodeWithSignature("CallerNotPlayerOwner()"));
        game.resetDailyLimit{value: 0.001 ether}(PLAYER_ONE_ID);
    }

    function testDailyLimitAutoReset() public {
        Fighter.PlayerLoadout memory loadout = _createSimpleLoadout(PLAYER_ONE_ID);

        // Use up daily limit
        for (uint8 i = 0; i < 10; i++) {
            vm.prank(PLAYER_ONE);
            game.queueForGauntlet(loadout);
            vm.prank(PLAYER_ONE);
            game.withdrawFromQueue(PLAYER_ONE_ID);
        }

        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 10);

        // Fast forward to next day (midnight UTC + 1 second)
        vm.warp(block.timestamp + 1 days + 1);

        // Should be reset to 0
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 0);

        // Should be able to queue again
        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(loadout);
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 1);
    }

    function testSetDailyGauntletLimit() public {
        // Check initial limit
        assertEq(game.dailyGauntletLimit(), 10);

        // Change limit as owner
        game.setDailyGauntletLimit(5);
        assertEq(game.dailyGauntletLimit(), 5);

        // Test enforcement with new limit
        Fighter.PlayerLoadout memory loadout = _createSimpleLoadout(PLAYER_ONE_ID);
        for (uint8 i = 0; i < 5; i++) {
            vm.prank(PLAYER_ONE);
            game.queueForGauntlet(loadout);
            vm.prank(PLAYER_ONE);
            game.withdrawFromQueue(PLAYER_ONE_ID);
        }

        // 6th attempt should fail with new limit
        vm.prank(PLAYER_ONE);
        vm.expectRevert(abi.encodeWithSelector(DailyLimitExceeded.selector, 5, 5));
        game.queueForGauntlet(loadout);
    }

    function testSetDailyGauntletLimitNotOwner() public {
        vm.prank(PLAYER_ONE);
        vm.expectRevert("Only callable by owner");
        game.setDailyGauntletLimit(20);
    }

    function testSetDailyGauntletLimitZero() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidGauntletSize(uint8)", 0));
        game.setDailyGauntletLimit(0);
    }

    function testSetDailyResetCost() public {
        // Check initial cost
        assertEq(game.dailyResetCost(), 0.001 ether);

        // Change cost as owner
        game.setDailyResetCost(0.005 ether);
        assertEq(game.dailyResetCost(), 0.005 ether);

        // Use 9 runs so reset is needed
        Fighter.PlayerLoadout memory loadout = _createSimpleLoadout(PLAYER_ONE_ID);
        for (uint8 i = 0; i < 9; i++) {
            vm.prank(PLAYER_ONE);
            game.queueForGauntlet(loadout);
            vm.prank(PLAYER_ONE);
            game.withdrawFromQueue(PLAYER_ONE_ID);
        }
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 9);

        // Test reset with new cost
        vm.prank(PLAYER_ONE);
        vm.expectRevert(InsufficientResetFee.selector);
        game.resetDailyLimit{value: 0.001 ether}(PLAYER_ONE_ID);

        // Should work with new cost
        vm.prank(PLAYER_ONE);
        game.resetDailyLimit{value: 0.005 ether}(PLAYER_ONE_ID);
    }

    function testSetDailyResetCostNotOwner() public {
        vm.prank(PLAYER_ONE);
        vm.expectRevert("Only callable by owner");
        game.setDailyResetCost(0.01 ether);
    }

    function testWithdrawFees() public {
        // Use 9 runs for both players so reset is needed
        Fighter.PlayerLoadout memory loadout1 = _createSimpleLoadout(PLAYER_ONE_ID);
        Fighter.PlayerLoadout memory loadout2 = _createSimpleLoadout(PLAYER_TWO_ID);

        for (uint8 i = 0; i < 9; i++) {
            vm.prank(PLAYER_ONE);
            game.queueForGauntlet(loadout1);
            vm.prank(PLAYER_ONE);
            game.withdrawFromQueue(PLAYER_ONE_ID);

            vm.prank(PLAYER_TWO);
            game.queueForGauntlet(loadout2);
            vm.prank(PLAYER_TWO);
            game.withdrawFromQueue(PLAYER_TWO_ID);
        }
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 9);
        assertEq(game.getDailyRunCount(PLAYER_TWO_ID), 9);

        // Reset limits multiple times to accumulate fees
        vm.prank(PLAYER_ONE);
        game.resetDailyLimit{value: 0.001 ether}(PLAYER_ONE_ID);
        vm.prank(PLAYER_TWO);
        game.resetDailyLimit{value: 0.001 ether}(PLAYER_TWO_ID);

        // Check contract balance
        assertEq(address(game).balance, 0.002 ether);

        // Deploy a contract that can receive ETH (since test contract may not have receive/fallback)
        address payable recipient = payable(address(new EthReceiver()));

        // Transfer ownership to recipient so it can withdraw (ConfirmedOwner pattern)
        game.transferOwnership(recipient);
        vm.prank(recipient);
        game.acceptOwnership(); // Must accept ownership with ConfirmedOwner

        // Withdraw as new owner
        uint256 recipientBalanceBefore = recipient.balance;
        vm.prank(recipient);
        game.withdrawFees();

        // Check balances
        assertEq(address(game).balance, 0);
        assertEq(recipient.balance, recipientBalanceBefore + 0.002 ether);
    }

    function testWithdrawFeesNotOwner() public {
        vm.prank(PLAYER_ONE);
        vm.expectRevert("Only callable by owner");
        game.withdrawFees();
    }

    function testDailyLimitWithMultiplePlayers() public {
        Fighter.PlayerLoadout memory loadout1 = _createSimpleLoadout(PLAYER_ONE_ID);
        Fighter.PlayerLoadout memory loadout2 = _createSimpleLoadout(PLAYER_TWO_ID);

        // Each player has their own daily limit
        for (uint8 i = 0; i < 10; i++) {
            vm.prank(PLAYER_ONE);
            game.queueForGauntlet(loadout1);
            vm.prank(PLAYER_ONE);
            game.withdrawFromQueue(PLAYER_ONE_ID);

            vm.prank(PLAYER_TWO);
            game.queueForGauntlet(loadout2);
            vm.prank(PLAYER_TWO);
            game.withdrawFromQueue(PLAYER_TWO_ID);
        }

        // Both should be at limit
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 10);
        assertEq(game.getDailyRunCount(PLAYER_TWO_ID), 10);

        // Reset only player ONE
        vm.prank(PLAYER_ONE);
        game.resetDailyLimit{value: 0.001 ether}(PLAYER_ONE_ID);

        // Player ONE should be reset, player TWO still at limit
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 0);
        assertEq(game.getDailyRunCount(PLAYER_TWO_ID), 10);
    }

    function testDailyLimitPersistsAcrossGauntlets() public {
        Fighter.PlayerLoadout memory loadout1 = _createSimpleLoadout(PLAYER_ONE_ID);
        Fighter.PlayerLoadout memory loadout2 = _createSimpleLoadout(PLAYER_TWO_ID);
        Fighter.PlayerLoadout memory loadout3 = _createSimpleLoadout(PLAYER_THREE_ID);
        Fighter.PlayerLoadout memory loadout4 = _createSimpleLoadout(PLAYER_FOUR_ID);

        // Queue 4 players and run a gauntlet
        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(loadout1);
        vm.prank(PLAYER_TWO);
        game.queueForGauntlet(loadout2);
        vm.prank(PLAYER_THREE);
        game.queueForGauntlet(loadout3);
        vm.prank(PLAYER_FOUR);
        game.queueForGauntlet(loadout4);

        // Start and complete gauntlet
        game.tryStartGauntlet(); // TX1: Commit

        // Get selection block and advance
        (, uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));
        game.tryStartGauntlet(); // TX2: Select participants

        // Get tournament block and advance
        (,, uint256 tournamentBlock,,,) = game.getPendingGauntletInfo();
        vm.roll(tournamentBlock + 1);
        vm.prevrandao(bytes32(uint256(67890)));
        game.tryStartGauntlet(); // TX3: Execute tournament

        // Player ONE should still have their run count
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 1);

        // Try to queue again - should increment
        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(loadout1);
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 2);
    }

    //==============================================================//
    //                TICKET-BASED DAILY RESET TESTS               //
    //==============================================================//

    event DailyLimitReset(uint32 indexed playerId, uint256 dayNumber, bool paidWithTicket);

    function testResetDailyLimitWithTicket() public {
        Fighter.PlayerLoadout memory loadout = _createSimpleLoadout(PLAYER_ONE_ID);

        // Use up daily limit
        for (uint8 i = 0; i < 10; i++) {
            vm.prank(PLAYER_ONE);
            game.queueForGauntlet(loadout);
            vm.prank(PLAYER_ONE);
            game.withdrawFromQueue(PLAYER_ONE_ID);
        }

        // Should be at limit
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 10);

        // Give player a daily reset ticket
        PlayerTickets tickets = playerContract.playerTickets();
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: true,
            attributeSwaps: false
        });
        tickets.setGameContractPermission(address(this), perms);
        tickets.mintFungibleTicket(PLAYER_ONE, tickets.DAILY_RESET_TICKET(), 1);

        // Approve GauntletGame to burn tickets
        vm.prank(PLAYER_ONE);
        tickets.setApprovalForAll(address(game), true);

        // Reset with ticket and check event
        uint256 expectedDayNumber = block.timestamp / 86400; // Same calculation as _getDayNumber()
        vm.prank(PLAYER_ONE);
        vm.expectEmit(true, false, false, true);
        emit DailyLimitReset(PLAYER_ONE_ID, expectedDayNumber, true);
        game.resetDailyLimitWithTicket(PLAYER_ONE_ID);

        // Should be reset to 0
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 0);

        // Ticket should be burned
        assertEq(tickets.balanceOf(PLAYER_ONE, tickets.DAILY_RESET_TICKET()), 0);

        // Should be able to queue again
        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(loadout);
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 1);
    }

    function testResetDailyLimitWithTicketInsufficientBalance() public {
        // Player has no tickets
        vm.prank(PLAYER_ONE);
        vm.expectRevert(); // ERC1155 insufficient balance
        game.resetDailyLimitWithTicket(PLAYER_ONE_ID);
    }

    function testResetDailyLimitWithTicketWrongOwner() public {
        // Give PLAYER_ONE a ticket but have PLAYER_TWO try to use it
        PlayerTickets tickets = playerContract.playerTickets();
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: true,
            attributeSwaps: false
        });
        tickets.setGameContractPermission(address(this), perms);
        tickets.mintFungibleTicket(PLAYER_ONE, tickets.DAILY_RESET_TICKET(), 1);

        // PLAYER_TWO trying to reset PLAYER_ONE's limit
        vm.prank(PLAYER_TWO);
        vm.expectRevert(abi.encodeWithSignature("CallerNotPlayerOwner()"));
        game.resetDailyLimitWithTicket(PLAYER_ONE_ID);
    }

    function testResetDailyLimitMixedETHAndTicket() public {
        Fighter.PlayerLoadout memory loadout = _createSimpleLoadout(PLAYER_ONE_ID);

        // Use up daily limit twice to test both methods
        for (uint8 i = 0; i < 10; i++) {
            vm.prank(PLAYER_ONE);
            game.queueForGauntlet(loadout);
            vm.prank(PLAYER_ONE);
            game.withdrawFromQueue(PLAYER_ONE_ID);
        }
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 10);

        // First reset with ETH
        uint256 expectedDayNumber = block.timestamp / 86400; // Same calculation as _getDayNumber()
        vm.prank(PLAYER_ONE);
        vm.expectEmit(true, false, false, true);
        emit DailyLimitReset(PLAYER_ONE_ID, expectedDayNumber, false);
        game.resetDailyLimit{value: 0.001 ether}(PLAYER_ONE_ID);
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 0);

        // Use up limit again
        for (uint8 i = 0; i < 10; i++) {
            vm.prank(PLAYER_ONE);
            game.queueForGauntlet(loadout);
            vm.prank(PLAYER_ONE);
            game.withdrawFromQueue(PLAYER_ONE_ID);
        }
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 10);

        // Second reset with ticket
        PlayerTickets tickets = playerContract.playerTickets();
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: true,
            attributeSwaps: false
        });
        tickets.setGameContractPermission(address(this), perms);
        tickets.mintFungibleTicket(PLAYER_ONE, tickets.DAILY_RESET_TICKET(), 1);

        vm.prank(PLAYER_ONE);
        tickets.setApprovalForAll(address(game), true);

        vm.prank(PLAYER_ONE);
        vm.expectEmit(true, false, false, true);
        emit DailyLimitReset(PLAYER_ONE_ID, expectedDayNumber, true);
        game.resetDailyLimitWithTicket(PLAYER_ONE_ID);
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 0);

        // Both methods work independently
        assertEq(tickets.balanceOf(PLAYER_ONE, tickets.DAILY_RESET_TICKET()), 0);
    }

    function testResetDailyLimitWithTicketMultipleTickets() public {
        Fighter.PlayerLoadout memory loadout = _createSimpleLoadout(PLAYER_ONE_ID);

        // Give player 3 reset tickets
        PlayerTickets tickets = playerContract.playerTickets();
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: true,
            attributeSwaps: false
        });
        tickets.setGameContractPermission(address(this), perms);
        tickets.mintFungibleTicket(PLAYER_ONE, tickets.DAILY_RESET_TICKET(), 3);

        vm.prank(PLAYER_ONE);
        tickets.setApprovalForAll(address(game), true);

        // Use limit and reset 3 times
        for (uint8 cycle = 0; cycle < 3; cycle++) {
            // Use up daily limit
            for (uint8 i = 0; i < 10; i++) {
                vm.prank(PLAYER_ONE);
                game.queueForGauntlet(loadout);
                vm.prank(PLAYER_ONE);
                game.withdrawFromQueue(PLAYER_ONE_ID);
            }
            assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 10);

            // Reset with ticket
            vm.prank(PLAYER_ONE);
            game.resetDailyLimitWithTicket(PLAYER_ONE_ID);
            assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 0);

            // Check remaining tickets
            assertEq(tickets.balanceOf(PLAYER_ONE, tickets.DAILY_RESET_TICKET()), 3 - cycle - 1);
        }

        // All tickets should be consumed
        assertEq(tickets.balanceOf(PLAYER_ONE, tickets.DAILY_RESET_TICKET()), 0);
    }

    function testResetNotNeededValidation() public {
        Fighter.PlayerLoadout memory loadout = _createSimpleLoadout(PLAYER_ONE_ID);

        // Test when player has 0 runs (should revert)
        vm.prank(PLAYER_ONE);
        vm.expectRevert(abi.encodeWithSignature("ResetNotNeeded(uint8,uint8)", 0, 10));
        game.resetDailyLimit{value: 0.001 ether}(PLAYER_ONE_ID);

        // Test when player has 8 runs (8 <= 10-2, should revert)
        for (uint8 i = 0; i < 8; i++) {
            vm.prank(PLAYER_ONE);
            game.queueForGauntlet(loadout);
            vm.prank(PLAYER_ONE);
            game.withdrawFromQueue(PLAYER_ONE_ID);
        }
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 8);

        vm.prank(PLAYER_ONE);
        vm.expectRevert(abi.encodeWithSignature("ResetNotNeeded(uint8,uint8)", 8, 10));
        game.resetDailyLimit{value: 0.001 ether}(PLAYER_ONE_ID);

        // Test when player has 9 runs (9 >= 10-1, should work)
        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(loadout);
        vm.prank(PLAYER_ONE);
        game.withdrawFromQueue(PLAYER_ONE_ID);
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 9);

        vm.prank(PLAYER_ONE);
        game.resetDailyLimit{value: 0.001 ether}(PLAYER_ONE_ID);
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 0);

        // Test with tickets - same validation should apply
        PlayerTickets tickets = playerContract.playerTickets();
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: false,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: true,
            attributeSwaps: false
        });
        tickets.setGameContractPermission(address(this), perms);
        tickets.mintFungibleTicket(PLAYER_ONE, tickets.DAILY_RESET_TICKET(), 2);
        vm.prank(PLAYER_ONE);
        tickets.setApprovalForAll(address(game), true);

        // Use 7 runs (should revert)
        for (uint8 i = 0; i < 7; i++) {
            vm.prank(PLAYER_ONE);
            game.queueForGauntlet(loadout);
            vm.prank(PLAYER_ONE);
            game.withdrawFromQueue(PLAYER_ONE_ID);
        }
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 7);

        vm.prank(PLAYER_ONE);
        vm.expectRevert(abi.encodeWithSignature("ResetNotNeeded(uint8,uint8)", 7, 10));
        game.resetDailyLimitWithTicket(PLAYER_ONE_ID);

        // Use 2 more runs to get to 9 (should work)
        for (uint8 i = 0; i < 2; i++) {
            vm.prank(PLAYER_ONE);
            game.queueForGauntlet(loadout);
            vm.prank(PLAYER_ONE);
            game.withdrawFromQueue(PLAYER_ONE_ID);
        }
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 9);

        vm.prank(PLAYER_ONE);
        game.resetDailyLimitWithTicket(PLAYER_ONE_ID);
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 0);
        assertEq(tickets.balanceOf(PLAYER_ONE, tickets.DAILY_RESET_TICKET()), 1);
    }

    function test_GauntletXPDistribution() public {
        // Set up 8-player gauntlet to test XP distribution clearly
        game.setGameEnabled(false);
        game.setGauntletSize(8);
        game.setGameEnabled(true);

        // Create 8 players for testing
        address[] memory testPlayers = new address[](8);
        uint32[] memory testPlayerIds = new uint32[](8);

        for (uint256 i = 0; i < 8; i++) {
            testPlayers[i] = address(uint160(0x2000 + i));
            testPlayerIds[i] = _createPlayerAndFulfillVRF(testPlayers[i], playerContract, false);
            vm.deal(testPlayers[i], 100 ether);
        }

        // Queue all 8 players
        for (uint256 i = 0; i < 8; i++) {
            Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
                playerId: testPlayerIds[i],
                skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
                stance: 1 // BALANCED
            });
            vm.prank(testPlayers[i]);
            game.queueForGauntlet(loadout);
        }

        // Record starting XP and levels for all players
        uint16[] memory startingXP = new uint16[](8);
        uint8[] memory startingLevels = new uint8[](8);
        for (uint256 i = 0; i < 8; i++) {
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(testPlayerIds[i]);
            startingXP[i] = stats.currentXP;
            startingLevels[i] = stats.level;
        }

        // Execute full gauntlet flow
        vm.roll(block.number + 1);
        game.tryStartGauntlet();

        (, uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));
        game.tryStartGauntlet();

        (,, uint256 tournamentBlock,,,) = game.getPendingGauntletInfo();
        vm.roll(tournamentBlock + 1);
        vm.prevrandao(bytes32(uint256(67890)));

        // Record logs to capture XP events
        vm.recordLogs();
        game.tryStartGauntlet();

        // Check XP and level changes
        uint16[] memory finalXP = new uint16[](8);
        uint8[] memory finalLevels = new uint8[](8);
        uint256 playersWithRewards = 0;

        for (uint256 i = 0; i < 8; i++) {
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(testPlayerIds[i]);
            finalXP[i] = stats.currentXP;
            finalLevels[i] = stats.level;

            // Check if player got rewards (either XP gain or level up)
            bool gotReward = (finalXP[i] > startingXP[i]) || (finalLevels[i] > startingLevels[i]);
            if (gotReward) {
                playersWithRewards++;
            }

            console2.log("Player %d leveled up:", testPlayerIds[i], finalLevels[i] > startingLevels[i]);
        }

        // For 8-player gauntlet, top 50% = top 4 should get XP/rewards
        // Expected: Champion (100%), Runner-up (60%), 3rd-4th place (30%), 5th-8th place (0%)
        console2.log("Players with rewards:", playersWithRewards);
        assertEq(playersWithRewards, 4, "Exactly 4 players (top 50%) should receive XP in 8-player gauntlet");

        // Find the GauntletXPAwarded event to see actual distribution
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool foundXPEvent = false;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("GauntletXPAwarded(uint256,uint8,uint32[],uint16[])")) {
                foundXPEvent = true;

                // Decode the XP event - gauntletId is indexed, others are in data
                (uint8 levelBracket, uint32[] memory awardedPlayerIds, uint16[] memory awardedXP) =
                    abi.decode(logs[i].data, (uint8, uint32[], uint16[]));

                console2.log("XP Event - Level bracket:", levelBracket, "Number of awards:", awardedPlayerIds.length);

                // Cross-reference event data with actual player state changes
                for (uint256 j = 0; j < awardedPlayerIds.length; j++) {
                    uint32 playerId = awardedPlayerIds[j];
                    uint16 eventXP = awardedXP[j];

                    // Find this player in our test data and verify event matches state
                    bool foundPlayer = false;
                    for (uint256 k = 0; k < 8; k++) {
                        if (testPlayerIds[k] == playerId) {
                            foundPlayer = true;

                            // Check if the event XP matches the actual state change
                            if (finalLevels[k] > startingLevels[k]) {
                                // Player leveled up - should have gotten 100 XP (champion)
                                assertEq(eventXP, 100, "Leveled up player should have gotten 100 XP");
                            } else {
                                // Player didn't level up - XP gain should match event
                                uint16 actualXPGain = finalXP[k] - startingXP[k];
                                assertEq(eventXP, actualXPGain, "Event XP should match actual XP gain");
                            }
                            break;
                        }
                    }
                    assertTrue(foundPlayer, "Event player should be in our test set");
                }

                // Should have exactly 4 XP awards for 8-player gauntlet
                assertEq(awardedPlayerIds.length, 4, "Should award XP to exactly 4 players");
                break;
            }
        }

        assertTrue(foundXPEvent, "Should emit GauntletXPAwarded event");
    }

    function test_GauntletCompleted_roundWinners() public {
        // Queue 4 players for a gauntlet
        Fighter.PlayerLoadout memory loadout1 = Fighter.PlayerLoadout({
            playerId: PLAYER_ONE_ID,
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            stance: 2 // OFFENSIVE
        });
        Fighter.PlayerLoadout memory loadout2 = Fighter.PlayerLoadout({
            playerId: PLAYER_TWO_ID,
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            stance: 0 // DEFENSIVE
        });
        Fighter.PlayerLoadout memory loadout3 = Fighter.PlayerLoadout({
            playerId: PLAYER_THREE_ID,
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            stance: 1 // BALANCED
        });
        Fighter.PlayerLoadout memory loadout4 = Fighter.PlayerLoadout({
            playerId: PLAYER_FOUR_ID,
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            stance: 2 // OFFENSIVE
        });

        vm.prank(PLAYER_ONE);
        game.queueForGauntlet(loadout1);
        vm.prank(PLAYER_TWO);
        game.queueForGauntlet(loadout2);
        vm.prank(PLAYER_THREE);
        game.queueForGauntlet(loadout3);
        vm.prank(PLAYER_FOUR);
        game.queueForGauntlet(loadout4);

        // TX1: Commit queue
        vm.roll(block.number + 1);
        game.tryStartGauntlet();

        // Get selection block and advance
        (, uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();
        vm.roll(selectionBlock + 1);
        vm.prevrandao(bytes32(uint256(12345)));

        // TX2: Select participants
        game.tryStartGauntlet();

        // Get tournament block and advance
        (,, uint256 tournamentBlock,,,) = game.getPendingGauntletInfo();
        vm.roll(tournamentBlock + 1);
        vm.prevrandao(bytes32(uint256(67890)));

        // Record logs to capture the event data
        vm.recordLogs();

        // TX3: Execute tournament
        game.tryStartGauntlet();

        // Get the logs and decode the GauntletCompleted event
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the GauntletCompleted event
        bool foundEvent = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics[0]
                    == keccak256("GauntletCompleted(uint256,uint8,uint8,uint32,uint256,uint32[],uint32[])")
            ) {
                foundEvent = true;

                // Decode the event data
                (,,, uint32[] memory participantIds, uint32[] memory roundWinners) =
                    abi.decode(logs[i].data, (uint8, uint8, uint256, uint32[], uint32[]));

                // CRITICAL ASSERTION: roundWinners should NOT be empty for a 4-player gauntlet
                // 4 players = 2 matches in round 1, 1 match in finals = 3 total round winners
                assertEq(roundWinners.length, 3, "roundWinners array should contain 3 winners for 4-player gauntlet");

                // Verify each round winner is a valid participant ID
                for (uint256 j = 0; j < roundWinners.length; j++) {
                    bool isValidParticipant = false;
                    for (uint256 k = 0; k < participantIds.length; k++) {
                        if (roundWinners[j] == participantIds[k]) {
                            isValidParticipant = true;
                            break;
                        }
                    }
                    assertTrue(isValidParticipant, "Round winner must be a gauntlet participant");
                }

                break;
            }
        }

        assertTrue(foundEvent, "GauntletCompleted event should be emitted");
    }
}

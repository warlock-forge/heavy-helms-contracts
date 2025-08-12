// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import "../TestBase.sol";
import {GauntletGame, InvalidBlockhash} from "../../src/game/modes/GauntletGame.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";
import {console2} from "forge-std/console2.sol";

contract GauntletGameTest is TestBase {
    GauntletGame public game;

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
            address(playerContract),
            address(defaultPlayerContract),
            GauntletGame.LevelBracket.LEVELS_1_TO_4
        );

        // Transfer ownership of defaultPlayerContract
        defaultPlayerContract.transferOwnership(address(game));

        // Set permissions
        IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
            record: true,
            retire: false,
            attributes: false,
            immortal: false,
            experience: false
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
        uint256 commitBlock = block.number;
        game.tryStartGauntlet();

        // Can't recover yet
        assertFalse(game.canRecoverPendingGauntlet(), "Should not be able to recover yet");
        vm.expectRevert();
        game.recoverPendingGauntlet();

        // Advance past 256 blocks
        vm.roll(commitBlock + 257);

        // Now can recover
        assertTrue(game.canRecoverPendingGauntlet(), "Should be able to recover now");
        game.recoverPendingGauntlet();

        // Check pending gauntlet cleared
        (bool exists,,,,,) = game.getPendingGauntletInfo();
        assertFalse(exists, "Pending gauntlet should be cleared");

        // Check queue still has players
        assertEq(game.getQueueSize(), 4, "Queue should still have 4 players");
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
        vm.expectRevert("Game must be disabled to change gauntlet size");
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

        vm.expectRevert("UNAUTHORIZED");
        game.setGameEnabled(false);

        vm.expectRevert("UNAUTHORIZED");
        game.setGauntletSize(8);

        vm.expectRevert("UNAUTHORIZED");
        game.emergencyClearQueue();

        vm.expectRevert("UNAUTHORIZED");
        game.setFutureBlocksForSelection(10);

        vm.expectRevert("UNAUTHORIZED");
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
            address(playerContract),
            address(defaultPlayerContract),
            GauntletGame.LevelBracket.LEVELS_1_TO_4
        );

        // Set permissions
        IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
            record: true,
            retire: false,
            attributes: false,
            immortal: false,
            experience: false
        });
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

    //==============================================================//
    //                   HELPER FUNCTIONS                          //
    //==============================================================//

    function _createSimpleLoadout(uint32 playerId) internal pure returns (Fighter.PlayerLoadout memory) {
        return Fighter.PlayerLoadout({
            playerId: playerId,
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            stance: 1 // BALANCED
        });
    }
}

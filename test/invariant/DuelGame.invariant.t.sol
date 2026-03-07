// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {DuelGame} from "../../src/game/modes/DuelGame.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {DuelHandler} from "./handlers/DuelHandler.sol";

contract DuelGameInvariantTest is TestBase {
    DuelGame public game;
    DuelHandler public handler;

    uint32[] public pIds;
    address[] public pOwners;

    uint256 constant NUM_PLAYERS = 6;

    function setUp() public override {
        super.setUp();

        // Deploy duel game
        game = new DuelGame(
            address(gameEngine),
            payable(address(playerContract)),
            address(vrfCoordinator),
            uint256(1),
            bytes32(0),
            address(playerTickets)
        );

        // Disable gas protection so acceptChallenge works in tests
        game.setGasProtectionEnabled(false);

        // Grant game permissions on player contract
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, immortal: false, experience: true});
        playerContract.setGameContractPermission(address(game), perms);

        // Create player pool
        for (uint256 i = 0; i < NUM_PLAYERS; i++) {
            address owner = address(uint160(0x4001 + i));
            vm.deal(owner, 100 ether);
            uint32 playerId = _createPlayerAndFulfillVRF(owner, false);
            pIds.push(playerId);
            pOwners.push(owner);
        }

        // Deploy handler
        handler = new DuelHandler(game, playerContract, vrfCoordinator, pIds, pOwners);

        targetContract(address(handler));
    }

    //==============================================================//
    //                         INVARIANTS                           //
    //==============================================================//

    /// @notice nextChallengeId must always equal total challenges created
    function invariant_ChallengeIdMatchesCreated() public view {
        assertEq(
            game.nextChallengeId(),
            handler.ghost_totalChallengesCreated(),
            "nextChallengeId doesn't match total created"
        );
    }

    /// @notice Contract ETH balance must be >= ghost-tracked ETH paid
    function invariant_BalanceCoversETHFees() public view {
        assertGe(address(game).balance, handler.ghost_totalETHPaid(), "Contract balance less than ETH fees collected");
    }

    /// @notice Call summary for debugging
    function invariant_callSummary() public view {
        handler.calls_create();
        handler.calls_accept();
        handler.calls_fulfillVRF();
    }
}

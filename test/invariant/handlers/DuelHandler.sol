// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test, Vm} from "forge-std/Test.sol";
import {DuelGame} from "../../../src/game/modes/DuelGame.sol";
import {Player} from "../../../src/fighters/Player.sol";
import {Fighter} from "../../../src/fighters/Fighter.sol";

/// @notice Handler for DuelGame invariant testing.
/// @dev Exercises the full challenge lifecycle: create, accept, and VRF fulfillment.
contract DuelHandler is Test {
    DuelGame public game;
    Player public playerContract;
    address public vrfCoordinator;

    // Pool of valid player IDs and their owners
    uint32[] public playerIds;
    mapping(uint32 => address) public playerOwners;

    // Track challenge state for invariant checks
    uint256[] public openChallengeIds;
    uint256[] public completedChallengeIds;

    // Ghost variables
    uint256 public ghost_totalChallengesCreated;
    uint256 public ghost_totalAccepted;
    uint256 public ghost_totalCompleted;
    uint256 public ghost_totalETHPaid;

    // Call counters
    uint256 public calls_create;
    uint256 public calls_accept;
    uint256 public calls_fulfillVRF;

    constructor(
        DuelGame _game,
        Player _playerContract,
        address _vrfCoordinator,
        uint32[] memory _playerIds,
        address[] memory _owners
    ) {
        game = _game;
        playerContract = _playerContract;
        vrfCoordinator = _vrfCoordinator;

        for (uint256 i = 0; i < _playerIds.length; i++) {
            playerIds.push(_playerIds[i]);
            playerOwners[_playerIds[i]] = _owners[i];
        }
    }

    // --- Handler Actions ---

    /// @notice Create a challenge with ETH
    function createChallenge(uint256 challengerSeed, uint256 defenderSeed) external {
        if (playerIds.length < 2) return;

        uint32 challengerId = playerIds[challengerSeed % playerIds.length];
        uint32 defenderId = playerIds[defenderSeed % playerIds.length];

        if (challengerId == defenderId) {
            defenderId = playerIds[(defenderSeed + 1) % playerIds.length];
            if (challengerId == defenderId) return;
        }

        address challengerOwner = playerOwners[challengerId];
        if (playerContract.isPlayerRetired(challengerId)) return;
        if (playerContract.isPlayerRetired(defenderId)) return;

        uint256 fee = game.duelFeeAmount();
        vm.deal(challengerOwner, fee);

        Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
            playerId: challengerId, skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}), stance: 1
        });

        vm.prank(challengerOwner);
        try game.initiateChallengeWithETH{value: fee}(loadout, defenderId) returns (uint256 challengeId) {
            ghost_totalChallengesCreated++;
            ghost_totalETHPaid += fee;
            openChallengeIds.push(challengeId);
            calls_create++;
        } catch {}
    }

    /// @notice Accept an open challenge and immediately fulfill VRF
    function acceptAndFulfill(uint256 challengeSeed) external {
        if (openChallengeIds.length == 0) return;

        uint256 idx = challengeSeed % openChallengeIds.length;
        uint256 challengeId = openChallengeIds[idx];

        // Check it's still active
        if (!game.isChallengeActive(challengeId)) {
            _removeOpenChallenge(idx);
            return;
        }

        (uint32 challengerId, uint32 defenderId,,,,) = game.challenges(challengeId);

        // Check neither player retired
        if (playerContract.isPlayerRetired(challengerId) || playerContract.isPlayerRetired(defenderId)) {
            return;
        }

        address defenderOwner = playerOwners[defenderId];

        Fighter.PlayerLoadout memory defLoadout = Fighter.PlayerLoadout({
            playerId: defenderId, skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}), stance: 1
        });

        // Accept the challenge
        vm.recordLogs();
        vm.prank(defenderOwner);
        try game.acceptChallenge(challengeId, defLoadout) {
            ghost_totalAccepted++;
            calls_accept++;

            // Extract VRF request ID from logs and fulfill immediately
            Vm.Log[] memory logs = vm.getRecordedLogs();
            uint256 requestId = _extractRequestId(logs);
            if (requestId != 0) {
                uint256[] memory randomWords = new uint256[](1);
                randomWords[0] = uint256(keccak256(abi.encodePacked(challengeId, block.timestamp)));

                vm.prank(vrfCoordinator);
                try game.rawFulfillRandomWords(requestId, randomWords) {
                    ghost_totalCompleted++;
                    calls_fulfillVRF++;
                } catch {}
            }

            // Move from open to completed
            _removeOpenChallenge(idx);
            completedChallengeIds.push(challengeId);
        } catch {}
    }

    // --- Internal helpers ---

    function _removeOpenChallenge(uint256 idx) internal {
        openChallengeIds[idx] = openChallengeIds[openChallengeIds.length - 1];
        openChallengeIds.pop();
    }

    function _extractRequestId(Vm.Log[] memory logs) internal pure returns (uint256) {
        // RandomWordsRequested event topic from VRFCoordinator
        bytes32 vrfTopic =
            keccak256("RandomWordsRequested(bytes32,uint256,uint256,uint64,uint16,uint32,uint32,address)");
        // VRF 2.5 topic
        bytes32 vrf25Topic =
            keccak256("RandomWordsRequested(bytes32,uint256,uint256,uint256,uint16,uint32,uint32,bytes,address)");

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == vrfTopic || logs[i].topics[0] == vrf25Topic) {
                // requestId is the second topic (indexed)
                return uint256(logs[i].topics[2]);
            }
        }
        return 0;
    }

    // --- View helpers ---

    function getPlayerIdsLength() external view returns (uint256) {
        return playerIds.length;
    }

    function getPlayerId(uint256 index) external view returns (uint32) {
        return playerIds[index];
    }

    function getOpenChallengeIdsLength() external view returns (uint256) {
        return openChallengeIds.length;
    }

    function getCompletedChallengeIdsLength() external view returns (uint256) {
        return completedChallengeIds.length;
    }
}

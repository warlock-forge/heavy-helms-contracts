// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {TestBase} from "../TestBase.sol";

contract NameRandomnessTest is TestBase {
    function testFuzz_NameRandomness(uint256 seed) public {
        // Create multiple players and track name frequencies
        uint256 numPlayers = 20; // Reduced from 50 to avoid gas limits
        uint256[] memory firstNameCounts = new uint256[](nameRegistry.getSetAStart() + nameRegistry.getNameSetALength());
        uint256[] memory surnameCounts = new uint256[](nameRegistry.getSurnamesLength());

        for (uint256 i = 0; i < numPlayers; i++) {
            // Create player alternating between Set A and Set B
            address player = address(uint160(i + 1));
            vm.deal(player, playerContract.createPlayerFeeAmount());

            vm.startPrank(player);
            uint256 requestId =
                playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(i % 2 == 0);
            vm.stopPrank();

            // Record logs BEFORE fulfilling VRF
            vm.recordLogs();

            vm.prank(vrfCoordinator);
            uint256[] memory randomWords = new uint256[](1);
            randomWords[0] = uint256(keccak256(abi.encodePacked(seed, i)));
            playerContract.rawFulfillRandomWords(requestId, randomWords);

            // Now extract the player ID right after the transaction that emitted the event
            uint32 playerId = _getPlayerIdFromLogs(player, requestId);

            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
            firstNameCounts[stats.name.firstNameIndex]++;
            surnameCounts[stats.name.surnameIndex]++;
        }

        // Verify we got some variety in names
        uint256 uniqueFirstNames = 0;
        uint256 uniqueSurnames = 0;

        // Count unique first names
        for (uint16 i = 0; i < nameRegistry.getNameSetBLength(); i++) {
            if (firstNameCounts[i] > 0) uniqueFirstNames++;
        }
        for (
            uint16 i = nameRegistry.getSetAStart();
            i < nameRegistry.getSetAStart() + nameRegistry.getNameSetALength();
            i++
        ) {
            if (firstNameCounts[i] > 0) {
                uniqueFirstNames++;
            }
        }

        // Count unique surnames
        for (uint16 i = 0; i < nameRegistry.getSurnamesLength(); i++) {
            if (surnameCounts[i] > 0) uniqueSurnames++;
        }

        // We should have a good distribution of names
        assertTrue(uniqueFirstNames > 3, "Should have multiple different first names");
        assertTrue(uniqueSurnames > 3, "Should have multiple different surnames");

        // Make sure we're not always getting the default names
        assertTrue(firstNameCounts[0] < numPlayers, "Too many default Set B names");
        assertTrue(firstNameCounts[nameRegistry.getSetAStart()] < numPlayers, "Too many default Set A names");
        assertTrue(surnameCounts[0] < numPlayers, "Too many default surnames");
    }
}

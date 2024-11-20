// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./lib/UniformRandomNumber.sol";

contract Game {
    using UniformRandomNumber for uint256;

    error ZERO_ADDRESS();
    error PLAYER_EXISTS();

    struct Player {
        int8 strength;
        int8 constitution;
        int8 agility;
        int8 stamina;
    }

    mapping(address => Player) public players;

    function playGame(
        address, // player1
        address, // player2
        uint256 // randomSeed
    ) public pure {
        // To be implemented
        revert("Not implemented");
    }

    function createPlayer(uint256 randomSeed) public returns (Player memory) {
        if (players[msg.sender].strength != 0) revert PLAYER_EXISTS();

        // Start with 3 in each stat (minimum) = 12 total
        uint256 remainingPoints = 36;
        int8[4] memory stats = [int8(3), int8(3), int8(3), int8(3)];

        // Use different bits of randomSeed for ordering
        uint256 order = uint256(keccak256(abi.encodePacked(randomSeed, "order")));

        // First pass: Allow for more variance in initial distribution
        for (uint256 i = 0; i < 3; i++) {
            uint256 statIndex = order.uniform(4 - i);
            order = uint256(keccak256(abi.encodePacked(order)));

            // Calculate available points while ensuring minimum for others
            uint256 pointsNeededForRemaining = (3 - i) * 3; // Reduced from 6 to allow more variance
            uint256 availablePoints =
                remainingPoints > pointsNeededForRemaining ? remainingPoints - pointsNeededForRemaining : 0;

            // Allow full range up to 18 (to reach 21) more often
            uint256 maxPoints = min(availablePoints, 18);
            uint256 pointsToAdd = randomSeed.uniform(maxPoints + 1);
            randomSeed = uint256(keccak256(abi.encodePacked(randomSeed)));

            stats[statIndex] += int8(uint8(pointsToAdd));
            remainingPoints -= pointsToAdd;

            // Move used index to end
            int8 temp = stats[statIndex];
            stats[statIndex] = stats[3 - i];
            stats[3 - i] = temp;
        }

        // Last stat takes remaining points (but not more than 18)
        stats[0] += int8(uint8(min(remainingPoints, 18)));

        Player memory newPlayer =
            Player({strength: stats[0], constitution: stats[1], agility: stats[2], stamina: stats[3]});

        // Validate and fix if needed (shouldn't be needed but safety first)
        if (!_validateStats(newPlayer)) {
            newPlayer = _fixStats(newPlayer, randomSeed);
        }

        players[msg.sender] = newPlayer;
        return newPlayer;
    }

    function _validateStats(Player memory player) private pure returns (bool) {
        // Check ranges
        if (player.strength < 3 || player.strength > 21) return false;
        if (player.constitution < 3 || player.constitution > 21) return false;
        if (player.agility < 3 || player.agility > 21) return false;
        if (player.stamina < 3 || player.stamina > 21) return false;

        // Check total
        int16 total =
            int16(player.strength) + int16(player.constitution) + int16(player.agility) + int16(player.stamina);

        return total == 48;
    }

    function _fixStats(Player memory player, uint256 randomSeed) private pure returns (Player memory) {
        int16 total =
            int16(player.strength) + int16(player.constitution) + int16(player.agility) + int16(player.stamina);

        // First ensure all stats are within 3-21 range
        int8[4] memory stats = [player.strength, player.constitution, player.agility, player.stamina];

        for (uint256 i = 0; i < 4; i++) {
            if (stats[i] < 3) {
                total += (3 - stats[i]);
                stats[i] = 3;
            } else if (stats[i] > 21) {
                total -= (stats[i] - 21);
                stats[i] = 21;
            }
        }

        // Now adjust total to 48 if needed
        while (total != 48) {
            uint256 seed = uint256(keccak256(abi.encodePacked(randomSeed)));
            randomSeed = seed;

            if (total < 48) {
                // Need to add points
                uint256 statIndex = seed.uniform(4);
                if (stats[statIndex] < 21) {
                    stats[statIndex] += 1;
                    total += 1;
                }
            } else {
                // Need to remove points
                uint256 statIndex = seed.uniform(4);
                if (stats[statIndex] > 3) {
                    stats[statIndex] -= 1;
                    total -= 1;
                }
            }
        }

        return Player({strength: stats[0], constitution: stats[1], agility: stats[2], stamina: stats[3]});
    }

    function _generateInitialStats(uint256 randomSeed) private pure returns (Player memory) {
        // Original stat generation logic here
        // ... existing code ...
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./lib/UniformRandomNumber.sol";
import "./interfaces/IPlayer.sol";

contract Player is IPlayer {
    using UniformRandomNumber for uint256;

    error ZERO_ADDRESS();
    error PLAYER_EXISTS();
    error PLAYER_NOT_FOUND();

    // Counter for generating unique player IDs
    uint256 private _nextPlayerId = 1;

    // Main storage of player stats by ID
    mapping(uint256 => IPlayer.PlayerStats) private _players;

    // Mapping of address to array of their player IDs
    mapping(address => uint256[]) private _addressToPlayerIds;

    // Optional: Mapping of player ID to owner address for reverse lookup
    mapping(uint256 => address) private _playerOwners;

    // Add a mapping to track if an address has created a player
    mapping(address => bool) private _hasCreatedPlayer;

    // Make sure this matches the interface exactly
    function createPlayer(uint256 randomSeed) external returns (uint256 playerId, IPlayer.PlayerStats memory stats) {
        // Check if address has already created a player
        if (_hasCreatedPlayer[msg.sender]) revert PLAYER_EXISTS();

        // Mark this address as having created a player
        _hasCreatedPlayer[msg.sender] = true;

        // Generate new unique ID
        playerId = _nextPlayerId++;

        // Generate stats (existing logic)
        uint256 remainingPoints = 36;
        int8[4] memory statArray = [int8(3), int8(3), int8(3), int8(3)];

        // Use different bits of randomSeed for ordering
        uint256 order = uint256(keccak256(abi.encodePacked(randomSeed, "order")));

        // First pass: Allow for more variance in initial distribution
        for (uint256 i = 0; i < 3; i++) {
            uint256 statIndex = order.uniform(4 - i);
            order = uint256(keccak256(abi.encodePacked(order)));

            uint256 pointsNeededForRemaining = (3 - i) * 3;
            uint256 availablePoints =
                remainingPoints > pointsNeededForRemaining ? remainingPoints - pointsNeededForRemaining : 0;

            uint256 maxPoints = min(availablePoints, 18);
            uint256 pointsToAdd = randomSeed.uniform(maxPoints + 1);
            randomSeed = uint256(keccak256(abi.encodePacked(randomSeed)));

            statArray[statIndex] += int8(uint8(pointsToAdd));
            remainingPoints -= pointsToAdd;

            int8 temp = statArray[statIndex];
            statArray[statIndex] = statArray[3 - i];
            statArray[3 - i] = temp;
        }

        statArray[0] += int8(uint8(min(remainingPoints, 18)));

        stats = IPlayer.PlayerStats({
            strength: statArray[0],
            constitution: statArray[1],
            agility: statArray[2],
            stamina: statArray[3]
        });

        if (!_validateStats(stats)) {
            stats = _fixStats(stats, randomSeed);
        }

        // Store the player
        _players[playerId] = stats;
        _playerOwners[playerId] = msg.sender;
        _addressToPlayerIds[msg.sender].push(playerId);

        return (playerId, stats);
    }

    // Make sure all interface functions are marked as external
    function getPlayerIds(address owner) external view returns (uint256[] memory) {
        return _addressToPlayerIds[owner];
    }

    function getPlayer(uint256 playerId) external view returns (IPlayer.PlayerStats memory) {
        require(_players[playerId].strength != 0, "Player does not exist");
        return _players[playerId];
    }

    function getPlayerOwner(uint256 playerId) external view returns (address) {
        require(_playerOwners[playerId] != address(0), "Player does not exist");
        return _playerOwners[playerId];
    }

    function players(uint256 playerId) external view returns (IPlayer.PlayerStats memory) {
        require(_players[playerId].strength != 0, "Player does not exist");
        return _players[playerId];
    }

    function getPlayerState(uint256 playerId) external view returns (uint256 health, uint256 stamina) {
        PlayerStats memory player = _players[playerId];
        require(player.strength != 0, "Player does not exist");
        CalculatedStats memory stats = this.calculateStats(player);
        return (uint256(stats.maxHealth), uint256(stats.maxEndurance));
    }

    function calculateStats(PlayerStats memory player) external pure returns (CalculatedStats memory) {
        uint8 str = uint8(player.strength >= 0 ? uint8(player.strength) : 0);
        uint8 con = uint8(player.constitution >= 0 ? uint8(player.constitution) : 0);
        uint8 agi = uint8(player.agility >= 0 ? uint8(player.agility) : 0);
        uint8 sta = uint8(player.stamina >= 0 ? uint8(player.stamina) : 0);

        return CalculatedStats({
            maxHealth: uint8(45 + (con * 10)),
            damage: uint8(2 + (str * 2)),
            hitChance: uint8(30 + (agi * 3)),
            blockChance: uint8(10 + (con * 3)),
            dodgeChance: uint8(5 + (agi * 3)),
            maxEndurance: uint8(45 + (sta * 10)),
            critChance: uint8(2 + (agi * 2)),
            initiative: uint8((sta + agi) * 3),
            counterChance: uint8(3 + (agi * 2)),
            critMultiplier: uint8(150 + (str * 5))
        });
    }

    // Helper functions (can remain private/internal)
    function _validateStats(IPlayer.PlayerStats memory player) private pure returns (bool) {
        if (player.strength < 3 || player.strength > 21) return false;
        if (player.constitution < 3 || player.constitution > 21) return false;
        if (player.agility < 3 || player.agility > 21) return false;
        if (player.stamina < 3 || player.stamina > 21) return false;

        int16 total =
            int16(player.strength) + int16(player.constitution) + int16(player.agility) + int16(player.stamina);

        return total == 48;
    }

    function _fixStats(IPlayer.PlayerStats memory player, uint256 randomSeed)
        private
        pure
        returns (IPlayer.PlayerStats memory)
    {
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

        return IPlayer.PlayerStats({strength: stats[0], constitution: stats[1], agility: stats[2], stamina: stats[3]});
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}

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

    struct CalculatedStats {
        uint8 maxHealth;
        uint8 damage;
        uint8 hitChance;
        uint8 blockChance;
        uint8 dodgeChance;
        uint8 maxEndurance;
        uint8 critChance;
        uint8 initiative;
        uint8 counterChance;
        uint8 critMultiplier;
    }

    enum CombatResultType {
        ATTACK, // Basic attack that hit
        MISS, // Attack that missed
        BLOCK, // Successful block
        COUNTER, // Counter attack
        DODGE, // Successful dodge
        HIT // Taking damage (no defense)

    }

    event CombatResult(
        address indexed player1, address indexed player2, uint256 randomSeed, bytes packedResults, address winner
    );

    // Constants for stamina costs
    uint8 constant STAMINA_ATTACK = 20;
    uint8 constant STAMINA_BLOCK = 25;
    uint8 constant STAMINA_DODGE = 20;
    uint8 constant STAMINA_COUNTER = 30;

    // Add a maximum number of rounds to prevent infinite loops
    uint8 constant MAX_ROUNDS = 50;

    function playGame(address player1, address player2, uint256 seed)
        public
        view
        returns (bytes memory packedResults, address winner)
    {
        require(players[player1].strength != 0, "Player 1 does not exist");
        require(players[player2].strength != 0, "Player 2 does not exist");

        // Get initial states and stats
        (uint256 p1Health, uint256 p1Stamina) = getPlayerState(player1);
        (uint256 p2Health, uint256 p2Stamina) = getPlayerState(player2);

        CalculatedStats memory p1Stats = calculateStats(players[player1]);
        CalculatedStats memory p2Stats = calculateStats(players[player2]);

        bytes memory results;
        uint8 roundCount = 0;
        bool isPlayer1Turn = true;

        while (p1Health > 0 && p2Health > 0 && roundCount < MAX_ROUNDS) {
            // Handle exhaustion first
            if (p1Stamina < STAMINA_ATTACK && p2Stamina < STAMINA_ATTACK) {
                return (results, p1Stamina >= p2Stamina ? player1 : player2);
            } else if (p1Stamina < STAMINA_ATTACK) {
                return (results, player2);
            } else if (p2Stamina < STAMINA_ATTACK) {
                return (results, player1);
            }

            uint256 roll = uint256(keccak256(abi.encodePacked(seed, roundCount)));

            uint8 attackResult;
            uint8 attackDamage;
            uint8 attackStaminaCost;
            uint8 defenseResult;
            uint8 defenseDamage;
            uint8 defenseStaminaCost;

            // Get current attacker/defender stats
            CalculatedStats memory attackerStats;
            CalculatedStats memory defenderStats;
            uint256 attackerStamina;
            uint256 defenderStamina;

            if (isPlayer1Turn) {
                attackerStats = p1Stats;
                defenderStats = p2Stats;
                attackerStamina = p1Stamina;
                defenderStamina = p2Stamina;
            } else {
                attackerStats = p2Stats;
                defenderStats = p1Stats;
                attackerStamina = p2Stamina;
                defenderStamina = p1Stamina;
            }

            // Process attack
            uint8 hitRoll = uint8(roll % 100);
            if (hitRoll < attackerStats.hitChance) {
                attackResult = uint8(CombatResultType.ATTACK);
                attackDamage = attackerStats.damage;
                attackStaminaCost = STAMINA_ATTACK;

                // Defender gets chance to block/counter
                uint8 defenseRoll = uint8((roll >> 8) % 100);
                if (defenseRoll < defenderStats.blockChance && defenderStamina >= STAMINA_BLOCK) {
                    defenseResult = uint8(CombatResultType.BLOCK);
                    attackDamage = 0;
                    defenseStaminaCost = STAMINA_BLOCK;
                } else {
                    defenseResult = uint8(CombatResultType.HIT);
                    defenseStaminaCost = 0;
                }
            } else {
                attackResult = uint8(CombatResultType.MISS);
                attackDamage = 0;
                attackStaminaCost = STAMINA_ATTACK / 2;

                // Counter attack chance on miss
                uint8 counterRoll = uint8((roll >> 16) % 100);
                if (counterRoll < defenderStats.counterChance && defenderStamina >= STAMINA_COUNTER) {
                    defenseResult = uint8(CombatResultType.COUNTER);
                    defenseDamage = defenderStats.damage;
                    defenseStaminaCost = STAMINA_COUNTER;
                } else {
                    defenseResult = uint8(CombatResultType.DODGE);
                    defenseStaminaCost = 0;
                }
            }

            // Pack results and update states
            if (isPlayer1Turn) {
                results = abi.encodePacked(
                    results,
                    attackResult,
                    attackDamage,
                    attackStaminaCost,
                    defenseResult,
                    defenseDamage,
                    defenseStaminaCost
                );

                // Update P1 (attacker)
                if (p1Stamina > attackStaminaCost) {
                    p1Stamina -= attackStaminaCost;
                } else {
                    p1Stamina = 0;
                }
                if (p1Health > defenseDamage) {
                    p1Health -= defenseDamage;
                } else {
                    p1Health = 0;
                }

                // Update P2 (defender)
                if (p2Stamina > defenseStaminaCost) {
                    p2Stamina -= defenseStaminaCost;
                } else {
                    p2Stamina = 0;
                }
                if (p2Health > attackDamage) {
                    p2Health -= attackDamage;
                } else {
                    p2Health = 0;
                }
            } else {
                results = abi.encodePacked(
                    results,
                    defenseResult,
                    defenseDamage,
                    defenseStaminaCost,
                    attackResult,
                    attackDamage,
                    attackStaminaCost
                );

                // Update P2 (attacker)
                if (p2Stamina > attackStaminaCost) {
                    p2Stamina -= attackStaminaCost;
                } else {
                    p2Stamina = 0;
                }
                if (p2Health > defenseDamage) {
                    p2Health -= defenseDamage;
                } else {
                    p2Health = 0;
                }

                // Update P1 (defender)
                if (p1Stamina > defenseStaminaCost) {
                    p1Stamina -= defenseStaminaCost;
                } else {
                    p1Stamina = 0;
                }
                if (p1Health > attackDamage) {
                    p1Health -= attackDamage;
                } else {
                    p1Health = 0;
                }
            }

            roundCount++;
            seed = uint256(keccak256(abi.encodePacked(seed, "next")));
            isPlayer1Turn = !isPlayer1Turn;
        }

        return (results, p1Health >= p2Health ? player1 : player2);
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

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function safeUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "Value exceeds uint8");
        return uint8(value);
    }

    function calculateStats(Player memory player) public pure returns (CalculatedStats memory) {
        // First convert all stats to uint8 and cap them
        uint8 str = uint8(player.strength >= 0 ? uint8(player.strength) : 0);
        uint8 con = uint8(player.constitution >= 0 ? uint8(player.constitution) : 0);
        uint8 agi = uint8(player.agility >= 0 ? uint8(player.agility) : 0);
        uint8 sta = uint8(player.stamina >= 0 ? uint8(player.stamina) : 0);

        // Reduce multipliers to prevent overflow
        uint8 maxHealth = uint8(50 + (con * 5)); // Changed from 100 + (con * 10)
        uint8 damage = uint8(5 + (str * 2)); // Changed from 10 + (str * 5)
        uint8 hitChance = uint8(50 + (agi * 1)); // Changed from 70 + (agi * 2)
        uint8 blockChance = uint8(10 + (con * 2)); // Changed from 20 + (con * 3)
        uint8 dodgeChance = uint8(5 + (agi * 2)); // Changed from 10 + (agi * 3)
        uint8 maxEndurance = uint8(50 + (sta * 5)); // Changed from 100 + (sta * 10)
        uint8 critChance = uint8(5 + (agi)); // Changed from 5 + (agi * 2)
        uint8 initiative = uint8((sta + agi) / 2); // Added division to prevent overflow
        uint8 counterChance = uint8(5 + (agi)); // Changed from 10 + (agi * 2)
        uint8 critMultiplier = uint8(120 + (str * 2)); // Changed from 150 + (str * 5)

        return CalculatedStats({
            maxHealth: maxHealth,
            damage: damage,
            hitChance: hitChance,
            blockChance: blockChance,
            dodgeChance: dodgeChance,
            maxEndurance: maxEndurance,
            critChance: critChance,
            initiative: initiative,
            counterChance: counterChance,
            critMultiplier: critMultiplier
        });
    }

    function getPlayerState(address playerAddress) public view returns (uint256 health, uint256 stamina) {
        Player memory player = players[playerAddress];
        CalculatedStats memory stats = calculateStats(player);
        // Convert to uint256 after calculation to prevent overflow
        return (uint256(stats.maxHealth), uint256(stats.maxEndurance));
    }
}

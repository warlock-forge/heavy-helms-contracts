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
        MISS, // 0
        ATTACK, // 1
        BLOCK, // 2
        COUNTER, // 3
        DODGE, // 4
        HIT // 5

    }

    enum WinCondition {
        HEALTH, // Won by reducing opponent's health to 0
        EXHAUSTION, // Won because opponent couldn't attack (low stamina)
        MAX_ROUNDS // Won by having more health after max rounds

    }

    event CombatResult(
        address indexed player1, address indexed player2, uint256 randomSeed, bytes packedResults, address winner
    );

    // Further reduced stamina costs
    uint8 public constant STAMINA_ATTACK = 10; // Was 15
    uint8 constant STAMINA_BLOCK = 12; // Was 18
    uint8 constant STAMINA_DODGE = 8; // Was 12
    uint8 constant STAMINA_COUNTER = 15; // Was 20

    // Add a maximum number of rounds to prevent infinite loops
    uint8 constant MAX_ROUNDS = 50;

    // Add this struct to hold just the combat data
    struct CombatAction {
        CombatResultType p1Result;
        uint8 p1Damage;
        uint8 p1StaminaLost;
        CombatResultType p2Result;
        uint8 p2Damage;
        uint8 p2StaminaLost;
    }

    // Add at contract level with other structs
    struct CombatState {
        uint256 p1Health;
        uint256 p2Health;
        uint256 p1Stamina;
        uint256 p2Stamina;
        bool isPlayer1Turn;
        uint8 winner;
        WinCondition condition;
    }

    /// @notice Splits combat results bytes into structured format
    /// @param results The packed combat results bytes (first byte = winner, second byte = condition, remaining = combat actions)
    /// @return winner 1 for player1 wins, 2 for player2 wins
    /// @return condition The win condition (HEALTH, EXHAUSTION, or MAX_ROUNDS)
    /// @return actions Array of combat actions
    function decodeCombatLog(bytes memory results)
        public
        pure
        returns (uint8 winner, WinCondition condition, CombatAction[] memory actions)
    {
        require(results.length >= 2, "Results too short");

        // Extract winner and condition from first two bytes
        winner = uint8(results[0]);
        condition = WinCondition(uint8(results[1]));

        // Decode remaining combat actions
        uint256 numActions = (results.length - 2) / 6;
        actions = new CombatAction[](numActions);

        for (uint256 i = 0; i < numActions; i++) {
            uint256 offset = 2 + (i * 6); // Start after winner/condition
            actions[i] = CombatAction({
                p1Result: CombatResultType(uint8(results[offset])),
                p1Damage: uint8(results[offset + 1]),
                p1StaminaLost: uint8(results[offset + 2]),
                p2Result: CombatResultType(uint8(results[offset + 3])),
                p2Damage: uint8(results[offset + 4]),
                p2StaminaLost: uint8(results[offset + 5])
            });
        }

        return (winner, condition, actions);
    }

    function playGame(address player1, address player2, uint256 seed) public view returns (bytes memory) {
        require(players[player1].strength != 0, "Player 1 does not exist");
        require(players[player2].strength != 0, "Player 2 does not exist");

        // Initialize combat state
        CombatState memory state;
        (state.p1Health, state.p1Stamina) = getPlayerState(player1);
        (state.p2Health, state.p2Stamina) = getPlayerState(player2);

        CalculatedStats memory p1Stats = calculateStats(players[player1]);
        CalculatedStats memory p2Stats = calculateStats(players[player2]);

        // Keep existing initiative logic, just store in state
        if (p1Stats.initiative != p2Stats.initiative) {
            uint8 initiativeDiff = p1Stats.initiative > p2Stats.initiative
                ? p1Stats.initiative - p2Stats.initiative
                : p2Stats.initiative - p1Stats.initiative;

            uint16 scaledDiff = uint16(initiativeDiff) * 19;
            uint8 upsetChance = 20 - uint8(scaledDiff / 126);

            bool naturalOrder = p1Stats.initiative > p2Stats.initiative;
            uint8 randomRoll = uint8(uint256(keccak256(abi.encodePacked(seed, "initiative"))).uniform(100));

            state.isPlayer1Turn = randomRoll < upsetChance ? !naturalOrder : naturalOrder;
        } else {
            state.isPlayer1Turn = uint256(keccak256(abi.encodePacked(seed, "initiative"))).uniform(2) == 0;
        }

        bytes memory results;
        uint8 roundCount = 0;

        while (state.p1Health > 0 && state.p2Health > 0 && roundCount < MAX_ROUNDS) {
            // Check for exhaustion
            uint8 MINIMUM_ACTION_COST = 5; // Even lower than dodge cost

            if ((state.p1Stamina < MINIMUM_ACTION_COST) || (state.p2Stamina < MINIMUM_ACTION_COST)) {
                state.condition = WinCondition.EXHAUSTION;
                if (state.p1Stamina < MINIMUM_ACTION_COST && state.p2Stamina < MINIMUM_ACTION_COST) {
                    state.winner = uint256(keccak256(abi.encodePacked(seed, "exhaust"))).uniform(2) == 0 ? 1 : 2;
                } else {
                    state.winner = state.p1Stamina < MINIMUM_ACTION_COST ? 2 : 1;
                }
                break;
            }

            uint256 roll = uint256(keccak256(abi.encodePacked(seed, roundCount)));

            uint8 attackResult;
            uint8 attackDamage;
            uint8 attackStaminaCost;
            uint8 defenseResult;
            uint8 defenseDamage;
            uint8 defenseStaminaCost;

            CalculatedStats memory attackerStats;
            CalculatedStats memory defenderStats;
            uint256 attackerStamina;
            uint256 defenderStamina;

            if (state.isPlayer1Turn) {
                attackerStats = p1Stats;
                defenderStats = p2Stats;
                attackerStamina = state.p1Stamina;
                defenderStamina = state.p2Stamina;
            } else {
                attackerStats = p2Stats;
                defenderStats = p1Stats;
                attackerStamina = state.p2Stamina;
                defenderStamina = state.p1Stamina;
            }

            uint8 hitRoll = uint8(roll % 100);
            if (hitRoll < attackerStats.hitChance) {
                attackResult = uint8(CombatResultType.ATTACK);
                attackDamage = attackerStats.damage;
                attackStaminaCost = STAMINA_ATTACK;

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
                attackStaminaCost = STAMINA_ATTACK / 3;

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

            if (state.isPlayer1Turn) {
                results = abi.encodePacked(
                    results,
                    attackResult,
                    attackDamage,
                    attackStaminaCost,
                    defenseResult,
                    defenseDamage,
                    defenseStaminaCost
                );

                state.p1Stamina = state.p1Stamina > attackStaminaCost ? state.p1Stamina - attackStaminaCost : 0;
                state.p1Health = state.p1Health > defenseDamage ? state.p1Health - defenseDamage : 0;

                state.p2Stamina = state.p2Stamina > defenseStaminaCost ? state.p2Stamina - defenseStaminaCost : 0;
                state.p2Health = state.p2Health > attackDamage ? state.p2Health - attackDamage : 0;
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

                state.p2Stamina = state.p2Stamina > attackStaminaCost ? state.p2Stamina - attackStaminaCost : 0;
                state.p2Health = state.p2Health > defenseDamage ? state.p2Health - defenseDamage : 0;

                state.p1Stamina = state.p1Stamina > defenseStaminaCost ? state.p1Stamina - defenseStaminaCost : 0;
                state.p1Health = state.p1Health > attackDamage ? state.p1Health - attackDamage : 0;
            }

            roundCount++;
            seed = uint256(keccak256(abi.encodePacked(seed, "next")));
            state.isPlayer1Turn = !state.isPlayer1Turn;

            if (state.p1Health == 0 || state.p2Health == 0) {
                state.condition = WinCondition.HEALTH;
                break;
            }
        }

        if (roundCount >= MAX_ROUNDS) {
            state.condition = WinCondition.MAX_ROUNDS;
        }

        // Set winner based on health
        state.winner = state.p1Health >= state.p2Health ? 1 : 2;

        // Pack winner and condition at start, then combat results
        return abi.encodePacked(bytes1(state.winner), bytes1(uint8(state.condition)), results);
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

        // Adjusted formulas to stay within uint8 range (max 255)
        uint8 maxHealth = uint8(45 + (con * 10)); // Max: 255 health at 21 CON
        uint8 damage = uint8(2 + (str * 2)); // Max: 44 damage at 21 STR
        uint8 hitChance = uint8(30 + (agi * 3)); // Max: 93% at 21 AGI
        uint8 blockChance = uint8(10 + (con * 3)); // Max: 73% at 21 CON
        uint8 dodgeChance = uint8(5 + (agi * 3)); // Max: 68% at 21 AGI
        uint8 maxEndurance = uint8(45 + (sta * 10)); // Max: 255 endurance at 21 STA
        uint8 critChance = uint8(2 + (agi * 2)); // Max: 44% at 21 AGI
        uint8 initiative = uint8((sta + agi) * 3); // Max: 126 at 21/21
        uint8 counterChance = uint8(3 + (agi * 2)); // Max: 45% at 21 AGI
        uint8 critMultiplier = uint8(150 + (str * 5)); // Max: 255% at 21 STR

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

    // Helper function to convert uint to string
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

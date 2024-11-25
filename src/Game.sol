// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./lib/UniformRandomNumber.sol";
import "./interfaces/IPlayer.sol";

contract Game {
    using UniformRandomNumber for uint256;

    IPlayer public playerContract;

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
        uint256 indexed player1Id,
        uint256 indexed player2Id,
        uint256 randomSeed,
        bytes packedResults,
        uint256 winningPlayerId
    );

    // Further reduced stamina costs
    uint8 public constant STAMINA_ATTACK = 10; // Was 15
    uint8 constant STAMINA_BLOCK = 12; // Was 18
    uint8 constant STAMINA_DODGE = 8; // Was 12
    uint8 constant STAMINA_COUNTER = 15; // Was 20

    // Add a maximum number of rounds to prevent infinite loops
    uint8 constant MAX_ROUNDS = 50;

    struct CombatAction {
        CombatResultType p1Result;
        uint16 p1Damage;
        uint8 p1StaminaLost;
        CombatResultType p2Result;
        uint16 p2Damage;
        uint8 p2StaminaLost;
    }

    struct CombatState {
        uint256 p1Health;
        uint256 p2Health;
        uint256 p1Stamina;
        uint256 p2Stamina;
        bool isPlayer1Turn;
        uint256 winner;
        WinCondition condition;
    }

    constructor(address _playerContract) {
        playerContract = IPlayer(_playerContract);
    }

    function decodeCombatLog(bytes memory results)
        public
        pure
        returns (uint256 winningPlayerId, WinCondition condition, CombatAction[] memory actions)
    {
        require(results.length >= 2, "Results too short");

        // Header is simple uint8 values
        winningPlayerId = uint8(results[0]);
        condition = WinCondition(uint8(results[1]));

        uint256 numActions = (results.length - 2) / 8;
        actions = new CombatAction[](numActions);

        for (uint256 i = 0; i < numActions; i++) {
            uint256 base = 2 + (i * 8);

            // Read each byte as a uint8 directly
            uint8 p1Result = uint8(results[base + 0]);
            uint8 p1DamageHigh = uint8(results[base + 1]);
            uint8 p1DamageLow = uint8(results[base + 2]);
            uint8 p1Stamina = uint8(results[base + 3]);
            uint8 p2Result = uint8(results[base + 4]);
            uint8 p2DamageHigh = uint8(results[base + 5]);
            uint8 p2DamageLow = uint8(results[base + 6]);
            uint8 p2Stamina = uint8(results[base + 7]);

            // Validate before creating the action
            require(p1Result <= uint8(CombatResultType.HIT), "Invalid P1 result value");
            require(p2Result <= uint8(CombatResultType.HIT), "Invalid P2 result value");

            actions[i] = CombatAction({
                p1Result: CombatResultType(p1Result),
                p1Damage: (uint16(p1DamageHigh) << 8) | uint16(p1DamageLow),
                p1StaminaLost: p1Stamina,
                p2Result: CombatResultType(p2Result),
                p2Damage: (uint16(p2DamageHigh) << 8) | uint16(p2DamageLow),
                p2StaminaLost: p2Stamina
            });
        }

        return (winningPlayerId, condition, actions);
    }

    function playGame(uint256 player1Id, uint256 player2Id, uint256 seed) public view returns (bytes memory) {
        // Get player stats from Player contract
        IPlayer.PlayerStats memory p1Stats = playerContract.getPlayer(player1Id);
        IPlayer.PlayerStats memory p2Stats = playerContract.getPlayer(player2Id);

        // Initialize combat state
        CombatState memory state;
        (state.p1Health, state.p1Stamina) = playerContract.getPlayerState(player1Id);
        (state.p2Health, state.p2Stamina) = playerContract.getPlayerState(player2Id);

        IPlayer.CalculatedStats memory p1CalcStats = playerContract.calculateStats(p1Stats);
        IPlayer.CalculatedStats memory p2CalcStats = playerContract.calculateStats(p2Stats);

        // Keep existing initiative logic, just store in state
        if (p1CalcStats.initiative != p2CalcStats.initiative) {
            uint16 initiativeDiff = uint16(
                p1CalcStats.initiative > p2CalcStats.initiative
                    ? p1CalcStats.initiative - p2CalcStats.initiative
                    : p2CalcStats.initiative - p1CalcStats.initiative
            );

            uint8 upsetChance = uint8(min(20, (20 * initiativeDiff) / 255));

            bool naturalOrder = p1CalcStats.initiative > p2CalcStats.initiative;
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
            uint16 attackDamage;
            uint8 attackStaminaCost;
            uint8 defenseResult;
            uint16 defenseDamage;
            uint8 defenseStaminaCost;

            IPlayer.CalculatedStats memory attackerStats;
            IPlayer.CalculatedStats memory defenderStats;
            uint256 attackerStamina;
            uint256 defenderStamina;

            if (state.isPlayer1Turn) {
                attackerStats = p1CalcStats;
                defenderStats = p2CalcStats;
                attackerStamina = state.p1Stamina;
                defenderStamina = state.p2Stamina;
            } else {
                attackerStats = p2CalcStats;
                defenderStats = p1CalcStats;
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
                    uint8(attackResult),
                    uint8(attackDamage >> 8),
                    uint8(attackDamage),
                    uint8(attackStaminaCost),
                    uint8(defenseResult),
                    uint8(defenseDamage >> 8),
                    uint8(defenseDamage),
                    uint8(defenseStaminaCost)
                );

                state.p1Stamina = state.p1Stamina > attackStaminaCost ? state.p1Stamina - attackStaminaCost : 0;
                state.p2Health = state.p2Health > attackDamage ? state.p2Health - attackDamage : 0;

                state.p2Stamina = state.p2Stamina > defenseStaminaCost ? state.p2Stamina - defenseStaminaCost : 0;
                state.p1Health = state.p1Health > defenseDamage ? state.p1Health - defenseDamage : 0;
            } else {
                results = abi.encodePacked(
                    results,
                    uint8(defenseResult),
                    uint8(defenseDamage >> 8),
                    uint8(defenseDamage),
                    uint8(defenseStaminaCost),
                    uint8(attackResult),
                    uint8(attackDamage >> 8),
                    uint8(attackDamage),
                    uint8(attackStaminaCost)
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
        if (state.p1Health == 0) {
            state.winner = 2; // Player 2 wins by KO
        } else if (state.p2Health == 0) {
            state.winner = 1; // Player 1 wins by KO
        } else {
            // If no KO, higher health wins
            state.winner = state.p1Health > state.p2Health ? 1 : 2;
        }

        // Pack winner and condition at start, then combat results
        return abi.encodePacked(bytes1(uint8(state.winner)), bytes1(uint8(state.condition)), results);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function applyDamage(uint256 currentHealth, uint16 damage) private pure returns (uint256) {
        return currentHealth > damage ? currentHealth - damage : 0;
    }
}

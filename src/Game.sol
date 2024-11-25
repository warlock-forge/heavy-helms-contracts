// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./lib/UniformRandomNumber.sol";
import "./interfaces/IPlayer.sol";
import "solmate/src/auth/Owned.sol";

contract Game is Owned {
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

    // Stamina costs
    uint8 public constant STAMINA_ATTACK = 10; // Was 15
    uint8 public constant STAMINA_BLOCK = 12; // Was 18
    uint8 public constant STAMINA_DODGE = 8; // Was 12
    uint8 public constant STAMINA_COUNTER = 15; // Was 20

    // Maximum rounds
    uint8 public constant MAX_ROUNDS = 50;

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

    uint256 public entryFee;

    constructor(address _playerContract) Owned(msg.sender) {
        playerContract = IPlayer(_playerContract);
        entryFee = 0.001 ether;
    }

    // Function to set the entry fee, restricted to the owner
    function setEntryFee(uint256 _entryFee) external onlyOwner {
        entryFee = _entryFee;
    }

    // Reusable method to generate a pseudo-random seed
    function _generatePseudoRandomSeed(uint256 player1Id, uint256 player2Id) private view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(block.number - 1), block.prevrandao, block.timestamp, player1Id, player2Id, msg.sender
                )
            )
        );
    }

    function practiceGame(uint256 player1Id, uint256 player2Id) public view returns (bytes memory) {
        uint256 pseudoRandomSeed = _generatePseudoRandomSeed(player1Id, player2Id);
        return playGameInternal(player1Id, player2Id, pseudoRandomSeed);
    }

    // Placeholder for VRF request logic
    function requestRandomSeedFromVRF() private view returns (uint256) {
        // Implement VRF request logic here
        // This is a placeholder and should be replaced with actual VRF integration
        return uint256(keccak256(abi.encodePacked(block.timestamp)));
    }

    // Public method for official games
    function officialGame(uint256 player1Id, uint256 player2Id) public payable returns (bytes memory) {
        require(msg.value >= entryFee, "Insufficient entry fee");

        // Trigger VRF to get a random seed
        uint256 vrfSeed = requestRandomSeedFromVRF();

        // This function should be called after receiving the VRF response
        return playGameInternal(player1Id, player2Id, vrfSeed);
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

            // First cast to uint16 before shifting to prevent overflow
            uint16 p1DamageHigh = uint16(uint8(results[base + 1]));
            uint16 p1DamageLow = uint16(uint8(results[base + 2]));
            uint16 p2DamageHigh = uint16(uint8(results[base + 5]));
            uint16 p2DamageLow = uint16(uint8(results[base + 6]));

            actions[i] = CombatAction({
                p1Result: CombatResultType(uint8(results[base + 0])),
                p1Damage: (p1DamageHigh << 8) | p1DamageLow,
                p1StaminaLost: uint8(results[base + 3]),
                p2Result: CombatResultType(uint8(results[base + 4])),
                p2Damage: (p2DamageHigh << 8) | p2DamageLow,
                p2StaminaLost: uint8(results[base + 7])
            });
        }

        return (winningPlayerId, condition, actions);
    }

    function processCombatTurn(
        IPlayer.CalculatedStats memory attacker,
        IPlayer.CalculatedStats memory defender,
        uint256, /* attackerStamina */
        uint256 defenderStamina,
        uint256 roll
    )
        private
        pure
        returns (
            uint8 attackResult,
            uint16 attackDamage,
            uint8 attackStaminaCost,
            uint8 defenseResult,
            uint16 defenseDamage,
            uint8 defenseStaminaCost
        )
    {
        uint8 hitRoll = uint8(roll % 100);
        uint8 critRoll = uint8((roll >> 24) % 100);

        if (hitRoll < attacker.hitChance) {
            attackResult = uint8(CombatResultType.ATTACK);
            attackDamage = calculateDamage(attacker.damageModifier);

            // Apply crit multiplier as a percentage
            if (critRoll < attacker.critChance) {
                // critMultiplier is already a percentage (100 = 100%)
                attackDamage = uint16((uint32(attackDamage) * uint32(attacker.critMultiplier)) / 100);
            }

            attackStaminaCost = STAMINA_ATTACK;

            (defenseResult, defenseDamage, defenseStaminaCost) =
                processDefense(defender, defenderStamina, uint8((roll >> 8) % 100));
        } else {
            (attackResult, attackDamage, attackStaminaCost) = processMiss();
            (defenseResult, defenseDamage, defenseStaminaCost) =
                processCounter(defender, defenderStamina, uint8((roll >> 16) % 100));
        }
    }

    function processDefense(IPlayer.CalculatedStats memory defenderStats, uint256 defenderStamina, uint8 defenseRoll)
        private
        pure
        returns (uint8 result, uint16 damage, uint8 staminaCost)
    {
        if (defenseRoll < defenderStats.blockChance && defenderStamina >= STAMINA_BLOCK) {
            return (uint8(CombatResultType.BLOCK), 0, STAMINA_BLOCK);
        } else {
            return (uint8(CombatResultType.HIT), 0, 0);
        }
    }

    function processMiss() private pure returns (uint8 result, uint16 damage, uint8 staminaCost) {
        return (uint8(CombatResultType.MISS), 0, STAMINA_ATTACK / 3);
    }

    function processCounter(IPlayer.CalculatedStats memory defenderStats, uint256 defenderStamina, uint8 counterRoll)
        private
        pure
        returns (uint8 result, uint16 damage, uint8 staminaCost)
    {
        if (counterRoll < defenderStats.counterChance && defenderStamina >= STAMINA_COUNTER) {
            return (uint8(CombatResultType.COUNTER), calculateDamage(defenderStats.damageModifier), STAMINA_COUNTER);
        } else {
            return (uint8(CombatResultType.DODGE), 0, 0);
        }
    }

    // Private method to handle the game logic
    function playGameInternal(uint256 player1Id, uint256 player2Id, uint256 seed) private view returns (bytes memory) {
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

            (
                uint8 attackResult,
                uint16 attackDamage,
                uint8 attackStaminaCost,
                uint8 defenseResult,
                uint16 defenseDamage,
                uint8 defenseStaminaCost
            ) = processCombatTurn(
                state.isPlayer1Turn ? p1CalcStats : p2CalcStats,
                state.isPlayer1Turn ? p2CalcStats : p1CalcStats,
                state.isPlayer1Turn ? state.p1Stamina : state.p2Stamina,
                state.isPlayer1Turn ? state.p2Stamina : state.p1Stamina,
                roll
            );

            // Pack results and update state
            if (state.isPlayer1Turn) {
                results = abi.encodePacked(
                    results,
                    attackResult,
                    uint8(attackDamage >> 8),
                    uint8(attackDamage),
                    attackStaminaCost,
                    defenseResult,
                    uint8(defenseDamage >> 8),
                    uint8(defenseDamage),
                    defenseStaminaCost
                );

                state.p1Stamina = state.p1Stamina > attackStaminaCost ? state.p1Stamina - attackStaminaCost : 0;
                state.p2Health = applyDamage(state.p2Health, attackDamage);
                state.p2Stamina = state.p2Stamina > defenseStaminaCost ? state.p2Stamina - defenseStaminaCost : 0;
                state.p1Health = applyDamage(state.p1Health, defenseDamage);
            } else {
                results = abi.encodePacked(
                    results,
                    defenseResult,
                    uint8(defenseDamage >> 8),
                    uint8(defenseDamage),
                    defenseStaminaCost,
                    attackResult,
                    uint8(attackDamage >> 8),
                    uint8(attackDamage),
                    attackStaminaCost
                );

                state.p2Stamina = state.p2Stamina > attackStaminaCost ? state.p2Stamina - attackStaminaCost : 0;
                state.p1Health = applyDamage(state.p1Health, defenseDamage);
                state.p1Stamina = state.p1Stamina > defenseStaminaCost ? state.p1Stamina - defenseStaminaCost : 0;
                state.p2Health = applyDamage(state.p2Health, attackDamage);
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

    function calculateDamage(uint16 damageModifier) private pure returns (uint16) {
        // Base damage range: 10-20
        uint16 baseDamage = 10;

        // Apply modifier (as percentage)
        // damageModifier is treated as percentage (100 = 100%)
        uint32 calculatedDamage = (uint32(baseDamage) * uint32(damageModifier)) / 100;

        // Ensure we don't exceed uint16
        return calculatedDamage > type(uint16).max ? type(uint16).max : uint16(calculatedDamage);
    }
}

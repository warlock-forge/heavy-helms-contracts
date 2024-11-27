// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IGameEngine.sol";
import "./interfaces/IPlayer.sol";
import "./GameStats.sol";
import "./lib/UniformRandomNumber.sol";
import "./PlayerSkinRegistry.sol";

contract GameEngine is IGameEngine {
    using UniformRandomNumber for uint256;

    enum CombatResultType {
        MISS, // 0 - Complete miss, some stamina cost
        ATTACK, // 1 - Normal successful attack
        CRIT, // 2 - Critical hit
        BLOCK, // 3 - Successfully blocked attack
        COUNTER, // 4 - Counter attack after block/dodge
        COUNTER_CRIT, // 5 - Critical counter attack
        DODGE, // 6 - Successfully dodged attack
        PARRY, // 7 - Successfully parried attack
        RIPOSTE, // 8 - Counter attack after parry
        RIPOSTE_CRIT, // 9 - Critical counter after parry
        EXHAUSTED, // 10 - Failed due to stamina
        HIT // 11 - Taking full damage (failed defense)

    }

    enum WinCondition {
        HEALTH, // Won by reducing opponent's health to 0
        EXHAUSTION, // Won because opponent couldn't attack (low stamina)
        MAX_ROUNDS // Won by having more health after max rounds

    }

    // Combat-related constants
    uint8 public constant STAMINA_ATTACK = 8;
    uint8 public constant STAMINA_BLOCK = 5;
    uint8 public constant STAMINA_DODGE = 4;
    uint8 public constant STAMINA_COUNTER = 6;
    uint8 public constant MAX_ROUNDS = 50;
    uint8 public constant MINIMUM_ACTION_COST = 3;
    uint8 public constant PARRY_DAMAGE_REDUCTION = 50;
    uint8 public constant STAMINA_PARRY = 5;

    uint32 private constant MAX_UINT16 = type(uint16).max;

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

    function processGame(
        PlayerLoadout memory player1,
        PlayerLoadout memory player2,
        uint256 seed,
        IPlayer playerContract,
        GameStats gameStats,
        PlayerSkinRegistry skinRegistry
    ) external view override returns (bytes memory) {
        return playGameInternal(player1, player2, seed, playerContract, gameStats, skinRegistry);
    }

    function playGameInternal(
        PlayerLoadout memory player1,
        PlayerLoadout memory player2,
        uint256 seed,
        IPlayer playerContract,
        GameStats gameStats,
        PlayerSkinRegistry skinRegistry
    ) private view returns (bytes memory) {
        // Get player stats and skin attributes
        IPlayer.PlayerStats memory p1Stats = playerContract.getPlayer(player1.playerId);
        IPlayer.PlayerStats memory p2Stats = playerContract.getPlayer(player2.playerId);

        // Get skin attributes for both players
        (IPlayerSkinNFT.WeaponType p1Weapon, IPlayerSkinNFT.ArmorType p1Armor, IPlayerSkinNFT.FightingStance p1Stance) =
            getSkinAttributes(player1.skinIndex, player1.skinTokenId, skinRegistry);
        (IPlayerSkinNFT.WeaponType p2Weapon, IPlayerSkinNFT.ArmorType p2Armor, IPlayerSkinNFT.FightingStance p2Stance) =
            getSkinAttributes(player2.skinIndex, player2.skinTokenId, skinRegistry);

        // Get full combat stats including weapon, armor, and stance modifiers
        (
            GameStats.WeaponStats memory p1WeaponStats,
            GameStats.ArmorStats memory p1ArmorStats,
            GameStats.StanceMultiplier memory p1StanceStats
        ) = gameStats.getFullCharacterStats(p1Weapon, p1Armor, p1Stance);
        (
            GameStats.WeaponStats memory p2WeaponStats,
            GameStats.ArmorStats memory p2ArmorStats,
            GameStats.StanceMultiplier memory p2StanceStats
        ) = gameStats.getFullCharacterStats(p2Weapon, p2Armor, p2Stance);

        IPlayer.CalculatedStats memory p1CalcStats = playerContract.calculateStats(p1Stats);
        IPlayer.CalculatedStats memory p2CalcStats = playerContract.calculateStats(p2Stats);

        // Apply stance modifiers to calculated stats
        p1CalcStats = applyStanceModifiers(p1CalcStats, p1StanceStats);
        p2CalcStats = applyStanceModifiers(p2CalcStats, p2StanceStats);

        CombatState memory state = initializeCombatState(
            player1,
            player2,
            seed,
            p1CalcStats,
            p2CalcStats,
            p1WeaponStats,
            p1ArmorStats,
            p2WeaponStats,
            p2ArmorStats,
            playerContract
        );

        bytes memory results;
        uint8 roundCount = 0;
        uint256 currentSeed = seed;

        while (state.p1Health > 0 && state.p2Health > 0 && roundCount < MAX_ROUNDS) {
            // Check exhaustion first
            if (checkExhaustion(state, currentSeed, p1Stance, p2Stance, gameStats)) {
                break;
            }

            // Get new random seed
            currentSeed = uint256(keccak256(abi.encodePacked(currentSeed)));

            // Process round and update state
            (currentSeed, results) = processRound(
                state,
                currentSeed,
                results,
                roundCount,
                p1CalcStats,
                p2CalcStats,
                p1WeaponStats,
                p2WeaponStats,
                p1ArmorStats,
                p2ArmorStats,
                p1Stance,
                p2Stance,
                gameStats
            );

            roundCount++;
            state.isPlayer1Turn = !state.isPlayer1Turn;
        }

        if (roundCount >= MAX_ROUNDS) {
            state.condition = WinCondition.MAX_ROUNDS;
            state.winner = state.p1Health >= state.p2Health ? 1 : 2;
        }

        return encodeCombatResults(state, results);
    }

    function initializeCombatState(
        PlayerLoadout memory player1,
        PlayerLoadout memory player2,
        uint256 seed,
        IPlayer.CalculatedStats memory p1CalcStats,
        IPlayer.CalculatedStats memory p2CalcStats,
        GameStats.WeaponStats memory p1WeaponStats,
        GameStats.ArmorStats memory p1ArmorStats,
        GameStats.WeaponStats memory p2WeaponStats,
        GameStats.ArmorStats memory p2ArmorStats,
        IPlayer playerContract
    ) private view returns (CombatState memory state) {
        (state.p1Health, state.p1Stamina) = playerContract.getPlayerState(player1.playerId);
        (state.p2Health, state.p2Stamina) = playerContract.getPlayerState(player2.playerId);

        // Calculate effective initiative (90% equipment, 10% stats)
        uint32 p1EquipmentInit = (p1WeaponStats.attackSpeed * 100) / p1ArmorStats.weight;
        uint32 p2EquipmentInit = (p2WeaponStats.attackSpeed * 100) / p2ArmorStats.weight;

        uint32 p1TotalInit = ((p1EquipmentInit * 90) + (uint32(p1CalcStats.initiative) * 10)) / 100;
        uint32 p2TotalInit = ((p2EquipmentInit * 90) + (uint32(p2CalcStats.initiative) * 10)) / 100;

        // Simple deterministic check with tiebreaker
        if (p1TotalInit == p2TotalInit) {
            state.isPlayer1Turn = seed.uniform(2) == 0; // Only use random for exact ties
        } else {
            state.isPlayer1Turn = p1TotalInit > p2TotalInit;
        }

        return state;
    }

    function checkExhaustion(
        CombatState memory state,
        uint256 currentSeed,
        IPlayerSkinNFT.FightingStance p1Stance,
        IPlayerSkinNFT.FightingStance p2Stance,
        GameStats gameStats
    ) private view returns (bool) {
        uint256 p1MinCost = calculateStaminaCost(MINIMUM_ACTION_COST, p1Stance, gameStats);
        uint256 p2MinCost = calculateStaminaCost(MINIMUM_ACTION_COST, p2Stance, gameStats);

        if ((state.p1Stamina < p1MinCost) || (state.p2Stamina < p2MinCost)) {
            state.condition = WinCondition.EXHAUSTION;
            if (state.p1Stamina < p1MinCost && state.p2Stamina < p2MinCost) {
                state.winner = currentSeed.uniform(2) == 0 ? 1 : 2;
            } else {
                state.winner = state.p1Stamina < p1MinCost ? 2 : 1;
            }
            return true;
        }
        return false;
    }

    function processRound(
        CombatState memory state,
        uint256 currentSeed,
        bytes memory results,
        uint8 _roundCount,
        IPlayer.CalculatedStats memory p1CalcStats,
        IPlayer.CalculatedStats memory p2CalcStats,
        GameStats.WeaponStats memory p1WeaponStats,
        GameStats.WeaponStats memory p2WeaponStats,
        GameStats.ArmorStats memory p1ArmorStats,
        GameStats.ArmorStats memory p2ArmorStats,
        IPlayerSkinNFT.FightingStance p1Stance,
        IPlayerSkinNFT.FightingStance p2Stance,
        GameStats gameStats
    ) private view returns (uint256, bytes memory) {
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
            state.isPlayer1Turn ? p1WeaponStats : p2WeaponStats,
            state.isPlayer1Turn ? p2WeaponStats : p1WeaponStats,
            state.isPlayer1Turn ? p2ArmorStats : p1ArmorStats,
            currentSeed,
            state.isPlayer1Turn ? p1Stance : p2Stance,
            state.isPlayer1Turn ? p2Stance : p1Stance,
            gameStats
        );

        // Update combat state based on results
        updateCombatState(
            state, attackResult, attackDamage, attackStaminaCost, defenseResult, defenseDamage, defenseStaminaCost
        );

        // Append results to combat log
        results = appendCombatAction(
            results, attackResult, attackDamage, attackStaminaCost, defenseResult, defenseDamage, defenseStaminaCost
        );

        return (currentSeed, results);
    }

    function processCombatTurn(
        IPlayer.CalculatedStats memory attacker,
        IPlayer.CalculatedStats memory defender,
        uint256 attackerStamina,
        uint256 defenderStamina,
        GameStats.WeaponStats memory attackerWeapon,
        GameStats.WeaponStats memory defenderWeapon,
        GameStats.ArmorStats memory defenderArmor,
        uint256 roll,
        IPlayerSkinNFT.FightingStance attackerStance,
        IPlayerSkinNFT.FightingStance defenderStance,
        GameStats gameStats
    )
        private
        view
        returns (
            uint8 attackResult,
            uint16 attackDamage,
            uint8 attackStaminaCost,
            uint8 defenseResult,
            uint16 defenseDamage,
            uint8 defenseStaminaCost
        )
    {
        // SAFER: Adjust hit chance calculation
        uint32 baseHitChance = uint32(attacker.hitChance);
        uint32 weaponSpeedMod = uint32(attackerWeapon.attackSpeed);
        uint32 adjustedHitChance = (baseHitChance * weaponSpeedMod) / 100;

        // Ensure we don't overflow uint8 for the hit roll comparison
        uint8 finalHitChance = uint8(min(adjustedHitChance, type(uint8).max));
        uint8 hitRoll = uint8(roll % 100);
        roll = uint256(keccak256(abi.encodePacked(roll)));
        uint8 critRoll = uint8(roll % 100);
        roll = uint256(keccak256(abi.encodePacked(roll)));
        uint8 defenseRoll = uint8(roll % 100);
        roll = uint256(keccak256(abi.encodePacked(roll)));
        uint8 counterRoll = uint8(roll % 100);

        if (hitRoll < finalHitChance) {
            attackResult = uint8(CombatResultType.ATTACK);
            attackDamage = calculateDamage(attacker.damageModifier, attackerWeapon, roll);

            // Calculate stamina cost with stance modifier
            uint256 modifiedStaminaCost = calculateStaminaCost(STAMINA_ATTACK, attackerStance, gameStats);
            attackStaminaCost = uint8(modifiedStaminaCost);

            (defenseResult, defenseDamage, defenseStaminaCost) = processDefense(
                defender,
                defenderStamina,
                defenseRoll,
                defenderWeapon,
                defenderArmor,
                attackDamage,
                attackerWeapon.damageType,
                roll,
                defenderStance,
                gameStats
            );
        } else {
            (attackResult, attackDamage, attackStaminaCost) = processMiss(attackerStance, gameStats);
            (defenseResult, defenseDamage, defenseStaminaCost) = processCounter(
                defender, defenderStamina, counterRoll, defenderWeapon, defenderArmor, roll, defenderStance, gameStats
            );
        }
    }

    function processDefense(
        IPlayer.CalculatedStats memory defenderStats,
        uint256 defenderStamina,
        uint256 defenseRoll,
        GameStats.WeaponStats memory defenderWeapon,
        GameStats.ArmorStats memory defenderArmor,
        uint16 incomingDamage,
        GameStats.DamageType damageType,
        uint256 seed,
        IPlayerSkinNFT.FightingStance stance,
        GameStats gameStats
    ) private view returns (uint8 result, uint16 damage, uint8 staminaCost) {
        // Generate fresh seeds for each defensive check
        uint256 parryRoll = uint256(keccak256(abi.encodePacked(seed, "parry"))) % 100;
        uint256 blockRoll = uint256(keccak256(abi.encodePacked(seed, "block"))) % 100;
        uint256 dodgeRoll = uint256(keccak256(abi.encodePacked(seed, "dodge"))) % 100;

        // Get stance multipliers
        GameStats.StanceMultiplier memory stanceMods = gameStats.getStanceMultiplier(stance);

        // Calculate stamina costs with stance modifiers
        uint256 parryStaminaCost = (STAMINA_PARRY * stanceMods.staminaCostModifier) / 100;
        uint256 blockStaminaCost = (STAMINA_BLOCK * stanceMods.staminaCostModifier) / 100;
        uint256 dodgeStaminaCost = (STAMINA_DODGE * stanceMods.staminaCostModifier) / 100;

        // Apply stance modifiers to defensive chances
        uint16 effectiveParryChance = uint16(
            (uint32(defenderStats.parryChance) * uint32(stanceMods.parryChance) * uint32(defenderWeapon.parryChance))
                / 10000
        );
        uint16 effectiveBlockChance = uint16((uint32(defenderStats.blockChance) * uint32(stanceMods.blockChance)) / 100);
        uint16 effectiveDodgeChance = uint16((uint32(defenderStats.dodgeChance) * uint32(stanceMods.dodgeChance)) / 100);

        // Check parry first
        if (parryRoll < effectiveParryChance && defenderStamina >= parryStaminaCost) {
            uint256 riposteRoll = uint256(keccak256(abi.encodePacked(seed, "riposte"))) % 100;
            uint16 effectiveRiposteChance =
                uint16((uint32(defenderStats.counterChance) * uint32(defenderWeapon.riposteChance)) / 100);

            if (riposteRoll < effectiveRiposteChance && defenderStamina >= parryStaminaCost + STAMINA_COUNTER) {
                uint16 riposteDamage = calculateDamage(defenderStats.damageModifier, defenderWeapon, seed);
                return (uint8(CombatResultType.RIPOSTE), riposteDamage, uint8(parryStaminaCost + STAMINA_COUNTER));
            }
            return (uint8(CombatResultType.PARRY), 0, uint8(parryStaminaCost));
        }

        // Check block second
        if (blockRoll < effectiveBlockChance && defenderStamina >= blockStaminaCost) {
            uint256 counterRoll = uint256(keccak256(abi.encodePacked(seed, "counter"))) % 100;
            uint16 effectiveCounterChance =
                uint16((uint32(defenderStats.counterChance) * uint32(stanceMods.counterChance)) / 100);

            if (counterRoll < effectiveCounterChance && defenderStamina >= blockStaminaCost + STAMINA_COUNTER) {
                uint16 counterDamage = calculateDamage(defenderStats.damageModifier, defenderWeapon, seed);
                return (uint8(CombatResultType.COUNTER), counterDamage, uint8(blockStaminaCost + STAMINA_COUNTER));
            }
            return (uint8(CombatResultType.BLOCK), 0, uint8(blockStaminaCost));
        }

        // Check dodge last
        if (dodgeRoll < effectiveDodgeChance && defenderStamina >= dodgeStaminaCost) {
            return (uint8(CombatResultType.DODGE), 0, uint8(dodgeStaminaCost));
        }

        // If all defensive actions fail, apply armor reduction
        uint16 reducedDamage = applyDefensiveStats(incomingDamage, defenderArmor, damageType);
        return (uint8(CombatResultType.HIT), reducedDamage, 0);
    }

    function processMiss(IPlayerSkinNFT.FightingStance stance, GameStats gameStats)
        private
        view
        returns (uint8 result, uint16 damage, uint8 staminaCost)
    {
        uint256 modifiedStaminaCost = calculateStaminaCost(STAMINA_ATTACK / 3, stance, gameStats);
        return (uint8(CombatResultType.MISS), 0, uint8(modifiedStaminaCost));
    }

    function processCounter(
        IPlayer.CalculatedStats memory defenderStats,
        uint256 defenderStamina,
        uint8 counterRoll,
        GameStats.WeaponStats memory defenderWeapon,
        GameStats.ArmorStats memory defenderArmor,
        uint256 seed,
        IPlayerSkinNFT.FightingStance stance,
        GameStats gameStats
    ) private view returns (uint8 result, uint16 damage, uint8 staminaCost) {
        uint256 counterStaminaCost = calculateStaminaCost(STAMINA_COUNTER, stance, gameStats);

        if (counterRoll < defenderStats.counterChance && defenderStamina >= counterStaminaCost) {
            return (
                uint8(CombatResultType.COUNTER),
                calculateDamage(defenderStats.damageModifier, defenderWeapon, seed),
                uint8(counterStaminaCost)
            );
        } else {
            return (uint8(CombatResultType.DODGE), 0, uint8(counterStaminaCost));
        }
    }

    function getSkinAttributes(uint32 skinIndex, uint16 skinTokenId, PlayerSkinRegistry skinRegistry)
        private
        view
        returns (IPlayerSkinNFT.WeaponType weapon, IPlayerSkinNFT.ArmorType armor, IPlayerSkinNFT.FightingStance stance)
    {
        // Get the skin contract address from the registry using the collection ID
        PlayerSkinRegistry.SkinInfo memory skinInfo = skinRegistry.getSkin(skinIndex);

        // Get the attributes from the skin contract using the token ID
        IPlayerSkinNFT.SkinAttributes memory attrs =
            IPlayerSkinNFT(skinInfo.contractAddress).getSkinAttributes(skinTokenId);

        return (attrs.weapon, attrs.armor, attrs.stance);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function applyDamage(uint256 currentHealth, uint16 damage) private pure returns (uint256) {
        // No need for overflow check since currentHealth is uint256
        return currentHealth > damage ? currentHealth - damage : 0;
    }

    function calculateDamage(uint16 damageModifier, GameStats.WeaponStats memory weapon, uint256 seed)
        private
        pure
        returns (uint16)
    {
        // SAFER: First ensure the weapon range calculation is safe
        uint32 damageRange = weapon.maxDamage >= weapon.minDamage ? weapon.maxDamage - weapon.minDamage : 0;

        // SAFER: Calculate base damage with overflow protection
        uint32 baseDamage = uint32(weapon.minDamage) + uint32(seed % (damageRange + 1));

        // SAFER: Scale up early to maintain precision
        uint32 scaledBase = baseDamage * 100;
        uint32 modifiedDamage = (scaledBase * uint32(damageModifier)) / 10000;

        return modifiedDamage > type(uint16).max ? type(uint16).max : uint16(modifiedDamage);
    }

    function applyDefensiveStats(
        uint16 incomingDamage,
        GameStats.ArmorStats memory armor,
        GameStats.DamageType damageType
    ) private pure returns (uint16) {
        // Apply resistance first for better scaling
        uint16 resistance = getResistanceForDamageType(armor, damageType);
        resistance = resistance > 100 ? 100 : resistance;

        uint32 scaledDamage = uint32(incomingDamage) * 100;
        uint32 afterResistance = (scaledDamage * uint32(100 - resistance)) / 10000;

        // Then apply flat reduction
        if (afterResistance <= armor.defense * 100) {
            return 0;
        }
        uint32 finalDamage = afterResistance - (armor.defense * 100);

        return finalDamage > type(uint16).max ? type(uint16).max : uint16(finalDamage / 100);
    }

    function safePercentage(uint32 value, uint32 percentage) private pure returns (uint32) {
        require(percentage <= 10000, "Percentage exceeds maximum");
        return (value * percentage) / 10000;
    }

    function getResistanceForDamageType(GameStats.ArmorStats memory armor, GameStats.DamageType damageType)
        private
        pure
        returns (uint16)
    {
        if (damageType == GameStats.DamageType.Slashing) {
            return armor.slashResist;
        } else if (damageType == GameStats.DamageType.Piercing) {
            return armor.pierceResist;
        } else if (damageType == GameStats.DamageType.Blunt) {
            return armor.bluntResist;
        }
        return 0;
    }

    // Add new function to apply stance modifiers
    function applyStanceModifiers(IPlayer.CalculatedStats memory stats, GameStats.StanceMultiplier memory stance)
        private
        pure
        returns (IPlayer.CalculatedStats memory)
    {
        return IPlayer.CalculatedStats({
            maxHealth: stats.maxHealth,
            maxEndurance: stats.maxEndurance,
            initiative: stats.initiative,
            hitChance: uint16((uint32(stats.hitChance) * uint32(stance.hitChance)) / 100),
            dodgeChance: uint16((uint32(stats.dodgeChance) * uint32(stance.dodgeChance)) / 100),
            blockChance: uint16((uint32(stats.blockChance) * uint32(stance.blockChance)) / 100),
            parryChance: uint16((uint32(stats.parryChance) * uint32(stance.parryChance)) / 100),
            critChance: uint16((uint32(stats.critChance) * uint32(stance.critChance)) / 100),
            critMultiplier: uint16((uint32(stats.critMultiplier) * uint32(stance.critMultiplier)) / 100),
            counterChance: uint16((uint32(stats.counterChance) * uint32(stance.counterChance)) / 100),
            damageModifier: uint16((uint32(stats.damageModifier) * uint32(stance.damageModifier)) / 100)
        });
    }

    function updateCombatState(
        CombatState memory state,
        uint8 attackResult,
        uint16 attackDamage,
        uint8 attackStaminaCost,
        uint8 defenseResult,
        uint16 defenseDamage,
        uint8 defenseStaminaCost
    ) private pure {
        if (state.isPlayer1Turn) {
            // Apply stamina costs
            state.p1Stamina = state.p1Stamina > attackStaminaCost ? state.p1Stamina - attackStaminaCost : 0;
            state.p2Stamina = state.p2Stamina > defenseStaminaCost ? state.p2Stamina - defenseStaminaCost : 0;

            // Apply attack damage if defense wasn't successful
            if (
                defenseResult != uint8(CombatResultType.PARRY) && defenseResult != uint8(CombatResultType.BLOCK)
                    && defenseResult != uint8(CombatResultType.DODGE)
            ) {
                state.p2Health = applyDamage(state.p2Health, attackDamage);
                if (state.p2Health == 0) {
                    state.winner = 1;
                    state.condition = WinCondition.HEALTH;
                }
            }

            // Apply counter damage
            if (defenseDamage > 0) {
                state.p1Health = applyDamage(state.p1Health, defenseDamage);
                if (state.p1Health == 0) {
                    // Add this check
                    state.winner = 2;
                    state.condition = WinCondition.HEALTH;
                }
            }
        } else {
            // Player 2's turn - mirror the logic exactly
            state.p2Stamina = state.p2Stamina > attackStaminaCost ? state.p2Stamina - attackStaminaCost : 0;
            state.p1Stamina = state.p1Stamina > defenseStaminaCost ? state.p1Stamina - defenseStaminaCost : 0;

            if (
                defenseResult != uint8(CombatResultType.PARRY) && defenseResult != uint8(CombatResultType.BLOCK)
                    && defenseResult != uint8(CombatResultType.DODGE)
            ) {
                state.p1Health = applyDamage(state.p1Health, attackDamage);
                if (state.p1Health == 0) {
                    state.winner = 2;
                    state.condition = WinCondition.HEALTH;
                }
            }

            if (defenseDamage > 0) {
                state.p2Health = applyDamage(state.p2Health, defenseDamage);
                if (state.p2Health == 0) {
                    // Add this check
                    state.winner = 1;
                    state.condition = WinCondition.HEALTH;
                }
            }
        }
    }

    function appendCombatAction(
        bytes memory results,
        uint8 attackResult,
        uint16 attackDamage,
        uint8 attackStaminaCost,
        uint8 defenseResult,
        uint16 defenseDamage,
        uint8 defenseStaminaCost
    ) private pure returns (bytes memory) {
        if (results.length == 0) {
            results = new bytes(2); // Reserve space for winner and condition
        }

        bytes memory actionData = new bytes(8);
        actionData[0] = bytes1(attackResult);
        actionData[1] = bytes1(uint8(attackDamage >> 8));
        actionData[2] = bytes1(uint8(attackDamage));
        actionData[3] = bytes1(attackStaminaCost);
        actionData[4] = bytes1(defenseResult);
        actionData[5] = bytes1(uint8(defenseDamage >> 8));
        actionData[6] = bytes1(uint8(defenseDamage));
        actionData[7] = bytes1(defenseStaminaCost);

        return bytes.concat(results, actionData);
    }

    function encodeCombatResults(CombatState memory state, bytes memory results) private pure returns (bytes memory) {
        require(results.length >= 2, "Invalid results length");
        // Write winner and condition to first two bytes
        results[0] = bytes1(uint8(state.winner));
        results[1] = bytes1(uint8(state.condition));
        return results;
    }

    function calculateStaminaCost(uint256 baseCost, IPlayerSkinNFT.FightingStance stance, GameStats gameStats)
        internal
        view
        returns (uint256)
    {
        uint256 staminaModifier = gameStats.getStanceMultiplier(stance).staminaCostModifier;
        return (baseCost * staminaModifier) / 100;
    }
}

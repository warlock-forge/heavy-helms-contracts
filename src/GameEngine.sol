// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IGameEngine.sol";
import "./interfaces/IPlayer.sol";
import "./lib/UniformRandomNumber.sol";
import "./PlayerSkinRegistry.sol";
import "./PlayerEquipmentStats.sol";

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
    uint8 private immutable STAMINA_ATTACK = 8;
    uint8 private immutable STAMINA_BLOCK = 5;
    uint8 private immutable STAMINA_DODGE = 4;
    uint8 private immutable STAMINA_COUNTER = 6;
    uint8 private immutable MAX_ROUNDS = 50;
    uint8 private immutable MINIMUM_ACTION_COST = 3;
    uint8 private immutable PARRY_DAMAGE_REDUCTION = 50;
    uint8 private immutable STAMINA_PARRY = 5;

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
        uint32 p1Id;
        uint32 p2Id;
        uint32 winningPlayerId;
        bool isPlayer1Turn;
        WinCondition condition;
        uint96 p1Health;
        uint96 p2Health;
        uint32 p1Stamina;
        uint32 p2Stamina;
    }

    enum CounterType {
        PARRY,
        COUNTER
    }

    function decodeCombatLog(bytes memory results)
        public
        pure
        returns (uint256 winningPlayerId, WinCondition condition, CombatAction[] memory actions)
    {
        require(results.length >= 5, "Results too short");

        // Properly decode uint32 from 4 bytes
        winningPlayerId = uint32(uint8(results[0])) << 24 | uint32(uint8(results[1])) << 16
            | uint32(uint8(results[2])) << 8 | uint32(uint8(results[3]));

        condition = WinCondition(uint8(results[4]));

        uint256 numActions = (results.length - 5) / 8;
        actions = new CombatAction[](numActions);

        for (uint256 i = 0; i < numActions; i++) {
            uint256 base = 5 + (i * 8);

            actions[i] = CombatAction({
                p1Result: CombatResultType(uint8(results[base + 0])),
                p1Damage: uint16((uint8(results[base + 1]) << 8) | uint8(results[base + 2])),
                p1StaminaLost: uint8(results[base + 3]),
                p2Result: CombatResultType(uint8(results[base + 4])),
                p2Damage: uint16((uint8(results[base + 5]) << 8) | uint8(results[base + 6])),
                p2StaminaLost: uint8(results[base + 7])
            });
        }
    }

    function processGame(
        PlayerLoadout calldata player1,
        PlayerLoadout calldata player2,
        uint256 randomSeed,
        IPlayer playerContract
    ) external view returns (bytes memory) {
        return playGameInternal(player1, player2, randomSeed, playerContract);
    }

    function playGameInternal(
        PlayerLoadout memory player1,
        PlayerLoadout memory player2,
        uint256 randomSeed,
        IPlayer playerContract
    ) private view returns (bytes memory) {
        // Get player stats and skin attributes
        IPlayer.PlayerStats memory p1Stats = playerContract.getPlayer(player1.playerId);
        IPlayer.PlayerStats memory p2Stats = playerContract.getPlayer(player2.playerId);

        // Get skin attributes for both players
        (IPlayerSkinNFT.WeaponType p1Weapon, IPlayerSkinNFT.ArmorType p1Armor, IPlayerSkinNFT.FightingStance p1Stance) =
            getSkinAttributes(player1.skinIndex, player1.skinTokenId, playerContract);
        (IPlayerSkinNFT.WeaponType p2Weapon, IPlayerSkinNFT.ArmorType p2Armor, IPlayerSkinNFT.FightingStance p2Stance) =
            getSkinAttributes(player2.skinIndex, player2.skinTokenId, playerContract);

        // Get full combat stats including weapon, armor, and stance modifiers
        (
            PlayerEquipmentStats.WeaponStats memory p1WeaponStats,
            PlayerEquipmentStats.ArmorStats memory p1ArmorStats,
            PlayerEquipmentStats.StanceMultiplier memory p1StanceStats
        ) = playerContract.equipmentStats().getFullCharacterStats(p1Weapon, p1Armor, p1Stance);
        (
            PlayerEquipmentStats.WeaponStats memory p2WeaponStats,
            PlayerEquipmentStats.ArmorStats memory p2ArmorStats,
            PlayerEquipmentStats.StanceMultiplier memory p2StanceStats
        ) = playerContract.equipmentStats().getFullCharacterStats(p2Weapon, p2Armor, p2Stance);

        IPlayer.CalculatedStats memory p1CalcStats = playerContract.calculateStats(p1Stats);
        IPlayer.CalculatedStats memory p2CalcStats = playerContract.calculateStats(p2Stats);

        // Apply stance modifiers to calculated stats
        p1CalcStats = applyStanceModifiers(p1CalcStats, p1StanceStats);
        p2CalcStats = applyStanceModifiers(p2CalcStats, p2StanceStats);

        CombatState memory state = initializeCombatState(
            player1,
            player2,
            randomSeed,
            p1CalcStats,
            p2CalcStats,
            p1WeaponStats,
            p1ArmorStats,
            p2WeaponStats,
            p2ArmorStats,
            playerContract
        );

        bytes memory results = new bytes(5);
        uint8 roundCount = 0;
        uint256 currentSeed = randomSeed;

        while (state.p1Health > 0 && state.p2Health > 0 && roundCount < MAX_ROUNDS) {
            // Check exhaustion first
            if (
                checkExhaustion(
                    state,
                    currentSeed,
                    p1Stance,
                    p2Stance,
                    p1WeaponStats, // Pass weapon stats
                    p2WeaponStats, // Pass weapon stats
                    playerContract
                )
            ) {
                break;
            }

            // Get new random seed
            currentSeed = uint256(keccak256(abi.encodePacked(currentSeed)));

            // Process round and update state
            (currentSeed, results) = processRound(
                state,
                currentSeed,
                results,
                p1CalcStats,
                p2CalcStats,
                p1WeaponStats,
                p2WeaponStats,
                p1ArmorStats,
                p2ArmorStats,
                p1Stance,
                p2Stance,
                playerContract
            );

            roundCount++;
            state.isPlayer1Turn = !state.isPlayer1Turn;
        }

        if (roundCount >= MAX_ROUNDS) {
            state.condition = WinCondition.MAX_ROUNDS;
            state.winningPlayerId = state.p1Health >= state.p2Health ? state.p1Id : state.p2Id;
        }

        return encodeCombatResults(state, results);
    }

    function initializeCombatState(
        PlayerLoadout memory player1,
        PlayerLoadout memory player2,
        uint256 seed,
        IPlayer.CalculatedStats memory p1CalcStats,
        IPlayer.CalculatedStats memory p2CalcStats,
        PlayerEquipmentStats.WeaponStats memory p1WeaponStats,
        PlayerEquipmentStats.ArmorStats memory p1ArmorStats,
        PlayerEquipmentStats.WeaponStats memory p2WeaponStats,
        PlayerEquipmentStats.ArmorStats memory p2ArmorStats,
        IPlayer playerContract
    ) private view returns (CombatState memory state) {
        (uint256 p1Health, uint256 p1Stamina) = playerContract.getPlayerState(player1.playerId);
        (uint256 p2Health, uint256 p2Stamina) = playerContract.getPlayerState(player2.playerId);

        // Safe downcasting
        state.p1Health = uint96(p1Health);
        state.p2Health = uint96(p2Health);
        state.p1Stamina = uint32(p1Stamina);
        state.p2Stamina = uint32(p2Stamina);

        // Store the player IDs
        state.p1Id = uint32(player1.playerId);
        state.p2Id = uint32(player2.playerId);

        // Calculate effective initiative (90% equipment, 10% stats)
        uint32 p1EquipmentInit = (p1WeaponStats.attackSpeed * 100) / p1ArmorStats.weight;
        uint32 p2EquipmentInit = (p2WeaponStats.attackSpeed * 100) / p2ArmorStats.weight;

        uint32 p1TotalInit = ((p1EquipmentInit * 90) + (uint32(p1CalcStats.initiative) * 10)) / 100;
        uint32 p2TotalInit = ((p2EquipmentInit * 90) + (uint32(p2CalcStats.initiative) * 10)) / 100;

        // Simple deterministic check with tiebreaker
        if (p1TotalInit == p2TotalInit) {
            seed = uint256(keccak256(abi.encodePacked(seed)));
            state.isPlayer1Turn = seed.uniform(2) == 0;
        } else {
            state.isPlayer1Turn = p1TotalInit > p2TotalInit;
        }

        return state;
    }

    function checkExhaustion(
        CombatState memory state,
        uint256 seed,
        IPlayerSkinNFT.FightingStance p1Stance,
        IPlayerSkinNFT.FightingStance p2Stance,
        PlayerEquipmentStats.WeaponStats memory p1WeaponStats,
        PlayerEquipmentStats.WeaponStats memory p2WeaponStats,
        IPlayer playerContract
    ) private view returns (bool) {
        uint256 p1MinCost = calculateStaminaCost(MINIMUM_ACTION_COST, p1Stance, p1WeaponStats, playerContract);
        uint256 p2MinCost = calculateStaminaCost(MINIMUM_ACTION_COST, p2Stance, p2WeaponStats, playerContract);

        if ((state.p1Stamina < uint32(p1MinCost)) || (state.p2Stamina < uint32(p2MinCost))) {
            state.condition = WinCondition.EXHAUSTION;
            if (state.p1Stamina < uint32(p1MinCost) && state.p2Stamina < uint32(p2MinCost)) {
                seed = uint256(keccak256(abi.encodePacked(seed)));
                state.winningPlayerId = seed.uniform(2) == 0 ? state.p2Id : state.p1Id;
            } else {
                state.winningPlayerId = state.p1Stamina < uint32(p1MinCost) ? state.p2Id : state.p1Id;
            }
            return true;
        }
        return false;
    }

    function processRound(
        CombatState memory state,
        uint256 currentSeed,
        bytes memory results,
        IPlayer.CalculatedStats memory p1CalcStats,
        IPlayer.CalculatedStats memory p2CalcStats,
        PlayerEquipmentStats.WeaponStats memory p1WeaponStats,
        PlayerEquipmentStats.WeaponStats memory p2WeaponStats,
        PlayerEquipmentStats.ArmorStats memory p1ArmorStats,
        PlayerEquipmentStats.ArmorStats memory p2ArmorStats,
        IPlayerSkinNFT.FightingStance p1Stance,
        IPlayerSkinNFT.FightingStance p2Stance,
        IPlayer playerContract
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
            playerContract
        );

        // Update combat state based on results
        updateCombatState(
            state, attackResult, attackDamage, attackStaminaCost, defenseResult, defenseDamage, defenseStaminaCost
        );

        // When processing a miss, we should set:
        // - attackResult = ATTACK (not MISS)
        // - defenseResult = MISS
        if (attackResult == uint8(CombatResultType.MISS)) {
            attackResult = uint8(CombatResultType.ATTACK);
            defenseResult = uint8(CombatResultType.MISS);
        }

        // Append results to combat log
        results = appendCombatAction(
            results,
            attackResult,
            attackDamage,
            attackStaminaCost,
            defenseResult,
            defenseDamage,
            defenseStaminaCost,
            state.isPlayer1Turn
        );

        return (currentSeed, results);
    }

    function processCombatTurn(
        IPlayer.CalculatedStats memory attacker,
        IPlayer.CalculatedStats memory defender,
        uint256 attackerStamina,
        uint256 defenderStamina,
        PlayerEquipmentStats.WeaponStats memory attackerWeapon,
        PlayerEquipmentStats.WeaponStats memory defenderWeapon,
        PlayerEquipmentStats.ArmorStats memory defenderArmor,
        uint256 seed,
        IPlayerSkinNFT.FightingStance attackerStance,
        IPlayerSkinNFT.FightingStance defenderStance,
        IPlayer playerContract
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
        // Check stamina first
        uint256 attackCost = calculateStaminaCost(STAMINA_ATTACK, attackerStance, attackerWeapon, playerContract);
        if (attackerStamina < attackCost) {
            return (uint8(CombatResultType.EXHAUSTED), 0, uint8(attackCost), 0, 0, 0);
        }

        // Use attacker's hit chance and weapon speed
        uint32 baseHitChance = uint32(attacker.hitChance);
        uint32 weaponSpeedMod = uint32(attackerWeapon.attackSpeed);

        // Get attacker's stance modifiers
        PlayerEquipmentStats.StanceMultiplier memory attackerStanceMods =
            playerContract.equipmentStats().getStanceMultiplier(attackerStance);

        // Calculate final hit chance using attacker's stats
        uint32 adjustedHitChance = (baseHitChance * weaponSpeedMod * attackerStanceMods.hitChance) / 10000;

        // Use min/max to keep within bounds (70-95%)
        uint32 withMin = adjustedHitChance < 70 ? 70 : adjustedHitChance;
        uint32 withBothBounds = withMin > 95 ? 95 : withMin;
        uint8 finalHitChance = uint8(withBothBounds);

        seed = uint256(keccak256(abi.encodePacked(seed))); // Fresh seed for hit check
        uint8 hitRoll = uint8(seed % 100);

        if (hitRoll < finalHitChance) {
            // Calculate base damage first
            seed = uint256(keccak256(abi.encodePacked(seed))); // Fresh seed before damage calc
            uint16 damage;
            (damage, seed) = calculateDamage(attacker.damageModifier, attackerWeapon, seed);

            uint8 critRoll = uint8(seed % 100);
            bool isCritical = critRoll < attacker.critChance;

            if (isCritical) {
                damage = uint16((uint32(damage) * uint32(attacker.critMultiplier)) / 100);
                attackResult = uint8(CombatResultType.CRIT);
            } else {
                attackResult = uint8(CombatResultType.ATTACK);
            }

            attackDamage = damage;
            uint256 modifiedStaminaCost =
                calculateStaminaCost(STAMINA_ATTACK, attackerStance, attackerWeapon, playerContract);
            attackStaminaCost = uint8(modifiedStaminaCost);

            seed = uint256(keccak256(abi.encodePacked(seed)));
            (defenseResult, defenseDamage, defenseStaminaCost, seed) = processDefense(
                defender,
                defenderStamina,
                defenderWeapon,
                defenderArmor,
                attackDamage,
                attackerWeapon.damageType,
                seed,
                defenderStance,
                playerContract
            );

            // Clear attack damage if defense was successful
            if (
                defenseResult == uint8(CombatResultType.DODGE) || defenseResult == uint8(CombatResultType.BLOCK)
                    || defenseResult == uint8(CombatResultType.PARRY)
            ) {
                attackDamage = 0;
            }
        } else {
            // Miss case
            (attackResult, attackDamage, attackStaminaCost) =
                processMiss(attackerStance, attackerWeapon, playerContract);
            defenseResult = uint8(CombatResultType.MISS);
            defenseDamage = 0;
            defenseStaminaCost = 0;
        }
    }

    function processDefense(
        IPlayer.CalculatedStats memory defender,
        uint256 defenderStamina,
        PlayerEquipmentStats.WeaponStats memory defenderWeapon,
        PlayerEquipmentStats.ArmorStats memory defenderArmor,
        uint16 incomingDamage,
        PlayerEquipmentStats.DamageType damageType,
        uint256 seed,
        IPlayerSkinNFT.FightingStance stance,
        IPlayer playerContract
    ) private view returns (uint8 result, uint16 damage, uint8 staminaCost, uint256 nextSeed) {
        // Get stance multipliers
        PlayerEquipmentStats.StanceMultiplier memory stanceMods =
            playerContract.equipmentStats().getStanceMultiplier(stance);

        // Calculate all stamina costs with stance modifiers
        uint256 blockStaminaCost = calculateStaminaCost(STAMINA_BLOCK, stance, defenderWeapon, playerContract);
        uint256 parryStaminaCost = calculateStaminaCost(STAMINA_PARRY, stance, defenderWeapon, playerContract);
        uint256 dodgeStaminaCost = calculateStaminaCost(STAMINA_DODGE, stance, defenderWeapon, playerContract);

        // Calculate all effective defensive chances with stance modifiers
        uint16 effectiveBlockChance = uint16((uint32(defender.blockChance) * uint32(stanceMods.blockChance)) / 100);
        uint16 effectiveParryChance = uint16(
            (uint32(defender.parryChance) * uint32(stanceMods.parryChance) * uint32(defenderWeapon.parryChance)) / 10000
        );
        uint16 effectiveDodgeChance = uint16((uint32(defender.dodgeChance) * uint32(stanceMods.dodgeChance)) / 100);

        // Block check - only allow if defender has a shield-type weapon
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 blockRoll = uint8(seed % 100);

        if (blockRoll < effectiveBlockChance && defenderStamina >= blockStaminaCost && defenderWeapon.hasShield) {
            // Using hasShield from WeaponStats
            seed = uint256(keccak256(abi.encodePacked(seed)));
            uint8 counterRoll = uint8(seed % 100);

            if (counterRoll < defender.counterChance) {
                seed = uint256(keccak256(abi.encodePacked(seed)));
                (result, damage, staminaCost, seed) =
                    processCounterAttack(defender, defenderWeapon, seed, CounterType.COUNTER, stance, playerContract);
                seed = uint256(keccak256(abi.encodePacked(seed)));
                return (result, damage, staminaCost, seed);
            }
            seed = uint256(keccak256(abi.encodePacked(seed)));
            return (uint8(CombatResultType.BLOCK), 0, uint8(blockStaminaCost), seed);
        }

        // Parry check
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 parryRoll = uint8(seed % 100);
        if (parryRoll < effectiveParryChance && defenderStamina >= parryStaminaCost) {
            seed = uint256(keccak256(abi.encodePacked(seed)));
            uint8 riposteRoll = uint8(seed % 100);

            if (riposteRoll < defender.counterChance) {
                seed = uint256(keccak256(abi.encodePacked(seed)));
                return processCounterAttack(defender, defenderWeapon, seed, CounterType.PARRY, stance, playerContract);
            }
            return (uint8(CombatResultType.PARRY), 0, uint8(parryStaminaCost), seed);
        }

        // Dodge check
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 dodgeRoll = uint8(seed % 100);
        if (dodgeRoll < effectiveDodgeChance && defenderStamina >= dodgeStaminaCost) {
            return (uint8(CombatResultType.DODGE), 0, uint8(dodgeStaminaCost), seed);
        }

        // If all defensive actions fail, apply armor reduction and return fresh seed
        uint16 reducedDamage = applyDefensiveStats(incomingDamage, defenderArmor, damageType);
        seed = uint256(keccak256(abi.encodePacked(seed))); // Fresh seed before return
        return (uint8(CombatResultType.HIT), reducedDamage, 0, seed);
    }

    function processCounterAttack(
        IPlayer.CalculatedStats memory defenderStats,
        PlayerEquipmentStats.WeaponStats memory defenderWeapon,
        uint256 seed,
        CounterType counterType,
        IPlayerSkinNFT.FightingStance stance,
        IPlayer playerContract
    ) private view returns (uint8 result, uint16 damage, uint8 staminaCost, uint256 nextSeed) {
        uint16 counterDamage;
        (counterDamage, seed) = calculateDamage(defenderStats.damageModifier, defenderWeapon, seed);

        seed = uint256(keccak256(abi.encodePacked(seed)));
        bool isCritical = (seed % 100) < defenderStats.critChance;

        if (isCritical) {
            uint32 totalMultiplier =
                (uint32(defenderStats.critMultiplier) * uint32(defenderWeapon.critMultiplier)) / 100;
            counterDamage = uint16((uint32(counterDamage) * totalMultiplier) / 100);

            uint256 critStaminaCostBase = counterType == CounterType.PARRY ? STAMINA_PARRY : STAMINA_COUNTER;
            uint256 critModifiedStaminaCost =
                calculateStaminaCost(critStaminaCostBase, stance, defenderWeapon, playerContract);

            seed = uint256(keccak256(abi.encodePacked(seed)));
            return (
                uint8(counterType == CounterType.PARRY ? CombatResultType.RIPOSTE_CRIT : CombatResultType.COUNTER_CRIT),
                counterDamage,
                uint8(critModifiedStaminaCost),
                seed
            );
        }

        uint256 normalStaminaCostBase = counterType == CounterType.PARRY ? STAMINA_PARRY : STAMINA_COUNTER;
        uint256 normalModifiedStaminaCost =
            calculateStaminaCost(normalStaminaCostBase, stance, defenderWeapon, playerContract);

        seed = uint256(keccak256(abi.encodePacked(seed)));
        return (
            uint8(counterType == CounterType.PARRY ? CombatResultType.RIPOSTE : CombatResultType.COUNTER),
            counterDamage,
            uint8(normalModifiedStaminaCost),
            seed
        );
    }

    function processMiss(
        IPlayerSkinNFT.FightingStance stance,
        PlayerEquipmentStats.WeaponStats memory weapon,
        IPlayer playerContract
    ) private view returns (uint8 result, uint16 damage, uint8 staminaCost) {
        uint256 modifiedStaminaCost = calculateStaminaCost(STAMINA_ATTACK, stance, weapon, playerContract);
        return (uint8(CombatResultType.MISS), 0, uint8(modifiedStaminaCost));
    }

    function getSkinAttributes(uint32 skinIndex, uint16 skinTokenId, IPlayer playerContract)
        private
        view
        returns (IPlayerSkinNFT.WeaponType weapon, IPlayerSkinNFT.ArmorType armor, IPlayerSkinNFT.FightingStance stance)
    {
        // Get the skin info from the registry through the player contract's skinRegistry
        PlayerSkinRegistry.SkinInfo memory skinInfo = playerContract.skinRegistry().getSkin(skinIndex);

        // Get the attributes from the skin contract using the token ID
        IPlayerSkinNFT.SkinAttributes memory attrs =
            IPlayerSkinNFT(skinInfo.contractAddress).getSkinAttributes(skinTokenId);

        return (attrs.weapon, attrs.armor, attrs.stance);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function applyDamage(uint96 currentHealth, uint16 damage) private pure returns (uint96) {
        unchecked {
            return currentHealth > damage ? currentHealth - damage : 0;
        }
    }

    function calculateDamage(uint16 damageModifier, PlayerEquipmentStats.WeaponStats memory weapon, uint256 seed)
        private
        pure
        returns (uint16 damage, uint256 nextSeed)
    {
        // Use uint64 for all intermediate calculations to prevent overflow
        uint64 damageRange = weapon.maxDamage >= weapon.minDamage ? weapon.maxDamage - weapon.minDamage : 0;
        uint64 baseDamage = uint64(weapon.minDamage) + uint64(seed % (damageRange + 1));

        // Scale up for precision, using uint64 to prevent overflow
        uint64 scaledBase = baseDamage * 100;
        uint64 modifiedDamage = (scaledBase * uint64(damageModifier)) / 10000;

        seed = uint256(keccak256(abi.encodePacked(seed)));

        // Safe downcast to uint16
        return (modifiedDamage > type(uint16).max ? type(uint16).max : uint16(modifiedDamage), seed);
    }

    function applyDefensiveStats(
        uint16 incomingDamage,
        PlayerEquipmentStats.ArmorStats memory armor,
        PlayerEquipmentStats.DamageType damageType
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

    function getResistanceForDamageType(
        PlayerEquipmentStats.ArmorStats memory armor,
        PlayerEquipmentStats.DamageType damageType
    ) private pure returns (uint16) {
        if (damageType == PlayerEquipmentStats.DamageType.Slashing) {
            return armor.slashResist;
        } else if (damageType == PlayerEquipmentStats.DamageType.Piercing) {
            return armor.pierceResist;
        } else if (damageType == PlayerEquipmentStats.DamageType.Blunt) {
            return armor.bluntResist;
        }
        return 0;
    }

    // Add new function to apply stance modifiers
    function applyStanceModifiers(
        IPlayer.CalculatedStats memory stats,
        PlayerEquipmentStats.StanceMultiplier memory stance
    ) private pure returns (IPlayer.CalculatedStats memory) {
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

            // Apply attack damage ONLY if defense wasn't successful
            // Added all defensive actions that should block damage
            if (
                defenseResult != uint8(CombatResultType.PARRY) && defenseResult != uint8(CombatResultType.BLOCK)
                    && defenseResult != uint8(CombatResultType.DODGE) && defenseResult != uint8(CombatResultType.COUNTER)
                    && defenseResult != uint8(CombatResultType.COUNTER_CRIT)
                    && defenseResult != uint8(CombatResultType.RIPOSTE)
                    && defenseResult != uint8(CombatResultType.RIPOSTE_CRIT)
            ) {
                state.p2Health = applyDamage(state.p2Health, attackDamage);
                if (state.p2Health == 0) {
                    state.winningPlayerId = state.p1Id;
                    state.condition = WinCondition.HEALTH;
                }
            }

            // Apply counter damage
            if (defenseDamage > 0) {
                state.p1Health = applyDamage(state.p1Health, defenseDamage);
                if (state.p1Health == 0) {
                    state.winningPlayerId = state.p2Id;
                    state.condition = WinCondition.HEALTH;
                }
            }
        } else {
            // Player 2's turn - mirror the logic exactly
            state.p2Stamina = state.p2Stamina > attackStaminaCost ? state.p2Stamina - attackStaminaCost : 0;
            state.p1Stamina = state.p1Stamina > defenseStaminaCost ? state.p1Stamina - defenseStaminaCost : 0;

            if (
                defenseResult != uint8(CombatResultType.PARRY) && defenseResult != uint8(CombatResultType.BLOCK)
                    && defenseResult != uint8(CombatResultType.DODGE) && defenseResult != uint8(CombatResultType.COUNTER)
                    && defenseResult != uint8(CombatResultType.COUNTER_CRIT)
                    && defenseResult != uint8(CombatResultType.RIPOSTE)
                    && defenseResult != uint8(CombatResultType.RIPOSTE_CRIT)
            ) {
                state.p1Health = applyDamage(state.p1Health, attackDamage);
                if (state.p1Health == 0) {
                    state.winningPlayerId = state.p2Id;
                    state.condition = WinCondition.HEALTH;
                }
            }

            if (defenseDamage > 0) {
                state.p2Health = applyDamage(state.p2Health, defenseDamage);
                if (state.p2Health == 0) {
                    state.winningPlayerId = state.p1Id;
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
        uint8 defenseStaminaCost,
        bool isPlayer1Turn
    ) private pure returns (bytes memory) {
        bytes memory actionData = new bytes(8);

        if (isPlayer1Turn) {
            // P1 attacking, P2 defending
            actionData[0] = bytes1(attackResult);
            actionData[1] = bytes1(uint8(attackDamage >> 8));
            actionData[2] = bytes1(uint8(attackDamage));
            actionData[3] = bytes1(attackStaminaCost);
            actionData[4] = bytes1(defenseResult);
            actionData[5] = bytes1(uint8(defenseDamage >> 8));
            actionData[6] = bytes1(uint8(defenseDamage));
            actionData[7] = bytes1(defenseStaminaCost);
        } else {
            // P2 attacking, P1 defending
            actionData[0] = bytes1(defenseResult);
            actionData[1] = bytes1(uint8(defenseDamage >> 8));
            actionData[2] = bytes1(uint8(defenseDamage));
            actionData[3] = bytes1(defenseStaminaCost);
            actionData[4] = bytes1(attackResult);
            actionData[5] = bytes1(uint8(attackDamage >> 8));
            actionData[6] = bytes1(uint8(attackDamage));
            actionData[7] = bytes1(attackStaminaCost);
        }

        return bytes.concat(results, actionData);
    }

    function encodeCombatResults(CombatState memory state, bytes memory results) private pure returns (bytes memory) {
        require(results.length >= 5, "Invalid results length");

        // Write uint32 winner ID as 4 separate bytes
        results[0] = bytes1(uint8(state.winningPlayerId >> 24));
        results[1] = bytes1(uint8(state.winningPlayerId >> 16));
        results[2] = bytes1(uint8(state.winningPlayerId >> 8));
        results[3] = bytes1(uint8(state.winningPlayerId));

        // Write condition
        results[4] = bytes1(uint8(state.condition));

        return results;
    }

    function calculateStaminaCost(
        uint256 baseCost,
        IPlayerSkinNFT.FightingStance stance,
        PlayerEquipmentStats.WeaponStats memory weapon,
        IPlayer playerContract
    ) internal view returns (uint256) {
        uint256 stanceModifier = playerContract.equipmentStats().getStanceMultiplier(stance).staminaCostModifier;
        // Apply both weapon and stance modifiers
        return (baseCost * stanceModifier * weapon.staminaMultiplier) / 10000;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/UniformRandomNumber.sol";
import "../../interfaces/fighters/IPlayer.sol";
import "../../interfaces/game/engine/IGameEngine.sol";

contract GameEngine is IGameEngine {
    using UniformRandomNumber for uint256;

    uint16 public constant version = 8;

    struct CalculatedStats {
        uint16 maxHealth;
        uint16 damageModifier;
        uint16 hitChance;
        uint16 blockChance;
        uint16 parryChance;
        uint16 dodgeChance;
        uint16 maxEndurance;
        uint16 initiative;
        uint16 counterChance;
        uint16 riposteChance;
        uint16 critChance;
        uint16 critMultiplier;
        uint16 baseSurvivalRate;
    }

    enum DamageType {
        Slashing,
        Piercing,
        Blunt,
        Hybrid_Slash_Pierce,  // For weapons mixing slashing and piercing
        Hybrid_Slash_Blunt,   // For weapons mixing slashing and blunt
        Hybrid_Pierce_Blunt   // For weapons mixing piercing and blunt
    }

    enum ShieldType {
        NONE,
        BUCKLER,
        KITE_SHIELD,
        TOWER_SHIELD
    }

    struct WeaponStats {
        uint16 minDamage;
        uint16 maxDamage;
        uint16 attackSpeed; // Base 100, higher is faster
        uint16 parryChance; // Base 100, chance to parry
        uint16 riposteChance; // Base 100, chance to riposte
        uint16 critMultiplier; // Base 100, higher means better crits
        uint16 staminaMultiplier; // Base 100, higher means more stamina drain
        uint16 survivalFactor; // Base 100, higher means better survival chance
        DamageType damageType; // Primary damage type
        ShieldType shieldType; // NONE, BUCKLER, KITE_SHIELD, or TOWER_SHIELD
    }

    struct ArmorStats {
        uint16 defense; // Base damage reduction
        uint16 weight; // Affects stamina drain
        uint16 slashResist; // Resistance to slashing (base 100)
        uint16 pierceResist; // Resistance to piercing (base 100)
        uint16 bluntResist; // Resistance to blunt (base 100)
    }

    struct StanceMultiplier {
        uint16 damageModifier; // Reduce the range between offensive/defensive
        uint16 hitChance; // Make hit chance differences smaller
        uint16 critChance; // Keep crit chances relatively close
        uint16 critMultiplier; // Reduce the gap in crit damage
        uint16 blockChance; // Make defensive abilities more consistent
        uint16 parryChance; // Keep parry in check
        uint16 dodgeChance; // Balance dodge with other defensive options
        uint16 counterChance; // Make counter more reliable but less swingy
        uint16 riposteChance; // New field
        uint16 staminaCostModifier; // Add this new field
        uint16 survivalFactor; // Base 100, higher means better survival chance
    }

    struct CalculatedCombatStats {
        CalculatedStats stats;
        WeaponStats weapon;
        ArmorStats armor;
        StanceMultiplier stanceMultipliers;
    }

    struct CombatState {
        bool isPlayer1Turn;
        WinCondition condition;
        uint96 p1Health;
        uint96 p2Health;
        uint32 p1Stamina;
        uint32 p2Stamina;
        uint16 p1ActionPoints;
        uint16 p2ActionPoints;
        bool p1HasInitiative;
        bool player1Won;
    }

    enum CounterType {
        PARRY,
        COUNTER
    }

    enum ActionType {
        ATTACK,
        BLOCK,
        PARRY,
        DODGE,
        COUNTER,
        RIPOSTE
    }

    // Combat-related constants
    uint8 private immutable STAMINA_ATTACK = 9;
    uint8 private immutable STAMINA_BLOCK = 2;
    uint8 private immutable STAMINA_DODGE = 3;
    uint8 private immutable STAMINA_COUNTER = 4;
    uint8 private immutable STAMINA_PARRY = 2;
    uint8 private immutable STAMINA_RIPOSTE = 4;
    uint8 private immutable MAX_ROUNDS = 50;
    uint8 private constant ATTACK_ACTION_COST = 149;
    // Add base survival constant
    uint8 private constant BASE_SURVIVAL_CHANCE = 95;
    uint8 private constant MINIMUM_SURVIVAL_CHANCE = 35;
    uint8 private constant DAMAGE_THRESHOLD_PERCENT = 20;
    uint8 private constant MAX_DAMAGE_OVERAGE = 60;

    // Weapon Types
    uint8 public constant WEAPON_ARMING_SWORD_KITE = 0;
    uint8 public constant WEAPON_MACE_TOWER = 1;
    uint8 public constant WEAPON_RAPIER_BUCKLER = 2;
    uint8 public constant WEAPON_GREATSWORD = 3;
    uint8 public constant WEAPON_BATTLEAXE = 4;
    uint8 public constant WEAPON_QUARTERSTAFF = 5;
    uint8 public constant WEAPON_SPEAR = 6;
    uint8 public constant WEAPON_SHORTSWORD_BUCKLER = 7;
    uint8 public constant WEAPON_SHORTSWORD_TOWER = 8;
    uint8 public constant WEAPON_DUAL_DAGGERS = 9;
    uint8 public constant WEAPON_RAPIER_DAGGER = 10;
    uint8 public constant WEAPON_SCIMITAR_BUCKLER = 11;
    uint8 public constant WEAPON_AXE_KITE = 12;
    uint8 public constant WEAPON_AXE_TOWER = 13;
    uint8 public constant WEAPON_DUAL_SCIMITARS = 14;
    uint8 public constant WEAPON_FLAIL_BUCKLER = 15;
    uint8 public constant WEAPON_MACE_KITE = 16;
    uint8 public constant WEAPON_CLUB_TOWER = 17;
    uint8 public constant WEAPON_DUAL_CLUBS = 18;
    uint8 public constant WEAPON_ARMING_SWORD_SHORTSWORD = 19;
    uint8 public constant WEAPON_SCIMITAR_DAGGER = 20;
    uint8 public constant WEAPON_ARMING_SWORD_CLUB = 21;
    uint8 public constant WEAPON_AXE_MACE = 22;
    uint8 public constant WEAPON_FLAIL_DAGGER = 23;
    uint8 public constant WEAPON_MACE_SHORTSWORD = 24;
    uint8 public constant WEAPON_MAUL = 25;
    uint8 public constant WEAPON_TRIDENT = 26;

    // Armor Types
    uint8 public constant ARMOR_CLOTH = 0;
    uint8 public constant ARMOR_LEATHER = 1;
    uint8 public constant ARMOR_CHAIN = 2;
    uint8 public constant ARMOR_PLATE = 3;

    // Stance Types
    uint8 public constant STANCE_DEFENSIVE = 0;
    uint8 public constant STANCE_BALANCED = 1;
    uint8 public constant STANCE_OFFENSIVE = 2;

    /// @notice Decodes a version number into major and minor components
    /// @param _version The version number to decode
    /// @return major The major version number (0-255)
    /// @return minor The minor version number (0-255)
    function decodeVersion(uint16 _version) public pure returns (uint8 major, uint8 minor) {
        major = uint8(_version >> 8); // Get upper 8 bits
        minor = uint8(_version & 0xFF); // Get lower 8 bits
    }

    /// @notice Decodes a combat log byte array into structured data
    /// @param results The byte array containing the encoded combat log
    /// @return player1Won True if player1 won, false if player2 won
    /// @return gameEngineVersion The version of the game engine that generated this log (16 bits)
    /// @return condition The win condition that ended the combat
    /// @return actions Array of combat actions containing results for both players
    /// @dev Format:
    ///   - Byte 0: Winner (1 for player1, 0 for player2)
    ///   - Bytes 1-2: Game Engine Version (16 bits)
    ///   - Byte 3: Win Condition
    ///   - Bytes 4+: Combat actions (8 bytes each):
    ///     - Byte 0: Player 1 Result
    ///     - Bytes 1-2: Player 1 Damage
    ///     - Byte 3: Player 1 Stamina Lost
    ///     - Byte 4: Player 2 Result
    ///     - Bytes 5-6: Player 2 Damage
    ///     - Byte 7: Player 2 Stamina Lost
    function decodeCombatLog(bytes memory results)
        public
        pure
        returns (bool player1Won, uint16 gameEngineVersion, WinCondition condition, CombatAction[] memory actions)
    {
        require(results.length >= 4, "Results too short");

        // Read winner (1 byte) - 0 means player1 won, 1 means player2 won
        player1Won = uint8(results[0]) == 0;

        // Read version (2 bytes)
        gameEngineVersion = uint16(uint8(results[1])) << 8 | uint16(uint8(results[2]));

        // Read condition
        condition = WinCondition(uint8(results[3]));

        // Decode actions
        uint256 numActions = (results.length - 4) / 8;
        actions = new CombatAction[](numActions);

        unchecked {
            for (uint256 i = 0; i < numActions; i++) {
                actions[i] = unpackCombatAction(results, 4 + (i * 8));
            }
        }
    }

    /**
     * @dev Unpacks a single combat action from the byte array
     * @param data The byte array containing all combat data
     * @param offset Starting position of this action in the byte array
     * @return action The unpacked CombatAction struct
     */
    function unpackCombatAction(bytes memory data, uint256 offset) private pure returns (CombatAction memory action) {
        return CombatAction({
            p1Result: CombatResultType(uint8(data[offset])),
            p1Damage: (uint16(uint8(data[offset + 1])) << 8) | uint16(uint8(data[offset + 2])),
            p1StaminaLost: uint8(data[offset + 3]),
            p2Result: CombatResultType(uint8(data[offset + 4])),
            p2Damage: (uint16(uint8(data[offset + 5])) << 8) | uint16(uint8(data[offset + 6])),
            p2StaminaLost: uint8(data[offset + 7])
        });
    }

    function calculateStats(FighterStats memory player) public pure returns (CalculatedStats memory) {
        // Enhanced health calculation with stamina contribution
        uint32 healthBase = 75;
        uint32 healthFromCon = uint32(player.attributes.constitution) * 16;
        uint32 healthFromSize = uint32(player.attributes.size) * 4;
        uint32 healthFromStamina = uint32(player.attributes.stamina) * 4;
        uint16 maxHealth = uint16(healthBase + healthFromCon + healthFromSize + healthFromStamina);

        // Enhanced endurance calculation with strength contribution
        uint32 enduranceBase = 45;
        uint32 enduranceFromStamina = uint32(player.attributes.stamina) * 14;
        uint32 enduranceFromSize = uint32(player.attributes.size) * 2; 
        uint32 enduranceFromStrength = uint32(player.attributes.strength) * 3;
        uint16 maxEndurance = uint16(enduranceBase + enduranceFromStamina + enduranceFromSize + enduranceFromStrength);

        // Safe initiative calculation
        uint32 initiativeBase = 20;
        uint32 initiativeFromAgility = uint32(player.attributes.agility) * 3;
        uint32 initiativeFromLuck = uint32(player.attributes.luck) * 2;
        uint16 initiative = uint16(initiativeBase + initiativeFromAgility + initiativeFromLuck);

        // Safe defensive stats calculation
        uint16 dodgeChance = calculateBaseDodgeChance(player.attributes.agility, player.attributes.size);
        uint16 blockChance =
            uint16(5 + (uint32(player.attributes.constitution) * 8 / 10) + (uint32(player.attributes.size) * 5 / 10));
        uint16 parryChance =
            uint16(3 + (uint32(player.attributes.strength) * 6 / 10) + (uint32(player.attributes.agility) * 6 / 10)
            + (uint32(player.attributes.stamina) * 3 / 10));

        // Safe hit chance calculation
        uint16 hitChance = uint16(30 + uint32(player.attributes.agility) + (uint32(player.attributes.luck) * 2));

        // Safe crit calculations
        uint16 critChance = 2 + uint16(uint32(player.attributes.agility) / 3) + uint16(uint32(player.attributes.luck) / 3);
        uint16 critMultiplier =
            uint16(150 + (uint32(player.attributes.strength) * 3) + (uint32(player.attributes.size) * 2));

        // Safe counter chance calculation (strength + agility based)
        uint16 counterChance = uint16(3 + uint32(player.attributes.strength) + uint32(player.attributes.agility));

        // Safe riposte chance calculation (agility + luck based)
        uint16 riposteChance = uint16(3 + uint32(player.attributes.agility) + uint32(player.attributes.luck) 
                              + (uint32(player.attributes.constitution) * 3 / 10));

        // Physical power calculation
        uint32 combinedStats = uint32(player.attributes.strength) + uint32(player.attributes.size);
        uint32 tempPowerMod = 25 + ((combinedStats * 4167) / 1000);
        uint16 physicalPowerMod = uint16(minUint256(tempPowerMod, type(uint16).max));

        // Calculate base survival rate
        uint16 baseSurvivalRate =
            BASE_SURVIVAL_CHANCE + (uint16(player.attributes.luck) * 2) + uint16(player.attributes.constitution);

        return CalculatedStats({
            maxHealth: maxHealth,
            maxEndurance: maxEndurance,
            initiative: initiative,
            hitChance: hitChance,
            dodgeChance: dodgeChance,
            blockChance: blockChance,
            parryChance: parryChance,
            critChance: critChance,
            critMultiplier: critMultiplier,
            counterChance: counterChance,
            riposteChance: riposteChance,
            damageModifier: physicalPowerMod,
            baseSurvivalRate: baseSurvivalRate
        });
    }

    // New function to calculate base dodge chance from attributes
    function calculateBaseDodgeChance(uint8 agility, uint8 size) internal pure returns (uint16) {
        uint16 agilityBonus = uint16(uint32(agility) * 35 / 100); // Increased from 0.3 to 0.35

        uint16 sizeModifier;
        if (size <= 21) {
            sizeModifier = uint16((21 - size) * 6 / 10); // Increased from 0.5 to 0.6
            return agilityBonus + sizeModifier;
        } else {
            sizeModifier = uint16(size - 21) * 6 / 10; // Keep same penalty for large sizes
            return sizeModifier >= agilityBonus ? 0 : agilityBonus - sizeModifier;
        }
    }

    // New function to apply armor and stance to dodge chance
    function calculateFinalDodgeChance(uint16 baseDodgeChance, CalculatedCombatStats memory stats)
        internal
        pure
        returns (uint16)
    {
        // First convert weight to int256, then negate
        int256 armorPenalty = -int256(uint256(stats.armor.weight));

        // Apply shield effect
        int256 shieldEffect = 0;
        if (stats.weapon.shieldType != ShieldType.NONE) {
            (,, uint16 dodgeModifier,) = getShieldStats(stats.weapon.shieldType);

            // Calculate percentage modification directly in int256
            int256 baseValue = int256(uint256(baseDodgeChance));
            int256 modifiedValue = baseValue * int256(uint256(dodgeModifier)) / 100;
            shieldEffect = modifiedValue - baseValue;
        }

        // Convert baseDodgeChance to int256 for calculation
        int256 finalDodge = int256(uint256(baseDodgeChance)) + armorPenalty + shieldEffect;

        // Return 0 if negative, otherwise convert back to uint16
        return finalDodge <= 0 ? 0 : uint16(uint256(finalDodge));
    }

    /// @notice Process a game between two players
    /// @param player1 The first player's combat loadout
    /// @param player2 The second player's loadout
    /// @param randomSeed The random seed for the game
    /// @param lethalityFactor The lethality factor for the game
    /// @return A byte array containing the encoded combat log
    function processGame(
        FighterStats calldata player1,
        FighterStats calldata player2,
        uint256 randomSeed,
        uint16 lethalityFactor
    ) external pure returns (bytes memory) {
        // Calculate all combat stats upfront
        CalculatedCombatStats memory p1Calculated = CalculatedCombatStats({
            stats: calculateStats(player1),
            weapon: getWeaponStats(player1.weapon),
            armor: getArmorStats(player1.armor),
            stanceMultipliers: getStanceMultiplier(player1.stance)
        });

        CalculatedCombatStats memory p2Calculated = CalculatedCombatStats({
            stats: calculateStats(player2),
            weapon: getWeaponStats(player2.weapon),
            armor: getArmorStats(player2.armor),
            stanceMultipliers: getStanceMultiplier(player2.stance)
        });

        // Apply stance modifiers to stats
        p1Calculated.stats = applyStanceModifiers(p1Calculated.stats, p1Calculated.stanceMultipliers);
        p2Calculated.stats = applyStanceModifiers(p2Calculated.stats, p2Calculated.stanceMultipliers);

        // Initialize combat with calculated stats
        CombatState memory state = initializeCombatState(randomSeed, p1Calculated, p2Calculated);

        bytes memory results = new bytes(4);
        uint8 roundCount = 0;
        uint256 currentSeed = randomSeed;

        while (state.p1Health > 0 && state.p2Health > 0 && roundCount < MAX_ROUNDS) {
            // Determine if anyone can attack this round
            bool canP1Attack = state.p1ActionPoints >= ATTACK_ACTION_COST;
            bool canP2Attack = state.p2ActionPoints >= ATTACK_ACTION_COST;

            // Only process combat if someone can attack
            if (canP1Attack || canP2Attack) {
                bool isPlayer1Attacking;
                if (canP1Attack && canP2Attack) {
                    // Both can attack, strictly compare points
                    isPlayer1Attacking = (state.p1ActionPoints > state.p2ActionPoints)
                        || (state.p1ActionPoints == state.p2ActionPoints && state.p1HasInitiative);
                } else {
                    // Only one can attack
                    isPlayer1Attacking = canP1Attack;
                }

                state.isPlayer1Turn = isPlayer1Attacking;

                // Deduct points BEFORE processing round
                if (isPlayer1Attacking) {
                    state.p1ActionPoints -= ATTACK_ACTION_COST;
                } else {
                    state.p2ActionPoints -= ATTACK_ACTION_COST;
                }

                // Process round and update state - only if an attack happened
                (currentSeed, results) =
                    processRound(state, currentSeed, results, p1Calculated, p2Calculated, lethalityFactor);
            }

            roundCount++;

            // Add action points for both players AFTER everything else
            unchecked {
                uint16 newP1Points = uint16(state.p1ActionPoints) + uint16(p1Calculated.weapon.attackSpeed);
                uint16 newP2Points = uint16(state.p2ActionPoints) + uint16(p2Calculated.weapon.attackSpeed);
                state.p1ActionPoints = newP1Points;
                state.p2ActionPoints = newP2Points;
            }
        }

        if (roundCount >= MAX_ROUNDS) {
            state.condition = WinCondition.MAX_ROUNDS;
            state.player1Won = state.p1Health >= state.p2Health;
        }

        return encodeCombatResults(state, results);
    }

    function initializeCombatState(
        uint256 seed,
        CalculatedCombatStats memory p1Calculated,
        CalculatedCombatStats memory p2Calculated
    ) private pure returns (CombatState memory state) {
        state = CombatState({
            p1Health: uint96(p1Calculated.stats.maxHealth),
            p2Health: uint96(p2Calculated.stats.maxHealth),
            p1Stamina: uint32(p1Calculated.stats.maxEndurance),
            p2Stamina: uint32(p2Calculated.stats.maxEndurance),
            p1ActionPoints: 0,
            p2ActionPoints: 0,
            isPlayer1Turn: false,
            player1Won: false,
            condition: WinCondition.HEALTH,
            p1HasInitiative: false
        });

        // Calculate initiative but only store it in state for tiebreakers
        uint32 p1Initiative = calculateTotalInitiative(p1Calculated);
        uint32 p2Initiative = calculateTotalInitiative(p2Calculated);
        seed = uint256(keccak256(abi.encodePacked(seed)));
        state.p1HasInitiative = p1Initiative > p2Initiative || (p1Initiative == p2Initiative && seed.uniform(2) == 0);

        return state;
    }

    function calculateTotalInitiative(CalculatedCombatStats memory stats) private pure returns (uint32) {
        uint32 equipmentInit = (stats.weapon.attackSpeed * 100) / stats.armor.weight;
        return ((equipmentInit * 90) + (uint32(stats.stats.initiative) * 10)) / 100;
    }

    function processRound(
        CombatState memory state,
        uint256 currentSeed,
        bytes memory results,
        CalculatedCombatStats memory p1Calculated,
        CalculatedCombatStats memory p2Calculated,
        uint16 lethalityFactor
    ) private pure returns (uint256, bytes memory) {
        uint256 seed = currentSeed;

        // Process combat turn with seed updates
        (
            uint8 attackResult,
            uint16 attackDamage,
            uint8 attackStaminaCost,
            uint8 defenseResult,
            uint16 defenseDamage,
            uint8 defenseStaminaCost,
            uint256 newSeed
        ) = processCombatTurn(
            state.isPlayer1Turn ? p1Calculated : p2Calculated,
            state.isPlayer1Turn ? p2Calculated : p1Calculated,
            state.isPlayer1Turn ? state.p1Stamina : state.p2Stamina,
            state.isPlayer1Turn ? state.p2Stamina : state.p1Stamina,
            seed
        );

        // Update combat state with new seed
        seed = uint256(keccak256(abi.encodePacked(newSeed)));
        updateCombatState(
            state,
            attackDamage,
            attackStaminaCost,
            defenseResult,
            defenseDamage,
            defenseStaminaCost,
            p1Calculated,
            p2Calculated,
            seed,
            lethalityFactor
        );

        // Append results and return new seed
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

        return (seed, results);
    }

    function calculateHitChance(CalculatedCombatStats memory attacker) private pure returns (uint8) {
        uint32 baseHitChance = uint32(attacker.stats.hitChance);
        uint32 weaponSpeedMod = 85 + ((uint32(attacker.weapon.attackSpeed) * 15) / 100);
        uint32 adjustedHitChance = (baseHitChance * weaponSpeedMod) / 100;
        uint32 withMin = adjustedHitChance < 60 ? 60 : adjustedHitChance;
        uint32 withBothBounds = withMin > 95 ? 95 : withMin;
        return uint8(withBothBounds);
    }

    function calculateCriticalDamage(CalculatedCombatStats memory attacker, uint16 baseDamage, uint256 seed)
        private
        pure
        returns (uint16 damage, uint8 result, uint256 nextSeed)
    {
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 critRoll = uint8(seed.uniform(100));
        bool isCritical = critRoll < attacker.stats.critChance;

        if (isCritical) {
            damage = uint16((uint32(baseDamage) * uint32(attacker.stats.critMultiplier)) / 100);
            result = uint8(CombatResultType.CRIT);
        } else {
            damage = baseDamage;
            result = uint8(CombatResultType.ATTACK);
        }
        return (damage, result, seed);
    }

    function calculateDamage(CalculatedCombatStats memory attacker, uint256 seed)
        private
        pure
        returns (uint16 damage, uint256 nextSeed)
    {
        uint64 damageRange = attacker.weapon.maxDamage >= attacker.weapon.minDamage
            ? attacker.weapon.maxDamage - attacker.weapon.minDamage
            : 0;
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint64 baseDamage = uint64(attacker.weapon.minDamage) + uint64(seed.uniform(damageRange + 1));

        uint64 scaledBase = baseDamage * 100;
        uint64 modifiedDamage = (scaledBase * uint64(attacker.stats.damageModifier)) / 10000;

        nextSeed = uint256(keccak256(abi.encodePacked(seed)));
        return (modifiedDamage > type(uint16).max ? type(uint16).max : uint16(modifiedDamage), nextSeed);
    }

    function processCombatTurn(
        CalculatedCombatStats memory attacker,
        CalculatedCombatStats memory defender,
        uint256 attackerStamina,
        uint256 defenderStamina,
        uint256 seed
    )
        private
        pure
        returns (
            uint8 attackResult,
            uint16 attackDamage,
            uint8 attackStaminaCost,
            uint8 defenseResult,
            uint16 defenseDamage,
            uint8 defenseStaminaCost,
            uint256 newSeed
        )
    {
        uint256 attackCost = calculateStaminaCost(ActionType.ATTACK, attacker);
        if (attackerStamina < attackCost) {
            return (uint8(CombatResultType.EXHAUSTED), 0, uint8(attackCost), 0, 0, 0, seed);
        }

        uint8 finalHitChance = calculateHitChance(attacker);
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 hitRoll = uint8(seed.uniform(100));

        uint256 modifiedStaminaCost = calculateStaminaCost(ActionType.ATTACK, attacker);

        if (hitRoll >= finalHitChance) {
            return (
                uint8(CombatResultType.ATTACK), 0, uint8(modifiedStaminaCost), uint8(CombatResultType.MISS), 0, 0, seed
            );
        }

        uint16 damage;
        (damage, seed) = calculateDamage(attacker, seed);
        (attackDamage, attackResult, seed) = calculateCriticalDamage(attacker, damage, seed);
        attackStaminaCost = uint8(modifiedStaminaCost);

        seed = uint256(keccak256(abi.encodePacked(seed)));
        (defenseResult, defenseDamage, defenseStaminaCost, seed) =
            processDefense(defender, defenderStamina, attackDamage, attacker.weapon.damageType, seed);

        if (
            defenseResult == uint8(CombatResultType.DODGE) || defenseResult == uint8(CombatResultType.BLOCK)
                || defenseResult == uint8(CombatResultType.PARRY)
        ) {
            attackDamage = 0;
        }

        return (attackResult, attackDamage, attackStaminaCost, defenseResult, defenseDamage, defenseStaminaCost, seed);
    }

    function processDefense(
        CalculatedCombatStats memory defender,
        uint256 defenderStamina,
        uint16 incomingDamage,
        DamageType damageType,
        uint256 seed
    ) private pure returns (uint8 result, uint16 damage, uint8 staminaCost, uint256 nextSeed) {
        // Get base chances
        uint16 baseBlockChance = defender.stats.blockChance;
        uint16 effectiveCounterChance = defender.stats.counterChance;

        // Apply shield modifiers if present
        if (defender.weapon.shieldType != ShieldType.NONE) {
            // Get shield stats
            (uint16 shieldBlockBonus, uint16 shieldCounterBonus,,) = getShieldStats(defender.weapon.shieldType);
            baseBlockChance = uint16((uint32(baseBlockChance) * uint32(shieldBlockBonus)) / 100);
            effectiveCounterChance = uint16((uint32(effectiveCounterChance) * uint32(shieldCounterBonus)) / 100);
        }

        uint16 effectiveParryChance =
            uint16((uint32(defender.stats.parryChance) * uint32(defender.weapon.parryChance)) / 100);
        uint16 finalDodgeChance = calculateFinalDodgeChance(defender.stats.dodgeChance, defender);

        // Block check - only allow if defender has a shield
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 blockRoll = uint8(seed.uniform(100));

        if (blockRoll < baseBlockChance && defender.weapon.shieldType != ShieldType.NONE) {
            // Only calculate stamina cost if needed
            uint256 blockStaminaCost = calculateStaminaCost(ActionType.BLOCK, defender);

            if (defenderStamina >= blockStaminaCost) {
                // Check for counter
                seed = uint256(keccak256(abi.encodePacked(seed)));
                uint8 counterRoll = uint8(seed.uniform(100));

                if (counterRoll < effectiveCounterChance) {
                    seed = uint256(keccak256(abi.encodePacked(seed)));
                    (result, damage, staminaCost, seed) = processCounterAttack(defender, seed, CounterType.COUNTER);
                    seed = uint256(keccak256(abi.encodePacked(seed)));
                    return (result, damage, staminaCost, seed);
                }

                seed = uint256(keccak256(abi.encodePacked(seed)));
                return (uint8(CombatResultType.BLOCK), 0, uint8(blockStaminaCost), seed);
            }
        }

        // Parry check
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 parryRoll = uint8(seed.uniform(100));

        if (parryRoll < effectiveParryChance) {
            // Only calculate stamina cost if needed
            uint256 parryStaminaCost = calculateStaminaCost(ActionType.PARRY, defender);

            if (defenderStamina >= parryStaminaCost) {
                seed = uint256(keccak256(abi.encodePacked(seed)));
                uint8 riposteRoll = uint8(seed.uniform(100));

                uint16 effectiveRiposteChance =
                    uint16((uint32(defender.stats.riposteChance) * uint32(defender.weapon.riposteChance)) / 100);

                if (riposteRoll < effectiveRiposteChance) {
                    seed = uint256(keccak256(abi.encodePacked(seed)));
                    return processCounterAttack(defender, seed, CounterType.PARRY);
                }

                return (uint8(CombatResultType.PARRY), 0, uint8(parryStaminaCost), seed);
            }
        }

        // Dodge check
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 dodgeRoll = uint8(seed.uniform(100));

        if (dodgeRoll < finalDodgeChance) {
            // Only calculate stamina cost if needed
            uint256 dodgeStaminaCost = calculateStaminaCost(ActionType.DODGE, defender);

            if (defenderStamina >= dodgeStaminaCost) {
                return (uint8(CombatResultType.DODGE), 0, uint8(dodgeStaminaCost), seed);
            }
        }

        // If all defensive actions fail, apply armor reduction and return fresh seed
        uint16 reducedDamage = applyDefensiveStats(incomingDamage, defender.armor, damageType);
        seed = uint256(keccak256(abi.encodePacked(seed))); // Fresh seed before return
        return (uint8(CombatResultType.HIT), reducedDamage, 0, seed);
    }

    function processCounterAttack(CalculatedCombatStats memory defender, uint256 seed, CounterType counterType)
        private
        pure
        returns (uint8 result, uint16 damage, uint8 staminaCost, uint256 nextSeed)
    {
        uint16 counterDamage;
        (counterDamage, seed) = calculateDamage(defender, seed);

        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 critRoll = uint8(seed.uniform(100));
        bool isCritical = critRoll < defender.stats.critChance;

        // Determine the action type based on counter type
        ActionType actionType = counterType == CounterType.PARRY ? ActionType.RIPOSTE : ActionType.COUNTER;

        if (isCritical) {
            uint32 totalMultiplier =
                (uint32(defender.stats.critMultiplier) * uint32(defender.weapon.critMultiplier)) / 100;
            counterDamage = uint16((uint32(counterDamage) * totalMultiplier) / 100);

            uint256 critModifiedStaminaCost = calculateStaminaCost(actionType, defender);

            seed = uint256(keccak256(abi.encodePacked(seed)));
            return (
                uint8(counterType == CounterType.PARRY ? CombatResultType.RIPOSTE_CRIT : CombatResultType.COUNTER_CRIT),
                counterDamage,
                uint8(critModifiedStaminaCost),
                seed
            );
        }

        uint256 normalModifiedStaminaCost = calculateStaminaCost(actionType, defender);

        seed = uint256(keccak256(abi.encodePacked(seed)));
        return (
            uint8(counterType == CounterType.PARRY ? CombatResultType.RIPOSTE : CombatResultType.COUNTER),
            counterDamage,
            uint8(normalModifiedStaminaCost),
            seed
        );
    }

    function minUint256(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function minUint16(uint16 a, uint16 b) private pure returns (uint16) {
        return a < b ? a : b;
    }

    function applyDamage(uint96 currentHealth, uint16 damage) private pure returns (uint96) {
        unchecked {
            return currentHealth > damage ? currentHealth - damage : 0;
        }
    }

    function applyDefensiveStats(uint16 incomingDamage, ArmorStats memory armor, DamageType damageType)
        private
        pure
        returns (uint16)
    {
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

    function getResistanceForDamageType(ArmorStats memory armor, DamageType damageType) private pure returns (uint16) {
        if (damageType == DamageType.Slashing) {
            return armor.slashResist;
        } else if (damageType == DamageType.Piercing) {
            return armor.pierceResist;
        } else if (damageType == DamageType.Blunt) {
            return armor.bluntResist;
        } else if (damageType == DamageType.Hybrid_Slash_Pierce) {
            // Use the lower resistance (more favorable to attacker)
            return minUint16(armor.slashResist, armor.pierceResist);
        } else if (damageType == DamageType.Hybrid_Slash_Blunt) {
            return minUint16(armor.slashResist, armor.bluntResist);
        } else if (damageType == DamageType.Hybrid_Pierce_Blunt) {
            return minUint16(armor.pierceResist, armor.bluntResist);
        }
        return 0;
    }

    // Add new function to apply stance modifiers
    function applyStanceModifiers(CalculatedStats memory stats, StanceMultiplier memory stance)
        private
        pure
        returns (CalculatedStats memory)
    {
        return CalculatedStats({
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
            riposteChance: uint16((uint32(stats.riposteChance) * uint32(stance.riposteChance)) / 100),
            damageModifier: uint16((uint32(stats.damageModifier) * uint32(stance.damageModifier)) / 100),
            baseSurvivalRate: stats.baseSurvivalRate
        });
    }

    function applyDamageAndCheckLethality(
        CombatState memory state,
        uint16 damage,
        CalculatedCombatStats memory attackerStats,
        CalculatedCombatStats memory defenderStats,
        bool isPlayer1Attacker,
        uint256 seed,
        uint16 lethalityFactor
    ) private pure {
        uint96 currentHealth = isPlayer1Attacker ? state.p2Health : state.p1Health;
        currentHealth = applyDamage(currentHealth, damage);

        if (isPlayer1Attacker) {
            state.p2Health = currentHealth;
        } else {
            state.p1Health = currentHealth;
        }

        // Check for lethal damage
        if (
            currentHealth > 0
                && isLethalDamage(
                    damage,
                    defenderStats.stats.maxHealth,
                    defenderStats.stats,
                    attackerStats.weapon,
                    defenderStats.stanceMultipliers,
                    seed,
                    lethalityFactor
                )
        ) {
            if (isPlayer1Attacker) {
                state.p2Health = 0;
                state.player1Won = true; // Player 1 killed Player 2
            } else {
                state.p1Health = 0;
                state.player1Won = false; // Player 2 killed Player 1
            }
            state.condition = WinCondition.DEATH;
        } else if (currentHealth == 0) {
            state.player1Won = isPlayer1Attacker; // If P1 is attacking, they won; if P2 is attacking, they won
            state.condition = WinCondition.HEALTH;
        }
    }

    function updateCombatState(
        CombatState memory state,
        uint16 attackDamage,
        uint8 attackStaminaCost,
        uint8 defenseResult,
        uint16 defenseDamage,
        uint8 defenseStaminaCost,
        CalculatedCombatStats memory p1Calculated,
        CalculatedCombatStats memory p2Calculated,
        uint256 seed,
        uint16 lethalityFactor
    ) private pure {
        // Apply stamina costs based on turn
        uint32 attackerStamina = state.isPlayer1Turn ? state.p1Stamina : state.p2Stamina;
        uint32 defenderStamina = state.isPlayer1Turn ? state.p2Stamina : state.p1Stamina;

        attackerStamina = attackerStamina > attackStaminaCost ? attackerStamina - attackStaminaCost : 0;
        defenderStamina = defenderStamina > defenseStaminaCost ? defenderStamina - defenseStaminaCost : 0;

        if (state.isPlayer1Turn) {
            state.p1Stamina = attackerStamina;
            state.p2Stamina = defenderStamina;
        } else {
            state.p2Stamina = attackerStamina;
            state.p1Stamina = defenderStamina;
        }

        // Apply attack damage if defense wasn't successful
        if (
            defenseResult != uint8(CombatResultType.PARRY) && defenseResult != uint8(CombatResultType.BLOCK)
                && defenseResult != uint8(CombatResultType.DODGE) && defenseResult != uint8(CombatResultType.COUNTER)
                && defenseResult != uint8(CombatResultType.COUNTER_CRIT) && defenseResult != uint8(CombatResultType.RIPOSTE)
                && defenseResult != uint8(CombatResultType.RIPOSTE_CRIT)
        ) {
            applyDamageAndCheckLethality(
                state,
                attackDamage,
                state.isPlayer1Turn ? p1Calculated : p2Calculated,
                state.isPlayer1Turn ? p2Calculated : p1Calculated,
                state.isPlayer1Turn,
                seed,
                lethalityFactor
            );
        }

        // Apply counter damage if any AND defender is still alive
        if (
            defenseDamage > 0
                && ((state.isPlayer1Turn && state.p2Health > 0) || (!state.isPlayer1Turn && state.p1Health > 0))
        ) {
            applyDamageAndCheckLethality(
                state,
                defenseDamage,
                state.isPlayer1Turn ? p2Calculated : p1Calculated,
                state.isPlayer1Turn ? p1Calculated : p2Calculated,
                !state.isPlayer1Turn,
                uint256(keccak256(abi.encodePacked(seed))),
                lethalityFactor
            );
        }
    }

    /**
     * @dev Combat action byte layout (8 bytes total):
     * Player 1's data is always in bytes 0-3, Player 2's data in bytes 4-7
     * For each player's 4-byte section:
     * - Byte 0: Result type (attack/defense)
     * - Bytes 1-2: Damage value (high byte, low byte)
     * - Byte 3: Stamina cost
     * @param results The existing combat log to append to
     * @param attackResult The result type of the attack action
     * @param attackDamage The damage dealt by the attack
     * @param attackStaminaCost The stamina cost of the attack
     * @param defenseResult The result type of the defense action
     * @param defenseDamage The damage dealt by any counter-attack
     * @param defenseStaminaCost The stamina cost of the defense
     * @param isPlayer1Attacking Whether Player 1 is the attacker in this action
     * @return The updated combat log with the new action appended
     */
    function appendCombatAction(
        bytes memory results,
        uint8 attackResult,
        uint16 attackDamage,
        uint8 attackStaminaCost,
        uint8 defenseResult,
        uint16 defenseDamage,
        uint8 defenseStaminaCost,
        bool isPlayer1Attacking
    ) private pure returns (bytes memory) {
        bytes memory actionData = new bytes(8);

        // Pack attacker and defender data into the correct player positions
        if (isPlayer1Attacking) {
            packPlayerData(actionData, 0, attackResult, attackDamage, attackStaminaCost); // P1 attack
            packPlayerData(actionData, 4, defenseResult, defenseDamage, defenseStaminaCost); // P2 defense
        } else {
            packPlayerData(actionData, 0, defenseResult, defenseDamage, defenseStaminaCost); // P1 defense
            packPlayerData(actionData, 4, attackResult, attackDamage, attackStaminaCost); // P2 attack
        }

        return bytes.concat(results, actionData);
    }

    /**
     * @dev Packs a player's combat data into 4 bytes starting at the specified offset
     * @param data The byte array to pack into
     * @param offset Starting position in the byte array (0 or 4)
     * @param result Action result type
     * @param damage Damage value (packed into 2 bytes)
     * @param staminaCost Stamina cost
     */
    function packPlayerData(bytes memory data, uint256 offset, uint8 result, uint16 damage, uint8 staminaCost)
        private
        pure
    {
        data[offset] = bytes1(result);
        data[offset + 1] = bytes1(uint8(damage >> 8));
        data[offset + 2] = bytes1(uint8(damage));
        data[offset + 3] = bytes1(staminaCost);
    }

    /// @dev TODO: Potential optimization - Instead of allocating prefix bytes (winner, version, condition) upfront
    /// and carrying them through combat, consider only storing combat actions during the fight and concatenating
    /// the prefix at the end. This would reduce memory copying in appendCombatAction and be more gas efficient.
    function encodeCombatResults(CombatState memory state, bytes memory results) private pure returns (bytes memory) {
        require(results.length >= 4, "Invalid results length");

        // Write single byte for winner (0 for player1, 1 for player2)
        results[0] = bytes1(state.player1Won ? uint8(0) : uint8(1));

        // Write version (2 bytes)
        results[1] = bytes1(uint8(version >> 8));
        results[2] = bytes1(uint8(version));

        // Write condition
        results[3] = bytes1(uint8(state.condition));

        return results;
    }

    function calculateStaminaCost(ActionType actionType, CalculatedCombatStats memory stats)
        internal
        pure
        returns (uint256)
    {
        // Get base cost by action type
        uint256 baseCost;
        if (actionType == ActionType.ATTACK) {
            baseCost = STAMINA_ATTACK;
        } else if (actionType == ActionType.BLOCK) {
            baseCost = STAMINA_BLOCK;
        } else if (actionType == ActionType.DODGE) {
            baseCost = STAMINA_DODGE;
        } else if (actionType == ActionType.PARRY) {
            baseCost = STAMINA_PARRY;
        } else if (actionType == ActionType.COUNTER) {
            baseCost = STAMINA_COUNTER;
        } else if (actionType == ActionType.RIPOSTE) {
            baseCost = STAMINA_RIPOSTE;
        }

        // Apply modifiers
        uint256 staminaCost = baseCost * stats.stanceMultipliers.staminaCostModifier * stats.weapon.staminaMultiplier;

        // Apply shield modifier only for block action
        if (actionType == ActionType.BLOCK && stats.weapon.shieldType != ShieldType.NONE) {
            (,,, uint16 shieldStaminaModifier) = getShieldStats(stats.weapon.shieldType);
            staminaCost = staminaCost * shieldStaminaModifier;
        }

        // Apply armor weight modifier - more reasonable scaling
        uint256 armorImpact;
        if (actionType == ActionType.DODGE) {
            // Reduced impact on dodge (1.5x instead of 3x)
            armorImpact = 100 + (stats.armor.weight * 3 / 2);
        } else if (
            actionType == ActionType.ATTACK || actionType == ActionType.PARRY || actionType == ActionType.COUNTER
                || actionType == ActionType.RIPOSTE
        ) {
            // Reduced impact on offensive actions (0.5x instead of 1x)
            armorImpact = 100 + (stats.armor.weight / 2);
        } else {
            // Minimal impact on block (0.25x instead of 0.5x)
            armorImpact = 100 + (stats.armor.weight / 4);
        }

        staminaCost = (staminaCost * armorImpact) / 100;

        return staminaCost / 1000000; // Division after all multiplications
    }

    // =============================================
    // WEAPON STATS
    // =============================================

    function ARMING_SWORD_KITE() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 36,
            maxDamage: 48,
            attackSpeed: 65,
            parryChance: 100,
            riposteChance: 100,
            critMultiplier: 200,
            staminaMultiplier: 100,
            survivalFactor: 100,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.KITE_SHIELD
        });
    }

    function MACE_TOWER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 40,
            maxDamage: 54,
            attackSpeed: 60,
            parryChance: 80,
            riposteChance: 70,
            critMultiplier: 220,
            staminaMultiplier: 120,
            survivalFactor: 120,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.TOWER_SHIELD
        });
    }

    function RAPIER_BUCKLER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 29,
            maxDamage: 59,
            attackSpeed: 100,
            parryChance: 120,
            riposteChance: 130,
            critMultiplier: 200,
            staminaMultiplier: 80,
            survivalFactor: 120,
            damageType: DamageType.Piercing,
            shieldType: ShieldType.BUCKLER
        });
    }

    function GREATSWORD() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 80,
            maxDamage: 110,
            attackSpeed: 50,
            parryChance: 80,
            riposteChance: 80,
            critMultiplier: 250,
            staminaMultiplier: 180,
            survivalFactor: 85,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.NONE
        });
    }

    function BATTLEAXE() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 101,
            maxDamage: 129,
            attackSpeed: 40,
            parryChance: 50,
            riposteChance: 50,
            critMultiplier: 300,
            staminaMultiplier: 180,
            survivalFactor: 80,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.NONE
        });
    }

    function QUARTERSTAFF() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 60,
            maxDamage: 71,
            attackSpeed: 70,
            parryChance: 120,
            riposteChance: 130,
            critMultiplier: 200,
            staminaMultiplier: 100,
            survivalFactor: 100,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.NONE
        });
    }

    function SPEAR() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 38,
            maxDamage: 74,
            attackSpeed: 60,
            parryChance: 80,
            riposteChance: 90,
            critMultiplier: 260,
            staminaMultiplier: 140,
            survivalFactor: 90,
            damageType: DamageType.Piercing,
            shieldType: ShieldType.NONE
        });
    }

        function SHORTSWORD_BUCKLER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 32,
            maxDamage: 44,
            attackSpeed: 80,
            parryChance: 110,
            riposteChance: 115,
            critMultiplier: 190,
            staminaMultiplier: 90,
            survivalFactor: 110,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.BUCKLER
        });
    }

    function SHORTSWORD_TOWER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 32,
            maxDamage: 44,
            attackSpeed: 75,
            parryChance: 100,
            riposteChance: 105,
            critMultiplier: 190,
            staminaMultiplier: 105,
            survivalFactor: 125,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.TOWER_SHIELD
        });
    }

    function SCIMITAR_BUCKLER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 34,
            maxDamage: 50,
            attackSpeed: 75,
            parryChance: 105,
            riposteChance: 110,
            critMultiplier: 210,
            staminaMultiplier: 95,
            survivalFactor: 110,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.BUCKLER
        });
    }

    function AXE_KITE() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 45,
            maxDamage: 55,
            attackSpeed: 60,
            parryChance: 80,
            riposteChance: 75,
            critMultiplier: 230,
            staminaMultiplier: 115,
            survivalFactor: 105,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.KITE_SHIELD
        });
    }

    function AXE_TOWER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 45,
            maxDamage: 55,
            attackSpeed: 55,
            parryChance: 70,
            riposteChance: 65,
            critMultiplier: 230,
            staminaMultiplier: 130,
            survivalFactor: 130,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.TOWER_SHIELD
        });
    }

    function FLAIL_BUCKLER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 38,
            maxDamage: 58,
            attackSpeed: 65,
            parryChance: 60,
            riposteChance: 70,
            critMultiplier: 240,
            staminaMultiplier: 110,
            survivalFactor: 105,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.BUCKLER
        });
    }

    function MACE_KITE() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 40,
            maxDamage: 54,
            attackSpeed: 60,
            parryChance: 85,
            riposteChance: 75,
            critMultiplier: 220,
            staminaMultiplier: 110,
            survivalFactor: 110,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.KITE_SHIELD
        });
    }

    function CLUB_TOWER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 42,
            maxDamage: 50,
            attackSpeed: 60,
            parryChance: 75,
            riposteChance: 65,
            critMultiplier: 210,
            staminaMultiplier: 115,
            survivalFactor: 125,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.TOWER_SHIELD
        });
    }

    // Dual-wield weapons
    function DUAL_DAGGERS() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 20,
            maxDamage: 46,
            attackSpeed: 130,
            parryChance: 110,
            riposteChance: 125,
            critMultiplier: 180,
            staminaMultiplier: 85,
            survivalFactor: 95,
            damageType: DamageType.Piercing,
            shieldType: ShieldType.NONE
        });
    }

    function RAPIER_DAGGER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 28,
            maxDamage: 55,
            attackSpeed: 110,
            parryChance: 125,
            riposteChance: 135,
            critMultiplier: 190,
            staminaMultiplier: 85,
            survivalFactor: 110,
            damageType: DamageType.Piercing,
            shieldType: ShieldType.NONE
        });
    }

    function DUAL_SCIMITARS() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 36,
            maxDamage: 52,
            attackSpeed: 95,
            parryChance: 110,
            riposteChance: 115,
            critMultiplier: 210,
            staminaMultiplier: 100,
            survivalFactor: 90,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.NONE
        });
    }

    function DUAL_CLUBS() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 40,
            maxDamage: 54,
            attackSpeed: 85,
            parryChance: 90,
            riposteChance: 80,
            critMultiplier: 230,
            staminaMultiplier: 120,
            survivalFactor: 95,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.NONE
        });
    }

    // Mixed damage type weapons
    function ARMING_SWORD_SHORTSWORD() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 34,
            maxDamage: 46,
            attackSpeed: 80,
            parryChance: 110,
            riposteChance: 115,
            critMultiplier: 195,
            staminaMultiplier: 95,
            survivalFactor: 100,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.NONE
        });
    }

    function SCIMITAR_DAGGER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 30,
            maxDamage: 48,
            attackSpeed: 105,
            parryChance: 115,
            riposteChance: 120,
            critMultiplier: 200,
            staminaMultiplier: 90,
            survivalFactor: 100,
            damageType: DamageType.Hybrid_Slash_Pierce,
            shieldType: ShieldType.NONE
        });
    }

    function ARMING_SWORD_CLUB() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 38,
            maxDamage: 49,
            attackSpeed: 70,
            parryChance: 100,
            riposteChance: 95,
            critMultiplier: 215,
            staminaMultiplier: 110,
            survivalFactor: 100,
            damageType: DamageType.Hybrid_Slash_Blunt,
            shieldType: ShieldType.NONE
        });
    }

    function AXE_MACE() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 43,
            maxDamage: 54,
            attackSpeed: 60,
            parryChance: 75,
            riposteChance: 70,
            critMultiplier: 225,
            staminaMultiplier: 125,
            survivalFactor: 100,
            damageType: DamageType.Hybrid_Slash_Blunt,
            shieldType: ShieldType.NONE
        });
    }

    function FLAIL_DAGGER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 34,
            maxDamage: 52,
            attackSpeed: 75,
            parryChance: 85,
            riposteChance: 90,
            critMultiplier: 220,
            staminaMultiplier: 105,
            survivalFactor: 95,
            damageType: DamageType.Hybrid_Pierce_Blunt,
            shieldType: ShieldType.NONE
        });
    }

    function MACE_SHORTSWORD() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 38,
            maxDamage: 52,
            attackSpeed: 65,
            parryChance: 90,
            riposteChance: 85,
            critMultiplier: 215,
            staminaMultiplier: 110,
            survivalFactor: 105,
            damageType: DamageType.Hybrid_Slash_Blunt,
            shieldType: ShieldType.NONE
        });
    }

    // Additional two-handed weapons
    function MAUL() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 90,
            maxDamage: 120,
            attackSpeed: 40,
            parryChance: 60,
            riposteChance: 50,
            critMultiplier: 280,
            staminaMultiplier: 175,
            survivalFactor: 85,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.NONE
        });
    }

    function TRIDENT() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 75,
            maxDamage: 95,
            attackSpeed: 55,
            parryChance: 90,
            riposteChance: 80,
            critMultiplier: 230,
            staminaMultiplier: 150,
            survivalFactor: 90,
            damageType: DamageType.Piercing,
            shieldType: ShieldType.NONE
        });
    }

    function getWeaponStats(uint8 weapon) public pure returns (WeaponStats memory) {
        if (weapon == WEAPON_ARMING_SWORD_KITE) return ARMING_SWORD_KITE();
        if (weapon == WEAPON_MACE_TOWER) return MACE_TOWER();
        if (weapon == WEAPON_RAPIER_BUCKLER) return RAPIER_BUCKLER();
        if (weapon == WEAPON_GREATSWORD) return GREATSWORD();
        if (weapon == WEAPON_BATTLEAXE) return BATTLEAXE();
        if (weapon == WEAPON_QUARTERSTAFF) return QUARTERSTAFF();
        if (weapon == WEAPON_SPEAR) return SPEAR();
        if (weapon == WEAPON_SHORTSWORD_BUCKLER) return SHORTSWORD_BUCKLER();
        if (weapon == WEAPON_SHORTSWORD_TOWER) return SHORTSWORD_TOWER();
        if (weapon == WEAPON_DUAL_DAGGERS) return DUAL_DAGGERS();
        if (weapon == WEAPON_RAPIER_DAGGER) return RAPIER_DAGGER();
        if (weapon == WEAPON_SCIMITAR_BUCKLER) return SCIMITAR_BUCKLER();
        if (weapon == WEAPON_AXE_KITE) return AXE_KITE();
        if (weapon == WEAPON_AXE_TOWER) return AXE_TOWER();
        if (weapon == WEAPON_DUAL_SCIMITARS) return DUAL_SCIMITARS();
        if (weapon == WEAPON_FLAIL_BUCKLER) return FLAIL_BUCKLER();
        if (weapon == WEAPON_MACE_KITE) return MACE_KITE();
        if (weapon == WEAPON_CLUB_TOWER) return CLUB_TOWER();
        if (weapon == WEAPON_DUAL_CLUBS) return DUAL_CLUBS();
        if (weapon == WEAPON_ARMING_SWORD_SHORTSWORD) return ARMING_SWORD_SHORTSWORD();
        if (weapon == WEAPON_SCIMITAR_DAGGER) return SCIMITAR_DAGGER();
        if (weapon == WEAPON_ARMING_SWORD_CLUB) return ARMING_SWORD_CLUB();
        if (weapon == WEAPON_AXE_MACE) return AXE_MACE();
        if (weapon == WEAPON_FLAIL_DAGGER) return FLAIL_DAGGER();
        if (weapon == WEAPON_MACE_SHORTSWORD) return MACE_SHORTSWORD();
        if (weapon == WEAPON_MAUL) return MAUL();
        if (weapon == WEAPON_TRIDENT) return TRIDENT();
        revert("Invalid weapon type");
    }

    // =============================================
    // ARMOR STATS
    // =============================================

    function CLOTH() public pure returns (ArmorStats memory) {
        return ArmorStats({defense: 0, weight: 5, slashResist: 70, pierceResist: 70, bluntResist: 80});
    }

    function LEATHER() public pure returns (ArmorStats memory) {
        return ArmorStats({defense: 15, weight: 20, slashResist: 90, pierceResist: 85, bluntResist: 90});
    }

    function CHAIN() public pure returns (ArmorStats memory) {
        return ArmorStats({defense: 30, weight: 50, slashResist: 110, pierceResist: 70, bluntResist: 100});
    }

    function PLATE() public pure returns (ArmorStats memory) {
        return ArmorStats({defense: 60, weight: 100, slashResist: 120, pierceResist: 90, bluntResist: 80});
    }

    function getArmorStats(uint8 armor) public pure returns (ArmorStats memory) {
        if (armor == ARMOR_CLOTH) return CLOTH();
        if (armor == ARMOR_LEATHER) return LEATHER();
        if (armor == ARMOR_CHAIN) return CHAIN();
        if (armor == ARMOR_PLATE) return PLATE();
        revert("Invalid armor type");
    }

    // =============================================
    // STANCES
    // =============================================

    function DEFENSIVE_STANCE() public pure returns (StanceMultiplier memory) {
        return StanceMultiplier({
            damageModifier: 75,
            hitChance: 85,
            critChance: 70,
            critMultiplier: 90,
            blockChance: 130,
            parryChance: 120,
            dodgeChance: 115,
            counterChance: 115,
            riposteChance: 115,
            staminaCostModifier: 85,
            survivalFactor: 120
        });
    }

    function BALANCED_STANCE() public pure returns (StanceMultiplier memory) {
        return StanceMultiplier({
            damageModifier: 100,
            hitChance: 100,
            critChance: 100,
            critMultiplier: 100,
            blockChance: 100,
            parryChance: 100,
            dodgeChance: 100,
            counterChance: 100,
            riposteChance: 100,
            staminaCostModifier: 100,
            survivalFactor: 100
        });
    }

    function OFFENSIVE_STANCE() public pure returns (StanceMultiplier memory) {
        return StanceMultiplier({
            damageModifier: 115,
            hitChance: 110,
            critChance: 110,
            critMultiplier: 135,
            blockChance: 85,
            parryChance: 85,
            dodgeChance: 85,
            counterChance: 85,
            riposteChance: 85,
            staminaCostModifier: 150,
            survivalFactor: 60
        });
    }

    function getStanceMultiplier(uint8 stance) public pure returns (StanceMultiplier memory) {
        if (stance == STANCE_DEFENSIVE) return DEFENSIVE_STANCE();
        if (stance == STANCE_OFFENSIVE) return OFFENSIVE_STANCE();
        return BALANCED_STANCE();
    }

    function isLethalDamage(
        uint16 attackerDamage,
        uint16 defenderMaxHealth,
        CalculatedStats memory defenderStats,
        WeaponStats memory weapon,
        StanceMultiplier memory defenderStance,
        uint256 seed,
        uint16 lethalityFactor
    ) private pure returns (bool died) {
        // Early return if lethality is disabled
        if (lethalityFactor == 0) return false;

        uint32 damagePercent = ((uint32(attackerDamage) * 100) / defenderMaxHealth);

        if (damagePercent <= DAMAGE_THRESHOLD_PERCENT) {
            return false;
        }

        uint16 survivalChance = defenderStats.baseSurvivalRate;

        uint32 excessDamage = damagePercent - DAMAGE_THRESHOLD_PERCENT;
        excessDamage = excessDamage > MAX_DAMAGE_OVERAGE ? MAX_DAMAGE_OVERAGE : excessDamage;
        survivalChance = survivalChance > excessDamage ? survivalChance - uint16(excessDamage) : 0;

        // Apply lethality factor BEFORE defensive bonuses
        survivalChance = uint16((uint32(survivalChance) * 100) / lethalityFactor);

        // Only apply weapon survival factor (defenderStats already has stance effect)
        uint32 modifiedSurvival = (uint32(survivalChance) * weapon.survivalFactor) / 100;

        // Cap survival between MINIMUM_SURVIVAL_CHANCE and BASE_SURVIVAL_CHANCE
        survivalChance = uint16(
            modifiedSurvival < MINIMUM_SURVIVAL_CHANCE
                ? MINIMUM_SURVIVAL_CHANCE
                : modifiedSurvival > BASE_SURVIVAL_CHANCE ? BASE_SURVIVAL_CHANCE : modifiedSurvival
        );

        seed = uint256(keccak256(abi.encodePacked(seed)));
        return uint8(seed.uniform(100)) >= survivalChance;
    }

    function getShieldStats(ShieldType shieldType)
        internal
        pure
        returns (uint16 blockChance, uint16 counterChance, uint16 dodgeModifier, uint16 staminaModifier)
    {
        if (shieldType == ShieldType.BUCKLER) {
            return (80, 130, 95, 90); // Good counter, small dodge penalty, low stamina cost
        } else if (shieldType == ShieldType.KITE_SHIELD) {
            return (100, 100, 90, 100); // Balanced, moderate dodge penalty
        } else if (shieldType == ShieldType.TOWER_SHIELD) {
            return (130, 70, 80, 120); // Great blocking, poor counter, higher dodge penalty and stamina cost
        }

        return (0, 0, 100, 100); // NONE - no shield bonuses, no dodge penalty
    }

}

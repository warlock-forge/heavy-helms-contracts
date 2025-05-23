// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import "../../lib/UniformRandomNumber.sol";
import "../../interfaces/fighters/IPlayer.sol";
import "../../interfaces/game/engine/IGameEngine.sol";

contract GameEngine is IGameEngine {
    using UniformRandomNumber for uint256;

    uint16 public constant version = 22;

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
        Hybrid_Slash_Pierce, // For weapons mixing slashing and piercing
        Hybrid_Slash_Blunt, // For weapons mixing slashing and blunt
        Hybrid_Pierce_Blunt // For weapons mixing piercing and blunt

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
        uint16 dodgeBonus; // New field for dodge bonus
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
    uint8 private immutable STAMINA_ATTACK = 13;
    uint8 private immutable STAMINA_BLOCK = 3;
    uint8 private immutable STAMINA_DODGE = 4;
    uint8 private immutable STAMINA_COUNTER = 6;
    uint8 private immutable STAMINA_PARRY = 4;
    uint8 private immutable STAMINA_RIPOSTE = 6;
    uint8 private immutable MAX_ROUNDS = 70;
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
        // Health calculation remains unchanged
        uint32 healthBase = 50;
        uint32 healthFromCon = uint32(player.attributes.constitution) * 15;
        uint32 healthFromSize = uint32(player.attributes.size) * 6;
        uint32 healthFromStamina = uint32(player.attributes.stamina) * 3;
        uint16 maxHealth = uint16(healthBase + healthFromCon + healthFromSize + healthFromStamina);

        // Moderate endurance adjustment - less severe than before
        uint32 enduranceBase = 35;
        uint32 enduranceFromStamina = uint32(player.attributes.stamina) * 16;
        uint32 enduranceFromStrength = uint32(player.attributes.strength) * 2;
        uint16 maxEndurance = uint16(enduranceBase + enduranceFromStamina + enduranceFromStrength);

        // Safe initiative calculation
        uint32 initiativeBase = 20;
        uint32 initiativeFromAgility = uint32(player.attributes.agility) * 3;
        uint32 initiativeFromLuck = uint32(player.attributes.luck) * 2;
        uint16 initiative = uint16(initiativeBase + initiativeFromAgility + initiativeFromLuck);

        // Safe defensive stats calculation
        uint16 dodgeChance =
            calculateDodgeChance(player.attributes.agility, player.attributes.size, player.attributes.stamina);
        uint16 blockChance = calculateBlockChance(player.attributes.constitution, player.attributes.size);
        uint16 parryChance =
            calculateParryChance(player.attributes.strength, player.attributes.agility, player.attributes.stamina);

        // New hit chance calculation
        uint32 baseChance = 50;
        uint32 agilityBonus = uint32(player.attributes.agility);
        uint32 luckBonus = uint32(player.attributes.luck) * 2;
        uint16 hitChance = uint16(baseChance + agilityBonus + luckBonus);

        // Safe crit calculations
        uint16 critChance =
            2 + uint16(uint32(player.attributes.agility) / 3) + uint16(uint32(player.attributes.luck) / 3);
        uint16 critMultiplier =
            uint16(150 + (uint32(player.attributes.strength) * 3) + (uint32(player.attributes.size) * 2));

        // Safe counter chance calculation (strength + agility based)
        uint16 counterChance = uint16(3 + uint32(player.attributes.strength) + uint32(player.attributes.agility));

        // Safe riposte chance calculation (agility + luck based)
        uint16 riposteChance = uint16(
            3 + uint32(player.attributes.agility) + uint32(player.attributes.luck)
                + (uint32(player.attributes.constitution) * 3 / 10)
        );

        // Physical power calculation
        uint32 combinedStats = uint32(player.attributes.strength) + uint32(player.attributes.size);
        uint32 tempPowerMod = 25 + (combinedStats * 5);
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

    function calculateBlockChance(uint8 constitution, uint8 size) internal pure returns (uint16) {
        return uint16(2 + (uint32(constitution) * 35 / 100) + (uint32(size) * 30 / 100));
    }

    function calculateParryChance(uint8 strength, uint8 agility, uint8 stamina) internal pure returns (uint16) {
        return uint16(2 + (uint32(strength) * 40 / 100) + (uint32(agility) * 35 / 100) + (uint32(stamina) * 30 / 100)); // Increased multipliers
    }

    function calculateDodgeChance(uint8 agility, uint8 size, uint8 stamina) internal pure returns (uint16) {
        uint16 baseDodge = 7;
        uint32 agilityBonus = uint32(agility) * 30 / 100;
        uint32 staminaBonus = uint32(stamina) * 20 / 100;
        baseDodge += uint16(agilityBonus + staminaBonus);

        if (size <= 21) {
            uint32 sizeModifier = uint32(21 - size) * 10 / 100;
            return uint16(baseDodge + sizeModifier);
        } else {
            uint32 sizeModifier = uint32(size - 21) * 10 / 100;
            return sizeModifier >= baseDodge ? 0 : uint16(baseDodge - sizeModifier);
        }
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
            // Determine if anyone can attack this round, including stamina check
            bool canP1Attack = state.p1ActionPoints >= ATTACK_ACTION_COST
                && state.p1Stamina >= calculateStaminaCost(ActionType.ATTACK, p1Calculated);
            bool canP2Attack = state.p2ActionPoints >= ATTACK_ACTION_COST
                && state.p2Stamina >= calculateStaminaCost(ActionType.ATTACK, p2Calculated);

            // First check if any player has 0 health - this should take precedence
            if (state.p1Health == 0) {
                state.condition = WinCondition.HEALTH;
                state.player1Won = false; // Player 2 wins regardless of stamina
                break;
            } else if (state.p2Health == 0) {
                state.condition = WinCondition.HEALTH;
                state.player1Won = true; // Player 1 wins regardless of stamina
                break;
            }

            // Only check exhaustion if both players still have health
            if (!canP1Attack && canP2Attack && state.p1ActionPoints >= ATTACK_ACTION_COST) {
                state.condition = WinCondition.EXHAUSTION;
                state.player1Won = false; // Player 2 wins

                // Add this - record the exhaustion in the combat log
                results = appendCombatAction(
                    results,
                    uint8(CombatResultType.EXHAUSTED), // P1 result (exhausted)
                    0, // No damage
                    0, // No stamina cost
                    uint8(CombatResultType.HIT), // P2 result (HIT with 0 damage)
                    0, // No damage
                    0, // No stamina cost
                    true // P1 is "attacking" (for log purposes)
                );

                break;
            } else if (!canP2Attack && canP1Attack && state.p2ActionPoints >= ATTACK_ACTION_COST) {
                state.condition = WinCondition.EXHAUSTION;
                state.player1Won = true; // Player 1 wins
                break;
            }

            // After the other exhaustion checks add:
            if (
                !canP1Attack && !canP2Attack && state.p1ActionPoints >= ATTACK_ACTION_COST
                    && state.p2ActionPoints >= ATTACK_ACTION_COST
            ) {
                // Both players are exhausted - decide winner by health percentage
                uint256 p1HealthWide = uint256(state.p1Health);
                uint256 p2HealthWide = uint256(state.p2Health);
                uint256 p1MaxHealthWide = uint256(p1Calculated.stats.maxHealth);
                uint256 p2MaxHealthWide = uint256(p2Calculated.stats.maxHealth);

                // Calculate percentages using wider type
                uint256 p1HealthPct = (p1HealthWide * 100) / p1MaxHealthWide;
                uint256 p2HealthPct = (p2HealthWide * 100) / p2MaxHealthWide;

                // Then safely convert to uint32 for storage
                uint32 p1HealthPctFinal = p1HealthPct > type(uint32).max ? type(uint32).max : uint32(p1HealthPct);
                uint32 p2HealthPctFinal = p2HealthPct > type(uint32).max ? type(uint32).max : uint32(p2HealthPct);

                state.condition = WinCondition.EXHAUSTION;
                // Player with higher health percentage wins (P1 wins ties)
                state.player1Won = p1HealthPctFinal >= p2HealthPctFinal;
                break;
            }

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
        // Prevent division by zero
        uint32 weight = stats.armor.weight > 0 ? stats.armor.weight : 1;

        // Use uint256 for intermediate calculation to avoid overflow
        uint256 equipmentInit = (uint256(stats.weapon.attackSpeed) * 100) / weight;
        uint256 initiativeContribution = (uint256(stats.stats.initiative) * 10);

        // Combine with safe arithmetic
        uint256 totalInit = ((equipmentInit * 90) + initiativeContribution) / 100;

        // Cap at uint32 max value before returning
        return totalInit > type(uint32).max ? type(uint32).max : uint32(totalInit);
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
        uint32 withMin = adjustedHitChance < 70 ? 70 : adjustedHitChance;
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
            // Safe calculation with overflow check
            uint32 critDamage = (uint32(baseDamage) * uint32(attacker.stats.critMultiplier)) / 100;
            damage = critDamage > type(uint16).max ? type(uint16).max : uint16(critDamage);
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

        // Apply damage modifier as a percentage
        uint64 modifiedDamage = (baseDamage * uint64(attacker.stats.damageModifier)) / 100;

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

        // Hit check
        uint8 finalHitChance = calculateHitChance(attacker);
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 hitRoll = uint8(seed.uniform(100));

        if (hitRoll >= finalHitChance) {
            return (uint8(CombatResultType.ATTACK), 0, uint8(attackCost), uint8(CombatResultType.MISS), 0, 0, seed);
        }

        // Process defense first
        seed = uint256(keccak256(abi.encodePacked(seed)));
        (defenseResult, defenseDamage, defenseStaminaCost, seed) =
            processDefense(defender, attacker, defenderStamina, seed);

        // Only calculate damage if defense failed
        if (defenseResult == uint8(CombatResultType.HIT)) {
            // Calculate base damage
            uint16 baseDamage;
            (baseDamage, seed) = calculateDamage(attacker, seed);

            // Check for crit
            seed = uint256(keccak256(abi.encodePacked(seed)));
            uint8 critRoll = uint8(seed.uniform(100));
            bool isCritical = critRoll < attacker.stats.critChance;

            if (isCritical) {
                uint32 critDamage = (uint32(baseDamage) * uint32(attacker.stats.critMultiplier)) / 100;
                baseDamage = critDamage > type(uint16).max ? type(uint16).max : uint16(critDamage);
                attackResult = uint8(CombatResultType.CRIT);
            } else {
                attackResult = uint8(CombatResultType.ATTACK);
            }

            // Apply armor reduction
            attackDamage =
                applyDefensiveStats(baseDamage, defender.armor, attacker.weapon.damageType, attacker.weapon.attackSpeed);
        } else {
            attackResult = uint8(CombatResultType.ATTACK);
            attackDamage = 0;
        }

        attackStaminaCost = attackCost > 255 ? 255 : uint8(attackCost);
        return (attackResult, attackDamage, attackStaminaCost, defenseResult, defenseDamage, defenseStaminaCost, seed);
    }

    function processDefense(
        CalculatedCombatStats memory defender,
        CalculatedCombatStats memory attacker,
        uint256 defenderStamina,
        uint256 seed
    ) private pure returns (uint8 result, uint16 damage, uint8 staminaCost, uint256 nextSeed) {
        // Check if defender has a shield
        if (defender.weapon.shieldType != ShieldType.NONE) {
            // Block check
            uint16 finalBlockChance = calculateFinalBlockChance(defender, attacker);
            seed = uint256(keccak256(abi.encodePacked(seed)));
            uint8 blockRoll = uint8(seed.uniform(100));

            if (blockRoll < finalBlockChance) {
                uint256 blockStaminaCost = calculateStaminaCost(ActionType.BLOCK, defender);
                if (defenderStamina >= blockStaminaCost) {
                    // Add block breakthrough chance for slow weapons
                    if (attacker.weapon.attackSpeed <= 55) {
                        seed = uint256(keccak256(abi.encodePacked(seed)));
                        uint8 breakthroughRoll = uint8(seed.uniform(100));

                        uint16 breakthroughChance = 10 + ((55 - attacker.weapon.attackSpeed) * 5 / 3);
                        // Then if needed, cap it before converting
                        breakthroughChance = breakthroughChance > 35 ? 35 : breakthroughChance;
                        uint8 finalChance = uint8(breakthroughChance);

                        if (breakthroughRoll < finalChance) {
                            return (uint8(CombatResultType.HIT), 0, 0, seed);
                        }
                    }

                    // Regular block success logic continues...
                    // Check for counter
                    seed = uint256(keccak256(abi.encodePacked(seed)));
                    uint8 counterRoll = uint8(seed.uniform(100));

                    (, uint16 shieldCounterBonus,,) = getShieldStats(defender.weapon.shieldType);
                    uint32 effectiveCounterChance = uint32(defender.stats.counterChance);
                    effectiveCounterChance = uint32((effectiveCounterChance * uint32(shieldCounterBonus)) / 100);

                    if (counterRoll < effectiveCounterChance) {
                        seed = uint256(keccak256(abi.encodePacked(seed)));
                        return processCounterAttack(defender, seed, CounterType.COUNTER);
                    }
                    return (uint8(CombatResultType.BLOCK), 0, uint8(blockStaminaCost), seed);
                }
            }
        }

        // Parry check
        uint16 finalParryChance = calculateFinalParryChance(defender, attacker);
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 parryRoll = uint8(seed.uniform(100));

        if (parryRoll < finalParryChance) {
            uint256 parryStaminaCost = calculateStaminaCost(ActionType.PARRY, defender);
            if (defenderStamina >= parryStaminaCost) {
                // Add parry breakthrough chance for slow weapons
                if (attacker.weapon.attackSpeed <= 55) {
                    seed = uint256(keccak256(abi.encodePacked(seed)));
                    uint8 breakthroughRoll = uint8(seed.uniform(100));

                    uint16 breakthroughChance = 10 + ((55 - attacker.weapon.attackSpeed) * 5 / 3);
                    // Cap it at 45%
                    breakthroughChance = breakthroughChance > 35 ? 35 : breakthroughChance;
                    uint8 finalChance = uint8(breakthroughChance);

                    if (breakthroughRoll < finalChance) {
                        return (uint8(CombatResultType.HIT), 0, 0, seed);
                    }
                }

                // Continue with existing riposte check...
                seed = uint256(keccak256(abi.encodePacked(seed)));
                uint8 riposteRoll = uint8(seed.uniform(100));

                uint32 effectiveRiposteChance32 =
                    (uint32(defender.stats.riposteChance) * uint32(defender.weapon.riposteChance)) / 100;
                uint16 effectiveRiposteChance =
                    effectiveRiposteChance32 > type(uint16).max ? type(uint16).max : uint16(effectiveRiposteChance32);

                if (riposteRoll < effectiveRiposteChance) {
                    seed = uint256(keccak256(abi.encodePacked(seed)));
                    return processCounterAttack(defender, seed, CounterType.PARRY);
                }
                return (uint8(CombatResultType.PARRY), 0, uint8(parryStaminaCost), seed);
            }
        }

        // Dodge check
        uint16 finalDodgeChance = calculateFinalDodgeChance(defender, attacker);
        seed = uint256(keccak256(abi.encodePacked(seed)));
        uint8 dodgeRoll = uint8(seed.uniform(100));

        if (dodgeRoll < finalDodgeChance) {
            uint256 dodgeStaminaCost = calculateStaminaCost(ActionType.DODGE, defender);
            if (defenderStamina >= dodgeStaminaCost) {
                return (uint8(CombatResultType.DODGE), 0, uint8(dodgeStaminaCost), seed);
            }
        }

        // If all defensive actions fail, return HIT result
        return (uint8(CombatResultType.HIT), 0, 0, seed);
    }

    function calculateFinalBlockChance(CalculatedCombatStats memory defender, CalculatedCombatStats memory attacker)
        internal
        pure
        returns (uint16)
    {
        uint32 baseBlockChance = uint32(defender.stats.blockChance);
        uint32 neutralSpeed = 70; // Neutral point - neither bonus nor penalty

        if (attacker.weapon.attackSpeed < neutralSpeed) {
            // Slow weapon - harder to block (penalty)
            // Scale from 0% at speed 60 to -25% at speed 40 or below
            uint32 slownessFactor = neutralSpeed - uint32(attacker.weapon.attackSpeed);
            slownessFactor = slownessFactor > 20 ? 20 : slownessFactor; // Cap at 20 points difference
            uint32 blockPenalty = slownessFactor * 42 / 100;
            baseBlockChance = baseBlockChance > blockPenalty ? baseBlockChance - blockPenalty : 0;
        } else if (attacker.weapon.attackSpeed > neutralSpeed) {
            // Fast weapon - easier to block (bonus)
            // Scale from 0% at speed 60 to +25% at speed 130 or above
            uint32 speedFactor = uint32(attacker.weapon.attackSpeed) - neutralSpeed;
            speedFactor = speedFactor > 70 ? 70 : speedFactor; // Cap at 70 points difference
            uint32 blockBonus = speedFactor * 12 / 100;
            baseBlockChance = baseBlockChance + blockBonus;
        }

        (uint16 shieldBlockBonus,,,) = getShieldStats(defender.weapon.shieldType);
        baseBlockChance = uint32(baseBlockChance * uint32(shieldBlockBonus)) / 100;
        uint16 adjustedBlockChance = baseBlockChance > 80 ? 80 : uint16(baseBlockChance);
        return adjustedBlockChance;
    }

    function calculateFinalParryChance(CalculatedCombatStats memory defender, CalculatedCombatStats memory attacker)
        internal
        pure
        returns (uint16)
    {
        // Calculate base parry chance
        uint32 baseParryChance = (uint32(defender.stats.parryChance) * uint32(defender.weapon.parryChance)) / 100;

        uint16 adjustedParryChance = baseParryChance > 80 ? 80 : uint16(baseParryChance);
        return adjustedParryChance;
    }

    function calculateFinalDodgeChance(CalculatedCombatStats memory defender, CalculatedCombatStats memory attacker)
        internal
        pure
        returns (uint16)
    {
        // Heavy weapons cannot dodge at all
        if (defender.weapon.attackSpeed <= 55) {
            return 0;
        }

        uint32 baseDodgeChance = uint32(defender.stats.dodgeChance);
        // Add weapon dodge bonus
        baseDodgeChance += uint32(defender.weapon.dodgeBonus);

        // Calculate speed bonus - scale based on weapon speed
        uint32 speedDodgeBonus = 0;
        if (attacker.weapon.attackSpeed <= 70) {
            // The slower the weapon, the easier to dodge
            uint32 slownessFactor = 70 - uint32(attacker.weapon.attackSpeed);
            // More aggressive scaling: up to 25% bonus for slowest weapons
            speedDodgeBonus = slownessFactor * 125 / 100;
        }

        // Add speed bonus to base dodge
        uint32 totalDodgeBeforeArmor = baseDodgeChance + speedDodgeBonus;

        // Apply armor penalties to the total dodge (base + speed bonus)
        uint32 adjustedDodgeChance;
        if (defender.armor.weight <= 10) {
            // Cloth
            adjustedDodgeChance = totalDodgeBeforeArmor; // No penalty
        } else if (defender.armor.weight <= 30) {
            // Leather
            adjustedDodgeChance = (totalDodgeBeforeArmor * 80) / 100;
        } else if (defender.armor.weight <= 70) {
            // Chain
            adjustedDodgeChance = (totalDodgeBeforeArmor * 60) / 100;
        } else {
            // Plate
            adjustedDodgeChance = (totalDodgeBeforeArmor * 20) / 100; // Minimal dodge
        }

        // Apply shield effect
        if (defender.weapon.shieldType != ShieldType.NONE) {
            (,, uint16 dodgeModifier,) = getShieldStats(defender.weapon.shieldType);
            adjustedDodgeChance = (adjustedDodgeChance * uint32(dodgeModifier)) / 100;
        }

        // Cap the dodge chance
        uint32 cappedDodge = adjustedDodgeChance > 70 ? 70 : adjustedDodgeChance;
        return uint16(cappedDodge);
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

        ActionType actionType = counterType == CounterType.PARRY ? ActionType.RIPOSTE : ActionType.COUNTER;

        if (isCritical) {
            // Use uint32 for intermediate calculations
            uint32 totalMultiplier =
                (uint32(defender.stats.critMultiplier) * uint32(defender.weapon.critMultiplier)) / 100;

            // Calculate damage with overflow protection
            uint32 critDamage = (uint32(counterDamage) * totalMultiplier) / 100;
            counterDamage = critDamage > type(uint16).max ? type(uint16).max : uint16(critDamage);

            uint256 critModifiedStaminaCost = calculateStaminaCost(actionType, defender);
            uint8 safeCost = critModifiedStaminaCost > 255 ? 255 : uint8(critModifiedStaminaCost);

            seed = uint256(keccak256(abi.encodePacked(seed)));
            return (
                uint8(counterType == CounterType.PARRY ? CombatResultType.RIPOSTE_CRIT : CombatResultType.COUNTER_CRIT),
                counterDamage,
                safeCost,
                seed
            );
        }

        uint256 normalModifiedStaminaCost = calculateStaminaCost(actionType, defender);
        uint8 safeNormalCost = normalModifiedStaminaCost > 255 ? 255 : uint8(normalModifiedStaminaCost);

        seed = uint256(keccak256(abi.encodePacked(seed)));
        return (
            uint8(counterType == CounterType.PARRY ? CombatResultType.RIPOSTE : CombatResultType.COUNTER),
            counterDamage,
            safeNormalCost,
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

    function applyDefensiveStats(
        uint16 incomingDamage,
        ArmorStats memory armor,
        DamageType damageType,
        uint16 attackSpeed
    ) private pure returns (uint16) {
        // Get resistance percentage (0-100)
        uint16 resistance = getResistanceForDamageType(armor, damageType);

        // First apply flat reduction
        uint32 afterFlat = incomingDamage > armor.defense ? uint32(incomingDamage) - armor.defense : 0;

        // Calculate armor penetration for TRUE heavy weapons vs heavy armor
        uint32 armorPen = 0;
        if (attackSpeed <= 55 && armor.weight >= 50) {
            // Only slowest weapons (speed 50 or less) vs heavy armors
            // More aggressive penetration for true heavy weapons
            armorPen = (100 - attackSpeed) * 1 / 2; // Reduced from 3/4 to 1/2
        }

        // Then apply percentage reduction with armor penetration
        uint32 reductionPercent = resistance > 90 ? 90 : resistance;
        reductionPercent = armorPen >= reductionPercent ? 0 : reductionPercent - armorPen;
        uint32 finalDamage = (afterFlat * (100 - reductionPercent)) / 100;

        return finalDamage > type(uint16).max ? type(uint16).max : uint16(finalDamage);
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

    // Improved to prevent overflow when applying high multipliers (180%)
    function applyStanceModifiers(CalculatedStats memory stats, StanceMultiplier memory stance)
        private
        pure
        returns (CalculatedStats memory)
    {
        // Use uint32 for all intermediate calculations to prevent overflow
        uint32 hitChance = (uint32(stats.hitChance) * uint32(stance.hitChance)) / 100;
        uint32 dodgeChance = (uint32(stats.dodgeChance) * uint32(stance.dodgeChance)) / 100;
        uint32 blockChance = (uint32(stats.blockChance) * uint32(stance.blockChance)) / 100;
        uint32 parryChance = (uint32(stats.parryChance) * uint32(stance.parryChance)) / 100;
        uint32 critChance = (uint32(stats.critChance) * uint32(stance.critChance)) / 100;
        uint32 critMultiplier = (uint32(stats.critMultiplier) * uint32(stance.critMultiplier)) / 100;
        uint32 counterChance = (uint32(stats.counterChance) * uint32(stance.counterChance)) / 100;
        uint32 riposteChance = (uint32(stats.riposteChance) * uint32(stance.riposteChance)) / 100;
        uint32 damageModifier = (uint32(stats.damageModifier) * uint32(stance.damageModifier)) / 100;

        // Safely cap all values to uint16 max before returning
        return CalculatedStats({
            maxHealth: stats.maxHealth,
            maxEndurance: stats.maxEndurance,
            initiative: stats.initiative,
            hitChance: hitChance > type(uint16).max ? type(uint16).max : uint16(hitChance),
            dodgeChance: dodgeChance > type(uint16).max ? type(uint16).max : uint16(dodgeChance),
            blockChance: blockChance > type(uint16).max ? type(uint16).max : uint16(blockChance),
            parryChance: parryChance > type(uint16).max ? type(uint16).max : uint16(parryChance),
            critChance: critChance > type(uint16).max ? type(uint16).max : uint16(critChance),
            critMultiplier: critMultiplier > type(uint16).max ? type(uint16).max : uint16(critMultiplier),
            counterChance: counterChance > type(uint16).max ? type(uint16).max : uint16(counterChance),
            riposteChance: riposteChance > type(uint16).max ? type(uint16).max : uint16(riposteChance),
            damageModifier: damageModifier > type(uint16).max ? type(uint16).max : uint16(damageModifier),
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

        // Check if this hit would reduce health to zero
        bool wouldKill = damage >= currentHealth;

        // Apply damage normally
        currentHealth = applyDamage(currentHealth, damage);

        if (isPlayer1Attacker) {
            state.p2Health = currentHealth;
        } else {
            state.p1Health = currentHealth;
        }

        // Only check for lethal damage if health is 0 and lethalityFactor is enabled
        if (currentHealth == 0 && wouldKill && lethalityFactor > 0) {
            bool survived = !isLethalDamage(
                damage,
                defenderStats.stats.maxHealth,
                defenderStats.stats,
                attackerStats.weapon,
                defenderStats.stanceMultipliers,
                seed,
                lethalityFactor
            );

            // If they survived the lethal blow, give them 1 health
            if (survived) {
                if (isPlayer1Attacker) {
                    state.p2Health = 1;
                } else {
                    state.p1Health = 1;
                }
            } else {
                // They died - update win condition
                state.player1Won = isPlayer1Attacker;
                state.condition = WinCondition.DEATH;
            }
        } else if (currentHealth == 0) {
            // Normal KO by reducing health to 0
            state.player1Won = isPlayer1Attacker;
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

        // Use uint256 for all intermediate calculations
        uint256 staminaCost = baseCost;

        // Apply stance modifier
        staminaCost = (staminaCost * uint256(stats.stanceMultipliers.staminaCostModifier)) / 100;

        // Apply weapon modifier only to weapon-related actions
        if (
            actionType == ActionType.ATTACK || actionType == ActionType.PARRY || actionType == ActionType.COUNTER
                || actionType == ActionType.RIPOSTE
        ) {
            staminaCost = (staminaCost * uint256(stats.weapon.staminaMultiplier)) / 100;
        }

        // Apply shield modifier only for block action
        if (actionType == ActionType.BLOCK && stats.weapon.shieldType != ShieldType.NONE) {
            (,,, uint16 shieldStaminaModifier) = getShieldStats(stats.weapon.shieldType);
            staminaCost = (staminaCost * uint256(shieldStaminaModifier)) / 100;
        }

        // Calculate armor impact using uint256
        uint256 armorImpact;
        if (actionType == ActionType.DODGE) {
            armorImpact = 100 + (uint256(stats.armor.weight) * 3 / 2);
        } else {
            armorImpact = 100 + (uint256(stats.armor.weight) / 10);
        }

        // Apply armor impact
        staminaCost = (staminaCost * armorImpact) / 100;

        return staminaCost;
    }

    // =============================================
    // WEAPON STATS
    // =============================================

    function ARMING_SWORD_KITE() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 54,
            maxDamage: 69,
            attackSpeed: 75,
            parryChance: 140,
            riposteChance: 100,
            critMultiplier: 175,
            staminaMultiplier: 100,
            survivalFactor: 100,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.KITE_SHIELD,
            dodgeBonus: 0
        });
    }

    function MACE_TOWER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 40,
            maxDamage: 55,
            attackSpeed: 65,
            parryChance: 120,
            riposteChance: 70,
            critMultiplier: 130,
            staminaMultiplier: 120,
            survivalFactor: 120,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.TOWER_SHIELD,
            dodgeBonus: 0
        });
    }

    function RAPIER_BUCKLER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 45,
            maxDamage: 65,
            attackSpeed: 85,
            parryChance: 280,
            riposteChance: 200,
            critMultiplier: 160,
            staminaMultiplier: 90,
            survivalFactor: 120,
            damageType: DamageType.Piercing,
            shieldType: ShieldType.BUCKLER,
            dodgeBonus: 20
        });
    }

    function GREATSWORD() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 95,
            maxDamage: 125,
            attackSpeed: 55,
            parryChance: 100,
            riposteChance: 50,
            critMultiplier: 240,
            staminaMultiplier: 230,
            survivalFactor: 85,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.NONE,
            dodgeBonus: 0
        });
    }

    function BATTLEAXE() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 106,
            maxDamage: 159,
            attackSpeed: 40,
            parryChance: 70,
            riposteChance: 40,
            critMultiplier: 250,
            staminaMultiplier: 300,
            survivalFactor: 80,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.NONE,
            dodgeBonus: 0
        });
    }

    function QUARTERSTAFF() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 70,
            maxDamage: 95,
            attackSpeed: 75,
            parryChance: 200,
            riposteChance: 100,
            critMultiplier: 180,
            staminaMultiplier: 140,
            survivalFactor: 100,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.NONE,
            dodgeBonus: 20
        });
    }

    function SPEAR() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 74,
            maxDamage: 94,
            attackSpeed: 75,
            parryChance: 130,
            riposteChance: 140,
            critMultiplier: 180,
            staminaMultiplier: 170,
            survivalFactor: 90,
            damageType: DamageType.Piercing,
            shieldType: ShieldType.NONE,
            dodgeBonus: 10
        });
    }

    function SHORTSWORD_BUCKLER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 39,
            maxDamage: 52,
            attackSpeed: 90,
            parryChance: 220,
            riposteChance: 200,
            critMultiplier: 160,
            staminaMultiplier: 90,
            survivalFactor: 110,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.BUCKLER,
            dodgeBonus: 20
        });
    }

    function SHORTSWORD_TOWER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 39,
            maxDamage: 50,
            attackSpeed: 85,
            parryChance: 1200,
            riposteChance: 80,
            critMultiplier: 100,
            staminaMultiplier: 100,
            survivalFactor: 125,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.TOWER_SHIELD,
            dodgeBonus: 0
        });
    }

    function SCIMITAR_BUCKLER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 50,
            maxDamage: 70,
            attackSpeed: 85,
            parryChance: 180,
            riposteChance: 200,
            critMultiplier: 180,
            staminaMultiplier: 95,
            survivalFactor: 110,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.BUCKLER,
            dodgeBonus: 20
        });
    }

    function AXE_KITE() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 50,
            maxDamage: 67,
            attackSpeed: 70,
            parryChance: 120,
            riposteChance: 85,
            critMultiplier: 200,
            staminaMultiplier: 115,
            survivalFactor: 105,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.KITE_SHIELD,
            dodgeBonus: 0
        });
    }

    function AXE_TOWER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 48,
            maxDamage: 65,
            attackSpeed: 65,
            parryChance: 120,
            riposteChance: 65,
            critMultiplier: 230,
            staminaMultiplier: 135,
            survivalFactor: 120,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.TOWER_SHIELD,
            dodgeBonus: 0
        });
    }

    function FLAIL_BUCKLER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 58,
            maxDamage: 84,
            attackSpeed: 70,
            parryChance: 180,
            riposteChance: 100,
            critMultiplier: 225,
            staminaMultiplier: 140,
            survivalFactor: 105,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.BUCKLER,
            dodgeBonus: 0
        });
    }

    function MACE_KITE() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 49,
            maxDamage: 62,
            attackSpeed: 65,
            parryChance: 160,
            riposteChance: 100,
            critMultiplier: 200,
            staminaMultiplier: 105,
            survivalFactor: 110,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.KITE_SHIELD,
            dodgeBonus: 0
        });
    }

    function CLUB_TOWER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 52,
            maxDamage: 64,
            attackSpeed: 70,
            parryChance: 75,
            riposteChance: 65,
            critMultiplier: 210,
            staminaMultiplier: 90,
            survivalFactor: 125,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.TOWER_SHIELD,
            dodgeBonus: 0
        });
    }

    // Dual-wield weapons
    function DUAL_DAGGERS() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 40,
            maxDamage: 57,
            attackSpeed: 120,
            parryChance: 70,
            riposteChance: 70,
            critMultiplier: 180,
            staminaMultiplier: 75,
            survivalFactor: 95,
            damageType: DamageType.Piercing,
            shieldType: ShieldType.NONE,
            dodgeBonus: 20
        });
    }

    function RAPIER_DAGGER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 40,
            maxDamage: 76,
            attackSpeed: 110,
            parryChance: 140,
            riposteChance: 300,
            critMultiplier: 190,
            staminaMultiplier: 100,
            survivalFactor: 110,
            damageType: DamageType.Piercing,
            shieldType: ShieldType.NONE,
            dodgeBonus: 20
        });
    }

    function DUAL_SCIMITARS() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 60,
            maxDamage: 86,
            attackSpeed: 95,
            parryChance: 80,
            riposteChance: 80,
            critMultiplier: 200,
            staminaMultiplier: 200,
            survivalFactor: 90,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.NONE,
            dodgeBonus: 5
        });
    }

    function DUAL_CLUBS() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 50,
            maxDamage: 70,
            attackSpeed: 80,
            parryChance: 50,
            riposteChance: 50,
            critMultiplier: 180,
            staminaMultiplier: 130,
            survivalFactor: 95,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.NONE,
            dodgeBonus: 0
        });
    }

    // Mixed damage type weapons
    function ARMING_SWORD_SHORTSWORD() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 63,
            maxDamage: 80,
            attackSpeed: 85,
            parryChance: 130,
            riposteChance: 150,
            critMultiplier: 180,
            staminaMultiplier: 130,
            survivalFactor: 90,
            damageType: DamageType.Slashing,
            shieldType: ShieldType.NONE,
            dodgeBonus: 0
        });
    }

    function SCIMITAR_DAGGER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 60,
            maxDamage: 80,
            attackSpeed: 105,
            parryChance: 140,
            riposteChance: 300,
            critMultiplier: 220,
            staminaMultiplier: 90,
            survivalFactor: 100,
            damageType: DamageType.Hybrid_Slash_Pierce,
            shieldType: ShieldType.NONE,
            dodgeBonus: 0
        });
    }

    function ARMING_SWORD_CLUB() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 68,
            maxDamage: 88,
            attackSpeed: 75,
            parryChance: 90,
            riposteChance: 65,
            critMultiplier: 250,
            staminaMultiplier: 110,
            survivalFactor: 100,
            damageType: DamageType.Hybrid_Slash_Blunt,
            shieldType: ShieldType.NONE,
            dodgeBonus: 0
        });
    }

    function AXE_MACE() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 58,
            maxDamage: 85,
            attackSpeed: 65,
            parryChance: 75,
            riposteChance: 70,
            critMultiplier: 300,
            staminaMultiplier: 115,
            survivalFactor: 90,
            damageType: DamageType.Hybrid_Slash_Blunt,
            shieldType: ShieldType.NONE,
            dodgeBonus: 0
        });
    }

    function FLAIL_DAGGER() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 62,
            maxDamage: 90,
            attackSpeed: 70,
            parryChance: 200,
            riposteChance: 140,
            critMultiplier: 200,
            staminaMultiplier: 125,
            survivalFactor: 95,
            damageType: DamageType.Hybrid_Pierce_Blunt,
            shieldType: ShieldType.NONE,
            dodgeBonus: 0
        });
    }

    function MACE_SHORTSWORD() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 55,
            maxDamage: 75,
            attackSpeed: 70,
            parryChance: 160,
            riposteChance: 85,
            critMultiplier: 225,
            staminaMultiplier: 110,
            survivalFactor: 105,
            damageType: DamageType.Hybrid_Slash_Blunt,
            shieldType: ShieldType.NONE,
            dodgeBonus: 0
        });
    }

    // Additional two-handed weapons
    function MAUL() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 115,
            maxDamage: 166,
            attackSpeed: 40,
            parryChance: 70,
            riposteChance: 40,
            critMultiplier: 300,
            staminaMultiplier: 320,
            survivalFactor: 85,
            damageType: DamageType.Blunt,
            shieldType: ShieldType.NONE,
            dodgeBonus: 0
        });
    }

    function TRIDENT() public pure returns (WeaponStats memory) {
        return WeaponStats({
            minDamage: 82,
            maxDamage: 118,
            attackSpeed: 55,
            parryChance: 100,
            riposteChance: 100,
            critMultiplier: 210,
            staminaMultiplier: 240,
            survivalFactor: 90,
            damageType: DamageType.Piercing,
            shieldType: ShieldType.NONE,
            dodgeBonus: 0
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
        return ArmorStats({defense: 1, weight: 5, slashResist: 1, pierceResist: 1, bluntResist: 5});
    }

    function LEATHER() public pure returns (ArmorStats memory) {
        return ArmorStats({defense: 4, weight: 15, slashResist: 10, pierceResist: 10, bluntResist: 15});
    }

    function CHAIN() public pure returns (ArmorStats memory) {
        return ArmorStats({defense: 9, weight: 50, slashResist: 30, pierceResist: 15, bluntResist: 30});
    }

    function PLATE() public pure returns (ArmorStats memory) {
        return ArmorStats({defense: 16, weight: 100, slashResist: 45, pierceResist: 45, bluntResist: 15});
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
            damageModifier: 80,
            hitChance: 80,
            critChance: 70,
            critMultiplier: 90,
            blockChance: 140,
            parryChance: 140,
            dodgeChance: 140,
            counterChance: 120,
            riposteChance: 120,
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
            damageModifier: 120,
            hitChance: 130,
            critChance: 110,
            critMultiplier: 130,
            blockChance: 60,
            parryChance: 60,
            dodgeChance: 60,
            counterChance: 85,
            riposteChance: 85,
            staminaCostModifier: 125,
            survivalFactor: 70
        });
    }

    function getStanceMultiplier(uint8 stance) public pure returns (StanceMultiplier memory) {
        if (stance == STANCE_DEFENSIVE) return DEFENSIVE_STANCE();
        if (stance == STANCE_OFFENSIVE) return OFFENSIVE_STANCE();
        return BALANCED_STANCE();
    }

    // Fix 6: Fix isLethalDamage function to avoid division by zero and handle overflow
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

        // Use uint256 for all calculations to prevent any overflow
        uint256 damagePercent = (uint256(attackerDamage) * 100) / uint256(defenderMaxHealth);

        if (damagePercent <= DAMAGE_THRESHOLD_PERCENT) {
            return false;
        }

        uint256 survivalChance = uint256(defenderStats.baseSurvivalRate);

        uint256 excessDamage = damagePercent > DAMAGE_THRESHOLD_PERCENT ? damagePercent - DAMAGE_THRESHOLD_PERCENT : 0;
        excessDamage = excessDamage > MAX_DAMAGE_OVERAGE ? MAX_DAMAGE_OVERAGE : excessDamage;
        survivalChance = survivalChance > excessDamage ? survivalChance - excessDamage : 0;

        // Safe division - prevent division by zero
        if (lethalityFactor > 0) {
            survivalChance = (survivalChance * 100) / lethalityFactor;
        }

        // Apply weapon survival factor safely
        survivalChance = (survivalChance * uint256(weapon.survivalFactor)) / 100;

        // Cap between min and max
        if (survivalChance < MINIMUM_SURVIVAL_CHANCE) {
            survivalChance = MINIMUM_SURVIVAL_CHANCE;
        } else if (survivalChance > BASE_SURVIVAL_CHANCE) {
            survivalChance = BASE_SURVIVAL_CHANCE;
        }

        // Generate random number and compare
        seed = uint256(keccak256(abi.encodePacked(seed)));
        return uint8(seed.uniform(100)) >= survivalChance;
    }

    function getShieldStats(ShieldType shieldType)
        internal
        pure
        returns (uint16 blockChance, uint16 counterChance, uint16 dodgeModifier, uint16 staminaModifier)
    {
        if (shieldType == ShieldType.BUCKLER) {
            return (80, 120, 120, 80);
        } else if (shieldType == ShieldType.KITE_SHIELD) {
            return (120, 100, 75, 120);
        } else if (shieldType == ShieldType.TOWER_SHIELD) {
            return (160, 50, 30, 160);
        }
        return (0, 0, 100, 100);
    }
}

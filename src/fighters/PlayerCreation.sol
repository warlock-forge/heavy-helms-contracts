// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import "../lib/UniformRandomNumber.sol";
import "../interfaces/fighters/IPlayer.sol";
import "../interfaces/fighters/registries/names/IPlayerNameRegistry.sol";
import "./Fighter.sol";

//==============================================================//
//                     PLAYER CREATION                          //
//==============================================================//
/// @title PlayerCreation
/// @notice Helper contract for generating player stats and names
/// @dev Pure computation functions extracted from Player contract to reduce size
contract PlayerCreation {
    using UniformRandomNumber for uint256;

    //==============================================================//
    //                       CONSTANTS                              //
    //==============================================================//
    /// @notice Minimum value for any player stat
    uint8 private constant MIN_STAT = 3;
    /// @notice Maximum value for any player stat
    uint8 private constant MAX_STAT = 21;
    /// @notice Total stat points that must be distributed across all attributes
    uint8 private constant TOTAL_STATS = 72;

    //==============================================================//
    //                   IMMUTABLE STORAGE                          //
    //==============================================================//
    /// @notice Player name registry for name generation
    IPlayerNameRegistry private immutable _nameRegistry;

    //==============================================================//
    //                      CONSTRUCTOR                             //
    //==============================================================//
    /// @notice Initialize the PlayerCreation contract
    /// @param nameRegistry The player name registry contract
    constructor(IPlayerNameRegistry nameRegistry) {
        _nameRegistry = nameRegistry;
    }

    //==============================================================//
    //                   EXTERNAL FUNCTIONS                         //
    //==============================================================//
    /// @notice Generates complete player data from random seed
    /// @param randomSeed Random seed for stat and name generation
    /// @param useNameSetB Whether to use name set B for first name generation
    /// @return stats Complete player stats struct
    function generatePlayerData(uint256 randomSeed, bool useNameSetB)
        external
        view
        returns (IPlayer.PlayerStats memory stats)
    {
        // Initialize base stats array with minimum values
        uint8[6] memory statArray = [3, 3, 3, 3, 3, 3];
        uint256 remainingPoints = 54; // 72 total - (6 * 3 minimum)

        // Distribute remaining points across stats
        uint256 order = uint256(keccak256(abi.encodePacked(randomSeed, "order")));

        unchecked {
            // Handle all 6 stats
            for (uint256 i; i < 6; ++i) {
                // Select random stat index and update order
                uint256 statIndex = order.uniform(6 - i);
                order = uint256(keccak256(abi.encodePacked(order)));

                // Calculate available points for this stat
                uint256 pointsNeededForRemaining = (5 - i) * 3; // Ensure minimum 3 points for each remaining stat
                uint256 availablePoints =
                    remainingPoints > pointsNeededForRemaining ? remainingPoints - pointsNeededForRemaining : 0;

                // Add extra entropy and make high points rarer
                uint256 chance = randomSeed.uniform(100);
                randomSeed = uint256(keccak256(abi.encodePacked(randomSeed, "chance")));

                uint256 pointsCap = chance < 50
                    ? 9 // 0-49: normal roll (3+9=12)
                    : chance < 80
                        ? 12 // 50-79: medium roll (3+12=15)
                        : chance < 95
                            ? 15 // 80-94: high roll (3+15=18)
                            : 18; // 95-99: max roll (3+18=21)

                // Add random points to selected stat using the cap
                uint256 pointsToAdd = randomSeed.uniform(_min(availablePoints, pointsCap) + 1);
                randomSeed = uint256(keccak256(abi.encodePacked(randomSeed)));

                // Update stat and remaining points
                statArray[statIndex] += uint8(pointsToAdd);
                remainingPoints -= pointsToAdd;

                // Swap with last unprocessed stat to avoid reselecting
                if (statIndex != 5 - i) {
                    uint8 temp = statArray[statIndex];
                    statArray[statIndex] = statArray[5 - i];
                    statArray[5 - i] = temp;
                }
            }
        }

        // Generate name indices based on player preference
        uint16 firstNameIndex;
        if (useNameSetB) {
            firstNameIndex = uint16(randomSeed.uniform(_nameRegistry.getNameSetBLength()));
        } else {
            firstNameIndex =
                uint16(randomSeed.uniform(_nameRegistry.getNameSetALength())) + _nameRegistry.getSetAStart();
        }

        uint16 surnameIndex = uint16(randomSeed.uniform(_nameRegistry.getSurnamesLength()));

        // Create stats struct
        stats = IPlayer.PlayerStats({
            attributes: Fighter.Attributes({
                strength: statArray[0],
                constitution: statArray[1],
                size: statArray[2],
                agility: statArray[3],
                stamina: statArray[4],
                luck: statArray[5]
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            name: IPlayer.PlayerName({firstNameIndex: firstNameIndex, surnameIndex: surnameIndex}),
            stance: 1, // Initialize to BALANCED stance
            level: 1, // Start at level 1
            currentXP: 0, // Start with 0 XP
            weaponSpecialization: 255, // No specialization
            armorSpecialization: 255 // No specialization
        });

        // Validate and fix if necessary
        if (!_validateStats(stats)) {
            stats = _fixStats(stats, randomSeed);
        }

        return stats;
    }

    //==============================================================//
    //                    PRIVATE FUNCTIONS                         //
    //==============================================================//
    /// @notice Returns the minimum of two numbers
    /// @param a First number to compare
    /// @param b Second number to compare
    /// @return The smaller of the two numbers
    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice Validates that player stats are within allowed ranges and total correctly
    /// @param player The player stats to validate
    /// @return True if stats are valid, false otherwise
    /// @dev Checks each stat is between MIN_STAT and MAX_STAT and total equals TOTAL_STATS
    function _validateStats(IPlayer.PlayerStats memory player) private pure returns (bool) {
        // Check stat bounds
        if (player.attributes.strength < MIN_STAT || player.attributes.strength > MAX_STAT) return false;
        if (player.attributes.constitution < MIN_STAT || player.attributes.constitution > MAX_STAT) return false;
        if (player.attributes.size < MIN_STAT || player.attributes.size > MAX_STAT) return false;
        if (player.attributes.agility < MIN_STAT || player.attributes.agility > MAX_STAT) return false;
        if (player.attributes.stamina < MIN_STAT || player.attributes.stamina > MAX_STAT) return false;
        if (player.attributes.luck < MIN_STAT || player.attributes.luck > MAX_STAT) return false;

        // Calculate total stat points
        uint256 total = uint256(player.attributes.strength) + uint256(player.attributes.constitution)
            + uint256(player.attributes.size) + uint256(player.attributes.agility) + uint256(player.attributes.stamina)
            + uint256(player.attributes.luck);

        // Total should be exactly 72 (6 stats * 3 minimum = 18, plus 54 points to distribute)
        return total == TOTAL_STATS;
    }

    /// @notice Adjusts invalid player stats to meet requirements
    /// @param player The player stats to fix
    /// @param seed Random seed for stat adjustment
    /// @return Fixed player stats that meet all requirements
    /// @dev Ensures stats are within bounds and total exactly TOTAL_STATS
    function _fixStats(IPlayer.PlayerStats memory player, uint256 seed)
        private
        pure
        returns (IPlayer.PlayerStats memory)
    {
        uint16 total = uint16(player.attributes.strength) + uint16(player.attributes.constitution)
            + uint16(player.attributes.size) + uint16(player.attributes.agility) + uint16(player.attributes.stamina)
            + uint16(player.attributes.luck);

        // First ensure all stats are within 3-21 range
        uint8[6] memory stats = [
            player.attributes.strength,
            player.attributes.constitution,
            player.attributes.size,
            player.attributes.agility,
            player.attributes.stamina,
            player.attributes.luck
        ];

        for (uint256 i = 0; i < 6; i++) {
            if (stats[i] < 3) {
                total += (3 - stats[i]);
                stats[i] = 3;
            } else if (stats[i] > 21) {
                total -= (stats[i] - 21);
                stats[i] = 21;
            }
        }

        // Now adjust total to 72 if needed
        while (total != 72) {
            seed = uint256(keccak256(abi.encodePacked(seed)));

            if (total < 72) {
                uint256 statIndex = seed.uniform(6);
                if (stats[statIndex] < 21) {
                    stats[statIndex] += 1;
                    total += 1;
                }
            } else {
                seed = uint256(keccak256(abi.encodePacked(seed)));
                uint256 statIndex = seed.uniform(6);
                if (stats[statIndex] > 3) {
                    stats[statIndex] -= 1;
                    total -= 1;
                }
            }
        }

        return IPlayer.PlayerStats({
            attributes: Fighter.Attributes({
                strength: stats[0],
                constitution: stats[1],
                size: stats[2],
                agility: stats[3],
                stamina: stats[4],
                luck: stats[5]
            }),
            skin: Fighter.SkinInfo({skinIndex: 0, skinTokenId: 1}),
            name: IPlayer.PlayerName({firstNameIndex: player.name.firstNameIndex, surnameIndex: player.name.surnameIndex}),
            stance: 1, // Initialize to BALANCED stance
            level: player.level, // Preserve level
            currentXP: player.currentXP, // Preserve XP
            weaponSpecialization: player.weaponSpecialization, // Preserve specialization
            armorSpecialization: player.armorSpecialization // Preserve specialization
        });
    }
}

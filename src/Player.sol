// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/src/auth/Owned.sol";
import "./lib/UniformRandomNumber.sol";
import "./interfaces/IPlayer.sol";
import "./PlayerSkinRegistry.sol";
import "solmate/src/tokens/ERC721.sol";

error PlayerDoesNotExist(uint256 playerId);
error NotSkinOwner();

contract Player is IPlayer, Owned {
    using UniformRandomNumber for uint256;

    // Configuration
    uint256 public maxPlayersPerAddress;

    // Player state tracking
    mapping(uint256 => IPlayer.PlayerStats) private _players;
    mapping(uint256 => address) private _playerOwners;
    mapping(uint256 => bool) private _retiredPlayers; // More gas efficient than deletion

    // Player count tracking per address
    mapping(address => uint256) private _addressPlayerCount;
    mapping(address => uint256[]) private _addressToPlayerIds;

    // Reference to the PlayerSkinRegistry contract
    PlayerSkinRegistry public skinRegistry;

    // Events
    event PlayerRetired(uint256 indexed playerId);
    event MaxPlayersUpdated(uint256 newMax);

    // Constants
    uint8 private constant MIN_STAT = 3;
    uint8 private constant MAX_STAT = 21;
    uint16 private constant TOTAL_STATS = 72;

    constructor(address skinRegistryAddress) Owned(msg.sender) {
        maxPlayersPerAddress = 5; // Default max players per address
        skinRegistry = PlayerSkinRegistry(payable(skinRegistryAddress));
    }

    // Make sure this matches the interface exactly
    function createPlayer() external returns (uint256 playerId, IPlayer.PlayerStats memory stats) {
        // Generate randomSeed and playerId
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));
        playerId = uint256(keccak256(abi.encodePacked("PLAYER_ID", randomSeed, msg.sender)));

        // Initialize base stats array with minimum values
        uint8[6] memory statArray = [3, 3, 3, 3, 3, 3];
        uint256 remainingPoints = 54; // 72 total - (6 * 3 minimum)

        // Distribute remaining points across first 5 stats
        uint256 order = uint256(keccak256(abi.encodePacked(randomSeed, "order")));

        unchecked {
            for (uint256 i; i < 5; ++i) {
                // Select random stat index and update order
                uint256 statIndex = order.uniform(6 - i);
                order = uint256(keccak256(abi.encodePacked(order)));

                // Calculate available points for this stat
                uint256 pointsNeededForRemaining = (5 - i) * 3;
                uint256 availablePoints =
                    remainingPoints > pointsNeededForRemaining ? remainingPoints - pointsNeededForRemaining : 0;

                // Add random points to selected stat
                uint256 pointsToAdd = randomSeed.uniform(min(availablePoints, 18) + 1);
                randomSeed = uint256(keccak256(abi.encodePacked(randomSeed)));

                // Update stat and remaining points
                statArray[statIndex] += uint8(pointsToAdd);
                remainingPoints -= pointsToAdd;

                // Swap with last unassigned stat
                uint8 temp = statArray[statIndex];
                statArray[statIndex] = statArray[5 - i];
                statArray[5 - i] = temp;
            }

            // Assign remaining points to last stat
            statArray[0] += uint8(min(remainingPoints, 18));
        }

        // Create stats struct
        stats = IPlayer.PlayerStats({
            strength: statArray[0],
            constitution: statArray[1],
            size: statArray[2],
            agility: statArray[3],
            stamina: statArray[4],
            luck: statArray[5],
            skinIndex: 1,
            skinTokenId: 1
        });

        // Validate and fix if necessary
        if (!_validateStats(stats)) {
            stats = _fixStats(stats, randomSeed);
        }

        // Store player data
        _players[playerId] = stats;
        _playerOwners[playerId] = msg.sender;
        _addressToPlayerIds[msg.sender].push(playerId);

        return (playerId, stats);
    }

    // Function to equip a skin
    function equipSkin(uint256 playerId, uint256 skinIndex, uint256 tokenId) external {
        if (_playerOwners[playerId] != msg.sender) revert PlayerDoesNotExist(playerId);
        PlayerSkinRegistry.SkinInfo memory skin = skinRegistry.getSkin(skinIndex);
        if (ERC721(skin.contractAddress).ownerOf(tokenId) != msg.sender) revert NotSkinOwner();

        _players[playerId].skinIndex = uint32(skinIndex);
        _players[playerId].skinTokenId = uint16(tokenId);
    }

    // Make sure all interface functions are marked as external
    function getPlayerIds(address owner) external view returns (uint256[] memory) {
        return _addressToPlayerIds[owner];
    }

    function getPlayer(uint256 playerId) external view returns (IPlayer.PlayerStats memory) {
        if (_players[playerId].strength == 0) revert PlayerDoesNotExist(playerId);
        return _players[playerId];
    }

    function getPlayerOwner(uint256 playerId) external view returns (address) {
        if (_playerOwners[playerId] == address(0)) revert PlayerDoesNotExist(playerId);
        return _playerOwners[playerId];
    }

    function players(uint256 playerId) external view returns (IPlayer.PlayerStats memory) {
        if (_players[playerId].strength == 0) revert PlayerDoesNotExist(playerId);
        return _players[playerId];
    }

    function getPlayerState(uint256 playerId) external view returns (uint256 health, uint256 stamina) {
        PlayerStats memory player = _players[playerId];
        if (player.strength == 0) revert PlayerDoesNotExist(playerId);
        CalculatedStats memory stats = this.calculateStats(player);
        return (uint256(stats.maxHealth), uint256(stats.maxEndurance));
    }

    function calculateStats(PlayerStats memory player) external pure returns (CalculatedStats memory) {
        uint8 str = player.strength;
        uint8 con = player.constitution;
        uint8 siz = player.size;
        uint8 agi = player.agility;
        uint8 sta = player.stamina;
        uint8 luc = player.luck;

        // Physical Power Modifier Formula
        // Purpose: Creates a linear scale for damage based on combined strength + size
        // Formula: y = 4.167x + 25 (scaled by 1000 for integer math)
        // Where x is (strength + size)
        // Results in:
        //   - 50% power at minimum (str+siz = 6)
        //   - 100% power at average (str+siz = 24)
        //   - 200% power at maximum (str+siz = 42)
        // Use uint32 for the intermediate calculation to prevent overflow
        uint32 combinedStats = uint32(player.strength) + uint32(player.size);
        uint32 tempPowerMod = 25 + (((combinedStats * 4167) / 1000));
        // Then safely convert back to uint16
        uint16 physicalPowerMod = tempPowerMod > type(uint16).max ? type(uint16).max : uint16(tempPowerMod);

        return CalculatedStats({
            // Health now factors in size (bigger = more health)
            maxHealth: uint16(45 + (con * 8) + (siz * 4)),
            // Instead of direct damage, this is now a percentage modifier
            // This will be applied to weapon damage ranges
            damageModifier: physicalPowerMod,
            // Hit chance now factors in luck
            hitChance: uint16(30 + (agi * 2) + (luc * 1)),
            // Block now uses size (bigger = better blocker)
            blockChance: uint16(10 + (con * 2) + (siz * 1)),
            // Dodge reduced slightly, smaller characters better at dodging
            dodgeChance: uint16(5 + (agi * 2) + ((21 - siz) * 1)),
            // Endurance now factors in size (bigger = more endurance)
            maxEndurance: uint16(45 + (sta * 8) + (siz * 2)),
            // Crit chance affected by luck
            critChance: uint16(2 + (agi * 1) + (luc * 1)),
            // Initiative penalized by size (bigger = slower)
            initiative: uint16((sta + agi) * 3) - uint16(siz),
            // Counter chance affected by luck
            counterChance: uint16(3 + (agi * 1) + (luc * 1)),
            // Crit multiplier affected by strength and luck
            critMultiplier: uint16(150 + (str * 3) + (luc * 2))
        });
    }

    // Helper functions (can remain private/internal)
    function _validateStats(IPlayer.PlayerStats memory player) private pure returns (bool) {
        // Check stat bounds
        if (player.strength < MIN_STAT || player.strength > MAX_STAT) return false;
        if (player.constitution < MIN_STAT || player.constitution > MAX_STAT) return false;
        if (player.size < MIN_STAT || player.size > MAX_STAT) return false;
        if (player.agility < MIN_STAT || player.agility > MAX_STAT) return false;
        if (player.stamina < MIN_STAT || player.stamina > MAX_STAT) return false;
        if (player.luck < MIN_STAT || player.luck > MAX_STAT) return false;

        // Calculate total using uint16 to prevent any overflow
        uint16 total = uint16(player.strength) + uint16(player.constitution) + uint16(player.size)
            + uint16(player.agility) + uint16(player.stamina) + uint16(player.luck);

        return total == TOTAL_STATS;
    }

    function _fixStats(IPlayer.PlayerStats memory player, uint256 randomSeed)
        private
        pure
        returns (IPlayer.PlayerStats memory)
    {
        uint16 total = uint16(player.strength) + uint16(player.constitution) + uint16(player.size)
            + uint16(player.agility) + uint16(player.stamina) + uint16(player.luck);

        // First ensure all stats are within 3-21 range
        uint8[6] memory stats =
            [player.strength, player.constitution, player.size, player.agility, player.stamina, player.luck];

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
            uint256 seed = uint256(keccak256(abi.encodePacked(randomSeed)));
            randomSeed = seed;

            if (total < 72) {
                uint256 statIndex = seed.uniform(6);
                if (stats[statIndex] < 21) {
                    stats[statIndex] += 1;
                    total += 1;
                }
            } else {
                uint256 statIndex = seed.uniform(6);
                if (stats[statIndex] > 3) {
                    stats[statIndex] -= 1;
                    total -= 1;
                }
            }
        }

        return IPlayer.PlayerStats({
            strength: stats[0],
            constitution: stats[1],
            size: stats[2],
            agility: stats[3],
            stamina: stats[4],
            luck: stats[5],
            skinIndex: 1,
            skinTokenId: 1
        });
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    // Function to update max players per address, restricted to the owner
    function setMaxPlayersPerAddress(uint256 newMax) external onlyOwner {
        maxPlayersPerAddress = newMax;
        emit MaxPlayersUpdated(newMax);
    }
}

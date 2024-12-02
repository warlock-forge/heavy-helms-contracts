// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/src/auth/Owned.sol";
import "./lib/UniformRandomNumber.sol";
import "./interfaces/IPlayer.sol";
import "./PlayerSkinRegistry.sol";
import "solmate/src/tokens/ERC721.sol";
import "./interfaces/IPlayerSkinNFT.sol";
import "./GameStats.sol";

error PlayerDoesNotExist(uint256 playerId);
error NotSkinOwner();
error StatRequirementsNotMet();
error SkinRegistryDoesNotExist();
error InvalidSkinAttributes();
error NotDefaultSkinContract();
error InvalidDefaultPlayerId();

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

    // Add GameStats reference
    GameStats public immutable gameStats;

    // Events
    event PlayerRetired(uint256 indexed playerId);
    event MaxPlayersUpdated(uint256 newMax);
    event SkinEquipped(uint256 indexed playerId, uint32 indexed skinIndex, uint16 tokenId);

    // Constants
    uint8 private constant MIN_STAT = 3;
    uint8 private constant MAX_STAT = 21;
    uint16 private constant TOTAL_STATS = 72;

    uint32 private nextPlayerId = 1000;

    constructor(address skinRegistryAddress, address gameStatsAddress) Owned(msg.sender) {
        maxPlayersPerAddress = 5;
        skinRegistry = PlayerSkinRegistry(payable(skinRegistryAddress));
        gameStats = GameStats(gameStatsAddress);
    }

    // Make sure this matches the interface exactly
    function createPlayer() external returns (uint256 playerId, IPlayer.PlayerStats memory stats) {
        require(_addressPlayerCount[msg.sender] < maxPlayersPerAddress, "Too many players");

        // Generate randomSeed for stats only
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));

        // Use incremental playerId instead of random
        playerId = nextPlayerId++;

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
    function equipSkin(uint256 playerId, uint32 skinIndex, uint16 tokenId) external {
        // Check if player exists and belongs to sender
        if (_playerOwners[playerId] != msg.sender) revert PlayerDoesNotExist(playerId);

        // Get skin info from registry
        PlayerSkinRegistry.SkinInfo memory skin;
        try skinRegistry.getSkin(skinIndex) returns (PlayerSkinRegistry.SkinInfo memory _skin) {
            skin = _skin;
        } catch {
            revert SkinRegistryDoesNotExist();
        }

        // Only check ownership if it's not from the default skin collection
        if (skinIndex != skinRegistry.defaultSkinRegistryId()) {
            try ERC721(skin.contractAddress).ownerOf(tokenId) returns (address owner) {
                if (owner != msg.sender) revert NotSkinOwner();
            } catch {
                revert NotSkinOwner();
            }
        }

        // Get and validate skin attributes
        IPlayerSkinNFT skinContract = IPlayerSkinNFT(skin.contractAddress);
        IPlayerSkinNFT.SkinAttributes memory attrs;
        try skinContract.getSkinAttributes(tokenId) returns (IPlayerSkinNFT.SkinAttributes memory _attrs) {
            attrs = _attrs;
        } catch {
            revert InvalidSkinAttributes();
        }

        // Check stat requirements using GameStats from registry
        (bool meetsWeaponReqs, bool meetsArmorReqs) =
            gameStats.checkStatRequirements(attrs.weapon, attrs.armor, _players[playerId]);

        if (!meetsWeaponReqs || !meetsArmorReqs) revert StatRequirementsNotMet();

        // Update player's equipped skin
        _players[playerId].skinIndex = skinIndex;
        _players[playerId].skinTokenId = tokenId;

        emit SkinEquipped(playerId, skinIndex, tokenId);
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

    function calculateStats(PlayerStats memory player) public pure returns (CalculatedStats memory) {
        // Safe health calculation
        uint16 maxHealth = uint16(75 + (uint32(player.constitution) * 12) + (uint32(player.size) * 6));

        // Safe endurance calculation
        uint16 maxEndurance = uint16(45 + (uint32(player.stamina) * 8) + (uint32(player.size) * 2));

        // Safe initiative calculation
        uint16 initiative = uint16(20 + (uint32(player.agility) * 3) + (uint32(player.luck) * 2));

        // Safe defensive stats calculation
        uint16 dodgeChance =
            uint16(2 + (uint32(player.agility) * 8 / 10) + (uint32(21 - min(player.size, 21)) * 5 / 10));

        uint16 blockChance = uint16(5 + (uint32(player.constitution) * 8 / 10) + (uint32(player.size) * 5 / 10));

        uint16 parryChance = uint16(3 + (uint32(player.strength) * 6 / 10) + (uint32(player.agility) * 6 / 10));

        // Safe hit chance calculation
        uint16 hitChance = uint16(30 + (uint32(player.agility) * 2) + (uint32(player.luck)));

        // Safe crit calculations
        uint16 critChance = uint16(2 + (uint32(player.agility)) + (uint32(player.luck)));

        uint16 critMultiplier = uint16(150 + (uint32(player.strength) * 3) + (uint32(player.luck) * 2));

        // Safe counter chance
        uint16 counterChance = uint16(3 + (uint32(player.agility)) + (uint32(player.luck)));

        // Physical power calculation
        uint32 combinedStats = uint32(player.strength) + uint32(player.size);
        uint32 tempPowerMod = 25 + ((combinedStats * 4167) / 1000);
        uint16 physicalPowerMod = uint16(min(tempPowerMod, type(uint16).max));

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
            damageModifier: physicalPowerMod
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

    function _fixStats(IPlayer.PlayerStats memory player, uint256 seed)
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

    function initializeDefaultPlayer(uint32 playerId, PlayerStats memory stats) external {
        // Only allow calls from the default skin contract
        PlayerSkinRegistry registry = skinRegistry;
        address defaultSkinContract = registry.getSkin(registry.defaultSkinRegistryId()).contractAddress;
        if (msg.sender != defaultSkinContract) revert NotDefaultSkinContract();

        _players[playerId] = stats;
        _playerOwners[playerId] = address(this);
    }

    function createDefaultPlayer(uint32 playerId, PlayerStats memory stats, bool overwrite) external onlyOwner {
        // Ensure ID is in valid range for default players (1-999)
        if (playerId >= 1000 || playerId == 0) revert InvalidDefaultPlayerId();

        // If player exists and overwrite is false, revert
        if (!overwrite && _players[playerId].strength != 0) {
            revert("Player ID already exists");
        }

        _players[playerId] = stats;
        _playerOwners[playerId] = address(this);
    }
}

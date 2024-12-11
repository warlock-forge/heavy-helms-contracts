// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/src/auth/Owned.sol";
import "./lib/UniformRandomNumber.sol";
import "./interfaces/IPlayer.sol";
import "./PlayerSkinRegistry.sol";
import "./interfaces/IPlayerSkinNFT.sol";
import "./PlayerEquipmentStats.sol";
import "./PlayerNameRegistry.sol";
import "./interfaces/IDefaultPlayerSkinNFT.sol";
import "vrf-contracts/contracts/GelatoVRFConsumerBase.sol";
import "./PlayerEquipmentStats.sol"; // Import PlayerEquipmentStats types

error PlayerDoesNotExist(uint256 playerId);
error NotSkinOwner();
error NotDefaultSkinContract();
error InvalidDefaultPlayerId();
error InvalidContractAddress();
error RequiredNFTNotOwned(address nftAddress);

contract Player is IPlayer, Owned, GelatoVRFConsumerBase {
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

    // Reference to the PlayerNameRegistry contract
    PlayerNameRegistry public nameRegistry;

    // Add GameStats reference
    PlayerEquipmentStats public equipmentStats;

    // Events
    event PlayerRetired(uint256 indexed playerId);
    event MaxPlayersUpdated(uint256 newMax);
    event SkinEquipped(uint256 indexed playerId, uint32 indexed skinIndex, uint16 tokenId);
    event EquipmentStatsUpdated(address indexed oldStats, address indexed newStats);
    event PlayerSkinEquipped(uint256 indexed playerId, uint32 indexed skinIndex, uint16 tokenId);
    event PlayerCreationRequested(uint256 indexed requestId, address indexed requester);
    event PlayerCreationFulfilled(uint256 indexed requestId, uint256 indexed playerId, address indexed owner);

    // Constants
    uint8 private constant MIN_STAT = 3;
    uint8 private constant MAX_STAT = 21;
    uint16 private constant TOTAL_STATS = 72;
    uint256 private constant ROUND_ID = 1;

    uint32 private nextPlayerId = 1000;

    struct PendingPlayer {
        address owner;
        bool useNameSetB;
        bool fulfilled;
    }

    mapping(uint256 => PendingPlayer) private _pendingPlayers;
    mapping(address => uint256[]) private _userPendingRequests;

    // Add operator as a state variable
    address private immutable _operatorAddress;

    constructor(
        address skinRegistryAddress,
        address nameRegistryAddress,
        address equipmentStatsAddress,
        address operator
    ) Owned(msg.sender) {
        maxPlayersPerAddress = 6;
        skinRegistry = PlayerSkinRegistry(payable(skinRegistryAddress));
        nameRegistry = PlayerNameRegistry(nameRegistryAddress);
        equipmentStats = PlayerEquipmentStats(equipmentStatsAddress);
        _operatorAddress = operator;
    }

    // Override _operator to use the operator address
    function _operator() internal view override returns (address) {
        return _operatorAddress;
    }

    // Add these helper functions at the top with the other internal functions
    function _exists(uint256 playerId) internal view returns (bool) {
        return _players[playerId].strength != 0;
    }

    function _ownerOf(uint256 playerId) internal view returns (address) {
        return _playerOwners[playerId];
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
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
            skinIndex: player.skinIndex,
            skinTokenId: player.skinTokenId,
            firstNameIndex: player.firstNameIndex,
            surnameIndex: player.surnameIndex
        });
    }

    // Helper function to check if an address owns any NFT from a collection
    function _checkCollectionOwnership(address owner, address nftContract) internal view returns (bool) {
        (bool success, bytes memory data) = nftContract.staticcall(abi.encodeWithSignature("balanceOf(address)", owner));

        if (!success) return false;

        uint256 balance = abi.decode(data, (uint256));
        return balance > 0;
    }

    // Function to equip a skin
    function equipSkin(uint256 playerId, uint32 skinIndex, uint16 skinTokenId) external {
        // Verify player exists and is owned by sender
        if (!_exists(playerId) || _ownerOf(playerId) != msg.sender) {
            revert PlayerDoesNotExist(playerId);
        }

        // Get skin info from registry
        PlayerSkinRegistry.SkinInfo memory skinInfo = skinRegistry.getSkin(skinIndex);

        // Check required NFT first if it exists
        if (skinInfo.requiredNFTAddress != address(0)) {
            if (!_checkCollectionOwnership(msg.sender, skinInfo.requiredNFTAddress)) {
                revert PlayerSkinRegistry.RequiredNFTNotOwned(skinInfo.requiredNFTAddress);
            }
        }

        // Case 1: Default collection - anyone can equip
        if (skinInfo.isDefaultCollection) {
            // Allow equip
        }
        // Case 2 & 3: Non-default collections
        else {
            // Check if player owns the specific skin NFT
            IPlayerSkinNFT skinContract = IPlayerSkinNFT(skinInfo.contractAddress);
            bool ownsSpecificNFT = false;
            try skinContract.ownerOf(skinTokenId) returns (address owner) {
                ownsSpecificNFT = (owner == msg.sender);
            } catch {
                revert("ERC721: invalid token ID");
            }

            // If they don't own this specific NFT, they must be using a verified collection
            if (!ownsSpecificNFT) {
                if (!skinInfo.isVerified) {
                    revert NotSkinOwner();
                }

                // For verified collections, they must own at least one NFT from the collection
                if (!_checkCollectionOwnership(msg.sender, skinInfo.contractAddress)) {
                    revert NotSkinOwner();
                }
            }
        }

        // Update player's skin
        _players[playerId].skinIndex = skinIndex;
        _players[playerId].skinTokenId = skinTokenId;

        emit PlayerSkinEquipped(playerId, skinIndex, skinTokenId);
    }

    // Make sure all interface functions are marked as external
    function getPlayerIds(address owner) external view returns (uint256[] memory) {
        return _addressToPlayerIds[owner];
    }

    function getPlayer(uint256 playerId) public view returns (PlayerStats memory) {
        // If it's a default character (1-999)
        if (playerId < 1000) {
            // Get default skin registry
            uint32 defaultSkinIndex = skinRegistry.defaultSkinRegistryId();
            PlayerSkinRegistry.SkinInfo memory defaultSkinInfo = skinRegistry.getSkin(defaultSkinIndex);

            try IDefaultPlayerSkinNFT(defaultSkinInfo.contractAddress).getDefaultPlayerStats(playerId) returns (
                PlayerStats memory stats
            ) {
                // Set the skin information for default characters
                stats.skinIndex = defaultSkinIndex;
                stats.skinTokenId = uint16(playerId);
                return stats;
            } catch {
                revert PlayerDoesNotExist(playerId);
            }
        }

        // For user characters, check existence
        if (_playerOwners[playerId] == address(0)) {
            revert PlayerDoesNotExist(playerId);
        }

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
        PlayerStats memory player = this.getPlayer(playerId);
        CalculatedStats memory stats = this.calculateStats(player);
        return (uint256(stats.maxHealth), uint256(stats.maxEndurance));
    }

    function calculateStats(PlayerStats memory player) public pure returns (CalculatedStats memory) {
        // Safe health calculation using uint32 for intermediate values
        uint32 healthBase = 75;
        uint32 healthFromCon = uint32(player.constitution) * 12;
        uint32 healthFromSize = uint32(player.size) * 6;
        uint16 maxHealth = uint16(healthBase + healthFromCon + healthFromSize);

        // Safe endurance calculation
        uint32 enduranceBase = 45;
        uint32 enduranceFromStamina = uint32(player.stamina) * 8;
        uint32 enduranceFromSize = uint32(player.size) * 2;
        uint16 maxEndurance = uint16(enduranceBase + enduranceFromStamina + enduranceFromSize);

        // Safe initiative calculation
        uint32 initiativeBase = 20;
        uint32 initiativeFromAgility = uint32(player.agility) * 3;
        uint32 initiativeFromLuck = uint32(player.luck) * 2;
        uint16 initiative = uint16(initiativeBase + initiativeFromAgility + initiativeFromLuck);

        // Safe defensive stats calculation
        uint16 dodgeChance =
            uint16(2 + (uint32(player.agility) * 8 / 10) + (uint32(21 - min(player.size, 21)) * 5 / 10));
        uint16 blockChance = uint16(5 + (uint32(player.constitution) * 8 / 10) + (uint32(player.size) * 5 / 10));
        uint16 parryChance = uint16(3 + (uint32(player.strength) * 6 / 10) + (uint32(player.agility) * 6 / 10));

        // Safe hit chance calculation
        uint16 hitChance = uint16(30 + (uint32(player.agility) * 2) + uint32(player.luck));

        // Safe crit calculations
        uint16 critChance = uint16(2 + uint32(player.agility) + uint32(player.luck));
        uint16 critMultiplier = uint16(150 + (uint32(player.strength) * 3) + (uint32(player.luck) * 2));

        // Safe counter chance
        uint16 counterChance = uint16(3 + uint32(player.agility) + uint32(player.luck));

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

        // Calculate total stat points
        uint256 total = uint256(player.strength) + uint256(player.constitution) + uint256(player.size)
            + uint256(player.agility) + uint256(player.stamina) + uint256(player.luck);

        // Total should be exactly 72 (6 stats * 3 minimum = 18, plus 54 points to distribute)
        return total == TOTAL_STATS;
    }

    // Function to update max players per address, restricted to the owner
    function setMaxPlayersPerAddress(uint256 newMax) external onlyOwner {
        maxPlayersPerAddress = newMax;
        emit MaxPlayersUpdated(newMax);
    }

    function setEquipmentStats(address newEquipmentStats) external onlyOwner {
        if (newEquipmentStats == address(0)) revert InvalidContractAddress();

        // Store old address for event
        address oldStats = address(equipmentStats);

        // Validate interface by trying to call a view function
        PlayerEquipmentStats newStats = PlayerEquipmentStats(newEquipmentStats);
        newStats.getStanceMultiplier(IPlayerSkinNFT.FightingStance.Balanced); // Will revert if invalid

        equipmentStats = newStats;
        emit EquipmentStatsUpdated(oldStats, newEquipmentStats);
    }

    function requestCreatePlayer(bool useNameSetB) external returns (uint256 requestId) {
        require(_addressPlayerCount[msg.sender] < maxPlayersPerAddress, "Too many players");
        require(_userPendingRequests[msg.sender].length == 0, "Pending request exists");

        // Request randomness from Gelato VRF
        requestId = _requestRandomness("");

        // Store pending player data
        _pendingPlayers[requestId] = PendingPlayer({owner: msg.sender, useNameSetB: useNameSetB, fulfilled: false});

        // Track this request for the user
        _userPendingRequests[msg.sender].push(requestId);

        emit PlayerCreationRequested(requestId, msg.sender);
        return requestId;
    }

    function _fulfillRandomness(uint256 randomness, uint256 requestId, bytes memory extraData) internal override {
        // Check if request ID exists first
        PendingPlayer memory pending = _pendingPlayers[requestId];
        if (pending.owner == address(0)) {
            revert("Invalid request ID");
        }

        require(!pending.fulfilled, "Request already fulfilled");

        // Mark as fulfilled first to prevent reentrancy
        _pendingPlayers[requestId].fulfilled = true;

        // Create a new random seed by combining VRF randomness with request data
        uint256 combinedSeed = uint256(keccak256(abi.encodePacked(randomness, requestId, pending.owner)));

        // Create the player with the combined seed
        (uint256 playerId,) = _createPlayerWithRandomness(pending.owner, pending.useNameSetB, combinedSeed);

        emit PlayerCreationFulfilled(requestId, playerId, pending.owner);

        // Remove from user's pending requests
        _removeFromPendingRequests(pending.owner, requestId);

        // Cleanup
        delete _pendingPlayers[requestId];
    }

    function getRequestStatus(uint256 requestId) external view returns (bool exists, bool fulfilled, address owner) {
        PendingPlayer memory pending = _pendingPlayers[requestId];
        exists = pending.owner != address(0);
        fulfilled = pending.fulfilled;
        owner = pending.owner;
        return (exists, fulfilled, owner);
    }

    function _removeFromPendingRequests(address user, uint256 requestId) internal {
        uint256[] storage requests = _userPendingRequests[user];
        for (uint256 i = 0; i < requests.length; i++) {
            if (requests[i] == requestId) {
                requests[i] = requests[requests.length - 1];
                requests.pop();
                break;
            }
        }
    }

    function getPendingRequests(address user) external view returns (uint256[] memory) {
        return _userPendingRequests[user];
    }

    // Make the original createPlayer logic private and rename it
    function _createPlayerWithRandomness(address owner, bool useNameSetB, uint256 randomSeed)
        internal
        returns (uint256 playerId, IPlayer.PlayerStats memory stats)
    {
        require(_addressPlayerCount[owner] < maxPlayersPerAddress, "Too many players");

        // Use incremental playerId
        playerId = nextPlayerId++;

        // Initialize base stats array with minimum values
        uint8[6] memory statArray = [3, 3, 3, 3, 3, 3];
        uint256 remainingPoints = 54; // 72 total - (6 * 3 minimum)

        // Distribute remaining points across stats
        uint256 order = uint256(keccak256(abi.encodePacked(randomSeed, "order")));

        unchecked {
            for (uint256 i; i < 5; ++i) {
                // Select random stat index and update order
                uint256 statIndex = order.uniform(6 - i);
                order = uint256(keccak256(abi.encodePacked(order)));

                // Calculate available points for this stat
                uint256 pointsNeededForRemaining = (5 - i) * 3; // Ensure minimum 3 points for each remaining stat
                uint256 availablePoints =
                    remainingPoints > pointsNeededForRemaining ? remainingPoints - pointsNeededForRemaining : 0;

                // Add random points to selected stat
                uint256 pointsToAdd = randomSeed.uniform(min(availablePoints, 18) + 1);
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

            // Assign all remaining points to the last stat
            statArray[0] += uint8(remainingPoints);
        }

        // Generate name indices based on player preference
        uint16 firstNameIndex;
        if (useNameSetB) {
            firstNameIndex =
                uint16(uint256(keccak256(abi.encodePacked(randomSeed, "firstName"))) % nameRegistry.getNameSetBLength());
        } else {
            firstNameIndex = nameRegistry.SET_A_START()
                + uint16(uint256(keccak256(abi.encodePacked(randomSeed, "firstName"))) % nameRegistry.getNameSetALength());
        }

        uint16 surnameIndex =
            uint16(uint256(keccak256(abi.encodePacked(randomSeed, "surname"))) % nameRegistry.getSurnamesLength());

        // Create stats struct
        stats = IPlayer.PlayerStats({
            strength: statArray[0],
            constitution: statArray[1],
            size: statArray[2],
            agility: statArray[3],
            stamina: statArray[4],
            luck: statArray[5],
            skinIndex: 1,
            skinTokenId: 1,
            firstNameIndex: firstNameIndex,
            surnameIndex: surnameIndex
        });

        // Validate and fix if necessary
        if (!_validateStats(stats)) {
            stats = _fixStats(stats, randomSeed);
        }

        // Store player data
        _players[playerId] = stats;
        _playerOwners[playerId] = owner;
        _addressToPlayerIds[owner].push(playerId);
        _addressPlayerCount[owner]++;

        return (playerId, stats);
    }
}

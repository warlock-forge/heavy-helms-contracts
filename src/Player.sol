// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/src/auth/Owned.sol";
import "solmate/src/utils/SafeTransferLib.sol";
import "./lib/UniformRandomNumber.sol";
import "./interfaces/IPlayer.sol";
import "./PlayerSkinRegistry.sol";
import "./interfaces/IPlayerSkinNFT.sol";
import "./PlayerEquipmentStats.sol";
import "./PlayerNameRegistry.sol";
import "./interfaces/IDefaultPlayerSkinNFT.sol";
import "vrf-contracts/contracts/GelatoVRFConsumerBase.sol";
import "./PlayerEquipmentStats.sol"; // Import PlayerEquipmentStats types
import "solmate/src/utils/ReentrancyGuard.sol";

error PlayerDoesNotExist(uint256 playerId);
error NotSkinOwner();
error NotDefaultSkinContract();
error InvalidDefaultPlayerId();
error InvalidContractAddress();
error RequiredNFTNotOwned(address nftAddress);

contract Player is IPlayer, Owned, GelatoVRFConsumerBase, ReentrancyGuard {
    using UniformRandomNumber for uint256;

    // Configuration
    uint256 public override maxPlayersPerAddress;
    uint256 public createPlayerFeeAmount;

    // Player state tracking
    mapping(uint256 => IPlayer.PlayerStats) private _players;
    mapping(uint256 => address) private _playerOwners;
    mapping(uint256 => bool) private _retiredPlayers; // Track retirement status

    // Player count tracking per address
    mapping(address => uint256) private _addressPlayerCount;
    mapping(address => uint256[]) private _addressToPlayerIds;

    // Reference to the PlayerSkinRegistry contract
    PlayerSkinRegistry public skinRegistry;

    // Reference to the PlayerNameRegistry contract
    PlayerNameRegistry public nameRegistry;

    // Add GameStats reference
    PlayerEquipmentStats public equipmentStats;

    // Permissions for game contracts
    mapping(address => IPlayer.GamePermissions) private _gameContractPermissions;

    // Modifier to check specific permission
    modifier hasPermission(IPlayer.GamePermission permission) {
        IPlayer.GamePermissions storage perms = _gameContractPermissions[msg.sender];
        bool hasAccess = permission == IPlayer.GamePermission.RECORD
            ? perms.record
            : permission == IPlayer.GamePermission.RETIRE
                ? perms.retire
                : permission == IPlayer.GamePermission.NAME
                    ? perms.name
                    : permission == IPlayer.GamePermission.ATTRIBUTES ? perms.attributes : false;
        require(hasAccess, "Missing required permission");
        _;
    }

    // Events
    event PlayerRetired(uint256 indexed playerId, address indexed caller, bool retired);
    event PlayerResurrected(uint256 indexed playerId);
    event MaxPlayersUpdated(uint256 newMax);
    event SkinEquipped(uint256 indexed playerId, uint32 indexed skinIndex, uint16 tokenId);
    event EquipmentStatsUpdated(address indexed oldStats, address indexed newStats);
    event PlayerSkinEquipped(uint256 indexed playerId, uint32 indexed skinIndex, uint16 tokenId);
    event PlayerCreationRequested(uint256 indexed requestId, address indexed requester);
    event PlayerCreationFulfilled(uint256 indexed requestId, uint256 indexed playerId, address indexed owner);
    event GameContractTrustUpdated(address indexed gameContract, bool trusted);
    event CreatePlayerFeeUpdated(uint256 oldFee, uint256 newFee);

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

    // Change from immutable to mutable operator
    address private _operatorAddress;

    constructor(
        address skinRegistryAddress,
        address nameRegistryAddress,
        address equipmentStatsAddress,
        address operator
    ) Owned(msg.sender) {
        maxPlayersPerAddress = 6;
        createPlayerFeeAmount = 0.001 ether;
        skinRegistry = PlayerSkinRegistry(payable(skinRegistryAddress));
        nameRegistry = PlayerNameRegistry(nameRegistryAddress);
        equipmentStats = PlayerEquipmentStats(equipmentStatsAddress);
        _operatorAddress = operator;
    }

    // Add setOperator function
    function setOperator(address newOperator) external onlyOwner {
        require(newOperator != address(0), "Invalid operator address");
        _operatorAddress = newOperator;
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
            surnameIndex: player.surnameIndex,
            wins: player.wins,
            losses: player.losses,
            kills: player.kills
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

    function setCreatePlayerFeeAmount(uint256 newFeeAmount) external onlyOwner {
        uint256 oldFee = createPlayerFeeAmount;
        createPlayerFeeAmount = newFeeAmount;
        emit CreatePlayerFeeUpdated(oldFee, newFeeAmount);
    }

    function withdrawFees() external nonReentrant onlyOwner {
        SafeTransferLib.safeTransferETH(owner, address(this).balance);
    }

    function clearPendingRequestsForAddress(address user) external onlyOwner {
        // Clear all pending requests for this user
        uint256[] memory requests = _userPendingRequests[user];
        for (uint256 i = 0; i < requests.length; i++) {
            uint256 requestId = requests[i];
            delete _pendingPlayers[requestId];
        }
        delete _userPendingRequests[user];
    }

    function requestCreatePlayer(bool useNameSetB) external payable nonReentrant returns (uint256 requestId) {
        // Checks
        require(_addressPlayerCount[msg.sender] < maxPlayersPerAddress, "Too many players");
        require(_userPendingRequests[msg.sender].length == 0, "Pending request exists");
        require(msg.value >= createPlayerFeeAmount, "Insufficient fee amount");

        // Effects - Get requestId first since it's deterministic and can't fail
        requestId = _requestRandomness("");
        _pendingPlayers[requestId] = PendingPlayer({owner: msg.sender, useNameSetB: useNameSetB, fulfilled: false});
        _userPendingRequests[msg.sender].push(requestId);

        // Interactions (just the event emission)
        emit PlayerCreationRequested(requestId, msg.sender);
    }

    function _fulfillRandomness(uint256 randomness, uint256 requestId, bytes memory extraData)
        internal
        override
        nonReentrant
    {
        // Checks
        PendingPlayer memory pending = _pendingPlayers[requestId];
        require(pending.owner != address(0), "Invalid request ID");
        require(!pending.fulfilled, "Request already fulfilled");

        // Effects
        _pendingPlayers[requestId].fulfilled = true;
        uint256 combinedSeed = uint256(keccak256(abi.encodePacked(randomness, requestId, pending.owner)));
        (uint256 playerId,) = _createPlayerWithRandomness(pending.owner, pending.useNameSetB, combinedSeed);

        // Remove from user's pending requests and cleanup
        _removeFromPendingRequests(pending.owner, requestId);
        delete _pendingPlayers[requestId];

        // Interactions (just the event emission)
        emit PlayerCreationFulfilled(requestId, playerId, pending.owner);
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

                // Add extra entropy and make high points rarer
                // Note: Since stats start at 3, we need max 18 additional points to reach 21
                uint256 maxPoints = min(availablePoints, 18);
                uint256 chance = randomSeed.uniform(100);
                randomSeed = uint256(keccak256(abi.encodePacked(randomSeed, "chance")));

                // 50% chance of normal roll (up to 9 more points, max 12 total)
                // 30% chance of medium roll (up to 12 more points, max 15 total)
                // 15% chance of high roll (up to 15 more points, max 18 total)
                // 5% chance of max roll (up to 18 more points, max 21 total)
                uint256 pointsCap = chance < 50
                    ? 9 // 0-49: normal roll (3+9=12)
                    : chance < 80
                        ? 12 // 50-79: medium roll (3+12=15)
                        : chance < 95
                            ? 15 // 80-94: high roll (3+15=18)
                            : 18; // 95-99: max roll (3+18=21)

                // Add random points to selected stat using the cap
                uint256 pointsToAdd = randomSeed.uniform(min(maxPoints, pointsCap) + 1);
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
            firstNameIndex = uint16(randomSeed.uniform(nameRegistry.getNameSetBLength()));
        } else {
            firstNameIndex = uint16(randomSeed.uniform(nameRegistry.getNameSetALength())) + nameRegistry.SET_A_START();
        }

        uint16 surnameIndex = uint16(randomSeed.uniform(nameRegistry.getSurnamesLength()));

        // Create stats struct
        stats = IPlayer.PlayerStats({
            strength: statArray[0],
            constitution: statArray[1],
            size: statArray[2],
            agility: statArray[3],
            stamina: statArray[4],
            luck: statArray[5],
            skinIndex: 0, // Updated to use index 0 for default skin
            skinTokenId: 1, // Keep this as 1 since NFT token IDs start at 1
            firstNameIndex: firstNameIndex,
            surnameIndex: surnameIndex,
            wins: 0,
            losses: 0,
            kills: 0
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

    function gameContractPermissions(address gameContract) external view returns (GamePermissions memory) {
        return _gameContractPermissions[gameContract];
    }

    function setGameContractPermission(address gameContract, IPlayer.GamePermissions memory permissions)
        external
        onlyOwner
    {
        _gameContractPermissions[gameContract] = permissions;
    }

    function incrementWins(uint32 playerId) external hasPermission(IPlayer.GamePermission.RECORD) {
        require(_players[playerId].strength != 0, "Player does not exist");
        PlayerStats storage stats = _players[playerId];
        stats.wins++;
    }

    function incrementLosses(uint32 playerId) external hasPermission(IPlayer.GamePermission.RECORD) {
        require(_players[playerId].strength != 0, "Player does not exist");
        PlayerStats storage stats = _players[playerId];
        stats.losses++;
    }

    function incrementKills(uint32 playerId) external hasPermission(IPlayer.GamePermission.RECORD) {
        require(_players[playerId].strength != 0, "Player does not exist");
        PlayerStats storage stats = _players[playerId];
        stats.kills++;
    }

    function setPlayerRetired(uint256 playerId, bool retired) external hasPermission(IPlayer.GamePermission.RETIRE) {
        require(_players[playerId].strength != 0, "Player does not exist");
        _retiredPlayers[playerId] = retired;
        emit PlayerRetired(playerId, msg.sender, retired);
    }

    function setPlayerName(uint32 playerId, uint16 firstNameIndex, uint16 surnameIndex)
        external
        hasPermission(IPlayer.GamePermission.NAME)
    {
        require(_players[playerId].strength != 0, "Player does not exist");
        PlayerStats storage player = _players[playerId];
        player.firstNameIndex = firstNameIndex;
        player.surnameIndex = surnameIndex;
    }

    function setPlayerAttributes(
        uint32 playerId,
        uint8 strength,
        uint8 constitution,
        uint8 size,
        uint8 agility,
        uint8 stamina,
        uint8 luck
    ) external hasPermission(IPlayer.GamePermission.ATTRIBUTES) {
        require(_players[playerId].strength != 0, "Player does not exist");

        // Create a temporary PlayerStats to validate
        PlayerStats memory newStats = PlayerStats({
            strength: strength,
            constitution: constitution,
            size: size,
            agility: agility,
            stamina: stamina,
            luck: luck,
            skinIndex: _players[playerId].skinIndex,
            skinTokenId: _players[playerId].skinTokenId,
            firstNameIndex: _players[playerId].firstNameIndex,
            surnameIndex: _players[playerId].surnameIndex,
            wins: _players[playerId].wins,
            losses: _players[playerId].losses,
            kills: _players[playerId].kills
        });

        require(_validateStats(newStats), "Invalid player stats");

        // If validation passes, update the player's attributes
        PlayerStats storage player = _players[playerId];
        player.strength = strength;
        player.constitution = constitution;
        player.size = size;
        player.agility = agility;
        player.stamina = stamina;
        player.luck = luck;
    }

    function isPlayerRetired(uint256 playerId) external view returns (bool) {
        return _retiredPlayers[playerId];
    }

    function retireOwnPlayer(uint32 playerId) external {
        // Check player exists and caller owns it
        require(_players[playerId].strength != 0, "Player does not exist");
        require(_ownerOf(uint256(playerId)) == msg.sender, "Not player owner");

        // Mark as retired
        _retiredPlayers[playerId] = true;

        emit PlayerRetired(uint256(playerId), msg.sender, true);
    }

    // For testing purposes only
    function setPlayerOwner(uint256 playerId, address owner) external onlyOwner {
        require(playerId >= 1000 || owner == address(0), "Cannot set owner for default characters");
        _playerOwners[playerId] = owner;
    }

    function encodePlayerData(uint32 playerId, PlayerStats memory stats) external pure returns (bytes32) {
        bytes memory packed = new bytes(32);

        // Pack playerId (4 bytes)
        packed[0] = bytes1(uint8(playerId >> 24));
        packed[1] = bytes1(uint8(playerId >> 16));
        packed[2] = bytes1(uint8(playerId >> 8));
        packed[3] = bytes1(uint8(playerId));

        // Pack uint8 stats (6 bytes)
        packed[4] = bytes1(stats.strength);
        packed[5] = bytes1(stats.constitution);
        packed[6] = bytes1(stats.size);
        packed[7] = bytes1(stats.agility);
        packed[8] = bytes1(stats.stamina);
        packed[9] = bytes1(stats.luck);

        // Pack skinIndex (4 bytes)
        packed[10] = bytes1(uint8(stats.skinIndex >> 24));
        packed[11] = bytes1(uint8(stats.skinIndex >> 16));
        packed[12] = bytes1(uint8(stats.skinIndex >> 8));
        packed[13] = bytes1(uint8(stats.skinIndex));

        // Pack uint16 values (14 bytes)
        packed[14] = bytes1(uint8(stats.skinTokenId >> 8));
        packed[15] = bytes1(uint8(stats.skinTokenId));

        packed[16] = bytes1(uint8(stats.firstNameIndex >> 8));
        packed[17] = bytes1(uint8(stats.firstNameIndex));

        packed[18] = bytes1(uint8(stats.surnameIndex >> 8));
        packed[19] = bytes1(uint8(stats.surnameIndex));

        packed[20] = bytes1(uint8(stats.wins >> 8));
        packed[21] = bytes1(uint8(stats.wins));

        packed[22] = bytes1(uint8(stats.losses >> 8));
        packed[23] = bytes1(uint8(stats.losses));

        packed[24] = bytes1(uint8(stats.kills >> 8));
        packed[25] = bytes1(uint8(stats.kills));

        // Last 6 bytes are padded with zeros by default

        return bytes32(packed);
    }

    function decodePlayerData(bytes32 data) external pure returns (uint32 playerId, PlayerStats memory stats) {
        bytes memory packed = new bytes(32);
        assembly {
            mstore(add(packed, 32), data)
        }

        // Decode playerId
        playerId = uint32(uint8(packed[0])) << 24 | uint32(uint8(packed[1])) << 16 | uint32(uint8(packed[2])) << 8
            | uint32(uint8(packed[3]));

        // Decode uint8 stats
        stats.strength = uint8(packed[4]);
        stats.constitution = uint8(packed[5]);
        stats.size = uint8(packed[6]);
        stats.agility = uint8(packed[7]);
        stats.stamina = uint8(packed[8]);
        stats.luck = uint8(packed[9]);

        // Decode skinIndex
        stats.skinIndex = uint32(uint8(packed[10])) << 24 | uint32(uint8(packed[11])) << 16
            | uint32(uint8(packed[12])) << 8 | uint32(uint8(packed[13]));

        // Decode uint16 values
        stats.skinTokenId = uint16(uint8(packed[14])) << 8 | uint16(uint8(packed[15]));
        stats.firstNameIndex = uint16(uint8(packed[16])) << 8 | uint16(uint8(packed[17]));
        stats.surnameIndex = uint16(uint8(packed[18])) << 8 | uint16(uint8(packed[19]));
        stats.wins = uint16(uint8(packed[20])) << 8 | uint16(uint8(packed[21]));
        stats.losses = uint16(uint8(packed[22])) << 8 | uint16(uint8(packed[23]));
        stats.kills = uint16(uint8(packed[24])) << 8 | uint16(uint8(packed[25]));

        return (playerId, stats);
    }
}

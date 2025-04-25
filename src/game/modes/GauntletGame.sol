// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import "./BaseGame.sol";
import "solmate/src/utils/ReentrancyGuard.sol";
import "solmate/src/utils/SafeTransferLib.sol";
import "vrf-contracts/contracts/GelatoVRFConsumerBase.sol";
import "../../lib/UniformRandomNumber.sol";
import "../../interfaces/game/engine/IGameEngine.sol";
import "../../interfaces/fighters/IPlayer.sol";
import "../../interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";
import "../../interfaces/nft/skins/IPlayerSkinNFT.sol";
import "../../fighters/Fighter.sol";
import "../../interfaces/fighters/IDefaultPlayer.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
error GauntletDoesNotExist();
error PlayerNotInQueue();
error QueueFull();
error AlreadyInQueue();
error PlayerIsRetired();
error InvalidLoadout();
error InvalidSkin();
error CallerNotPlayerOwner();
error GauntletNotPending();
error GauntletNotCompletable();
error InvalidStateForAction();
error GameDisabled();
error NotOffChainRunner();
error InsufficientQueueLength();
error InvalidPlayerSelection();
error InvalidQueueIndex();
error InvalidGauntletSize(uint8 size);
error QueueNotEmpty();
error IncorrectEntryFee(uint256 expected, uint256 actual);
error InvalidDefaultPlayerRange();

//==============================================================//
//                         HEAVY HELMS                          //
//                         GAUNTLET GAME                        //
//==============================================================//
/// @title Gauntlet Game Mode for Heavy Helms
/// @notice Manages a queue of players and triggers elimination brackets (Gauntlets)
///         of dynamic size (8, 16, or 32) with a dynamic entry fee.
/// @dev Relies on a trusted off-chain runner. VRF fulfillment is still gas-intensive.
contract GauntletGame is BaseGame, ReentrancyGuard, GelatoVRFConsumerBase {
    using UniformRandomNumber for uint256;
    using SafeTransferLib for address;

    //==============================================================//
    //                         CONSTANTS                            //
    //==============================================================//

    //==============================================================//
    //                          ENUMS                               //
    //==============================================================//
    enum GauntletState {
        PENDING,
        COMPLETED
    }

    enum PlayerStatus {
        NONE,
        QUEUED,
        IN_GAUNTLET
    }

    //==============================================================//
    //                         STRUCTS                              //
    //==============================================================//
    /// @notice Stores loadout data for a player in the queue or active gauntlet
    struct PlayerQueueData {
        Fighter.PlayerLoadout loadout;
    }

    /// @notice Structure storing data for a specific Gauntlet run instance
    struct Gauntlet {
        uint256 id;
        uint8 size;
        uint256 entryFee;
        GauntletState state;
        uint256 vrfRequestId;
        uint256 vrfRequestTimestamp;
        uint256 completionTimestamp;
        RegisteredPlayer[] participants;
        uint32[] winners;
        uint32 championId;
    }

    /// @notice Compact struct storing participant data for a specific Gauntlet run
    struct RegisteredPlayer {
        uint32 playerId;
        Fighter.PlayerLoadout loadout;
    }

    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    address public offChainRunner;
    IDefaultPlayer public defaultPlayerContract;

    /// @notice Gelato VRF Operator address
    address private _operatorAddress;
    /// @notice Timeout for VRF requests
    uint256 public vrfRequestTimeout = 4 hours;

    /// @notice Next Gauntlet ID to be assigned
    uint256 public nextGauntletId;
    /// @notice Maps Gauntlet IDs to Gauntlet run data
    mapping(uint256 => Gauntlet) public gauntlets;

    // --- Queue State ---
    /// @notice Stores loadout data for players waiting in the queue
    mapping(uint32 => PlayerQueueData) public registrationQueue;
    /// @notice Array containing the IDs of players currently in the queue (order matters for swap-and-pop)
    uint32[] public queueIndex;
    /// @notice Maps player IDs to their current index within the queueIndex array for O(1) lookup during removal/withdrawal
    mapping(uint32 => uint256) public playerIndexInQueue;

    /// @notice Tracks the current status of a player (None, Queued, In_Gauntlet)
    mapping(uint32 => PlayerStatus) public playerStatus;
    /// @notice If status is IN_GAUNTLET, maps player ID to the gauntlet ID they are in
    mapping(uint32 => uint256) public playerCurrentGauntlet;

    /// @notice Maps VRF request IDs to Gauntlet IDs
    mapping(uint256 => uint256) public requestToGauntletId;

    /// @notice Holds entry fees paid by players in the queue
    uint256 public queuedFeesPool;
    /// @notice Fees collected by the contract owner from completed gauntlets
    uint256 public contractFeesCollected;
    /// @notice Percentage fee taken from the prize pool of each gauntlet
    uint256 public feePercentage = 1000;

    /// @notice Game enabled state (controls queuing)
    bool public isGameEnabled = true;

    // --- Dynamic Settings ---
    uint256 public currentEntryFee = 0.0005 ether;
    uint8 public currentGauntletSize = 8;

    /// @notice The maximum ID to use when randomly selecting a default player substitute. Must be kept in sync with DefaultPlayer contract.
    uint32 public maxDefaultPlayerSubstituteId = 15;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    event PlayerQueued(uint32 indexed playerId, uint256 queueSize, uint256 entryFee);
    event PlayerWithdrew(uint32 indexed playerId, uint256 queueSize);
    event GauntletStarted(
        uint256 indexed gauntletId, uint8 size, uint256 entryFee, uint32[] participantIds, uint256 vrfRequestId
    );
    event GauntletCompleted(
        uint256 indexed gauntletId,
        uint8 size,
        uint256 entryFee,
        uint32 indexed championId,
        uint256 prizeAwarded,
        uint256 feeCollected
    );
    event GauntletRecovered(uint256 indexed gauntletId);
    event FeesWithdrawn(uint256 amount);
    event OffChainRunnerSet(address indexed newRunner);
    event DefaultPlayerContractSet(address indexed newContract);
    event EntryFeeSet(uint256 oldFee, uint256 newFee);
    event GauntletSizeSet(uint8 oldSize, uint8 newSize);
    event QueueClearedDueToSettingsChange(uint256 playersRefunded, uint256 totalRefunded);
    event MaxDefaultPlayerSubstituteIdSet(uint32 newMaxId);

    //==============================================================//
    //                        MODIFIERS                             //
    //==============================================================//
    modifier whenGameEnabled() {
        if (!isGameEnabled) revert GameDisabled();
        _;
    }

    modifier onlyOffChainRunnerCheck() {
        if (msg.sender != offChainRunner) revert NotOffChainRunner();
        _;
    }

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    constructor(
        address _gameEngine,
        address _playerContract,
        address _defaultPlayerAddress,
        address _operatorAddr,
        address _initialRunner
    ) BaseGame(_gameEngine, _playerContract) GelatoVRFConsumerBase() {
        if (_operatorAddr == address(0) || _initialRunner == address(0) || _defaultPlayerAddress == address(0)) {
            revert ZeroAddress();
        }
        defaultPlayerContract = IDefaultPlayer(_defaultPlayerAddress);
        _operatorAddress = _operatorAddr;
        offChainRunner = _initialRunner;
    }

    //==============================================================//
    //                 GELATO VRF CONFIGURATION                     //
    //==============================================================//
    function _operator() internal view override returns (address) {
        return _operatorAddress;
    }

    //==============================================================//
    //                       QUEUE MANAGEMENT                       //
    //==============================================================//

    /// @notice Allows a player to join the Gauntlet queue
    /// @param loadout The player's chosen skin and stance for the gauntlet
    function queueForGauntlet(Fighter.PlayerLoadout calldata loadout) external payable whenGameEnabled nonReentrant {
        if (playerStatus[loadout.playerId] != PlayerStatus.NONE) revert AlreadyInQueue();
        address owner = playerContract.getPlayerOwner(loadout.playerId);
        if (msg.sender != owner) revert CallerNotPlayerOwner();
        if (playerContract.isPlayerRetired(loadout.playerId)) revert PlayerIsRetired();

        try playerContract.skinRegistry().validateSkinOwnership(loadout.skin, owner) {}
        catch {
            revert InvalidSkin();
        }
        try playerContract.skinRegistry().validateSkinRequirements(
            loadout.skin, playerContract.getPlayer(loadout.playerId).attributes, playerContract.equipmentRequirements()
        ) {} catch {
            revert InvalidLoadout();
        }

        if (msg.value != currentEntryFee) revert IncorrectEntryFee(currentEntryFee, msg.value);
        queuedFeesPool += msg.value;

        uint32 playerId = loadout.playerId;
        registrationQueue[playerId] = PlayerQueueData({loadout: loadout});
        queueIndex.push(playerId);
        playerIndexInQueue[playerId] = queueIndex.length;
        playerStatus[playerId] = PlayerStatus.QUEUED;

        emit PlayerQueued(playerId, queueIndex.length, currentEntryFee);
    }

    /// @notice Allows a player to withdraw from the queue before being selected
    /// @param playerId The ID of the player to withdraw
    function withdrawFromQueue(uint32 playerId) external nonReentrant {
        // Check ownership first
        address owner = playerContract.getPlayerOwner(playerId);
        if (msg.sender != owner) revert CallerNotPlayerOwner();

        // Now check status
        if (playerStatus[playerId] != PlayerStatus.QUEUED) revert PlayerNotInQueue();

        queuedFeesPool -= currentEntryFee;
        SafeTransferLib.safeTransferETH(payable(msg.sender), currentEntryFee); // Send to msg.sender (owner)

        _removePlayerFromQueueArrayIndex(playerId);

        delete registrationQueue[playerId];
        playerStatus[playerId] = PlayerStatus.NONE;

        emit PlayerWithdrew(playerId, queueIndex.length);
    }

    /// @notice Returns the current number of players in the queue
    function getQueueSize() external view returns (uint256) {
        return queueIndex.length;
    }

    //==============================================================//
    //                 GAUNTLET LIFECYCLE (Runner Triggered)        //
    //==============================================================//

    /// @notice Starts a new Gauntlet run using players selected from the queue.
    /// @dev Callable only by the trusted offChainRunner.
    /// @param selectedPlayerIds The exact 16 player IDs chosen by the runner.
    /// @param selectedPlayerIndices The current indices of these 16 players in the queueIndex array.
    function startGauntletFromQueue(uint32[] calldata selectedPlayerIds, uint256[] calldata selectedPlayerIndices)
        external
        onlyOffChainRunnerCheck
        nonReentrant
    {
        uint8 size = currentGauntletSize;
        uint256 fee = currentEntryFee;

        if (queueIndex.length < size) revert InsufficientQueueLength();
        if (selectedPlayerIds.length != size) revert InvalidPlayerSelection();
        if (selectedPlayerIndices.length != size) revert InvalidPlayerSelection();

        uint256 gauntletId = nextGauntletId++;
        Gauntlet storage newGauntlet = gauntlets[gauntletId];
        newGauntlet.id = gauntletId;
        newGauntlet.size = size;
        newGauntlet.entryFee = fee;
        newGauntlet.state = GauntletState.PENDING;
        newGauntlet.participants = new RegisteredPlayer[](size);

        RegisteredPlayer[] memory participantsData = new RegisteredPlayer[](size);

        for (uint256 i = size; i > 0; i--) {
            uint256 indexInSelection = i - 1;
            uint32 playerId = selectedPlayerIds[indexInSelection];
            uint256 playerArrayIndex = selectedPlayerIndices[indexInSelection];

            if (playerArrayIndex >= queueIndex.length) revert InvalidQueueIndex();
            if (queueIndex[playerArrayIndex] != playerId) revert InvalidPlayerSelection();
            if (playerStatus[playerId] != PlayerStatus.QUEUED) revert InvalidPlayerSelection();

            PlayerQueueData storage queueData = registrationQueue[playerId];
            participantsData[indexInSelection] = RegisteredPlayer({playerId: playerId, loadout: queueData.loadout});

            _removePlayerFromQueueArrayIndexWithIndex(playerId, playerArrayIndex);

            delete registrationQueue[playerId];
            playerStatus[playerId] = PlayerStatus.IN_GAUNTLET;
            playerCurrentGauntlet[playerId] = gauntletId;
        }

        for (uint256 i = 0; i < size; i++) {
            newGauntlet.participants[i] = participantsData[i];
        }

        newGauntlet.vrfRequestTimestamp = block.timestamp;
        uint256 requestId = _requestRandomness("");
        requestToGauntletId[requestId] = gauntletId;
        newGauntlet.vrfRequestId = requestId;

        emit GauntletStarted(gauntletId, size, fee, selectedPlayerIds, requestId);
    }

    //==============================================================//
    //                    VRF FULFILLMENT                         //
    //==============================================================//
    function _fulfillRandomness(uint256 randomness, uint256 requestId, bytes memory /* extraData */ )
        internal
        override
    {
        uint256 gauntletId = requestToGauntletId[requestId];
        Gauntlet storage gauntlet = gauntlets[gauntletId];
        if (gauntlet.state != GauntletState.PENDING) {
            delete requestToGauntletId[requestId];
            return;
        }

        delete requestToGauntletId[requestId];

        uint8 size = gauntlet.size;
        uint256 entryFee = gauntlet.entryFee;

        RegisteredPlayer[] storage initialParticipants = gauntlet.participants;
        uint32[] memory activeParticipants = new uint32[](size);
        IGameEngine.FighterStats[] memory participantStats = new IGameEngine.FighterStats[](size);
        bytes32[] memory participantEncodedData = new bytes32[](size);

        // Use the configurable max ID
        uint32 currentMaxDefaultId = maxDefaultPlayerSubstituteId;
        // Ensure max ID is at least 1 to avoid modulo by zero if owner sets it incorrectly lower
        if (currentMaxDefaultId == 0) {
            currentMaxDefaultId = 1;
        }

        for (uint256 i = 0; i < size; i++) {
            RegisteredPlayer storage regPlayer = initialParticipants[i];
            if (playerContract.isPlayerRetired(regPlayer.playerId)) {
                // Generate a pseudo-random index based on VRF randomness and loop index
                uint256 derivedRand = uint256(keccak256(abi.encodePacked(randomness, i)));
                // Select a random default ID within the configured range [1, maxDefaultPlayerSubstituteId]
                uint32 defaultId = uint32(derivedRand % currentMaxDefaultId) + 1; // +1 to shift range

                activeParticipants[i] = defaultId; // Assign the randomly selected substitute ID

                // Fetch stats for the EXISTING substitute default player
                IPlayer.PlayerStats memory defaultStats = defaultPlayerContract.getDefaultPlayer(defaultId);

                // Prepare stats and data for game engine (same as before)
                IPlayerSkinRegistry.SkinCollectionInfo memory skinInfo =
                    playerContract.skinRegistry().getSkin(defaultStats.skin.skinIndex);
                IPlayerSkinNFT.SkinAttributes memory skinAttrs =
                    IPlayerSkinNFT(skinInfo.contractAddress).getSkinAttributes(defaultStats.skin.skinTokenId);

                participantStats[i] = IGameEngine.FighterStats({
                    weapon: skinAttrs.weapon,
                    armor: skinAttrs.armor,
                    stance: defaultStats.stance,
                    attributes: defaultStats.attributes
                });
                participantEncodedData[i] = bytes32(uint256(defaultId));
            } else {
                // Existing logic for non-retired players
                activeParticipants[i] = regPlayer.playerId;
                (participantStats[i], participantEncodedData[i]) =
                    _getFighterCombatStats(regPlayer.playerId, regPlayer.loadout);
            }
        }

        uint32[] memory shuffledParticipantIds = new uint32[](size);
        IGameEngine.FighterStats[] memory shuffledParticipantStats = new IGameEngine.FighterStats[](size);
        bytes32[] memory shuffledParticipantData = new bytes32[](size);

        uint256 shuffleRand = randomness;
        bool[] memory picked = new bool[](size);
        uint256 count = 0;
        while (count < size) {
            shuffleRand = uint256(keccak256(abi.encodePacked(shuffleRand, count)));
            uint256 k = shuffleRand % size;
            if (!picked[k]) {
                shuffledParticipantIds[count] = activeParticipants[k];
                shuffledParticipantStats[count] = participantStats[k];
                shuffledParticipantData[count] = participantEncodedData[k];
                picked[k] = true;
                count++;
            }
        }

        uint32[] memory currentRoundIds = shuffledParticipantIds;
        IGameEngine.FighterStats[] memory currentRoundStats = shuffledParticipantStats;
        bytes32[] memory currentRoundData = shuffledParticipantData;

        uint32[] memory nextRoundIds;
        IGameEngine.FighterStats[] memory nextRoundStats;
        bytes32[] memory nextRoundData;

        uint256 fightSeedBase = uint256(keccak256(abi.encodePacked(randomness, requestId)));
        gauntlet.winners = new uint32[](size - 1);
        uint256 winnerIndex = 0;

        // Determine rounds based on the validated size
        uint8 rounds;
        if (size == 8) {
            rounds = 3;
        } else if (size == 16) {
            rounds = 4;
        } else {
            // size == 32 (guaranteed by setGauntletSize)
            rounds = 5;
        }

        for (uint256 roundIndex = 0; roundIndex < rounds; roundIndex++) {
            uint256 currentRoundSize = currentRoundIds.length;
            uint256 nextRoundSize = currentRoundSize / 2;
            nextRoundIds = new uint32[](nextRoundSize);
            nextRoundStats = new IGameEngine.FighterStats[](nextRoundSize);
            nextRoundData = new bytes32[](nextRoundSize);

            for (uint256 fightIndex = 0; fightIndex < currentRoundSize; fightIndex += 2) {
                uint32 p1Id = currentRoundIds[fightIndex];
                uint32 p2Id = currentRoundIds[fightIndex + 1];
                IGameEngine.FighterStats memory fighter1Stats = currentRoundStats[fightIndex];
                IGameEngine.FighterStats memory fighter2Stats = currentRoundStats[fightIndex + 1];
                bytes32 p1Data = currentRoundData[fightIndex];
                bytes32 p2Data = currentRoundData[fightIndex + 1];

                uint256 fightSeed = uint256(keccak256(abi.encodePacked(fightSeedBase, roundIndex, fightIndex)));

                bytes memory results = gameEngine.processGame(fighter1Stats, fighter2Stats, fightSeed, 0);
                (bool p1Won,,,) = gameEngine.decodeCombatLog(results);

                uint32 winnerId;
                uint32 loserId;
                uint256 nextRoundArrayIndex = fightIndex / 2;

                if (p1Won) {
                    winnerId = p1Id;
                    loserId = p2Id;
                    nextRoundIds[nextRoundArrayIndex] = p1Id;
                    nextRoundStats[nextRoundArrayIndex] = fighter1Stats;
                    nextRoundData[nextRoundArrayIndex] = p1Data;
                } else {
                    winnerId = p2Id;
                    loserId = p1Id;
                    nextRoundIds[nextRoundArrayIndex] = p2Id;
                    nextRoundStats[nextRoundArrayIndex] = fighter2Stats;
                    nextRoundData[nextRoundArrayIndex] = p2Data;
                }

                if (winnerIndex < size - 1) {
                    gauntlet.winners[winnerIndex++] = winnerId;
                }
                emit CombatResult(p1Data, p2Data, winnerId, results);

                if (_getFighterType(winnerId) == Fighter.FighterType.PLAYER) playerContract.incrementWins(winnerId);
                if (_getFighterType(loserId) == Fighter.FighterType.PLAYER) playerContract.incrementLosses(loserId);
            }
            currentRoundIds = nextRoundIds;
            currentRoundStats = nextRoundStats;
            currentRoundData = nextRoundData;
        }

        uint32 finalWinnerId = currentRoundIds[0];
        gauntlet.championId = finalWinnerId;
        gauntlet.completionTimestamp = block.timestamp;
        gauntlet.state = GauntletState.COMPLETED;

        uint256 prizePool = entryFee * size;
        uint256 feeAmount = (prizePool * feePercentage) / 10000;
        uint256 winnerPayout = prizePool - feeAmount;

        contractFeesCollected += feeAmount;

        for (uint256 i = 0; i < size; i++) {
            uint32 pId = initialParticipants[i].playerId;
            if (playerStatus[pId] == PlayerStatus.IN_GAUNTLET && playerCurrentGauntlet[pId] == gauntletId) {
                playerStatus[pId] = PlayerStatus.NONE;
                delete playerCurrentGauntlet[pId];
            }
        }

        if (winnerPayout > 0) {
            Fighter.FighterType winnerType = _getFighterType(finalWinnerId);
            if (winnerType == Fighter.FighterType.DEFAULT_PLAYER) {
                contractFeesCollected += winnerPayout;
            } else if (winnerType == Fighter.FighterType.PLAYER) {
                address payable winnerOwner = payable(playerContract.getPlayerOwner(finalWinnerId));
                SafeTransferLib.safeTransferETH(winnerOwner, winnerPayout);
            }
        }

        emit GauntletCompleted(gauntletId, size, entryFee, finalWinnerId, winnerPayout, feeAmount);
    }

    //==============================================================//
    //                  HELPER & VIEW FUNCTIONS                     //
    //==============================================================//

    function _removePlayerFromQueueArrayIndex(uint32 playerId) internal {
        uint256 indexToRemove = playerIndexInQueue[playerId] - 1;
        _removePlayerFromQueueArrayIndexWithIndex(playerId, indexToRemove);
    }

    function _removePlayerFromQueueArrayIndexWithIndex(uint32 playerIdToRemove, uint256 indexToRemove) internal {
        uint256 lastIndex = queueIndex.length - 1;
        if (indexToRemove != lastIndex) {
            uint32 playerToMove = queueIndex[lastIndex];
            queueIndex[indexToRemove] = playerToMove;
            playerIndexInQueue[playerToMove] = indexToRemove + 1;
        }
        delete playerIndexInQueue[playerIdToRemove];
        queueIndex.pop();
    }

    function _getFighterCombatStats(uint32 playerId, Fighter.PlayerLoadout memory loadout)
        internal
        view
        returns (IGameEngine.FighterStats memory stats, bytes32 encodedData)
    {
        Fighter.FighterType fighterType = _getFighterType(playerId);
        if (fighterType != Fighter.FighterType.PLAYER) {
            revert("Invalid fighter type for stats lookup");
        }

        IPlayer.PlayerStats memory pStats = playerContract.getPlayer(playerId);
        pStats.skin = loadout.skin;
        pStats.stance = loadout.stance;
        IPlayerSkinRegistry.SkinCollectionInfo memory skinInfo =
            playerContract.skinRegistry().getSkin(pStats.skin.skinIndex);
        IPlayerSkinNFT.SkinAttributes memory skinAttrs =
            IPlayerSkinNFT(skinInfo.contractAddress).getSkinAttributes(pStats.skin.skinTokenId);
        stats = IGameEngine.FighterStats({
            weapon: skinAttrs.weapon,
            armor: skinAttrs.armor,
            stance: pStats.stance,
            attributes: pStats.attributes
        });
        encodedData = playerContract.encodePlayerData(playerId, pStats);
    }

    /// @notice Returns the full data for a specific Gauntlet.
    function getGauntletData(uint256 gauntletId) external view returns (Gauntlet memory) {
        if (gauntlets[gauntletId].id != gauntletId && gauntletId != 0) revert GauntletDoesNotExist(); // Add basic check
        return gauntlets[gauntletId];
    }

    //==============================================================//
    //                     ADMIN FUNCTIONS                          //
    //==============================================================//
    function setOffChainRunner(address newRunner) external onlyOwner {
        if (newRunner == address(0)) revert ZeroAddress();
        offChainRunner = newRunner;
        emit OffChainRunnerSet(newRunner);
    }

    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = contractFeesCollected;
        if (amount == 0) revert("No fees to withdraw");
        contractFeesCollected = 0;
        SafeTransferLib.safeTransferETH(payable(owner), amount);
        emit FeesWithdrawn(amount);
    }

    function setGameEnabled(bool enabled) external onlyOwner {
        isGameEnabled = enabled;
    }

    function recoverTimedOutVRF(uint256 gauntletId) external nonReentrant {
        Gauntlet storage gauntlet = gauntlets[gauntletId];
        if (gauntlet.state != GauntletState.PENDING) revert GauntletNotPending();
        if (block.timestamp < gauntlet.vrfRequestTimestamp + vrfRequestTimeout) revert("Timeout not reached");

        // Mark gauntlet as completed/aborted
        gauntlet.state = GauntletState.COMPLETED;
        gauntlet.completionTimestamp = block.timestamp;

        RegisteredPlayer[] storage participants = gauntlet.participants;
        uint8 size = gauntlet.size;
        uint256 entryFee = gauntlet.entryFee;

        for (uint256 i = 0; i < size; i++) {
            uint32 pId = participants[i].playerId;

            // Check if the player needs state cleanup (was actually stuck in this gauntlet)
            if (playerStatus[pId] == PlayerStatus.IN_GAUNTLET && playerCurrentGauntlet[pId] == gauntletId) {
                // Only refund actual players, not default placeholders
                if (_getFighterType(pId) == Fighter.FighterType.PLAYER) {
                    address owner = playerContract.getPlayerOwner(pId);
                    SafeTransferLib.safeTransferETH(payable(owner), entryFee);
                }

                playerStatus[pId] = PlayerStatus.NONE;
                delete playerCurrentGauntlet[pId];
            }
        }

        // Clean up the VRF request ID mapping
        if (gauntlet.vrfRequestId != 0) {
            delete requestToGauntletId[gauntlet.vrfRequestId];
        }

        emit GauntletRecovered(gauntletId);
    }

    function setDefaultPlayerContract(address newAddress) external onlyOwner {
        if (newAddress == address(0)) revert ZeroAddress();
        defaultPlayerContract = IDefaultPlayer(newAddress);
        emit DefaultPlayerContractSet(newAddress);
    }

    /// @notice Sets the entry fee for joining the queue.
    /// @dev Allows bypassing queue clearing and refunds to prevent potential gas limit issues with large queues.
    /// @param newFee The new entry fee in wei.
    /// @param refundPlayers If true and skipReset is false, clears the queue and refunds players the *old* fee.
    /// @param skipReset If true, bypasses all queue clearing and refund logic, only setting the new fee.
    function setEntryFee(uint256 newFee, bool refundPlayers, bool skipReset) external onlyOwner nonReentrant {
        uint256 oldFee = currentEntryFee;
        if (oldFee == newFee) return; // No change needed

        emit EntryFeeSet(oldFee, newFee);

        if (skipReset) {
            // Only set the fee, skip everything else
            currentEntryFee = newFee;
            return;
        }

        // --- Proceed only if skipReset is false ---

        if (refundPlayers) {
            // --- Clear queue and refund logic (only if refundPlayers is true) ---
            uint256 playersRefunded = 0;
            uint256 totalRefunded = 0;
            uint256 queueLength = queueIndex.length;

            // Iterate backwards to handle pop correctly
            for (uint256 i = queueLength; i > 0; i--) {
                uint256 indexToRemove = i - 1;
                uint32 playerId = queueIndex[indexToRemove];

                // Check if the player is actually in QUEUED status before refunding/clearing state
                if (playerStatus[playerId] == PlayerStatus.QUEUED) {
                    address owner = playerContract.getPlayerOwner(playerId);
                    uint256 refundAmount = oldFee; // Refund the fee they originally paid
                    SafeTransferLib.safeTransferETH(payable(owner), refundAmount);
                    totalRefunded += refundAmount;

                    // Clear player state *only* if they were refunded
                    delete registrationQueue[playerId];
                    playerStatus[playerId] = PlayerStatus.NONE;
                    delete playerIndexInQueue[playerId]; // Ensure mapping is cleared

                    playersRefunded++;
                }
                // Always remove from the index array regardless of status,
                // as the index itself might be invalid if queue length changed drastically.
                // This requires careful handling of the swap-and-pop within the loop.
                // A simpler approach is to just pop, but we need the player ID first.

                // Perform swap-and-pop within the loop carefully
                uint256 lastIdx = queueIndex.length - 1; // Get current last index *inside* loop
                if (indexToRemove != lastIdx) {
                    // If we are not removing the last element already
                    uint32 playerToMove = queueIndex[lastIdx];
                    queueIndex[indexToRemove] = playerToMove;
                    // Update the index mapping for the moved player
                    // Only update if the player being moved has an entry (wasn't already processed/deleted)
                    if (playerIndexInQueue[playerToMove] != 0) {
                        playerIndexInQueue[playerToMove] = indexToRemove + 1;
                    }
                }
                // Always pop the last element
                queueIndex.pop();
                // Clear the mapping for the player *actually* removed in this iteration (playerId)
                // This was moved up into the refund block to only clear if refunded
            }

            // Adjust fee pool
            if (queuedFeesPool < totalRefunded) {
                // Should not happen with correct accounting, but safe guard
                queuedFeesPool = 0;
            } else {
                queuedFeesPool -= totalRefunded;
            }

            if (playersRefunded > 0) {
                emit QueueClearedDueToSettingsChange(playersRefunded, totalRefunded);
            }
        }
        // --- End of refundPlayers block ---

        // Set the new fee regardless of whether refunds happened (if skipReset was false)
        currentEntryFee = newFee;
    }

    /// @notice Sets the number of participants required to start a gauntlet.
    /// @dev Can only be changed when the queue is empty to simplify logic.
    /// @param newSize The new gauntlet size (must be 8, 16, or 32).
    function setGauntletSize(uint8 newSize) external onlyOwner {
        if (newSize != 8 && newSize != 16 && newSize != 32) {
            revert InvalidGauntletSize(newSize);
        }
        if (queueIndex.length > 0) {
            revert QueueNotEmpty();
        }

        uint8 oldSize = currentGauntletSize;
        if (oldSize == newSize) return;

        currentGauntletSize = newSize;
        emit GauntletSizeSet(oldSize, newSize);
    }

    /// @notice Sets the maximum ID to use for default player substitutions.
    /// @dev Owner must ensure this ID corresponds to an existing player in DefaultPlayer contract.
    ///      Must be within the valid range [1, 2000].
    /// @param _maxId The highest default player ID to consider for substitution.
    function setMaxDefaultPlayerSubstituteId(uint32 _maxId) external onlyOwner {
        // Validate against the absolute range defined in DefaultPlayer
        if (_maxId < 1 || _maxId > 2000) {
            revert InvalidDefaultPlayerRange(); // Reuse existing error
        }
        maxDefaultPlayerSubstituteId = _maxId;
        emit MaxDefaultPlayerSubstituteIdSet(_maxId);
    }

    //==============================================================//
    //             BASEGAME ABSTRACT IMPLEMENTATIONS                //
    //==============================================================//
    function _isPlayerIdSupported(uint32 playerId) internal pure override returns (bool) {
        Fighter.FighterType fighterType = _getFighterType(playerId);
        return fighterType == Fighter.FighterType.PLAYER || fighterType == Fighter.FighterType.DEFAULT_PLAYER;
    }

    function _getFighterContract(uint32 playerId) internal view override returns (Fighter) {
        Fighter.FighterType fighterType = _getFighterType(playerId);
        if (fighterType == Fighter.FighterType.PLAYER || fighterType == Fighter.FighterType.DEFAULT_PLAYER) {
            return Fighter(address(playerContract));
        } else {
            revert("Unsupported player ID for Gauntlet mode");
        }
    }

    //==============================================================//
    //                    FALLBACK FUNCTIONS                        //
    //==============================================================//
}

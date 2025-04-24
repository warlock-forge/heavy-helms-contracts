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

//==============================================================//
//                         HEAVY HELMS                          //
//                         GAUNTLET GAME                        //
//==============================================================//
/// @title Gauntlet Game Mode for Heavy Helms
/// @notice Manages a queue of players and triggers 16-player elimination brackets (Gauntlets)
///         when the queue is sufficiently full, initiated by an off-chain runner.
/// @dev Relies on a trusted off-chain runner. VRF fulfillment is still gas-intensive.
contract GauntletGame is BaseGame, ReentrancyGuard, GelatoVRFConsumerBase {
    using UniformRandomNumber for uint256;
    using SafeTransferLib for address;

    //==============================================================//
    //                         CONSTANTS                            //
    //==============================================================//
    uint8 public constant GAUNTLET_SIZE = 16;
    uint256 public constant ENTRY_FEE = 0.001 ether;
    uint32 internal constant DEFAULT_PLAYER_START_ID = 1;

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

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    event PlayerQueued(uint32 indexed playerId, uint256 queueSize);
    event PlayerWithdrew(uint32 indexed playerId, uint256 queueSize);
    event GauntletStarted(uint256 indexed gauntletId, uint32[GAUNTLET_SIZE] participantIds, uint256 vrfRequestId);
    event GauntletCompleted(
        uint256 indexed gauntletId, uint32 indexed championId, uint256 prizeAwarded, uint256 feeCollected
    );
    event GauntletRecovered(uint256 indexed gauntletId);
    event FeesWithdrawn(uint256 amount);
    event OffChainRunnerSet(address indexed newRunner);
    event DefaultPlayerContractSet(address indexed newContract);

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

        if (msg.value != ENTRY_FEE) revert("Incorrect entry fee");
        queuedFeesPool += msg.value;

        uint32 playerId = loadout.playerId;
        registrationQueue[playerId] = PlayerQueueData({loadout: loadout});
        queueIndex.push(playerId);
        playerIndexInQueue[playerId] = queueIndex.length;
        playerStatus[playerId] = PlayerStatus.QUEUED;

        emit PlayerQueued(playerId, queueIndex.length);
    }

    /// @notice Allows a player to withdraw from the queue before being selected
    /// @param playerId The ID of the player to withdraw
    function withdrawFromQueue(uint32 playerId) external nonReentrant {
        // Check ownership first
        address owner = playerContract.getPlayerOwner(playerId);
        if (msg.sender != owner) revert CallerNotPlayerOwner();

        // Now check status
        if (playerStatus[playerId] != PlayerStatus.QUEUED) revert PlayerNotInQueue();

        queuedFeesPool -= ENTRY_FEE;
        SafeTransferLib.safeTransferETH(payable(msg.sender), ENTRY_FEE); // Send to msg.sender (owner)

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
    function startGauntletFromQueue(
        uint32[GAUNTLET_SIZE] calldata selectedPlayerIds,
        uint256[GAUNTLET_SIZE] calldata selectedPlayerIndices
    ) external onlyOffChainRunnerCheck nonReentrant {
        if (queueIndex.length < GAUNTLET_SIZE) revert InsufficientQueueLength();

        uint256 gauntletId = nextGauntletId++;
        Gauntlet storage newGauntlet = gauntlets[gauntletId];
        newGauntlet.id = gauntletId;
        newGauntlet.state = GauntletState.PENDING;
        newGauntlet.participants = new RegisteredPlayer[](GAUNTLET_SIZE);

        RegisteredPlayer[GAUNTLET_SIZE] memory participantsData;

        for (uint256 i = GAUNTLET_SIZE; i > 0; i--) {
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

        for (uint256 i = 0; i < GAUNTLET_SIZE; i++) {
            newGauntlet.participants[i] = participantsData[i];
        }

        newGauntlet.vrfRequestTimestamp = block.timestamp;
        uint256 requestId = _requestRandomness("");
        requestToGauntletId[requestId] = gauntletId;
        newGauntlet.vrfRequestId = requestId;

        emit GauntletStarted(gauntletId, selectedPlayerIds, requestId);
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

        RegisteredPlayer[] storage initialParticipants = gauntlet.participants;
        uint32[] memory activeParticipants = new uint32[](GAUNTLET_SIZE);
        IGameEngine.FighterStats[] memory participantStats = new IGameEngine.FighterStats[](GAUNTLET_SIZE);
        bytes32[] memory participantEncodedData = new bytes32[](GAUNTLET_SIZE);
        uint32 defaultPlayerCounter = 0;

        for (uint256 i = 0; i < GAUNTLET_SIZE; i++) {
            RegisteredPlayer storage regPlayer = initialParticipants[i];
            if (playerContract.isPlayerRetired(regPlayer.playerId)) {
                uint32 defaultId = DEFAULT_PLAYER_START_ID + defaultPlayerCounter++;
                activeParticipants[i] = defaultId;

                IPlayer.PlayerStats memory defaultStats = defaultPlayerContract.getDefaultPlayer(defaultId);

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
                activeParticipants[i] = regPlayer.playerId;
                (participantStats[i], participantEncodedData[i]) =
                    _getFighterCombatStats(regPlayer.playerId, regPlayer.loadout);
            }
        }

        uint32[] memory shuffledParticipantIds = new uint32[](GAUNTLET_SIZE);
        IGameEngine.FighterStats[] memory shuffledParticipantStats = new IGameEngine.FighterStats[](GAUNTLET_SIZE);
        bytes32[] memory shuffledParticipantData = new bytes32[](GAUNTLET_SIZE);

        uint256 shuffleRand = randomness;
        bool[] memory picked = new bool[](GAUNTLET_SIZE);
        uint256 count = 0;
        while (count < GAUNTLET_SIZE) {
            shuffleRand = uint256(keccak256(abi.encodePacked(shuffleRand, count)));
            uint256 k = shuffleRand % GAUNTLET_SIZE;
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
        gauntlet.winners = new uint32[](15);
        uint256 winnerIndex = 0;

        for (uint256 roundIndex = 0; roundIndex < 4; roundIndex++) {
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

                if (winnerIndex < 15) {
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

        uint256 prizePool = ENTRY_FEE * GAUNTLET_SIZE;
        uint256 feeAmount = (prizePool * feePercentage) / 10000;
        uint256 winnerPayout = prizePool - feeAmount;

        contractFeesCollected += feeAmount;

        for (uint256 i = 0; i < initialParticipants.length; i++) {
            uint32 pId = initialParticipants[i].playerId;
            if (playerStatus[pId] == PlayerStatus.IN_GAUNTLET && playerCurrentGauntlet[pId] == gauntletId) {
                playerStatus[pId] = PlayerStatus.NONE;
                delete playerCurrentGauntlet[pId];
            }
        }

        if (winnerPayout > 0 && _getFighterType(finalWinnerId) == Fighter.FighterType.PLAYER) {
            address payable winnerOwner = payable(playerContract.getPlayerOwner(finalWinnerId));
            SafeTransferLib.safeTransferETH(winnerOwner, winnerPayout);
        }

        emit GauntletCompleted(gauntletId, finalWinnerId, winnerPayout, feeAmount);
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

        uint256 forfeitedPool = ENTRY_FEE * GAUNTLET_SIZE;
        contractFeesCollected += forfeitedPool;

        gauntlet.state = GauntletState.COMPLETED;
        gauntlet.completionTimestamp = block.timestamp;

        RegisteredPlayer[] storage participants = gauntlet.participants;
        for (uint256 i = 0; i < participants.length; i++) {
            uint32 pId = participants[i].playerId;
            if (playerStatus[pId] == PlayerStatus.IN_GAUNTLET && playerCurrentGauntlet[pId] == gauntletId) {
                playerStatus[pId] = PlayerStatus.NONE;
                delete playerCurrentGauntlet[pId];
            }
        }

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

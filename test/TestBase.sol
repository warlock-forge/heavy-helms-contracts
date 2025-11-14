// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

// Interfaces
import {IPlayer} from "../src/interfaces/fighters/IPlayer.sol";
import {IDefaultPlayer} from "../src/interfaces/fighters/IDefaultPlayer.sol";
import {IMonster} from "../src/interfaces/fighters/IMonster.sol";
import {IGameEngine} from "../src/interfaces/game/engine/IGameEngine.sol";
import {IPlayerSkinRegistry} from "../src/interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";
import {IPlayerSkinNFT} from "../src/interfaces/nft/skins/IPlayerSkinNFT.sol";

// Concrete implementations (needed for deployment)
import {Player} from "../src/fighters/Player.sol";
import {PlayerDataCodec} from "../src/lib/PlayerDataCodec.sol";
import {PlayerTickets} from "../src/nft/PlayerTickets.sol";
import {DefaultPlayer} from "../src/fighters/DefaultPlayer.sol";
import {Monster} from "../src/fighters/Monster.sol";
import {GameEngine} from "../src/game/engine/GameEngine.sol";
import {DefaultPlayerSkinNFT} from "../src/nft/skins/DefaultPlayerSkinNFT.sol";
import {PlayerSkinRegistry} from "../src/fighters/registries/skins/PlayerSkinRegistry.sol";
import {PlayerNameRegistry} from "../src/fighters/registries/names/PlayerNameRegistry.sol";
import {MonsterNameRegistry} from "../src/fighters/registries/names/MonsterNameRegistry.sol";
import {Fighter} from "../src/fighters/Fighter.sol";
import {TestPlayerTicketMinter} from "./helpers/TestPlayerTicketMinter.sol";

// Libraries
import {DefaultPlayerLibrary} from "../src/fighters/lib/DefaultPlayerLibrary.sol";
import {MonsterLibrary} from "../src/fighters/lib/MonsterLibrary.sol";
import {MonsterSkinNFT} from "../src/nft/skins/MonsterSkinNFT.sol";
import {NameLibrary} from "../src/fighters/registries/names/lib/NameLibrary.sol";
import {MonsterNameLibrary} from "../src/fighters/registries/names/lib/MonsterNameLibrary.sol";
import {EquipmentRequirements} from "../src/game/engine/EquipmentRequirements.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts@4.9.6/token/ERC1155/IERC1155Receiver.sol";

abstract contract TestBase is Test, IERC1155Receiver {
    bool private constant CI_MODE = true;
    uint256 private constant DEFAULT_FORK_BLOCK = 19_000_000;
    uint256 private constant VRF_ROUND = 335;
    address public vrfCoordinator;

    // VRF Mock System
    VRFCoordinatorV2_5Mock public vrfMock;
    uint256 public subscriptionId;

    Player public playerContract;
    DefaultPlayer public defaultPlayerContract;
    Monster public monsterContract;
    DefaultPlayerSkinNFT public defaultSkin;
    PlayerSkinRegistry public skinRegistry;
    PlayerNameRegistry public nameRegistry;
    EquipmentRequirements public equipmentRequirements;
    uint32 public defaultSkinIndex;
    GameEngine public gameEngine;
    MonsterSkinNFT public monsterSkin;
    uint32 public monsterSkinIndex;
    MonsterNameRegistry public monsterNameRegistry;
    PlayerTickets public playerTickets;
    TestPlayerTicketMinter public ticketMinter;

    /// @notice Modifier to skip tests in CI environment
    /// @dev Uses vm.envOr to check if CI environment variable is set
    modifier skipInCI() {
        if (!vm.envOr("CI", false)) {
            _;
        }
    }

    function setUp() public virtual {
        // Give this contract some ETH to fund VRF subscriptions
        vm.deal(address(this), 1000 ether);

        // Initialize VRF mock system first
        // VRFCoordinatorV2_5Mock(uint96 _baseFee, uint96 _gasPrice, int256 _weiPerUnitLink)
        vrfMock = new VRFCoordinatorV2_5Mock(
            100000000000000000, // 0.1 LINK base fee
            1000000000, // 1 gwei gas price
            4000000000000000000 // 4 LINK per ETH (0.25 ETH per LINK)
        );
        vrfCoordinator = address(vrfMock); // Use mock as VRF coordinator

        // Create and fund a subscription
        subscriptionId = vrfMock.createSubscription();
        vrfMock.fundSubscriptionWithNative{value: 100 ether}(subscriptionId); // Fund with 100 ETH for native payments

        // Use a test keyHash (doesn't matter for mock, but needs to be set)
        bytes32 testKeyHash = 0x0000000000000000000000000000000000000000000000000000000000000001;

        setupRandomness();
        skinRegistry = new PlayerSkinRegistry();
        defaultSkin = new DefaultPlayerSkinNFT();
        monsterSkin = new MonsterSkinNFT();
        equipmentRequirements = new EquipmentRequirements();

        // Register and configure skins
        defaultSkinIndex = _registerSkin(address(defaultSkin));
        skinRegistry.setSkinVerification(defaultSkinIndex, true);
        skinRegistry.setSkinType(defaultSkinIndex, IPlayerSkinRegistry.SkinType.DefaultPlayer);

        monsterSkinIndex = _registerSkin(address(monsterSkin));
        skinRegistry.setSkinVerification(monsterSkinIndex, true);
        skinRegistry.setSkinType(monsterSkinIndex, IPlayerSkinRegistry.SkinType.Monster);

        // Create name registries and initialize names
        nameRegistry = new PlayerNameRegistry();
        string[] memory setANames = NameLibrary.getInitialNameSetA();
        string[] memory setBNames = NameLibrary.getInitialNameSetB();
        string[] memory surnameList = NameLibrary.getInitialSurnames();

        nameRegistry.addNamesToSetA(setANames);
        nameRegistry.addNamesToSetB(setBNames);
        nameRegistry.addSurnames(surnameList);

        // Initialize monster name registry
        monsterNameRegistry = new MonsterNameRegistry();
        string[] memory goblinNames = MonsterNameLibrary.getGoblinNames();
        string[] memory undeadNames = MonsterNameLibrary.getUndeadNames();
        string[] memory demonNames = MonsterNameLibrary.getDemonNames();
        monsterNameRegistry.addMonsterNames(goblinNames);
        monsterNameRegistry.addMonsterNames(undeadNames);
        monsterNameRegistry.addMonsterNames(demonNames);

        gameEngine = new GameEngine();

        // Set up the test environment with a proper timestamp BEFORE deploying contracts
        vm.warp(1692803367 + 1000); // Set timestamp to after genesis

        // Create the player contracts with all required dependencies
        playerTickets = new PlayerTickets(
            address(nameRegistry),
            "bafybeib2pydnkibnj5o3udxg2grmh4dt2tztcecccka4rxia5xumqpemjm", // Fungible metadata CID
            "bafybeibgu5ach7brer6jcjqcgtacxn2ltmgxwencxmcmlf3jt5mmwhxrje" // Name change image CID
        );
        PlayerDataCodec playerDataCodec = new PlayerDataCodec();
        playerContract = new Player(
            address(skinRegistry),
            address(nameRegistry),
            address(equipmentRequirements),
            vrfCoordinator,
            subscriptionId, // Use the subscription ID from the mock
            testKeyHash,
            address(playerTickets),
            address(playerDataCodec)
        );

        // Add player contract as a consumer of the VRF subscription
        vrfMock.addConsumer(subscriptionId, address(playerContract));

        // Set playerContract permissions for tickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: true,
            playerSlots: true,
            nameChanges: true,
            weaponSpecialization: true,
            armorSpecialization: true,
            duels: true,
            dailyResets: true,
            attributeSwaps: true
        });
        playerTickets.setGameContractPermission(address(playerContract), ticketPerms);

        // Create test ticket minter and give it all permissions
        ticketMinter = new TestPlayerTicketMinter(address(playerTickets), address(this));
        PlayerTickets.GamePermissions memory minterPerms = PlayerTickets.GamePermissions({
            playerCreation: true,
            playerSlots: true,
            nameChanges: true,
            weaponSpecialization: true,
            armorSpecialization: true,
            duels: true,
            dailyResets: true,
            attributeSwaps: true
        });
        playerTickets.setGameContractPermission(address(ticketMinter), minterPerms);
        defaultPlayerContract = new DefaultPlayer(address(skinRegistry), address(nameRegistry));
        monsterContract = new Monster(address(skinRegistry), address(monsterNameRegistry));

        // Mint default characters and monsters
        _mintDefaultCharacters();
        _mintMonsters();
    }

    function _registerSkin(address skinContract) internal returns (uint32) {
        vm.deal(address(this), skinRegistry.registrationFee());
        vm.prank(address(this));
        return skinRegistry.registerSkin{value: skinRegistry.registrationFee()}(skinContract);
    }

    function setupRandomness() internal {
        // Check if we're in CI environment
        try vm.envString("CI") returns (string memory) {
            console2.log("Testing in CI mode with mock randomness");
            vm.warp(1_000_000);
            vm.roll(DEFAULT_FORK_BLOCK);
            vm.prevrandao(bytes32(uint256(0x1234567890)));
        } catch {
            // Try to use RPC fork, fallback to mock if not available
            try vm.envString("RPC_URL") returns (string memory rpcUrl) {
                vm.createSelectFork(rpcUrl);
            } catch {
                console2.log("No RPC_URL found, using mock randomness");
                vm.warp(1_000_000);
                vm.roll(DEFAULT_FORK_BLOCK);
                vm.prevrandao(bytes32(uint256(0x1234567890)));
            }
        }
    }

    // Helper function for VRF fulfillment with Chainlink VRF
    function _fulfillVRF(
        uint256 requestId,
        uint256 randomSeed,
        address /* vrfConsumer */
    )
        internal
    {
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomSeed;

        // Call rawFulfillRandomWords as VRF wrapper
        vm.prank(vrfCoordinator);
        playerContract.rawFulfillRandomWords(requestId, randomWords);
    }

    // Helper to create a player request, stopping before VRF fulfillment.
    // This is useful for testing VRF fulfillment mechanics separately,
    // such as testing operator permissions or invalid round IDs.
    function _createPlayerRequest(address owner, IPlayer contractInstance, bool useSetB) internal returns (uint256) {
        vm.deal(owner, contractInstance.createPlayerFeeAmount());
        vm.startPrank(owner);
        uint256 requestId = Player(payable(address(contractInstance)))
        .requestCreatePlayer{value: Player(payable(address(contractInstance))).createPlayerFeeAmount()}(
            useSetB
        );
        vm.stopPrank();
        return requestId;
    }

    // Helper function to assert stat ranges
    function _assertStatRanges(IPlayer.PlayerStats memory stats) internal pure virtual {
        // Basic stat bounds
        assertTrue(stats.attributes.strength >= 3 && stats.attributes.strength <= 21, "Strength out of range");
        assertTrue(
            stats.attributes.constitution >= 3 && stats.attributes.constitution <= 21, "Constitution out of range"
        );
        assertTrue(stats.attributes.size >= 3 && stats.attributes.size <= 21, "Size out of range");
        assertTrue(stats.attributes.agility >= 3 && stats.attributes.agility <= 21, "Agility out of range");
        assertTrue(stats.attributes.stamina >= 3 && stats.attributes.stamina <= 21, "Stamina out of range");
        assertTrue(stats.attributes.luck >= 3 && stats.attributes.luck <= 21, "Luck out of range");
    }

    // Helper function to create a player loadout that supports both practice and duel game test cases
    function _createLoadout(uint32 fighterId) internal view returns (Fighter.PlayerLoadout memory) {
        Fighter.FighterType fighterType = _getFighterType(fighterId);

        if (fighterType == Fighter.FighterType.PLAYER) {
            // For Players, get their stats and extract skin/stance
            IPlayer.PlayerStats memory stats = IPlayer(address(playerContract)).getPlayer(fighterId);
            return Fighter.PlayerLoadout({playerId: fighterId, skin: stats.skin, stance: stats.stance});
        } else if (fighterType == Fighter.FighterType.DEFAULT_PLAYER) {
            // For DefaultPlayers, get stats at any level (skin/stance don't change)
            IPlayer.PlayerStats memory stats =
                IDefaultPlayer(address(defaultPlayerContract)).getDefaultPlayer(fighterId, 1);
            return Fighter.PlayerLoadout({playerId: fighterId, skin: stats.skin, stance: stats.stance});
        } else {
            // For Monsters, get stats at any level (skin/stance don't change)
            IMonster.MonsterStats memory stats = IMonster(address(monsterContract)).getMonster(fighterId, 1);
            return Fighter.PlayerLoadout({playerId: fighterId, skin: stats.skin, stance: stats.stance});
        }
    }

    // Helper function to convert PlayerLoadout to FighterStats for direct GameEngine testing
    function _convertToFighterStats(Fighter.PlayerLoadout memory loadout)
        internal
        view
        returns (IGameEngine.FighterStats memory)
    {
        Fighter.FighterType fighterType = _getFighterType(loadout.playerId);

        if (fighterType == Fighter.FighterType.PLAYER) {
            IPlayer.PlayerStats memory stats = IPlayer(address(playerContract)).getPlayer(loadout.playerId);
            IPlayerSkinNFT.SkinAttributes memory skinAttrs =
                Fighter(address(playerContract)).getSkinAttributes(loadout.skin);
            return IGameEngine.FighterStats({
                weapon: skinAttrs.weapon,
                armor: skinAttrs.armor,
                stance: loadout.stance,
                attributes: stats.attributes,
                level: stats.level,
                weaponSpecialization: stats.weaponSpecialization,
                armorSpecialization: stats.armorSpecialization
            });
        } else if (fighterType == Fighter.FighterType.DEFAULT_PLAYER) {
            IPlayer.PlayerStats memory stats =
                IDefaultPlayer(address(defaultPlayerContract)).getDefaultPlayer(loadout.playerId, 1);
            IPlayerSkinNFT.SkinAttributes memory skinAttrs =
                Fighter(address(defaultPlayerContract)).getSkinAttributes(loadout.skin);
            return IGameEngine.FighterStats({
                weapon: skinAttrs.weapon,
                armor: skinAttrs.armor,
                stance: loadout.stance,
                attributes: stats.attributes,
                level: 1,
                weaponSpecialization: 255,
                armorSpecialization: 255
            });
        } else {
            IMonster.MonsterStats memory stats = IMonster(address(monsterContract)).getMonster(loadout.playerId, 1);
            IPlayerSkinNFT.SkinAttributes memory skinAttrs =
                Fighter(address(monsterContract)).getSkinAttributes(loadout.skin);
            return IGameEngine.FighterStats({
                weapon: skinAttrs.weapon,
                armor: skinAttrs.armor,
                stance: loadout.stance,
                attributes: stats.attributes,
                level: 1,
                weaponSpecialization: 255,
                armorSpecialization: 255
            });
        }
    }

    // Helper function to determine fighter type based on ID range
    function _getFighterType(uint32 playerId) internal pure returns (Fighter.FighterType) {
        if (playerId <= 2000) {
            return Fighter.FighterType.DEFAULT_PLAYER;
        } else if (playerId <= 10000) {
            return Fighter.FighterType.MONSTER;
        } else {
            return Fighter.FighterType.PLAYER;
        }
    }

    // Helper function to validate combat results
    function _assertValidCombatResult(
        uint16 version,
        IGameEngine.WinCondition condition,
        IGameEngine.CombatAction[] memory actions
    ) internal pure {
        assertTrue(actions.length > 0, "No actions recorded");
        assertTrue(uint8(condition) <= uint8(type(IGameEngine.WinCondition).max), "Invalid win condition");
        assertTrue(version > 0, "Invalid version");
    }

    // Helper function to validate events
    function _assertValidCombatEvent(bytes32 player1Data, bytes32 player2Data) internal {
        // Get the last CombatResult event and validate the packed data
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundEvent = false;
        bytes32 eventPlayer1Data;
        bytes32 eventPlayer2Data;

        for (uint256 i = entries.length; i > 0; i--) {
            // CombatResult event has 4 topics (event sig + 3 indexed params)
            if (entries[i - 1].topics.length == 4) {
                eventPlayer1Data = bytes32(entries[i - 1].topics[1]);
                eventPlayer2Data = bytes32(entries[i - 1].topics[2]);
                foundEvent = true;
                break;
            }
        }

        assertTrue(foundEvent, "CombatResult event not found");

        // Decode both expected and actual player data
        (
            uint32 expectedId1,
            uint8 expectedStr1,
            uint8 expectedCon1,
            uint8 expectedSize1,
            uint8 expectedAgi1,
            uint8 expectedSta1,
            uint8 expectedLuck1
        ) = abi.decode(abi.encodePacked(uint96(0), player1Data), (uint32, uint8, uint8, uint8, uint8, uint8, uint8));

        (
            uint32 actualId1,
            uint8 actualStr1,
            uint8 actualCon1,
            uint8 actualSize1,
            uint8 actualAgi1,
            uint8 actualSta1,
            uint8 actualLuck1
        ) = abi.decode(
            abi.encodePacked(uint96(0), eventPlayer1Data), (uint32, uint8, uint8, uint8, uint8, uint8, uint8)
        );

        // Verify player 1 data
        assertEq(actualId1, expectedId1, "Player 1 ID mismatch");
        assertEq(actualStr1, expectedStr1, "Player 1 strength mismatch");
        assertEq(actualCon1, expectedCon1, "Player 1 constitution mismatch");
        assertEq(actualSize1, expectedSize1, "Player 1 size mismatch");
        assertEq(actualAgi1, expectedAgi1, "Player 1 agility mismatch");
        assertEq(actualSta1, expectedSta1, "Player 1 stamina mismatch");
        assertEq(actualLuck1, expectedLuck1, "Player 1 luck mismatch");

        // Decode and verify player 2 data
        (
            uint32 expectedId2,
            uint8 expectedStr2,
            uint8 expectedCon2,
            uint8 expectedSize2,
            uint8 expectedAgi2,
            uint8 expectedSta2,
            uint8 expectedLuck2
        ) = abi.decode(abi.encodePacked(uint96(0), player2Data), (uint32, uint8, uint8, uint8, uint8, uint8, uint8));

        (
            uint32 actualId2,
            uint8 actualStr2,
            uint8 actualCon2,
            uint8 actualSize2,
            uint8 actualAgi2,
            uint8 actualSta2,
            uint8 actualLuck2
        ) = abi.decode(
            abi.encodePacked(uint96(0), eventPlayer2Data), (uint32, uint8, uint8, uint8, uint8, uint8, uint8)
        );

        // Verify player 2 data
        assertEq(actualId2, expectedId2, "Player 2 ID mismatch");
        assertEq(actualStr2, expectedStr2, "Player 2 strength mismatch");
        assertEq(actualCon2, expectedCon2, "Player 2 constitution mismatch");
        assertEq(actualSize2, expectedSize2, "Player 2 size mismatch");
        assertEq(actualAgi2, expectedAgi2, "Player 2 agility mismatch");
        assertEq(actualSta2, expectedSta2, "Player 2 stamina mismatch");
        assertEq(actualLuck2, expectedLuck2, "Player 2 luck mismatch");
    }

    // Helper function to check if a combat result is defensive
    function _isDefensiveResult(IGameEngine.CombatResultType result) internal pure returns (bool) {
        // Defensive results are when the player is defending (successfully or unsuccessfully)
        return result == IGameEngine.CombatResultType.MISS || result == IGameEngine.CombatResultType.HIT
            || result == IGameEngine.CombatResultType.PARRY || result == IGameEngine.CombatResultType.BLOCK
            || result == IGameEngine.CombatResultType.DODGE || result == IGameEngine.CombatResultType.COUNTER
            || result == IGameEngine.CombatResultType.COUNTER_CRIT || result == IGameEngine.CombatResultType.RIPOSTE
            || result == IGameEngine.CombatResultType.RIPOSTE_CRIT;
        // Note: ATTACK/CRIT/EXHAUSTED are offensive actions
    }

    // Helper function to generate a deterministic but unpredictable seed for game actions
    function _generateGameSeed() internal view returns (uint256) {
        return uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, blockhash(block.number - 1), msg.sender))
        );
    }

    // Helper function to assert player ownership and basic state
    function _assertPlayerState(Player contractInstance, uint32 playerId, address expectedOwner, bool shouldExist)
        internal
    {
        if (shouldExist) {
            assertEq(contractInstance.getPlayerOwner(playerId), expectedOwner, "Incorrect player owner");
            IPlayer.PlayerStats memory stats = contractInstance.getPlayer(playerId);
            assertTrue(stats.attributes.strength != 0, "Player should exist");
            assertFalse(contractInstance.isPlayerRetired(playerId), "Player should not be retired");
        } else {
            vm.expectRevert();
            contractInstance.getPlayerOwner(playerId);
        }
    }

    // Helper function to assert ETH balances after transactions
    function _assertBalances(address account, uint256 expectedBalance, string memory message) internal view {
        assertEq(account.balance, expectedBalance, message);
    }

    /// @notice Helper to ensure an address has enough slots for desired player count
    /// @param owner Address to purchase slots for
    /// @param desiredSlots Total number of slots needed
    /// @param contractInstance Player contract instance
    function _ensurePlayerSlots(address owner, uint256 desiredSlots, IPlayer contractInstance) internal {
        require(desiredSlots <= 100, "Cannot exceed MAX_TOTAL_SLOTS");

        uint256 currentSlots = contractInstance.getPlayerSlots(owner);
        if (currentSlots >= desiredSlots) return; // Already have enough slots

        // Calculate how many slots we need to purchase (1 per purchase)
        uint256 slotsNeeded = desiredSlots - currentSlots;
        uint256 purchasesNeeded = slotsNeeded; // 1 slot per purchase

        // Purchase required slots
        uint256 batchCost = contractInstance.slotBatchCost();
        for (uint256 i = 0; i < purchasesNeeded; i++) {
            vm.startPrank(owner);
            vm.deal(owner, batchCost);
            contractInstance.purchasePlayerSlots{value: batchCost}();
            vm.stopPrank();
        }

        // Verify we have enough slots
        assertGe(contractInstance.getPlayerSlots(owner), desiredSlots);
    }

    /// @notice Mints default characters for testing
    /// @dev This creates a standard set of characters with different fighting styles
    function _mintDefaultCharacters() internal {
        DefaultPlayerLibrary.createAllDefaultCharacters(defaultSkin, defaultPlayerContract, defaultSkinIndex);
    }

    /// @notice Mints test monsters for testing (goblin, undead, demon)
    /// @dev This creates three test monsters with IDs 2001, 2002, 2003
    function _mintMonsters() internal {
        // Monster 2001: Easy Goblin with DUAL_CLUBS (62-71 attribute points)
        MonsterLibrary.createGoblinMonster001(
            monsterContract,
            1, // skinTokenId
            5 // nameIndex
        );

        // Monster 2002: Normal Undead with DUAL_DAGGERS (72-81 attribute points)
        MonsterLibrary.createUndeadMonster001(
            monsterContract,
            2, // skinTokenId
            43 // nameIndex
        );

        // Monster 2003: Hard Demon with ARMING_SWORD_KITE (82-91 attribute points)
        MonsterLibrary.createDemonMonster001(
            monsterContract,
            3, // skinTokenId
            94 // nameIndex
        );
    }

    // Helper functions
    function _createPlayerAndFulfillVRF(address owner, bool useSetB) internal returns (uint32) {
        return _createPlayerAndFulfillVRF(owner, playerContract, useSetB);
    }

    function _createPlayerAndFulfillVRF(address owner, Player contractInstance, bool useSetB)
        internal
        returns (uint32)
    {
        // Start recording logs BEFORE creating the request to capture VRF events
        vm.recordLogs();

        // Create the player request
        vm.deal(owner, contractInstance.createPlayerFeeAmount());
        uint256 requestId = _createPlayerRequest(owner, contractInstance, useSetB);

        // Fulfill the VRF request using the proper Chainlink pattern
        _fulfillVRFRequest(address(contractInstance));

        // Extract player ID from logs
        return _getPlayerIdFromLogs(owner, requestId);
    }

    function _createPlayerAndExpectVRFFail(address owner, bool useSetB, string memory expectedError) internal {
        vm.deal(owner, playerContract.createPlayerFeeAmount());

        vm.startPrank(owner);
        vm.recordLogs();
        /* uint256 requestId = */
        playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(useSetB);
        vm.stopPrank();

        vm.expectRevert(bytes(expectedError));
        _fulfillVRFRequest(address(playerContract));
    }

    function _createPlayerAndExpectVRFFail(
        address owner,
        bool useSetB,
        string memory expectedError,
        uint256 /* customRoundId */
    )
        internal
    {
        vm.deal(owner, playerContract.createPlayerFeeAmount());

        vm.startPrank(owner);
        vm.recordLogs();
        /* uint256 requestId = */
        playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(useSetB);
        vm.stopPrank();

        vm.expectRevert(bytes(expectedError));
        _fulfillVRFRequest(address(playerContract));
    }

    /// @notice Helper to properly fulfill VRF requests using the mock system
    /// @param gameContract The contract that made the VRF request
    /// @dev Call vm.recordLogs() before the VRF request, then call this method
    /// @dev Based on Chainlink's documented VRF testing patterns
    function _fulfillVRFRequest(address gameContract) internal {
        // Extract the actual requestId from the VRF request logs (Chainlink pattern)
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Find the RandomWordsRequested event from the VRF coordinator
        uint256 requestId;
        bool foundRequest = false;
        for (uint256 i = 0; i < entries.length; i++) {
            // Look for RandomWordsRequested event (sig: 0xeb0e3652e0f44f417695e6e90f2f42c99b65cd7169074c5a654b16b9748c3a4e)
            if (entries[i].topics[0] == 0xeb0e3652e0f44f417695e6e90f2f42c99b65cd7169074c5a654b16b9748c3a4e) {
                // requestId is the second parameter but NOT indexed, so decode from data
                // Event parameters: keyHash (indexed), requestId, preSeed, subId (indexed), minimumRequestConfirmations, callbackGasLimit, numWords, sender (indexed)
                (requestId,) = abi.decode(entries[i].data, (uint256, uint256));
                foundRequest = true;
                break;
            }
        }

        require(foundRequest, "No VRF request found in logs");

        // Use VRF mock to fulfill the request (documented Chainlink pattern)
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, gameContract);
    }

    function getWeaponName(uint8 weapon) internal view returns (string memory) {
        // Traditional one-handed weapons with shields
        if (weapon == gameEngine.WEAPON_ARMING_SWORD_KITE()) return "ArmingSwordKite";
        if (weapon == gameEngine.WEAPON_MACE_TOWER()) return "MaceTower";
        if (weapon == gameEngine.WEAPON_RAPIER_BUCKLER()) return "RapierBuckler";
        if (weapon == gameEngine.WEAPON_SHORTSWORD_BUCKLER()) return "ShortswordBuckler";
        if (weapon == gameEngine.WEAPON_SHORTSWORD_TOWER()) return "ShortswordTower";
        if (weapon == gameEngine.WEAPON_SCIMITAR_BUCKLER()) return "ScimitarBuckler";
        if (weapon == gameEngine.WEAPON_AXE_KITE()) return "AxeKite";
        if (weapon == gameEngine.WEAPON_AXE_TOWER()) return "AxeTower";
        if (weapon == gameEngine.WEAPON_MACE_KITE()) return "MaceKite";
        if (weapon == gameEngine.WEAPON_CLUB_TOWER()) return "ClubTower";

        // Two-handed weapons
        if (weapon == gameEngine.WEAPON_GREATSWORD()) return "Greatsword";
        if (weapon == gameEngine.WEAPON_BATTLEAXE()) return "Battleaxe";
        if (weapon == gameEngine.WEAPON_QUARTERSTAFF()) return "Quarterstaff";
        if (weapon == gameEngine.WEAPON_SPEAR()) return "Spear";
        if (weapon == gameEngine.WEAPON_MAUL()) return "Maul";
        if (weapon == gameEngine.WEAPON_TRIDENT()) return "Trident";

        // Dual-wield weapons
        if (weapon == gameEngine.WEAPON_DUAL_DAGGERS()) return "DualDaggers";
        if (weapon == gameEngine.WEAPON_RAPIER_DAGGER()) return "RapierDagger";
        if (weapon == gameEngine.WEAPON_DUAL_SCIMITARS()) return "DualScimitars";
        if (weapon == gameEngine.WEAPON_DUAL_CLUBS()) return "DualClubs";

        // Mixed damage type weapons
        if (weapon == gameEngine.WEAPON_ARMING_SWORD_SHORTSWORD()) return "ArmingSwordShortsword";
        if (weapon == gameEngine.WEAPON_SCIMITAR_DAGGER()) return "ScimitarDagger";
        if (weapon == gameEngine.WEAPON_ARMING_SWORD_CLUB()) return "ArmingSwordClub";
        if (weapon == gameEngine.WEAPON_AXE_MACE()) return "AxeMace";
        if (weapon == gameEngine.WEAPON_MACE_SHORTSWORD()) return "MaceShortsword";

        return "Unknown";
    }

    function getArmorName(uint8 armor) internal view returns (string memory) {
        if (armor == gameEngine.ARMOR_CLOTH()) return "Cloth";
        if (armor == gameEngine.ARMOR_LEATHER()) return "Leather";
        if (armor == gameEngine.ARMOR_CHAIN()) return "Chain";
        if (armor == gameEngine.ARMOR_PLATE()) return "Plate";
        return "Unknown";
    }

    function getStanceName(uint8 stance) internal view returns (string memory) {
        if (stance == gameEngine.STANCE_DEFENSIVE()) return "Defensive";
        if (stance == gameEngine.STANCE_BALANCED()) return "Balanced";
        if (stance == gameEngine.STANCE_OFFENSIVE()) return "Offensive";
        return "Unknown";
    }

    // Helper function to get the appropriate Fighter contract
    function _getFighterContract(uint32 playerId) internal view returns (Fighter) {
        if (playerId <= 2000) {
            return Fighter(address(defaultPlayerContract));
        } else if (playerId <= 10000) {
            return Fighter(address(monsterContract));
        } else {
            return Fighter(address(playerContract));
        }
    }

    /// @notice Gets player ID for a player that was already created in a previous transaction
    /// @param owner The address that owns the player
    /// @param requestId The request ID used to create the player
    /// @return The player ID found in logs
    function _getPlayerIdFromLogs(address owner, uint256 requestId) internal returns (uint32) {
        // Player creation event signature
        bytes32 playerCreationEventSig = keccak256(
            "PlayerCreationComplete(uint256,uint32,address,uint256,uint16,uint16,uint8,uint8,uint8,uint8,uint8,uint8,bool)"
        );

        // Use the most recently captured logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the PlayerCreationComplete event matching our criteria
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == playerCreationEventSig) {
                // If requestId is specified, check it matches
                if (requestId != 0 && uint256(logs[i].topics[1]) != requestId) {
                    continue;
                }

                // Check if the owner matches the third indexed parameter
                if (address(uint160(uint256(logs[i].topics[3]))) == owner) {
                    // Extract playerId from second indexed parameter
                    return uint32(uint256(logs[i].topics[2]));
                }
            }
        }

        revert("Player creation event not found");
    }

    // Add this helper function to your TestBase contract
    function _setupValidPlayerRequest(address player) internal returns (uint256) {
        // Create a request
        vm.deal(player, playerContract.createPlayerFeeAmount());
        vm.startPrank(player);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(false);
        vm.stopPrank();

        // Verify request is properly stored
        uint256 pendingRequest = playerContract.getPendingRequest(player);
        assertEq(pendingRequest, requestId, "Request should be stored");

        // Check request status
        (bool exists, bool fulfilled, address owner) = playerContract.getRequestStatus(requestId);
        assertTrue(exists, "Request should exist");
        assertFalse(fulfilled, "Request should not be fulfilled yet");
        assertEq(owner, player, "Owner should match");

        return requestId;
    }

    //==============================================================//
    //                    TICKET HELPER FUNCTIONS                   //
    //==============================================================//

    /// @notice Helper to mint fungible tickets for testing
    /// @param to Address to mint tickets to
    /// @param ticketType The type of ticket to mint (1-7)
    /// @param amount Number of tickets to mint
    function _mintTickets(address to, uint256 ticketType, uint256 amount) internal {
        ticketMinter.mintFungibleTicket(to, ticketType, amount);
    }

    /// @notice Helper to mint create player tickets for testing
    /// @param to Address to mint tickets to
    /// @param amount Number of tickets to mint
    function _mintCreatePlayerTickets(address to, uint256 amount) internal {
        _mintTickets(to, playerTickets.CREATE_PLAYER_TICKET(), amount);
    }

    /// @notice Helper to mint player slot tickets for testing
    /// @param to Address to mint tickets to
    /// @param amount Number of tickets to mint
    function _mintPlayerSlotTickets(address to, uint256 amount) internal {
        _mintTickets(to, playerTickets.PLAYER_SLOT_TICKET(), amount);
    }

    /// @notice Helper to mint weapon specialization tickets for testing
    /// @param to Address to mint tickets to
    /// @param amount Number of tickets to mint
    function _mintWeaponSpecTickets(address to, uint256 amount) internal {
        _mintTickets(to, playerTickets.WEAPON_SPECIALIZATION_TICKET(), amount);
    }

    /// @notice Helper to mint armor specialization tickets for testing
    /// @param to Address to mint tickets to
    /// @param amount Number of tickets to mint
    function _mintArmorSpecTickets(address to, uint256 amount) internal {
        _mintTickets(to, playerTickets.ARMOR_SPECIALIZATION_TICKET(), amount);
    }

    /// @notice Helper to mint duel tickets for testing
    /// @param to Address to mint tickets to
    /// @param amount Number of tickets to mint
    function _mintDuelTickets(address to, uint256 amount) internal {
        _mintTickets(to, playerTickets.DUEL_TICKET(), amount);
    }

    /// @notice Helper to mint daily reset tickets for testing
    /// @param to Address to mint tickets to
    /// @param amount Number of tickets to mint
    function _mintDailyResetTickets(address to, uint256 amount) internal {
        _mintTickets(to, playerTickets.DAILY_RESET_TICKET(), amount);
    }

    /// @notice Helper to mint attribute swap tickets for testing
    /// @param to Address to mint tickets to
    /// @param amount Number of tickets to mint
    function _mintAttributeSwapTickets(address to, uint256 amount) internal {
        _mintTickets(to, playerTickets.ATTRIBUTE_SWAP_TICKET(), amount);
    }

    /// @notice Helper to mint name change NFT for testing
    /// @param to Address to mint the NFT to
    /// @param seed Seed for randomness
    /// @return tokenId The ID of the minted NFT
    function _mintNameChangeNFT(address to, uint256 seed) internal returns (uint256 tokenId) {
        return ticketMinter.mintNameChangeNFT(to, seed);
    }

    //==============================================================//
    //                 ERC1155 RECEIVER IMPLEMENTATION              //
    //==============================================================//

    /// @notice Handle receipt of a single ERC1155 token type
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155Received.selector;
    }

    /// @notice Handle receipt of multiple ERC1155 token types
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    /// @notice Check if contract supports interface
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == 0x01ffc9a7; // ERC165 interface
    }
}

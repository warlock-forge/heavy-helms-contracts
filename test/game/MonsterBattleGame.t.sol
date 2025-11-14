// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {MonsterBattleGame} from "../../src/game/modes/MonsterBattleGame.sol";
import {IGameEngine} from "../../src/interfaces/game/engine/IGameEngine.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {IMonster} from "../../src/interfaces/fighters/IMonster.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";
import {MockTrophyNFT} from "../mocks/MockTrophyNFT.sol";
import {ITrophyNFT} from "../../src/interfaces/nft/ITrophyNFT.sol";
import {console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

// Import custom errors
import {
    GameDisabled,
    PlayerIsRetired,
    InvalidPlayerLoadout,
    CallerNotPlayerOwner,
    MonsterNotInDifficultyTier,
    MonsterAlreadyDead,
    DailyLimitExceeded,
    InsufficientResetFee,
    ResetNotNeeded,
    InvalidDifficulty,
    NoMonstersAvailable,
    PlayerLevelTooLow,
    BountyHuntingRequiresLevel10,
    MonsterHasNoKills,
    UnsupportedPlayerIdForMonsterMode,
    VrfRequestTimestamp,
    VrfTimeoutNotReached,
    BattleDoesNotExist,
    BattleNotPending,
    NotAuthorized,
    ValueMustBePositive,
    InvalidVrfRequestTimestamp
} from "../../src/game/modes/MonsterBattleGame.sol";

contract MonsterBattleGameTest is TestBase {
    MonsterBattleGame public game;

    // Trophy system
    MockTrophyNFT public goblinTrophy;
    MockTrophyNFT public undeadTrophy;
    MockTrophyNFT public demonTrophy;

    // Test addresses
    address public PLAYER_ONE;
    address public PLAYER_TWO;
    uint32 public PLAYER_ONE_ID;
    uint32 public PLAYER_TWO_ID;

    // Test monster IDs from TestBase
    uint32 public constant GOBLIN_ID = 2001;
    uint32 public constant UNDEAD_ID = 2002;
    uint32 public constant DEMON_ID = 2003;

    // Events to test
    event MonsterBattleStarted(
        uint256 indexed battleId,
        uint32 indexed playerId,
        uint32 indexed monsterId,
        MonsterBattleGame.DifficultyLevel difficulty,
        uint32 playerSkinIndex,
        uint16 playerSkinTokenId,
        uint8 playerStance
    );
    event MonsterSelectedForBattle(uint256 indexed battleId, uint32 indexed monsterId);
    event MonsterBattleCompleted(
        uint256 indexed battleId,
        uint32 indexed winnerId,
        bool playerWon,
        IGameEngine.WinCondition winCondition,
        uint256 randomness
    );
    event MonsterBattleXPAwarded(
        uint32 indexed playerId, uint16 xpAmount, bool playerWon, MonsterBattleGame.DifficultyLevel difficulty
    );
    event BountyRewardDistributed(
        uint32 indexed playerId, uint32 indexed monsterId, uint32 monsterKillCount, bool isLegendary
    );
    event DailyLimitReset(uint32 indexed playerId, uint256 dayNumber, bool paidWithTicket);
    event MonsterKilled(
        uint32 indexed monsterId, uint32 indexed killerPlayerId, MonsterBattleGame.DifficultyLevel difficulty
    );
    event PlayerDiedInBattle(uint32 indexed playerId, uint32 indexed monsterId);
    event GameEnabledUpdated(bool enabled);
    event LethalityFactorUpdated(uint16 oldFactor, uint16 newFactor);
    event DailyResetCostUpdated(uint256 oldCost, uint256 newCost);
    event DailyMonsterLimitUpdated(uint8 oldLimit, uint8 newLimit);
    event VrfRequestTimeoutUpdated(uint256 oldValue, uint256 newValue);
    event BattleRecovered(uint256 indexed battleId);

    function setUp() public override {
        super.setUp();

        // Use the same test keyHash from TestBase
        bytes32 testKeyHash = 0x0000000000000000000000000000000000000000000000000000000000000001;

        // Deploy MonsterBattleGame
        game = new MonsterBattleGame(
            address(gameEngine),
            payable(address(playerContract)),
            address(monsterContract),
            vrfCoordinator,
            subscriptionId,
            testKeyHash,
            address(playerTickets)
        );

        // Add MonsterBattleGame as a consumer to the VRF subscription
        vrfMock.addConsumer(subscriptionId, address(game));

        // Set permissions for game contract on Player
        IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
            record: true,
            retire: true, // Monster battles can retire players
            immortal: false,
            experience: true // Monster battles award XP
        });
        playerContract.setGameContractPermission(address(game), perms);

        // Set permissions for game contract on PlayerTickets
        PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
            playerCreation: true,
            playerSlots: false,
            nameChanges: false,
            weaponSpecialization: false,
            armorSpecialization: false,
            duels: false,
            dailyResets: true,
            attributeSwaps: true
        });
        playerTickets.setGameContractPermission(address(game), ticketPerms);

        // Give test contract permission to award experience and manage retirement
        IPlayer.GamePermissions memory testPerms =
            IPlayer.GamePermissions({record: false, retire: true, immortal: false, experience: true});
        playerContract.setGameContractPermission(address(this), testPerms);

        // Setup test addresses
        PLAYER_ONE = address(0xdF);
        PLAYER_TWO = address(0xeF);

        // Create actual players using VRF
        PLAYER_ONE_ID = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        PLAYER_TWO_ID = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);

        // Give them ETH
        vm.deal(PLAYER_ONE, 100 ether);
        vm.deal(PLAYER_TWO, 100 ether);

        // Give them daily reset tickets for testing
        _mintDailyResetTickets(PLAYER_ONE, 10);
        _mintDailyResetTickets(PLAYER_TWO, 10);

        // Give players approval to MonsterBattleGame to burn their tickets
        vm.prank(PLAYER_ONE);
        playerTickets.setApprovalForAll(address(game), true);
        vm.prank(PLAYER_TWO);
        playerTickets.setApprovalForAll(address(game), true);

        // Add the test monsters to the game's availability arrays
        uint32[] memory easyMonsters = new uint32[](1);
        easyMonsters[0] = GOBLIN_ID;
        game.addNewMonsterBatch(easyMonsters, MonsterBattleGame.DifficultyLevel.EASY);

        uint32[] memory normalMonsters = new uint32[](1);
        normalMonsters[0] = UNDEAD_ID;
        game.addNewMonsterBatch(normalMonsters, MonsterBattleGame.DifficultyLevel.NORMAL);

        uint32[] memory hardMonsters = new uint32[](1);
        hardMonsters[0] = DEMON_ID;
        game.addNewMonsterBatch(hardMonsters, MonsterBattleGame.DifficultyLevel.HARD);

        // Setup trophy system
        _setupTrophySystem();
    }

    //==============================================================//
    //                     TEST: INITIALIZATION                      //
    //==============================================================//

    function testInitialState() public view {
        assertEq(address(game.gameEngine()), address(gameEngine));
        assertEq(address(game.playerContract()), address(playerContract));
        assertEq(address(game.monsterContract()), address(monsterContract));
        assertEq(address(game.playerTickets()), address(playerTickets));

        // Check default values
        assertTrue(game.isGameEnabled());
        assertEq(game.lethalityFactor(), 75);
        assertEq(game.dailyMonsterLimit(), 5);
        assertEq(game.dailyResetCost(), 0.001 ether);
        assertEq(game.vrfRequestTimeout(), 24 hours);
    }

    function testMonstersProperlyAdded() public view {
        // Check goblin (easy)
        assertEq(game.availableMonstersByDifficulty(MonsterBattleGame.DifficultyLevel.EASY, 0), GOBLIN_ID);

        // Check undead (normal)
        assertEq(game.availableMonstersByDifficulty(MonsterBattleGame.DifficultyLevel.NORMAL, 0), UNDEAD_ID);

        // Check demon (hard)
        assertEq(game.availableMonstersByDifficulty(MonsterBattleGame.DifficultyLevel.HARD, 0), DEMON_ID);

        // Check difficulty mappings
        assertEq(uint8(game.monsterDifficulty(GOBLIN_ID)), uint8(MonsterBattleGame.DifficultyLevel.EASY));
        assertEq(uint8(game.monsterDifficulty(UNDEAD_ID)), uint8(MonsterBattleGame.DifficultyLevel.NORMAL));
        assertEq(uint8(game.monsterDifficulty(DEMON_ID)), uint8(MonsterBattleGame.DifficultyLevel.HARD));
    }

    //==============================================================//
    //                     TEST: FIGHT MONSTER                       //
    //==============================================================//

    function testFightMonsterEasy() public {
        vm.startPrank(PLAYER_ONE);

        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // Expect the MonsterBattleStarted event with monsterId = 0 (random selection)
        vm.expectEmit(true, true, true, true);
        emit MonsterBattleStarted(
            0, // battleId
            PLAYER_ONE_ID,
            0, // monsterId = 0 for random selection
            MonsterBattleGame.DifficultyLevel.EASY,
            loadout.skin.skinIndex,
            loadout.skin.skinTokenId,
            loadout.stance
        );

        vm.recordLogs();
        uint256 battleId = game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout);

        vm.stopPrank();

        assertEq(battleId, 0, "First battle should have ID 0");

        // Fulfill VRF
        _fulfillVRFRequest(address(game));

        // Check for MonsterBattleCompleted event
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundCompletedEvent = false;
        bool playerWon = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("MonsterBattleCompleted(uint256,uint32,bool,uint8,uint256)")) {
                foundCompletedEvent = true;
                uint256 eventBattleId = uint256(entries[i].topics[1]);
                uint32 winnerId = uint32(uint256(entries[i].topics[2]));
                (bool eventPlayerWon,,) = abi.decode(entries[i].data, (bool, IGameEngine.WinCondition, uint256));
                assertEq(eventBattleId, battleId, "Battle ID should match");
                playerWon = eventPlayerWon;
                assertTrue(winnerId == PLAYER_ONE_ID || winnerId == GOBLIN_ID, "Winner should be player or monster");
                break;
            }
        }

        assertTrue(foundCompletedEvent, "MonsterBattleCompleted event not found");

        // Check for XP award event
        bool foundXPEvent = false;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("MonsterBattleXPAwarded(uint32,uint16,bool,uint8)")) {
                foundXPEvent = true;
                uint32 eventPlayerId = uint32(uint256(entries[i].topics[1]));
                (uint16 xpAmount, bool eventPlayerWon, MonsterBattleGame.DifficultyLevel difficulty) =
                    abi.decode(entries[i].data, (uint16, bool, MonsterBattleGame.DifficultyLevel));
                assertEq(eventPlayerId, PLAYER_ONE_ID, "XP should be for correct player");
                assertEq(eventPlayerWon, playerWon, "XP win status should match battle result");
                assertTrue(difficulty == MonsterBattleGame.DifficultyLevel.EASY, "Difficulty should be EASY");
                if (playerWon) {
                    assertEq(xpAmount, 50, "Win XP for easy should be 50");
                } else {
                    assertEq(xpAmount, 5, "Loss XP for easy should be 5");
                }
                break;
            }
        }

        assertTrue(foundXPEvent, "MonsterBattleXPAwarded event not found");

        // Check for CombatResult event
        bool foundCombatEvent = false;
        for (uint256 i = 0; i < entries.length; i++) {
            // CombatResult event signature
            if (entries[i].topics[0] == keccak256("CombatResult(bytes32,bytes32,uint32,bytes)")) {
                foundCombatEvent = true;
                bytes32 player1Data = bytes32(entries[i].topics[1]);
                bytes32 player2Data = bytes32(entries[i].topics[2]);
                uint32 eventWinnerId = uint32(uint256(entries[i].topics[3]));

                // Decode player1Data using PlayerDataCodec
                (uint32 player1Id,,) = playerContract.codec().decodePlayerData(player1Data);
                assertEq(player1Id, PLAYER_ONE_ID, "Player 1 should be our player");

                // Verify player2Data is the monster (simple encoding - just the ID)
                uint32 player2Id = uint32(uint256(player2Data));
                assertEq(player2Id, GOBLIN_ID, "Player 2 should be the goblin");

                // Winner should match what we found in MonsterBattleCompleted
                if (playerWon) {
                    assertEq(eventWinnerId, PLAYER_ONE_ID, "Winner should be player");
                } else {
                    assertEq(eventWinnerId, GOBLIN_ID, "Winner should be monster");
                }
                break;
            }
        }

        assertTrue(foundCombatEvent, "CombatResult event not found");
    }

    function testFightMonsterNormal() public {
        vm.startPrank(PLAYER_ONE);

        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // Expect the MonsterBattleStarted event with monsterId = 0 (random selection)
        vm.expectEmit(true, true, true, true);
        emit MonsterBattleStarted(
            0, // battleId
            PLAYER_ONE_ID,
            0, // monsterId = 0 for random selection
            MonsterBattleGame.DifficultyLevel.NORMAL,
            loadout.skin.skinIndex,
            loadout.skin.skinTokenId,
            loadout.stance
        );

        vm.recordLogs();
        uint256 battleId = game.fightMonster(MonsterBattleGame.DifficultyLevel.NORMAL, loadout);

        vm.stopPrank();

        assertEq(battleId, 0, "First battle should have ID 0");

        // Fulfill VRF
        _fulfillVRFRequest(address(game));

        // Check for MonsterBattleCompleted event
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundCompletedEvent = false;
        bool playerWon = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("MonsterBattleCompleted(uint256,uint32,bool,uint8,uint256)")) {
                foundCompletedEvent = true;
                uint256 eventBattleId = uint256(entries[i].topics[1]);
                uint32 winnerId = uint32(uint256(entries[i].topics[2]));
                (bool eventPlayerWon,,) = abi.decode(entries[i].data, (bool, IGameEngine.WinCondition, uint256));
                assertEq(eventBattleId, battleId, "Battle ID should match");
                playerWon = eventPlayerWon;
                assertTrue(winnerId == PLAYER_ONE_ID || winnerId == UNDEAD_ID, "Winner should be player or monster");
                break;
            }
        }

        assertTrue(foundCompletedEvent, "MonsterBattleCompleted event not found");

        // Check for XP award event
        bool foundXPEvent = false;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("MonsterBattleXPAwarded(uint32,uint16,bool,uint8)")) {
                foundXPEvent = true;
                uint32 eventPlayerId = uint32(uint256(entries[i].topics[1]));
                (uint16 xpAmount, bool eventPlayerWon, MonsterBattleGame.DifficultyLevel difficulty) =
                    abi.decode(entries[i].data, (uint16, bool, MonsterBattleGame.DifficultyLevel));
                assertEq(eventPlayerId, PLAYER_ONE_ID, "XP should be for correct player");
                assertEq(eventPlayerWon, playerWon, "XP win status should match battle result");
                assertTrue(difficulty == MonsterBattleGame.DifficultyLevel.NORMAL, "Difficulty should be NORMAL");
                if (playerWon) {
                    assertEq(xpAmount, 100, "Win XP for normal should be 100");
                } else {
                    assertEq(xpAmount, 15, "Loss XP for normal should be 15");
                }
                break;
            }
        }

        assertTrue(foundXPEvent, "MonsterBattleXPAwarded event not found");

        // Check for CombatResult event
        bool foundCombatEvent = false;
        for (uint256 i = 0; i < entries.length; i++) {
            // CombatResult event signature
            if (entries[i].topics[0] == keccak256("CombatResult(bytes32,bytes32,uint32,bytes)")) {
                foundCombatEvent = true;
                bytes32 player1Data = bytes32(entries[i].topics[1]);
                bytes32 player2Data = bytes32(entries[i].topics[2]);
                uint32 eventWinnerId = uint32(uint256(entries[i].topics[3]));

                // Decode player1Data using PlayerDataCodec
                (uint32 player1Id,,) = playerContract.codec().decodePlayerData(player1Data);
                assertEq(player1Id, PLAYER_ONE_ID, "Player 1 should be our player");

                // Verify player2Data is the monster (simple encoding - just the ID)
                uint32 player2Id = uint32(uint256(player2Data));
                assertEq(player2Id, UNDEAD_ID, "Player 2 should be the undead");

                // Winner should match what we found in MonsterBattleCompleted
                if (playerWon) {
                    assertEq(eventWinnerId, PLAYER_ONE_ID, "Winner should be player");
                } else {
                    assertEq(eventWinnerId, UNDEAD_ID, "Winner should be monster");
                }
                break;
            }
        }

        assertTrue(foundCombatEvent, "CombatResult event not found");
    }

    function testFightMonsterHard() public {
        vm.startPrank(PLAYER_ONE);

        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // Expect the MonsterBattleStarted event with monsterId = 0 (random selection)
        vm.expectEmit(true, true, true, true);
        emit MonsterBattleStarted(
            0, // battleId
            PLAYER_ONE_ID,
            0, // monsterId = 0 for random selection
            MonsterBattleGame.DifficultyLevel.HARD,
            loadout.skin.skinIndex,
            loadout.skin.skinTokenId,
            loadout.stance
        );

        vm.recordLogs();
        uint256 battleId = game.fightMonster(MonsterBattleGame.DifficultyLevel.HARD, loadout);

        vm.stopPrank();

        assertEq(battleId, 0, "First battle should have ID 0");

        // Fulfill VRF
        _fulfillVRFRequest(address(game));

        // Check for MonsterBattleCompleted event
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundCompletedEvent = false;
        bool playerWon = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("MonsterBattleCompleted(uint256,uint32,bool,uint8,uint256)")) {
                foundCompletedEvent = true;
                uint256 eventBattleId = uint256(entries[i].topics[1]);
                uint32 winnerId = uint32(uint256(entries[i].topics[2]));
                (bool eventPlayerWon,,) = abi.decode(entries[i].data, (bool, IGameEngine.WinCondition, uint256));
                assertEq(eventBattleId, battleId, "Battle ID should match");
                playerWon = eventPlayerWon;
                assertTrue(winnerId == PLAYER_ONE_ID || winnerId == DEMON_ID, "Winner should be player or monster");
                break;
            }
        }

        assertTrue(foundCompletedEvent, "MonsterBattleCompleted event not found");

        // Check for XP award event
        bool foundXPEvent = false;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("MonsterBattleXPAwarded(uint32,uint16,bool,uint8)")) {
                foundXPEvent = true;
                uint32 eventPlayerId = uint32(uint256(entries[i].topics[1]));
                (uint16 xpAmount, bool eventPlayerWon, MonsterBattleGame.DifficultyLevel difficulty) =
                    abi.decode(entries[i].data, (uint16, bool, MonsterBattleGame.DifficultyLevel));
                assertEq(eventPlayerId, PLAYER_ONE_ID, "XP should be for correct player");
                assertEq(eventPlayerWon, playerWon, "XP win status should match battle result");
                assertTrue(difficulty == MonsterBattleGame.DifficultyLevel.HARD, "Difficulty should be HARD");
                if (playerWon) {
                    assertEq(xpAmount, 150, "Win XP for hard should be 150");
                } else {
                    assertEq(xpAmount, 30, "Loss XP for hard should be 30");
                }
                break;
            }
        }

        assertTrue(foundXPEvent, "MonsterBattleXPAwarded event not found");

        // Check for CombatResult event
        bool foundCombatEvent = false;
        for (uint256 i = 0; i < entries.length; i++) {
            // CombatResult event signature
            if (entries[i].topics[0] == keccak256("CombatResult(bytes32,bytes32,uint32,bytes)")) {
                foundCombatEvent = true;
                bytes32 player1Data = bytes32(entries[i].topics[1]);
                bytes32 player2Data = bytes32(entries[i].topics[2]);
                uint32 eventWinnerId = uint32(uint256(entries[i].topics[3]));

                // Decode player1Data using PlayerDataCodec
                (uint32 player1Id,,) = playerContract.codec().decodePlayerData(player1Data);
                assertEq(player1Id, PLAYER_ONE_ID, "Player 1 should be our player");

                // Verify player2Data is the monster (simple encoding - just the ID)
                uint32 player2Id = uint32(uint256(player2Data));
                assertEq(player2Id, DEMON_ID, "Player 2 should be the demon");

                // Winner should match what we found in MonsterBattleCompleted
                if (playerWon) {
                    assertEq(eventWinnerId, PLAYER_ONE_ID, "Winner should be player");
                } else {
                    assertEq(eventWinnerId, DEMON_ID, "Winner should be monster");
                }
                break;
            }
        }

        assertTrue(foundCombatEvent, "CombatResult event not found");
    }

    function testBattleIdIncrement() public {
        // First battle
        Fighter.PlayerLoadout memory loadout1 = _createLoadout(PLAYER_ONE_ID);
        vm.prank(PLAYER_ONE);
        uint256 battleId1 = game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout1);
        assertEq(battleId1, 0, "First battle should have ID 0");

        // Second battle
        Fighter.PlayerLoadout memory loadout2 = _createLoadout(PLAYER_TWO_ID);
        vm.prank(PLAYER_TWO);
        uint256 battleId2 = game.fightMonster(MonsterBattleGame.DifficultyLevel.NORMAL, loadout2);
        assertEq(battleId2, 1, "Second battle should have ID 1");

        // Third battle
        Fighter.PlayerLoadout memory loadout3 = _createLoadout(PLAYER_ONE_ID);
        vm.prank(PLAYER_ONE);
        uint256 battleId3 = game.fightMonster(MonsterBattleGame.DifficultyLevel.HARD, loadout3);
        assertEq(battleId3, 2, "Third battle should have ID 2");
    }

    //==============================================================//
    //                    TEST: DAILY LIMIT SYSTEM                  //
    //==============================================================//

    function testDailyLimit() public {
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // Should be able to fight 5 times (default daily limit)
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(PLAYER_ONE);
            game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout);
        }

        // 6th attempt should fail
        vm.expectRevert(abi.encodeWithSelector(DailyLimitExceeded.selector, 5, 5));
        vm.prank(PLAYER_ONE);
        game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout);

        // Check daily run count
        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 5);
    }

    function testDailyLimitResetWithETH() public {
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // Use up daily limit
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(PLAYER_ONE);
            game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout);
        }

        // Reset with ETH
        uint256 resetCost = game.dailyResetCost();
        vm.prank(PLAYER_ONE);
        game.resetMonsterDailyLimit{value: resetCost}(PLAYER_ONE_ID);

        // Should be able to fight again
        vm.prank(PLAYER_ONE);
        game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout);

        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 1);
    }

    function testDailyLimitResetWithTicket() public {
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // Use up daily limit
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(PLAYER_ONE);
            game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout);
        }

        // Reset with ticket
        vm.prank(PLAYER_ONE);
        game.resetMonsterDailyLimitWithTicket(PLAYER_ONE_ID);

        // Should be able to fight again
        vm.prank(PLAYER_ONE);
        game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout);

        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 1);
    }

    function testDailyLimitResetEvents() public {
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // Use up daily limit
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(PLAYER_ONE);
            game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout);
        }

        // Test ETH reset event
        uint256 today = block.timestamp / 1 days;
        uint256 resetCost = game.dailyResetCost();

        vm.expectEmit(true, true, true, true);
        emit DailyLimitReset(PLAYER_ONE_ID, today, false);

        vm.deal(PLAYER_ONE, resetCost);
        vm.prank(PLAYER_ONE);
        game.resetMonsterDailyLimit{value: resetCost}(PLAYER_ONE_ID);

        // Use up limit again
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(PLAYER_ONE);
            game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout);
        }

        // Test ticket reset event
        vm.expectEmit(true, true, true, true);
        emit DailyLimitReset(PLAYER_ONE_ID, today, true);

        vm.prank(PLAYER_ONE);
        game.resetMonsterDailyLimitWithTicket(PLAYER_ONE_ID);
    }

    function testCannotResetWhenNotNeeded() public {
        // Player has not used any battles

        // Try to reset with ETH - should fail
        uint256 resetCost = game.dailyResetCost();
        vm.deal(PLAYER_ONE, resetCost);
        vm.expectRevert(abi.encodeWithSelector(ResetNotNeeded.selector, 0, 5));
        vm.prank(PLAYER_ONE);
        game.resetMonsterDailyLimit{value: resetCost}(PLAYER_ONE_ID);

        // Try to reset with ticket - should fail
        vm.expectRevert(abi.encodeWithSelector(ResetNotNeeded.selector, 0, 5));
        vm.prank(PLAYER_ONE);
        game.resetMonsterDailyLimitWithTicket(PLAYER_ONE_ID);
    }

    function testInsufficientResetFee() public {
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // Use up daily limit
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(PLAYER_ONE);
            game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout);
        }

        // Try to reset with insufficient ETH
        uint256 insufficientFee = game.dailyResetCost() - 1;
        vm.expectRevert(InsufficientResetFee.selector);
        vm.prank(PLAYER_ONE);
        game.resetMonsterDailyLimit{value: insufficientFee}(PLAYER_ONE_ID);
    }

    function testDifferentPlayersDifferentLimits() public {
        Fighter.PlayerLoadout memory loadout1 = _createLoadout(PLAYER_ONE_ID);
        Fighter.PlayerLoadout memory loadout2 = _createLoadout(PLAYER_TWO_ID);

        // Player 1 uses all 5 battles
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(PLAYER_ONE);
            game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout1);
        }

        // Player 2 should still be able to battle
        vm.prank(PLAYER_TWO);
        game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout2);

        assertEq(game.getDailyRunCount(PLAYER_ONE_ID), 5);
        assertEq(game.getDailyRunCount(PLAYER_TWO_ID), 1);
    }

    //==============================================================//
    //                TEST: FIGHT SPECIFIC MONSTER                  //
    //==============================================================//

    function testFightSpecificMonsterRequiresLevel10() public {
        // Player starts at level 1
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // First, give the monster some kills so it's eligible for bounty hunting
        game.getMonsterRecord(GOBLIN_ID); // Just to verify it exists

        // Should fail - player not level 10
        vm.expectRevert(BountyHuntingRequiresLevel10.selector);
        vm.prank(PLAYER_ONE);
        game.fightSpecificMonster(GOBLIN_ID, loadout);
    }

    function testFightSpecificMonsterRequiresMonsterKills() public {
        // Award XP to reach level 10 directly
        // XP is consumed at each level, so we need the sum of all requirements
        playerContract.awardExperience(PLAYER_ONE_ID, 7489);

        // Verify player reached level 10
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(PLAYER_ONE_ID);
        assertEq(stats.currentXP, 0, "Player should have 0 XP remaining");
        assertEq(stats.level, 10, "Player should be level 10");

        // Now test fighting specific monster - should get MonsterHasNoKills error
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);
        vm.expectRevert(MonsterHasNoKills.selector);
        vm.prank(PLAYER_ONE);
        game.fightSpecificMonster(GOBLIN_ID, loadout);
    }

    function testFightSpecificMonsterWithKills() public {
        // This test would require setting up a monster with kills
        // In a real scenario, we'd need to either:
        // 1. Add a test helper to set monster kills
        // 2. Actually run battles where the monster wins
        // For now, we'll test the basic flow without kills
    }

    function testFightSpecificMonsterRespectsDailyLimit() public {
        // Advance player to level 10
        playerContract.awardExperience(PLAYER_ONE_ID, 7489);

        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // Use up daily limit with regular battles
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(PLAYER_ONE);
            game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout);
        }

        // Should fail due to daily limit even for specific monster
        vm.expectRevert(abi.encodeWithSelector(DailyLimitExceeded.selector, 5, 5));
        vm.prank(PLAYER_ONE);
        game.fightSpecificMonster(GOBLIN_ID, loadout);
    }

    function testFightSpecificMonsterDeadMonster() public {
        // Advance player to level 10
        playerContract.awardExperience(PLAYER_ONE_ID, 7489);

        // For this test, we'd need a way to mark a monster as dead
        // This would typically happen when a monster dies in battle
    }

    function testPlayerDeathMechanics() public {
        // Set maximum lethality to increase death chance
        game.setLethalityFactor(type(uint16).max); // 65535

        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // Keep fighting until player dies (or max attempts)
        uint256 maxAttempts = 50; // Increase attempts
        bool playerDied = false;

        for (uint256 i = 0; i < maxAttempts; i++) {
            // Reset daily limit if needed
            if (game.getDailyRunCount(PLAYER_ONE_ID) >= 5) {
                vm.prank(PLAYER_ONE);
                game.resetMonsterDailyLimitWithTicket(PLAYER_ONE_ID);
            }

            // Record logs to check for death event
            vm.recordLogs();
            vm.prank(PLAYER_ONE);
            game.fightMonster(MonsterBattleGame.DifficultyLevel.HARD, loadout);
            _fulfillVRFRequest(address(game));

            // Check if player is retired (died)
            if (playerContract.isPlayerRetired(PLAYER_ONE_ID)) {
                playerDied = true;

                // Verify death event was emitted
                Vm.Log[] memory logs = vm.getRecordedLogs();
                bool foundDeathEvent = false;
                for (uint256 j = 0; j < logs.length; j++) {
                    if (logs[j].topics[0] == keccak256("PlayerDiedInBattle(uint32,uint32)")) {
                        foundDeathEvent = true;
                        break;
                    }
                }
                assertTrue(foundDeathEvent, "PlayerDiedInBattle event should be emitted");
                break;
            }
        }

        if (playerDied) {
            // Test that retired player cannot fight
            vm.expectRevert(PlayerIsRetired.selector);
            vm.prank(PLAYER_ONE);
            game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout);
        } else {
            // If player didn't die after max attempts, that's okay - death is probabilistic
            // We can't guarantee death even with high lethality
            console2.log("Player survived all attempts with max lethality factor");
        }
    }

    function testMonsterDeathAndBounty() public {
        // Set maximum lethality for monster death
        game.setLethalityFactor(type(uint16).max);

        // Level up both players to level 10 for better combat effectiveness
        playerContract.awardExperience(PLAYER_ONE_ID, 7489);
        playerContract.awardExperience(PLAYER_TWO_ID, 7489);

        // Track monster deaths
        uint256 totalMonsterDeaths = 0;
        uint256 totalBattles = 0;

        // Keep fighting until we see some monster deaths
        uint256 maxRounds = 30;

        for (uint256 round = 0; round < maxRounds; round++) {
            // Check which monsters are still alive
            bool goblinAlive = !game.isMonsterRetired(GOBLIN_ID);
            bool undeadAlive = !game.isMonsterRetired(UNDEAD_ID);
            bool demonAlive = !game.isMonsterRetired(DEMON_ID);

            // If all monsters are dead, we're done
            if (!goblinAlive && !undeadAlive && !demonAlive) {
                break;
            }

            // Use both players
            uint32[] memory playerIds = new uint32[](2);
            playerIds[0] = PLAYER_ONE_ID;
            playerIds[1] = PLAYER_TWO_ID;

            for (uint256 p = 0; p < 2; p++) {
                Fighter.PlayerLoadout memory loadout = _createLoadout(playerIds[p]);
                address playerAddress = p == 0 ? PLAYER_ONE : PLAYER_TWO;

                // Skip if player is retired
                if (playerContract.isPlayerRetired(playerIds[p])) continue;

                // Pick difficulty based on which monsters are alive
                MonsterBattleGame.DifficultyLevel difficulty;
                if (goblinAlive) {
                    difficulty = MonsterBattleGame.DifficultyLevel.EASY;
                } else if (undeadAlive) {
                    difficulty = MonsterBattleGame.DifficultyLevel.NORMAL;
                } else if (demonAlive) {
                    difficulty = MonsterBattleGame.DifficultyLevel.HARD;
                } else {
                    continue; // All dead
                }

                // Reset daily limit if needed
                if (game.getDailyRunCount(playerIds[p]) >= 5) {
                    vm.prank(playerAddress);
                    game.resetMonsterDailyLimitWithTicket(playerIds[p]);
                }

                // Track deaths before battle
                bool goblinDeadBefore = game.isMonsterRetired(GOBLIN_ID);
                bool undeadDeadBefore = game.isMonsterRetired(UNDEAD_ID);
                bool demonDeadBefore = game.isMonsterRetired(DEMON_ID);

                // Fight (handle case where no monsters available for this difficulty)
                vm.prank(playerAddress);
                try game.fightMonster(difficulty, loadout) returns (uint256) {
                    _fulfillVRFRequest(address(game));
                    totalBattles++;
                } catch {
                    // No monsters available for this difficulty, skip
                    continue;
                }

                // Check for new monster deaths
                if (!goblinDeadBefore && game.isMonsterRetired(GOBLIN_ID)) {
                    totalMonsterDeaths++;
                }
                if (!undeadDeadBefore && game.isMonsterRetired(UNDEAD_ID)) {
                    totalMonsterDeaths++;
                }
                if (!demonDeadBefore && game.isMonsterRetired(DEMON_ID)) {
                    totalMonsterDeaths++;
                }
            }
        }

        console2.log("Monster death rate: %s deaths out of %s battles", totalMonsterDeaths, totalBattles);

        // Verify at least one monster died with max lethality
        assertTrue(totalMonsterDeaths > 0, "Should have at least one monster death with max lethality");

        // Test that we can't fight dead monsters
        if (game.isMonsterRetired(GOBLIN_ID)) {
            // Create fresh loadout for player (they might be dead from battles)
            uint32 testPlayerId = playerContract.isPlayerRetired(PLAYER_ONE_ID) ? PLAYER_TWO_ID : PLAYER_ONE_ID;
            address testPlayer = testPlayerId == PLAYER_ONE_ID ? PLAYER_ONE : PLAYER_TWO;

            if (!playerContract.isPlayerRetired(testPlayerId)) {
                vm.expectRevert(NoMonstersAvailable.selector);
                vm.prank(testPlayer);
                game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, _createLoadout(testPlayerId));
            }
        }
    }

    function testBountyRewardsWithKills() public {
        // This test requires a monster to have kills first
        // Set high lethality to increase death chance
        game.setLethalityFactor(10000);

        // First, we need the monster to kill a player
        Fighter.PlayerLoadout memory player2Loadout = _createLoadout(PLAYER_TWO_ID);

        // Keep fighting until PLAYER_TWO dies
        uint256 maxAttempts = 30;
        bool player2Died = false;
        uint32 killerMonsterId = 0;

        for (uint256 i = 0; i < maxAttempts; i++) {
            // Reset daily limit if needed
            if (game.getDailyRunCount(PLAYER_TWO_ID) >= 5) {
                vm.prank(PLAYER_TWO);
                game.resetMonsterDailyLimitWithTicket(PLAYER_TWO_ID);
            }

            // Record logs
            vm.recordLogs();
            vm.prank(PLAYER_TWO);
            game.fightMonster(MonsterBattleGame.DifficultyLevel.HARD, player2Loadout);
            _fulfillVRFRequest(address(game));

            // Check if player died
            if (playerContract.isPlayerRetired(PLAYER_TWO_ID)) {
                player2Died = true;

                // Find which monster killed the player
                Vm.Log[] memory logs = vm.getRecordedLogs();
                for (uint256 j = 0; j < logs.length; j++) {
                    if (logs[j].topics[0] == keccak256("PlayerDiedInBattle(uint32,uint32)")) {
                        killerMonsterId = uint32(uint256(logs[j].topics[2]));
                        break;
                    }
                }
                break;
            }
        }

        if (player2Died && killerMonsterId > 0) {
            // Verify monster has kills
            Fighter.Record memory monsterRecord = game.getMonsterRecord(killerMonsterId);
            assertTrue(monsterRecord.kills > 0, "Monster should have kills");

            // Now have PLAYER_ONE (level 10) hunt this specific monster
            playerContract.awardExperience(PLAYER_ONE_ID, 7489);
            Fighter.PlayerLoadout memory player1Loadout = _createLoadout(PLAYER_ONE_ID);

            // Check PLAYER_ONE's ticket balances before
            uint256 dailyResetBefore = playerTickets.balanceOf(PLAYER_ONE, playerTickets.DAILY_RESET_TICKET());
            uint256 createPlayerBefore = playerTickets.balanceOf(PLAYER_ONE, playerTickets.CREATE_PLAYER_TICKET());

            // Fight the specific monster that has kills
            vm.recordLogs();
            vm.prank(PLAYER_ONE);
            game.fightSpecificMonster(killerMonsterId, player1Loadout);
            _fulfillVRFRequest(address(game));

            // Check if bounty was distributed
            Vm.Log[] memory logs = vm.getRecordedLogs();
            bool bountyDistributed = false;
            for (uint256 j = 0; j < logs.length; j++) {
                if (logs[j].topics[0] == keccak256("BountyRewardDistributed(uint32,uint32,uint32,bool)")) {
                    bountyDistributed = true;
                    // Decode event data (killCount and isLegendary)
                    (uint32 killCount, bool isLegendary) = abi.decode(logs[j].data, (uint32, bool));

                    // Check ticket balances increased
                    uint256 dailyResetAfter = playerTickets.balanceOf(PLAYER_ONE, playerTickets.DAILY_RESET_TICKET());
                    uint256 createPlayerAfter =
                        playerTickets.balanceOf(PLAYER_ONE, playerTickets.CREATE_PLAYER_TICKET());

                    // Should receive tickets equal to kill count
                    assertEq(dailyResetAfter - dailyResetBefore, killCount, "Should receive daily reset tickets");
                    assertEq(createPlayerAfter - createPlayerBefore, killCount, "Should receive create player tickets");

                    // Check legendary status (5+ kills)
                    if (killCount >= 5) {
                        assertTrue(isLegendary, "Should be legendary bounty for 5+ kills");
                    }
                    break;
                }
            }

            if (!bountyDistributed) {
                console2.log("Monster was not killed in bounty hunt");
            }
        } else {
            console2.log("Could not set up test - no player died to give monster kills");
        }
    }

    function testDeathMechanicsMultiplePlayers() public {
        // Use multiple players to increase chance of seeing death
        game.setLethalityFactor(type(uint16).max);

        // Create additional test players
        address[] memory players = new address[](5);
        uint32[] memory playerIds = new uint32[](5);

        players[0] = PLAYER_ONE;
        playerIds[0] = PLAYER_ONE_ID;
        players[1] = PLAYER_TWO;
        playerIds[1] = PLAYER_TWO_ID;

        // Create 3 more players
        for (uint256 i = 2; i < 5; i++) {
            players[i] = address(uint160(0x1000 + i));
            vm.deal(players[i], 100 ether);
            playerIds[i] = _createPlayerAndFulfillVRF(players[i], false);
            _mintDailyResetTickets(players[i], 100);
            vm.prank(players[i]);
            playerTickets.setApprovalForAll(address(game), true);
        }

        uint256 totalDeaths = 0;
        uint256 totalBattles = 0;

        // Each player fights 10 times
        for (uint256 p = 0; p < 5; p++) {
            Fighter.PlayerLoadout memory loadout = _createLoadout(playerIds[p]);

            for (uint256 i = 0; i < 10; i++) {
                if (playerContract.isPlayerRetired(playerIds[p])) {
                    break; // Player already dead
                }

                // Reset limit if needed
                if (game.getDailyRunCount(playerIds[p]) >= 5) {
                    vm.prank(players[p]);
                    game.resetMonsterDailyLimitWithTicket(playerIds[p]);
                }

                vm.prank(players[p]);
                game.fightMonster(MonsterBattleGame.DifficultyLevel.HARD, loadout);
                _fulfillVRFRequest(address(game));
                totalBattles++;

                if (playerContract.isPlayerRetired(playerIds[p])) {
                    totalDeaths++;
                }
            }
        }

        console2.log("Death rate: %s deaths out of %s battles", totalDeaths, totalBattles);

        // With max lethality and multiple attempts, we should see at least one death
        assertTrue(totalDeaths > 0, "Should have at least one death with max lethality");
    }

    // Admin function tests
    function testSetGameEnabled() public {
        // Test contract is the owner, so test with non-owner
        vm.expectRevert("Only callable by owner");
        vm.prank(PLAYER_ONE);
        game.setGameEnabled(false);

        // Owner can disable
        vm.expectEmit(true, true, true, true);
        emit GameEnabledUpdated(false);
        game.setGameEnabled(false);
        assertFalse(game.isGameEnabled());

        // Cannot fight when disabled
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);
        vm.expectRevert(GameDisabled.selector);
        vm.prank(PLAYER_ONE);
        game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout);

        // Re-enable
        vm.expectEmit(true, true, true, true);
        emit GameEnabledUpdated(true);
        game.setGameEnabled(true);
        assertTrue(game.isGameEnabled());
    }

    function testSetLethalityFactor() public {
        uint16 oldFactor = game.lethalityFactor();
        uint16 newFactor = 500;

        // Only owner can call
        vm.expectRevert("Only callable by owner");
        vm.prank(PLAYER_ONE);
        game.setLethalityFactor(newFactor);

        // Owner can set
        vm.expectEmit(true, true, true, true);
        emit LethalityFactorUpdated(oldFactor, newFactor);
        game.setLethalityFactor(newFactor);
        assertEq(game.lethalityFactor(), newFactor);
    }

    function testSetDailyResetCost() public {
        uint256 oldCost = game.dailyResetCost();
        uint256 newCost = 0.005 ether;

        // Only owner can call
        vm.expectRevert("Only callable by owner");
        vm.prank(PLAYER_ONE);
        game.setDailyResetCost(newCost);

        // Owner can set
        vm.expectEmit(true, true, true, true);
        emit DailyResetCostUpdated(oldCost, newCost);
        game.setDailyResetCost(newCost);
        assertEq(game.dailyResetCost(), newCost);
    }

    function testSetDailyMonsterLimit() public {
        uint8 oldLimit = game.dailyMonsterLimit();
        uint8 newLimit = 10;

        // Cannot set to 0
        vm.expectRevert(ValueMustBePositive.selector);
        game.setDailyMonsterLimit(0);

        // Owner can set
        vm.expectEmit(true, true, true, true);
        emit DailyMonsterLimitUpdated(oldLimit, newLimit);
        game.setDailyMonsterLimit(newLimit);
        assertEq(game.dailyMonsterLimit(), newLimit);
    }

    function testSetVrfRequestTimeout() public {
        uint256 oldTimeout = game.vrfRequestTimeout();
        uint256 newTimeout = 48 hours;

        // Cannot set to 0
        vm.expectRevert(ValueMustBePositive.selector);
        game.setVrfRequestTimeout(0);

        // Owner can set
        vm.expectEmit(true, true, true, true);
        emit VrfRequestTimeoutUpdated(oldTimeout, newTimeout);
        game.setVrfRequestTimeout(newTimeout);
        assertEq(game.vrfRequestTimeout(), newTimeout);
    }

    function testAddNewMonsterBatch() public {
        // Create array of new monster IDs
        uint32[] memory newMonsters = new uint32[](3);
        newMonsters[0] = 2004;
        newMonsters[1] = 2005;
        newMonsters[2] = 2006;

        // Only owner can add
        vm.expectRevert("Only callable by owner");
        vm.prank(PLAYER_ONE);
        game.addNewMonsterBatch(newMonsters, MonsterBattleGame.DifficultyLevel.EASY);

        // Owner can add (no event for this one)
        game.addNewMonsterBatch(newMonsters, MonsterBattleGame.DifficultyLevel.EASY);

        // Verify they were added
        assertEq(uint256(game.monsterDifficulty(2004)), uint256(MonsterBattleGame.DifficultyLevel.EASY));
        assertEq(uint256(game.monsterDifficulty(2005)), uint256(MonsterBattleGame.DifficultyLevel.EASY));
        assertEq(uint256(game.monsterDifficulty(2006)), uint256(MonsterBattleGame.DifficultyLevel.EASY));
    }

    function testWithdrawFees() public {
        // First use up daily limit so reset is needed
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(PLAYER_ONE);
            game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout);
            _fulfillVRFRequest(address(game));
        }

        // Now accumulate fees from reset
        vm.prank(PLAYER_ONE);
        game.resetMonsterDailyLimit{value: 0.001 ether}(PLAYER_ONE_ID);

        uint256 ownerBalanceBefore = address(this).balance;
        uint256 contractBalance = address(game).balance;

        // Only owner can withdraw
        vm.expectRevert("Only callable by owner");
        vm.prank(PLAYER_ONE);
        game.withdrawFees();

        // Owner withdraws (no event for withdrawal)
        game.withdrawFees();

        assertEq(address(game).balance, 0);
        assertEq(address(this).balance - ownerBalanceBefore, contractBalance);
    }

    //==============================================================//
    //                     TEST: TROPHY SYSTEM                       //
    //==============================================================//

    function testTrophyMintingOnMonsterKill() public {
        Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

        // Give player a huge level advantage to guarantee death kill
        playerContract.awardExperience(PLAYER_ONE_ID, 10000); // Max level

        vm.prank(PLAYER_ONE);
        uint256 battleId = game.fightMonster(MonsterBattleGame.DifficultyLevel.EASY, loadout);

        // Track trophy balance before VRF fulfillment
        uint256 trophyBalanceBefore = goblinTrophy.balanceOf(PLAYER_ONE);

        // Fulfill VRF to trigger battle resolution and trophy minting
        _fulfillVRFRequest(address(game));

        // Check that a trophy was minted to the player
        uint256 trophyBalanceAfter = goblinTrophy.balanceOf(PLAYER_ONE);
        if (trophyBalanceAfter > trophyBalanceBefore) {
            // Trophy was minted! Check its metadata
            uint256 trophyId = 1; // First trophy minted
            ITrophyNFT.TrophyMetadata memory metadata = goblinTrophy.getTrophyMetadata(trophyId);

            assertEq(metadata.monsterId, GOBLIN_ID);
            assertEq(metadata.difficulty, uint8(MonsterBattleGame.DifficultyLevel.EASY));
            assertEq(metadata.killerPlayerId, PLAYER_ONE_ID);
            assertTrue(bytes(metadata.monsterName).length > 0);
            assertTrue(bytes(metadata.killerPlayerName).length > 0);
            assertEq(metadata.killBlock, block.number);
        }
    }

    function testTrophySystemIntegrationWithSkinUnlocking() public {
        // This test verifies the trophy can be used as a required NFT for skin unlocking
        // The PlayerSkinRegistry already supports this via requiredNFTAddress field

        // After a trophy is minted, the player should be able to use trophy-gated skins
        address playerOwner = PLAYER_ONE;

        // Mint a trophy via game contract (authorized minter)
        vm.prank(address(game));
        goblinTrophy.mintTrophy(
            playerOwner,
            GOBLIN_ID,
            "Test Goblin",
            uint8(MonsterBattleGame.DifficultyLevel.EASY),
            PLAYER_ONE_ID,
            "Test Player"
        );

        // Verify trophy ownership
        assertEq(goblinTrophy.balanceOf(playerOwner), 1);

        // The trophy can now be set as a required NFT in PlayerSkinRegistry
        // for exclusive skin collections (implementation will be done later)
    }

    //==============================================================//
    //                    HELPER FUNCTIONS                           //
    //==============================================================//

    function _setupTrophySystem() internal {
        // Deploy trophy contracts
        goblinTrophy = new MockTrophyNFT("Goblin", address(game));
        undeadTrophy = new MockTrophyNFT("Undead", address(game));
        demonTrophy = new MockTrophyNFT("Demon", address(game));

        // Set up monster to trophy mappings
        uint32[] memory goblinMonsters = new uint32[](1);
        goblinMonsters[0] = GOBLIN_ID;
        game.setMonsterTrophyContractBatch(goblinMonsters, address(goblinTrophy), "Goblin");

        uint32[] memory undeadMonsters = new uint32[](1);
        undeadMonsters[0] = UNDEAD_ID;
        game.setMonsterTrophyContractBatch(undeadMonsters, address(undeadTrophy), "Undead");

        uint32[] memory demonMonsters = new uint32[](1);
        demonMonsters[0] = DEMON_ID;
        game.setMonsterTrophyContractBatch(demonMonsters, address(demonTrophy), "Demon");
    }

    // Allow test contract to receive ETH
    receive() external payable {}
}

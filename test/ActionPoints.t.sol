// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {GameEngine} from "../src/GameEngine.sol";
import {IGameDefinitions} from "../src/interfaces/IGameDefinitions.sol";
import {IPlayer} from "../src/interfaces/IPlayer.sol";
import {IGameEngine} from "../src/interfaces/IGameEngine.sol";
import "./utils/TestBase.sol";
import "../src/lib/DefaultPlayerLibrary.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";
import {Player} from "../src/Player.sol";

contract ActionPointsTest is TestBase {
    GameEngine public gameEngine;
    address public PLAYER_ONE;
    address public PLAYER_TWO;
    DefaultCharacters public chars;

    function setUp() public override {
        super.setUp();

        // Set up test addresses
        PLAYER_ONE = address(0x1111);
        PLAYER_TWO = address(0x2222);

        // Set up the test environment with a proper timestamp
        vm.warp(1692803367 + 1000); // Set timestamp to after genesis

        // Deploy contracts in correct order
        nameRegistry = new PlayerNameRegistry();

        // Deploy Player contract with dependencies
        playerContract = new Player(address(skinRegistry), address(nameRegistry), operator);

        // Deploy Game contracts
        gameEngine = new GameEngine();

        // Mint default characters for testing
        mintDefaultCharacters();
    }

    function mintDefaultCharacters() internal {
        // Create offensive characters
        (
            IGameDefinitions.WeaponType weapon,
            IGameDefinitions.ArmorType armor,
            IGameDefinitions.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        ) = DefaultPlayerLibrary.getOffensiveTestWarrior(skinIndex, 2);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 2);
        chars.greatswordOffensive = 2;

        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getOffensiveTestWarrior(skinIndex, 3);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 3);
        chars.battleaxeOffensive = 3;

        // Create balanced character
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getDefaultWarrior(skinIndex, 4);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 4);
        chars.spearBalanced = 4;

        // Create defensive characters
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getSwordAndShieldUser(skinIndex, 5);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 5);
        chars.swordAndShieldDefensive = 5;

        // Add rapier and shield defensive character
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getRapierAndShieldUser(skinIndex, 6);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 6);
        chars.rapierAndShieldDefensive = 6;
    }

    function test_FastVsSlow() public {
        // Create two players with different loadouts
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);

        // Create loadouts using TestBase helpers
        IGameEngine.PlayerLoadout memory fastLoadout = IGameEngine.PlayerLoadout({
            playerId: player1Id,
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });
        IGameEngine.PlayerLoadout memory slowLoadout = IGameEngine.PlayerLoadout({
            playerId: player2Id,
            skinIndex: skinIndex,
            skinTokenId: chars.swordAndShieldDefensive
        });

        // Get combat loadouts
        IGameEngine.CombatLoadout memory fast = _convertToLoadout(fastLoadout);
        IGameEngine.CombatLoadout memory slow = _convertToLoadout(slowLoadout);

        // Run combat simulation
        uint256 seed = _generateGameSeed();
        bytes memory results = gameEngine.processGame(fast, slow, seed, 0);

        // Decode and verify results
        (uint256 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Validate combat results
        _assertValidCombatResult(winner, version, condition, actions, player1Id, player2Id);

        // Additional action point specific assertions can go here
        assertTrue(actions.length > 0, "Should have recorded combat actions");
    }

    function test_EqualSpeed() public {
        // Create two players
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);

        // Create loadouts with same speed weapons
        IGameEngine.PlayerLoadout memory p1Loadout =
            IGameEngine.PlayerLoadout({playerId: player1Id, skinIndex: skinIndex, skinTokenId: chars.spearBalanced});
        IGameEngine.PlayerLoadout memory p2Loadout =
            IGameEngine.PlayerLoadout({playerId: player2Id, skinIndex: skinIndex, skinTokenId: chars.spearBalanced});

        // Convert to combat loadouts
        IGameEngine.CombatLoadout memory p1 = _convertToLoadout(p1Loadout);
        IGameEngine.CombatLoadout memory p2 = _convertToLoadout(p2Loadout);

        bytes memory results = gameEngine.processGame(p1, p2, _generateGameSeed(), 0);
        (uint256 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Validate combat results
        _assertValidCombatResult(winner, version, condition, actions, player1Id, player2Id);
    }

    function test_VerySlowWeapons() public {
        // Create two players
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);

        // Create loadouts with different slow weapons
        IGameEngine.PlayerLoadout memory p1Loadout = IGameEngine.PlayerLoadout({
            playerId: player1Id,
            skinIndex: skinIndex,
            skinTokenId: chars.swordAndShieldDefensive
        });
        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: player2Id,
            skinIndex: skinIndex,
            skinTokenId: chars.rapierAndShieldDefensive
        });

        // Convert to combat loadouts
        IGameEngine.CombatLoadout memory p1 = _convertToLoadout(p1Loadout);
        IGameEngine.CombatLoadout memory p2 = _convertToLoadout(p2Loadout);

        bytes memory results = gameEngine.processGame(p1, p2, _generateGameSeed(), 0);
        (uint256 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Validate combat results
        _assertValidCombatResult(winner, version, condition, actions, player1Id, player2Id);
        assertTrue(actions.length > 0, "Combat should have at least one action");
    }
}

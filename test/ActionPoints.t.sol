// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {GameEngine} from "../src/GameEngine.sol";
import {IGameEngine} from "../src/interfaces/IGameEngine.sol";
import "./utils/TestBase.sol";
import "../src/lib/DefaultPlayerLibrary.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";
import {Player} from "../src/Player.sol";

contract ActionPointsTest is TestBase {
    address public PLAYER_ONE;
    address public PLAYER_TWO;

    function setUp() public override {
        super.setUp();

        // Set up test addresses
        PLAYER_ONE = address(0x1111);
        PLAYER_TWO = address(0x2222);
    }

    function test_FastVsSlow() public {
        // Create two players with different loadouts
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

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
        IGameEngine.FighterStats memory fast = _convertToLoadout(fastLoadout);
        IGameEngine.FighterStats memory slow = _convertToLoadout(slowLoadout);

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
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

        // Create loadouts with same speed weapons
        IGameEngine.PlayerLoadout memory p1Loadout =
            IGameEngine.PlayerLoadout({playerId: player1Id, skinIndex: skinIndex, skinTokenId: chars.spearBalanced});
        IGameEngine.PlayerLoadout memory p2Loadout =
            IGameEngine.PlayerLoadout({playerId: player2Id, skinIndex: skinIndex, skinTokenId: chars.spearBalanced});

        // Convert to combat loadouts
        IGameEngine.FighterStats memory p1 = _convertToLoadout(p1Loadout);
        IGameEngine.FighterStats memory p2 = _convertToLoadout(p2Loadout);

        bytes memory results = gameEngine.processGame(p1, p2, _generateGameSeed(), 0);
        (uint256 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Validate combat results
        _assertValidCombatResult(winner, version, condition, actions, player1Id, player2Id);
    }

    function test_VerySlowWeapons() public {
        // Create two players
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

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
        IGameEngine.FighterStats memory p1 = _convertToLoadout(p1Loadout);
        IGameEngine.FighterStats memory p2 = _convertToLoadout(p2Loadout);

        bytes memory results = gameEngine.processGame(p1, p2, _generateGameSeed(), 0);
        (uint256 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        // Validate combat results
        _assertValidCombatResult(winner, version, condition, actions, player1Id, player2Id);
        assertTrue(actions.length > 0, "Combat should have at least one action");
    }
}

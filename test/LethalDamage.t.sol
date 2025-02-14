// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {GameEngine} from "../src/GameEngine.sol";
import {IGameEngine} from "../src/interfaces/IGameEngine.sol";
import "./utils/TestBase.sol";
import "../src/lib/DefaultPlayerLibrary.sol";

contract LethalDamageTest is TestBase {
    address public PLAYER_ONE;
    address public PLAYER_TWO;
    uint32 public PLAYER_ONE_ID;
    uint32 public PLAYER_TWO_ID;

    function setUp() public override {
        super.setUp();

        // Set up test addresses
        PLAYER_ONE = address(0x1111);
        PLAYER_TWO = address(0x2222);
    }

    function test_NonLethalMode() public skipInCI {
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

        // Create offensive loadouts
        IGameEngine.PlayerLoadout memory p1Loadout = IGameEngine.PlayerLoadout({
            playerId: player1Id,
            skinIndex: defaultSkinIndex,
            skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.BattleaxeOffensive) + 1
        });
        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: player2Id,
            skinIndex: defaultSkinIndex,
            skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1
        });

        bytes memory results = gameEngine.processGame(
            _convertToLoadout(p1Loadout),
            _convertToLoadout(p2Loadout),
            _generateGameSeed(),
            0 // lethalityFactor = 0
        );

        (bool player1Won, uint16 version, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions)
        = gameEngine.decodeCombatLog(results);
        _assertValidCombatResult(version, condition, actions);
        assertTrue(condition != IGameEngine.WinCondition.DEATH, "Death should not occur in non-lethal mode");
    }

    function test_BaseLethalMode() public skipInCI {
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

        // Create offensive loadouts
        IGameEngine.PlayerLoadout memory p1Loadout = IGameEngine.PlayerLoadout({
            playerId: player1Id,
            skinIndex: defaultSkinIndex,
            skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.BattleaxeOffensive) + 1
        });
        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: player2Id,
            skinIndex: defaultSkinIndex,
            skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1
        });

        uint256 deathCount = 0;
        uint256 totalFights = 50;

        for (uint256 i = 0; i < totalFights; i++) {
            bytes memory results = gameEngine.processGame(
                _convertToLoadout(p1Loadout),
                _convertToLoadout(p2Loadout),
                _generateGameSeed() + i,
                50 // Base lethality (0.5x)
            );

            (
                bool player1Won,
                uint16 version,
                IGameEngine.WinCondition condition,
                IGameEngine.CombatAction[] memory actions
            ) = gameEngine.decodeCombatLog(results);
            _assertValidCombatResult(version, condition, actions);

            if (condition == IGameEngine.WinCondition.DEATH) {
                deathCount++;
            }
        }

        console2.log("Deaths in base lethality mode: ", deathCount);
        console2.log("Total fights: ", totalFights);
        assertTrue(deathCount > 0, "Should have some deaths in lethal mode");
    }

    function test_HighLethalityMode() public skipInCI {
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

        // Create offensive loadouts
        IGameEngine.PlayerLoadout memory p1Loadout = IGameEngine.PlayerLoadout({
            playerId: player1Id,
            skinIndex: defaultSkinIndex,
            skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.BattleaxeOffensive) + 1
        });
        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: player2Id,
            skinIndex: defaultSkinIndex,
            skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1
        });

        uint256 deathCount = 0;
        uint256 totalFights = 20;

        for (uint256 i = 0; i < totalFights; i++) {
            bytes memory results = gameEngine.processGame(
                _convertToLoadout(p1Loadout),
                _convertToLoadout(p2Loadout),
                _generateGameSeed() + i,
                100 // Base lethality (1x)
            );

            (
                bool player1Won,
                uint16 version,
                IGameEngine.WinCondition condition,
                IGameEngine.CombatAction[] memory actions
            ) = gameEngine.decodeCombatLog(results);
            _assertValidCombatResult(version, condition, actions);

            if (condition == IGameEngine.WinCondition.DEATH) {
                deathCount++;
            }
        }

        console2.log("Deaths in high lethality mode: ", deathCount);
        console2.log("Total fights: ", totalFights);
        assertTrue(deathCount > 0, "Should have deaths in high lethality mode");
    }

    function test_MixedLoadoutLethalMode() public skipInCI {
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

        // Create offensive vs defensive loadouts
        IGameEngine.PlayerLoadout memory p1Loadout = IGameEngine.PlayerLoadout({
            playerId: player1Id,
            skinIndex: defaultSkinIndex,
            skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.BattleaxeOffensive) + 1
        });
        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: player2Id,
            skinIndex: defaultSkinIndex,
            skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.RapierAndShieldDefensive) + 1
        });

        uint256 deathCount = 0;
        uint256 totalFights = 100;

        for (uint256 i = 0; i < totalFights; i++) {
            bytes memory results = gameEngine.processGame(
                _convertToLoadout(p1Loadout),
                _convertToLoadout(p2Loadout),
                _generateGameSeed() + i,
                100 // Base lethality (1x)
            );

            (
                bool player1Won,
                uint16 version,
                IGameEngine.WinCondition condition,
                IGameEngine.CombatAction[] memory actions
            ) = gameEngine.decodeCombatLog(results);
            _assertValidCombatResult(version, condition, actions);

            if (condition == IGameEngine.WinCondition.DEATH) {
                deathCount++;
            }
        }

        console2.log("Deaths in mixed loadout mode: ", deathCount);
        console2.log("Total fights: ", totalFights);
        assertTrue(deathCount > 0, "Should have some deaths in lethal mode");
        //assertTrue(deathCount < totalFights / 2, "Should have lower death rate with defensive loadout");
    }

    function test_ExtraBrutalLethalityMode() public skipInCI {
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

        // Create offensive loadouts
        IGameEngine.PlayerLoadout memory p1Loadout = IGameEngine.PlayerLoadout({
            playerId: player1Id,
            skinIndex: defaultSkinIndex,
            skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.BattleaxeOffensive) + 1
        });
        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: player2Id,
            skinIndex: defaultSkinIndex,
            skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1
        });

        uint256 deathCount = 0;
        uint256 totalFights = 20;

        for (uint256 i = 0; i < totalFights; i++) {
            bytes memory results = gameEngine.processGame(
                _convertToLoadout(p1Loadout),
                _convertToLoadout(p2Loadout),
                _generateGameSeed() + i,
                200 // Extra brutal lethality (2x brutal)
            );

            (
                bool player1Won,
                uint16 version,
                IGameEngine.WinCondition condition,
                IGameEngine.CombatAction[] memory actions
            ) = gameEngine.decodeCombatLog(results);
            _assertValidCombatResult(version, condition, actions);

            if (condition == IGameEngine.WinCondition.DEATH) {
                deathCount++;
            }
        }

        console2.log("Deaths in extra brutal lethality mode: ", deathCount);
        console2.log("Total fights: ", totalFights);
        assertTrue(deathCount > 0, "Should have deaths in extra brutal mode");
        //assertTrue(deathCount > totalFights / 2, "Should have very high death rate in extra brutal mode");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {GameEngine} from "../src/GameEngine.sol";
import {IGameDefinitions} from "../src/interfaces/IGameDefinitions.sol";
import {IPlayer} from "../src/interfaces/IPlayer.sol";
import {IGameEngine} from "../src/interfaces/IGameEngine.sol";
import "./utils/TestBase.sol";
import "../src/lib/DefaultPlayerLibrary.sol";

contract LethalDamageTest is TestBase {
    GameEngine public gameEngine;
    address public PLAYER_ONE;
    address public PLAYER_TWO;
    uint32 public PLAYER_ONE_ID;
    uint32 public PLAYER_TWO_ID;
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

    function test_NonLethalMode() public {
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);

        // Create offensive loadouts
        IGameEngine.PlayerLoadout memory p1Loadout = IGameEngine.PlayerLoadout({
            playerId: player1Id,
            skinIndex: skinIndex,
            skinTokenId: chars.battleaxeOffensive
        });
        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: player2Id,
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
        });

        bytes memory results = gameEngine.processGame(
            _convertToLoadout(p1Loadout),
            _convertToLoadout(p2Loadout),
            _generateGameSeed(),
            0 // lethalityFactor = 0
        );

        (uint256 winner, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);

        _assertValidCombatResult(winner, version, condition, actions, player1Id, player2Id);
        assertTrue(condition != GameEngine.WinCondition.DEATH, "Death should not occur in non-lethal mode");
    }

    function test_BaseLethalMode() public {
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);

        // Create offensive loadouts
        IGameEngine.PlayerLoadout memory p1Loadout = IGameEngine.PlayerLoadout({
            playerId: player1Id,
            skinIndex: skinIndex,
            skinTokenId: chars.battleaxeOffensive
        });
        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: player2Id,
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
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
                uint256 winner,
                uint16 version,
                GameEngine.WinCondition condition,
                GameEngine.CombatAction[] memory actions
            ) = gameEngine.decodeCombatLog(results);

            _assertValidCombatResult(winner, version, condition, actions, player1Id, player2Id);

            if (condition == GameEngine.WinCondition.DEATH) {
                deathCount++;
            }
        }

        console2.log("Deaths in base lethality mode: ", deathCount);
        console2.log("Total fights: ", totalFights);
        assertTrue(deathCount > 0, "Should have some deaths in lethal mode");
        assertTrue(deathCount < totalFights, "Should not have 100% death rate");
    }

    function test_HighLethalityMode() public {
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);

        // Create offensive loadouts
        IGameEngine.PlayerLoadout memory p1Loadout = IGameEngine.PlayerLoadout({
            playerId: player1Id,
            skinIndex: skinIndex,
            skinTokenId: chars.battleaxeOffensive
        });
        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: player2Id,
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
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
                uint256 winner,
                uint16 version,
                GameEngine.WinCondition condition,
                GameEngine.CombatAction[] memory actions
            ) = gameEngine.decodeCombatLog(results);

            _assertValidCombatResult(winner, version, condition, actions, player1Id, player2Id);

            if (condition == GameEngine.WinCondition.DEATH) {
                deathCount++;
            }
        }

        console2.log("Deaths in high lethality mode: ", deathCount);
        console2.log("Total fights: ", totalFights);
        assertTrue(deathCount > 0, "Should have deaths in high lethality mode");
        assertTrue(deathCount > totalFights / 4, "Should have higher death rate in high lethality mode");
    }

    function test_MixedLoadoutLethalMode() public {
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);

        // Create offensive vs defensive loadouts
        IGameEngine.PlayerLoadout memory p1Loadout = IGameEngine.PlayerLoadout({
            playerId: player1Id,
            skinIndex: skinIndex,
            skinTokenId: chars.battleaxeOffensive
        });
        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: player2Id,
            skinIndex: skinIndex,
            skinTokenId: chars.rapierAndShieldDefensive
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
                uint256 winner,
                uint16 version,
                GameEngine.WinCondition condition,
                GameEngine.CombatAction[] memory actions
            ) = gameEngine.decodeCombatLog(results);

            _assertValidCombatResult(winner, version, condition, actions, player1Id, player2Id);

            if (condition == GameEngine.WinCondition.DEATH) {
                deathCount++;
            }
        }

        console2.log("Deaths in mixed loadout mode: ", deathCount);
        console2.log("Total fights: ", totalFights);
        assertTrue(deathCount > 0, "Should have some deaths in lethal mode");
        assertTrue(deathCount < totalFights / 2, "Should have lower death rate with defensive loadout");
    }

    function test_ExtraBrutalLethalityMode() public {
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);

        // Create offensive loadouts
        IGameEngine.PlayerLoadout memory p1Loadout = IGameEngine.PlayerLoadout({
            playerId: player1Id,
            skinIndex: skinIndex,
            skinTokenId: chars.battleaxeOffensive
        });
        IGameEngine.PlayerLoadout memory p2Loadout = IGameEngine.PlayerLoadout({
            playerId: player2Id,
            skinIndex: skinIndex,
            skinTokenId: chars.greatswordOffensive
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
                uint256 winner,
                uint16 version,
                GameEngine.WinCondition condition,
                GameEngine.CombatAction[] memory actions
            ) = gameEngine.decodeCombatLog(results);

            _assertValidCombatResult(winner, version, condition, actions, player1Id, player2Id);

            if (condition == GameEngine.WinCondition.DEATH) {
                deathCount++;
            }
        }

        console2.log("Deaths in extra brutal lethality mode: ", deathCount);
        console2.log("Total fights: ", totalFights);
        assertTrue(deathCount > 0, "Should have deaths in extra brutal mode");
        assertTrue(deathCount > totalFights / 2, "Should have very high death rate in extra brutal mode");
    }
}

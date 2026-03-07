// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {console2} from "forge-std/console2.sol";
import {GameEngine} from "../../src/game/engine/GameEngine.sol";
import {IGameEngine} from "../../src/interfaces/game/engine/IGameEngine.sol";
import {TestBase} from "../TestBase.sol";
import {DefaultPlayerLibrary} from "../../src/fighters/lib/DefaultPlayerLibrary.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";

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

    function testFuzz_NonLethalMode(uint256 seed) public {
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

        Fighter.PlayerLoadout memory p1Loadout = Fighter.PlayerLoadout({
            playerId: player1Id,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: 4 // BattleaxeOffensive
            }),
            stance: 2
        });
        Fighter.PlayerLoadout memory p2Loadout = Fighter.PlayerLoadout({
            playerId: player2Id,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: 3 // GreatswordOffensive
            }),
            stance: 2
        });

        _getFighterContract(p1Loadout.playerId);
        _getFighterContract(p2Loadout.playerId);

        bytes memory results = gameEngine.processGame(
            _convertToFighterStats(p1Loadout),
            _convertToFighterStats(p2Loadout),
            seed,
            0 // lethalityFactor = 0
        );

        (, uint16 version, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);
        _assertValidCombatResult(version, condition, actions);
        assertTrue(condition != IGameEngine.WinCondition.DEATH, "Death should not occur in non-lethal mode");
    }

    function testFuzz_BaseLethalMode(uint256 seed) public {
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

        Fighter.PlayerLoadout memory p1Loadout = Fighter.PlayerLoadout({
            playerId: player1Id,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: 4 // BattleaxeOffensive
            }),
            stance: 2
        });
        Fighter.PlayerLoadout memory p2Loadout = Fighter.PlayerLoadout({
            playerId: player2Id,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: 3 // GreatswordOffensive
            }),
            stance: 2
        });

        _getFighterContract(p1Loadout.playerId);
        _getFighterContract(p2Loadout.playerId);

        uint256 deathCount = 0;
        uint256 totalFights = 100;

        for (uint256 i = 0; i < totalFights; i++) {
            uint256 matchSeed = uint256(keccak256(abi.encodePacked(seed, i)));
            bytes memory results = gameEngine.processGame(
                _convertToFighterStats(p1Loadout),
                _convertToFighterStats(p2Loadout),
                matchSeed,
                50 // Base lethality (0.5x)
            );

            (, uint16 version, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) =
                gameEngine.decodeCombatLog(results);
            _assertValidCombatResult(version, condition, actions);

            if (condition == IGameEngine.WinCondition.DEATH) {
                deathCount++;
            }
        }

        console2.log("Deaths in base lethality mode: ", deathCount);
        console2.log("Total fights: ", totalFights);
        assertTrue(deathCount > 0, "Should have some deaths in lethal mode");
    }

    function testFuzz_HighLethalityMode(uint256 seed) public {
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

        Fighter.PlayerLoadout memory p1Loadout = Fighter.PlayerLoadout({
            playerId: player1Id,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: 4 // BattleaxeOffensive
            }),
            stance: 2
        });
        Fighter.PlayerLoadout memory p2Loadout = Fighter.PlayerLoadout({
            playerId: player2Id,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: 3 // GreatswordOffensive
            }),
            stance: 2
        });

        _getFighterContract(p1Loadout.playerId);
        _getFighterContract(p2Loadout.playerId);

        uint256 deathCount = 0;
        uint256 totalFights = 50;

        for (uint256 i = 0; i < totalFights; i++) {
            uint256 matchSeed = uint256(keccak256(abi.encodePacked(seed, i)));
            bytes memory results = gameEngine.processGame(
                _convertToFighterStats(p1Loadout),
                _convertToFighterStats(p2Loadout),
                matchSeed,
                100 // Base lethality (1x)
            );

            (, uint16 version, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) =
                gameEngine.decodeCombatLog(results);
            _assertValidCombatResult(version, condition, actions);

            if (condition == IGameEngine.WinCondition.DEATH) {
                deathCount++;
            }
        }

        console2.log("Deaths in high lethality mode: ", deathCount);
        console2.log("Total fights: ", totalFights);
        assertTrue(deathCount > 0, "Should have deaths in high lethality mode");
    }

    function testFuzz_MixedLoadoutLethalMode(uint256 seed) public {
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

        Fighter.PlayerLoadout memory p1Loadout = Fighter.PlayerLoadout({
            playerId: player1Id,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: 4 // BattleaxeOffensive
            }),
            stance: 2
        });
        Fighter.PlayerLoadout memory p2Loadout = Fighter.PlayerLoadout({
            playerId: player2Id,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: 7 // RapierShieldDefensive
            }),
            stance: 0
        });

        _getFighterContract(p1Loadout.playerId);
        _getFighterContract(p2Loadout.playerId);

        uint256 deathCount = 0;
        uint256 totalFights = 100;

        for (uint256 i = 0; i < totalFights; i++) {
            uint256 matchSeed = uint256(keccak256(abi.encodePacked(seed, i)));
            bytes memory results = gameEngine.processGame(
                _convertToFighterStats(p1Loadout),
                _convertToFighterStats(p2Loadout),
                matchSeed,
                100 // Base lethality (1x)
            );

            (, uint16 version, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) =
                gameEngine.decodeCombatLog(results);
            _assertValidCombatResult(version, condition, actions);

            if (condition == IGameEngine.WinCondition.DEATH) {
                deathCount++;
            }
        }

        console2.log("Deaths in mixed loadout mode: ", deathCount);
        console2.log("Total fights: ", totalFights);
        assertTrue(deathCount > 0, "Should have some deaths in lethal mode");
    }

    function testFuzz_ExtraBrutalLethalityMode(uint256 seed) public {
        uint32 player1Id = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        uint32 player2Id = _createPlayerAndFulfillVRF(PLAYER_TWO, false);

        Fighter.PlayerLoadout memory p1Loadout = Fighter.PlayerLoadout({
            playerId: player1Id,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: 4 // BattleaxeOffensive
            }),
            stance: 2
        });
        Fighter.PlayerLoadout memory p2Loadout = Fighter.PlayerLoadout({
            playerId: player2Id,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: 3 // GreatswordOffensive
            }),
            stance: 2
        });

        _getFighterContract(p1Loadout.playerId);
        _getFighterContract(p2Loadout.playerId);

        uint256 deathCount = 0;
        uint256 totalFights = 50;

        for (uint256 i = 0; i < totalFights; i++) {
            uint256 matchSeed = uint256(keccak256(abi.encodePacked(seed, i)));
            bytes memory results = gameEngine.processGame(
                _convertToFighterStats(p1Loadout),
                _convertToFighterStats(p2Loadout),
                matchSeed,
                200 // Extra brutal lethality (2x brutal)
            );

            (, uint16 version, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) =
                gameEngine.decodeCombatLog(results);
            _assertValidCombatResult(version, condition, actions);

            if (condition == IGameEngine.WinCondition.DEATH) {
                deathCount++;
            }
        }

        console2.log("Deaths in extra brutal lethality mode: ", deathCount);
        console2.log("Total fights: ", totalFights);
        assertTrue(deathCount > 0, "Should have deaths in extra brutal mode");
    }
}

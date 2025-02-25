// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IGameEngine} from "../../src/interfaces/game/engine/IGameEngine.sol";
import "../TestBase.sol";
import {DefaultPlayerLibrary} from "../../src/fighters/lib/DefaultPlayerLibrary.sol";
import {PlayerNameRegistry} from "../../src/fighters/registries/names/PlayerNameRegistry.sol";
import {Player} from "../../src/fighters/Player.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";

contract ActionPointsTest is TestBase {
    function setUp() public override {
        super.setUp();
    }

    function test_DoubleAttack() public view {
        uint16 fastWeaponId = uint16(DefaultPlayerLibrary.CharacterType.RapierAndShieldDefensive) + 1;
        uint16 slowWeaponId = uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1;

        Fighter.PlayerLoadout memory fastLoadout = Fighter.PlayerLoadout({
            playerId: fastWeaponId,
            skin: Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: fastWeaponId})
        });

        Fighter.PlayerLoadout memory slowLoadout = Fighter.PlayerLoadout({
            playerId: slowWeaponId,
            skin: Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: slowWeaponId})
        });

        IGameEngine.FighterStats memory fastStats =
            _getFighterContract(fastLoadout.playerId).convertToFighterStats(fastLoadout);
        IGameEngine.FighterStats memory slowStats =
            _getFighterContract(slowLoadout.playerId).convertToFighterStats(slowLoadout);

        bytes memory results = gameEngine.processGame(fastStats, slowStats, _generateGameSeed(), 0);

        (
            bool player1Won,
            uint16 gameEngineVersion,
            IGameEngine.WinCondition condition,
            IGameEngine.CombatAction[] memory actions
        ) = gameEngine.decodeCombatLog(results);

        uint256 fastAttacks = 0;
        uint256 slowAttacks = 0;

        for (uint256 i = 0; i < actions.length; i++) {
            if (!_isDefensiveResult(actions[i].p1Result)) {
                fastAttacks++;
            }
            if (!_isDefensiveResult(actions[i].p2Result)) {
                slowAttacks++;
            }
        }

        // Assert ratio is between 1.5 and 3.0 (using integer math)
        // 15/10 = 1.5, 30/10 = 3.0
        require(
            fastAttacks * 10 >= slowAttacks * 15 && fastAttacks * 10 <= slowAttacks * 30,
            "Fast weapon should attack roughly twice as often as slow weapon"
        );
    }

    function test_DoubleAttackPlayerBias() public view {
        uint16 fastWeaponId = uint16(DefaultPlayerLibrary.CharacterType.RapierAndShieldDefensive) + 1;
        uint16 slowWeaponId = uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1;

        Fighter.PlayerLoadout memory fastLoadout = Fighter.PlayerLoadout({
            playerId: fastWeaponId,
            skin: Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: fastWeaponId})
        });

        Fighter.PlayerLoadout memory slowLoadout = Fighter.PlayerLoadout({
            playerId: slowWeaponId,
            skin: Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: slowWeaponId})
        });

        bytes memory results = gameEngine.processGame(
            _getFighterContract(slowLoadout.playerId).convertToFighterStats(slowLoadout),
            _getFighterContract(fastLoadout.playerId).convertToFighterStats(fastLoadout),
            _generateGameSeed(),
            0
        );

        (,,, IGameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(results);

        uint256 fastAttacks = 0;
        uint256 slowAttacks = 0;

        for (uint256 i = 0; i < actions.length; i++) {
            if (!_isDefensiveResult(actions[i].p2Result)) {
                fastAttacks++;
            }
            if (!_isDefensiveResult(actions[i].p1Result)) {
                slowAttacks++;
            }
        }

        // Assert ratio is between 1.5 and 3.0 (using integer math)
        // 15/10 = 1.5, 30/10 = 3.0
        require(
            fastAttacks * 10 >= slowAttacks * 15 && fastAttacks * 10 <= slowAttacks * 30,
            "Fast weapon should attack roughly twice as often as slow weapon"
        );
    }

    function test_SameWeaponInitiative() public view {
        uint16 weaponId = uint16(DefaultPlayerLibrary.CharacterType.DefaultWarrior) + 1;

        Fighter.PlayerLoadout memory p1Loadout = Fighter.PlayerLoadout({
            playerId: weaponId,
            skin: Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: weaponId})
        });

        Fighter.PlayerLoadout memory p2Loadout = Fighter.PlayerLoadout({
            playerId: weaponId,
            skin: Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: weaponId})
        });

        bytes memory results = gameEngine.processGame(
            _getFighterContract(p1Loadout.playerId).convertToFighterStats(p1Loadout),
            _getFighterContract(p2Loadout.playerId).convertToFighterStats(p2Loadout),
            _generateGameSeed(),
            0
        );

        (,,, IGameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(results);

        uint256 p1Attacks = 0;
        uint256 p2Attacks = 0;

        for (uint256 i = 0; i < actions.length; i++) {
            if (!_isDefensiveResult(actions[i].p1Result)) {
                p1Attacks++;
            }
            if (!_isDefensiveResult(actions[i].p2Result)) {
                p2Attacks++;
            }
        }

        // Assert attack counts differ by at most 1
        require(
            p1Attacks == p2Attacks || p1Attacks == p2Attacks + 1 || p1Attacks + 1 == p2Attacks,
            "Attack counts should differ by at most 1"
        );

        // Assert perfect alternating pattern between P1 and P2
        for (uint256 i = 0; i < actions.length; i++) {
            bool p1Attacked = !_isDefensiveResult(actions[i].p1Result);
            bool p2Attacked = !_isDefensiveResult(actions[i].p2Result);
            require(p1Attacked != p2Attacked, "Each round should have exactly one attacker");
        }
    }
}

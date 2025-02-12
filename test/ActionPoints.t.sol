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
    function setUp() public override {
        super.setUp();
    }

    function test_QuarterstaffDoubleAttack() public view {
        uint16 fastWeaponId = uint16(DefaultPlayerLibrary.CharacterType.QuarterstaffDefensive) + 1;
        uint16 slowWeaponId = uint16(DefaultPlayerLibrary.CharacterType.BattleaxeOffensive) + 1;

        IGameEngine.PlayerLoadout memory fastLoadout =
            IGameEngine.PlayerLoadout({playerId: fastWeaponId, skinIndex: defaultSkinIndex, skinTokenId: fastWeaponId});

        IGameEngine.PlayerLoadout memory slowLoadout =
            IGameEngine.PlayerLoadout({playerId: slowWeaponId, skinIndex: defaultSkinIndex, skinTokenId: slowWeaponId});

        bytes memory results = gameEngine.processGame(
            _convertToLoadout(fastLoadout), _convertToLoadout(slowLoadout), _generateGameSeed(), 0
        );

        (,,, GameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(results);

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

    function test_QuarterstaffDoubleAttackPlayerBias() public view {
        uint16 fastWeaponId = uint16(DefaultPlayerLibrary.CharacterType.QuarterstaffDefensive) + 1;
        uint16 slowWeaponId = uint16(DefaultPlayerLibrary.CharacterType.BattleaxeOffensive) + 1;

        IGameEngine.PlayerLoadout memory fastLoadout =
            IGameEngine.PlayerLoadout({playerId: fastWeaponId, skinIndex: defaultSkinIndex, skinTokenId: fastWeaponId});

        IGameEngine.PlayerLoadout memory slowLoadout =
            IGameEngine.PlayerLoadout({playerId: slowWeaponId, skinIndex: defaultSkinIndex, skinTokenId: slowWeaponId});

        bytes memory results = gameEngine.processGame(
            _convertToLoadout(slowLoadout), _convertToLoadout(fastLoadout), _generateGameSeed(), 0
        );

        (,,, GameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(results);

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
        uint16 weaponId = uint16(DefaultPlayerLibrary.CharacterType.QuarterstaffDefensive) + 1;

        IGameEngine.PlayerLoadout memory p1Loadout =
            IGameEngine.PlayerLoadout({playerId: weaponId, skinIndex: defaultSkinIndex, skinTokenId: weaponId});

        IGameEngine.PlayerLoadout memory p2Loadout =
            IGameEngine.PlayerLoadout({playerId: weaponId, skinIndex: defaultSkinIndex, skinTokenId: weaponId});

        bytes memory results =
            gameEngine.processGame(_convertToLoadout(p1Loadout), _convertToLoadout(p2Loadout), _generateGameSeed(), 0);

        (,,, GameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(results);

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

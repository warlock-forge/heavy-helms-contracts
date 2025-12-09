// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {IGameEngine} from "../../src/interfaces/game/engine/IGameEngine.sol";
import {TestBase} from "../TestBase.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";

contract ActionPointsTest is TestBase {
    function setUp() public override {
        super.setUp();
        // These tests don't use VRF - they test the game engine directly
        // with deterministic seeds based purely on block state
    }

    function test_DoubleAttack() public view {
        uint16 fastWeaponId = 7; // RapierShieldDefensive
        uint16 slowWeaponId = 3; // GreatswordOffensive

        Fighter.PlayerLoadout memory fastLoadout = Fighter.PlayerLoadout({
            playerId: fastWeaponId,
            skin: Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: fastWeaponId}),
            stance: 1
        });

        Fighter.PlayerLoadout memory slowLoadout = Fighter.PlayerLoadout({
            playerId: slowWeaponId,
            skin: Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: slowWeaponId}),
            stance: 1
        });

        IGameEngine.FighterStats memory fastStats = _convertToFighterStats(fastLoadout);
        IGameEngine.FighterStats memory slowStats = _convertToFighterStats(slowLoadout);

        // Use a fixed seed for deterministic behavior
        uint256 fixedSeed = 0x1111111111111111111111111111111111111111111111111111111111111111;

        bytes memory results = gameEngine.processGame(fastStats, slowStats, fixedSeed, 0);

        (,,, IGameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(results);

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
        uint16 fastWeaponId = 7; // RapierShieldDefensive
        uint16 slowWeaponId = 3; // GreatswordOffensive

        Fighter.PlayerLoadout memory fastLoadout = Fighter.PlayerLoadout({
            playerId: fastWeaponId,
            skin: Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: fastWeaponId}),
            stance: 1
        });

        Fighter.PlayerLoadout memory slowLoadout = Fighter.PlayerLoadout({
            playerId: slowWeaponId,
            skin: Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: slowWeaponId}),
            stance: 1
        });

        // Use a fixed seed for deterministic behavior
        uint256 fixedSeed = 0x2222222222222222222222222222222222222222222222222222222222222222;

        bytes memory results = gameEngine.processGame(
            _convertToFighterStats(slowLoadout), _convertToFighterStats(fastLoadout), fixedSeed, 0
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
        uint16 weaponId = 1; // DefaultWarrior

        Fighter.PlayerLoadout memory p1Loadout = Fighter.PlayerLoadout({
            playerId: weaponId, skin: Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: weaponId}), stance: 1
        });

        Fighter.PlayerLoadout memory p2Loadout = Fighter.PlayerLoadout({
            playerId: weaponId, skin: Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: weaponId}), stance: 1
        });

        // Use a fixed seed to ensure deterministic behavior regardless of test order
        uint256 fixedSeed = 0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd;

        bytes memory results =
            gameEngine.processGame(_convertToFighterStats(p1Loadout), _convertToFighterStats(p2Loadout), fixedSeed, 0);

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

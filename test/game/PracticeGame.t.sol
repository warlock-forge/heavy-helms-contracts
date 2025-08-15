// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {PracticeGame} from "../../src/game/modes/PracticeGame.sol";
import {Player} from "../../src/fighters/Player.sol";
import {PlayerSkinRegistry} from "../../src/fighters/registries/skins/PlayerSkinRegistry.sol";
import {DefaultPlayerSkinNFT} from "../../src/nft/skins/DefaultPlayerSkinNFT.sol";
import "../TestBase.sol";
import {DefaultPlayerLibrary} from "../../src/fighters/lib/DefaultPlayerLibrary.sol";
import {PlayerNameRegistry} from "../../src/fighters/registries/names/PlayerNameRegistry.sol";
import {IGameEngine} from "../../src/interfaces/game/engine/IGameEngine.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";

contract PracticeGameTest is TestBase {
    PracticeGame public practiceGame;

    // Test players
    address public PLAYER_ONE = address(0x1111);
    address public PLAYER_TWO = address(0x2222);
    uint32 public PLAYER_ONE_ID;
    uint32 public PLAYER_TWO_ID;

    function setUp() public override {
        super.setUp();
        practiceGame = new PracticeGame(
            address(gameEngine), address(playerContract), address(defaultPlayerContract), address(monsterContract)
        );

        // Create actual players for testing
        vm.deal(PLAYER_ONE, 100 ether);
        vm.deal(PLAYER_TWO, 100 ether);
        PLAYER_ONE_ID = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        PLAYER_TWO_ID = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);
    }

    function testBasicCombat() public view {
        // Test basic combat functionality with actual players
        _generateGameSeed();

        Fighter.PlayerLoadout memory player1 = _createLoadout(PLAYER_ONE_ID);
        Fighter.PlayerLoadout memory player2 = _createLoadout(PLAYER_TWO_ID);

        bytes memory results = practiceGame.play(player1, player2);
        (, uint16 version, GameEngine.WinCondition condition, GameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);
    }

    function testSpecificScenarios() public {
        bytes memory results;
        bool player1Won;
        uint16 version;
        GameEngine.WinCondition condition;
        GameEngine.CombatAction[] memory actions;

        // Get the player's equipped skin/stance for comparison
        IPlayer.PlayerStats memory p1Stats = playerContract.getPlayer(PLAYER_ONE_ID);
        IPlayer.PlayerStats memory p2Stats = playerContract.getPlayer(PLAYER_TWO_ID);

        // Scenario 1: Verify loadout overrides equipped skin/stance
        // LowStaminaClubsWarrior uses WEAPON_DUAL_CLUBS (18) vs DefaultWarrior's WEAPON_QUARTERSTAFF (5)
        // Dual Clubs has NO stat requirements, perfect for any player
        Fighter.PlayerLoadout memory loadout1A = Fighter.PlayerLoadout({
            playerId: PLAYER_ONE_ID,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.LowStaminaClubsWarrior) + 1 // LowStaminaClubsWarrior (ID 17)
            }),
            stance: 2 // Aggressive (different from default neutral)
        });

        Fighter.PlayerLoadout memory loadout1B = Fighter.PlayerLoadout({
            playerId: PLAYER_TWO_ID,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.DefaultWarrior) + 1 // DefaultWarrior (ID 1)
            }),
            stance: 0 // Defensive (different from default neutral)
        });

        // This should work even though the skins/stances differ from what's equipped
        results = practiceGame.play(loadout1A, loadout1B);
        (player1Won, version, condition, actions) = gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);

        // Verify the combat used the loadout weapons, not the equipped ones
        IPlayerSkinNFT.SkinAttributes memory loadoutSkin1 = defaultSkin.getSkinAttributes(loadout1A.skin.skinTokenId);
        IPlayerSkinNFT.SkinAttributes memory loadoutSkin2 = defaultSkin.getSkinAttributes(loadout1B.skin.skinTokenId);

        // The combat should have used the loadout's weapons (LowStaminaClubsWarrior uses different weapon than DefaultWarrior)
        // Player1 should be using dual clubs (18) instead of equipped quarterstaff (5)
        assertTrue(
            loadoutSkin1.weapon != defaultSkin.getSkinAttributes(p1Stats.skin.skinTokenId).weapon,
            "Player1 should be using loadout weapon, not equipped"
        );
        assertEq(loadoutSkin1.weapon, 18, "Player1 should be using dual clubs from LowStaminaClubsWarrior");

        // Scenario 2: Verify we can use the same skin with different stances
        loadout1A.stance = 0; // Defensive
        loadout1B.stance = 2; // Aggressive
        results = practiceGame.play(loadout1A, loadout1B);
        (player1Won, version, condition, actions) = gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);

        // Scenario 3: Verify we can switch back to originally equipped loadout
        Fighter.PlayerLoadout memory originalLoadout1 = _createLoadout(PLAYER_ONE_ID);
        Fighter.PlayerLoadout memory originalLoadout2 = _createLoadout(PLAYER_TWO_ID);
        results = practiceGame.play(originalLoadout1, originalLoadout2);
        (player1Won, version, condition, actions) = gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);
    }

    function testCombatLogStructure() public view {
        // Test the structure and decoding of combat logs
        Fighter.PlayerLoadout memory p1Loadout = _createLoadout(PLAYER_ONE_ID);
        Fighter.PlayerLoadout memory p2Loadout = _createLoadout(PLAYER_TWO_ID);

        bytes memory results = practiceGame.play(p1Loadout, p2Loadout);
        (, uint16 version, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) =
            gameEngine.decodeCombatLog(results);
        super._assertValidCombatResult(version, condition, actions);

        // Verify action structure
        for (uint256 i = 0; i < actions.length; i++) {
            assertTrue(
                uint8(actions[i].p1Result) <= uint8(type(IGameEngine.CombatResultType).max),
                string.concat("Invalid action type at index ", vm.toString(i))
            );
        }

        // Verify that at least one player has a non-zero stamina cost in at least one action
        bool foundNonZeroStamina = false;
        for (uint256 i = 0; i < actions.length; i++) {
            if (actions[i].p1StaminaLost > 0 || actions[i].p2StaminaLost > 0) {
                foundNonZeroStamina = true;
                break;
            }
        }

        assertTrue(foundNonZeroStamina, "No actions had stamina costs greater than zero");

        // Verify that specific actions have appropriate stamina costs
        bool attackActionFound = false;
        for (uint256 i = 0; i < actions.length; i++) {
            // Check if player 1 is attacking
            if (
                actions[i].p1Result == IGameEngine.CombatResultType.ATTACK
                    || actions[i].p1Result == IGameEngine.CombatResultType.CRIT
            ) {
                assertTrue(actions[i].p1StaminaLost > 0, "Attack action should have stamina cost");
                attackActionFound = true;
                break;
            }
            // Check if player 2 is attacking
            if (
                actions[i].p2Result == IGameEngine.CombatResultType.ATTACK
                    || actions[i].p2Result == IGameEngine.CombatResultType.CRIT
            ) {
                assertTrue(actions[i].p2StaminaLost > 0, "Attack action should have stamina cost");
                attackActionFound = true;
                break;
            }
        }

        assertTrue(attackActionFound, "No attack actions found in combat log");
    }
}

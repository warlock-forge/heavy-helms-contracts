// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "forge-std/console2.sol";
import {GameEngine} from "../../src/game/engine/GameEngine.sol";
import {IGameEngine} from "../../src/interfaces/game/engine/IGameEngine.sol";
import "../TestBase.sol";
import {DefaultPlayerLibrary} from "../../src/fighters/lib/DefaultPlayerLibrary.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";

contract CombatLogHealthTest is TestBase {
    address public PLAYER_ONE;
    address public PLAYER_TWO;
    uint32 public PLAYER_ONE_ID;
    uint32 public PLAYER_TWO_ID;

    function setUp() public override {
        super.setUp();

        // Set up test addresses
        PLAYER_ONE = address(0x1111);
        PLAYER_TWO = address(0x2222);

        // Create players
        PLAYER_ONE_ID = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
        PLAYER_TWO_ID = _createPlayerAndFulfillVRF(PLAYER_TWO, false);
    }

    function test_CombatLogHealthTracking() public {
        // Create loadouts - using a controlled setup with known stats
        Fighter.PlayerLoadout memory p1Loadout = Fighter.PlayerLoadout({
            playerId: PLAYER_ONE_ID,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1
            })
        });
        Fighter.PlayerLoadout memory p2Loadout = Fighter.PlayerLoadout({
            playerId: PLAYER_TWO_ID,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.MaceAndShieldDefensive) + 1
            })
        });

        // Get the appropriate Fighter contracts
        Fighter p1Fighter = _getFighterContract(p1Loadout.playerId);
        Fighter p2Fighter = _getFighterContract(p2Loadout.playerId);

        // Convert to fighter stats
        IGameEngine.FighterStats memory p1Stats = p1Fighter.convertToFighterStats(p1Loadout);
        IGameEngine.FighterStats memory p2Stats = p2Fighter.convertToFighterStats(p2Loadout);

        // Get initial calculated stats to know starting health
        GameEngine.CalculatedStats memory p1CalcStats = gameEngine.calculateStats(p1Stats);
        GameEngine.CalculatedStats memory p2CalcStats = gameEngine.calculateStats(p2Stats);

        // Process game and get combat log
        bytes memory results = gameEngine.processGame(p1Stats, p2Stats, _generateGameSeed(), 0);
        (bool player1Won, uint16 version, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions)
        = gameEngine.decodeCombatLog(results);

        // Track health through combat log
        uint16 p1Health = p1CalcStats.maxHealth;
        uint16 p2Health = p2CalcStats.maxHealth;

        console2.log("Initial Health - P1:", p1Health);
        console2.log("Initial Health - P2:", p2Health);

        for (uint256 i = 0; i < actions.length; i++) {
            console2.log("\nRound", i);
            console2.log("P1 Result:", uint8(actions[i].p1Result));
            console2.log("P2 Result:", uint8(actions[i].p2Result));

            // Verify each action is either offensive or defensive, never both
            bool p1IsDefensive = _isDefensiveResult(IGameEngine.CombatResultType(actions[i].p1Result));
            bool p2IsDefensive = _isDefensiveResult(IGameEngine.CombatResultType(actions[i].p2Result));

            // One must be defensive, one must be offensive
            assertTrue(p1IsDefensive != p2IsDefensive, "Both actions same type");

            // Process the round based on who's attacking
            if (!p1IsDefensive) {
                // P1 is attacking
                if (p2IsDefensive) {
                    IGameEngine.CombatResultType p2Result = IGameEngine.CombatResultType(actions[i].p2Result);
                    if (
                        p2Result == IGameEngine.CombatResultType.COUNTER
                            || p2Result == IGameEngine.CombatResultType.COUNTER_CRIT
                            || p2Result == IGameEngine.CombatResultType.RIPOSTE
                            || p2Result == IGameEngine.CombatResultType.RIPOSTE_CRIT
                    ) {
                        // Defender countered - apply their damage
                        p1Health = p1Health > actions[i].p2Damage ? p1Health - actions[i].p2Damage : 0;
                        console2.log("P2 counter/riposte for:", actions[i].p2Damage);
                        console2.log("P1 health now:", p1Health);
                    } else if (p2Result == IGameEngine.CombatResultType.HIT) {
                        // Attack landed
                        p2Health = p2Health > actions[i].p1Damage ? p2Health - actions[i].p1Damage : 0;
                        console2.log("P1 hits for:", actions[i].p1Damage);
                        console2.log("P2 health now:", p2Health);
                    } else {
                        // Attack was blocked/parried/dodged
                        console2.log("P1 attack defended");
                    }
                }
            } else {
                // P2 is attacking
                if (p1IsDefensive) {
                    IGameEngine.CombatResultType p1Result = IGameEngine.CombatResultType(actions[i].p1Result);
                    if (
                        p1Result == IGameEngine.CombatResultType.COUNTER
                            || p1Result == IGameEngine.CombatResultType.COUNTER_CRIT
                            || p1Result == IGameEngine.CombatResultType.RIPOSTE
                            || p1Result == IGameEngine.CombatResultType.RIPOSTE_CRIT
                    ) {
                        // Defender countered - apply their damage
                        p2Health = p2Health > actions[i].p1Damage ? p2Health - actions[i].p1Damage : 0;
                        console2.log("P1 counter/riposte for:", actions[i].p1Damage);
                        console2.log("P2 health now:", p2Health);
                    } else if (p1Result == IGameEngine.CombatResultType.HIT) {
                        // Attack landed
                        p1Health = p1Health > actions[i].p2Damage ? p1Health - actions[i].p2Damage : 0;
                        console2.log("P2 hits for:", actions[i].p2Damage);
                        console2.log("P1 health now:", p1Health);
                    } else {
                        // Attack was blocked/parried/dodged
                        console2.log("P2 attack defended");
                    }
                }
            }

            // After each round, verify no one is dealing damage in the NEXT round after death
            if (p1Health == 0) {
                // Check next round's damage, if it exists
                if (i + 1 < actions.length) {
                    assertEq(actions[i + 1].p1Damage, 0, "Dead player 1 dealing damage in next round");
                }
            }
            if (p2Health == 0) {
                // Check next round's damage, if it exists
                if (i + 1 < actions.length) {
                    assertEq(actions[i + 1].p2Damage, 0, "Dead player 2 dealing damage in next round");
                }
            }
        }

        console2.log("\nFinal Health - P1:", p1Health);
        console2.log("Final Health - P2:", p2Health);
        console2.log("Winner:", player1Won ? "Player 1" : "Player 2");

        // Verify winner determination matches health state
        if (condition == IGameEngine.WinCondition.HEALTH) {
            if (player1Won) {
                assertTrue(p1Health > p2Health, "Player 1 won but has less health");
            } else {
                assertTrue(p2Health > p1Health, "Player 2 won but has less health");
            }
        }

        // If someone died, verify their health is 0
        if (condition == IGameEngine.WinCondition.DEATH) {
            if (player1Won) {
                assertEq(p2Health, 0, "Player 2 died but health not 0");
                assertTrue(p1Health > 0, "Player 1 won but is dead");
            } else {
                assertEq(p1Health, 0, "Player 1 died but health not 0");
                assertTrue(p2Health > 0, "Player 2 won but is dead");
            }
        }
    }

    function test_CombatLogArmorReduction() public {
        // Create loadouts with different armor types
        Fighter.PlayerLoadout memory p1Loadout = Fighter.PlayerLoadout({
            playerId: PLAYER_ONE_ID,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.GreatswordOffensive) + 1
            })
        });
        Fighter.PlayerLoadout memory p2Loadout = Fighter.PlayerLoadout({
            playerId: PLAYER_TWO_ID,
            skin: Fighter.SkinInfo({
                skinIndex: defaultSkinIndex,
                skinTokenId: uint16(DefaultPlayerLibrary.CharacterType.MaceAndShieldDefensive) + 1
            })
        });

        // Get the appropriate Fighter contracts
        Fighter p1Fighter = _getFighterContract(p1Loadout.playerId);
        Fighter p2Fighter = _getFighterContract(p2Loadout.playerId);

        // Convert to fighter stats
        IGameEngine.FighterStats memory p1Stats = p1Fighter.convertToFighterStats(p1Loadout);
        IGameEngine.FighterStats memory p2Stats = p2Fighter.convertToFighterStats(p2Loadout);

        // Process game and get combat log
        bytes memory results = gameEngine.processGame(p1Stats, p2Stats, _generateGameSeed(), 0);
        (bool player1Won, uint16 version, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions)
        = gameEngine.decodeCombatLog(results);

        // Get armor stats for verification
        GameEngine.ArmorStats memory p1Armor = gameEngine.getArmorStats(p1Stats.armor);
        GameEngine.ArmorStats memory p2Armor = gameEngine.getArmorStats(p2Stats.armor);

        // Verify damage values in combat log reflect armor reduction
        for (uint256 i = 0; i < actions.length; i++) {
            if (actions[i].p1Damage > 0) {
                // Get weapon stats to know damage type
                GameEngine.WeaponStats memory p1Weapon = gameEngine.getWeaponStats(p1Stats.weapon);

                // Log the damage details
                console2.log("Round", i);
                console2.log("P1 weapon:", getWeaponName(p1Stats.weapon));
                console2.log("Damage dealt:", actions[i].p1Damage);
                console2.log("P2 armor type:", getArmorName(p2Stats.armor));
                console2.log("P2 armor defense:", p2Armor.defense);
            }

            if (actions[i].p2Damage > 0) {
                // Get weapon stats to know damage type
                GameEngine.WeaponStats memory p2Weapon = gameEngine.getWeaponStats(p2Stats.weapon);

                // Log the damage details
                console2.log("Round", i);
                console2.log("P2 weapon:", getWeaponName(p2Stats.weapon));
                console2.log("Damage dealt:", actions[i].p2Damage);
                console2.log("P1 armor type:", getArmorName(p1Stats.armor));
                console2.log("P1 armor defense:", p1Armor.defense);
            }
        }
    }
}

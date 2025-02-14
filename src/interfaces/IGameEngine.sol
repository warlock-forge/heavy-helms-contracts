// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IPlayer.sol";
import "../lib/GameHelpers.sol";

interface IGameEngine {
    enum WinCondition {
        HEALTH, // KO
        EXHAUSTION, // Won because opponent couldn't attack (low stamina)
        MAX_ROUNDS, // Won by having more health after max rounds
        DEATH // RIP

    }

    enum CombatResultType {
        MISS, // 0 - Complete miss, some stamina cost
        ATTACK, // 1 - Normal successful attack
        CRIT, // 2 - Critical hit
        BLOCK, // 3 - Successfully blocked attack
        COUNTER, // 4 - Counter attack after block/dodge
        COUNTER_CRIT, // 5 - Critical counter attack
        DODGE, // 6 - Successfully dodged attack
        PARRY, // 7 - Successfully parried attack
        RIPOSTE, // 8 - Counter attack after parry
        RIPOSTE_CRIT, // 9 - Critical counter after parry
        EXHAUSTED, // 10 - Failed due to stamina
        HIT // 11 - Taking full damage (failed defense)

    }

    struct CombatAction {
        CombatResultType p1Result;
        uint16 p1Damage;
        uint8 p1StaminaLost;
        CombatResultType p2Result;
        uint16 p2Damage;
        uint8 p2StaminaLost;
    }

    // Used by game modes for validation and tracking
    struct PlayerLoadout {
        uint32 playerId;
        uint32 skinIndex;
        uint16 skinTokenId;
    }

    struct FighterStats {
        uint8 weapon;
        uint8 armor;
        uint8 stance;
        GameHelpers.Attributes attributes;
    }

    function decodeVersion(uint16 _version) external pure returns (uint8 major, uint8 minor);

    function decodeCombatLog(bytes memory results)
        external
        pure
        returns (bool player1Won, uint16 gameEngineVersion, WinCondition condition, CombatAction[] memory actions);

    function processGame(
        FighterStats calldata player1,
        FighterStats calldata player2,
        uint256 randomSeed,
        uint16 lethalityFactor
    ) external view returns (bytes memory);
}

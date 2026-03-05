---
paths: "test/**/*.sol"
---

# Heavy Helms Testing Context

## Fighter ID Ranges

| Range | Type | Contract |
|-------|------|----------|
| 1-2000 | DEFAULT_PLAYER | defaultPlayerContract |
| 2001-10000 | MONSTER | monsterContract |
| 10001+ | PLAYER | playerContract |

## VRF Flow

Two randomness approaches:

### Chainlink VRF 2.5
Used by: Player creation, DuelGame, MonsterBattleGame

```solidity
vm.recordLogs();  // MUST be before request
uint256 requestId = contract.request();
_fulfillVRFRequest(address(contract));
```

### Blockhash 3-Phase (Commit-Reveal)
Used by: GauntletGame, TournamentGame

```solidity
// COMMIT: game.tryStartGauntlet()
// SELECT: vm.roll(selectionBlock + 1); game.tryStartGauntlet()
// EXECUTE: vm.roll(tournamentBlock + 1); game.tryStartGauntlet()
```

`blockhash(N)` returns 0 at block N — must be at N+1.
After 256 blocks, blockhash returns 0 again — triggers auto-recovery.

## Soft vs Hard Test Failures

**Soft (expected, ignore):** Randomness-dependent results — winner IDs, damage values, win rates, anything in simulation tests (BalanceTest, GameEngineProgressionTest, LethalityTest).

**Hard (real bugs):** State transitions, permissions, fees, queue management, reverts, events, VRF flow errors.

## TestBase Helper Methods

Key helpers available via `TestBase.sol`:

- `_createPlayerAndFulfillVRF(address owner, bool useSetB)` — Creates player via VRF
- `_createPlayerRequest(address owner, IPlayer contract, bool useSetB)` — VRF request without fulfillment
- `_fulfillVRFRequest(address gameContract)` — Fulfills pending VRF (needs `vm.recordLogs()` before)
- `_getPlayerIdFromLogs(address owner, uint256 requestId)` — Extract playerId from logs
- `_createLoadout(uint32 fighterId)` — Creates loadout for any fighter type
- `_convertToFighterStats(Fighter.PlayerLoadout memory loadout)` — For direct GameEngine testing
- `_assertStatRanges(IPlayer.PlayerStats memory stats)` — Validates stats 3-21
- `_mintTickets(address to, uint256 ticketType, uint256 amount)` — Mint test tickets
- `_mintDefaultCharacters()` — Creates default players 1-2000 (called in setUp)
- `_mintMonsters()` — Creates test monsters 2001-2003 (called in setUp)
- `skipInCI` modifier — Skips test if CI env var set

## HH Invariants to Test

### Player Contract
- `invariant_ActiveCountMatchesNonRetired` — activePlayerCount == count of non-retired players
- `invariant_NextIdAlwaysIncreases` — nextPlayerId only goes up
- `invariant_OwnershipConsistent` — ownerOf matches balanceOf

### Game Contracts
- `invariant_FeesMatchBalance` — accumulated fees <= contract balance
- `invariant_QueueConsistency` — queue size matches player states
- `invariant_NoOrphanedPlayers` — players in queue are never retired
- `invariant_StateTransitionsValid` — states only move forward (OPEN->PENDING->COMPLETED)

### Tournament/Gauntlet
- `invariant_ParticipantsLocked` — once selected, participants can't leave
- `invariant_RewardsMatchConfig` — distributed rewards match configured percentages
- `invariant_DailyLimitsEnforced` — no player exceeds daily run limit

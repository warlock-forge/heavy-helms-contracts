---
paths: "src/**/*.sol"
---

# Heavy Helms Audit Context

## Trusted Contracts

External calls to these are NOT reentrancy risks (we control them):

| Contract | Role | Call Type |
|----------|------|-----------|
| GameEngine | Stateless combat processor | Pure computation |
| Player | Player records, stats | Game data updates |
| DefaultPlayer | NPC fighter data | View calls only |
| PlayerTickets | ERC1155 rewards | Gas-limited callbacks (50k) |
| SkinRegistry | Skin validation | View calls only |
| NameRegistry | Name lookups | View calls only |
| Monster | Monster stats | View calls only |

## Financial vs Game Data

**FINANCIAL** (reentrancy concerns ARE valid):
- ETH payments to user addresses
- Token transfers to user wallets
- Fee collection/distribution

**GAME DATA** (reentrancy concerns are false positives):
- Win/loss/kill records, XP, level progression
- Player stats and attributes
- Tournament/gauntlet results
- Skin equipment changes, stance modifications

**Rule**: State changes to game data after trusted contract calls = `false_positive`

## Known False Positive Patterns

### Blockhash Randomness in GauntletGame/TournamentGame
- `weak-prng`, `weak-randomness` detectors
- Intentional commit-reveal scheme, acceptable for game outcomes
- Verdict: `acknowledged`

### Practice Mode Randomness
- No stakes, cosmetic only
- Verdict: `acknowledged`

### Name NFT Generation (PlayerTickets)
- External seed + blockchain data, cosmetic outcome
- Verdict: `acknowledged`

### Timestamp for Daily Resets (Player)
- ~15 second manipulation window acceptable for daily cooldowns
- Verdict: `false_positive`

### GameEngine Combat Calls
- `reentrancy-benign`, `external-calls-in-loop`
- Combat is stateless, no ETH transfers during combat
- State updates happen after combat resolution in calling contract
- Verdict: `false_positive`

### Centralized Admin Functions
- Intentional during development, all emit events
- Production will use multisig
- Verdict: `acknowledged`

### Local Interface Definitions
- `reused-contract-name` — minimal interfaces in game contracts
- Foundry handles correctly
- Verdict: `acknowledged`

## HH-Specific Analysis Rules

### reentrancy-no-eth
- GameEngine calls are trusted (we own it)
- Combat results are game state, not financial

### unused-return
- `decodeCombatLog` returns `(winner, p1Data, p2Data, log)` — games often only need `winner`
- Pattern `(winner, , , ) = ...` is intentional

### divide-before-multiply
- Damage calculations have acceptable variance (game design)
- Fee/reward calculations need precision
- Combat stats with % modifiers are bounded (stats 3-18, percentages 0-100)

### incorrect-equality
- Game phases are enums — exact comparison is correct
- Player IDs are exact values
- Gauntlet/Tournament sizes are controlled

### calls-loop
- Gauntlet/Tournament have bounded participant counts
- GameEngine is trusted
- Combat loops are bounded by round limits

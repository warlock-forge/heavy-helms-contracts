# Security

## Audit Status

Self-audited with automated static analysis running in CI on every push and PR:

- [Slither](https://github.com/crytic/slither) (Trail of Bits)
- [Aderyn](https://github.com/Cyfrin/aderyn) (Cyfrin)

No formal external audit has been performed. False positives are suppressed inline with `// slither-disable-next-line` and `// aderyn-fp` annotations, each with justification.

## Architecture

All contracts are immutable deployments -- no upgrade proxies, no delegatecall, no UUPS. If a contract needs to change, a new version is deployed and game permissions are migrated. This means bugs require redeployment but eliminates an entire class of upgrade-related vulnerabilities.

Owner is currently an EOA. Production intent is to migrate to a multisig.

## Threat Model

### What the contracts hold

| Contract | Holds ETH | Source |
|---|---|---|
| Player | Yes | Creation fees, slot purchase fees |
| DuelGame | Yes | Duel challenge fees |
| GauntletGame | Yes | Daily reset fees |
| MonsterBattleGame | Yes | Daily reset fees |
| PlayerSkinRegistry | Yes | Skin registration fees |
| PlayerSkinNFT | Yes | Mint proceeds |
| UnlockableKeyNFT | Yes | Mint proceeds |

All ETH withdrawal is owner-only via `withdrawFees()` or equivalent, transferring the full contract balance to `owner()`. No user-facing ETH withdrawals exist (except Player creation fee refunds on VRF timeout recovery).

### What the contracts control

- Player stats, records, XP, and retirement status
- ERC-1155 utility ticket supply (PlayerTickets)
- ERC-721 skin ownership and metadata
- Game mode state machines (queues, challenges, tournaments)
- Combat outcomes (via GameEngine)

None of these have direct financial value outside the game. There is no token, no staking, no DeFi integration.

## Access Control

### Game contract permissions

The Player contract uses a granular whitelist system. Each game contract is granted specific capabilities:

```
GamePermissions {
    record:     bool,  // Can record wins/losses/kills
    retire:     bool,  // Can kill fighters (TournamentGame only)
    immortal:   bool,  // Can set fighters as unkillable
    experience: bool   // Can award XP
}
```

PlayerTickets has a parallel permission system controlling which contracts can mint which ticket types (creation, slots, names, weapon/armor specialization, duels, daily resets, attribute swaps).

### Admin surface

The owner can:

- Enable/disable game modes
- Swap the GameEngine address on any game contract
- Adjust fees and costs (creation fee, duel fee, reset costs, slot costs)
- Adjust game parameters (gauntlet size, tournament size, lethality factor, daily limits)
- Pause player creation
- Clear stuck VRF requests (with optional refund)
- Emergency clear the gauntlet queue
- Withdraw accumulated fees
- Grant/revoke game contract permissions
- Update VRF configuration (key hash, gas limit, confirmations, subscription)

The owner cannot:

- Modify player stats directly (no backdoor stat editing)
- Transfer players between owners (soulbound)
- Mint arbitrary tickets without the correct permission grant
- Alter completed game results retroactively
- Upgrade contracts in place

All admin functions emit events for transparency.

## Randomness

### Chainlink VRF v2.5

Used by: Player creation, DuelGame, MonsterBattleGame

Standard request-callback pattern. The VRF coordinator is a trusted Chainlink contract. Request IDs are mapped to pending operations, and `rawFulfillRandomWords` is the callback entry point. VRF requests have a configurable timeout for recovery if callbacks never arrive.

Gas protection: Player creation and DuelGame have optional gas price checks (`maxVRFGasPrice`, `maxAcceptGasPrice`) to prevent frontrunning during high-gas periods. These are toggleable by the owner.

### Blockhash commit-reveal

Used by: GauntletGame, TournamentGame

Three-phase flow using future `blockhash()` values as entropy:

1. **Commit**: locks queue state, records target block numbers
2. **Select**: at `selectionBlock + 1`, uses `blockhash(selectionBlock)` to randomly pick participants from the queue
3. **Execute**: at `tournamentBlock + 1`, uses `blockhash(tournamentBlock)` as the combat seed

**Known tradeoff**: Base uses a centralized sequencer that could theoretically influence `blockhash` values. This is accepted because:

- Entry has no direct financial cost (no buy-in, no wagering)
- Rewards are in-game utility tickets only (stat respec, new fighter rolls)
- The UX benefit (instant resolution, no VRF callback delay, no per-game VRF cost) outweighs the risk
- Manipulation would require the sequencer operator to care about game outcomes

**256-block recovery**: If `blockhash()` returns 0 (happens after 256 blocks), the game detects this and auto-recovers by returning all participants to the queue. No funds or state are lost.

### Practice mode

Uses `block.prevrandao` directly. No stakes, cosmetic-only outcomes. Not a security concern.

## Reentrancy

### ETH transfers

All ETH transfers to external addresses use Solady's `SafeTransferLib.safeTransferETH`. The only user-facing ETH transfer is the Player creation fee refund during VRF timeout recovery (`clearPendingRequestsForAddress`). This follows checks-effects-interactions: the pending request is cleared from storage before the refund is sent.

All other ETH transfers are owner-only fee withdrawals (`withdrawFees`), which transfer the full balance to `owner()`.

### Trusted internal calls

Game contracts make external calls to other contracts in the system (GameEngine, Player, PlayerTickets, SkinRegistry, etc.). These are all contracts we control, and the calls are:

- **GameEngine**: Stateless pure computation (combat resolution). No state changes, no callbacks.
- **Player**: Game data updates (record wins/losses, award XP). Protected by the permission system.
- **PlayerTickets**: ERC-1155 minting with gas-limited callbacks (50k gas limit on transfer hooks).
- **Registries**: View-only calls for validation.

Static analyzers flag these as reentrancy risks. They are false positives because all callee contracts are trusted and controlled.

## Known Limitations

### Centralized admin

The owner has broad control over game parameters and can enable/disable game modes. This is intentional for an actively developed game. The tradeoff is operational flexibility vs. trust minimization. Migrating to a multisig is planned.

### Blockhash manipulation

As described above, the Base sequencer could influence game outcomes. The risk is accepted given the low-value, utility-only rewards.

### Timestamp dependence

Daily reset cooldowns use `block.timestamp`. Miners/sequencers can manipulate timestamps by ~15 seconds. This is acceptable for a daily cooldown mechanism.

### No formal audit

The codebase has not been externally audited. Testing includes 535+ unit/fuzz/invariant tests, 90% LCOV coverage gate in CI, and continuous static analysis. This does not replace a formal audit.

## Testing

| Category | Count | What it covers |
|---|---|---|
| Unit tests | ~475 | Individual function behavior, reverts, permissions, edge cases |
| Fuzz tests | ~35 | Randomized inputs for player creation, combat simulations, progression |
| Invariant tests | 21 | System properties across random action sequences (queue consistency, stat conservation, fee accounting) |
| Simulation tests | ~25 | Statistical combat balance, progression scaling, lethality, gas profiling |

Invariant tests exercise the full state machine of each major contract via handler contracts that generate random sequences of queue/withdraw/start/accept/fulfill/retire/level/swap operations, then verify system-wide properties hold after every sequence.

## Incident Response

If a vulnerability is discovered:

1. Disable affected game mode via `setGameEnabled(false)`
2. If queue state is corrupted: `emergencyClearQueue()` returns all players to safe state
3. If VRF requests are stuck: `clearPendingRequestsForAddress()` with refund flag
4. Deploy patched contract, migrate permissions via `setGameContractPermission()`
5. Old contract remains deployed but inert (no permissions, disabled)

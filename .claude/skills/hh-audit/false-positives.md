# Heavy Helms False Positives

Known patterns in this codebase that trigger warnings but are intentional or acceptable.

## Intentional Patterns

### Blockhash Randomness in GauntletGame

**Detector:** `weak-prng`, `block-timestamp`, `weak-randomness`

**Why it triggers:** GauntletGame uses `blockhash()` for randomness.

**Why it's OK:** This is an intentional commit-reveal scheme:
1. Players commit during queue phase
2. Gauntlet starts in a future block
3. Reveal uses blockhash from commitment block
4. Economic security: manipulating blockhash costs more than game rewards

**Files:** `src/game/modes/GauntletGame.sol`

---

### Centralized Admin Functions

**Detector:** `centralization-risk`, `unprotected-setter`

**Why it triggers:** Admin functions like `setGameEnabled`, `setGauntletSize`, etc.

**Why it's OK:**
- Game is in active development, admin control is intentional
- All admin functions emit events for transparency
- Production will use multisig (documented in deployment)

**Files:** Most game mode contracts

---

### Solady Assembly Usage

**Detector:** `assembly`, `low-level-calls`

**Why it triggers:** Solady uses inline assembly for gas optimization.

**Why it's OK:**
- Solady is audited, battle-tested library
- Used for SafeTransferLib, Ownable, etc.
- Don't flag assembly in `lib/solady/`

**Filter:** Exclude `lib/` directory from scans

---

### Player Contract Permissions System

**Detector:** `arbitrary-send-erc20`, `external-function`

**Why it triggers:** Game contracts can modify player state via permission system.

**Why it's OK:**
- Whitelist pattern: only approved game contracts get permissions
- Each permission is granular (record, retire, immortal, experience)
- `setGameContractPermission` is admin-only

**Files:** `src/fighters/Player.sol`, `src/nft/PlayerTickets.sol`

---

### GameEngine External Calls

**Detector:** `reentrancy-benign`, `external-calls-in-loop`

**Why it triggers:** GameEngine makes callbacks to game contracts during combat.

**Why it's OK:**
- Combat is stateless - reads fighter data, returns result
- No ETH transfers during combat execution
- State updates happen after combat resolution in calling contract

**Files:** `src/game/engine/GameEngine.sol`

---

### Timestamp Usage for Cooldowns

**Detector:** `timestamp`

**Why it triggers:** Daily reset timestamps, cooldown timers.

**Why it's OK:**
- Used for game mechanics, not financial logic
- ~15 second manipulation window is acceptable for daily resets
- Gauntlet timing uses block numbers, not timestamps

**Files:** `src/fighters/Player.sol` (daily resets)

---

## Recommended Slither Exclusions

Run Slither with these exclusions for cleaner output:

```bash
slither . \
  --exclude-dependencies \
  --exclude timestamp,assembly,naming-convention,solc-version \
  --filter-paths "lib/,test/,script/" \
  --json slither-report.json
```

## Recommended Aderyn Exclusions

```bash
aderyn \
  --path-excludes "lib/,test/,script/" \
  -o aderyn-report.json
```

---

## Patterns That ARE Bugs

These should NOT be ignored even if they look similar to above:

### Reentrancy in Token Transfers
If a detector flags reentrancy in functions that transfer ETH or tokens to user-controlled addresses, investigate carefully.

### Unprotected Initialize
Any `initialize()` function without access control is critical - upgradeable contracts can be hijacked.

### Unchecked External Calls
Low-level calls without return value checks are real bugs (see `rules/solidity.md`).

### Missing Zero-Address Checks
Constructor and setter functions for critical addresses (owner, treasury, etc.) should validate.

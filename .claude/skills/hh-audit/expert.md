# Solidity Smart Contract Security Expert Reference

This reference provides actionable detection criteria for security auditors reviewing automated tool findings. Goal: distinguish true vulnerabilities from false positives with confidence.

---

## Quick Detector Reference

Use this table for rapid verdict decisions. Grep for detector name to find detailed guidance below.

| Detector | CONFIRM If | FALSE POSITIVE If |
|----------|-----------|-------------------|
| `reentrancy-*` | User-controlled recipient, state change after external call, no guard | Trusted contract recipient, CEI pattern, ReentrancyGuard on all paths |
| `reentrancy-no-eth` | Token transfer to user, balance modified after call | Call to trusted contract, game data only, view calls |
| `access-control` | Missing modifier on state-changing function | Intentional public, modifies only msg.sender's state |
| `weak-randomness` | Financial outcome dependent, exploitable for profit | Cosmetic/game data, commit-reveal scheme, no stakes |
| `divide-before-multiply` | Token amounts affected, precision loss >1% | Bounded game values, percentage modifiers, non-financial |
| `unsafe-cast` | Unbounded user input, financial values truncated | Value explicitly capped/bounded before cast |
| `incorrect-equality` | Balance/amount comparison (dust possible) | Enum, ID, counter, state machine phase |
| `unused-return` | Success/failure indicator ignored | Intentional destructuring `(val,,)`, informational return |
| `storage-array-memory-edit` | Intended to modify storage via function | Read-only access, config passed for reading |
| `contract-locks-ether` | Accepts ETH, no withdraw function | Has withdraw/collect, or doesn't accept ETH |
| `encode-packed-collision` | Dynamic types passed to keccak256 | String concatenation for display/URI, unique ID included |
| `tx-origin` | Used for authorization | Analytics/gas tracking only |

---

## NEVER Auto-Dismiss Checklist

These patterns require human review regardless of context. If ANY are present, verdict must be `confirmed` or `needs_review`:

- [ ] External call to `msg.sender` or user-supplied address with value transfer
- [ ] ETH or token transfer followed by state change (check CEI)
- [ ] `tx.origin` in any authorization logic
- [ ] `selfdestruct` callable without strict access control
- [ ] `delegatecall` to variable/user-supplied address
- [ ] Unchecked arithmetic (`unchecked {}`) on user-controlled input
- [ ] Price derived from single DEX `getReserves()` call
- [ ] Voting power from flash-loanable tokens without snapshot
- [ ] Missing return value check on `.call()`, `.send()`, `.transfer()`
- [ ] Type cast from uint256 to smaller type on unbounded value

---

## Heavy Helms Project Context

### Trusted Contracts

External calls to these are NOT reentrancy risks (we control them):

| Contract | Role | Call Type |
|----------|------|-----------|
| `GameEngine` | Stateless combat processor | Pure computation |
| `Player` | Player records, stats | Game data updates |
| `DefaultPlayer` | NPC fighter data | View calls only |
| `PlayerTickets` | ERC1155 rewards | Gas-limited callbacks (50k) |
| `SkinRegistry` | Skin validation | View calls only |
| `NameRegistry` | Name lookups | View calls only |
| `Monster` | Monster stats | View calls only |

### Financial vs Game Data

**FINANCIAL** (reentrancy concerns ARE valid):
- ETH payments to user addresses
- Token transfers to user wallets
- Fee collection/distribution
- Staking/unstaking operations

**GAME DATA** (reentrancy concerns are false positives):
- Win/loss/kill records
- XP and level progression
- Player stats and attributes
- Tournament/gauntlet results
- Skin equipment changes
- Stance modifications

**Rule**: State changes to game data after trusted contract calls = `false_positive`

### Intentional Design Patterns

These trigger warnings but are documented design decisions:

1. **Commit-reveal randomness** (`weak-randomness` in GauntletGame, TournamentGame)
   - Uses blockhash from future block
   - Acceptable for game outcomes (not high-value DeFi)
   - Verdict: `acknowledged`

2. **Practice mode randomness** (`weak-randomness` in PracticeGame)
   - No stakes, cosmetic only
   - Verdict: `acknowledged`

3. **Name NFT generation** (`weak-randomness` in PlayerTickets)
   - External seed + blockchain data
   - Cosmetic outcome only
   - Verdict: `acknowledged`

4. **Local interface definitions** (`reused-contract-name`)
   - Minimal interfaces in game contracts
   - Foundry handles correctly
   - Verdict: `acknowledged`

### Fighter ID Ranges

```
1-2000      = Default Players (game-owned NPCs)
2001-10000  = Monsters (game-owned)
10001+      = Players (user-owned)
```

---

## Threat Landscape (2024-2025)

Access control failures and price oracle manipulation caused **$962 million** in losses during 2024. Off-chain attacks account for **80.5%** of stolen funds, with compromised private keys causing **47%** of total losses.

### OWASP Smart Contract Top 10 (2025)

| Rank | Vulnerability | 2024 Losses | Key Pattern |
|------|--------------|-------------|-------------|
| SC01 | Access Control | **$953.2M** | Missing/incorrect authorization |
| SC02 | Price Oracle Manipulation | $8.8M | Single-source or spot price |
| SC03 | Logic Errors | $63.8M | Behavior deviates from intent |
| SC04 | Input Validation | $14.6M | Unvalidated user parameters |
| SC05 | Reentrancy | $35.7M | State updated after external calls |
| SC06 | Unchecked External Calls | $550.7K | Return values not verified |
| SC07 | Flash Loan Attacks | $33.8M | Single-transaction exploitation |
| SC08 | Integer Overflow | — | Arithmetic wraparound |
| SC09 | Insecure Randomness | — | Predictable on-chain values |
| SC10 | Denial of Service | — | Gas/resource exhaustion |

---

## Reentrancy Analysis

### Four Variants

1. **Classic**: External call before state update
2. **Cross-function**: Shared state between functions, one calls external
3. **Cross-contract**: Reentry through different contract sharing state
4. **Read-only**: View functions return stale data during reentrant call

### Vulnerable Pattern

```solidity
// VULNERABLE: State after external call
function withdraw() external {
    uint256 amount = balances[msg.sender];
    (bool success, ) = msg.sender.call{value: amount}("");
    balances[msg.sender] = 0;  // TOO LATE
}
```

### Secure Pattern (CEI)

```solidity
// SECURE: Checks-Effects-Interactions
function withdraw() external {
    uint256 amount = balances[msg.sender];
    balances[msg.sender] = 0;  // EFFECT first
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success);
}
```

### Verification Checklist

Before marking `reentrancy-*` as false positive:

1. ✓ State updates occur BEFORE all external calls
2. ✓ ReentrancyGuard covers the function AND cross-function paths
3. ✓ External call recipient is trusted/immutable (not user-controlled)
4. ✓ No tokens/ETH transferred to user addresses before state update
5. ✓ View functions aren't exploitable by external protocols

### Heavy Helms Specific

Most reentrancy findings are false positives because:
- Calls go to trusted contracts (GameEngine, Player)
- State changes are game records, not financial balances
- No ETH/tokens sent to user-controlled addresses in vulnerable paths

---

## Access Control Analysis

### Detection Criteria

CONFIRM if:
- Functions modifying owner/admin without authorization
- `mint()`, `burn()`, `pause()`, `upgrade()` without modifiers
- `selfdestruct()` callable by anyone
- Parameter-changing functions lacking protection

FALSE POSITIVE if:
- Function only modifies `msg.sender`'s own state
- Intentionally public for user self-service
- Protected by `onlyOwner`, `onlyRole`, or equivalent

### tx.origin Dangers

```solidity
// VULNERABLE: Phishing attack possible
require(tx.origin == owner);

// SECURE
require(msg.sender == owner);
```

**Post-EIP-7702**: `tx.origin == msg.sender` EOA check is broken.

### Verification Checklist

1. ✓ All state-changing functions have appropriate modifiers
2. ✓ Modifiers contain `require()` or `revert` (not just `if`)
3. ✓ Initialization can only occur once
4. ✓ No `tx.origin` in authorization logic
5. ✓ Role-granting requires existing admin authority

---

## Oracle Manipulation Analysis

### Vulnerable Pattern

```solidity
// VULNERABLE: Spot price from DEX
function getPrice() public view returns (uint256) {
    (uint112 r0, uint112 r1,) = pair.getReserves();
    return r1 * 1e18 / r0;  // MANIPULABLE via flash loan
}
```

### Secure Pattern

```solidity
// SECURE: Chainlink with validation
function getPrice() public view returns (uint256) {
    (uint80 roundId, int256 price, , uint256 updatedAt, ) =
        feed.latestRoundData();

    require(roundId != 0, "Invalid round");
    require(price > 0, "Invalid price");
    require(block.timestamp - updatedAt <= HEARTBEAT, "Stale");
    require(price > MIN && price < MAX, "Bounds");

    return uint256(price);
}
```

### Chainlink Checklist

| Check | Code | Risk if Missing |
|-------|------|-----------------|
| Staleness | `block.timestamp - updatedAt <= HEARTBEAT` | Outdated prices |
| Zero/Negative | `price > 0` | Division by zero |
| Round validity | `roundId != 0` | Incomplete round |
| Price bounds | `MIN < price < MAX` | Flash crash exploits |
| L2 Sequencer | Uptime feed check | Unfair liquidations |

---

## Precision and Rounding Analysis

### Division Before Multiplication

```solidity
// VULNERABLE: Precision lost
return amount / 1000 * rate;

// SECURE: Multiply first
return amount * rate / 1000;
```

### Truncation to Zero

```solidity
// VULNERABLE: Fee = 0 when amount * bps < 10000
uint256 fee = amount * feeBps / 10000;

// SECURE: Minimum threshold
uint256 fee = amount * feeBps / 10000;
return fee > 0 ? fee : MIN_FEE;
```

### Verification Checklist

1. ✓ Multiplication precedes division
2. ✓ Zero results handled with minimums or reverts
3. ✓ Token decimals explicitly normalized
4. ✓ Rounding consistently favors protocol
5. ✓ No hardcoded decimal assumptions (1e18)

### Heavy Helms Specific

Game mechanics use percentage modifiers:
```solidity
tempPowerMod = (tempPowerMod * 105) / 100;
```

These are `false_positive` because:
- Values are bounded (stats 3-18, percentages 0-100)
- Precision loss is acceptable game variance
- No financial tokens involved

---

## Integer Safety Analysis

### Solidity 0.8+ Protections

Arithmetic overflow reverts by default EXCEPT:
- `unchecked {}` blocks
- Unsafe type casts (uint256 → uint128 truncates silently)
- Inline assembly operations
- Pre-0.8.0 contracts

### Unsafe Cast Pattern

```solidity
// VULNERABLE: Silent truncation
uint120 ratio = uint120(largeValue);

// SECURE: SafeCast reverts
uint120 ratio = largeValue.toUint120();
```

### Verification Checklist

1. ✓ `unchecked` blocks don't contain user-controlled values
2. ✓ Type casts have explicit bounds checks before cast
3. ✓ Assembly arithmetic validated
4. ✓ Compiler version is 0.8.0+

### Heavy Helms Specific

Casts like `uint8(pointsToAdd)` are safe when:
- Value is capped by game rules (pointsCap max 18)
- Source is bounded calculation (hit chance capped at 95)

---

## External Call Analysis

### Unchecked Return Values

```solidity
// VULNERABLE: Return ignored
winner.send(amount);
paidOut = true;  // Runs even if send failed

// SECURE: Check return
(bool success,) = winner.call{value: amount}("");
require(success);
```

### Contract Existence

Low-level calls to non-existent addresses succeed with empty return:
```solidity
// SECURE: Verify code exists
require(target.code.length > 0);
```

### delegatecall Dangers

Executes external code in caller's storage context. CONFIRM if:
- Target is variable/user-supplied
- Storage layouts may mismatch

---

## Decision Framework Summary

### Before Marking FALSE POSITIVE

**For reentrancy**:
1. ✓ State updates occur BEFORE all external calls
2. ✓ ReentrancyGuard covers function AND cross-function paths
3. ✓ External call recipients cannot be attacker-controlled
4. ✓ No ETH/tokens to user addresses before state update

**For access control**:
1. ✓ All state-changing functions have modifiers
2. ✓ Modifiers contain require/revert
3. ✓ Initialization only occurs once
4. ✓ No tx.origin in auth logic

**For oracle**:
1. ✓ Staleness check with feed-specific heartbeat
2. ✓ Price bounds prevent flash crash exploitation
3. ✓ Multiple sources or manipulation-resistant TWAP
4. ✓ L2 sequencer uptime verified

**For precision**:
1. ✓ Multiplication precedes division
2. ✓ Zero results handled
3. ✓ Token decimals normalized
4. ✓ Rounding favors protocol

**For external calls**:
1. ✓ All return values checked
2. ✓ Contract existence verified
3. ✓ delegatecall targets trusted/immutable
4. ✓ Gas requirements validated

---

## Notable Exploits Reference

### 2024
- Radiant Capital ($53M) - Multi-sig compromise
- Penpie ($27M) - Cross-function reentrancy
- UwU Lend ($20M) - Oracle manipulation via flash loans
- Sonne Finance ($20M) - Known Compound V2 vulnerability

### 2023
- Euler Finance ($197M) - Missing health check after donate
- Curve Finance ($73M) - Vyper compiler reentrancy bug

### Key Statistic
**83.3%** of eligible 2024 exploits involved flash loans.

---

## Resources

- **CTF Training**: Damn Vulnerable DeFi, Ethernaut
- **Exploit Tracking**: rekt.news, DefiLlama Hacks
- **Audit Findings**: Sherlock, Code4rena, Immunefi
- **Standards**: OWASP Smart Contract Top 10 2025, scsfg.io
- **Tools**: Slither Wiki, Aderyn docs

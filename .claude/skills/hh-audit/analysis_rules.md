# Deep Analysis Rules

Per-detector criteria for determining if a finding is a real issue or false positive.

Reference: `rules/solidity.md` for project security standards.

---

## reentrancy-no-eth

**Question:** Can an attacker benefit from re-entering this function?

**Analysis Steps:**
1. Read the function code
2. Identify the external call
3. Identify state changes AFTER the external call
4. Evaluate: What state could be corrupted if re-entered?

**Confirm if:**
- Tokens (ERC20/721/1155) are transferred to user-controlled address
- Balances, ownership, or permissions are modified after external call
- Attacker could drain funds or gain unauthorized access

**False Positive if:**
- External call is to trusted contract (game engine, registry)
- State changes are non-critical (counters, timestamps, game state)
- Function has reentrancy guard
- No economic benefit from re-entry

**Heavy Helms Context:**
- GameEngine calls are trusted (we own it)
- Combat results are game state, not financial
- Player/ticket balances ARE critical

---

## unused-return

**Question:** Does ignoring this return value cause silent failures?

**Analysis Steps:**
1. Read the function making the call
2. Identify what return value is ignored
3. Check if the return value indicates success/failure
4. Evaluate: Would ignoring failure cause incorrect state?

**Confirm if:**
- Return value indicates success/failure of critical operation
- Ignoring could leave contract in inconsistent state
- External call could fail silently

**False Positive if:**
- Return value is informational only (e.g., old value)
- Function is view/pure and can't fail meaningfully
- Caller explicitly doesn't need the return data
- Using tuple destructuring with `(val, , ,)` pattern intentionally

**Heavy Helms Context:**
- `decodeCombatLog` returns `(winner, p1Data, p2Data, log)`
- Games often only need `winner`, other returns are for events
- If only using `winner`, the pattern `(winner, , , ) = ...` is fine

---

## divide-before-multiply

**Question:** Is the precision loss significant for this use case?

**Analysis Steps:**
1. Read the calculation
2. Identify the divide-then-multiply pattern
3. Calculate potential precision loss
4. Evaluate: Does this affect economic outcomes?

**Confirm if:**
- Calculation affects token amounts, fees, or rewards
- Precision loss could be > 1% in realistic scenarios
- Attacker could exploit rounding to their advantage

**False Positive if:**
- Calculation is for display/UI only
- Values are bounded (e.g., percentages 0-100)
- Precision loss is negligible (< 0.01%)
- Game mechanics where slight variance is acceptable

**Heavy Helms Context:**
- Damage calculations can have slight variance (game design)
- Fee/reward calculations need precision
- Combat stats with % modifiers are bounded

---

## incorrect-equality

**Question:** Could this strict equality check cause unexpected behavior?

**Analysis Steps:**
1. Read the comparison
2. Identify what values are being compared
3. Evaluate: Could legitimate values fail this check?

**Confirm if:**
- Comparing ETH balances (can receive unexpected ETH)
- Comparing token balances (could have dust)
- Loop termination that could be manipulated

**False Positive if:**
- Comparing enums or constants
- Comparing IDs (which are exact by design)
- Comparing counts that are fully controlled
- Game state comparisons (phases, states)

**Heavy Helms Context:**
- Game phases are enums - exact comparison is correct
- Player IDs are exact values
- Gauntlet/Tournament sizes are controlled

---

## uninitialized-local

**Question:** Is this variable actually used before being set?

**Analysis Steps:**
1. Read the function
2. Find the variable declaration
3. Trace all code paths to first use
4. Evaluate: Is there a path where it's used uninitialized?

**Confirm if:**
- Variable is used in calculation before assignment
- Conditional assignment might be skipped
- Default value (0, false, address(0)) causes issues

**False Positive if:**
- Variable is always assigned before use in all paths
- Default value is intentional and correct
- Slither mis-detected due to complex control flow

---

## calls-loop

**Question:** Could this loop be used for DoS or gas griefing?

**Analysis Steps:**
1. Read the loop
2. Identify external calls in the loop
3. Evaluate: Is loop length user-controlled?

**Confirm if:**
- Loop iterates over user-controlled array
- Single user could make loop exceed gas limit
- External call could be made to fail intentionally

**False Positive if:**
- Loop length is bounded by contract (e.g., max 32 participants)
- External calls are to trusted contracts
- Function is admin-only or has rate limiting

**Heavy Helms Context:**
- Gauntlet/Tournament have bounded participant counts
- GameEngine is trusted
- Combat loops are bounded by round limits

---

## shadowing-local

**Question:** Does this shadowing cause confusion or bugs?

**Analysis Steps:**
1. Identify the shadowed variable
2. Check if both are used in the same scope
3. Evaluate: Could developer confuse them?

**Confirm if:**
- Shadowing causes actual logic errors
- Both variables are used and could be confused
- State variable is accidentally shadowed

**False Positive if:**
- Common pattern like `owner` in function parameter
- Intentional shadowing for local scope
- No actual confusion in usage

---

## General Decision Framework

For ANY finding:

1. **Read the actual code** - Don't guess based on detector description
2. **Understand the context** - What is this function trying to do?
3. **Apply project knowledge** - Use Heavy Helms patterns from memory
4. **Consider exploitability** - Could an attacker actually benefit?
5. **Check economic impact** - Are real funds/tokens at risk?

**Verdict Options:**
- `confirmed` - Real issue, needs fix
- `false_positive` - Safe, add to memory
- `needs_review` - Uncertain, flag for human review
- `acknowledged` - Known limitation, accepted risk

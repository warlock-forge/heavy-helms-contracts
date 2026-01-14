# Security Detector Reference

## Severity Levels

| Level | Description | Action |
|-------|-------------|--------|
| **High** | Exploitable vulnerability, potential fund loss | Must fix before deployment |
| **Medium** | Security concern, may lead to issues | Should fix |
| **Low** | Minor issues, code quality | Consider fixing |
| **Informational** | Best practices, optimizations | Optional |

---

## Critical Detectors (High Impact)

### `reentrancy-eth` / `reentrancy-no-eth`
**What:** External call before state update allows re-entry attack
**Risk:** Attacker drains funds by recursively calling function
**Fix:** Follow checks-effects-interactions, use ReentrancyGuard

### `arbitrary-send-eth` / `arbitrary-send-erc20`
**What:** User-controlled destination for ETH/token transfers
**Risk:** Attacker redirects funds to their address
**Fix:** Validate recipient, use pull-over-push pattern

### `suicidal`
**What:** Unprotected selfdestruct call
**Risk:** Anyone can destroy contract and steal ETH
**Fix:** Add access control or remove selfdestruct

### `unprotected-upgrade`
**What:** Upgrade function lacks access control
**Risk:** Attacker upgrades to malicious implementation
**Fix:** Add onlyOwner or role-based modifier

### `delegatecall-loop`
**What:** Delegatecall inside a loop
**Risk:** Unexpected state changes, gas griefing
**Fix:** Avoid delegatecall in loops

### `unchecked-transfer`
**What:** ERC20 transfer return value not checked
**Risk:** Silent failure, tokens not actually sent
**Fix:** Use SafeERC20 or check return value

---

## Important Detectors (Medium Impact)

### `reentrancy-benign`
**What:** Reentrancy that doesn't seem exploitable
**Risk:** May become exploitable with code changes
**Fix:** Still follow CEI pattern

### `locked-ether`
**What:** Contract receives ETH but can't withdraw
**Risk:** Funds permanently stuck
**Fix:** Add withdrawal function

### `controlled-array-length`
**What:** Array length controlled by user input
**Risk:** DoS via gas limit on iteration
**Fix:** Add length limits, use pagination

### `tx-origin`
**What:** Using tx.origin for authorization
**Risk:** Phishing attacks via malicious contracts
**Fix:** Use msg.sender instead

### `uninitialized-state`
**What:** State variable used before initialization
**Risk:** Unexpected zero values, logic errors
**Fix:** Initialize in constructor or declaration

### `unused-return`
**What:** Return value of external call ignored
**Risk:** Missed error conditions
**Fix:** Check return value or use try/catch

### `shadowing-state`
**What:** Child contract shadows parent's state variable
**Risk:** Confusing behavior, wrong variable accessed
**Fix:** Rename variable or use explicit reference

---

## Common Detectors (Low Impact)

### `timestamp`
**What:** Using block.timestamp for logic
**Risk:** Miners can manipulate slightly (~15 sec)
**Fix:** OK for non-critical timing, avoid for precise deadlines

### `assembly`
**What:** Inline assembly usage detected
**Risk:** Bypasses Solidity safety checks
**Fix:** Document extensively, audit carefully

### `pragma`
**What:** Floating pragma (^0.8.0) instead of fixed
**Risk:** Different compiler versions may behave differently
**Fix:** Use exact version (0.8.13) for production

### `low-level-calls`
**What:** Using call/delegatecall/staticcall
**Risk:** Silent failures if not checked
**Fix:** Check return value, prefer high-level calls

### `solc-version`
**What:** Outdated or experimental compiler version
**Risk:** Missing bug fixes or security patches
**Fix:** Use stable, recent version

### `naming-convention`
**What:** Names don't follow Solidity conventions
**Risk:** Reduced readability
**Fix:** Follow camelCase/PascalCase conventions

---

## Informational Detectors

### `dead-code`
**What:** Unreachable or unused code
**Fix:** Remove to reduce contract size

### `similar-names`
**What:** Variables with confusingly similar names
**Fix:** Rename for clarity

### `too-many-digits`
**What:** Large literal numbers (e.g., 1000000)
**Fix:** Use scientific notation or named constants

### `constable-states`
**What:** State variable could be constant
**Fix:** Add `constant` modifier for gas savings

### `immutable-states`
**What:** State variable could be immutable
**Fix:** Add `immutable` modifier if set once in constructor

---

## Aderyn-Specific Detectors

### `centralization-risk`
**What:** Single address has excessive control
**Risk:** Rug pull, single point of failure
**Fix:** Use multisig, timelock, or governance

### `push-over-pull`
**What:** Contract pushes funds to users
**Risk:** Failed transfers block execution
**Fix:** Use pull pattern (users withdraw)

### `unsafe-erc20-operation`
**What:** Direct transfer/approve without SafeERC20
**Risk:** Non-compliant tokens fail silently
**Fix:** Use SafeERC20 wrapper

### `missing-zero-address-check`
**What:** Address parameter not validated
**Risk:** Accidental burn or lock
**Fix:** Add `require(addr != address(0))`

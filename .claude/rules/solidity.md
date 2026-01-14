---
paths: src/**/*.sol
---

# Solidity Rules

## Solidity Version & Built-in Protections

This project uses Solidity 0.8.13+. Key built-in protections:

- **Arithmetic is checked by default** - overflow/underflow reverts automatically. SafeMath is NOT needed.
- **`unchecked` blocks bypass this** - only use when you're 100% certain overflow is impossible (e.g., loop counters)
- **Inline assembly/Yul has NO overflow protection** - arithmetic in assembly can still overflow silently
- **Type casting can overflow** - `uint8(uint256Value)` truncates without reverting. Be explicit about downcasting.

```solidity
// SAFE - auto-reverts on overflow
uint256 result = a + b;

// DANGEROUS - explicitly bypasses protection
unchecked { result = a + b; }

// DANGEROUS - silent truncation
uint8 small = uint8(largeUint256);  // No revert, just wraps
```

## Transaction Atomicity & Revert Semantics

**Ethereum transactions are atomic.** When a revert occurs:

- ALL state changes are rolled back (mappings, variables, balances)
- ALL events emitted before the revert are erased
- Gas consumed up to the revert is NOT refunded
- The transaction can still be included in a block (sender pays gas)

**Critical misconceptions to avoid:**

```solidity
// WRONG: Thinking events persist after revert
emit Transfer(from, to, amount);
if (balances[from] < amount) revert InsufficientBalance();
// The Transfer event is GONE if this reverts

// WRONG: Assuming try/catch catches everything
try externalContract.foo() {
    // success
} catch {
    // Only catches failures in externalContract.foo()
    // Internal reverts in THIS contract still bubble up
}
```

**try/catch only catches external call failures.** The caught revert rolled back the called contract's state, but any state changes in YOUR contract before the try block persist.

## Low-Level Calls

Low-level calls (`call`, `delegatecall`, `staticcall`) do NOT auto-revert on failure. They return `(bool success, bytes data)`.

```solidity
// DANGEROUS - silent failure
target.call(data);  // If this fails, execution continues!

// SAFE - explicit check
(bool success, ) = target.call(data);
require(success, "Call failed");

// ALSO CHECK: Target existence
// call() returns true for non-existent addresses!
require(target.code.length > 0, "Target has no code");
```

**Over 80% of Solidity vulnerabilities involve incorrect use of low-level calls** - usually missing return value checks.

## Access Control (OWASP SC01 - #1 Vulnerability)

Access control vulnerabilities are the **#1 cause of smart contract hacks** per OWASP Smart Contract Top 10 (2025). In 2024 alone: **$953M lost** to access control issues.

Common mistakes:
- Missing modifiers on admin functions
- Using `tx.origin` for authorization (see below)
- Simple `require(msg.sender == owner)` that gets missed during upgrades
- Unprotected initializers in upgradeable contracts

**Use role-based access control with principle of least privilege:**

```solidity
// GOOD - explicit roles, easy to audit
modifier onlyRole(bytes32 role) {
    require(hasRole[role][msg.sender], "Unauthorized");
    _;
}

function withdrawFees() external onlyRole(FEE_MANAGER_ROLE) { ... }
```

## msg.sender vs tx.origin

**Never use `tx.origin` for authorization.**

- `msg.sender` = immediate caller (changes with each call in the chain)
- `tx.origin` = original EOA that started the transaction (never changes)

```solidity
// DANGEROUS - phishing vulnerable
require(tx.origin == owner);  // Attacker's contract can call this

// SAFE
require(msg.sender == owner);
```

**EIP-7702 Warning (Pectra upgrade, 2025):** The `tx.origin == msg.sender` check to detect EOAs is becoming unreliable. Smart contract accounts can now make these equal via self-sponsoring.

## Checks-Effects-Interactions Pattern

Always follow this pattern rigorously:

1. First, perform all necessary input validation checks
2. Second, update all state variables
3. Only then, interact with external contracts or addresses

## Data Locations: storage, memory, calldata

**Reference types (arrays, structs, mappings) require explicit data location.**

| Location | Persists | Mutable | Gas Cost | Use Case |
|----------|----------|---------|----------|----------|
| storage | Yes | Yes | Expensive | State variables, persistent data |
| memory | No | Yes | Moderate | Temporary data, return values |
| calldata | No | No | Cheapest | External function inputs (read-only) |

**Critical behaviors:**

```solidity
// REFERENCE - modifies storage directly
MyStruct storage s = myMapping[key];
s.value = 123;  // State is changed!

// COPY - does NOT modify storage
MyStruct memory s = myMapping[key];
s.value = 123;  // Only local copy changed

// GAS TIP: Use calldata for external function array/struct params you don't modify
function process(uint256[] calldata data) external;  // Cheaper than memory
```

## Mappings Behavior

**Mappings cannot be iterated or cleared.**

- `delete myMapping` does nothing useful
- `delete myMapping[key]` resets that key to default value
- The EVM doesn't track which keys exist

```solidity
// WRONG - mapping inside struct survives delete
struct User {
    uint256 balance;
    mapping(address => bool) authorized;
}
delete users[addr];  // balance = 0, but authorized mapping data PERSISTS

// WORKAROUND - track keys separately if you need iteration
mapping(address => uint256) public balances;
address[] public allUsers;  // Manually maintain for iteration
```

## Function Design

- Use explicit function visibility modifiers and appropriate natspec comments
- Utilize function modifiers for common checks, enhancing readability and reducing redundancy
- Use view and pure function modifiers appropriately to signal state access patterns
- Implement fallback and receive functions with caution, clearly documenting their purpose

## Naming Conventions

- CamelCase for contracts
- PascalCase for interfaces (prefixed with "I")

## Error Handling

- Use custom errors instead of revert strings for gas efficiency and better error handling
- Implement effective error propagation patterns in internal functions

## Events

- Implement comprehensive events for all significant state changes
- Use events for off-chain logging and indexing of important state changes
- Remember: events are erased if the transaction reverts

## Security

- Use a reentrancy lock library like OpenZeppelin's ReentrancyGuard for all external calls, even if you believe re-entrancy is not possible
- **0.8.0+ does NOT protect against reentrancy** - only arithmetic overflow
- For ERC777 tokens or other tokens with callbacks, always consider re-entrancy risk
- Use pull over push payment patterns to mitigate reentrancy and denial of service attacks
- Implement rate limiting for sensitive functions to prevent abuse
- Implement circuit breakers for critical contract functionality (Pause mechanisms)
- Be careful with block.timestamp - it can be manipulated slightly by miners, don't use for high-precision timing
- For frontrunning protection, use commit-reveal schemes or integrate with flashbots where appropriate

## Randomness

- Implement proper randomness using Chainlink VRF or similar oracle solutions
- GauntletGame uses blockhash-based commit-reveal for security and gas efficiency

## Token Handling

- Use Solady's SafeTransferLib for interacting with ERC20 tokens
- When handling decimals, be aware of token standards - most ERC20 tokens use 18 decimals but some (like USDC) use 6
- Implement EIP-2612 permit functions for gasless approvals in token contracts
- Implement proper slippage protection for DEX-like functionalities

## Gas Optimization

- Conduct thorough gas optimization, considering both deployment and runtime costs
- Implement effective storage patterns to optimize gas costs (e.g., packing variables)
- Use immutable variables for values set once at construction time
- Use libraries for complex operations to reduce contract size and improve reusability
- Use assembly for gas-intensive operations, but document extensively and use with caution
- If Solady has an implementation built already, use that instead of writing assembly from scratch
- Be aware of gas refund patterns when clearing storage (Gas cost reduction for setting to zero from non-zero)
- Prefer `calldata` over `memory` for external function parameters you don't modify

## Architecture

- Implement the Interface Segregation Principle for flexible and maintainable contracts
- Design upgradeable contracts using proven patterns like the proxy pattern when necessary
- Implement proper inheritance patterns, favoring composition over deep inheritance chains
- Implement effective state machine patterns for complex contract logic
- Clearly document the intended call flow for multi-contract systems

## Financial Calculations

- Implement proper decimal handling for financial calculations, using fixed-point arithmetic libraries when necessary
- Implement a storage pattern for token balances that require historical lookups

## Governance

- Implement timelocks for sensitive operations when governance control is needed
- Implement governance mechanisms using proper weighted voting systems if needed

## Documentation

- Implement NatSpec comments for all public and external functions

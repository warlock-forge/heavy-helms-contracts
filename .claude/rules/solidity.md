---
paths: src/**/*.sol
---

# Solidity Rules

## Checks-Effects-Interactions Pattern

Always follow this pattern rigorously:

1. First, perform all necessary input validation checks
2. Second, update all state variables
3. Only then, interact with external contracts or addresses

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

## Access Control

- Implement role-based access control patterns for fine-grained permissions
- Implement specific rules for privileged roles and document their access levels
- Implement proper access control for initializers in upgradeable contracts
- Implement proper access control for self-destruct functionality, if used
- Use freezable patterns instead of deprecated `selfdestruct`

## Security

- Use a reentrancy lock library like OpenZeppelin's ReentrancyGuard for all external calls, even if you believe re-entrancy is not possible
- Never assume external call success - always check return values or use call with return value checking
- For ERC777 tokens or other tokens with callbacks, always consider re-entrancy risk
- Use pull over push payment patterns to mitigate reentrancy and denial of service attacks
- Implement rate limiting for sensitive functions to prevent abuse
- Implement circuit breakers for critical contract functionality (Pause mechanisms)
- Be careful with block.timestamp - it can be manipulated slightly by miners, don't use for high-precision timing
- For frontrunning protection, use commit-reveal schemes or integrate with flashbots where appropriate
- Use static analysis tools like Slither and Mythril in the development workflow
- Implement timelocks and multisig controls for sensitive operations in production

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

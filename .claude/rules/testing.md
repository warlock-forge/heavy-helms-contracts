---
paths: test/**/*.sol
---

# Foundry Testing Rules

## Test Base Class

All tests inherit from `TestBase.sol` which provides:

- VRF mock system setup
- Contract deployment helpers
- Player creation utilities
- Common test fixtures

Always use existing helper methods from TestBase.

## Test Naming

- Use `testFuzz_` prefix for fuzz tests
- Use `test_` prefix for standard tests

## expectRevert Pattern

Calculate all parameters outside the expectRevert block:

BAD:

```solidity
expectRevert();
contract.someMethod(calculate(param));
```

GOOD:

```solidity
calculatedParam = calculate(param);
expectRevert();
contract.someMethod(calculatedParam);
```

## Test Structure

- Use a `setup` function in test files to set default state and initialize variables
- Implement proper setup and teardown in test files
- Use the "fail early" pattern in tests - assert preconditions before continuing complex test flows

## Foundry Features to Use

- Use Foundry's fuzzing capabilities to uncover edge cases with property-based testing
- Take advantage of Foundry's test cheatcodes for advanced testing scenarios
- Write invariant tests for critical contract properties using Foundry's invariant testing features
- Use Foundry's Fuzz testing to automatically generate test cases and find edge case bugs
- Implement stateful fuzzing tests for complex state transitions
- Use Foundry's fork testing capabilities to test against live environments
- Write appropriate test fixtures using Foundry's standard libraries
- Use Foundry's vm.startPrank/vm.stopPrank for testing access control mechanisms

## Test Coverage

- Implement a comprehensive testing strategy including unit, integration, and end-to-end tests
- Use test coverage tools and aim for high test coverage, especially for critical paths
- Test both positive and negative cases (success conditions and failure conditions)
- Test edge cases specifically (empty arrays, zero values, max uint256 values, etc.)
- Include integration tests that test contracts against each other in realistic scenarios
- Implement gas usage tests to ensure operations remain efficient
- Implement differential testing by comparing implementations
- Test gas costs of common operations to prevent economic attacks

## Advanced Testing

- Implement formal verification for critical contract components when possible
- Use symbolic execution tools for finding edge cases human testers might miss
- Conduct regular security audits and bug bounties for production-grade contracts

## Deterministic Testing

If deterministic testing is being done, ensure that the `foundry.toml` file has `block_number` and `block_timestamp` values.

## CI Considerations

- Use `skipInCI` modifier for long-running balance tests

## Critical Test Areas

- VRF completion workflows
- Queue management (especially in GauntletGame)
- Fee calculations and distributions
- Player state transitions
- Combat mechanics edge cases
- Level progression scaling

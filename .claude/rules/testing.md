---
paths: "test/**/*.sol"
---

# Heavy Helms Testing Rules

## TestBase

All tests inherit from `TestBase.sol`. Always use existing helper methods — see `testbase.md` companion in hh-test skill for the full reference.

## expectRevert Pattern

Calculate all parameters outside the expectRevert block:

```solidity
calculatedParam = calculate(param);
vm.expectRevert();
contract.someMethod(calculatedParam);
```

## CI & Simulation Tests

- Non-deterministic simulation tests (balance, progression, lethality, tournament gas) live in `test/simulation/`
- The default Foundry profile excludes `test/simulation/*` via `no_match_path` — `forge test` only runs unit tests
- Run simulations locally with `FOUNDRY_PROFILE=simulation forge test -vv`
- The `skipInCI` modifier still exists in `TestBase.sol` for VRF integration tests in `Player.t.sol`

## Deterministic Testing

If deterministic testing is being done, ensure that the `foundry.toml` file has `block_number` and `block_timestamp` values.

## Critical Test Areas

- VRF completion workflows
- Queue management (especially in GauntletGame)
- Fee calculations and distributions
- Player state transitions
- Combat mechanics edge cases
- Level progression scaling

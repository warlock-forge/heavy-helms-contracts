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

- Simulation tests (balance, progression, lethality, tournament gas) live in `test/simulation/`
- The default Foundry profile excludes `test/simulation/*` via `no_match_path` -- `forge test` only runs unit tests
- Run simulations locally with `FOUNDRY_PROFILE=simulation forge test -vv`
- Simulation tests use Foundry fuzz seeds (`testFuzz_` prefix) for randomness -- no self-seeding or `vm.roll`/`vm.warp` hacks
- Unit tests use deterministic constant seeds (e.g. `12345`) -- never fake randomness from block state

## Critical Test Areas

- VRF completion workflows
- Queue management (especially in GauntletGame)
- Fee calculations and distributions
- Player state transitions
- Combat mechanics edge cases
- Level progression scaling

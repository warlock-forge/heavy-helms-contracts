---
name: hh-test
description: Heavy Helms test specialist. Runs tests, writes unit/fuzz/invariant tests, analyzes failures. Expert in VRF mocking, blockhash randomness, stateful fuzzing, and handler patterns.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Heavy Helms Test Specialist

Expert test agent for Solidity/Foundry. Runs tests, writes new tests, diagnoses failures.

## When to Activate

- User asks to run tests, check tests, or mentions test failures
- User asks to write tests or add test coverage
- User runs `/test` command

## CRITICAL: Tree-First Workflow

**When writing NEW tests, ALWAYS create the `.tree` spec file FIRST.**

1. Create `test/specs/contract.function.tree` with test structure
2. Run `bulloak scaffold -w -s "^0.8.13" file.tree` to generate skeleton
3. Add imports, inheritance, and test logic to generated `.t.sol`
4. Verify with `bulloak check file.tree`

**Never write test code without a .tree spec.** The spec IS the documentation.

```bash
# Workflow
bulloak scaffold -w -s "^0.8.13" test/specs/myTest.tree  # Generate
bulloak check test/specs/myTest.tree                      # Validate
```

## Running Tests

### Command

```bash
forge test --no-match-test "testFuzz_" 2>&1
```

Skip fuzz tests by default (slow). Use `--match-contract X` or `--match-test X` to narrow scope.

### Reporting - BE CONCISE

**All pass:** `359 tests passed`

**Soft fails only:** `359 passed, 3 soft fails (balance tests) - all good`

**Hard fails:** List each with `ContractName::testName - error`

### Soft vs Hard Failures

**Soft (ignore):** Randomness-dependent - winner IDs, damage values, win rates, anything in BalanceTest.t.sol or GameEngineProgressionTest.t.sol

**Hard (bugs):** State transitions, permissions, fees, queue management, reverts, events, VRF flow

---

## File Organization

**Split large files by concern.** Instead of 2000+ line monoliths:

```
test/game/gauntlet/
├── GauntletGame.queue.t.sol      # Join/withdraw
├── GauntletGame.selection.t.sol  # Commit/reveal
├── GauntletGame.rewards.t.sol    # XP/tickets
├── GauntletGame.admin.t.sol      # Owner functions
└── GauntletGame.invariant.t.sol  # Invariants
```

**Use contract-per-function pattern:**
```solidity
contract JoinQueue_Test is GauntletTestBase {
    function test_JoinQueue_AddsPlayer() public { }
    function test_RevertWhen_AlreadyInQueue() public { }
}
```

See `style-guide.md` for full details.

---

## Test Categories

### 1. Unit Tests (`test_*`)
Single function behavior. Most common.

### 2. Fuzz Tests (`testFuzz_*`)
Random inputs to find edge cases. Use `bound()` to constrain:
```solidity
function testFuzz_Deposit(uint256 amount) public {
    amount = bound(amount, 1, 1e18);  // Constrain to valid range
    // test logic
}
```

### 3. Invariant Tests (`invariant_*`) - WE NEED MORE OF THESE
Stateful fuzzing - random function sequences trying to break properties.

```solidity
contract GauntletInvariantTest is TestBase, StdInvariant {
    GauntletHandler handler;

    function setUp() public override {
        super.setUp();
        handler = new GauntletHandler(gauntletGame, playerContract);
        targetContract(address(handler));
    }

    function invariant_QueueSizeMatchesPlayerCount() public {
        assertEq(
            gauntletGame.getQueueSize(),
            handler.ghost_playersInQueue()
        );
    }

    function invariant_FeesNeverExceedBalance() public {
        assertLe(
            gauntletGame.accumulatedFees(),
            address(gauntletGame).balance
        );
    }
}
```

### 4. Revert Tests (`test_RevertWhen_*`)
Always calculate values BEFORE `vm.expectRevert()`:
```solidity
function test_RevertWhen_NotOwner() public {
    uint256 playerId = PLAYER_ONE_ID;  // Calculate first
    vm.expectRevert(NotOwner.selector);
    vm.prank(ATTACKER);
    game.withdraw(playerId);
}
```

---

## Handler Pattern for Invariants

Handlers wrap protocol calls to ensure valid sequences:

```solidity
contract GauntletHandler is Test {
    GauntletGame game;
    Player playerContract;

    // Ghost variables - track cumulative state
    uint256 public ghost_playersInQueue;
    uint256 public ghost_totalFeesCollected;
    address[] public actors;

    modifier useActor(uint256 seed) {
        address actor = actors[bound(seed, 0, actors.length - 1)];
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    function joinQueue(uint256 actorSeed, uint32 playerId) external useActor(actorSeed) {
        // Bound playerId to valid range
        playerId = uint32(bound(playerId, 10001, playerContract.nextPlayerId() - 1));

        // Skip if already queued or not owner
        if (game.isPlayerQueued(playerId)) return;
        if (playerContract.ownerOf(playerId) != actors[bound(actorSeed, 0, actors.length - 1)]) return;

        game.joinQueue(playerId);
        ghost_playersInQueue++;
    }

    function withdrawFromQueue(uint256 actorSeed, uint32 playerId) external useActor(actorSeed) {
        if (!game.isPlayerQueued(playerId)) return;

        game.withdrawFromQueue(playerId);
        ghost_playersInQueue--;
    }
}
```

---

## Heavy Helms Invariants to Test

### Player Contract
- `invariant_ActiveCountMatchesNonRetired` - activePlayerCount == count of non-retired players
- `invariant_NextIdAlwaysIncreases` - nextPlayerId only goes up
- `invariant_OwnershipConsistent` - ownerOf matches balanceOf

### Game Contracts
- `invariant_FeesMatchBalance` - accumulated fees ≤ contract balance
- `invariant_QueueConsistency` - queue size matches player states
- `invariant_NoOrphanedPlayers` - players in queue are never retired
- `invariant_StateTransitionsValid` - states only move forward (OPEN→PENDING→COMPLETED)

### Tournament/Gauntlet
- `invariant_ParticipantsLocked` - once selected, participants can't leave
- `invariant_RewardsMatchConfig` - distributed rewards match configured percentages
- `invariant_DailyLimitsEnforced` - no player exceeds daily run limit

---

## Writing New Tests

**Before writing, read:**
- `style-guide.md` - Naming, organization, BTT patterns
- `testbase.md` - Helper methods
- `vrf-patterns.md` - VRF mocking
- `game-patterns.md` - Game-specific patterns
- `invariant-patterns.md` - Stateful fuzz testing
- `install.md` - Tool installation (bulloak)

### Template

```solidity
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";

contract MyTest is TestBase {
    address public PLAYER_ONE;
    uint32 public PLAYER_ONE_ID;

    function setUp() public override {
        super.setUp();  // ALWAYS call

        PLAYER_ONE = address(0x1001);
        PLAYER_ONE_ID = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        vm.deal(PLAYER_ONE, 100 ether);
    }

    function test_BasicBehavior() public {
        // Arrange
        // Act
        // Assert
    }
}
```

### Critical Patterns

**VRF - recordLogs BEFORE request:**
```solidity
vm.recordLogs();
uint256 requestId = game.startBattle();
_fulfillVRFRequest(address(game));
```

**Blockhash - Roll to block + 1:**
```solidity
vm.roll(selectionBlock + 1);  // blockhash(N) available from N+1
game.executeSelection();
```

**Events:**
```solidity
vm.expectEmit(true, true, true, true);
emit ExpectedEvent(arg1, arg2);
contract.methodThatEmits();
```

---

## Fighter ID Ranges

| Range | Type | Contract |
|-------|------|----------|
| 1-2000 | DEFAULT_PLAYER | defaultPlayerContract |
| 2001-10000 | MONSTER | monsterContract |
| 10001+ | PLAYER | playerContract |

---

## Foundry Config (foundry.toml)

```toml
[fuzz]
runs = 256

[invariant]
runs = 256
depth = 15
fail_on_revert = false
```

Increase `runs` and `depth` for more thorough invariant testing.

---

## Bulloak - BTT Tooling

Use bulloak to scaffold tests from `.tree` specs and validate implementation.

### Install

See `install.md` for full installation guide. Quick:
```bash
cargo install bulloak
```

### Workflow

1. **Write spec** - Create `.tree` file defining test structure
2. **Scaffold** - Generate Solidity skeleton
3. **Implement** - Fill in test logic
4. **Check** - Validate implementation matches spec (CI)

### Commands
```bash
bulloak scaffold foo.tree              # Generate .sol from .tree
bulloak scaffold foo.tree -o out.t.sol # Output to specific file
bulloak check foo.tree                 # Verify impl matches spec
bulloak check --fix foo.tree           # Auto-add missing tests
```

### Example .tree File
```
JoinQueue_Test
├── Given game is disabled
│   └── It should revert with GameDisabled.
└── Given game is enabled
    ├── When player already in queue
    │   └── It should revert with AlreadyInQueue.
    ├── When player is retired
    │   └── It should revert with PlayerRetired.
    └── When all valid
        ├── It should add player to queue.
        └── It should emit PlayerJoinedQueue.
```

### CI Integration
Add to CI pipeline alongside forge test:
```bash
bulloak check test/**/*.tree  # Fail if tests don't match specs
```

---

## Quick Reference

```bash
# Forge
forge test                              # All tests
forge test --match-contract Player      # Specific contract
forge test --match-test testDeposit     # Specific test
forge test -vvv                         # Verbose with traces
forge test --gas-report                 # Gas costs
forge test --no-match-test "testFuzz_"  # Skip fuzz (faster)

# Bulloak
bulloak scaffold *.tree                 # Generate from all trees
bulloak check *.tree                    # Validate all specs
bulloak check --fix *.tree              # Auto-fix missing tests
```

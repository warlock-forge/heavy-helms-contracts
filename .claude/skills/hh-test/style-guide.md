# Test Style Guide

Modern Foundry test organization standards for Heavy Helms.

## File Organization

### Split Large Files by Concern

Instead of one 2000+ line file:
```
test/game/GauntletGame.t.sol  # 2438 lines - too big!
```

Split by functional area:
```
test/game/gauntlet/
├── GauntletGame.queue.t.sol      # Join/withdraw queue
├── GauntletGame.selection.t.sol  # Commit/reveal/selection
├── GauntletGame.rewards.t.sol    # XP/ticket rewards
├── GauntletGame.admin.t.sol      # Owner functions
├── GauntletGame.dailyLimit.t.sol # Daily limit logic
└── GauntletGame.invariant.t.sol  # Invariant tests
```

### Contract-Per-Function Pattern

Each public function gets its own test contract:

```solidity
// GauntletGame.queue.t.sol

contract JoinQueue_Test is GauntletTestBase {
    function test_JoinQueue_AddsPlayerToQueue() public { }
    function test_JoinQueue_EmitsEvent() public { }
    function test_RevertWhen_AlreadyInQueue() public { }
    function test_RevertWhen_PlayerRetired() public { }
    function test_RevertWhen_NotPlayerOwner() public { }
}

contract WithdrawFromQueue_Test is GauntletTestBase {
    function test_WithdrawFromQueue_RemovesPlayer() public { }
    function test_RevertWhen_NotInQueue() public { }
    function test_RevertWhen_GauntletStarted() public { }
}
```

**Benefits:**
- Smaller contracts compile faster
- Clear grouping in test output
- Easy to find tests for specific functions

---

## Naming Conventions

### Test Functions

```
test_[Description]                    # Happy path
test_RevertWhen_[Condition]          # Revert on parameter/input
test_RevertGiven_[State]             # Revert on contract state
testFuzz_[Description]               # Fuzz test
testFork_[Description]               # Fork test
invariant_[Property]                 # Invariant test
```

**Examples:**
```solidity
function test_JoinQueue_AddsPlayerToQueue() public { }
function test_RevertWhen_AmountIsZero() public { }
function test_RevertGiven_GameDisabled() public { }
function testFuzz_JoinQueue_WithRandomPlayers(uint256 count) public { }
```

### Modifiers for Conditions

Use modifiers to express preconditions clearly:

```solidity
modifier givenGameEnabled() {
    game.setGameEnabled(true);
    _;
}

modifier givenPlayerInQueue(uint32 playerId) {
    vm.prank(playerContract.ownerOf(playerId));
    game.joinQueue(playerId);
    _;
}

modifier whenGauntletPending() {
    _fillQueueAndStartGauntlet();
    _;
}

// Usage
function test_WithdrawFromQueue_RemovesPlayer()
    public
    givenGameEnabled
    givenPlayerInQueue(PLAYER_ONE_ID)
{
    vm.prank(PLAYER_ONE);
    game.withdrawFromQueue(PLAYER_ONE_ID);
    assertFalse(game.isPlayerQueued(PLAYER_ONE_ID));
}
```

### Constants

Use `ALL_CAPS_WITH_UNDERSCORES`:

```solidity
uint256 constant ENTRY_FEE = 0.01 ether;
uint256 constant MAX_QUEUE_SIZE = 64;
address constant ATTACKER = address(0xBAD);
```

---

## BTT (Branching Tree Technique) + Bulloak

### Install Bulloak
```bash
cargo install bulloak
```

### Workflow

1. **Create `.tree` spec** - Define test structure in natural language
2. **Scaffold** - `bulloak scaffold` generates Solidity skeleton
3. **Implement** - Fill in actual test logic
4. **Validate** - `bulloak check` ensures impl matches spec (use in CI)

### Example .tree File

```
// test/game/gauntlet/joinQueue.tree

JoinQueue_Test
├── Given game is disabled
│   └── It should revert with GameDisabled.
└── Given game is enabled
    ├── When player is already in queue
    │   └── It should revert with AlreadyInQueue.
    ├── When player is retired
    │   └── It should revert with PlayerRetired.
    ├── When caller is not player owner
    │   └── It should revert with NotPlayerOwner.
    └── When all conditions valid
        ├── It should add player to queue.
        ├── It should emit PlayerJoinedQueue event.
        └── It should increment queue size.
```

### Scaffold Command

```bash
bulloak scaffold -s "^0.8.13" test/game/gauntlet/joinQueue.tree
```

Generates:
```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract JoinQueue_Test {
    modifier givenGameIsDisabled() {
        _;
    }

    modifier givenGameIsEnabled() {
        _;
    }

    modifier whenPlayerIsAlreadyInQueue() {
        _;
    }

    modifier whenPlayerIsRetired() {
        _;
    }

    modifier whenCallerIsNotPlayerOwner() {
        _;
    }

    modifier whenAllConditionsValid() {
        _;
    }

    function test_RevertGiven_GameIsDisabled()
        external
        givenGameIsDisabled
    {
        // It should revert with GameDisabled.
    }

    function test_RevertWhen_PlayerIsAlreadyInQueue()
        external
        givenGameIsEnabled
        whenPlayerIsAlreadyInQueue
    {
        // It should revert with AlreadyInQueue.
    }

    function test_RevertWhen_PlayerIsRetired()
        external
        givenGameIsEnabled
        whenPlayerIsRetired
    {
        // It should revert with PlayerRetired.
    }

    function test_RevertWhen_CallerIsNotPlayerOwner()
        external
        givenGameIsEnabled
        whenCallerIsNotPlayerOwner
    {
        // It should revert with NotPlayerOwner.
    }

    function test_WhenAllConditionsValid()
        external
        givenGameIsEnabled
        whenAllConditionsValid
    {
        // It should add player to queue.
        // It should emit PlayerJoinedQueue event.
        // It should increment queue size.
    }
}
```

### Check Command (CI)

```bash
# Verify implementation matches spec
bulloak check test/game/gauntlet/joinQueue.tree

# Auto-fix missing tests
bulloak check --fix test/game/gauntlet/joinQueue.tree
```

### .tree Syntax Rules

| Keyword | Use For | Example |
|---------|---------|---------|
| `Given` | Contract state | `Given game is disabled` |
| `When` | Parameters/caller | `When amount is zero` |
| `It should` | Expected behavior | `It should revert.` |

- Keywords are case-insensitive
- Use `├──` and `└──` for tree structure
- Actions end with `.` (become comments in test)
- Conditions don't end with `.` (become modifiers)

---

## Test Structure

### AAA Pattern (Arrange-Act-Assert)

```solidity
function test_JoinQueue_AddsPlayerToQueue() public {
    // Arrange
    uint32 playerId = PLAYER_ONE_ID;
    uint256 queueSizeBefore = game.getQueueSize();

    // Act
    vm.prank(PLAYER_ONE);
    game.joinQueue(playerId);

    // Assert
    assertTrue(game.isPlayerQueued(playerId));
    assertEq(game.getQueueSize(), queueSizeBefore + 1);
}
```

### Assertion Messages

Always add descriptive messages for complex assertions:

```solidity
assertEq(
    game.getQueueSize(),
    expectedSize,
    "Queue size should match after join"
);

assertLe(
    game.accumulatedFees(),
    address(game).balance,
    "Fees must never exceed contract balance"
);
```

---

## Shared Test Base

Create per-contract test bases for shared setup:

```solidity
// test/game/gauntlet/GauntletTestBase.sol

abstract contract GauntletTestBase is TestBase {
    GauntletGame public game;

    address public PLAYER_ONE;
    address public PLAYER_TWO;
    uint32 public PLAYER_ONE_ID;
    uint32 public PLAYER_TWO_ID;

    function setUp() public virtual override {
        super.setUp();

        game = new GauntletGame(/* deps */);
        _setupVRFConsumer(address(game));
        _setupGamePermissions(address(game));

        PLAYER_ONE = makeAddr("player1");
        PLAYER_TWO = makeAddr("player2");
        PLAYER_ONE_ID = _createPlayerWithFunds(PLAYER_ONE);
        PLAYER_TWO_ID = _createPlayerWithFunds(PLAYER_TWO);
    }

    function _createPlayerWithFunds(address owner) internal returns (uint32) {
        uint32 id = _createPlayerAndFulfillVRF(owner, playerContract, false);
        vm.deal(owner, 100 ether);
        return id;
    }

    function _fillQueue(uint256 count) internal {
        // Helper to fill queue with players
    }
}
```

---

## Don'ts

❌ **Don't** put assertions in `setUp()` - use `test_SetUpState()` instead

❌ **Don't** use magic numbers - define constants

❌ **Don't** mix concerns in one giant file

❌ **Don't** use inconsistent naming (`testBug_`, `testFix_`)

❌ **Don't** duplicate setup code - use modifiers and helpers

❌ **Don't** write tests without descriptive names

---

## Migration Path

For existing large files:

1. **Create test base** - Extract shared setup to `ContractTestBase.sol`
2. **Identify groups** - List all tests, group by function/concern
3. **Create new files** - One file per concern with contract-per-function
4. **Move tests** - Keep old file temporarily, move tests incrementally
5. **Add modifiers** - Replace inline setup with modifiers
6. **Delete old file** - Once all tests migrated

---

## Quick Reference

| Pattern | Example |
|---------|---------|
| Happy path | `test_JoinQueue_AddsPlayer()` |
| Revert (input) | `test_RevertWhen_AmountZero()` |
| Revert (state) | `test_RevertGiven_GameDisabled()` |
| Fuzz | `testFuzz_JoinQueue(uint256 count)` |
| Invariant | `invariant_QueueSizeConsistent()` |
| Modifier | `givenPlayerInQueue(playerId)` |
| Constant | `uint256 constant MAX_SIZE = 64;` |

**Sources:**
- [Foundry Best Practices](https://getfoundry.sh/guides/best-practices/writing-tests/)
- [BTT Examples](https://github.com/PaulRBerg/btt-examples)
- [Bulloak](https://www.bulloak.dev/)
- [Sablier BTT Discussion](https://github.com/sablier-labs/lockup/discussions/647)

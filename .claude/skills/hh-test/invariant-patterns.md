# Invariant Testing Patterns for Heavy Helms

## What Are Invariants?

Invariants are properties that must ALWAYS be true, regardless of what sequence of actions occurs. Foundry's invariant testing randomly calls contract functions trying to break these properties.

## Setup Structure

```solidity
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract MyInvariantTest is TestBase, StdInvariant {
    MyHandler handler;

    function setUp() public override {
        super.setUp();

        // Deploy handler with references to contracts under test
        handler = new MyHandler(targetContract, playerContract);

        // Tell Foundry to only call handler functions
        targetContract(address(handler));

        // Optionally exclude specific selectors
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = handler.riskyFunction.selector;
        targetSelector(FuzzSelector({
            addr: address(handler),
            selectors: selectors
        }));
    }

    function invariant_MyProperty() public {
        // Assert something that must always be true
        assertGe(contract.balance(), contract.accumulatedFees());
    }
}
```

## Handler Pattern

Handlers mediate between fuzzer and protocol. They:
1. Bound inputs to valid ranges
2. Skip invalid states gracefully (return early, don't revert)
3. Track "ghost variables" for invariant assertions

```solidity
contract GauntletHandler is Test {
    GauntletGame public game;
    Player public playerContract;

    // Ghost variables - cumulative state tracking
    uint256 public ghost_totalJoins;
    uint256 public ghost_totalWithdraws;
    uint256 public ghost_feesCollected;

    // Actor management
    address[] public actors;
    mapping(address => uint32[]) public actorPlayers;

    constructor(GauntletGame _game, Player _player) {
        game = _game;
        playerContract = _player;

        // Setup actors with players
        for (uint i = 0; i < 10; i++) {
            address actor = address(uint160(0x1000 + i));
            actors.push(actor);
            vm.deal(actor, 100 ether);
            // Create players for each actor...
        }
    }

    modifier useActor(uint256 seed) {
        uint256 index = bound(seed, 0, actors.length - 1);
        vm.startPrank(actors[index]);
        _;
        vm.stopPrank();
    }

    function joinQueue(uint256 actorSeed, uint256 playerIndex) external useActor(actorSeed) {
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        uint32[] storage players = actorPlayers[actor];

        if (players.length == 0) return;  // No players, skip

        uint32 playerId = players[bound(playerIndex, 0, players.length - 1)];

        if (game.isPlayerQueued(playerId)) return;  // Already queued, skip
        if (playerContract.isRetired(playerId)) return;  // Retired, skip

        game.joinQueue(playerId);
        ghost_totalJoins++;
    }

    function withdrawFromQueue(uint256 actorSeed, uint256 playerIndex) external useActor(actorSeed) {
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        uint32[] storage players = actorPlayers[actor];

        if (players.length == 0) return;

        uint32 playerId = players[bound(playerIndex, 0, players.length - 1)];

        if (!game.isPlayerQueued(playerId)) return;  // Not queued, skip

        game.withdrawFromQueue(playerId);
        ghost_totalWithdraws++;
    }
}
```

## Key Invariants for Heavy Helms

### Player Contract

```solidity
function invariant_ActivePlayerCount() public {
    uint256 counted = 0;
    for (uint32 i = 10001; i < playerContract.nextPlayerId(); i++) {
        if (!playerContract.isRetired(i)) counted++;
    }
    assertEq(playerContract.activePlayerCount(), counted);
}

function invariant_PlayerIdNeverDecreases() public {
    assertGe(playerContract.nextPlayerId(), handler.ghost_initialNextId());
}

function invariant_SlotCountsValid() public {
    // No player has more players than slots
    for (uint i = 0; i < handler.actorCount(); i++) {
        address actor = handler.actors(i);
        assertLe(
            playerContract.balanceOf(actor),
            playerContract.getPlayerSlots(actor)
        );
    }
}
```

### Queue-Based Games (Gauntlet, Tournament)

```solidity
function invariant_QueueConsistency() public {
    // Queue size matches join/withdraw ghost tracking
    assertEq(
        game.getQueueSize(),
        handler.ghost_totalJoins() - handler.ghost_totalWithdraws()
    );
}

function invariant_NoRetiredPlayersInQueue() public {
    uint32[] memory queued = game.getQueuedPlayers();
    for (uint i = 0; i < queued.length; i++) {
        assertFalse(playerContract.isRetired(queued[i]));
    }
}

function invariant_DailyLimitsRespected() public {
    for (uint i = 0; i < handler.actorCount(); i++) {
        address actor = handler.actors(i);
        uint32[] memory players = handler.getActorPlayers(actor);
        for (uint j = 0; j < players.length; j++) {
            assertLe(
                game.getDailyRunCount(players[j]),
                game.dailyGauntletLimit()
            );
        }
    }
}
```

### Fee Handling

```solidity
function invariant_FeesNeverExceedBalance() public {
    assertLe(game.accumulatedFees(), address(game).balance);
}

function invariant_FeesOnlyIncrease() public {
    assertGe(game.accumulatedFees(), handler.ghost_lastFeeSnapshot());
}
```

### State Machines

```solidity
function invariant_ValidStateTransitions() public {
    // If tournament is COMPLETED, it must have been PENDING first
    if (game.tournamentState() == TournamentState.COMPLETED) {
        assertTrue(handler.ghost_sawPendingState());
    }
}
```

## Ghost Variable Patterns

Ghost variables track information the fuzzer can't see:

```solidity
// Cumulative counters
uint256 public ghost_totalDeposits;
uint256 public ghost_totalWithdrawals;

// Snapshots for monotonicity checks
uint256 public ghost_lastBalance;
uint32 public ghost_lastPlayerId;

// State tracking
bool public ghost_sawPendingState;
uint256 public ghost_maxQueueSizeSeen;

// Sum tracking for conservation invariants
uint256 public ghost_sumOfAllShares;
```

## Configuration

In `foundry.toml`:

```toml
[invariant]
runs = 256          # Number of test runs
depth = 15          # Function calls per run
fail_on_revert = false  # Don't fail on expected reverts
dictionary_weight = 80   # Use values from state
```

For thorough testing before release:
```toml
[invariant]
runs = 1000
depth = 50
```

## Running Invariant Tests

```bash
# Run all invariant tests
forge test --match-test "invariant_"

# Run specific invariant test contract
forge test --match-contract GauntletInvariantTest

# Verbose output to see call sequences on failure
forge test --match-test "invariant_" -vvv
```

## Common Pitfalls

1. **Handler reverts** - Use early returns, not reverts, for invalid states
2. **Unbounded inputs** - Always use `bound()` for fuzzed parameters
3. **Missing state** - Ghost variables must track everything invariants need
4. **Too narrow targeting** - Test the handler, not just one function
5. **Ignoring depth** - Bugs often need 10+ calls to surface

## When to Write Invariants

High-value targets:
- Anything handling ETH/tokens (fee accumulation, withdrawals)
- State machines (tournament/gauntlet phases)
- Queue management (join/leave/selection)
- Counter consistency (player counts, IDs)
- Access control boundaries

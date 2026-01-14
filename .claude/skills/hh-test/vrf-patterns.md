# VRF Testing Patterns

Heavy Helms uses two randomness approaches:
1. **Chainlink VRF 2.5** - For Player creation, DuelGame, MonsterBattleGame
2. **Blockhash-based** - For GauntletGame, TournamentGame (3-phase commit-reveal)

## Chainlink VRF Pattern

### Basic Flow

```solidity
// 1. BEFORE making VRF request - start recording logs
vm.recordLogs();

// 2. Make the VRF request
vm.prank(user);
uint256 requestId = game.requestSomething{value: fee}(params);

// 3. Fulfill using helper (extracts requestId from logs)
_fulfillVRFRequest(address(game));

// 4. Optionally extract result from logs
uint32 resultId = _getPlayerIdFromLogs(user, requestId);
```

### Why recordLogs() Must Be First

The `_fulfillVRFRequest()` helper extracts the requestId from the `RandomWordsRequested` event:

```solidity
// Event signature: 0xeb0e3652e0f44f417695e6e90f2f42c99b65cd7169074c5a654b16b9748c3a4e
// Parameters: keyHash (indexed), requestId (in data), preSeed, subId (indexed), ...

Vm.Log[] memory entries = vm.getRecordedLogs();
for (uint256 i = 0; i < entries.length; i++) {
    if (entries[i].topics[0] == 0xeb0e3652e0f44f417695e6e90f2f42c99b65cd7169074c5a654b16b9748c3a4e) {
        (requestId,) = abi.decode(entries[i].data, (uint256, uint256));
        break;
    }
}
```

If you don't call `vm.recordLogs()` before the request, the event won't be captured.

### Player Creation Example

```solidity
function testCreatePlayer() public {
    vm.recordLogs();

    vm.deal(PLAYER_ONE, playerContract.createPlayerFeeAmount());
    vm.prank(PLAYER_ONE);
    uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(false);

    // Fulfill VRF
    _fulfillVRFRequest(address(playerContract));

    // Extract player ID from logs
    uint32 playerId = _getPlayerIdFromLogs(PLAYER_ONE, requestId);

    // Now playerId is usable
    IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
    _assertStatRanges(stats);
}
```

### DuelGame VRF Example

```solidity
function testDuelWithVRF() public {
    // Create challenge (no VRF yet)
    vm.prank(PLAYER_ONE);
    uint256 challengeId = game.initiateChallengeWithTicket(loadout, PLAYER_TWO_ID);

    // Accept triggers VRF request
    vm.recordLogs();  // Start recording BEFORE accept
    vm.prank(PLAYER_TWO);
    game.acceptChallenge(challengeId, defenderLoadout);

    // Fulfill VRF to complete duel
    _fulfillVRFRequest(address(game));

    // Challenge is now COMPLETED
    (,,, DuelGame.ChallengeState state,,,) = game.getChallenge(challengeId);
    assertEq(uint8(state), uint8(DuelGame.ChallengeState.COMPLETED));
}
```

### Testing VRF Without Fulfillment

Use `_createPlayerRequest()` to test pending state:

```solidity
function testPendingVRFRequest() public {
    uint256 requestId = _createPlayerRequest(PLAYER_ONE, playerContract, false);

    // Request exists but not fulfilled
    (bool exists, bool fulfilled, address owner) = playerContract.getRequestStatus(requestId);
    assertTrue(exists);
    assertFalse(fulfilled);
    assertEq(owner, PLAYER_ONE);

    // Player doesn't exist yet
    vm.expectRevert();
    playerContract.getPlayer(10001);
}
```

### VRF Timeout Recovery Testing

```solidity
function testVRFTimeoutRecovery() public {
    // Create pending challenge
    vm.prank(PLAYER_ONE);
    uint256 challengeId = game.initiateChallengeWithTicket(loadout, PLAYER_TWO_ID);

    vm.recordLogs();
    vm.prank(PLAYER_TWO);
    game.acceptChallenge(challengeId, defenderLoadout);

    // DON'T fulfill - simulate VRF timeout

    // Advance time past timeout
    vm.warp(block.timestamp + game.vrfRequestTimeout() + 1);

    // Recovery should work now
    vm.prank(PLAYER_ONE);  // challenger or defender can recover
    game.recoverTimedOutVRF(challengeId);

    // Challenge marked completed (no winner)
    (,,, DuelGame.ChallengeState state,,,) = game.getChallenge(challengeId);
    assertEq(uint8(state), uint8(DuelGame.ChallengeState.COMPLETED));
}
```

## Blockhash-Based Pattern (3-Phase)

Used by GauntletGame and TournamentGame for MEV resistance.

### The Three Phases

1. **COMMIT** - Record block number, set future selection block
2. **SELECT** - At selection block + 1, use blockhash for randomness
3. **EXECUTE** - At tournament block + 1, run tournament

### Why Block + 1?

`blockhash(N)` returns 0 when called from block N. You must be at block N+1 or later:

```solidity
// At block 100
uint256 hash = blockhash(100);  // Returns 0!

// At block 101
uint256 hash = blockhash(100);  // Returns actual hash
```

### GauntletGame Example

```solidity
function testThreePhaseGauntlet() public {
    // Queue 4 players
    for (uint i = 0; i < 4; i++) {
        vm.prank(players[i]);
        game.queueForGauntlet(loadouts[i]);
    }

    // PHASE 1: COMMIT
    game.tryStartGauntlet();
    (bool exists, uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();
    assertTrue(exists);

    // PHASE 2: SELECT
    // Must advance to selectionBlock + 1 for valid blockhash
    vm.roll(selectionBlock + 1);
    vm.prevrandao(bytes32(uint256(12345)));  // Optional: set deterministic seed
    game.tryStartGauntlet();

    (,, uint256 tournamentBlock,,,) = game.getPendingGauntletInfo();

    // PHASE 3: EXECUTE
    vm.roll(tournamentBlock + 1);
    vm.prevrandao(bytes32(uint256(67890)));
    game.tryStartGauntlet();

    // Gauntlet complete
    GauntletGame.Gauntlet memory gauntlet = game.getGauntletData(0);
    assertEq(uint8(gauntlet.state), uint8(GauntletGame.GauntletState.COMPLETED));
    assertTrue(gauntlet.championId > 0);
}
```

### Testing Invalid Blockhash

```solidity
function testInvalidBlockhash() public {
    // Queue and commit
    game.tryStartGauntlet();
    (,uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();

    // Roll to exact selection block (NOT +1)
    vm.roll(selectionBlock);  // blockhash will return 0!

    vm.expectRevert(InvalidBlockhash.selector);
    game.tryStartGauntlet();
}
```

### Testing 256-Block Recovery

After 256 blocks, blockhash returns 0 and recovery triggers:

```solidity
function testAutoRecoveryAfter256Blocks() public {
    // Queue and commit
    game.tryStartGauntlet();
    (,uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();

    // Jump way past 256 blocks
    vm.roll(selectionBlock + 300);

    // This triggers auto-recovery instead of executing
    game.tryStartGauntlet();

    // Pending gauntlet cleared, players back in queue
    (bool exists,,,,,) = game.getPendingGauntletInfo();
    assertFalse(exists);
    assertEq(game.getQueueSize(), 4);  // Players restored to queue
}
```

### Hybrid Selection Pattern

When queue has more players than gauntlet size:

```solidity
function testHybridSelection() public {
    // Queue 16 players, gauntlet size = 8
    for (uint i = 0; i < 16; i++) {
        vm.prank(players[i]);
        game.queueForGauntlet(loadouts[i]);
    }
    assertEq(game.getQueueSize(), 16);

    // Phase 1: Commit
    game.tryStartGauntlet();

    // Phase 2: Select (takes 8 of 16)
    vm.roll(selectionBlock + 1);
    game.tryStartGauntlet();

    // 8 selected for tournament, 8 remain in queue
    assertEq(game.getQueueSize(), 8);

    // Continue to execute...
}
```

## Gas Protection Testing

Both VRF-based games have gas price limits to prevent MEV:

```solidity
function testGasProtection() public {
    // High gas should fail
    vm.txGasPrice(0.2 gwei);  // Above 0.1 gwei default limit
    vm.prank(PLAYER_TWO);
    vm.expectRevert(GasPriceTooHigh.selector);
    game.acceptChallenge(challengeId, loadout);

    // At limit should work
    vm.txGasPrice(0.1 gwei);
    vm.prank(PLAYER_TWO);
    game.acceptChallenge(challengeId, loadout);  // Succeeds
}
```

## Common VRF Test Mistakes

### 1. Forgetting recordLogs()
```solidity
// BAD - VRF request won't be captured
uint256 requestId = game.request();
_fulfillVRFRequest(address(game));  // Fails - no request found

// GOOD
vm.recordLogs();
uint256 requestId = game.request();
_fulfillVRFRequest(address(game));
```

### 2. Wrong block for blockhash
```solidity
// BAD - at exact block
vm.roll(selectionBlock);
game.tryStartGauntlet();  // InvalidBlockhash!

// GOOD - at block + 1
vm.roll(selectionBlock + 1);
game.tryStartGauntlet();
```

### 3. Not adding VRF consumer
```solidity
// BAD - forgot to add consumer
game = new DuelGame(...);
// VRF requests will fail!

// GOOD
game = new DuelGame(...);
vrfMock.addConsumer(subscriptionId, address(game));
```

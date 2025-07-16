# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Heavy Helms is a Solidity-based on-chain game featuring combat mechanics, NFT skins, and multiple game modes. The project uses Foundry for development and testing, with Gelato VRF for randomness.

## Key Commands

### Build
```bash
forge build
```

### Test
```bash
forge test                    # Run all tests
forge test -vv               # Run with verbose output
forge test --match-test      # Run specific test function
forge test --match-contract  # Run specific test contract
```

### Deployment & Scripts
```bash
forge script <script-path> --broadcast    # Deploy/execute with transaction
forge script <script-path>                # Dry run without broadcasting
```

### Code Quality
```bash
forge fmt         # Format Solidity code
forge coverage    # Generate test coverage report
forge snapshot    # Create gas snapshots for tests
```

## Architecture Overview

### Core Contract Structure

1. **Fighter System** (`src/fighters/`)
   - `Fighter.sol`: Base contract for all fighter types
   - `Player.sol`: Main player characters owned by users
   - `DefaultPlayer.sol`: AI-controlled default players
   - `Monster.sol`: Enemy monsters for PvE content
   - Libraries: `DefaultPlayerLibrary.sol`, `MonsterLibrary.sol` for fighter generation

2. **Game Engine** (`src/game/`)
   - `GameEngine.sol`: Core combat mechanics and battle resolution
   - `EquipmentRequirements.sol`: Equipment validation and requirements
   - Game Modes:
     - `BaseGame.sol`: Abstract base for all game modes
     - `PracticeGame.sol`: Practice mode against AI
     - `DuelGame.sol`: PvP dueling system
     - `GauntletGame.sol`: Tournament-style battles

3. **NFT System** (`src/nft/`)
   - `GameOwnedNFT.sol`: Base NFT contract
   - Skin NFTs: `DefaultPlayerSkinNFT.sol`, `MonsterSkinNFT.sol`, `PlayerSkinNFT.sol`
   - `UnlockablePlayerSkinNFT.sol`: Special unlockable skins

4. **Registry System** (`src/fighters/registries/`)
   - `PlayerSkinRegistry.sol`: Manages skin collections and validation
   - `PlayerNameRegistry.sol`, `MonsterNameRegistry.sol`: Name generation systems

### Key Design Patterns

1. **VRF Integration**: Uses Gelato VRF for on-chain randomness
   - Games request randomness for fair combat resolution
   - Mock system available for testing (`GelatoVRFAutoMock.sol`)

2. **Fighter ID Ranges**:
   - Players: 1-2000
   - Default Players: 1001-2000
   - Monsters: 2001-10000

3. **Combat System**:
   - Turn-based combat with stamina management
   - Multiple combat results (miss, attack, crit, block, counter, etc.)
   - Equipment affects combat outcomes

4. **State Management**:
   - Players have registration states for different game modes
   - Games track pending VRF requests

## Testing Patterns

### Test Base Class
All tests inherit from `TestBase.sol` which provides:
- VRF mock system setup
- Contract deployment helpers
- Player creation utilities
- Common test fixtures

### Testing Best Practices (from Cursor rules)
1. **Always use existing helper methods** from TestBase - don't recreate functionality
2. Use `testFuzz_` prefix for fuzz tests
3. Calculate parameters outside `expectRevert` blocks
4. Follow established patterns for:
   - Player creation and management
   - Combat simulation
   - State validation
   - Gas testing

### Critical Test Areas
- VRF completion workflows
- Queue management (especially in GauntletGame)
- Fee calculations and distributions
- Player state transitions
- Combat mechanics edge cases

## Development Workflow

1. **Environment Setup**:
   ```bash
   forge install --no-git foundry-rs/forge-std@1eea5ba transmissions11/solmate@c93f771 gelatodigital/vrf-contracts@fdb85db
   ```

2. **Configuration** (`.env` file):
   ```
   RPC_URL=<YOUR RPC URL>              # Optional for forked testing
   PK=<YOUR PRIVATE KEY>               # For deployment
   GELATO_VRF_OPERATOR=<VRF OPERATOR>  # For VRF setup
   ```

3. **Deployment Order**:
   - GameEngine → EquipmentRequirements → Registries → Fighters → Games

## Security Considerations

1. **Checks-Effects-Interactions Pattern**: Always followed for reentrancy protection
2. **Access Control**: Owner-based permissions, whitelisting for games
3. **VRF Security**: Proper validation of VRF responses
4. **Fee Handling**: Careful arithmetic to prevent overflow/underflow

## Common Patterns

1. **Error Handling**: Custom errors used throughout (e.g., `error ZeroAddress()`)
2. **Events**: Comprehensive events for all state changes
3. **Modifiers**: Common validation in modifiers (e.g., `onlyWhitelistedGame`)
4. **Libraries**: Extensive use of libraries for code reuse and gas optimization

## Important Notes

- **Via IR**: Enabled in foundry.toml for optimization
- **Solmate**: Primary dependency for gas-optimized contracts
- **Testing**: Extensive test coverage expected, use `-vv` for debugging
- **Gas Optimization**: Critical due to on-chain game nature
- **Cursor Rules**: Follow established patterns in `.cursor/rules/` for consistency

## Git Commit Rules

- **NEVER add advertising or self-promotion to commit messages**
- Keep commit messages clean and professional
- Focus on what changed, not who made the changes
- No "Generated with" or "Co-Authored-By" additions

## Bug Fixes & Security Considerations

### Gauntlet Queue Selection Exploit

**Issue Identified**: In GauntletGame.sol, when the queue has more players than the gauntlet size, attackers can time their call to `tryStartGauntlet()` to manipulate player selection. Since the pseudo-randomness uses predictable block variables (`block.timestamp`, `block.prevrandao`), sophisticated users can calculate whether they'll be selected and only trigger the gauntlet when the randomness favors them.

**Current Vulnerable Code**:
```solidity
// GauntletGame.sol:340-341
uint256 selectionSeed = uint256(keccak256(abi.encodePacked(
    block.timestamp, block.prevrandao, address(this), currentQueueSize
)));
```

**Exploit Scenario**: 
- 30 players in queue, gauntlet size 8
- Attacker calculates: "If I call tryStartGauntlet() now, will I be selected?"
- If yes → trigger gauntlet
- If no → wait for next block and recalculate

**Proposed Solution: Future Blockhash Selection**

Use a two-phase commit-reveal approach where selection randomness comes from a future block that can't be predicted:

```solidity
struct PendingGauntlet {
    uint256 selectionBlock;
    uint32[] queueSnapshot;
    uint256 timestamp;
    bool exists;
}

PendingGauntlet public pendingGauntlet;

function tryStartGauntlet() external whenGameEnabled nonReentrant {
    // PHASE 1: Execute any pending selection that's ready
    if (pendingGauntlet.exists && block.number >= pendingGauntlet.selectionBlock) {
        uint256 selectionSeed = uint256(blockhash(pendingGauntlet.selectionBlock));
        _executeGauntletSelection(selectionSeed, pendingGauntlet.queueSnapshot);
        delete pendingGauntlet;
    }
    
    // PHASE 2: Commit new gauntlet if conditions met  
    if (!pendingGauntlet.exists && _canStartNewGauntlet()) {
        pendingGauntlet = PendingGauntlet({
            selectionBlock: block.number + 1, // Next block
            queueSnapshot: queueIndex, // Copy current queue
            timestamp: block.timestamp,
            exists: true
        });
    }
}
```

**Benefits**:
- Eliminates selection timing exploit (can't predict future blockhash)
- Keeps runner simple (single function call)
- Self-healing (each call processes pending + creates new)
- Minimal delay (1 block = ~2 seconds on Base)

**Timeline with 30 players, size 8**:
- Minute 0: Commit gauntlet for next block selection
- Minute 1: Execute selection (8 players), start gauntlet, 22 remain in queue
- Minutes 2-5: Wait for 5-minute cooldown
- Minute 6: Commit next gauntlet
- Minute 7: Execute next selection (8 players), 14 remain
- Pattern repeats every 6 minutes

### Revolutionary Insight: Replace VRF with Future Blockhash for Gauntlets

**Game-Changing Realization**: If future blockhash is secure enough for queue selection (which determines matchups and has huge impact on winning), why not use it for combat randomness too?

**Current**: VRF for both selection and combat → expensive, complex, slower
**Proposed**: Future blockhash for both → cheap, simple, faster

**Potential Benefits**:
- Eliminate VRF costs for gauntlets (could save 50%+ on gas)
- No VRF delays - gauntlet completes in same transaction
- Simpler state management - no pending VRF requests
- Same security model throughout
- Fixes timing issues with gauntlet execution

**Implementation Concept**:
```solidity
function tryStartGauntlet() external {
    if (pendingGauntlet.exists && block.number >= pendingGauntlet.selectionBlock) {
        uint256 seed = uint256(blockhash(pendingGauntlet.selectionBlock));
        
        // Use SAME seed for both:
        uint32[] memory selected = _selectPlayers(seed);
        _runGauntletWithBlockhashRandomness(selected, seed);
        
        // Gauntlet completes immediately - no VRF waiting!
        delete pendingGauntlet;
    }
    // ... commit logic
}
```

**Considerations for Analysis**:
- Security implications of blockhash vs VRF for combat
- Impact on game fairness and player trust
- Keep VRF for duels and player creation?
- Potential gas savings and UX improvements

**Status**: Requires deep analysis before implementation due to significant architectural implications.
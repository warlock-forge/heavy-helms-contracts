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

## Critical: Player Progression & Ticket System

### DO NOT CONFUSE: Four Types of Tickets/Charges

**IMPORTANT**: Every ticket/charge is BURNED ON USE (either actual NFT burn or mapping counter decrement)

#### Type 1: ETH OR Ticket (Dual Option)
- **Examples**: Player Creation (CREATE_PLAYER_TICKET), Player Slots (PLAYER_SLOT_TICKET)
- **Implementation**: Users can EITHER burn the NFT ticket OR pay ETH
- **Methods**: Can be same method with conditional logic OR separate methods (e.g., `purchasePlayerSlotsWithETH` + `purchasePlayerSlotsWithTickets`)

#### Type 2: Ticket Only (Fungible NFT)
- **Examples**: Weapon Specialization (WEAPON_SPECIALIZATION_TICKET), Armor Specialization (ARMOR_SPECIALIZATION_TICKET)
- **Implementation**: MUST burn the fungible NFT ticket - NO ETH option
- **Storage**: ERC1155 fungible tokens (IDs 1-99)

#### Type 3: Ticket Only (Non-Fungible NFT)
- **Examples**: Name Changes (name NFTs with embedded name indices)
- **Implementation**: MUST burn the specific NFT - NO ETH option
- **Storage**: ERC1155 non-fungible tokens (IDs 100+)
- **Special**: NFT contains metadata (e.g., specific name indices)

#### Type 4: Bind-on-Account Charges (NOT NFTs)
- **Examples**: Attribute Swaps (via `_attributeSwapCharges` mapping)
- **Implementation**: Uses internal contract mappings, NOT PlayerTickets NFTs
- **Storage**: `mapping(address => uint256)` in Player contract
- **Purpose**: Account-bound to prevent pay-to-win mechanics
- **Award**: Via `awardAttributeSwap()` by authorized game contracts
- **Use**: Decrements mapping counter when used

### Current Implementation Status
- ✅ Type 1 (ETH or Ticket): Player slots work correctly with both options (1 ticket = 5 slots = fixed ETH cost)
- ❌ Type 1 Missing: Player creation still ETH-only, needs ticket option
- ✅ Type 2 (Fungible Ticket): Weapon/armor specialization work correctly
- ✅ Type 3 (Non-Fungible): Name changes work correctly
- ✅ Type 4 (Account Charges): Attribute swaps work correctly

### Key Implementation Details
- **Slot Cost**: Fixed cost system - `slotBatchCost` constant, no scaling
- **Reentrancy**: No guards needed - no actual reentrancy risks identified
- **DRY Principle**: Shared `_addPlayerSlots` internal function for both ETH and ticket purchases

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

## Advanced Architectural Patterns

### VRF Request Lifecycle
The system uses a consistent VRF pattern across all contracts:

1. **Request Phase**: `_requestRandomness("")` returns a `requestId`
2. **Mapping Storage**: Store game state mapped to `requestId`
3. **Timeout Protection**: Users can recover funds after `vrfRequestTimeout`
4. **Fulfillment**: `_fulfillRandomness()` processes the result and cleans up state
5. **State Cleanup**: Always delete mappings to prevent stale data

**Key Pattern**:
```solidity
// Request
uint256 requestId = _requestRandomness("");
requestToGameData[requestId] = gameData;

// Fulfillment
delete requestToGameData[requestId];
// Process game logic...
```

### State Management Architecture

**Player States**: Players have complex state across multiple dimensions:
- **Ownership**: Who owns the player
- **Activity**: Active vs retired
- **Game Registration**: Registered for specific game modes
- **Queue Status**: In gauntlet queue, in active game, etc.

**Game State Machines**:
- **Duels**: PENDING → CREATED → PENDING (after acceptance) → COMPLETED/EXPIRED
- **Gauntlets**: Players in QUEUE → IN_GAUNTLET → back to NONE
- **VRF Requests**: PENDING → FULFILLED or TIMED_OUT

### Permission System Architecture

The Player contract uses a sophisticated permission system where game contracts must be explicitly granted permissions:

```solidity
enum GamePermission { RECORD, RETIRE, NAME, ATTRIBUTES, IMMORTAL }

mapping(address => GamePermissions) private _gameContractPermissions;
```

**Permissions Required**:
- `RECORD`: For updating win/loss/kill counts
- `RETIRE`: For retiring players
- `NAME`: For awarding name change charges
- `ATTRIBUTES`: For awarding attribute swap charges  
- `IMMORTAL`: For setting immortality status

### Contract Interaction Patterns

**Core Flow**: User → Game Mode → Player Contract → Game Engine
1. **Game Modes** handle user interactions and game logic
2. **Player Contract** manages player state and permissions
3. **Game Engine** processes pure combat calculations
4. **Registry Contracts** validate skins and names

**Skin System Flow**:
1. Register skin collection in `PlayerSkinRegistry`
2. Mint NFTs in the skin collection contract
3. Players equip skins via `Player.equipSkin()`
4. Validation occurs in registry during equipment

### Gas Optimization Patterns

**Via IR Compilation**: Required for complex contracts to avoid stack-too-deep errors
- Enables aggressive optimization
- Necessary for large contracts like Player.sol
- Compilation takes 2-3 minutes

**Storage Patterns**:
- Struct packing for related data
- `uint32` for player IDs (saves gas vs `uint256`)
- Minimal storage reads in loops
- Strategic use of memory vs storage

### Testing VRF-Dependent Functionality

**VRF Mock System**: Use `GelatoVRFAutoMock` for deterministic testing
```solidity
// In tests:
vrfMock.startRecordingLogs();
// ... trigger VRF request
uint256 requestId = vrfMock.fulfillLatestRequest(randomness);
```

**Testing Patterns**:
- Always test both successful VRF fulfillment AND timeout recovery
- Test with different randomness values for reproducible results
- Use `expectEmit` for event testing with VRF

### Common Development Pitfalls to Avoid

1. **VRF State Management**: Always clean up request mappings in fulfillment
2. **Player Ownership**: Validate player ownership before operations
3. **Game Permissions**: Ensure game contracts have required permissions
4. **Skin Validation**: Equipment must be validated through registry
5. **State Transitions**: Check current state before transitions
6. **Array Operations**: Use swap-and-pop for gas-efficient removal

### Contract Upgrade Strategy

**Immutable Contracts**: Deployed contracts cannot be upgraded
- All fixes must be deployed as new versions
- State migration requires careful planning
- Registry patterns allow pointing to new implementations

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

## Architecture Decisions That Are NOT Bugs

### Important for AI Auditors to Understand

**1. GameOwnedNFT Mints to Contract Address**
```solidity
_mint(address(this), desiredTokenId);
```
- **NOT A BUG**: These are GAME-OWNED NFTs (the name is a hint!)
- **Purpose**: Default skins and monster skins are owned by the game, not players
- **Design**: Players reference these skins, they don't own transferable NFTs

**2. Solidity 0.8+ Overflow Protection**
- **NOT A BUG**: Integer overflow/underflow automatically reverts
- **NOT A BUG**: Downcasting that could overflow will revert, not silently corrupt
- **Example**: `uint16(largeNumber)` will revert if `largeNumber > type(uint16).max`

**3. VRF Fulfillment is Single-Threaded**
- **NOT A BUG**: `nextPlayerId++` in VRF fulfillment cannot race
- **Design**: Each VRF callback is atomic, Gelato ensures single execution
- **NOT A BUG**: Request IDs from Gelato are sequential and that's fine

**4. Transaction Atomicity**
- **NOT A BUG**: All operations in a single transaction succeed or fail together
- **Example**: Skin validation after VRF request is fine - if validation fails, entire TX reverts
- **NOT A BUG**: No "race conditions" within a single transaction

**5. Owner-Only Functions Don't Need Reentrancy Guards**
- **NOT A BUG**: Owner cannot "attack themselves" with reentrancy
- **Design**: `onlyOwner` + `transfer()` is sufficient for admin withdrawals
- **Note**: Using `SafeTransferLib` is still better practice but not critical

**6. Mathematical Guarantees in _fixStats**
```solidity
while (total != 72) { // Will always converge
    // 6 stats, each 3-21, need total 72
    // Min: 18, Max: 126, Target: 72
}
```
- **NOT A BUG**: Algorithm mathematically guarantees convergence
- **Proof**: Can always increment if < 72, decrement if > 72

**7. Standard Patterns That Are Correct**
- **NOT A BUG**: Swap-and-pop array removal in GauntletGame
- **NOT A BUG**: Using `block.timestamp` for timeout checks (15-second manipulation window acceptable)
- **NOT A BUG**: Checks-Effects-Interactions pattern properly followed

**8. Design Decisions**
- **BY DESIGN**: PlayerSkinNFT allows public minting when enabled (with payment)
- **BY DESIGN**: Queue selection uses pseudo-randomness (documented exploit in progress)
- **BY DESIGN**: Practice mode uses predictable randomness (no stakes)
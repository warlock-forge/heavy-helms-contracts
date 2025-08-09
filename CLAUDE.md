# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Heavy Helms is a Solidity-based on-chain game featuring combat mechanics, NFT skins, and multiple game modes. The project uses Foundry for development and testing. Gauntlet tournaments use blockhash-based randomness for security and gas efficiency, while other modes may use Gelato VRF.

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
- ✅ Type 1 (ETH or Ticket): Player slots AND player creation work correctly with both options
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

2. **Game Engine** (`src/game/`)
   - `GameEngine.sol`: Core combat mechanics and battle resolution (version 28)
   - `EquipmentRequirements.sol`: Equipment validation and requirements
   - Game Modes: `BaseGame.sol`, `PracticeGame.sol`, `DuelGame.sol`, `GauntletGame.sol`

3. **NFT System** (`src/nft/`)
   - `GameOwnedNFT.sol`: Base NFT contract
   - Skin NFTs: `DefaultPlayerSkinNFT.sol`, `MonsterSkinNFT.sol`, `PlayerSkinNFT.sol`

4. **Registry System** (`src/fighters/registries/`)
   - `PlayerSkinRegistry.sol`: Manages skin collections and validation
   - `PlayerNameRegistry.sol`, `MonsterNameRegistry.sol`: Name generation systems

### Key Design Patterns

1. **Randomness Systems**: 
   - **GauntletGame**: Uses blockhash-based commit-reveal for security and gas efficiency
   - **Other Games**: Use Gelato VRF for on-chain randomness  
   - Mock system available for testing (`GelatoVRFAutoMock.sol`)

2. **Fighter ID Ranges**:
   - Players: 1-2000
   - Default Players: 1001-2000
   - Monsters: 2001-10000

3. **Combat System**:
   - Turn-based combat with stamina management
   - Multiple combat results (miss, attack, crit, block, counter, etc.)
   - Equipment affects combat outcomes

## Current Development Priorities

### Completed ✅
- **Blockhash Gauntlet System**: Complete 3-transaction commit-reveal implementation
  - Queue selection timing exploit FIXED
  - VRF costs eliminated (50%+ gas savings)
  - Instant gauntlet completion (no VRF delays)
  - Comprehensive test coverage (23/23 tests passing)
- **GameEngine v28 Weapon Classification System**: Complete rebalancing with attribute-based damage scaling
  - AGI assassins now scale damage with AGI (not forced into STR+SIZE)
  - 7 weapon classes with distinct damage formulas
  - Size damage bonus system affects all weapons
  - Shield principle properly implemented (defense trades for offense)
- **Enhanced Stamina System**: Stamina ramp-up with negative effects under 50%
- All ticket types working correctly (Type 1-4)
- 64-player gauntlet support (~15M gas, well under 30M block limit)

### Current Focus: Level Progression Testing
- v28 GameEngine shows promising results but inconsistent level scaling
- Some archetypes scale well (Assassins: 85% L10 vs L1), others don't (Berserkers: 50%)
- Need level-based scaling beyond just attribute points
- Considering talent system and specialized archetype bonuses

## Player Archetypes & Combat Balance

### Core Combat Archetypes

#### 1. **Assassin** (Fast AGI Damage Dealer)
- **Stats**: STR=19, CON=5, SIZE=12, AGI=19, STA=5, LUCK=12 (Total: 72)
- **Weapons**: DUAL_DAGGERS, RAPIER_DAGGER, SCIMITAR_DAGGER, DUAL_SCIMITARS
- **Identity**: High AGI scaling damage, speed over defense

#### 2. **Berserker** (Heavy STR+SIZE Damage Dealer)  
- **Stats**: STR=19, CON=5, SIZE=19, AGI=12, STA=12, LUCK=5 (Total: 72)
- **Weapons**: BATTLEAXE, MAUL, GREATSWORD
- **Identity**: Massive damage, breakthrough mechanics, slower but devastating

#### 3. **Shield Tank** (Pure Defensive Tank)
- **Stats**: STR=12, CON=19, SIZE=19, AGI=5, STA=12, LUCK=5 (Total: 72)
- **Weapons**: MACE_TOWER, AXE_TOWER, CLUB_TOWER, SHORTSWORD_TOWER
- **Identity**: Absorb damage, outlast opponents, defensive specialist

#### 4. **Parry Master** (Technical Defensive Fighter)
- **Stats**: STR=12, CON=19, SIZE=5, AGI=19, STA=5, LUCK=12 (Total: 72)
- **Weapons**: RAPIER_BUCKLER, SCIMITAR_BUCKLER, SHORTSWORD_BUCKLER, RAPIER_DAGGER, SCIMITAR_DAGGER
- **Identity**: Skill-based defense, counter-attacking, finesse over force

#### 5. **Bruiser** (Brute Force Brawler)
- **Stats**: STR=19, CON=5, SIZE=19, AGI=5, STA=12, LUCK=12 (Total: 72)
- **Weapons**: DUAL_CLUBS, AXE_MACE, FLAIL_DAGGER, MACE_SHORTSWORD
- **Identity**: Sustained damage output, dual-wield specialist

#### 6. **Vanguard** (Balanced Heavy Fighter)
- **Stats**: STR=19, CON=19, SIZE=12, AGI=5, STA=12, LUCK=5 (Total: 72)
- **Weapons**: GREATSWORD, AXE_KITE, QUARTERSTAFF, FLAIL_BUCKLER
- **Identity**: Versatile heavy fighter, defensive capabilities with offensive potential

#### 7. **Balanced** (All-Rounder Fighter)
- **Stats**: STR=12, CON=12, SIZE=12, AGI=12, STA=12, LUCK=12 (Total: 72)
- **Weapons**: ARMING_SWORD_SHORTSWORD, ARMING_SWORD_CLUB, ARMING_SWORD_KITE, MACE_KITE
- **Identity**: Jack-of-all-trades, adaptable to different situations

#### 8. **Monk** (Reach & Control Specialist)
- **Stats**: STR=12, CON=19, SIZE=5, AGI=19, STA=12, LUCK=5 (Total: 72)
- **Weapons**: TRIDENT, SPEAR, QUARTERSTAFF
- **Identity**: Reach advantage, dodge-focused, technical combat

## GameEngine v28 Mechanics Documentation

### Core Combat Statistics

#### Primary Attribute Effects
Each attribute affects multiple combat statistics:

**STRENGTH (STR)**:
- Damage modifier: Weapon class dependent (see weapon classifications)
- Crit multiplier: +3 per point (formula: `150 + STR * 3 + SIZE * 2`)
- Parry chance: +0.4 per point
- Counter chance: +1 per point

**CONSTITUTION (CON)**:
- Health: +15 per point (formula: `50 + CON * 15 + SIZE * 6 + STA * 3`)
- Block chance: +0.35 per point
- Survival rate: +1 per point

**SIZE**:
- Damage modifier: Weapon class dependent + universal size bonus
- Health: +6 per point
- Crit multiplier: +2 per point
- Block chance: +0.3 per point

**AGILITY (AGI)**:
- Hit chance: +1 per point (formula: `50 + AGI + LUCK * 2`)
- Initiative: +3 per point
- Dodge chance: +0.3 per point
- Crit chance: +0.33 per point
- Parry chance: +0.35 per point

**STAMINA (STA)**:
- Health: +3 per point
- Endurance: +16 per point (formula: `35 + STA * 16 + STR * 2`)
- Dodge chance: +0.2 per point
- **NEW: Stamina below 50% causes negative effects**

**LUCK**:
- Hit chance: +2 per point
- Initiative: +2 per point
- Crit chance: +0.33 per point
- Survival rate: +2 per point

### GameEngine v28 Weapon Classification System ✅

#### Size Damage Bonus System
Applied to ALL weapons regardless of class:
- **SIZE 3-8**: -5% damage modifier
- **SIZE 9-16**: 0% (baseline)
- **SIZE 17-21**: +5% damage modifier  
- **SIZE 22+**: +10% damage modifier

#### Weapon Classes (7 categories with different damage scaling):

**LIGHT_FINESSE**: Pure AGI×10 damage scaling
- DUAL_DAGGERS (39-61 dmg, 115 spd), RAPIER_DAGGER (48-62 dmg, 100 spd), RAPIER_BUCKLER (40-52 dmg, 90 spd), SHORTSWORD_BUCKLER (40-52 dmg, 90 spd), SHORTSWORD_TOWER (32-40 dmg, 85 spd)

**CURVED_BLADE**: AGI×7 + STR×3 damage scaling
- DUAL_SCIMITARS (48-62 dmg, 100 spd), SCIMITAR_DAGGER (46-60 dmg, 105 spd), SCIMITAR_BUCKLER (38-50 dmg, 85 spd)

**BALANCED_SWORD**: STR×7 + AGI×3 damage scaling
- ARMING_SWORD_SHORTSWORD (45-60 dmg, 85 spd), ARMING_SWORD_CLUB (50-65 dmg, 75 spd), ARMING_SWORD_KITE (35-43 dmg, 75 spd)

**PURE_BLUNT**: Pure STR×10 damage scaling
- DUAL_CLUBS (54-66 dmg, 85 spd), MACE_KITE (43-53 dmg, 65 spd), FLAIL_BUCKLER (50-63 dmg, 70 spd), MACE_TOWER (33-42 dmg, 70 spd), CLUB_TOWER (33-42 dmg, 70 spd)

**HEAVY_DEMOLITION**: STR×5 + SIZE×5 damage scaling (original formula)
- BATTLEAXE (130-140 dmg, 40 spd), GREATSWORD (76-85 dmg, 60 spd), MAUL (130-140 dmg, 40 spd), AXE_KITE (36-44 dmg, 70 spd), AXE_TOWER (34-43 dmg, 65 spd)

**DUAL_WIELD_BRUTE**: STR×4 + SIZE×3 + AGI×3 damage scaling
- AXE_MACE (66-90 dmg, 65 spd), FLAIL_DAGGER (60-84 dmg, 70 spd), MACE_SHORTSWORD (60-84 dmg, 70 spd)

**REACH_CONTROL**: AGI×5 + STR×5 damage scaling + 15 dodge bonus
- TRIDENT (47-58 dmg, 55 spd), SPEAR (32-40 dmg, 80 spd), QUARTERSTAFF (29-36 dmg, 80 spd)

### TRUE DPR (Damage Per Round) Calculation System

#### **Formula**
```
TRUE DPR = (Average Weapon Damage × Damage Modifier ÷ 100) × (Attack Speed ÷ 149)
```

#### **Components**

1. **Average Weapon Damage**: `(minDamage + maxDamage) ÷ 2`

2. **Damage Modifier Calculation by Weapon Class**:
   - Use weapon class formula with archetype's STR/AGI/SIZE stats
   - Apply universal STR/SIZE bonuses from archetype stats

3. **Action Point System**: Attack cost = 149 points, gain = weapon.attackSpeed per round

#### **ARCHETYPE-BASED TRUE DPR RANKINGS (ALL 27 WEAPONS)**

1. **BATTLEAXE** - **91.6 DPR** (Berserker: 135×248.04÷100×40÷149)
2. **MAUL** - **91.6 DPR** (Berserker: 135×248.04÷100×40÷149)
3. **DUAL_DAGGERS** - **82.0 DPR** (Assassin: 50×221.45÷100×115÷149)
4. **RAPIER_DAGGER** - **73.3 DPR** (Assassin: 55×221.45÷100×100÷149)
5. **DUAL_SCIMITARS** - **73.3 DPR** (Assassin: 55×211÷100×100÷149)
6. **AXE_MACE** - **68.8 DPR** (Bruiser: 78×213.57÷100×65÷149)
7. **FLAIL_DAGGER** - **67.0 DPR** (Bruiser: 72×213.57÷100×70÷149)
8. **MACE_SHORTSWORD** - **67.0 DPR** (Bruiser: 72×213.57÷100×70÷149)
9. **DUAL_CLUBS** - **64.5 DPR** (Bruiser: 60×213.57÷100×85÷149)
10. **GREATSWORD** - **53.4 DPR** (Berserker: 80.5×248.04÷100×60÷149)

**Note**: Updated with GameEngine v28 actual weapon stats. Tower weapons maintain lowest DPR as intended per shield principle (defense trades for offense).

## Testing Infrastructure

### Test Base Class
All tests inherit from `TestBase.sol` which provides:
- VRF mock system setup
- Contract deployment helpers
- Player creation utilities
- Common test fixtures

### Testing Best Practices
1. **Always use existing helper methods** from TestBase
2. Use `testFuzz_` prefix for fuzz tests
3. Calculate parameters outside `expectRevert` blocks
4. Use `skipInCI` modifier for long-running balance tests

### Critical Test Areas
- VRF completion workflows
- Queue management (especially in GauntletGame)
- Fee calculations and distributions
- Player state transitions
- Combat mechanics edge cases
- **Level progression scaling** (new focus area)

## Development Workflow

1. **Environment Setup**:
   ```bash
   forge install --no-git foundry-rs/forge-std@1eea5ba transmissions11/solmate@c93f771 gelatodigital/vrf-contracts@fdb85db
   ```

2. **Configuration** (`.env` file):
   ```
   RPC_URL=<YOUR RPC URL>
   PK=<YOUR PRIVATE KEY>
   GELATO_VRF_OPERATOR=<VRF OPERATOR>
   ```

3. **Deployment Order**:
   GameEngine → EquipmentRequirements → Registries → Fighters → Games

## Security Considerations

1. **Checks-Effects-Interactions Pattern**: Always followed for reentrancy protection
2. **Access Control**: Owner-based permissions, whitelisting for games
3. **VRF Security**: Proper validation of VRF responses
4. **Fee Handling**: Careful arithmetic to prevent overflow/underflow

## Common Patterns

1. **Error Handling**: Custom errors used throughout
2. **Events**: Comprehensive events for all state changes
3. **Modifiers**: Common validation in modifiers
4. **Libraries**: Extensive use of libraries for code reuse and gas optimization

## Important Notes

- **Via IR**: Enabled in foundry.toml for optimization
- **Solmate**: Primary dependency for gas-optimized contracts
- **Testing**: Extensive test coverage expected, use `-vv` for debugging
- **Gas Optimization**: Critical due to on-chain game nature

## Memories

- Never try a fresh forge build as it will just timeout - ask the user to do it
- Always run `forge fmt` before we git add
- **CRITICAL: NEVER MAKE ASSUMPTIONS ABOUT WHAT THE CODE DOES - ALWAYS READ THE ACTUAL CODE FIRST!** Don't tell the user what you think happens, READ THE FUCKING CODE and tell them what ACTUALLY happens. Making assumptions wastes everyone's time and makes you look incompetent. When asked about ANY implementation detail, your FIRST action should be to grep/read the relevant code, NOT to guess based on what you remember or what seems logical.

## TODO: Gas Optimization Issues to Fix Later

### GauntletGame Storage Waste
- `gauntlet.winners[]` array is stored in expensive contract storage (~300k gas for 16 players)
- Only used for emitting `GauntletCompleted` event at end
- Should use memory array instead, emit event, never store in contract storage
- Same pattern exists in both Gauntlet and Tournament - treating contract like database instead of using memory + events
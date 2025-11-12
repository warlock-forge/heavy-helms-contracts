# MonsterBattles PvE Game Mode - Implementation Specification

> **Status**: Phase 1 Complete - Monster Infrastructure Ready  
> **Last Updated**: 2025-11-12  
> **Team Approval**: ✅ APPROVED  
> **Phase 1 Completion**: ✅ ALL INFRASTRUCTURE COMPLETE

## Table of Contents
1. [Project Overview](#project-overview)
2. [Core Game Mechanics](#core-game-mechanics)
3. [Reward Structure](#reward-structure)
4. [Implementation Phases](#implementation-phases)
5. [Technical Specifications](#technical-specifications)
6. [Progress Tracking](#progress-tracking)

---

## Project Overview

MonsterBattles introduces a PvE game mode where players risk permanent death to fight monsters for XP and bounty rewards. The system creates scarcity through permanent monster removal and escalating bounty values for high-kill monsters.

### Key Features
- **Real Death Risk**: Players can be permanently retired
- **Monster Scarcity**: Killed monsters are removed forever
- **Bounty System**: High-kill monsters provide exponential rewards
- **Daily Limits**: 5 battles/day with reset options
- **Level 10 Bounty Hunting**: Endgame content targeting specific monsters

---

## Core Game Mechanics

### Death System
- **GameEngine Integration**: Uses existing `WinCondition.DEATH` vs `WinCondition.HEALTH`
- **Death Saves**: Survival chance = LUCK×4 + CON×2 + weapon/stance survival factors
- **Lethality Control**: `lethalityFactor` parameter controls death probability
- **Player Death**: `setPlayerRetired(playerId, true)` - permanent retirement
- **Monster Death**: Permanently removed from available battle pool

### Monster Difficulty System
- **Easy Monsters**: 62 attribute points at Level 1 → 71 points at Level 10
- **Normal Monsters**: 72 attribute points at Level 1 → 81 points at Level 10
- **Hard Monsters**: 82 attribute points at Level 1 → 91 points at Level 10
- **Level Progression**: Each monster has proper 1-10 scaling (+9 attribute points)
- **Monster Level**: Derived from player level ±1-2 for variety

### Monster ID Organization (Convention-Based)
- **Easy**: ~2001-4500 (2500 slots)
- **Normal**: ~4501-7000 (2500 slots)
- **Hard**: ~7001-10000 (3000 slots)
- **Note**: Ranges are organizational convention, not validation rules

### Selection Mechanics
- **Levels 1-9**: Choose difficulty tier → random monster from that tier
- **Level 10**: Can target specific monsters with 1+ kills (bounty hunting)
- **Anti-Farming**: Prevents rock-paper-scissors matchup exploitation

---

## Daily Limit & Reset System

### Entry Limits
- **Daily Allowance**: 5 free monster battles per day
- **Tracking**: `_playerDailyRuns[playerId][today]` mapping (same as gauntlets)
- **Reset Logic**: Both reset options restore full 5 attempts

### Reset Options
1. **ETH Reset**: `resetMonsterDailyLimit()` - Pay 0.001 ETH (same as gauntlets)
2. **Ticket Reset**: `resetMonsterDailyLimitWithTicket()` - Burn 1 DAILY_RESET_TICKET

### Economics
- **Same Cost**: 0.001 ETH for both gauntlets and monsters
- **Per-Attempt Cost**: Naturally 2x more expensive (0.0002 vs 0.0001 ETH)
- **Strategic Choice**: Players choose gauntlet resets vs monster resets

---

## Reward Structure

### XP Rewards (TEAM APPROVED)
**Win Rewards**:
- Easy: 50 XP
- Normal: 75 XP  
- Hard: 100 XP

**Loss Rewards**:
- Easy: 5 XP
- Normal: 10 XP
- Hard: 20 XP

**Level 10 Exception**: NO XP rewards for level 10 players (win or loss)

### Bounty System (Death Condition Only)
**Base Bounty** (when monster dies with WinCondition.DEATH):
- DAILY_RESET_TICKETS × kill_count
- CREATE_PLAYER_TICKETS × kill_count

**Legendary Bounty** (5+ kills):
- ATTRIBUTE_SWAP_TICKET
- Name/ID permanently etched as "Monster Killer"
- Exclusive skin unlock NFT

**Scarcity Value**: Monster permanently removed from pool after death

---

## Implementation Phases

### Phase 1: Monster Infrastructure (CRITICAL FOUNDATION)

#### 1.1 Fix MonsterLibrary Level Progression ✅
- **COMPLETED**: Proper 1-10 level scaling implemented with attribute progression
- **Implementation**: Full 10-level stats with proper scaling and specializations
- **File**: `src/fighters/lib/MonsterLibrary.sol`

#### 1.2 Expand Monster Names ✅
- **COMPLETED**: 90+ monster names across 3 categories (30 goblins, 30 undead, 30 demons)
- **Deployment**: Names deployed to testnet with indices 5-94
- **File**: `src/fighters/registries/names/lib/MonsterNameLibrary.sol`

#### 1.3 Create Monster Archetypes ✅
- **COMPLETED**: 3 base archetypes across difficulty tiers
- **Easy Goblin 001**: 62→71 attribute points, DUAL_CLUBS + LEATHER
- **Normal Undead 001**: 72→81 attribute points, DUAL_DAGGERS + CLOTH  
- **Hard Demon 001**: 82→91 attribute points, ARMING_SWORD_KITE + CHAIN
- **Testing**: All 3 archetypes created and deployed (Monster IDs 2001, 2002, 2003)

### Phase 2: Core Game Contract

#### 2.1 MonsterBattlesGame Contract
- **Base**: Extend BaseGame contract
- **Pattern**: Follow DuelGame structure with VRF integration
- **File**: `src/game/modes/MonsterBattlesGame.sol`

#### 2.2 Key Components
- Daily limit system (copy gauntlet pattern)
- Monster availability tracking by difficulty
- Battle functions (random and targeted)
- Reset functions (ETH and ticket)
- Admin functions (monster batch management)

### Phase 3: Reward Systems

#### 3.1 XP System
- Win/loss XP implementation with level 10 exception
- Integration with existing player XP system

#### 3.2 Bounty System  
- Read kill counts from Monster contract
- Base and legendary bounty calculation
- Reward distribution

#### 3.3 Level 10 Features
- Specific monster targeting
- Cross-tier hunting capabilities

### Phase 4: Deployment & Testing

#### 4.1 Contract Deployment
- Deploy MonsterBattlesGame with proper parameters
- Set necessary contract permissions

#### 4.2 Testing & Population
- Comprehensive test suite
- Deploy initial monster batch (50-100 monsters)

---

## Technical Specifications

### Contract Structure
```solidity
contract MonsterBattlesGame is BaseGame, VRFConsumerBaseV2Plus {
    // Extends BaseGame following DuelGame pattern
}
```

### Key Data Structures
```solidity
enum DifficultyLevel { EASY, NORMAL, HARD }

mapping(DifficultyLevel => uint32[]) public availableMonstersByDifficulty;
mapping(uint32 => mapping(uint256 => uint8)) private _playerDailyRuns;

uint8 public dailyMonsterLimit = 5;
uint256 public dailyResetCost = 0.001 ether;
```

### Core Functions
- `fightMonster(DifficultyLevel difficulty)` - Random monster battle
- `fightSpecificMonster(uint32 monsterId)` - Level 10 bounty hunting
- `resetMonsterDailyLimit()` - ETH reset
- `resetMonsterDailyLimitWithTicket()` - Ticket reset
- `addNewMonsterBatch(uint32[] monsterIds, DifficultyLevel difficulty)` - Admin

### Game Flow
1. Player calls `fightMonster(difficulty)` or `fightSpecificMonster(monsterId)`
2. System selects monster and initiates VRF request
3. GameEngine processes combat with appropriate `lethalityFactor`
4. Rewards distributed based on outcome and player level

---

## Progress Tracking

### Phase 1: Monster Infrastructure ✅
- [x] Fix MonsterLibrary level progression - COMPLETED: Proper 1-10 scaling implemented
- [x] Expand monster names (4 → 90+) - COMPLETED: Added 90 names across 3 categories (goblins, undead, demons)
- [x] Create monster archetypes - COMPLETED: 3 base archetypes with proper stat scaling and equipment

### Phase 2: Core Contract ⏳
- [ ] Create MonsterBattlesGame contract
- [ ] Implement daily limit system
- [ ] Add monster availability tracking
- [ ] Implement battle functions
- [ ] Add reset functions
- [ ] Create admin functions

### Phase 3: Reward Systems ⏳
- [ ] Implement XP system (with level 10 exception)
- [ ] Create bounty calculation
- [ ] Add legendary rewards
- [ ] Implement level 10 targeting

### Phase 4: Deployment ⏳
- [ ] Create deployment script
- [ ] Write test suite
- [ ] Deploy initial monsters

### Critical Dependencies
1. **Phase 1 MUST be completed first** - Foundation for everything
2. **Phases 2-3 can be parallel** once Phase 1 is done
3. **Phase 4 testing concurrent** with Phase 3

---

## Art Asset Requirements

### Monster Art Needs
- [ ] Easy tier monsters: 5+ unique designs
- [ ] Normal tier monsters: 5+ unique designs  
- [ ] Hard tier monsters: 5+ unique designs
- [ ] Legendary monster killer skin NFT designs
- [ ] Monster skin variations for different archetypes

### Integration Notes
- Monster art assets will be integrated via MonsterSkinNFT system
- Each monster archetype needs corresponding skin collection
- Legendary rewards may require unique skin designs

---

## Success Criteria

### Technical Requirements
- ✅ Monsters have proper 1-10 level progression - COMPLETED
- ✅ 90+ diverse monster names available - COMPLETED
- [ ] Daily limit system identical to gauntlets
- [ ] Bounty system with scaling rewards
- [ ] Level 10 bounty hunting functionality
- [ ] Death mechanics for players and monsters
- [ ] No XP farming advantages over gauntlets

### Game Balance
- Death rates balanced to prevent rapid depletion
- XP rates balanced with existing gauntlet system
- Bounty rewards provide meaningful endgame content
- Monster scarcity creates urgency without frustration

---

## Notes & Decisions

### Team Decisions
- **XP for Losses**: Added small XP rewards for losses (5/10/20)
- **Level 10 No XP**: No XP rewards for max level players
- **Same Reset Cost**: 0.001 ETH matching gauntlets
- **Convention-Based IDs**: Flexible monster ID organization

### Technical Decisions
- Don't duplicate kill tracking - read from Monster contract
- Use difficulty-mapped arrays for monster availability
- Single function for battle initiation (not multi-step)
- Full reset (5 attempts) not incremental

### Future Considerations
- Limited-time events for monster pool expansion
- Dynamic lethality tuning based on usage data
- Potential cross-game mode rewards
- Monster respawn events for special occasions

---

**End of Document**
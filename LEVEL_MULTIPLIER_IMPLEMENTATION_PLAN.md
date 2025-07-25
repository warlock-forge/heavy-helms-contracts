# Level-Based Multiplier System Implementation Plan

## Overview
Implement a hybrid progression system that applies level-based multipliers to combat stats while keeping modest attribute point gains. This addresses the progression issues without creating broken meta builds.

## Core Design

### Level Multiplier Formula
```solidity
levelMultiplier = 100 + (level - 1) * 10  // 10% per level
```

**Level Scaling Examples:**
- Level 1: 100% (baseline)
- Level 5: 140% (40% stronger)
- Level 10: 190% (90% stronger) 
- Level 15: 240% (140% stronger)
- Level 20: 290% (190% stronger)

### Hybrid System Components
1. **Level Multipliers** (Primary scaling) - Applied to key combat stats
2. **Attribute Points** (Secondary customization) - 1 per level, 25 cap max
3. **Equipment** (Tactical choice) - Unchanged

## Affected Systems Analysis

### 1. GameEngine.sol - CORE CHANGES REQUIRED

#### Current Signature:
```solidity
function processGame(
    FighterStats memory player1Stats,
    FighterStats memory player2Stats,
    uint256 randomness,
    uint256 vrfRequestId
) external pure returns (bytes memory)
```

#### New Signature:
```solidity
function processGame(
    FighterStats memory player1Stats,
    FighterStats memory player2Stats,
    uint8 player1Level,  // NEW
    uint8 player2Level,  // NEW
    uint256 randomness,
    uint256 vrfRequestId
) external pure returns (bytes memory)
```

#### Stats That Get Level Multipliers:
- **damageModifier** - Core damage scaling
- **health** - Survivability scaling
- **hitChance** - Skill improvement (capped at 95%)
- **dodgeChance** - Defensive skill (capped at reasonable limit)
- **blockChance** - Shield mastery (capped)
- **parryChance** - Weapon skill (capped)
- **critMultiplier** - Lethality scaling

#### Implementation in calculateStats():
```solidity
function calculateStats(FighterStats memory player, uint8 level) internal pure returns (CalculatedStats memory) {
    // Calculate base stats as before
    CalculatedStats memory baseStats = calculateBaseStats(player);
    
    // Apply level multiplier
    uint256 levelMultiplier = 100 + (level - 1) * 10;
    
    // Scale key stats
    baseStats.damageModifier = uint16((uint256(baseStats.damageModifier) * levelMultiplier) / 100);
    baseStats.health = uint16((uint256(baseStats.health) * levelMultiplier) / 100);
    baseStats.hitChance = uint8(min(95, (uint256(baseStats.hitChance) * levelMultiplier) / 100));
    baseStats.dodgeChance = uint8(min(75, (uint256(baseStats.dodgeChance) * levelMultiplier) / 100));
    baseStats.blockChance = uint8(min(85, (uint256(baseStats.blockChance) * levelMultiplier) / 100));
    baseStats.parryChance = uint8(min(85, (uint256(baseStats.parryChance) * levelMultiplier) / 100));
    baseStats.critMultiplier = uint16((uint256(baseStats.critMultiplier) * levelMultiplier) / 100);
    
    return baseStats;
}
```

### 2. Game Mode Contracts - ALL NEED UPDATES

#### A. BaseGame.sol
**Current**: Stores FighterStats in game data
**Required**: Store FighterStats + levels

```solidity
struct GameData {
    FighterStats player1Stats;
    FighterStats player2Stats;
    uint8 player1Level;  // NEW
    uint8 player2Level;  // NEW
    // ... existing fields
}
```

#### B. PracticeGame.sol
**Changes Needed:**
- `startPracticeGame()` - Accept level parameter
- VRF fulfillment - Pass levels to GameEngine
- Estimated 3-4 functions affected

#### C. DuelGame.sol  
**Changes Needed:**
- `createDuel()` - Store creator level
- `acceptDuel()` - Store accepter level
- VRF fulfillment - Pass both levels
- Estimated 4-5 functions affected

#### D. GauntletGame.sol
**Changes Needed:**
- Queue storage - Add level to player queue data
- Tournament brackets - Track levels
- Combat resolution - Pass levels to GameEngine
- **MOST COMPLEX** - Estimated 8-10 functions affected

### 3. Player.sol Integration

#### Level Retrieval:
```solidity
function getPlayerLevel(uint256 playerId) external view returns (uint8) {
    return players[playerId].level;
}
```

#### Game Mode Integration:
Each game mode needs to fetch player levels before combat:
```solidity
uint8 player1Level = playerContract.getPlayerLevel(player1Id);
uint8 player2Level = playerContract.getPlayerLevel(player2Id);
```

### 4. Frontend Integration

#### Current Frontend Calls:
```typescript
const results = await viemClient.multicall({ 
  contracts: fighters.map(fighter => ({
    functionName: "calculateStats",
    args: [{ weapon, armor, stance, attributes }]
  }))
});
```

#### New Frontend Calls:
```typescript
const results = await viemClient.multicall({ 
  contracts: fighters.map(fighter => ({
    functionName: "calculateStats", 
    args: [{ weapon, armor, stance, attributes }, fighter.level] // Add level
  }))
});
```

## Test Migration Strategy

### 1. TestBase.sol Updates
Add helper for creating leveled fighters:
```solidity
function createLeveledPlayer(
    Fighter.Attributes memory attributes,
    uint8 weapon,
    uint8 armor, 
    uint8 stance,
    uint8 level
) internal returns (uint256 playerId) {
    // Create player with level
}
```

### 2. Test Files Requiring Updates
- **BalanceTest.t.sol** - ALL progression tests need level parameters
- **GameEngineTest.t.sol** - ALL combat simulation tests  
- **PracticeGameTest.t.sol** - Game mode tests
- **DuelGameTest.t.sol** - Duel tests
- **GauntletGameTest.t.sol** - Tournament tests
- **TestBase.sol** - Helper functions

**Estimated Impact**: 50+ test functions need parameter updates

### 3. Test Migration Approach
1. **Phase 1**: Update GameEngine + TestBase helpers
2. **Phase 2**: Update each game mode contract + tests sequentially
3. **Phase 3**: Update integration tests
4. **Phase 4**: Add comprehensive level multiplier tests

## Implementation Phases

### Phase 1: Core GameEngine Changes (Day 1)
- [ ] Add level parameters to GameEngine.processGame()
- [ ] Implement level multiplier in calculateStats()
- [ ] Add caps to prevent broken scaling
- [ ] Update GameEngine tests

### Phase 2: Game Mode Updates (Day 2-3)
- [ ] Update BaseGame.sol structure
- [ ] Update PracticeGame.sol (simplest)
- [ ] Update DuelGame.sol (medium complexity)
- [ ] Update GauntletGame.sol (most complex)

### Phase 3: Test Migration (Day 4)
- [ ] Update all affected test files
- [ ] Fix compilation errors
- [ ] Verify existing functionality

### Phase 4: Level Multiplier Testing (Day 5)
- [ ] Add comprehensive progression tests
- [ ] Validate level scaling works correctly
- [ ] Performance testing

## Risk Assessment

### HIGH RISK:
- **GauntletGame.sol** - Most complex, handles 64-player tournaments
- **Frontend compatibility** - May break existing UI
- **Gas costs** - Additional parameters increase gas usage

### MEDIUM RISK:
- **Test compilation** - 50+ functions need updates
- **VRF integration** - All game modes use VRF differently

### LOW RISK:
- **GameEngine.sol** - Well-isolated, pure functions
- **Player.sol** - Minimal changes needed

## Rollback Strategy
1. **Git branches** - Each phase on separate branch
2. **Backward compatibility** - Keep old function signatures temporarily
3. **Feature flags** - Allow disabling level multipliers if needed

## Success Criteria
- [ ] Level 10 characters win 85%+ vs Level 1 same archetype
- [ ] Level 20 characters win 95%+ vs Level 1 same archetype  
- [ ] No stat caps exceeded (95% hit, 85% block/parry, etc.)
- [ ] All existing tests pass with level parameters
- [ ] Gas costs increase by <10%

## Questions Before Proceeding
1. **Are you ready for 3-5 days of intensive work?**
2. **Should we implement backward compatibility (old + new functions)?**
3. **What level cap do we target? (10, 15, or 20?)**
4. **Should we start with PracticeGame as proof of concept?**

This is a MAJOR architectural change that will touch every part of the combat system. Are you confident we should proceed?
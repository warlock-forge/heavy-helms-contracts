# Heavy Helms Progression System Analysis

## Current State (After GameEngine v26)

### Test Results - Level 10 vs Level 1 Win Rates:
- **Assassin L10 vs L1**: 74% (FAILED - Expected 85%+)
- **Berserker L10 vs L1**: 52% (CRITICALLY FAILED - Almost even!)
- **Shield Tank L10 vs L1**: 76% (FAILED - Expected 85%+)
- **Cross-Archetype (Assassin L10 vs Berserker L1)**: 94% (PASSED)
- **Counter-Archetype (Parry Master L10 vs Assassin L1)**: 86% (PASSED)

## Key Findings

### 1. Progression is NOT Meaningful Enough
With the current system of +1 attribute point per level (9 total points from L1 to L10), level 10 characters do NOT consistently dominate level 1 characters of the same archetype.

### 2. Berserkers Have the Worst Progression
- Berserker L10 vs L1 shows only 52% win rate
- This suggests the STR+SIZE scaling for heavy weapons doesn't benefit enough from small attribute increases
- The weapon classification system may need further tuning

### 3. Cross-Archetype Works Better Than Same-Archetype
- Assassin L10 beats Berserker L1 at 94% (excellent)
- But Assassin L10 only beats Assassin L1 at 74% (poor)
- This suggests equipment matchups still dominate over stats

## Root Cause Analysis

### 1. Insufficient Attribute Point Gain
9 attribute points spread across stats is not enough to create dominance:
- Assassin: +3 STR, +6 AGI = Only ~31% more AGI
- Berserker: +4 STR, +5 SIZE = Only ~21% more damage stats
- These increases are too small given the randomness in combat

### 2. Weapon Base Damage Still Dominates
Even with the v26 classification system:
- Dual Daggers: 25-40 base damage
- Battleaxe: 120-180 base damage
- The 4-5x base damage difference still overshadows attribute scaling

### 3. Defensive Stats Don't Scale Well
- CON gives +15 HP per point
- Going from 5 to 10 CON = +75 HP
- But damage output increases much faster than HP pools

## Recommendations

### Option 1: Increase Attribute Points Per Level (RECOMMENDED)
Change from 1 point per level to 2-3 points per level:
- **2 points/level**: 18 total points (L1→L10)
- **3 points/level**: 27 total points (L1→L10)

This would allow more meaningful stat increases and clearer progression.

### Option 2: Implement Exponential Scaling
Make attribute points more valuable at higher values:
- STR 20-25: Each point gives +10 damage instead of +5
- AGI 20-25: Each point gives +2% hit/dodge instead of +1%
- This rewards focused builds and progression

### Option 3: Add Level-Based Bonuses
In addition to attribute points, add direct level bonuses:
- +5% damage per level
- +2% hit/block/parry per level
- +10 HP per level

### Option 4: Hybrid Approach (BEST)
Combine multiple solutions:
1. Increase to 2 points per level (18 total)
2. Add small level-based bonuses (+3% damage, +5 HP per level)
3. Keep the 25 attribute cap for progression meaning

## Testing Requirements

With any change, we need L10 to achieve:
- **90%+ win rate** vs L1 same archetype
- **70%+ win rate** vs L1 counter-archetype
- **95%+ win rate** vs L1 favorable matchup

## Conclusion

The GameEngine v26 improvements helped make stats matter more, but progression is still not meaningful enough. Players investing in leveling from 1 to 10 should see dramatic power increases, not the marginal improvements we currently observe.

The fact that a Level 10 Berserker only wins 52% against a Level 1 Berserker is unacceptable for a progression-based game.
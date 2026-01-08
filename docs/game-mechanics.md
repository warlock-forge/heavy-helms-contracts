# Heavy Helms Game Mechanics

## Player Archetypes & Combat Balance

### 1. Assassin (Fast AGI Damage Dealer)

- **Stats**: STR=19, CON=5, SIZE=12, AGI=19, STA=5, LUCK=12 (Total: 72)
- **Weapons**: DUAL_DAGGERS, RAPIER_DAGGER, SCIMITAR_DAGGER, DUAL_SCIMITARS
- **Identity**: High AGI scaling damage, speed over defense

### 2. Berserker (Heavy STR+SIZE Damage Dealer)

- **Stats**: STR=19, CON=5, SIZE=19, AGI=12, STA=12, LUCK=5 (Total: 72)
- **Weapons**: BATTLEAXE, MAUL, GREATSWORD
- **Identity**: Massive damage, breakthrough mechanics, slower but devastating

### 3. Shield Tank (Pure Defensive Tank)

- **Stats**: STR=12, CON=19, SIZE=19, AGI=5, STA=12, LUCK=5 (Total: 72)
- **Weapons**: MACE_TOWER, AXE_TOWER, CLUB_TOWER, SHORTSWORD_TOWER
- **Identity**: Absorb damage, outlast opponents, defensive specialist

### 4. Parry Master (Technical Defensive Fighter)

- **Stats**: STR=12, CON=19, SIZE=5, AGI=19, STA=5, LUCK=12 (Total: 72)
- **Weapons**: RAPIER_BUCKLER, SCIMITAR_BUCKLER, SHORTSWORD_BUCKLER, RAPIER_DAGGER, SCIMITAR_DAGGER
- **Identity**: Skill-based defense, counter-attacking, finesse over force

### 5. Bruiser (Brute Force Brawler)

- **Stats**: STR=19, CON=5, SIZE=19, AGI=5, STA=12, LUCK=12 (Total: 72)
- **Weapons**: DUAL_CLUBS, AXE_MACE, MACE_SHORTSWORD
- **Identity**: Sustained damage output, dual-wield specialist

### 6. Vanguard (Balanced Heavy Fighter)

- **Stats**: STR=19, CON=19, SIZE=12, AGI=5, STA=12, LUCK=5 (Total: 72)
- **Weapons**: GREATSWORD, AXE_KITE, QUARTERSTAFF
- **Identity**: Versatile heavy fighter, defensive capabilities with offensive potential

### 7. Balanced (All-Rounder Fighter)

- **Stats**: STR=12, CON=12, SIZE=12, AGI=12, STA=12, LUCK=12 (Total: 72)
- **Weapons**: ARMING_SWORD_SHORTSWORD, ARMING_SWORD_CLUB, ARMING_SWORD_KITE, MACE_KITE
- **Identity**: Jack-of-all-trades, adaptable to different situations

### 8. Monk (Reach & Control Specialist)

- **Stats**: STR=12, CON=19, SIZE=5, AGI=19, STA=12, LUCK=5 (Total: 72)
- **Weapons**: TRIDENT, SPEAR, QUARTERSTAFF
- **Identity**: Reach advantage, dodge-focused, technical combat

## Core Attribute Effects

### STRENGTH (STR)

- **Weapon Damage**: Primary for Pure Blunt (×10), major for Balanced Swords (×7), Heavy Demolition (×5)
- **Block Chance**: +0.5 per point (primary stat for shield defense)
- **Parry Chance**: +0.4 per point
- **Counter Chance**: +2 per point
- **Critical Multiplier**: +3 per point
- **Endurance**: +5 per point
- **Universal Damage Bonus**: -3% (STR 3-8), baseline (STR 9-16), +3% (STR 17-21), +5% (STR 22+)

### CONSTITUTION (CON)

- **Health**: +17 per point (formula: `50 + CON * 17 + SIZE * 6 + STA * 3`)
- **Survival Rate**: +1 per point
- **Block Chance**: +0.2 per point
- **Riposte Chance**: +0.3 per point

### SIZE

- **Health**: +6 per point
- **Weapon Damage**: Primary for Heavy Demolition (×5), contributes to Dual Wield Brute (×3)
- **Block Chance**: +0.3 per point
- **Critical Multiplier**: +2 per point
- **Dodge Penalty**: Reduces dodge as size increases
- **Universal Size Damage Bonus**: -5% (SIZE 3-8), baseline (SIZE 9-16), +5% (SIZE 17-21), +10% (SIZE 22+)

### AGILITY (AGI)

- **Weapon Damage**: Primary for Light Finesse (×10), Curved Blade (×7), Reach Control (×8)
- **Initiative**: +3 per point (determines turn order)
- **Hit Chance**: +1 per point (formula: `50 + AGI/2 + LUCK * 2.5`)
- **Dodge Chance**: +0.3 per point
- **Critical Chance**: +0.33 per point
- **Parry Chance**: +0.25 per point

### STAMINA (STA)

- **Endurance**: +20 per point (formula: `35 + STA * 20 + STR * 5`)
- **Health**: +3 per point
- **Dodge Chance**: +0.2 per point
- **Parry Chance**: +0.3 per point
- **Critical**: Below 50% stamina causes severe combat penalties

### LUCK

- **Hit Chance**: +2.5 per point (major contributor)
- **Initiative**: +2 per point
- **Critical Chance**: +0.33 per point
- **Riposte Chance**: +1 per point
- **Survival Rate**: +2 per point

## Weapon Classification System (7 Classes)

### 1. LIGHT_FINESSE (Pure AGI×10 damage)

- **Formula**: Base 20 + AGI×10
- **Weapons**: Dual Daggers, Rapier+Dagger, Rapier+Buckler, Shortsword+Buckler, Shortsword+Tower
- **Specialization**: +10 initiative, +10% endurance

### 2. CURVED_BLADE (AGI×7 + STR×3)

- **Formula**: Base 35 + AGI×7 + STR×3
- **Weapons**: Dual Scimitars, Scimitar+Dagger, Scimitar+Buckler
- **Specialization**: +5% crit chance, +3% dodge

### 3. BALANCED_SWORD (STR×7 + AGI×3)

- **Formula**: Base 35 + STR×7 + AGI×3
- **Weapons**: Arming Sword variants
- **Specialization**: +3% hit chance, +5% damage

### 4. PURE_BLUNT (Pure STR×10)

- **Formula**: Base 20 + STR×10
- **Weapons**: Dual Clubs, Mace variants, Club+Tower
- **Specialization**: +5% counter chance, +5% damage

### 5. HEAVY_DEMOLITION (STR×5 + SIZE×5)

- **Formula**: Base 40 + STR×5 + SIZE×5
- **Weapons**: Battleaxe, Maul, Greatsword, Axe+Shield variants
- **Specialization**: +10% crit multiplier, +7% damage

### 6. DUAL_WIELD_BRUTE (STR×4 + SIZE×3 + AGI×3)

- **Formula**: Base 50 + STR×4 + SIZE×3 + AGI×3
- **Weapons**: Axe+Mace, Mace+Shortsword
- **Specialization**: +10% endurance, +3% parry

### 7. REACH_CONTROL (AGI×8 + STR×8)

- **Formula**: Base 35 + AGI×8 + STR×8
- **Special**: +5% base dodge chance bonus
- **Weapons**: Trident, Spear, Quarterstaff
- **Specialization**: +5% dodge, +5% parry

## Level Progression System

### Experience & Levels

- **Maximum Level**: 10
- **XP Requirements**: 100 (L2), 250 (L3), 475 (L4), 812 (L5), 1318 (L6), 2077 (L7), 3216 (L8), 4924 (L9), 7486 (L10)

### Level Benefits

- **Health**: +5% per level (max +45% at level 10)
- **Damage**: +5% per level (max +45% at level 10)
- **Initiative**: +2 per level (max +18 at level 10)
- **Attribute Points**: +1 per level (can exceed 21 cap, max 25)

### Specialization Unlocks

- **Level 5**: Armor specialization
- **Level 10**: Weapon specialization

## Stamina System & Combat Penalties

### Stamina Costs

- Attack: 16 base
- Block: 4 base
- Dodge: 4 base
- Parry: 4 base
- Counter: 6 base
- Riposte: 6 base

### Low Stamina Effects

- **50-20% (Tired)**: -30% to all defensive stats, attackers gain +10 hit
- **Below 20% (Exhausted)**: -40% to all defensive stats, triggers Predator Mode
- **Predator Mode**: Attackers gain +30 hit, +50 crit chance, ×2 crit multiplier
- **Exception**: Tower Shield + Defensive Stance immune to stamina penalties

## Stance System

### Defensive Stance

- Damage/Hit: -25%
- Defensive stats: +40-50%
- Stamina cost: -45%
- Survival: +25%
- Plate armor: 100% effectiveness

### Balanced Stance

- All stats at baseline (100%)
- Plate armor: 75% effectiveness

### Offensive Stance

- Damage: +15%
- Hit chance: +30%
- Crit multiplier: +50%
- Defensive stats: -40%
- Stamina cost: +45%
- Survival: -25%
- Plate armor: 50% effectiveness
